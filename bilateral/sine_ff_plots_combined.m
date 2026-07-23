% bilateral/sine_ff_plots_combined.m
% Feedforward sine-wave section — panels in analysisPlots_combined.m style.
% 4 mode columns (OL | OL+prev | CL | CL+prev) instead of the OL|CL pair.
%
% Panel lettering follows PAPER.md "Fig 5" (2026-07-21). Letters run in LOGICAL
% order; the physical top row of the assembled figure is A, E, F.
%
%   paper/images/figure5/sine_5B_single_trial_<sfx>.pdf   – single trial     (12.5 x 3.5)
%   paper/images/figure5/sine_5C_trialavg_<sfx>.pdf       – trials + average (12.5 x 3.5) +/-std
%   paper/images/figure5/sine_5D_trialavg_input_<sfx>.pdf – avg 638 input mW (12.5 x 3.5) +/-std
%   paper/images/figure5/sine_5E_rmse_time_<sfx>.pdf      – RMSE over time   (5.2 x 4)   +/-SEM
%   paper/images/figure5/sine_5F_variance_<sfx>.pdf       – variance vs time (5.2 x 4)
%   paper/images/figure5/sine_5G_rmse_violin_<sfx>.pdf    – trial RMSE violin(4.2 x 5.4)
%   paper/images/figure5/sine_5H_phase_lag_<sfx>.pdf      – PHASE LAG (deg)  (4.2 x 5.4)
%   (5A = system schematic, drawn in Illustrator — not produced here.)
%
% Style delegated to paperStyle / setPaperDefaults / paperAxes / paperLegend.
% Requires: load_bilateral.m has been run (`sessions` in workspace).
% Fits (total 17, gap 0.3): row1 5A+5E+5F = 6+5.2+5.2+0.6 = 17.0 OK
%                           row2 col1(12.5) + col2(4.2) + 0.3 = 17.0 OK
% Col1 (5B/5C/5D) shares one time base: only 5D carries a labelled time bar.
% ERROR METRIC = RMSE (sqrt of mean squared error), matching the Fig 3 decision.

%% ---- Knobs -------------------------------------------------------------
SESSION_TAG = 's2';        % s1 = AL_0048 2026-07-01/6 (87 tr); s2 = 2026-07-14/1 (200 tr, Fig 5 primary); s3 = 2026-07-21/1 (198 sine tr, pixel_R=[407 367]; preview REPLICATES, OL-vs-CL ns p=0.36)
SIDE        = 'right';
PRE         = 2;           % s before onset
POST        = 2;           % s after trajectory end
EX_TRIAL    = 6;           % which trial (within mode) for the single-trial panel
INP_SCALE   = 2;           % scale on the 638 command (mW) so it reads on the dF/F axis
RMSE_CLIP_P = 95;          % 5G y-limit percentile (s2 has heavy motion outliers)
EXPORT      = true;        % paper panels -> vector PDF
EXPORT_PNG  = true;        % also mirror each panel as a 300-dpi PNG (figure4/png/)
PREVIEW_DIR = '';          % non-empty -> also drop 200-dpi PNG previews there
                           % (quick visual check; PDFs remain the deliverable)
% -------------------------------------------------------------------------
prev = @(f, nm) preview_png(f, PREVIEW_DIR, nm);

close all   % clear leftover panels: a stale figure stack makes the OS clamp the
            % short 4-cm-tall panels, distorting their rasterised PNG export
PS = paperStyle();
setPaperDefaults();

sess = sessions.(SESSION_TAG);
d = sess.d; dFoF = sess.(SIDE).dFoF; sn = sess.sine;
sfx = sprintf('%s_%s_%d', sess.mn, sess.td, sess.en);
fs = 35; dur = sn.dur;

if exist(fullfile('paper','images'), 'dir')
    paper_root = 'paper';
elseif exist(fullfile('..','paper','images'), 'dir')
    paper_root = fullfile('..','paper');
else
    paper_root = 'paper';
end
outDir = fullfile(paper_root, 'images', 'figure5');
if EXPORT && ~exist(outDir,'dir'); mkdir(outDir); end
pngDir = fullfile(outDir, 'png');
if EXPORT && EXPORT_PNG && ~exist(pngDir,'dir'); mkdir(pngDir); end

MODE_CODES  = [2 1 3 0];
MODE_LABELS = {'Open-Loop', 'OL + Preview', 'Closed-Loop', 'CL + Preview'};
MODE_SHORT  = {'OL', 'OL+p', 'CL', 'CL+p'};   % compact labels for 5G / 5H ticks
% Per-mode colour code (2026-07-23): OL=red, OL+prev=orange, CL=blue,
% CL+prev=green (the green CL used to be). Order matches MODE_CODES [2 1 3 0].
MODE_COLS   = [1.00 0.00 0.00;    % OL       red
               1.00 0.55 0.25;    % OL+prev  orange
               0.00 0.40 0.85;    % CL       blue
               0.00 0.50 0.00];   % CL+prev  green
COL_INP     = MODE_COLS;   % input command uses each mode's own colour (2026-07-23)
nMode = numel(MODE_CODES);

nPre = round(PRE*fs); nPost = round((dur+POST)*fs);
T    = (-nPre : nPost) / fs;          % trace time axis
Tref = (0 : round(dur*fs)) / fs;      % reference axis
x1 = 0; x2 = dur;

%% ---- Gather traces / refs / inputs per mode ---------------------------
[tt, v] = getTLanalog(sess.mn, sess.td, sess.en, 'lightCommand638');
% Volts -> mW using the rig calibration in force on the session date. The 638
% V->mW slope changed 3.5x between the two sessions' calibrations, so the raw
% command is not comparable across sessions and must not be plotted as Volts.
[v, calib] = laser_v2mw(v, sess.td, 638);
fprintf('%s: 638 calib %s (%.2f mW at 3 V)\n', sfx, calib.date, laser_v2mw(3, sess.td, 638));
traces = cell(1,nMode); refs = cell(1,nMode); inps = cell(1,nMode);
rmseV  = cell(1,nMode); nTr = zeros(1,nMode);
sideMask = strcmp({sess.trial_meta.side}, SIDE);
for m = 1:nMode
    trials = [sess.trial_meta(([sess.trial_meta.ff_cond]==MODE_CODES(m)) & sideMask).trial_idx];
    for j = 1:numel(trials)
        i0 = sess.onset_idx(trials(j));
        if isnan(i0) || i0-nPre < 1 || i0+nPost > numel(dFoF); continue; end
        if i0+round(dur*fs) > numel(sess.ref_raw); continue; end
        traces{m} = [traces{m}; dFoF(i0-nPre : i0+nPost)];
        Rj = sn.ref0 - sess.ref_raw(i0 : i0+round(dur*fs)).';   % right/inhibitory: negative
        refs{m}   = [refs{m}; Rj(:)'];
        inps{m}   = [inps{m}; interp1(tt, v, d.timeBlue(i0)+T, 'linear', 0)];
        seg = dFoF(i0 : i0+round(dur*fs));
        % RMSE, not MSE — sample-normalised root-mean-square error, matching the
        % Fig 3 project-wide decision (2026-07-16). sqrt is monotone, so every
        % rank-based stat (Wilcoxon) is unchanged; only magnitudes/units differ.
        rmseV{m}  = [rmseV{m}; sqrt(mean((seg(:) - Rj(:)).^2))];
    end
    nTr(m) = size(traces{m},1);
end
refPlot = mean(cell2mat(refs(:)), 1);

%% ---- Shared 4-column layout (normalised) ------------------------------
% PW is the col1 width from PAPER.md Fig 5 (12.5 cm, ~2/3 of the 17 cm measure).
% Positions below are normalised, so narrowing PW narrows each mode sub-column
% proportionally (~2.9 cm per mode at 12.5).
PW = 12.5;
lm = 0.05; rm = 0.01; cg = 0.02;
cW  = (1 - lm - rm - 3*cg) / 4;
cL  = lm + (0:3)*(cW + cg);

%% 5B: single trial (col1 row1) -------------------------------------------
fig_A = paperFig(PW, 3.5);
bm = 0.12; tm = 0.12; axH = 1 - bm - tm;
axA = gobjects(1,nMode);
for m = 1:nMode
    axA(m) = axes(fig_A, 'Position', [cL(m), bm, cW, axH]); hold(axA(m),'on');
    plot(axA(m), T, zeros(size(T)), 'k', 'LineWidth', PS.lw_zero, 'HandleVisibility','off');
    k = min(EX_TRIAL, nTr(m));
    plot(axA(m), T, INP_SCALE*inps{m}(k,:), 'Color', COL_INP(m,:), ...
        'LineWidth', PS.lw_inp, 'HandleVisibility','off');
    plot(axA(m), T, traces{m}(k,:), 'Color', MODE_COLS(m,:), ...
        'LineWidth', PS.lw_mean, 'HandleVisibility','off');
    plot(axA(m), Tref, refPlot, '--k', 'LineWidth', PS.lw_ref, 'HandleVisibility','off');
    xline(axA(m), 0, 'HandleVisibility','off'); xline(axA(m), dur, 'HandleVisibility','off');
    ylim(axA(m), [-12 8]); xlim(axA(m), [-PRE dur+POST]);
    addStimPatch(axA(m), x1, x2);
    uistack(findobj(axA(m),'Type','line'), 'top'); hold(axA(m),'off');
    if m == 1
        % X arm unlabelled: 5D carries the time bar for the whole col1 stack
        paperAxes(axA(m), 'XLength',1, 'YLength',3, 'XLabel','', 'YLabel','3% dF/F');
    else
        paperAxes(axA(m));
    end
    text(axA(m), 0.5, 1.06, MODE_LABELS{m}, 'Units','normalized', ...
        'HorizontalAlignment','center', 'Clipping','off');
end
linkaxes(axA,'x');
if EXPORT; paperExport(fig_A, fullfile(outDir, sprintf('sine_5B_single_trial_%s.pdf', sfx)));
    if EXPORT_PNG; paperExport(fig_A, fullfile(pngDir, sprintf('sine_5B_single_trial_%s.png', sfx))); end; end
prev(fig_A, '5B');

%% 5C: all trials + average (col1 row2) -----------------------------------
fig_B = paperFig(PW, 3.5);
bm = 0.12; tm = 0.12; axH = 1 - bm - tm;
axB = gobjects(1,nMode); hLeg = gobjects(1,3);
for m = 1:nMode
    axB(m) = axes(fig_B, 'Position', [cL(m), bm, cW, axH]); hold(axB(m),'on');
    plot(axB(m), T, zeros(size(T)), 'k', 'LineWidth', PS.lw_zero, 'HandleVisibility','off');
    mu = mean(traces{m},1); sd = std(traces{m},0,1);
    fill(axB(m), [T fliplr(T)], [mu+sd fliplr(mu-sd)], MODE_COLS(m,:), ...
        'FaceAlpha', PS.fa, 'EdgeColor','none', 'HandleVisibility','off');
    h1 = plot(axB(m), T, mu, 'Color', MODE_COLS(m,:), 'LineWidth', PS.lw_mean);
    h2 = plot(axB(m), Tref, refPlot, '--k', 'LineWidth', PS.lw_ref);
    xline(axB(m), 0, 'HandleVisibility','off'); xline(axB(m), dur, 'HandleVisibility','off');
    ylim(axB(m), [-8 6]); xlim(axB(m), [-PRE dur+POST]);
    addStimPatch(axB(m), x1, x2);
    uistack(findobj(axB(m),'Type','line'), 'top'); hold(axB(m),'off');
    if m == 1
        % X arm unlabelled: 5D carries the time bar for the whole col1 stack
        paperAxes(axB(m), 'XLength',1, 'YLength',2, 'XLabel','', 'YLabel','2% dF/F');
        hLeg(1) = h1; hLeg(2) = h2;
    else
        paperAxes(axB(m));
    end
    text(axB(m), 0.5, 1.06, sprintf('%s (n=%d)', MODE_LABELS{m}, nTr(m)), ...
        'Units','normalized', 'HorizontalAlignment','center', 'Clipping','off');
end
lgd = legend(axB(1), [hLeg(1) hLeg(2)], {'mean \pm std','Ref'}, 'Orientation','horizontal');
paperLegend(lgd); lgd.Units = 'normalized';
lgd.Position(2) = 0.01; lgd.Position(1) = 0.5 - lgd.Position(3)/2;
linkaxes(axB,'x');
if EXPORT; paperExport(fig_B, fullfile(outDir, sprintf('sine_5C_trialavg_%s.pdf', sfx)));
    if EXPORT_PNG; paperExport(fig_B, fullfile(pngDir, sprintf('sine_5C_trialavg_%s.png', sfx))); end; end
prev(fig_B, '5C');

%% 5D: average inputs (col1 row3 — carries the shared time axis) ----------
fig_C = paperFig(PW, 3.5);
bm = 0.15; tm = 0.08; axH = 1 - bm - tm;
axC = gobjects(1,nMode);
for m = 1:nMode
    axC(m) = axes(fig_C, 'Position', [cL(m), bm, cW, axH]); hold(axC(m),'on');
    plot(axC(m), T, zeros(size(T)), 'k', 'LineWidth', PS.lw_zero, 'HandleVisibility','off');
    mu = mean(inps{m},1); sd = std(inps{m},0,1);
    fill(axC(m), [T fliplr(T)], [mu+sd fliplr(mu-sd)], COL_INP(m,:), ...
        'FaceAlpha', PS.fa, 'EdgeColor','none', 'HandleVisibility','off');
    plot(axC(m), T, mu, 'Color', COL_INP(m,:), 'LineWidth', PS.lw_mean, 'HandleVisibility','off');
    xline(axC(m), 0, 'HandleVisibility','off'); xline(axC(m), dur, 'HandleVisibility','off');
    ylim(axC(m), [-0.5 3]); xlim(axC(m), [-PRE dur+POST]);
    addStimPatch(axC(m), x1, x2);
    uistack(findobj(axC(m),'Type','line'), 'top'); hold(axC(m),'off');
    if m == 1
        paperAxes(axC(m), 'XLength',1, 'YLength',1, 'XLabel','1 s', 'YLabel','1 mW');
    else
        paperAxes(axC(m));
    end
end
linkaxes(axC,'x');
if EXPORT; paperExport(fig_C, fullfile(outDir, sprintf('sine_5D_trialavg_input_%s.pdf', sfx)));
    if EXPORT_PNG; paperExport(fig_C, fullfile(pngDir, sprintf('sine_5D_trialavg_input_%s.png', sfx))); end; end
prev(fig_C, '5D');

%% 5E: RMSE over time (row1) ----------------------------------------------
% Per-timepoint squared error is averaged across trials (mean +/- SEM), then the
% mean and both band edges are sqrt'd so the axis reads in RMSE (dF/F) units.
% sqrt is monotone, so the band still brackets the same trials -- but it becomes
% ASYMMETRIC after the transform, which is correct, not a bug.
nRef  = round(dur*fs);
fig_RM = paperFig(5.2, 4);
lmE = 0.17; rmE = 0.05; bmE = 0.14; tmE = 0.08;
ax_rm = axes(fig_RM, 'Position', [lmE, bmE, 1-lmE-rmE, 1-bmE-tmE]); hold(ax_rm,'on');
for m = 1:nMode
    E   = (traces{m}(:, nPre+1 : nPre+1+nRef) - refs{m}).^2;
    mu  = mean(E,1);  sem = std(E,0,1)/sqrt(size(E,1));
    lo  = sqrt(max(mu-sem, 0));  hi = sqrt(mu+sem);
    fill(ax_rm, [Tref fliplr(Tref)], [hi fliplr(lo)], MODE_COLS(m,:), ...
        'FaceAlpha', PS.fa, 'EdgeColor','none', 'HandleVisibility','off');
    plot(ax_rm, Tref, sqrt(mu), 'Color', MODE_COLS(m,:), 'LineWidth', PS.lw_mean, ...
        'DisplayName', MODE_LABELS{m});
end
xlim(ax_rm, [0 dur]); hold(ax_rm,'off');
% No in-panel legend: at 5.2 cm it lands on top of the traces. The mode colour key
% is carried by the 5B/5C column titles in the assembled figure.
text(ax_rm, -0.13, 0.5, 'RMSE (% dF/F)', 'Units','normalized', 'Rotation',90, ...
    'HorizontalAlignment','center', 'VerticalAlignment','middle', ...
    'FontSize',PS.fs, 'FontWeight',PS.fw, 'Color','k', 'Clipping','off');
paperAxes(ax_rm, 'XLength',1, 'YLength',2, 'XLabel','1 s', 'YLabel','2');
% Early-vs-late split behind claim (c): which modes improve within the trial?
iE = Tref <= 1;  iL = Tref > 1;
fprintf('\n[5E] RMSE early (0-1 s) -> late (1-%g s), per mode:\n', dur);
for m = 1:nMode
    E  = (traces{m}(:, nPre+1 : nPre+1+nRef) - refs{m}).^2;
    rE = sqrt(mean(mean(E(:,iE),1)));  rL = sqrt(mean(mean(E(:,iL),1)));
    fprintf('   %-14s %6.3f -> %6.3f  (%+.3f)%s\n', MODE_LABELS{m}, rE, rL, rL-rE, ...
        repmat('  <- falls', 1, rL < rE));
end
if EXPORT; paperExport(fig_RM, fullfile(outDir, sprintf('sine_5E_rmse_time_%s.pdf', sfx)));
    if EXPORT_PNG; paperExport(fig_RM, fullfile(pngDir, sprintf('sine_5E_rmse_time_%s.png', sfx))); end; end
prev(fig_RM, '5E');

%% 5F: variance over time (row1) ------------------------------------------
fig_D = paperFig(5.2, 4);
lm2 = 0.13; rm2 = 0.05; bm2 = 0.12; tm2 = 0.08;
ax_var = axes(fig_D, 'Position', [lm2, bm2, 1-lm2-rm2, 1-bm2-tm2]); hold(ax_var,'on');
for m = 1:nMode
    plot(ax_var, T, var(traces{m},0,1), 'Color', MODE_COLS(m,:), 'LineWidth', PS.lw_mean);
end
xline(ax_var, 0, 'LineWidth', PS.lw_zero, 'HandleVisibility','off');
xline(ax_var, dur, 'LineWidth', PS.lw_zero, 'HandleVisibility','off');
xlim(ax_var, [-PRE dur+POST]);
addStimPatch(ax_var, x1, x2);
uistack(findobj(ax_var,'Type','line'), 'top'); hold(ax_var,'off');
paperAxes(ax_var, 'XLength',1, 'YLength',10, 'XLabel','1 s', 'YLabel','10');
text(ax_var, -0.12, 0.5, 'Variance across trials', 'Units','normalized', 'Rotation',90, ...
    'HorizontalAlignment','center', 'VerticalAlignment','middle', 'Color','k', 'Clipping','off');
if EXPORT; paperExport(fig_D, fullfile(outDir, sprintf('sine_5F_variance_%s.pdf', sfx)));
    if EXPORT_PNG; paperExport(fig_D, fullfile(pngDir, sprintf('sine_5F_variance_%s.png', sfx))); end; end
prev(fig_D, '5F');

%% 5G: trial RMSE half-violin (col2 row1) ---------------------------------
fig_E = paperFig(4.2, 5.4);
lm2e = 0.13; rm2e = 0.05; bm2e = 0.15; tm2e = 0.10;
ax_mse = axes(fig_E, 'Position', [lm2e, bm2e, 1-lm2e-rm2e, 1-bm2e-tm2e]); hold(ax_mse,'on');
hw = 0.34;
% Robust y-limit: the RMSE tail is dominated by a few motion trials, which
% otherwise compress every violin to a sliver. Axis is CLIPPED (density is still
% estimated on the full data); state this in the caption.
allRmse = cell2mat(rmseV(:));
rmseTop = prctile(allRmse, RMSE_CLIP_P);
nClip   = sum(allRmse > rmseTop);
for m = 1:nMode
    if nTr(m) < 2; continue; end
    [fk, yk] = ksdensity(rmseV{m}); fk = fk/max(fk)*hw;
    fill(ax_mse, [m-fk, m*ones(size(fk))], [yk, fliplr(yk)], MODE_COLS(m,:), ...
        'FaceAlpha', PS.fa, 'EdgeColor','none', 'HandleVisibility','off');
    plot(ax_mse, m+0.12, mean(rmseV{m}), '*', 'Color', MODE_COLS(m,:), ...
        'MarkerSize', 4, 'LineWidth', 0.75, 'HandleVisibility','off');
end
xlim(ax_mse, [0.4 nMode+0.6]); ylim(ax_mse, [0 rmseTop]);
hold(ax_mse,'off');
fprintf('[5G] RMSE axis clipped at p%d = %.2f (%d/%d trials above, off-axis)\n', ...
    RMSE_CLIP_P, rmseTop, nClip, numel(allRmse));
% Wilcoxon rank-sum on the paper contrasts. RMSE is a monotone transform of MSE,
% so these p-values are IDENTICAL to the ones computed on MSE.
try
    pOLCL = ranksum(rmseV{1}, rmseV{3});
    pOLpv = ranksum(rmseV{1}, rmseV{2});
    fprintf('[5G] OL vs CL p=%.4g  |  OL vs OL+prev p=%.4g\n', pOLCL, pOLpv);
catch ME_rs
    fprintf('[5G] ranksum unavailable: %s\n', ME_rs.message);
end
text(ax_mse, -0.12, 0.5, 'Trial RMSE (% dF/F)', 'Units','normalized', 'Rotation',90, ...
    'HorizontalAlignment','center', 'VerticalAlignment','middle', 'Color','k', 'Clipping','off');
% Mode labels under each violin — without these the four are only distinguishable
% by colour, which does not survive greyscale printing.
for m = 1:nMode
    text(ax_mse, m, -0.02*rmseTop, MODE_SHORT{m}, 'HorizontalAlignment','center', ...
        'VerticalAlignment','top', 'FontSize',PS.fs, 'FontWeight',PS.fw, 'Clipping','off');
end
% Y scale bar: paperAxes(ax) alone strips every tick, leaving the RMSE axis with
% no readable scale. X arm is unlabelled (the x axis is categorical).
paperAxes(ax_mse, 'XLength',0.5, 'YLength',2, 'XLabel','', 'YLabel','2');
if EXPORT; paperExport(fig_E, fullfile(outDir, sprintf('sine_5G_rmse_violin_%s.pdf', sfx)));
    if EXPORT_PNG; paperExport(fig_E, fullfile(pngDir, sprintf('sine_5G_rmse_violin_%s.png', sfx))); end; end
prev(fig_E, '5G');

%% 5H: PHASE LAG by mode (col2 row2) --------------------------------------
% 1 Hz fundamental fit of mean response vs mean reference. Dashed grey line =
% the preview lookahead (previewT_steps / fs), which OL's lag should match.
Xf   = [ones(numel(Tref),1), sin(2*pi*sn.hz*Tref).', cos(2*pi*sn.hz*Tref).'];
fAmp = @(y) hypot([0 1 0]*(Xf\y(:)), [0 0 1]*(Xf\y(:)));
fPh  = @(y) atan2([0 0 1]*(Xf\y(:)), [0 1 0]*(Xf\y(:)));
lags = nan(1,nMode); gains = nan(1,nMode);
iRef = (nPre+1) : (nPre+1+round(dur*fs));
for m = 1:nMode
    mu = mean(traces{m}(:, iRef),1); mr = mean(refs{m},1);
    lg_ = mod(fPh(mr)-fPh(mu)+pi, 2*pi)-pi;      % wrapped phase diff, radians
    lags(m)  = lg_*180/pi;                        % report as phase in degrees
    gains(m) = fAmp(mu)/fAmp(mr);
end
% preview lookahead as an equivalent phase at the drive frequency (deg)
prevLook = 360 * sn.hz * sess.d.input_params(find([sess.trial_meta.ff_cond]>=0,1), 8) / fs;

fig_F = paperFig(4.2, 5.4);
% wide left margin: this is the only small panel with a numeric y-axis, so the
% tick labels + ylabel must fit inside the figure box or raster export clips them
lm2f = 0.30; rm2f = 0.05; bm2f = 0.20; tm2f = 0.08;
ax_ph = axes(fig_F, 'Position', [lm2f, bm2f, 1-lm2f-rm2f, 1-bm2f-tm2f]); hold(ax_ph,'on');
for m = 1:nMode
    bar(ax_ph, m, lags(m), 0.6, 'FaceColor', MODE_COLS(m,:), ...
        'FaceAlpha', 0.75, 'EdgeColor','none');
end
yline(ax_ph, 0, 'k-', 'LineWidth', PS.lw_zero);
yline(ax_ph, prevLook, '--', 'Color', [0.5 0.5 0.5], 'LineWidth', PS.lw_ref);
text(ax_ph, nMode+0.55, prevLook, sprintf('preview %.0f\\circ', prevLook), ...
    'Color', [0.5 0.5 0.5], 'HorizontalAlignment','right', 'VerticalAlignment','bottom', ...
    'FontSize', PS.fs, 'Clipping','off');
hold(ax_ph,'off');
xlim(ax_ph, [0.4 nMode+0.6]);
ax_ph.XTick = 1:nMode; ax_ph.XTickLabel = MODE_SHORT;
ax_ph.XTickLabelRotation = 30;
ylabel(ax_ph, 'Phase lag (\circ)', 'FontSize', PS.fs, 'FontWeight', PS.fw);
set(ax_ph, 'Box','off', 'TickDir','out', 'FontSize', PS.fs, 'FontWeight', PS.fw);
if EXPORT; paperExport(fig_F, fullfile(outDir, sprintf('sine_5H_phase_lag_%s.pdf', sfx)));
    if EXPORT_PNG; paperExport(fig_F, fullfile(pngDir, sprintf('sine_5H_phase_lag_%s.png', sfx))); end; end
prev(fig_F, 'F');

fprintf('\n[%s] %s exp %d — n per mode: %s\n', SESSION_TAG, sess.td, sess.en, mat2str(nTr));
fprintf('gain: %s\nlag (deg): %s | preview lookahead = %.0f deg\n', ...
    mat2str(gains,3), mat2str(round(lags)), prevLook);
