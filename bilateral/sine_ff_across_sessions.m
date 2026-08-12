% bilateral/sine_ff_across_sessions.m
% Cross-session summary of the feedforward sine sessions (s1/s2/s3): three
% point-plots, each with the 4 modes on x and ONE point per session per mode.
%   sine_combined_rmse.pdf      – total RMSE over the stim window (% dF/F)
%   sine_combined_variance.pdf  – total across-trial variance over the window
%   sine_combined_phase.pdf     – 1 Hz phase lag (deg)
% Requires: load_bilateral.m has run (`sessions` with s1/s2/s3).
%
% n=3 sessions -> NO across-session significance test (Wilcoxon signed-rank
% cannot reach p<0.25 at n=3). These panels show DIRECTION + CONSISTENCY:
% each session is a point, paired across modes by a faint line; the bold bar
% is the across-session mean. Report within-session stats separately (5G).
% Metric definitions match sine_ff_plots_combined.m (raw dF/F vs sine ref,
% stim window 0..dur).

SESS_TAGS = {'s1','s2','s3'};
SIDE      = 'right';
fs        = 35;
% EXPORT / PREVIEW_DIR are preset-overridable: when the panels are placed in the
% Illustrator master the PDFs are LOCKED by Windows and paperExport throws
% "Permission denied". Preset EXPORT=false + PREVIEW_DIR to iterate on layout.
if ~exist('EXPORT','var')     || isempty(EXPORT); EXPORT = true; end
if ~exist('PREVIEW_DIR','var'); PREVIEW_DIR = ''; end

% ---- Drowsy/outlier flag = SEPARATE companion analysis (2026-07-28, Nick 2026-07-17.1)
% Per user 2026-07-28: the PRIMARY analysis (registered PDF panels + pooled
% stats) uses ALL trials — nothing is dropped. The drowsy flag is kept only as
% a SEPARATE companion split so we can report clean-vs-drowsy side by side,
% without deleting any trial from the headline numbers.
% A trial is flagged drowsy if its PRE-stim dF/F variance (window PRE_STIM_S
% before onset) exceeds  median + DROWSY_SD_MULT*SD  of that session's pre-stim
% variance distribution (pooled over all 4 modes — drowsiness is an animal
% state, not a mode property).
CLEAN_COMPANION = true;   % compute the separate clean-vs-drowsy companion split
DROWSY_SD_MULT  = 2.5;    % multiplier on SD above the session median (rule kept as-is)
PRE_STIM_S      = 2.0;    % pre-onset window (s) used for the variance flag
EXPORT_PNG_POOL = true;   % also export the pooled clean-RMSE bar as PNG

MODE_CODES  = [2 1 3 0];
MODE_SHORT  = {'OL','OL+p','CL','CL+p'};
MODE_COLS   = [1.00 0.00 0.00;    % OL       red
               1.00 0.55 0.25;    % OL+prev  orange
               0.00 0.40 0.85;    % CL       blue
               0.00 0.50 0.00];   % CL+prev  green
SESS_MARK   = 'o';                % same marker for every session (aligned vertically)
nS = numel(SESS_TAGS); nMode = numel(MODE_CODES);

PS = paperStyle(); setPaperDefaults();
if exist(fullfile('paper','images','figure5'),'dir'); outDir=fullfile('paper','images','figure5');
elseif exist(fullfile('..','paper','images','figure5'),'dir'); outDir=fullfile('..','paper','images','figure5');
else; outDir='.'; end

%% ---- Gather per-(session,mode) metrics, with drowsy-trial exclusion -----
RMSE = nan(nS,nMode); VARr = nan(nS,nMode); LAG = nan(nS,nMode); NT = nan(nS,nMode);
NTdrowsy = nan(nS,nMode);   % # trials flagged drowsy per (session,mode) (NOT dropped)
poolRMSE = cell(1,nMode);   % pooled ALL-trial per-trial RMSE across the 3 sessions (PRIMARY)
poolLAGf = cell(1,nMode);   % pooled ALL-trial per-trial xcorr lag (frames, +ve=response lags ref)
poolClean= cell(1,nMode);   % logical aligned to poolRMSE: true = pre-stim state clean (not drowsy)
preThr   = nan(1,nS);
for si = 1:nS
    s = sessions.(SESS_TAGS{si});
    dur = s.sine.dur; hz = s.sine.hz;
    nPre = round(2*fs); nR = round(dur*fs); nPreStim = round(PRE_STIM_S*fs);
    mlag = round(fs/hz/2);                       % xcorr search = +/- half drive period
    Tref = (0:nR)/fs;
    Xf = [ones(numel(Tref),1), sin(2*pi*hz*Tref).', cos(2*pi*hz*Tref).'];
    fPh = @(y) atan2([0 0 1]*(Xf\y(:)), [0 1 0]*(Xf\y(:)));
    sideMask = strcmp({s.trial_meta.side}, SIDE); fc = [s.trial_meta.ff_cond];
    dF = s.(SIDE).dFoF(:).'; rr = s.ref_raw(:).'; ref0 = s.sine.ref0;
    nGuard = max(nPre, nPreStim);

    % ---- pass 1: per-session pre-stim variance threshold (all sine modes) ----
    allTr = [s.trial_meta((fc>=0) & sideMask).trial_idx];
    pv = nan(1,numel(allTr));
    for j = 1:numel(allTr)
        i0 = s.onset_idx(allTr(j));
        if isnan(i0) || i0-nGuard<1 || i0+nR>numel(dF) || i0+nR>numel(rr); continue; end
        pv(j) = var(dF(i0-nPreStim:i0-1));
    end
    thr = median(pv,'omitnan') + DROWSY_SD_MULT*std(pv,'omitnan'); preThr(si) = thr;
    nFlag = sum(pv > thr); nEval = sum(~isnan(pv));
    fprintf('%s: preVar med=%.2f sd=%.2f thr=%.2f | %d/%d flagged drowsy (%.0f%%)\n', ...
        SESS_TAGS{si}, median(pv,'omitnan'), std(pv,'omitnan'), thr, nFlag, nEval, 100*nFlag/max(nEval,1));

    % ---- pass 2: per-mode metrics on ALL trials; drowsy flag recorded, NOT dropped ----
    for m = 1:nMode
        tr = [s.trial_meta((fc==MODE_CODES(m)) & sideMask).trial_idx];
        Tc = []; Rc = []; lagC = []; cleanM = [];
        for j = 1:numel(tr)
            i0 = s.onset_idx(tr(j));
            if isnan(i0) || i0-nGuard<1 || i0+nR>numel(dF) || i0+nR>numel(rr); continue; end
            T = dF(i0:i0+nR); R = ref0 - rr(i0:i0+nR);
            Tc = [Tc; T]; Rc = [Rc; R];                                   %#ok<AGROW>
            cleanM(end+1) = var(dF(i0-nPreStim:i0-1)) <= thr;             %#ok<AGROW>
            % per-trial phase lag via constrained cross-correlation (response vs
            % logged sine ref). Full-window xcorr of a periodic signal aliases by
            % whole periods, so the search is limited to +/- half a drive period.
            [c,lg] = xcorr(T-mean(T), R-mean(R), mlag, 'normalized');
            [~,ix] = max(c); lagC(end+1) = lg(ix);                        %#ok<AGROW>
        end
        NT(si,m)       = size(Tc,1);
        NTdrowsy(si,m) = sum(cleanM==0);
        if isempty(Tc); continue; end
        RMSE(si,m) = mean(sqrt(mean((Tc-Rc).^2, 2)));
        VARr(si,m) = mean(var(Tc, 0, 1));
        LAG(si,m)  = (mod(fPh(mean(Rc,1)) - fPh(mean(Tc,1)) + pi, 2*pi) - pi) * 180/pi;
        poolRMSE{m} = [poolRMSE{m}, sqrt(mean((Tc-Rc).^2, 2)).'];
        poolLAGf{m} = [poolLAGf{m}, lagC];
        poolClean{m}= [poolClean{m}, logical(cleanM)];
    end
    fprintf('%s n/mode=%s | drowsy-flagged/mode=%s (kept in primary)\n', SESS_TAGS{si}, ...
        mat2str(NT(si,:)), mat2str(NTdrowsy(si,:)));
end

%% ---- Draw one point-plot per metric -----------------------------------
metrics = {RMSE, VARr, LAG};
ylabs   = {'Trial RMSE', 'Across-trial variance', 'Phase lag'};
fnames  = {'sine_combined_rmse.pdf', 'sine_combined_variance.pdf', 'sine_combined_phase.pdf'};
% Short-corner-axis treatment (2026-08-12, user): 5I/5J/5K now match the rest of
% Fig 5 -- no box, no ticks, a single labelled y scale bar. X is CATEGORICAL, so
% its arm is suppressed (XLength 0) and the mode names are drawn as text under
% the points. Y bar length per panel, chosen to be a readable fraction of the
% spread, and labelled with its UNIT (a bare number was the complaint).
ybar    = {1, 5, 20};
ybarLab = {'1% \DeltaF/F', '5 (% \DeltaF/F)^2', '20\circ'};

for p = 1:3
    M = metrics{p};
    fig = paperFig(5.5, 4.5);
    lm=0.20; rm=0.04; bm=0.16; tm=0.06;
    ax = axes(fig, 'Position', [lm bm 1-lm-rm 1-bm-tm]); hold(ax,'on');

    if p == 3   % phase panel: zero reference line
        yline(ax, 0, 'k-', 'LineWidth', PS.lw_zero, 'HandleVisibility','off');
    end

    % faint paired lines: each session across the 4 modes (all at integer x)
    for si = 1:nS
        plot(ax, 1:nMode, M(si,:), '-', 'Color', [0.6 0.6 0.6 0.45], ...
            'LineWidth', 0.5, 'HandleVisibility','off');
    end
    % session points — same marker/colour per mode, aligned vertically at each x
    for m = 1:nMode
        plot(ax, m*ones(1,nS), M(:,m), SESS_MARK, 'MarkerSize', 4, ...
            'MarkerFaceColor', MODE_COLS(m,:), 'MarkerEdgeColor', 'none');
    end
    % across-session mean bar per mode
    for m = 1:nMode
        plot(ax, [m-0.22 m+0.22], mean(M(:,m),'omitnan')*[1 1], 'k-', ...
            'LineWidth', 1.5, 'HandleVisibility','off');
    end

    xlim(ax, [0.5 nMode+0.5]);
    % Pad y so the corner bar has room under the data; the mode names are drawn
    % BELOW the axis bottom (clipping off) so they never collide with the bar.
    yl = [min(M(:),[],'omitnan') max(M(:),[],'omitnan')];
    rng_ = diff(yl); if rng_ == 0; rng_ = 1; end
    yl = yl + [-1 1]*0.10*rng_;
    yl(1) = min(yl(1), yl(1));                  % keep bottom room for the y bar
    ylim(ax, [yl(1) - 0.10*rng_, yl(2)]);
    hold(ax,'off');
    % Corner axes: y bar only — x is CATEGORICAL, so its arm is suppressed.
    paperAxes(ax, 'XLength',0, 'YLength',ybar{p}, 'YLabel',ybarLab{p});
    text(ax, -0.22, 0.5, ylabs{p}, 'Units','normalized', 'Rotation',90, ...
        'HorizontalAlignment','center', 'VerticalAlignment','middle', 'Color','k', ...
        'FontSize', PS.fs, 'FontWeight', PS.fw, 'Clipping','off');
    % mode names as text (paperAxes strips the categorical tick labels)
    for m = 1:nMode
        text(ax, m, ax.YLim(1) - 0.02*diff(ax.YLim), MODE_SHORT{m}, ...
            'HorizontalAlignment','center', 'VerticalAlignment','top', ...
            'FontSize', PS.fs, 'FontWeight', PS.fw, 'Clipping','off');
    end
    if EXPORT; paperExport(fig, fullfile(outDir, fnames{p})); end
    preview_png(fig, PREVIEW_DIR, sprintf('5%c', 'H'+p));   % 5I / 5J / 5K
end

fprintf('\n=== across-session summary (rows s1/s2/s3, cols OL/OL+p/CL/CL+p) ===\n');
fprintf('ALL-TRIAL RMSE (PRIMARY):\n');   disp(RMSE);
fprintf('drowsy-flagged per (session,mode) [kept in primary]:\n'); disp(NTdrowsy);
fprintf('VARIANCE (all trials):\n');       disp(VARr);
fprintf('PHASE deg (fundamental fit, all trials):\n');disp(LAG);

%% ---- POOLED per-condition RMSE (mean +/- SD across ALL pooled trials) ------
% Trials pooled across the 3 sessions per mode (headline recompute, Nick
% 2026-07-17.1). PRIMARY = all trials (no drowsy drop). RMSE = sample-normalised
% root-mean-square error vs the logged sine, window 0..dur, per project naming.
fprintf('\n=== POOLED ALL-TRIAL per-trial RMSE (across %d sessions), mean +/- SD ===\n', nS);
poolMean = nan(1,nMode); poolSD = nan(1,nMode); poolN = nan(1,nMode);
for m = 1:nMode
    x = poolRMSE{m}; poolMean(m)=mean(x); poolSD(m)=std(x); poolN(m)=numel(x);
    fprintf('  %-5s n=%3d  RMSE = %.3f +/- %.3f  (median %.3f)\n', ...
        MODE_SHORT{m}, poolN(m), poolMean(m), poolSD(m), median(x));
end

%% ---- Per-trial PHASE LAG via cross-correlation (pooled, all trials) --------
fprintf('\n=== xcorr phase lag per mode (pooled all trials, +ve = response lags ref) ===\n');
lagMeanF = nan(1,nMode); lagMedF = nan(1,nMode);
for m = 1:nMode
    Lf = poolLAGf{m}; Ld = Lf/fs*360;    % frames -> deg at hz=1 (drive freq)
    lagMeanF(m)=mean(Lf); lagMedF(m)=median(Lf);
    fprintf('  %-5s lag = %.2f +/- %.2f frames = %.1f +/- %.1f deg (median %.1f fr / %.1f deg)\n', ...
        MODE_SHORT{m}, mean(Lf), std(Lf), mean(Ld), std(Ld), median(Lf), median(Lf)/fs*360);
end
% preview lag correction (expect ~5 frames / ~51 deg, matching previewT_steps)
dOL = lagMeanF(1)-lagMeanF(2); dCL = lagMeanF(3)-lagMeanF(4);
dOLm= lagMedF(1)-lagMedF(2);  dCLm= lagMedF(3)-lagMedF(4);
fprintf('Preview correction  OL->OL+p: mean %.2f fr (%.1f deg) | median %.1f fr (%.1f deg)\n', ...
    dOL, dOL/fs*360, dOLm, dOLm/fs*360);
fprintf('Preview correction  CL->CL+p: mean %.2f fr (%.1f deg) | median %.1f fr (%.1f deg)\n', ...
    dCL, dCL/fs*360, dCLm, dCLm/fs*360);

%% ---- Statistics across the 4 modes ----------------------------------------
% (a) Friedman repeated-measures (session = block, mode = treatment) on the
%     session-level ALL-TRIAL RMSE. n=3 sessions -> underpowered; direction only.
% (b) Kruskal-Wallis on pooled per-trial RMSE (descriptive; trials are NOT
%     independent subjects, so treat as effect-size evidence, not RM proof).
fprintf('\n=== stats across 4 modes (all trials) ===\n');
try
    [pF,tF] = friedman(RMSE, 1, 'off');
    fprintf('Friedman (n=%d sessions x %d modes): chi2=%.3f, p=%.4f  [underpowered at n=%d]\n', ...
        nS, nMode, tF{2,5}, pF, nS);
catch ME; fprintf('friedman failed: %s\n', ME.message); end
g = []; xall = [];
for m = 1:nMode; xall=[xall poolRMSE{m}]; g=[g m*ones(1,numel(poolRMSE{m}))]; end
[pKW,tKW] = kruskalwallis(xall, g, 'off');
fprintf('Kruskal-Wallis (pooled per-trial): chi2=%.3f, df=%d, p=%.4g\n', tKW{2,5}, tKW{2,3}, pKW);
fprintf('pairwise ranksum (pooled all trials): OL vs OL+p p=%.3g | CL vs CL+p p=%.3g | OL vs CL p=%.3g\n', ...
    ranksum(poolRMSE{1},poolRMSE{2}), ranksum(poolRMSE{3},poolRMSE{4}), ranksum(poolRMSE{1},poolRMSE{3}));

%% ---- [SINE-DROWSY] Separate companion: clean vs drowsy split (rule kept) ---
% Per user 2026-07-28: NOTHING is dropped from the primary analysis above. Here
% we split the SAME pooled trials by the drowsy flag and report clean-only vs
% drowsy-only side by side, purely as a companion robustness check.
cleanMean = nan(1,nMode); cleanSD = nan(1,nMode); cleanN = nan(1,nMode);
drowMean  = nan(1,nMode); drowSD  = nan(1,nMode); drowN  = nan(1,nMode);
if CLEAN_COMPANION
    fprintf('\n=== [companion] pooled RMSE split by pre-stim state (rule: median+%.1f*SD) ===\n', DROWSY_SD_MULT);
    for m = 1:nMode
        % BUGFIX 2026-08-12: poolClean accumulates as DOUBLE (the seed [] is a
        % 0x0 double, so the logical concat demotes), which made x(cm) index with
        % 0 and threw. This whole companion section — and the pooled summary bar
        % below it — had been dying here.
        x = poolRMSE{m}; cm = logical(poolClean{m});
        cleanMean(m)=mean(x(cm));  cleanSD(m)=std(x(cm));  cleanN(m)=sum(cm);
        drowMean(m) =mean(x(~cm)); drowSD(m) =std(x(~cm)); drowN(m) =sum(~cm);
        fprintf('  %-5s  all n=%3d %.3f | clean n=%3d %.3f+/-%.3f | drowsy n=%3d %.3f+/-%.3f\n', ...
            MODE_SHORT{m}, numel(x), mean(x), cleanN(m), cleanMean(m), cleanSD(m), ...
            drowN(m), drowMean(m), drowSD(m));
    end
end

%% ---- Summary bar: pooled RMSE, all trials (primary) + clean-only overlay ---
% Supplementary summary bar (PNG per project export rule — NOT a registered PDF
% panel; the 3 registered PDFs stay on ALL trials, unrefactored). Bars = pooled
% ALL-trial mean, whisker = +/-SD, session means overlaid; clean-only companion
% mean drawn as an open diamond for comparison.
figP = paperFig(5.5, 4.5);
lm=0.20; rm=0.04; bm=0.16; tm=0.08;
axP = axes(figP, 'Position', [lm bm 1-lm-rm 1-bm-tm]); hold(axP,'on');
for m = 1:nMode
    bar(axP, m, poolMean(m), 0.6, 'FaceColor', MODE_COLS(m,:), 'FaceAlpha', 0.75, 'EdgeColor','none');
    plot(axP, [m m], poolMean(m)+[-1 1]*poolSD(m), 'k-', 'LineWidth', 1.0);
    plot(axP, m+0.28*ones(1,nS), RMSE(:,m), 'o', 'MarkerSize', 3, ...
        'MarkerFaceColor', [0.35 0.35 0.35], 'MarkerEdgeColor','none');
    if CLEAN_COMPANION && ~isnan(cleanMean(m))
        plot(axP, m-0.28, cleanMean(m), 'd', 'MarkerSize', 4, ...
            'MarkerEdgeColor','k', 'MarkerFaceColor','none', 'LineWidth', 0.8);
    end
end
xlim(axP, [0.5 nMode+0.5]);
axP.XTick = 1:nMode; axP.XTickLabel = MODE_SHORT; axP.XTickLabelRotation = 30;
ylabel(axP, 'Pooled trial RMSE (% dF/F)', 'FontSize', PS.fs, 'FontWeight', PS.fw);
set(axP, 'Box','off', 'TickDir','out', 'FontSize', PS.fs, 'FontWeight', PS.fw);
% \diamond is not in MATLAB's tex subset — it threw a SceneNode warning and the
% title rendered truncated. Spelled out instead.
title(axP, 'Pooled RMSE: all trials (bar) + clean-only (open marker)', ...
    'FontSize', PS.fs, 'FontWeight', PS.fw);
if EXPORT_PNG_POOL
    exportgraphics(figP, fullfile(outDir, 'sine_rmse_pooled_all_with_clean.png'), 'Resolution', 300);
    fprintf('\nExported PNG: %s\n', fullfile(outDir, 'sine_rmse_pooled_all_with_clean.png'));
end
