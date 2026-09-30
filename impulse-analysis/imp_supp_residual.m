%% imp_supp_residual.m -- SUPPLEMENTARY paper figure: the stim-blind Actual/Global/Local residual.
%
% SCOPE. ONE session: AL_0033 2025-01-29 e1 (pipeline index 3, "Mouse 2" on the Fig-2 panels).
% This is the only impulse session whose stim-blind decomposition is defensible, and the choice is
% made by a MODEL-QUALITY criterion computed before any state test (RESEARCH 2026-08-12):
%
%   AL_0033 e1  capture 91% / leak  9% / catch  -2% / 6 of 9 amps / 748 trials   -> KEPT (this file)
%   AL_0041 e1  capture 32% / leak 68% / catch -21%  -> CATCH FAILS, pipeline VOIDs its numbers
%   AL_0041 e2  capture 37% / leak 63% / catch -14%  -> weak model (this is pipeline index 2)
%   AL_0048 e1  capture 29% / leak 71%               -> readout ~2.6 mm off the illuminated spot
%
% *** THE 91/9 ABOVE IS THE 2026-08-12 NUMBER AND THIS SCRIPT NO LONGER REPRODUCES IT. ***
% As actually run 2026-09-30 under the CURRENTLY COMMITTED affected-pixel selection (f2_affected
% monotone selection, 136 of 442 contra px kept, committed 2026-09-10) with select_mode='r2max':
%
%   spont R^2 0.958 | capture 70% | leak 30% | catch -2% | shift-null -0.96 | 6 of 9 amps, 748 trials
%
% The ranking that picks AL_0033 is unchanged and the CATCH control is still clean (-2%), so the
% session choice stands -- but the capture number moved 91 -> 70 because the committed predictor
% set changed on 2026-09-10, not because anything here was re-tuned. QUOTE 70/30, NOT 91/9, and
% re-run this script rather than copying numbers out of RESEARCH.md if the selection is recommitted.
%
% ** n = 1. ** There is no pooling, no Stouffer and no replication here, and AL_0033 is also the
% highest-powered session (748 trials / 9 amps vs 208/260/300). "The only session where the effect
% is measurable" cannot be distinguished from "the only session where it is real". Every number
% this script prints is a single-session, single-mouse result and the caption must say so.
%
% WHY THIS IS SUPPLEMENTARY. The residual / Actual=Global+Local state-dependence was CUT from the
% main paper on 2026-09-11 (TASKS.md, RESEARCH 2026-09-11). Motion on the Local effect is null and
% the rel-delta effect does not survive pooling (held-out variability z=+0.79 p=.43), and rel-delta
% failed to replicate on Ye/Zhiwen AB_0004 with the OPPOSITE sign (RESEARCH 2026-07-02). Panels F/G
% are therefore a NEGATIVE / robustness result -- the decomposition is clean (A-E) and the local
% effect is state-ROBUST -- not a positive state-dependence claim.
%
% SELECTION MODE. 'r2max' is forced. The regulariser is picked on held-out spontaneous R^2 alone,
% so capture/leak are MEASURED rather than targeted and the GLOBAL negative control is armed. Under
% 'frontier' the penalty enforces b'e ~ 0, which is the very thing panels F/G's control tests, and
% any state result obtained there would be a property of the penalty. Do not change this silently.
%
% PANELS (each exported as its own vector PDF, assembled in Illustrator)
%   A  supp_res_A_predmap    where the prediction comes from: contra weights, excluded pixels, site
%   B  supp_res_B_heldout    the model itself: held-out spontaneous ipsi trace vs prediction
%   C  supp_res_C_agl        Actual = Global + Local, trial-averaged, 3 amplitudes + the CATCH tile
%   D  supp_res_D_dose       dose curves for the three components
%   E  supp_res_E_quality    capture / leak / |catch| against the 15% catch threshold
%   F  supp_res_F_motion     Local residual vs MOTION, with the Global negative control
%   G  supp_res_G_reldelta   Local residual vs 2-4 Hz RELATIVE delta, with the Global control
%
% RUN:  load_experiments        % once (reads SVD from the server; slow)
%       imp_supp_residual
%
% KNOBS (set before the run):  SUPP_SESS (3) | SUPP_SELECT ('r2max') | SUPP_OUTDIR | SUPP_DV
% --------------------------------------------------------------------------------------------------

here = fileparts(mfilename('fullpath'));
if isempty(here) || contains(here, tempdir,'IgnoreCase',true) || contains(here,'Editor_','IgnoreCase',true)
    here = 'C:\Users\aditya\Documents\projects\brain_paper\impulse-analysis';
end
addpath(here); addpath(genpath(fullfile(here,'..','utils')));

if ~exist('SUPP_SESS','var')   || isempty(SUPP_SESS),   SUPP_SESS   = 3;        end
if ~exist('SUPP_SELECT','var') || isempty(SUPP_SELECT), SUPP_SELECT = 'r2max';  end
if ~exist('SUPP_DV','var')     || isempty(SUPP_DV),     SUPP_DV     = 'L1DEVz'; end
if ~exist('SUPP_OUTDIR','var') || isempty(SUPP_OUTDIR)
    SUPP_OUTDIR = fullfile(here,'..','paper','images','supp_residual');
end
if ~exist(SUPP_OUTDIR,'dir'), mkdir(SUPP_OUTDIR); end

PS = paperStyle();
COL_A = [0 0 0];            % Actual  -- measured ipsi trace
COL_G = [0.85 0.20 0.20];   % Global  -- contra prediction (same convention as f2_fitfig)
COL_L = [0.10 0.40 0.85];   % Local   -- residual

%% ---- build the decomposition --------------------------------------------------------------------
if ~exist('allExperiments','var') || isempty(allExperiments)
    fprintf('[SUPP-RES] allExperiments absent -> load_experiments (reads SVD from the server; slow)\n');
    load_experiments
end
assert(SUPP_SESS >= 1 && SUPP_SESS <= numel(allExperiments), ...
    'imp_supp_residual: SUPP_SESS must be 1..%d', numel(allExperiments));

ae = allExperiments(SUPP_SESS);
fprintf('\n[SUPP-RES] session %d: %s %s e%d   select_mode=%s\n', SUPP_SESS, ae.mn, ae.td, ae.en, SUPP_SELECT);

P = f2_prep(ae, struct('dataDir', fullfile(here,'data'), 'verbose',true));
A = f2_affected(P, struct('plot',false));
M = f2_model(P, A, struct('select_mode',SUPP_SELECT, 'use_motion',false, 'verbose',false));
D = f2_decomp(P, M, struct('verbose',true, 'wantTraces',true));

fprintf('\n=====================================================================\n');
fprintf('  %s   (n=1, supplementary)\n', P.label);
fprintf('  spont R^2 %.3f | capture %.0f%% | leak %.0f%% | catch %+.0f%% | shift %.2f\n', ...
        M.r2_spont, D.capMed, D.leakMed, 100*D.catch.ratio, M.r2_shift);
fprintf('=====================================================================\n');
if abs(D.catch.ratio) > 0.15
    fprintf(2,'  ** CATCH FAILS -- do NOT export these panels as a paper figure **\n');
end

tt   = D.rel(:)/D.Fs;                       % D.rel is in FRAMES; convert once
preN = D.preN;
nG   = P.nG;  bPix = M.b(1:nG);

%% ================================================================================================
%  A  predictor map -- where the prediction comes from
%% ================================================================================================
figA = paperFig(5.0, 4.0);
axA  = axes(figA,'Position',[0.02 0.04 0.78 0.90]); hold(axA,'on');
image(axA, repmat(P.dspImg,[1 1 3])); axis(axA,'image','off'); set(axA,'YDir','reverse');

exc = find(any(A.affected,2));              % stim-affected -> EXCLUDED from the predictor set
plot(axA, P.dspGc(exc), P.dspGr(exc), 'x', 'Color',[0.45 0.45 0.45], 'MarkerSize',2, 'LineWidth',0.3);

act = find(bPix ~= 0);
if ~isempty(act)
    w    = bPix(act);  amax = max(abs(w));
    sz   = 3 + 22*abs(w)/max(amax,eps);
    scatter(axA, P.dspGc(act), P.dspGr(act), sz, w, 'filled', ...
            'MarkerEdgeColor',[0.3 0.3 0.3], 'LineWidth',0.15);
    colormap(axA, supp_divmap());  clim(axA, [-amax amax]);
    cb = colorbar(axA); cb.FontSize = PS.fs; cb.FontWeight = PS.fw;
    cb.LineWidth = 0.5;  cb.Label.String = 'weight';
    cb.Label.FontSize = PS.fs; cb.Label.FontWeight = PS.fw;
    cb.Position = [0.815 0.18 0.035 0.62];
end
plot(axA, P.dspSc, P.dspSr, '+', 'Color',[0.90 0.10 0.10], 'MarkerSize',6, 'LineWidth',1.0);
text(axA, 0.02, 0.97, sprintf('%d predictors, %d excluded', numel(act), numel(exc)), ...
     'Units','normalized', 'FontSize',PS.fs, 'FontWeight',PS.fw, 'Color','w', ...
     'VerticalAlignment','top', 'HorizontalAlignment','left');
supp_export(figA, SUPP_OUTDIR, 'supp_res_A_predmap');

%% ================================================================================================
%  B  the model itself -- held-out spontaneous fit
%% ================================================================================================
yhat = P.muY + P.Zte*M.b;
nB   = min(600, numel(P.yte));
figB = paperFig(8.0, 3.0);
axB  = axes(figB,'Position',[0.10 0.20 0.87 0.72]); hold(axB,'on'); box(axB,'off');
plot(axB, 1:nB, P.yte(1:nB), '-', 'Color',COL_A, 'LineWidth',PS.lw_fit, 'DisplayName','actual (held out)');
plot(axB, 1:nB, yhat(1:nB),  '-', 'Color',COL_G, 'LineWidth',PS.lw_fit, 'DisplayName','contra prediction');
xlim(axB,[1 nB]);
% Headroom so the legend sits in cleared space rather than on top of the traces.
% Headroom at BOTH ends: the legend sits above the traces, the R^2 line below them.
ylB = [min([P.yte(1:nB); yhat(1:nB)]) max([P.yte(1:nB); yhat(1:nB)])];
ylim(axB, [ylB(1) - 0.26*diff(ylB), ylB(2) + 0.26*diff(ylB)]);
xlabel(axB,'held-out spontaneous frame'); ylabel(axB,'\DeltaF/F (%)');
lgB = legend(axB,'Location','northeast','Box','off','FontSize',PS.fs,'Orientation','horizontal');
try, lgB.ItemTokenSize = [6 6]; catch, end %#ok<CTCH>
% The shifted-target control is named, not abbreviated: it PASSES by going strongly NEGATIVE (the
% same weights scored against a time-shifted ipsi trace do worse than the mean), so a reader must
% not take "-0.96" for a failure to reach zero. The failure mode is a shift score near R^2 itself.
text(axB, 0.015, 0.03, sprintf('R^2 = %.3f   (shifted-target control %+.2f)', M.r2_spont, M.r2_shift), ...
     'Units','normalized','FontSize',PS.fs,'FontWeight',PS.fw,'VerticalAlignment','bottom');
supp_style(axB, PS);
supp_export(figB, SUPP_OUTDIR, 'supp_res_B_heldout');

%% ================================================================================================
%  C  Actual = Global + Local, trial-averaged: 3 amplitudes + the CATCH tile
%     Shared y across ALL FOUR tiles, catch included -- per-tile autoscaling makes a flat control
%     look like it has structure, which is the one thing this panel exists to rule out.
%% ================================================================================================
okA  = find(D.ampOK(:).');
assert(~isempty(okA), 'imp_supp_residual: no responding amplitudes.');
if numel(okA) >= 3
    pick = okA([1 round((1+numel(okA))/2) numel(okA)]);
else
    pick = okA;
end
nPick = numel(pick);

allv = [];
for ai = pick
    allv = [allv; D.trA{ai}(:); D.trG{ai}(:); D.trL{ai}(:)]; %#ok<AGROW>
end
allv = [allv; D.catch.trA(:); D.catch.trG(:); D.catch.trL(:)];
yl   = [min(allv) max(allv)];  yl = yl + 0.08*diff(yl)*[-1 1];
xlC  = [-0.4 0.8];

figC = paperFig(11.0, 3.6);
TC   = tiledlayout(figC, 1, nPick+1, 'TileSpacing','compact', 'Padding','compact');
for ii = 1:nPick
    ai = pick(ii);
    ax = nexttile(TC); hold(ax,'on'); box(ax,'off');
    supp_tile(ax, tt, D.trA{ai}, D.trG{ai}, D.trL{ai}, preN, yl, xlC, COL_A, COL_G, COL_L, PS);
    % Title kept to the amplitude alone -- with 4 narrow tiles a "(n=..)" suffix runs into the
    % neighbouring title. Trial counts go in the corner, where they cannot collide.
    title(ax, sprintf('%.1f V', D.amps(ai)), 'FontSize',PS.fs,'FontWeight',PS.fw);
    text(ax, 0.04, 0.05, sprintf('n=%d', D.nT_amp(ai)), 'Units','normalized', ...
         'FontSize',PS.fs, 'FontWeight',PS.fw, 'VerticalAlignment','bottom');
    if ii == 1
        ylabel(ax,'\DeltaF/F (%)');
    else
        set(ax,'YTickLabel',[]);
    end
    supp_style(ax, PS);
end
axCt = nexttile(TC); hold(axCt,'on'); box(axCt,'on');
supp_tile(axCt, tt, D.catch.trA, D.catch.trG, D.catch.trL, preN, yl, xlC, COL_A, COL_G, COL_L, PS);
set(axCt,'YTickLabel',[], 'XColor',[0.15 0.45 0.15], 'YColor',[0.15 0.45 0.15], 'LineWidth',0.8);
title(axCt, {'CATCH 0 V', sprintf('n=%d, %.0f%% of stim Local', D.catch.nT, 100*D.catch.ratio)}, ...
      'FontSize',PS.fs,'FontWeight',PS.fw,'Color',[0.15 0.45 0.15]);
% The legend lives in the CATCH tile: it is the only tile that is flat by construction, so it is
% the one place three sample lines can sit without covering data.
lgC = legend(axCt, {'Actual','Global','Local'}, 'Location','south','Box','off','FontSize',PS.fs);
try, lgC.ItemTokenSize = [6 6]; catch, end %#ok<CTCH>
supp_style(axCt, PS);
set(axCt,'XColor',[0.15 0.45 0.15], 'YColor',[0.15 0.45 0.15]);
xlabel(TC,'time from laser onset (s)','FontSize',PS.fs,'FontWeight',PS.fw);
supp_export(figC, SUPP_OUTDIR, 'supp_res_C_agl');

%% ================================================================================================
%  D  dose curves for the three components
%% ================================================================================================
figD = paperFig(5.5, 4.0);
axD  = axes(figD,'Position',[0.22 0.20 0.74 0.74]); hold(axD,'on'); box(axD,'off');
plot(axD, D.amps, D.Adip, '-o','Color',COL_A,'LineWidth',PS.lw_fit,'MarkerFaceColor',COL_A, ...
     'MarkerSize',2.5,'DisplayName','Actual');
plot(axD, D.amps, D.Gdip, '-s','Color',COL_G,'LineWidth',PS.lw_fit,'MarkerFaceColor',COL_G, ...
     'MarkerSize',2.5,'DisplayName','Global (leak)');
plot(axD, D.amps, D.Ldip, '-^','Color',COL_L,'LineWidth',PS.lw_fit,'MarkerFaceColor',COL_L, ...
     'MarkerSize',2.5,'DisplayName','Local (residual)');
bad = ~D.ampOK(:).';
if any(bad)
    plot(axD, D.amps(bad), D.Adip(bad), 'o','Color',[0.55 0.55 0.55],'MarkerSize',5, ...
         'LineWidth',0.6,'DisplayName','no response');
end
yline(axD, 0, ':', 'Color',[0.4 0.4 0.4], 'LineWidth',PS.lw_zero, 'HandleVisibility','off');
% The 0-200 ms window is the locked project definition of inhibition energy; it goes in the caption
% rather than the axis, where at 6 pt "0-200" reads as a decimal point.
xlabel(axD,'laser amplitude (V)'); ylabel(axD,'inhibition energy (\DeltaF/F %)');
lgD = legend(axD,'Location','southwest','Box','off','FontSize',PS.fs);
try, lgD.ItemTokenSize = [6 6]; catch, end %#ok<CTCH>
supp_style(axD, PS);
supp_export(figD, SUPP_OUTDIR, 'supp_res_D_dose');

%% ================================================================================================
%  E  decomposition quality -- capture / leak / |catch| against the 15% catch threshold
%% ================================================================================================
figE = paperFig(4.0, 4.0);
axE  = axes(figE,'Position',[0.26 0.16 0.70 0.78]); hold(axE,'on'); box(axE,'off');
vals = [D.capMed, D.leakMed, 100*abs(D.catch.ratio)];
bh = bar(axE, 1:3, vals, 0.6, 'FaceColor','flat', 'EdgeColor','none');
bh.CData = [COL_L; COL_G; 0.45 0.45 0.45];
yline(axE, 15, '--', 'Color',[0.15 0.45 0.15], 'LineWidth',PS.lw_ref, 'HandleVisibility','off');
text(axE, 3.92, 15, 'catch threshold', 'FontSize',PS.fs,'FontWeight',PS.fw, ...
     'Color',[0.15 0.45 0.15], 'HorizontalAlignment','right','VerticalAlignment','bottom');
for k = 1:3
    text(axE, k, vals(k)+3, sprintf('%.0f', vals(k)), 'FontSize',PS.fs,'FontWeight',PS.fw, ...
         'HorizontalAlignment','center');
end
set(axE,'XTick',1:3,'XTickLabel',{'capture','leak','|catch|'});
xlim(axE,[0.4 3.95]); ylim(axE,[0 max(105, max(vals)*1.15)]);
ylabel(axE,'% of Actual dip');
supp_style(axE, PS);
supp_export(figE, SUPP_OUTDIR, 'supp_res_E_quality');

%% ================================================================================================
%  F/G  state-dependence of the LOCAL residual, with the GLOBAL negative control.
%
%  The test is  partialcorr(DV_zWithinAmp, state | dev_pre)  [Spearman] -- the SAME test f2_state
%  runs, so the numbers printed on these panels are the pipeline's own. The scatter is the matching
%  added-variable (partial-regression) plot: BOTH axes are rank-transformed and residualised on
%  dev_pre, so the Pearson slope of what is drawn IS the reported partial Spearman rho. Plotting
%  raw DV against raw state would show a cloud whose slope is not the quoted statistic.
%
%  The GLOBAL component gets the identical treatment with a DV-matched statistic. Global is the
%  ongoing network activity and SHOULD track state; a Local effect that merely resembles the Global
%  one is leakage, not a local finding. On AL_0033 that is exactly what motion does.
%% ================================================================================================
ST = D.ST;
assert(~isempty(ST) && ~isempty(ST.LD), 'imp_supp_residual: no per-trial state payload (need wantTraces=true).');
zf   = @(x)(x - mean(x,'omitnan'))./max(std(x,'omitnan'), eps);
dvL  = ST.(SUPP_DV);
dvG  = supp_globaldv(ST.trG, D.dcc, SUPP_DV);
ctrl = zf(ST.PRE);

% field | console label (full) | axis label (SHORT -- a 5.5 cm panel at 6 pt cannot carry the full
% band definition, which belongs in the caption) | output filename
STATES = { 'MOT', 'motion (z)',                        'motion',              'supp_res_F_motion'
           'DPr', 'relative \delta (2-4 / 0.4-10 Hz)', 'rel. \delta (2-4 Hz)', 'supp_res_G_reldelta' };

fprintf('\n[SUPP-RES] state-dependence of the LOCAL residual (DV = %s), n=1 session\n', SUPP_DV);
for k = 1:size(STATES,1)
    st  = zf(ST.(STATES{k,1}));
    okL = isfinite(dvL) & isfinite(st) & isfinite(ctrl);
    okG = isfinite(dvG) & isfinite(st) & isfinite(ctrl);
    [rL, pL] = partialcorr(dvL(okL), st(okL), ctrl(okL), 'type','Spearman','rows','complete');
    [rG, pG] = partialcorr(dvG(okG), st(okG), ctrl(okG), 'type','Spearman','rows','complete');
    fprintf('   %-34s Local rho=%+.3f p=%.3g  |  Global control rho=%+.3f p=%.3g  (n=%d)\n', ...
            STATES{k,2}, rL, pL, rG, pG, nnz(okL));

    [xL, yL] = supp_partialrank(st(okL), dvL(okL), ctrl(okL));
    [xG, yG] = supp_partialrank(st(okG), dvG(okG), ctrl(okG));

    fh = paperFig(5.5, 4.0);
    ax = axes(fh,'Position',[0.20 0.19 0.76 0.75]); hold(ax,'on'); box(ax,'off');
    scatter(ax, xL, yL, 2, COL_L, 'filled', 'MarkerFaceAlpha',0.25, 'HandleVisibility','off');
    [bxL, byL, seL] = supp_bin(xL, yL, 6);
    [bxG, byG, ~  ] = supp_bin(xG, yG, 6);
    errorbar(ax, bxL, byL, seL, '-o', 'Color',COL_L, 'MarkerFaceColor',COL_L, 'MarkerSize',2.5, ...
             'LineWidth',PS.lw_fit, 'CapSize',2, 'DisplayName','Local (residual)');
    plot(ax, bxG, byG, '--s', 'Color',COL_G, 'MarkerFaceColor',COL_G, 'MarkerSize',2.5, ...
         'LineWidth',PS.lw_fit, 'DisplayName','Global (control)');
    yline(ax, 0, ':', 'Color',[0.4 0.4 0.4], 'LineWidth',PS.lw_zero, 'HandleVisibility','off');
    xlim(ax, [-0.55 0.55]); ylim(ax, [-0.62 0.78]);   % fractional rank; headroom for the legend
    set(ax,'XTick',-0.5:0.25:0.5, 'YTick',-0.5:0.25:0.5);
    xlabel(ax, sprintf('%s | dev_{pre}  (partial rank)', STATES{k,3}));
    ylabel(ax, sprintf('%s | dev_{pre}', supp_dvlabel(SUPP_DV)));
    lg = legend(ax,'Location','north','Box','off','FontSize',PS.fs,'Orientation','horizontal');
    try, lg.ItemTokenSize = [6 6]; catch, end %#ok<CTCH>
    text(ax, 0.97, 0.03, sprintf('Local \\rho=%+.2f, p=%.2g\nGlobal \\rho=%+.2f  (n=%d)', ...
         rL, pL, rG, nnz(okL)), 'Units','normalized', 'FontSize',PS.fs, 'FontWeight',PS.fw, ...
         'HorizontalAlignment','right', 'VerticalAlignment','bottom');
    supp_style(ax, PS);
    supp_export(fh, SUPP_OUTDIR, STATES{k,4});
end

fprintf('\n[SUPP-RES] panels written to %s\n', SUPP_OUTDIR);

%% ------------------------------------------------------------------------------------------------
%  local helpers
%% ------------------------------------------------------------------------------------------------
function supp_tile(ax, tt, a, g, r, preN, yl, xl, cA, cG, cL, PS)
% One Actual/Global/Local tile, baseline-subtracted over the pre-window so the three traces start
% together and the comparison is about the response, not the resting offset.
bl = @(v) v(:) - mean(v(1:max(preN,1)));
plot(ax, tt, bl(a), '-', 'Color',cA, 'LineWidth',PS.lw_mean);
plot(ax, tt, bl(g), '-', 'Color',cG, 'LineWidth',PS.lw_fit);
plot(ax, tt, bl(r), '-', 'Color',cL, 'LineWidth',PS.lw_fit);
xline(ax, 0, ':', 'Color',[0.4 0.4 0.4], 'LineWidth',PS.lw_zero);
yline(ax, 0, ':', 'Color',[0.4 0.4 0.4], 'LineWidth',PS.lw_zero);
xlim(ax, xl); ylim(ax, yl);
end

function supp_style(ax, PS)
set(ax, 'FontSize',PS.fs, 'FontWeight',PS.fw, 'TickDir','out', 'LineWidth',0.5, 'Layer','top');
end

function supp_export(fh, outdir, name)
% Vector PDF, cropped to content. Cropping (not a locked PaperSize) is the project default since
% 2026-09-29 -- a locked page silently clipped panel titles.
f = fullfile(outdir, [name '.pdf']);
exportgraphics(fh, f, 'ContentType','vector');
fprintf('   -> %s\n', f);
end

function gd = supp_globaldv(tr, dcc, dv)
% The Global control DV must MIRROR the Local DV or it is not a control (RESEARCH 2026-08-12: with
% a signed Global against an unsigned Local, every control looked reassuringly small; matched, the
% motion control on AL_0033 is LARGER than Local and the effect is revealed as network-wide).
gd = [];
for ai = 1:numel(tr)
    G = tr{ai};  if isempty(G), continue; end
    dc = dcc{ai};  if isempty(dc), dc = 1:size(G,1); end
    Gd = G(dc,:);  mu = mean(Gd, 2);
    switch upper(dv)
        case 'L1DEVZ', v = mean(abs(Gd - mu), 1).';
        case 'GAINZ',  v = (Gd.'*mu) / max(mu.'*mu, eps);
        otherwise,     v = mean(Gd, 1).';
    end
    gd = [gd; (v - mean(v,'omitnan'))./max(std(v,'omitnan'),eps)]; %#ok<AGROW>
end
end

function [xr, yr] = supp_partialrank(x, y, c)
% Added-variable coordinates for a partial SPEARMAN: rank-transform all three, then residualise x
% and y on c. corr(xr,yr) (Pearson) then equals partialcorr(x,y,c,'type','Spearman').
% Divided by n so the axes read as FRACTIONAL rank (about -0.5..+0.5) instead of raw rank counts,
% which put a meaningless "500" on a paper axis and change meaning with trial count.
n  = numel(x);
rx = tiedrank(x(:)); ry = tiedrank(y(:)); rc = tiedrank(c(:));
Z  = [ones(numel(rc),1), rc];
xr = (rx - Z*(Z\rx)) / n;
yr = (ry - Z*(Z\ry)) / n;
end

function [bx, by, bse] = supp_bin(x, y, nb)
% Equal-count bins along x; mean +/- SEM of y in each. Equal-count (not equal-width) because the
% state markers are heavy-tailed -- equal-width bins put almost every trial in one bin.
x = x(:); y = y(:);
q = [-inf; quantile(x, (1:nb-1)/nb).'; inf];
bx = nan(nb,1); by = nan(nb,1); bse = nan(nb,1);
for i = 1:nb
    m = x > q(i) & x <= q(i+1);
    if nnz(m) < 3, continue; end
    bx(i) = mean(x(m)); by(i) = mean(y(m)); bse(i) = std(y(m))/sqrt(nnz(m));
end
ok = isfinite(bx); bx = bx(ok); by = by(ok); bse = bse(ok);
end

function s = supp_dvlabel(dv)
switch upper(dv)
    case 'L1DEVZ', s = 'Local |deviation|';
    case 'GAINZ',  s = 'Local template gain';
    otherwise,     s = 'Local dip';
end
end

function cm = supp_divmap()
% Blue-white-red diverging map for the signed predictor weights.
n = 128;
lo = [0.10 0.40 0.85]; hi = [0.85 0.20 0.20]; mid = [1 1 1];
cm = [interp1([0 1],[lo; mid],linspace(0,1,n)); interp1([0 1],[mid; hi],linspace(0,1,n))];
end
