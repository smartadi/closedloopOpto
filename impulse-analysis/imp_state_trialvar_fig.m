%% IMP_STATE_TRIALVAR_FIG  Paper-style panels for the trial-variability-vs-state analysis.
%
% Style matches motion_analysis.m: paperFig / paperStyle / paperLegend / paperExport,
% 6 pt bold throughout, Box off, TickDir out, 6 x 4 cm default.
%
% RUN AFTER `imp_state_trialvar.m` -- it consumes the STV struct that script leaves in the
% workspace. Nothing is recomputed here except the per-bin bootstrap CIs (the exploratory
% figure has a CI only on the top/bottom ratio, which is too coarse for a panel).
%
% Panels, one pair per ADMISSIBLE marker (motion, relative delta):
%   stv_<tag>_funnel  6x4  signed per-trial deviation vs state, with the +/-SD envelope
%   stv_<tag>_sd      6x4  SD of the deviation per state bin, with bootstrap CI  <- the result
%   stv_persession    6x4  rho(|dev|, state) per session, both markers
%   stv_motsplit      6x4  SD below vs above the motion threshold        (control-dependent)
%   stv_vardecomp     6x4  variance decomposition at the motion split    (control-dependent)
%
% The last two are drawn ONLY when STV_PLOTCTRL is true, because both exist to compare the
% response against the stim-free window -- without that comparison they are just two bars.
%
% Export is PNG at 300 dpi (CLAUDE.md: PDF only for panels registered in PAPER.md or when the
% user calls it a paper panel). Set STVF_EXT='.pdf' if one of these is promoted.

here = fileparts(mfilename('fullpath'));
if isempty(here), here = pwd; end
addpath(genpath(fullfile(fileparts(here), 'utils')));

assert(exist('STV','var')==1 && isstruct(STV), ...
       '[STVF] STV absent -- run imp_state_trialvar.m first.');

PS = paperStyle();
if ~exist('STVF_EXT','var')   || isempty(STVF_EXT),   STVF_EXT = '.png';  end
if ~exist('STVF_NBOOT','var') || isempty(STVF_NBOOT), STVF_NBOOT = 2000;  end
% WHICH PANELS (user, 2026-08-12: "we will keep the two quartile plots"):
%   'quartile' (DEFAULT) -- only the two SD-per-quartile panels, the ones going into the figure
%   'all'                -- adds the funnels and the per-session panel as exploratory PNGs
if ~exist('STVF_PANELS','var') || isempty(STVF_PANELS), STVF_PANELS = 'quartile'; end
% PAPER BUILD. When true the two quartile panels are ALSO written as vector PDFs into
% paper/images/figure2/ under locked names. PAPER.md's asset policy is that a PDF in a figureN
% folder means the panel is locked and Illustrator-linked -- so this stays OFF by default and is
% turned on deliberately, and the panels are registered in PAPER.md in the same commit.
if ~exist('STVF_PAPER','var') || isempty(STVF_PAPER), STVF_PAPER = false; end
% Overridable so a build can be staged somewhere writable: the real paper/images/figure2
% PDFs are LOCKED whenever Illustrator or Acrobat has them open, and a half-written panel
% set is worse than none.
if exist('STVF_PAPERROOT','var') == 1 && ~isempty(STVF_PAPERROOT)
    paperRoot = STVF_PAPERROOT;
else
    paperRoot = fullfile(fileparts(here), 'paper');
end
paperNames = struct('MOT','imp_state_var_motion', 'DPr','imp_state_var_reldelta');
% Inherit the control switch from the main script so the two never disagree about what is
% being shown. Default true, matching imp_state_trialvar.m.
if ~exist('STV_PLOTCTRL','var') || isempty(STV_PLOTCTRL), STV_PLOTCTRL = true; end

outDir = fullfile(here, 'figs', 'state_trialvar', 'paper');
if ~exist(outDir,'dir'), mkdir(outDir); end

R   = STV.R;
adm = find([R.adm]);                       % admissible markers only (motion, rel delta)
C_stim = PS.col_ol;                        % red  -- impulse response
C_ctl  = PS.col_inp_ol;                    % gray -- stim-free control
nB     = STV.nbin;

rng(11,'twister');
fprintf('\n[STVF] paper panels -> %s   (control %s)\n', outDir, ...
        local_tern(STV_PLOTCTRL,'ON','OFF'));

%% ---- pass 1: bootstrap the per-bin CIs for every marker ----------------------------------------
% Done up front so the quartile panels can share one y-axis. Two panels of the SAME quantity on
% different y-scales invite a reader to compare their slopes, which is exactly the comparison the
% differing scales make invalid.
CI = struct('lo',{},'hi',{},'ploLo',{},'ploHi',{});
for i = 1:numel(adm)
    k = adm(i);
    [CI(i).lo, CI(i).hi] = local_binci(R(k).y, R(k).gbin, nB, STVF_NBOOT);
    if STV_PLOTCTRL
        [CI(i).ploLo, CI(i).ploHi] = local_binci(STV.T.devPre, R(k).gbin, nB, STVF_NBOOT);
    end
end
yAll = [ [CI.lo] [CI.hi] R(adm).sdB ];
if STV_PLOTCTRL, yAll = [yAll [CI.ploLo] [CI.ploHi] R(adm).sdP]; end
yAll = yAll(isfinite(yAll));
yLimSD = [floor(min(yAll)*20)/20, ceil(max(yAll)*20)/20];     % common y-axis, rounded to 0.05

%% ---- pass 2: draw ------------------------------------------------------------------------------
for i = 1:numel(adm)
    k   = adm(i);
    r   = R(k);
    tag = lower(r.tag);

    % ================= funnel: signed deviation vs state ========================================
    if strcmpi(STVF_PANELS, 'all')
    % SIGNED, not |dev| -- the point of the analysis is that the effect is on SPREAD and has no
    % directional component, which is only visible if both signs are on the page.
    % The envelope is a filled RIBBON, not two lines: at 6 cm two thin curves read as two
    % unrelated series, while the shaded band reads as the one thing it is -- the spread.
    f = paperFig(6, 4);  ax = axes(f);  hold(ax,'on');
    xb = r.binMed(:).';  sb = r.sdB(:).';
    fill(ax, [xb fliplr(xb)], [sb -fliplr(sb)], C_stim, ...
         'FaceAlpha', PS.fa, 'EdgeColor','none', 'HandleVisibility','off');
    scatter(ax, r.x, r.y, 2, [0.62 0.62 0.62], 'filled', ...
            'MarkerFaceAlpha', 0.30, 'MarkerEdgeColor','none', 'HandleVisibility','off');
    plot(ax, xb,  sb, '-', 'Color', C_stim, 'LineWidth', PS.lw_fit, 'HandleVisibility','off');
    plot(ax, xb, -sb, '-', 'Color', C_stim, 'LineWidth', PS.lw_fit, 'HandleVisibility','off');
    hz = yline(ax, 0, 'k:', 'LineWidth', PS.lw_zero);  hz.HandleVisibility = 'off';
    xlim(ax, [0 1]);  ylim(ax, [-3.2 3.2]);
    xticks(ax, 0:0.25:1);  yticks(ax, -3:1.5:3);
    set(ax, 'Box', PS.ax_box, 'TickDir', PS.ax_tickdir, 'FontSize', PS.fs, 'FontWeight', PS.fw);
    xlabel(ax, sprintf('%s (%s)', r.name, r.units), 'FontSize', PS.fs, 'FontWeight', PS.fw);
    ylabel(ax, 'Deviation (SD)', 'FontSize', PS.fs, 'FontWeight', PS.fw);
    text(ax, 0.97, 0.94, '\pm1 SD', 'Units','normalized', 'HorizontalAlignment','right', ...
         'Color', C_stim, 'FontSize', PS.fs, 'FontWeight', PS.fw);
    hold(ax,'off');
    paperExport(f, fullfile(outDir, sprintf('stv_%s_funnel%s', tag, STVF_EXT)));
    end   % STVF_PANELS == 'all'

    % ================= the result: SD per quartile, bootstrap CI =================================
    % Per-bin CI by resampling WITHIN each bin -- the exploratory figure carries a CI only on the
    % top/bottom ratio, which cannot show whether an individual bin is resolved.
    ciLo = CI(i).lo;  ciHi = CI(i).hi;
    if STV_PLOTCTRL, cpLo = CI(i).ploLo;  cpHi = CI(i).ploHi; end

    f = paperFig(PS.f2w, PS.f2h);  ax = axes(f);  hold(ax,'on');   % 2J / 2K -- Fig-2 grid
    xb = r.binMed(:).';
    fill(ax, [xb fliplr(xb)], [ciLo fliplr(ciHi)], C_stim, ...
         'FaceAlpha', PS.fa, 'EdgeColor','none', 'HandleVisibility','off');
    hS = plot(ax, xb, r.sdB, '-o', 'Color', C_stim, 'MarkerFaceColor', C_stim, ...
              'LineWidth', PS.lw_mean, 'MarkerSize', 2.5, 'DisplayName','Impulse response');
    hAll = hS;
    if STV_PLOTCTRL
        fill(ax, [xb fliplr(xb)], [cpLo fliplr(cpHi)], C_ctl, ...
             'FaceAlpha', PS.fa, 'EdgeColor','none', 'HandleVisibility','off');
        hC = plot(ax, xb, r.sdP, '--s', 'Color', C_ctl, 'MarkerFaceColor', C_ctl, ...
                  'LineWidth', PS.lw_fit, 'MarkerSize', 2, 'DisplayName','No stimulus');
        hAll = [hS hC];
    end
    % Quartile ticks. The markers sit at the bin MEDIANS, which on a percentile axis land at
    % Q1..Q4 centres by construction -- so label the quartiles rather than 0/0.25/0.5/0.75/1,
    % which would invite reading the x position as a magnitude it does not carry.
    xticks(ax, 0.125:0.25:0.875);
    xticklabels(ax, {'Q1','Q2','Q3','Q4'});
    xlim(ax, [0 1]);  ylim(ax, yLimSD);
    set(ax, 'Box', PS.ax_box, 'TickDir', PS.ax_tickdir, 'FontSize', PS.fs, 'FontWeight', PS.fw);
    xlabel(ax, sprintf('%s quartile', r.name), 'FontSize', PS.fs, 'FontWeight', PS.fw);
    ylabel(ax, 'SD of deviation', 'FontSize', PS.fs, 'FontWeight', PS.fw);
    % NO in-panel stats text (user, 2026-08-12: "i dont like the text we put there"). The
    % numbers are printed to the console by imp_state_trialvar and belong in the caption --
    % Q4/Q1 with CI and the stratified rho are sentences, not annotations, and at 6 pt inside
    % a 4 cm axis they were competing with the data for the reader's first glance. Printed
    % here so the caption can be written straight off the run.
    fprintf('[STVF] %-12s caption numbers: Q4/Q1 %.2f [%.2f-%.2f], BF p %.2g, strat rho %+.3f, n=%d\n', ...
            r.name, r.ratio, r.ci(1), r.ci(2), r.bf, r.rhoStrat, r.n);
    % A one-entry legend labels a panel that has only one thing on it -- drop it and let the
    % y-label do the work. It comes back automatically when the control adds a second series.
    if numel(hAll) > 1, lg = legend(ax, hAll, 'Location','best');  paperLegend(lg); end
    hold(ax,'off');
    paperExport(f, fullfile(outDir, sprintf('stv_%s_sd%s', tag, STVF_EXT)));

    % ---- paper build: the same axes as a locked vector PDF -------------------------------------
    if STVF_PAPER
        if ~isfield(paperNames, r.tag)
            warning('[STVF] no locked filename for marker %s -- PDF skipped.', r.tag);
        else
            pdfDir = fullfile(paperRoot, 'images', 'figure2');
            if ~exist(pdfDir,'dir'), mkdir(pdfDir); end
            paperExport(f, fullfile(pdfDir, [paperNames.(r.tag) '.pdf']));
        end
    end
end

%% ---- 2G REBUILD: per-session |dev| vs rel-delta, all sessions on one axis ----------------------
% Replaces the old 2G (single-session pre-stim-variance scatter, retracted 2026-07-01 as a signal-
% power confound). Two changes, both from the user 2026-08-12: ALL sessions, not just AL_0033, and
% RELATIVE delta on x rather than pre-stim variance -- rel delta is the power-corrected marker, the
% only version of the delta claim that is not arithmetically guaranteed by signal amplitude.
% Why a scatter beside 2K's quartile curve: 2K asserts "3 of 4 sessions agree" and this is where a
% reader can see it. Per-session fits make a session that runs the other way visible instead of
% averaged away. |dev| on y because the claim is about SPREAD -- see the Levene note in the driver.
kD = find(strcmpi({R.tag}, 'DPr'), 1);
if ~isempty(kD)
    xs = STV.T.DPrz(:);  ys = abs(STV.T.dev(:));  ss = STV.T.sess(:);
    vv = isfinite(xs) & isfinite(ys);
    f = paperFig(PS.f2w, PS.f2h);  ax = axes(f);  hold(ax,'on');   % 2G -- Fig-2 grid
    % Shuffled draw order with per-point colour, so no session paints over the others -- the
    % same defect that was fixed in 2F on the same day.
    rng(3,'twister');  sh = randperm(nnz(vv));  iv = find(vv);  iv = iv(sh);
    scatter(ax, xs(iv), ys(iv), 3, PS.sess(ss(iv),:), 'filled', ...
            'MarkerFaceAlpha', 0.35, 'MarkerEdgeColor','none', 'HandleVisibility','off');
    uu = unique(ss(vv));  hL = gobjects(numel(uu),1);
    for i = 1:numel(uu)
        m = vv & ss == uu(i);
        p = polyfit(xs(m), ys(m), 1);
        xf = linspace(min(xs(m)), max(xs(m)), 50);
        hL(i) = plot(ax, xf, polyval(p, xf), '-', 'Color', PS.sessColor(uu(i)), ...
                     'LineWidth', PS.lw_mean, 'DisplayName', sprintf('s%d', uu(i)));
    end
    xlim(ax, [0 1]);  ylim(ax, [0 3]);  xticks(ax, 0:0.25:1);
    set(ax, 'Box', PS.ax_box, 'TickDir', PS.ax_tickdir, 'FontSize', PS.fs, 'FontWeight', PS.fw);
    xlabel(ax, 'Rel \delta (within-session percentile)', 'FontSize', PS.fs, 'FontWeight', PS.fw);
    ylabel(ax, '|Deviation| (SD)', 'FontSize', PS.fs, 'FontWeight', PS.fw);
    lg = legend(ax, hL, 'Location','northwest', 'NumColumns', 2);  paperLegend(lg);
    hold(ax,'off');
    paperExport(f, fullfile(outDir, ['stv_reldelta_scatter' STVF_EXT]));
    if STVF_PAPER
        pdfDir = fullfile(paperRoot, 'images', 'figure2');
        if ~exist(pdfDir,'dir'), mkdir(pdfDir); end
        paperExport(f, fullfile(pdfDir, 'imp_state_reldelta_scatter.pdf'));
    end
    fprintf('[STVF] rel-delta per-session slopes: %s\n', ...
            strjoin(compose('s%d %+.3f', uu, R(kD).rhoPerSess(:)).', '  '));
end

%% ---- per-session replication ------------------------------------------------------------------
% The pooled numbers are computed on RAW (un-z-scored) states, so between-session offsets could in
% principle manufacture them. This panel is the check: the effect has to be visible session by
% session, with no pooling to hide behind.
uS   = unique(STV.T.sess);
nS   = numel(uS);
qual = PS.sessQual(numel(adm));
if strcmpi(STVF_PANELS, 'all')

f = paperFig(6, 4);  ax = axes(f);  hold(ax,'on');
hz = yline(ax, 0, 'k-', 'LineWidth', PS.lw_zero);  hz.HandleVisibility = 'off';
% Markers only, no connecting line: sessions are not an ordered series, so a line between them
% implies a trend that does not exist. Offset the two markers so they never sit on top of
% each other at a session where the two rho happen to coincide.
off = linspace(-0.10, 0.10, max(numel(adm),2));
for i = 1:numel(adm)
    k = adm(i);
    plot(ax, (1:nS) + off(i), STV.PS_rho(:,k), 'o', 'Color', qual(i,:), ...
         'MarkerFaceColor', qual(i,:), 'MarkerSize', 3, 'LineWidth', 0.5, ...
         'DisplayName', R(k).name);
end
xticks(ax, 1:nS);
xticklabels(ax, local_shortlab(STV.labels(uS)));
xlim(ax, [0.5 nS+0.5]);  ylim(ax, [-0.32 0.32]);  yticks(ax, -0.3:0.15:0.3);
set(ax, 'Box', PS.ax_box, 'TickDir', PS.ax_tickdir, 'FontSize', PS.fs, 'FontWeight', PS.fw);
ylabel(ax, '\rho( |deviation| , state )', 'FontSize', PS.fs, 'FontWeight', PS.fw);
lg = legend(ax, 'Location','best');  paperLegend(lg);
hold(ax,'off');
paperExport(f, fullfile(outDir, ['stv_persession' STVF_EXT]));
end   % STVF_PANELS == 'all'

%% ---- motion threshold split + variance decomposition (control panels) --------------------------
if STV_PLOTCTRL && strcmpi(STVF_PANELS, 'all')
    M = STV.motSplit;

    % ---- SD below vs above the threshold, response beside the stim-free window -----------------
    f = paperFig(6, 4);  ax = axes(f);  hold(ax,'on');
    bar(ax, [1 2], [M.sdLo M.sdHi], 0.55, 'FaceColor', C_stim, 'EdgeColor','none', ...
        'DisplayName', 'Impulse response');
    bar(ax, [4 5], [M.sdLoP M.sdHiP], 0.55, 'FaceColor', C_ctl, 'EdgeColor','none', ...
        'DisplayName', 'No stimulus');
    xticks(ax, [1 2 4 5]);
    xticklabels(ax, {sprintf('z\\leq%.1f', M.thr), sprintf('z>%.1f', M.thr), ...
                     sprintf('z\\leq%.1f', M.thr), sprintf('z>%.1f', M.thr)});
    xlim(ax, [0.3 5.7]);
    set(ax, 'Box', PS.ax_box, 'TickDir', PS.ax_tickdir, 'FontSize', PS.fs, 'FontWeight', PS.fw);
    ylabel(ax, 'SD of deviation', 'FontSize', PS.fs, 'FontWeight', PS.fw);
    title(ax, sprintf('n=%d / %d   ratio %.2f vs %.2f', M.nLo, M.nHi, M.ratio, M.ratioP), ...
          'FontSize', PS.fs, 'FontWeight', PS.fw);
    lg = legend(ax, 'Location','best');  paperLegend(lg);
    hold(ax,'off');
    paperExport(f, fullfile(outDir, ['stv_motsplit' STVF_EXT]));

    % ---- variance decomposition ----------------------------------------------------------------
    % The claim is about the RESIDUAL bar: what is left of the response once the part predictable
    % from a stim-free window of the same length is regressed out. If that falls further than the
    % ongoing signal does, motion made the RESPONSE more reproducible, not the measurement cleaner.
    f = paperFig(6, 4);  ax = axes(f);  hold(ax,'on');
    ratios = [M.vObs(2)/M.vObs(1), M.vShm(2)/M.vShm(1), M.vRes(2)/M.vRes(1)];
    cols   = [C_stim; C_ctl; PS.col_fit];
    for i = 1:3
        bar(ax, i, ratios(i), 0.55, 'FaceColor', cols(i,:), 'EdgeColor','none');
    end
    h1 = yline(ax, 1, 'k-', 'LineWidth', PS.lw_zero);  h1.HandleVisibility = 'off';
    xticks(ax, 1:3);  xticklabels(ax, {'Observed','No stim','Residual'});
    xlim(ax, [0.4 3.6]);  ylim(ax, [0 max(ratios)*1.35]);
    for i = 1:3
        text(ax, i, ratios(i) + 0.05*max(ratios), sprintf('%.2f', ratios(i)), ...
             'HorizontalAlignment','center', 'FontSize', PS.fs, 'FontWeight', PS.fw);
    end
    set(ax, 'Box', PS.ax_box, 'TickDir', PS.ax_tickdir, 'FontSize', PS.fs, 'FontWeight', PS.fw);
    ylabel(ax, 'Variance ratio, high/low motion', 'FontSize', PS.fs, 'FontWeight', PS.fw);
    hold(ax,'off');
    paperExport(f, fullfile(outDir, ['stv_vardecomp' STVF_EXT]));
elseif ~STV_PLOTCTRL
    fprintf(['[STVF] STV_PLOTCTRL=false -- skipped stv_motsplit and stv_vardecomp.\n' ...
             '       Both exist to compare the response against the stim-free window;\n' ...
             '       without it they are bars with nothing to be measured against.\n']);
end
if strcmpi(STVF_PANELS, 'quartile')
    fprintf('[STVF] STVF_PANELS=''quartile'' -- funnels and per-session panel skipped (use ''all'').\n');
end

fprintf('[STVF] done.\n');

%% ================================= local functions ==============================================
function [lo, hi] = local_binci(y, g, nB, nboot)
%LOCAL_BINCI  Bootstrap 95%% CI on the SD within each bin, resampling WITHIN the bin.
lo = nan(1,nB);  hi = nan(1,nB);
for b = 1:nB
    v = y(g == b);  v = v(isfinite(v));
    n = numel(v);
    if n < 4, continue; end
    bs = arrayfun(@(~) std(v(randi(n, n, 1))), 1:nboot);
    q  = quantile(bs, [0.025 0.975]);
    lo(b) = q(1);  hi(b) = q(2);
end
end

function s = local_shortlab(labs)
%LOCAL_SHORTLAB  "AL_0041 2025-12-02 e1" -> "0041 e1" so 6 pt ticks stay legible at 6 cm.
s = cell(size(labs));
for i = 1:numel(labs)
    p = strsplit(labs{i}, ' ');
    mn = strrep(p{1}, 'AL_', '');
    if numel(p) >= 3, s{i} = sprintf('%s %s', mn, p{3}); else, s{i} = mn; end
end
end

function v = local_tern(c, a, b)
if c, v = a; else, v = b; end
end
