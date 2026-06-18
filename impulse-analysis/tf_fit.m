% impulse-analysis -- extracted from Impulse_mouseDataAnalysis_all.m
% Run from impulse-analysis/ directory.
% Requires: load_experiments.m has been run first (allExperiments, selExp, t_win).

%%
%% =========================================================
%  TF FIT â€” all amplitudes, session mean
%  Knobs: selExp, nPoles (1 or 2), nLeads (0 or 1)
%  nLeads=1 adds one numerator zero â†’ response can start at t=0
%  (more responsive / faster onset)
%% =========================================================

selExp   = 3;        % <-- target session
maxPoles = 3;        % <-- sweep 1..maxPoles
maxZeros = 3;        % <-- sweep 0..min(np-1, maxZeros)
maxDelay = 0;        % <-- sweep 0..maxDelay samples (~0..143 ms at 35 Hz)
tFit_s   = 0.5;     % <-- post-stim fit window end (s); increase for strong-amp tails
fig_A_amps_mW = [0, 0.7, 1.63];  % <-- mW values to plot in Fig A; [] = auto (smallest/mid/largest)

DF_s   = allExperiments(selExp).DF_imp;
uA_s   = allExperiments(selExp).uAmp(:);
nAmp_s = numel(uA_s);

% Post-stim fit window: 0 to tFit_s (set above; use tWin for full available range)
t_full = -tWin : 1/fs : tWin;
iPost  = find(t_full >= 0 & t_full <= tFit_s);
tPost  = t_full(iPost)';
Ts     = 1/fs;

% Normalise each amplitude by its input voltage â†’ all collapse to h(t)
% Exclude zero-amplitude rows (inserted missing-event placeholders)
% Weight by amplitude^2 so stronger inputs dominate the fitted time constants
% (unweighted mean biases poles toward weak-amp shape; stronger amps have longer tails)
validAmp = uA_s > 0;
w_amp    = uA_s(validAmp).^2;
w_amp    = w_amp / sum(w_amp);
h_rows   = bsxfun(@rdivide, DF_s(validAmp, iPost), uA_s(validAmp));
h_norm   = sum(bsxfun(@times, h_rows, w_amp), 1, 'omitnan')';
validT_h = isfinite(h_norm);   % guards against NaN and Inf
nT_h     = sum(validT_h);

% Single iddata: unit impulse in, normalised response out
% Prepend nPre zeros (toolbox requirement for transient data)
nPre    = maxPoles + maxZeros + 2;
u_fit   = [zeros(nPre,1); 1; zeros(nT_h-1, 1)];
y_fit   = [zeros(nPre,1); h_norm(validT_h)];
data_fit = iddata(y_fit, u_fit, Ts);
data_fit.Tstart = -nPre * Ts;   % shift so t=0 is the impulse, not the start of the prepended zeros

% Sweep over (np, nz): strictly proper â†’ nz < np
tfOpt    = tfestOptions('EnforceStability', false, 'Display', 'off');
allMdls  = {};
mdlNames = {};
res      = struct('np',{},'nz',{},'nd',{},'AIC',{},'FPE',{},'sys',{});
ri       = 0;
for nd = 0:maxDelay
    for np = 1:maxPoles
        for nz = 0:min(np-1, maxZeros)
            try
                sys_i = tfest(data_fit, np, nz, tfOpt, 'InputDelay', nd*Ts);
                ri = ri + 1;
                res(ri).np  = np;
                res(ri).nz  = nz;
                res(ri).nd  = nd;
                res(ri).AIC = aic(sys_i);
                res(ri).FPE = fpe(sys_i);
                res(ri).sys = sys_i;
                allMdls{end+1}  = sys_i; %#ok<SAGROW>
                mdlNames{end+1} = sprintf('%dp%dz%dd', np, nz, nd); %#ok<SAGROW>
            catch ME
                fprintf('  tfest(%dp%dz%dd) failed: %s\n', np, nz, nd, ME.message);
            end
        end
    end
end

if isempty(res)
    error('tfest failed â€” check that System Identification Toolbox is installed.');
end

% Toolbox compare on the normalised trace
figure('Name', sprintf('Session %d â€” model comparison', selExp));
compare(data_fit, allMdls{:});
legend(mdlNames{:}, 'Location','best');

% Select best by AIC
[~, iBest] = min([res.AIC]);
best_sys = res(iBest).sys;

fprintf('\nSession %d â€” TF order selection:\n', selExp);
fprintf('  np  nz  nd     AIC       FPE\n');
for r = 1:numel(res)
    mk = ''; if r == iBest, mk = '  <-- best'; end
    fprintf('  %d   %d   %d  %8.2f  %10.4f%s\n', res(r).np, res(r).nz, res(r).nd, res(r).AIC, res(r).FPE, mk);
end
fprintf('Best: %dp/%dz/%dd (delay=%.0f ms)\n', res(iBest).np, res(iBest).nz, res(iBest).nd, res(iBest).nd*Ts*1000);
[num_tf, den_tf] = tfdata(best_sys, 'v');
fprintf('  Num: [%s]\n', num2str(num_tf, '%.4g  '));
fprintf('  Den: [%s]\n', num2str(den_tf, '%.4g  '));
if best_sys.InputDelay > 0
    fprintf('  Input delay: %.1f ms\n', best_sys.InputDelay * 1000);
end

% â”€â”€ Residual analysis â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
% Autocorrelation of residuals + cross-correlation with input.
% Significant spikes outside the confidence bounds â†’ model is missing structure.
figure('Name', sprintf('Session %d â€” residual analysis', selExp));
resid(data_fit, best_sys);

% Per-amplitude predictions using toolbox sim()
R2_all = nan(nAmp_s,1);
yp_all = cell(nAmp_s,1);
for iAmp = 1:nAmp_s
    y_i    = DF_s(iAmp, iPost)';
    validT = ~isnan(y_i);
    if sum(validT) < 5, continue; end
    nT  = sum(validT);
    % simulate unit impulse response, scale by input amplitude
    u_unit = [zeros(nPre,1); 1; zeros(nT-1, 1)];
    yp_obj = sim(best_sys, iddata([], u_unit, Ts));
    yp_i   = uA_s(iAmp) * yp_obj.OutputData(nPre+1:end);
    SS_res = sum((y_i(validT) - yp_i).^2);
    SS_tot = sum((y_i(validT) - mean(y_i(validT))).^2);
    R2_all(iAmp) = 1 - SS_res / max(SS_tot, eps);
    yp_full = nan(size(tPost));
    yp_full(validT) = yp_i;
    yp_all{iAmp} = yp_full;
    fprintf('  amp=%.2fV  RÂ²=%.3f\n', uA_s(iAmp), R2_all(iAmp));
end

% Pooled R² across all amplitudes (global-mean centering).
y_pool  = [];
yp_pool = [];
for iAmp = 1:nAmp_s
    if isempty(yp_all{iAmp}), continue; end
    y_i  = DF_s(iAmp, iPost)';
    yp_i = yp_all{iAmp};
    vT   = ~isnan(y_i) & ~isnan(yp_i);
    y_pool  = [y_pool;  y_i(vT)];
    yp_pool = [yp_pool; yp_i(vT)];
end
if numel(y_pool) > 1
    R2_pool = 1 - sum((y_pool - yp_pool).^2) / sum((y_pool - mean(y_pool)).^2);
else
    R2_pool = NaN;
end
fprintf('  Session %d total R² (pooled, all amps): %.3f\n', selExp, R2_pool);

% â”€â”€ Figure: one subplot per amplitude â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
nCols = min(nAmp_s, 4);
nRows = ceil(nAmp_s / nCols);
figure('Color','w','Position',[60 80 260*nCols 240*nRows]);
tlo_tf = tiledlayout(nRows, nCols, 'TileSpacing','compact','Padding','compact');
tfStr = sprintf('Session %d â€” best TF: %dp/%dz/%dd  (AIC=%.1f)', ...
    selExp, res(iBest).np, res(iBest).nz, res(iBest).nd, res(iBest).AIC);
title(tlo_tf, tfStr, 'FontWeight','bold','FontSize',9);

cMap = parula(nAmp_s);
for iAmp = 1:nAmp_s
    ax = nexttile(tlo_tf);  hold(ax,'on');

    % individual trials (gray)
    df_trials = allExperiments(selExp).imp.dfImp{iAmp}(:, iPost);
    validT = ~isnan(DF_s(iAmp, iPost)');
    for k = 1:size(df_trials,1)
        plot(ax, tPost(validT), df_trials(k,validT), '-', ...
            'Color',[0.8 0.8 0.8],'LineWidth',0.4,'HandleVisibility','off');
    end

    % mean
    y_data = DF_s(iAmp, iPost)';
    plot(ax, tPost(validT), y_data(validT), '-', ...
        'Color', cMap(iAmp,:), 'LineWidth',2, 'DisplayName','Mean');

    % fit
    if ~isempty(yp_all{iAmp})
        plot(ax, tPost(validT), yp_all{iAmp}(validT), 'k--', ...
            'LineWidth',1.5, 'DisplayName',sprintf('RÂ²=%.2f', R2_all(iAmp)));
    end

    title(ax, sprintf('%.2f V  RÂ²=%.2f', uA_s(iAmp), R2_all(iAmp)), 'FontSize',8);
    xlabel(ax,'Time (s)');
    if iAmp==1, ylabel(ax,'dF/F (%)'); end
    legend(ax,'Box','off','FontSize',7,'Location','best');
    set(ax,'Box','off','TickDir','out','FontSize',8);
end

%% â”€â”€ LOAO validation â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
% Leave-one-amplitude-out: for each amplitude, refit h_norm on the remaining
% amplitudes, then predict the held-out amplitude and record RÂ².
% A drop in RÂ² relative to the full-fit value reveals amplitude-dependent dynamics.

validIdx  = find(validAmp);          % indices into uA_s that were used in h_norm
nValid    = numel(validIdx);
R2_loao   = nan(nAmp_s, 1);

fprintf('\nLOAO validation (session %d):\n', selExp);
fprintf('  amp(V)   RÂ²_full   RÂ²_loao\n');

for iLeave = 1:nValid
    iAmp_lo  = validIdx(iLeave);     % amplitude index being held out
    trainIdx = validIdx([1:iLeave-1, iLeave+1:end]);

    % Recompute amplitude-weighted h_norm without the held-out amplitude
    w_lo   = uA_s(trainIdx).^2;
    w_lo   = w_lo / sum(w_lo);
    h_rows_lo = bsxfun(@rdivide, DF_s(trainIdx, iPost), uA_s(trainIdx));
    h_norm_lo = sum(bsxfun(@times, h_rows_lo, w_lo), 1, 'omitnan')';
    validT_lo = isfinite(h_norm_lo);
    nT_lo     = sum(validT_lo);
    if nT_lo < maxPoles + 2, continue; end

    % Fit best-order model (same np/nz/nd as full best) on leave-out data
    u_lo   = [zeros(nPre,1); 1; zeros(nT_lo-1,1)];
    y_lo   = [zeros(nPre,1); h_norm_lo(validT_lo)];
    d_lo   = iddata(y_lo, u_lo, Ts);
    d_lo.Tstart = -nPre * Ts;
    try
        sys_lo = tfest(d_lo, res(iBest).np, res(iBest).nz, tfOpt, ...
                       'InputDelay', res(iBest).nd * Ts);
    catch
        continue;
    end

    % Predict held-out amplitude
    y_ho   = DF_s(iAmp_lo, iPost)';
    validT_ho = ~isnan(y_ho);
    if sum(validT_ho) < 5, continue; end
    nT_ho  = sum(validT_ho);
    u_ho   = [zeros(nPre,1); 1; zeros(nT_ho-1,1)];
    yp_obj = sim(sys_lo, iddata([], u_ho, Ts));
    yp_ho  = uA_s(iAmp_lo) * yp_obj.OutputData(nPre+1:end);
    SS_res = sum((y_ho(validT_ho) - yp_ho).^2);
    SS_tot = sum((y_ho(validT_ho) - mean(y_ho(validT_ho))).^2);
    R2_loao(iAmp_lo) = 1 - SS_res / max(SS_tot, eps);

    fprintf('  %.2f      %.3f     %.3f\n', uA_s(iAmp_lo), R2_all(iAmp_lo), R2_loao(iAmp_lo));
end

% â”€â”€ LOAO summary figure â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
figure('Color','w','Position',[100 100 400 300]); hold on;
validPlot = ~isnan(R2_loao);
plot(uA_s(validPlot), R2_all(validPlot),  'o-', 'Color',[0.2 0.4 0.8], ...
    'LineWidth',1.5, 'MarkerFaceColor',[0.2 0.4 0.8], 'DisplayName','Full fit');
plot(uA_s(validPlot), R2_loao(validPlot), 's--','Color',[0.8 0.2 0.2], ...
    'LineWidth',1.5, 'MarkerFaceColor',[0.8 0.2 0.2], 'DisplayName','LOAO');
xlabel('Amplitude (V)'); ylabel('RÂ²');
title(sprintf('Session %d â€” LOAO validation', selExp), 'FontWeight','bold');
legend('Box','off','Location','best');
set(gca,'Box','off','TickDir','out');
ylim([0 1]);

%% â”€â”€ Paper Fig A: TF data vs model â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
% Smallest, middle, largest amplitude: session mean (color) + TF fit (black dash).
% Pre-trial baseline shown to the left of t = 0.

preWin_A = 0.2;                                          % seconds of pre-stim baseline to show
iWin_A   = find(t_full >= -preWin_A & t_full <= tFit_s);
tWin_A   = t_full(iWin_A);

vIdx = find(validAmp);
nV   = numel(vIdx);
fprintf('Session %d available amplitudes (mW): %s\n', selExp, num2str(uA_s(:)'/3, '%.2f  '));
if ~isempty(fig_A_amps_mW)
    tol = 0.5;   % mW tolerance for nearest-amplitude match
    repAmpIdx = [];
    for tgt = fig_A_amps_mW
        [d_match, ii] = min(abs(uA_s/3 - tgt));
        if d_match <= tol
            repAmpIdx(end+1) = ii; 
        else
            fprintf('  WARNING: no amplitude within %.2f mW of %.2f mW (closest: %.2f mW)\n', tol, tgt, uA_s(ii)/3);
        end
    end
elseif nV >= 3
    repAmpIdx = vIdx([1, round(nV/2), nV]);
elseif nV == 2
    repAmpIdx = vIdx([1, nV]);
else
    repAmpIdx = vIdx;
end
nRep = numel(repAmpIdx);
% Grayscale color grading: lightest = weakest amp, darkest = strongest (matches Fig 2A scheme)
grayLevels = linspace(0.85, 0.20, max(nRep, 1));
cRep = repmat(grayLevels(:), 1, 3);   % Nx3 grayscale RGB

PS = paperStyle();
setPaperDefaults();
fig_A = paperFig(6, 4);
hold on;
ax_A  = gca;
title(ax_A, 'Session 1', 'FontSize', 6, 'FontWeight', 'bold', 'Color', [0.2 0.4 0.8]);

for k = 1:nRep
    iAmp   = repAmpIdx(k);
    y_data = DF_s(iAmp, iWin_A)';
    validT = ~isnan(y_data);

    if isfinite(R2_all(iAmp))
        ampLabel = sprintf('%.2f mW(R^2=%.2f)', uA_s(iAmp)/3, R2_all(iAmp));
    else
        ampLabel = sprintf('%.2f mW', uA_s(iAmp)/3);
    end

    plot(ax_A, tWin_A(validT), y_data(validT), '-', ...
        'Color', cRep(k,:), 'LineWidth', 1.5, 'DisplayName', ampLabel);

    % TF model prediction -- same color as mean trace, dashed; out of legend
    if ~isempty(yp_all{iAmp})
        validPost = ~isnan(DF_s(iAmp, iPost)');
        plot(ax_A, tPost(validPost), yp_all{iAmp}(validPost), '--', ...
            'Color', cRep(k,:), 'LineWidth', 1.5, 'HandleVisibility','off');
    end
end

% Single neutral legend entry -- gray dash explains the dashed style
plot(ax_A, nan, nan, '--', 'Color', [0.45 0.45 0.45], 'LineWidth', 1.5, 'DisplayName', 'TF fit');

% Stim onset marker (vertical line at t = 0)
yl_A = ylim(ax_A);
yTop = max(yl_A(2), 0.5);
ylim(ax_A, [yl_A(1), yTop]);

% Gray shaded region added AFTER ylim is fixed — use data range so patch never expands axes
hPatch = patch(ax_A, [-preWin_A tFit_s tFit_s -preWin_A], ...
    [yl_A(1) yl_A(1) yTop yTop], ...
    [0.8 0.8 0.8], 'FaceAlpha', 0.5, 'EdgeColor', 'none', 'HandleVisibility', 'off');
uistack(hPatch, 'bottom');   % send behind all traces
line(ax_A, [0 0], [yl_A(1), yTop * 0.85], 'Color','r', 'LineWidth', 0.75, 'HandleVisibility','off');
text(ax_A, 0.02, yTop, 'Stim', 'Color','r', 'FontSize',6, 'FontWeight','bold', ...
    'HorizontalAlignment','left', 'VerticalAlignment','top', 'Clipping','off');
if isfinite(R2_pool)
    text(ax_A, tWin_A(end), yTop, sprintf('R^2=%.2f', R2_pool), ...
        'FontSize',6, 'FontWeight','bold', 'Color',[0.2 0.2 0.2], ...
        'HorizontalAlignment','right', 'VerticalAlignment','top');
end

paperAxes(ax_A, 'XLength',0.15,'YLength',1,'XLabel','150 ms','YLabel','1% dF/F');

lgd_A = legend(ax_A, 'Location','southeast');
paperLegend(lgd_A);
lgd_A.ItemTokenSize = [20 6];   % wider than default [6 6] so dash pattern is visible
lgd_A.FontSize      = 5;        % one pt smaller to fit long labels
lgd_A.Location      = 'none';   % switch to manual placement
lgd_A.Units         = 'normalized';
lgd_A.Position      = [0.55 0.03 0.43 0.35];  % pinned to bottom-right corner
lgd_A.AutoUpdate    = 'off';

% Resolve output dir whether run from brain_paper/ root or impulse-analysis/
if exist(fullfile('paper','images','figure2'), 'dir')
    out_imp_dir = fullfile('paper','images','figure2');
elseif exist(fullfile('..','paper','images','figure2'), 'dir')
    out_imp_dir = fullfile('..','paper','images','figure2');
else
    out_imp_dir = '.';
    warning('tf_fit: cannot find paper/images/figure2/ -- exporting to current folder.');
end
paperExport(fig_A, fullfile(out_imp_dir, sprintf('tf_data_vs_model_%s_%s_en%d.pdf', ...
    allExperiments(selExp).mn, allExperiments(selExp).td, allExperiments(selExp).en)));

%% â”€â”€ Paper Fig B: LOAO validation â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
% Full-fit RÂ² (filled circles) vs LOAO RÂ² (open squares) across amplitudes

validBoth = validAmp & ~isnan(R2_loao);
xAmp_B    = uA_s(validBoth) / 3;   % V â†’ mW
r2Full_B  = R2_all(validBoth);
r2Loao_B  = R2_loao(validBoth);

if isempty(xAmp_B)
    warning('tf_loao: no amplitudes with both R2_full and R2_loao â€” skipping figure.');
else
    fig_B = paperFig(4, 4);
    hold on;
    ax_B  = gca;

    plot(ax_B, xAmp_B, r2Full_B, 'o-', ...
        'Color', [0.2 0.4 0.8], 'LineWidth', 1.5, ...
        'MarkerSize', 4, 'MarkerFaceColor', [0.2 0.4 0.8], ...
        'DisplayName', 'Full fit');
    plot(ax_B, xAmp_B, r2Loao_B, 's--', ...
        'Color', [0.8 0.2 0.2], 'LineWidth', 1.5, ...
        'MarkerSize', 4, 'MarkerFaceColor', 'w', ...
        'MarkerEdgeColor', [0.8 0.2 0.2], ...
        'DisplayName', 'LOAO');

    ylim(ax_B, [0, 1]);
    yline(ax_B, 1, '--k', 'LineWidth', 0.75, 'HandleVisibility','off');

    xRange_B = max(xAmp_B) - min(xAmp_B);
    xLen_B   = max(0.1, round(xRange_B / 2, 1));

    shortCornerAxes_plot(ax_B, 'XLength',xLen_B,'YLength',0.5, ...
        'XLabel',sprintf('%.1f mW', xLen_B),'YLabel','0.5 R^2', ...
        'LineWidth',PS.sca_lw,'LabelGap',PS.sca_gap,'FontSize',PS.fs,'FontWeight',PS.fw);

    lgd_B = legend(ax_B, 'Box','off','FontSize',6,'FontWeight','bold','Location','southwest');
    try; lgd_B.ItemTokenSize = [6 6]; catch; end
    lgd_B.AutoUpdate = 'off';

    % exportgraphics(fig_B, sprintf('paper/images/figure2/tf_loao_%s_%s_en%d.pdf', ...
    %     allExperiments(selExp).mn, allExperiments(selExp).td, allExperiments(selExp).en), ...
    %     'ContentType','vector');
end
