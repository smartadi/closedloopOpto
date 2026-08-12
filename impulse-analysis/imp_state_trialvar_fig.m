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

%% ---- one funnel + one SD panel per admissible marker ------------------------------------------
for k = adm
    r   = R(k);
    tag = lower(r.tag);

    % ================= funnel: signed deviation vs state ========================================
    % SIGNED, not |dev| -- the point of the analysis is that the effect is on SPREAD and has no
    % directional component, which is only visible if both signs are on the page.
    f = paperFig(6, 4);  ax = axes(f);  hold(ax,'on');
    scatter(ax, r.x, r.y, 3, PS.grad1, 'filled', ...
            'MarkerFaceAlpha', 0.25, 'MarkerEdgeColor','none', 'HandleVisibility','off');
    hEnv = plot(ax, r.binMed,  r.sdB, '-o', 'Color', C_stim, 'MarkerFaceColor', C_stim, ...
                'LineWidth', PS.lw_fit, 'MarkerSize', 2.5, 'DisplayName', '\pm1 SD');
    plot(ax, r.binMed, -r.sdB, '-o', 'Color', C_stim, 'MarkerFaceColor', C_stim, ...
         'LineWidth', PS.lw_fit, 'MarkerSize', 2.5, 'HandleVisibility','off');
    hz = yline(ax, 0, 'k:', 'LineWidth', PS.lw_zero);  hz.HandleVisibility = 'off';
    xlim(ax, quantile(r.x, [0.005 0.995]));
    ylim(ax, [-4 4]);
    set(ax, 'Box', PS.ax_box, 'TickDir', PS.ax_tickdir, 'FontSize', PS.fs, 'FontWeight', PS.fw);
    xlabel(ax, sprintf('%s (%s)', r.name, r.units), 'FontSize', PS.fs, 'FontWeight', PS.fw);
    ylabel(ax, 'Deviation from amp mean (SD)',      'FontSize', PS.fs, 'FontWeight', PS.fw);
    lg = legend(ax, hEnv, 'Location','northeast');  paperLegend(lg);
    hold(ax,'off');
    paperExport(f, fullfile(outDir, sprintf('stv_%s_funnel%s', tag, STVF_EXT)));

    % ================= the result: SD per state bin, bootstrap CI ================================
    % Per-bin CI by resampling WITHIN each bin -- the exploratory figure carries a CI only on the
    % top/bottom ratio, which cannot show whether an individual bin is resolved.
    [ciLo, ciHi] = local_binci(r.y,  r.gbin, nB, STVF_NBOOT);
    if STV_PLOTCTRL
        yp = STV.T.devPre;                                   % same trials, same order as r.y
        [cpLo, cpHi] = local_binci(yp, r.gbin, nB, STVF_NBOOT);
    end

    f = paperFig(6, 4);  ax = axes(f);  hold(ax,'on');
    hS = errorbar(ax, r.binMed, r.sdB, r.sdB-ciLo, ciHi-r.sdB, '-o', ...
                  'Color', C_stim, 'MarkerFaceColor', C_stim, 'LineWidth', PS.lw_fit, ...
                  'MarkerSize', 3, 'CapSize', 2, 'DisplayName', 'Impulse response');
    hAll = hS;
    if STV_PLOTCTRL
        hC = errorbar(ax, r.binMed, r.sdP, r.sdP-cpLo, cpHi-r.sdP, '--s', ...
                      'Color', C_ctl, 'MarkerFaceColor', C_ctl, 'LineWidth', PS.lw_fit, ...
                      'MarkerSize', 2.5, 'CapSize', 2, 'DisplayName', 'No stimulus');
        hAll = [hS hC];
    end
    % Ticks AT the bin medians, so uneven spacing stays visible (the raw motion bins really are
    % crowded at the low end -- that is information, not a plotting defect). Rotated because at
    % 6 cm the crowded labels collide otherwise.
    xticks(ax, r.binMed);
    xticklabels(ax, compose('%.2f', r.binMed));
    xtickangle(ax, 30);
    xlim(ax, [min(r.binMed) - 0.10*range(r.binMed), max(r.binMed) + 0.10*range(r.binMed)]);
    set(ax, 'Box', PS.ax_box, 'TickDir', PS.ax_tickdir, 'FontSize', PS.fs, 'FontWeight', PS.fw);
    xlabel(ax, sprintf('%s (%s)', r.name, r.units), 'FontSize', PS.fs, 'FontWeight', PS.fw);
    ylabel(ax, 'SD of deviation',                   'FontSize', PS.fs, 'FontWeight', PS.fw);
    title(ax, sprintf('SD ratio %.2f [%.2f-%.2f]  p=%.1e', r.ratio, r.ci(1), r.ci(2), r.bf), ...
          'FontSize', PS.fs, 'FontWeight', PS.fw);
    % A one-entry legend labels a panel that has only one thing on it -- drop it and let the
    % y-label do the work. It comes back automatically when the control adds a second series.
    if numel(hAll) > 1, lg = legend(ax, hAll, 'Location','best');  paperLegend(lg); end
    hold(ax,'off');
    paperExport(f, fullfile(outDir, sprintf('stv_%s_sd%s', tag, STVF_EXT)));
end

%% ---- per-session replication ------------------------------------------------------------------
% The pooled numbers are computed on RAW (un-z-scored) states, so between-session offsets could in
% principle manufacture them. This panel is the check: the effect has to be visible session by
% session, with no pooling to hide behind.
uS   = unique(STV.T.sess);
nS   = numel(uS);
qual = PS.sessQual(numel(adm));

f = paperFig(6, 4);  ax = axes(f);  hold(ax,'on');
for i = 1:numel(adm)
    k = adm(i);
    plot(ax, 1:nS, STV.PS_rho(:,k), '-o', 'Color', qual(i,:), 'MarkerFaceColor', qual(i,:), ...
         'LineWidth', PS.lw_fit, 'MarkerSize', 3, 'DisplayName', R(k).name);
end
hz = yline(ax, 0, 'k-', 'LineWidth', PS.lw_zero);  hz.HandleVisibility = 'off';
xticks(ax, 1:nS);
xticklabels(ax, local_shortlab(STV.labels(uS)));
xtickangle(ax, 30);
xlim(ax, [0.7 nS+0.3]);  ylim(ax, [-0.35 0.35]);
set(ax, 'Box', PS.ax_box, 'TickDir', PS.ax_tickdir, 'FontSize', PS.fs, 'FontWeight', PS.fw);
ylabel(ax, '\rho( |deviation| , state )', 'FontSize', PS.fs, 'FontWeight', PS.fw);
lg = legend(ax, 'Location','best');  paperLegend(lg);
hold(ax,'off');
paperExport(f, fullfile(outDir, ['stv_persession' STVF_EXT]));

%% ---- motion threshold split + variance decomposition (control panels) --------------------------
if STV_PLOTCTRL
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
else
    fprintf(['[STVF] STV_PLOTCTRL=false -- skipped stv_motsplit and stv_vardecomp.\n' ...
             '       Both exist to compare the response against the stim-free window;\n' ...
             '       without it they are bars with nothing to be measured against.\n']);
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
