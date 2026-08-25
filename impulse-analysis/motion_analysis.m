% impulse-analysis -- extracted from Impulse_mouseDataAnalysis_all.m
% Run from impulse-analysis/ directory.
% Requires: load_experiments.m has been run first (allExperiments, selExp, t_win).

PS = paperStyle();
setPaperDefaults();

assert(isfolder('../paper'), ...
    'Run from impulse-analysis/ directory (current: %s)', pwd);

%% Motion analysis parameters â€” set integration window here before running analysis sections
% Motion energy is recomputed on-the-fly from the stored motTrace (Â±3 s).
% Change motWin_ana / motThr_lo / motThr_hi; both sections below will use them.

motWin_ana     = [-1.0, 0.5];   % [start, end] in seconds relative to stim onset
motThr_lo      = -0.5;          % mean z-score: Low | Mid boundary
motThr_hi      =  0.5;          % mean z-score: Mid | High boundary
tertertColors_motot = [0.20 0.40 0.80;   % Low  â€” blue
                  0.55 0.25 0.75;   % Mid  â€” purple
                  0.85 0.20 0.20];  % High â€” red
tLabels_m      = {'Low motion', 'Mid motion', 'High motion'};

% TWO PARALLEL STREAMS — set which deviation signal Y is:
%   'peakdev' = |Peak_imp - mean(Peak_imp)| per amp (ORIGINAL: deviation from
%               trial-averaged response). Always available.
%   'cperr'   = CP-4 per-trial prediction error (contra-pred + TF route). Needs
%               archive/contra_prediction.m to have run (populates imp.cp_err).
%               That script is ARCHIVED (2026-08-25) -- restore it to use this metric;
%               otherwise this route falls back to 'peakdev' (guard below).
% Output filenames are tagged with the stream so the two never overwrite.
if ~exist('dev_metric','var'), dev_metric = 'cperr'; end   % 'peakdev' | 'cperr'
dev_tag = dev_metric;
% ---- SILENT-FALLBACK GUARD (added 2026-08-12) --------------------------------------------------
% imp.cp_err is populated by archive/contra_prediction.m (ARCHIVED) and is ABSENT in a plain run.
% The per-amp plotting guards below are `isfield(imp_e,'cp_err') && ...`, so with dev_metric='cperr'
% and no such field every plot silently falls back to Peak_imp_dev -- while dev_tag stays 'cperr'
% and dev_ylabel stays 'Prediction error'. The result is a figure labelled and FILENAMED as a
% prediction error that actually shows peak deviation, which reached paper panel 2F. Detect it here
% and downgrade the tag/label to what is really being plotted, loudly.
if strcmp(dev_metric,'cperr')
    haveCP = false;
    for iChk = 1:numel(allExperiments)
        if isfield(allExperiments(iChk).imp,'cp_err') && ~isempty(allExperiments(iChk).imp.cp_err)
            haveCP = true; break
        end
    end
    if ~haveCP
        warning('motion_analysis:cperrMissing', ...
          ['dev_metric=''cperr'' but imp.cp_err is absent (run archive/contra_prediction.m, now ARCHIVED).\n' ...
           '         FALLING BACK to peakdev -- tag and axis label corrected so the export is not mislabelled.']);
        dev_metric = 'peakdev';  dev_tag = 'peakdev';
    end
end
% expColors normally comes from dose_response.m (runs earlier in run_all); guard
% so motion_analysis can also run standalone.
if ~exist('expColors','var'), expColors = PS.sess; end   % colorblind-safe when global PAPER_CB=true
dev_ylabel = 'Prediction error';
if strcmp(dev_metric,'peakdev'), dev_ylabel = 'Peak dev (\DeltaF/F %)'; end
% ---- SIGNED deviation (user, 2026-08-12) -------------------------------------------------------
% Was |Peak_imp - mean(Peak_imp)|. The absolute value threw away the DIRECTION of each trial's
% departure from its amplitude mean, so a trial that was inhibited more than average and one that
% was inhibited less were plotted at the same height. Now signed:
%   dev = Peak_imp - mean(Peak_imp)     > 0  SHALLOWER dip than average (LESS inhibition)
%                                       < 0  DEEPER    dip than average (MORE inhibition)
% Computed from Peak_imp here rather than read from imp.Peak_imp_dev, because that field is ABS in
% load_experiments.m (line 355) but SIGNED in load_bilateral_impulse.m (line 224) and therefore does
% not mean one thing across sessions. See RESEARCH 2026-08-12.
devSigned = @(v) v(:) - mean(v(:), 'omitnan');

%% Motion vs Peak_imp deviation â€” one figure per session, subplots per amp
%
% X: mean z-scored motion over motWin_ana (comparable across sessions)
% Y: |Peak_imp âˆ’ mean(Peak_imp)| for that amp group  (imp.Peak_imp_dev)
% Dots coloured by Low/Mid/High using motThr_lo / motThr_hi from parameter cell.
% Click any dot â†’ motionDetailCallback opens dF/F + motion trace for that trial.

nExp      = numel(allExperiments);
t_win_mot = -tWin : 1/35 : tWin;   % full Â±3 s â€” matches dfImp / motTrace column count
iMot_a    = t_win_mot >= motWin_ana(1) & t_win_mot <= motWin_ana(2);

for expIdx = 1:nExp
    imp_e  = allExperiments(expIdx).imp;
    nAmp_e = numel(imp_e.uAmp);
    if nAmp_e == 0, continue; end

    % Compute shared x/y limits across all amps for this experiment
    xAll_m = []; yAll_m = [];
    for iA = 1:nAmp_e
        xAll_m = [xAll_m; mean(imp_e.motTrace{iA}(:, iMot_a), 2)]; %#ok<AGROW>
        if strcmp(dev_metric,'cperr') && isfield(imp_e, 'cp_err') && ~isempty(imp_e.cp_err{iA})
            yAll_m = [yAll_m; imp_e.cp_err{iA}(:)];              %#ok<AGROW>
        else
            yAll_m = [yAll_m; devSigned(imp_e.Peak_imp{iA})];     %#ok<AGROW>
        end
    end
    xAll_m = xAll_m(isfinite(xAll_m)); yAll_m = yAll_m(isfinite(yAll_m));
    xPad   = 0.05 * (max(xAll_m) - min(xAll_m));
    % SIGNED dev -> the y-axis must span both directions and be centred on 0, or the sign is
    % invisible. Symmetric limits so "deeper" and "shallower" are read off the same scale.
    yMax_m = max(abs(yAll_m));  yPad = 0.05 * yMax_m;
    xLim_m = [min(xAll_m) - xPad,  max(xAll_m) + xPad];
    yLim_m = [-(yMax_m + yPad),    yMax_m + yPad];

    nCols_m = min(nAmp_e, 4);
    nRows_m = ceil(nAmp_e / nCols_m);

    fig_m = figure('Color','w');
    fig_m.Units    = 'inches';
    fig_m.Position = [1, 1, nCols_m*3, nRows_m*3];
    sgtitle(sprintf('%s  %s  e%d  [click dot for detail]', allExperiments(expIdx).mn, ...
        allExperiments(expIdx).td, allExperiments(expIdx).en), ...
        'FontWeight','bold', 'FontSize', 10, 'Interpreter','none');

    for iAmp = 1:nAmp_e
        if strcmp(dev_metric,'cperr') && isfield(imp_e, 'cp_err') && ~isempty(imp_e.cp_err{iAmp})
            dev_i = imp_e.cp_err{iAmp}(:);
        else
            dev_i = devSigned(imp_e.Peak_imp{iAmp});              % SIGNED (see header)
        end
        nUse   = min(size(imp_e.motTrace{iAmp}, 1), numel(dev_i));
        if nUse < 2, continue; end
        mot_i  = mean(imp_e.motTrace{iAmp}(1:nUse, iMot_a), 2);
        dev_i  = dev_i(1:nUse);
        tert_i = 1 + (mot_i >= motThr_lo) + (mot_i > motThr_hi);

        ax = subplot(nRows_m, nCols_m, iAmp);
        hold(ax, 'on');
        hAll = gobjects(0);
        for k = 1:3
            mk = tert_i == k;
            if ~any(mk), continue; end
            hS = scatter(ax, mot_i(mk), dev_i(mk), 25, tertertColors_motot(k,:), ...
                'filled', 'MarkerFaceAlpha', 0.6, 'DisplayName', tLabels_m{k});
            hAll(end+1) = hS;
        end

        yline(ax, 0, 'k:', 'HandleVisibility','off');   % 0 = amp-average dip; sign is the point now
        r = corr(mot_i, dev_i, 'rows','complete');
        title(ax, sprintf('%.2f V   (n=%d,  r=%.2f)', imp_e.uAmp{iAmp}, nUse, r), ...
            'FontSize', 8, 'FontWeight','bold');
        xlabel(ax, sprintf('Mean motion z-score (%.1f to %.1f s)', motWin_ana(1), motWin_ana(2)), 'FontSize', 8);
        ylabel(ax, dev_ylabel, 'FontSize', 8);
        lg = legend(ax, 'Box','off', 'FontSize', 7, 'Location','best');
        lg.ItemTokenSize = [6 6];
        set(ax, 'Box','off', 'TickDir','out', 'FontSize', 8);
        xlim(ax, xLim_m);
        ylim(ax, yLim_m);

        % Capture per-iteration values for the closure
        c_ax   = ax;
        c_mot  = mot_i;
        c_dev  = dev_i;
        c_imp  = imp_e;
        c_iAmp = iAmp;
        c_twin = t_win_mot;
        for hh = hAll
            set(hh, 'ButtonDownFcn', ...
                @(~,~) motionDetailCallback(c_ax, c_mot, c_dev, c_imp, c_iAmp, c_twin));
        end
    end
end

%% Motion-sorted figures â€” pooled amps, session selExp_mot
%
% Figure 1: trials sorted by motion (Y), |Peak_imp âˆ’ mean| (X), two classes.
% Figure 2: mean motion z-score (X) vs |Peak_imp âˆ’ mean| (Y), two classes.
%
% Classification: No motion (mean z â‰¤ motThr_hi) vs Motion (mean z > motThr_hi).
% motThr_hi is set in the parameters cell above.

selExp_mot = 3;

imp_e_mot  = allExperiments(selExp_mot).imp;
nAmp_mot   = numel(imp_e_mot.uAmp);
mn_mot     = allExperiments(selExp_mot).mn;
td_mot     = allExperiments(selExp_mot).td;
en_mot     = allExperiments(selExp_mot).en;

t_full_mot = -tWin : 1/35 : tWin;
iMot_a     = t_full_mot >= motWin_ana(1) & t_full_mot <= motWin_ana(2);
iCrop_new  = find(t_full_mot >= -2 & t_full_mot <= 2);   % for legacy pool loop

binColors_m = [0.30 0.55 0.85; 0.85 0.20 0.20];   % No motion â€” blue; Motion â€” red
binLabels_m = {'No motion', 'Motion'};

% --- Pooled data prep ---
allAbsDev_m = [];
allMot_m    = [];

for iAmp = 1:nAmp_mot
    nUse = min([size(imp_e_mot.dfImp{iAmp}, 1), size(imp_e_mot.motTrace{iAmp}, 1)]);
    if nUse < 2, continue; end
    mot_i = mean(imp_e_mot.motTrace{iAmp}(1:nUse, iMot_a), 2);
    if strcmp(dev_metric,'cperr') && isfield(imp_e_mot, 'cp_err') && ~isempty(imp_e_mot.cp_err{iAmp})
        dev_i = imp_e_mot.cp_err{iAmp}(1:nUse);
    else
        pk_i  = imp_e_mot.Peak_imp{iAmp}(:);
        mn_i  = mean(pk_i, 'omitnan');
        dev_i = pk_i(1:nUse) - mn_i;                 % SIGNED (see header)
    end
    allAbsDev_m = [allAbsDev_m; dev_i];   %#ok<AGROW>
    allMot_m    = [allMot_m;    mot_i];   %#ok<AGROW>
end

[~, si_m]      = sort(allMot_m, 'ascend');
absDevSorted_m = allAbsDev_m(si_m);
motSorted_m    = allMot_m(si_m);

motBin_m     = (allMot_m    > motThr_hi) + 1;   % 1 = No motion, 2 = Motion
motBinSort_m = (motSorted_m > motThr_hi) + 1;

% --- Legacy pool loop (used by poster figure and pre-trial variance sections) ---
allDF_n   = [];
allMot_n  = [];
ampIdx_n  = [];
devNorm_n = [];
for iAmp = 1:nAmp_mot
    df_i  = imp_e_mot.dfImp{iAmp};
    pk_i  = imp_e_mot.Peak_imp{iAmp}(:);
    mn_i  = imp_e_mot.Peak_imp_mean(iAmp);
    if isnan(mn_i) || mn_i == 0, continue; end
    nUse  = min([size(df_i, 1), numel(pk_i), size(imp_e_mot.motTrace{iAmp}, 1)]);
    mot_i = mean(imp_e_mot.motTrace{iAmp}(1:nUse, iMot_a), 2);
    allDF_n   = [allDF_n;   df_i(1:nUse, iCrop_new) / abs(mn_i)];  %#ok<AGROW>
    allMot_n  = [allMot_n;  mot_i];                                  %#ok<AGROW>
    ampIdx_n  = [ampIdx_n;  repmat(iAmp, nUse, 1)];                 %#ok<AGROW>
    % SIGNED numerator, |mn_i| denominator: mn_i is a negative dip, so dividing by its magnitude
    % scales without flipping the sign that now carries the direction.
    devNorm_n = [devNorm_n; (pk_i(1:nUse) - mn_i) / abs(mn_i)];     %#ok<AGROW>
end

% ---- Figure 1: trial rank (sorted by motion) vs |Peak dev| ----
[rA_m, pA_m] = corr(allMot_m, allAbsDev_m, 'rows', 'complete');

fig_ad = paperFig(6, 6);
ax_ad  = axes(fig_ad);
hold(ax_ad, 'on');
for k = 1:2
    mk = motBinSort_m == k;
    scatter(ax_ad, absDevSorted_m(mk), find(mk), 6, ...
        binColors_m(k, :), 'filled', 'MarkerFaceAlpha', 0.6, ...
        'DisplayName', binLabels_m{k});
end
hl_a0 = xline(ax_ad, 0, 'k-', 'LineWidth', 0.5); hl_a0.HandleVisibility = 'off';
title(ax_ad, sprintf('r = %.2f  p = %.3f', rA_m, pA_m), ...
    'FontSize', 6, 'FontWeight', 'bold');
xlabel(ax_ad, 'Peak dev (\DeltaF/F %)',  'FontSize', 6, 'FontWeight', 'bold');
ylabel(ax_ad, sprintf('Trial (sorted by motion, %.1f to %.1f s)', motWin_ana(1), motWin_ana(2)), ...
    'FontSize', 6, 'FontWeight', 'bold');
lg_ad = legend(ax_ad, 'Location', 'best', 'FontSize', 6);
lg_ad.ItemTokenSize = [6 6];
set(ax_ad, 'Box', 'off', 'TickDir', 'out', 'FontSize', 6, 'YDir', 'normal');
hold(ax_ad, 'off');

% ---- Figure 2: mean motion z-score vs |Peak dev| scatter ----
fig_mv = paperFig(6, 4);
ax_mv  = axes(fig_mv);
hold(ax_mv, 'on');
for k = 1:2
    mk = motBin_m == k;
    scatter(ax_mv, allMot_m(mk), allAbsDev_m(mk), 6, ...
        binColors_m(k, :), 'filled', 'MarkerFaceAlpha', 0.5, ...
        'DisplayName', binLabels_m{k});
end
hl_mv = xline(ax_mv, motThr_hi, 'k--', 'LineWidth', 0.8); hl_mv.HandleVisibility = 'off';
% title(ax_mv, sprintf('r = %.2f  p = %.3f', rA_m, pA_m), ...
    % 'FontSize', 6, 'FontWeight', 'bold');
xlabel(ax_mv, sprintf('Mean motion z-score (%.1f to %.1f s)', motWin_ana(1), motWin_ana(2)), 'FontSize', 6, 'FontWeight', 'bold');
ylabel(ax_mv, dev_ylabel,  'FontSize', 6, 'FontWeight', 'bold');
lg_mv = legend(ax_mv, 'Location', 'best');
paperLegend(lg_mv);
hold(ax_mv, 'off');
paperExport(fig_mv, ...
    fullfile(paperRoot, 'images', 'supplementary', sprintf('imp_motion_devscatter_%s_%s_%s_en%d.png', dev_tag, mn_mot, td_mot, en_mot)));

% ---- Figure 2 (pooled all sessions): motion z-score vs |Peak dev| ----
% colour = session (expColors); marker = o no-motion, ^ motion
allAbsDev_pool = [];
allMot_pool    = [];
allExp_pool    = [];

for expIdx = 1:nExp
    imp_e_p  = allExperiments(expIdx).imp;
    nAmp_p   = numel(imp_e_p.uAmp);
    for iAmp = 1:nAmp_p
        nUse = min([size(imp_e_p.dfImp{iAmp}, 1), size(imp_e_p.motTrace{iAmp}, 1)]);
        if nUse < 2, continue; end
        mot_i = mean(imp_e_p.motTrace{iAmp}(1:nUse, iMot_a), 2);
        if strcmp(dev_metric,'cperr') && isfield(imp_e_p, 'cp_err') && ~isempty(imp_e_p.cp_err{iAmp})
            dev_i = imp_e_p.cp_err{iAmp}(1:nUse);
        else
            pk_i  = imp_e_p.Peak_imp{iAmp}(:);
            mn_i  = mean(pk_i, 'omitnan');
            dev_i = pk_i(1:nUse) - mn_i;                 % SIGNED (see header)
        end
        allAbsDev_pool = [allAbsDev_pool; dev_i];                   %#ok<AGROW>
        allMot_pool    = [allMot_pool;    mot_i];                    %#ok<AGROW>
        allExp_pool    = [allExp_pool;    repmat(expIdx, nUse, 1)];  %#ok<AGROW>
    end
end

[rP, pP]    = corr(allMot_pool, allAbsDev_pool, 'rows', 'complete');
motBin_pool = (allMot_pool > motThr_hi) + 1;   % 1=No motion, 2=Motion

% shuffle so no session dominates by draw order
rng(0);
shufIdx        = randperm(numel(allMot_pool));
allMot_s       = allMot_pool(shufIdx);
allAbsDev_s    = allAbsDev_pool(shufIdx);
allExp_s       = allExp_pool(shufIdx);
motBin_s       = motBin_pool(shufIdx);

% Session is encoded by COLOUR (sequential gradient PS.sessGrad -> ordered and
% colourblind-safe); a single pooled trend line carries the motion->error trend.
% Session colour indexed by SESSION NUMBER (PS.sessColor), so session k is the same shade
% here as in 2C-i and the TF panels. PS.sessGrad(nExp) re-sampled the ramp to whatever nExp
% this run had, which recoloured sessions 1-3 the moment AL_0048 was added as the 4th.
gradC = PS.sess;

% Per-session min-max normalise motion to [0,1] (replaces the z-score: motion
% energy is a positive quantity, so a 0-1 scale is more intuitive; doing it
% per-session preserves cross-session comparability the way the z-score did).
motN_s = nan(size(allMot_s));
for e = unique(allExp_s).'
    m  = allExp_s == e;
    lo = min(allMot_s(m));  hi = max(allMot_s(m));
    if hi > lo,  motN_s(m) = (allMot_s(m) - lo) ./ (hi - lo);
    else,        motN_s(m) = 0;  end
end

fig_mvp = paperFig(PS.f2w, PS.f2h);   % 2F -- Fig-2 grid (see paperStyle f2w/f2h)
ax_mvp  = axes(fig_mvp);
hold(ax_mvp, 'on');

% ONE scatter call for all points, drawn in the SHUFFLED order, with per-point colour
% (user, 2026-08-12: "make sure that s4 dots are not necessarily on the top hiding all the
% other dots, lets randomize some"). The rows were already shuffled above, but the drawing
% loop then grouped them BY SESSION and painted session 1 first and session 4 last, so the
% whole of the newest session sat on top of the other three and the shuffle bought nothing.
% Interleaving the points is the only way the overlap reads honestly.
vS  = isfinite(motN_s) & isfinite(allAbsDev_s) & allExp_s >= 1 & allExp_s <= nExp;
scatter(ax_mvp, motN_s(vS), allAbsDev_s(vS), 8, gradC(allExp_s(vS),:), ...
    'o', 'filled', 'MarkerFaceAlpha', 0.5, ...
    'MarkerEdgeColor', 'none', 'HandleVisibility', 'off');
hLeg_p = gobjects(nExp, 1);
for expIdx = 1:nExp
    if ~any(allExp_s == expIdx), continue; end
    hLeg_p(expIdx) = plot(ax_mvp, nan, nan, 'o', 'MarkerFaceColor', gradC(expIdx,:), ...
        'MarkerEdgeColor', 'none', 'MarkerSize', 4, ...
        'DisplayName', sprintf('Session %d', expIdx));
end

% NO trend line on this panel (user, 2026-08-17: "i dont need a linear fit shown its not the
% result"). Correct, and worth stating: a line through a SIGNED deviation is a test of the
% MEAN, and the mean deviation is flat by construction (dev is taken about the amplitude
% mean) -- r = 0.003, p = 0.89. Drawing it invited the reader to look for a slope that cannot
% exist and distracted from what the panel does show, which is the funnel NARROWING with
% motion. The scale claim lives in 2J. r is still computed and printed for the record.
okFit = ~isnan(motN_s) & ~isnan(allAbsDev_s);
[rN, pN] = corr(motN_s(okFit), allAbsDev_s(okFit), 'rows', 'complete');
fprintf('[motion] 2F pooled signed-dev trend (NOT drawn): r=%.3f p=%.3f\n', rN, pN);

xlim(ax_mvp, [-0.03 1.03]);
% SIGNED dev: the old clamp `max(yl(1),-2)` assumed a floor at 0 and would CLIP real negative
% (deeper-than-average) trials. Use symmetric limits about 0 so both directions are visible.
yMax_p = max(abs(allAbsDev_s(okFit)));
ylim(ax_mvp, [-1.05*yMax_p, 1.05*yMax_p]);
hz_mvp = yline(ax_mvp, 0, 'k:', 'LineWidth', 0.5); hz_mvp.HandleVisibility = 'off';
xlabel(ax_mvp, sprintf('Normalized motion, 0-1 (%.1f to %.1f s)', motWin_ana(1), motWin_ana(2)), ...
    'FontSize', 6, 'FontWeight', 'bold');
ylabel(ax_mvp, dev_ylabel, 'FontSize', 6, 'FontWeight', 'bold');
lg_mvp = legend(ax_mvp, hLeg_p(isgraphics(hLeg_p)), 'Location', 'northeast');
paperLegend(lg_mvp);
hold(ax_mvp, 'off');
paperExport(fig_mvp, ...
    fullfile(paperRoot, 'images', 'figure2', sprintf('imp_motion_devscatter_all_sessions_%s%s.pdf', dev_tag, PS.cbtag)));


%% Prediction error vs motion z-score — all sessions, all amps, threshold = 1.5
motThr_15    = 1.5;
colLo15      = [0.25 0.50 0.85];   % blue  — below threshold
colHi15      = [0.85 0.20 0.20];   % red   — above threshold

% use finite pairs only
vP15 = isfinite(allMot_pool) & isfinite(allAbsDev_pool);
mot15  = allMot_pool(vP15);
dev15  = allAbsDev_pool(vP15);
bin15  = mot15 > motThr_15;        % true = high motion

[r15, p15] = corr(mot15, dev15, 'rows', 'complete');
nLo15 = sum(~bin15);  nHi15 = sum(bin15);
fprintf('[motion] All sessions pooled  n=%d  r=%.3f  p=%.4f\n', numel(mot15), r15, p15);
fprintf('[motion] Below z=1.5: %d trials  |  Above z=1.5: %d trials\n', nLo15, nHi15);

fig_15 = paperFig(6, 4);
ax_15  = axes(fig_15);
hold(ax_15, 'on');
scatter(ax_15, mot15(~bin15), dev15(~bin15), 6, colLo15, 'filled', ...
    'MarkerFaceAlpha', 0.45, 'MarkerEdgeColor', 'none', ...
    'DisplayName', sprintf('z \\leq 1.5  (n=%d)', nLo15));
scatter(ax_15, mot15( bin15), dev15( bin15), 6, colHi15, 'filled', ...
    'MarkerFaceAlpha', 0.55, 'MarkerEdgeColor', 'none', ...
    'DisplayName', sprintf('z > 1.5  (n=%d)', nHi15));
xl15 = xline(ax_15, motThr_15, 'k--', 'LineWidth', 0.8);
xl15.HandleVisibility = 'off';
hz15 = yline(ax_15, 0, 'k:', 'LineWidth', 0.5); hz15.HandleVisibility = 'off';
ylim(ax_15, [-1.05 1.05]*max(abs(dev15)));      % symmetric: sign is the point
hold(ax_15, 'off');
set(ax_15, 'Box', 'off', 'TickDir', 'out', 'FontSize', 6, 'FontWeight', 'bold');
xlabel(ax_15, sprintf('Motion z-score (%.1f to %.1f s)', motWin_ana(1), motWin_ana(2)), ...
    'FontSize', 6, 'FontWeight', 'bold');
ylabel(ax_15, dev_ylabel, 'FontSize', 6, 'FontWeight', 'bold');
title(ax_15, sprintf('All sessions · all amps  r=%.3f  p=%.4f', r15, p15), ...
    'FontSize', 6, 'FontWeight', 'bold');
lg_15 = legend(ax_15, 'Location', 'best');
paperLegend(lg_15);
paperExport(fig_15, ...
    fullfile(paperRoot, 'images', 'figure2', sprintf('imp_motion_pred_err_thr15_%s.png', dev_tag)));
