% controller-analysis/cl_mse_factors.m
% Hierarchical regression + variance partitioning for CL trial MSE.
%
% Three predictors (pooled across all sessions with motion data):
%   X1 -- |ΔF/F at stim onset − ref|    (initial deviation)
%   X2 -- z-scored motion (2 s pre + full trial window)
%   X3 -- pre-trial dF/F std (1 s before onset) as proxy for LF/slow variance
%
% Analysis stages:
%   1. Collinearity check (predictor correlation matrix + VIF)
%   2. Hierarchical regression: R²₁, ΔR²₂, ΔR²₃ with bootstrap 95% CI
%   3. Partial R² (unique contribution of each factor holding others fixed)
%   4. Paper figures: correlation heatmap | waterfall R² | partial R² bars
%
% Run from brain_paper/ root OR controller-analysis/ -- path auto-detected.
% Requires: load_sessions.m has run first (mouse, fields defined in workspace).
clc;
close all;


PS = paperStyle();
setPaperDefaults();

% ---- paper/ root detection ----
if exist(fullfile('paper','images'), 'dir')
    paper_root = 'paper';
elseif exist(fullfile('..','paper','images'), 'dir')
    paper_root = fullfile('..','paper');
else
    paper_root = 'paper';
    warning('cl_mse_factors: cannot locate paper/ directory -- exporting locally.');
end

% ---- constants ----
Fs_cl     = 35;         % imaging frame rate (Hz)
c0        = 36;         % stim-onset column in wcDfk (t = 0; 35 cols = 1 s pre)
pre_s     = 1;          % pre-trial window for X3 (s)
mot_pre_s = 2;          % motion combined window: 2 s pre + full trial
c0_mot    = 71;         % onset column in wcmotion (mv(i-70:i+35*dur), so onset=index 71)

% ---- helper: OLS R² (no toolbox required) ----
% fitR2(X, y) -- X does NOT include intercept; added internally
fitR2 = @(Xp, yp) ...
    1 - sum((yp - [ones(size(Xp,1),1), Xp] * ([ones(size(Xp,1),1), Xp] \ yp)).^2) / ...
        max(sum((yp - mean(yp)).^2), eps);

%% ── Pool CL trials ──────────────────────────────────────────────────────────

Y  = [];   % CL MSE (er_wcDfk)
X1 = [];   % |ΔF/F_onset − ref|
X2 = [];   % motion (combined window mean)
X3 = [];   % pre-trial dF/F std

for k = 1:length(fields)
    if isfield(mouse.(fields{k}), 'skip') && mouse.(fields{k}).skip; continue; end
    if ~isfield(mouse.(fields{k}), 'data');                          continue; end
    dk    = mouse.(fields{k}).data;
    ref_k = mouse.(fields{k}).d.ref;
    dur_k = mouse.(fields{k}).d.params.dur;

    % require motion data (flag set by initialize_data / backfilled by load_sessions)
    if ~mouse.(fields{k}).has_motion; continue; end
    if ~isfield(dk,'wcmotion');       continue; end

    nT = size(dk.wcDfk, 1);    % number of CL trials

    % X1: onset deviation from reference
    x1_k = abs(dk.wcDfk(:, c0) - ref_k);                              % [nT x 1]

    % X2: motion energy -- combined window (2 s pre-onset through trial end)
    % d.motion is z-scored motion energy; mean of squares avoids cancellation.
    ws = max(1, c0_mot - round(mot_pre_s * Fs_cl));
    we = min(size(dk.wcmotion, 2), c0_mot + round(dur_k * Fs_cl) - 1);
    mot_win = dk.wcmotion(1:nT, ws:we);                                % [nT x W]
    x2_k = mean(mot_win .^ 2, 2);                                      % mean sq energy [nT x 1]

    % X3: pre-trial dF/F std (1 s before onset)
    pre_end   = c0 - 1;
    pre_start = max(1, c0 - round(pre_s * Fs_cl));
    if pre_end >= pre_start
        x3_k = std(dk.wcDfk(1:nT, pre_start:pre_end), 0, 2);         % [nT x 1]
    else
        x3_k = zeros(nT, 1);
    end

    n_use = min([numel(dk.er_wcDfk), numel(x1_k), numel(x2_k), numel(x3_k)]);

    Y  = [Y;  dk.er_wcDfk(1:n_use)];  %#ok<*AGROW>
    X1 = [X1; x1_k(1:n_use)];
    X2 = [X2; x2_k(1:n_use)];
    X3 = [X3; x3_k(1:n_use)];
end

% Remove rows with NaN / Inf
ok = all(isfinite([Y X1 X2 X3]), 2);
Y = Y(ok); X1 = X1(ok); X2 = X2(ok); X3 = X3(ok);
n = numel(Y);
fprintf('\n[cl_mse_factors] %d valid CL trials pooled.\n', n);

% Z-score all variables for comparable coefficients
Y_z  = (Y  - mean(Y))  / std(Y);
X_z  = zscore([X1, X2, X3]);   % [n x 3]

%% ── Stage 1: Collinearity ───────────────────────────────────────────────────

R_pred = corr([X1 X2 X3]);
pred_names = {'Onset dev', 'Motion energy', 'Pre-trial std'};

% VIF for each predictor
vif_vals = nan(3,1);
for j = 1:3
    oth = setdiff(1:3, j);
    vif_vals(j) = 1 / max(1 - fitR2(X_z(:,oth), X_z(:,j)), eps);
end

fprintf('Predictor correlations:\n');
pairs = nchoosek(1:3,2);
for p = 1:size(pairs,1)
    i = pairs(p,1); j = pairs(p,2);
    fprintf('  r(%s, %s) = %.3f\n', pred_names{i}, pred_names{j}, R_pred(i,j));
end
fprintf('VIF:  %s=%.2f  |  %s=%.2f  |  %s=%.2f\n', ...
    pred_names{1},vif_vals(1), pred_names{2},vif_vals(2), pred_names{3},vif_vals(3));

% ---- Figure A: predictor correlation heatmap ----
bwr = interp1([0 0.5 1], [0.18 0.33 0.78; 1 1 1; 0.84 0.19 0.15], linspace(0,1,256));
fig_corr = paperFig(5, 4.5);
ax_cr = axes(fig_corr,'Position',[0.22 0.22 0.58 0.65]);
imagesc(ax_cr, R_pred);
colormap(ax_cr, bwr);
clim(ax_cr, [-1 1]);
set(ax_cr,'XTick',1:3,'YTick',1:3, ...
    'XTickLabel',pred_names,'YTickLabel',pred_names, ...
    'TickLabelInterpreter','none','FontSize',6,'FontWeight','bold');
xtickangle(ax_cr, 25);
for i = 1:3
    for j = 1:3
        col_ij = 'k';
        if abs(R_pred(i,j)) > 0.55; col_ij = 'w'; end
        text(ax_cr, j, i, sprintf('%.2f', R_pred(i,j)), ...
            'HorizontalAlignment','center','FontSize',6,'FontWeight','bold','Color',col_ij);
    end
end
cb_cr = colorbar(ax_cr,'Location','eastoutside');
cb_cr.FontSize = 5; cb_cr.FontWeight = 'bold';
ylabel(cb_cr,'Pearson r','FontSize',5,'FontWeight','bold');
title(ax_cr,'Predictor correlations','FontSize',6,'FontWeight','bold');
paperExport(fig_corr, fullfile(paper_root,'cl_mse_pred_corr.png'));

%% ── Stage 2: Hierarchical regression ────────────────────────────────────────

r2_step = nan(3,1);
r2_step(1) = fitR2(X_z(:,1),     Y_z);           % X1 alone
r2_step(2) = fitR2(X_z(:,1:2),   Y_z);           % X1 + X2
r2_step(3) = fitR2(X_z(:,1:3),   Y_z);           % X1 + X2 + X3

delta_r2 = [r2_step(1); diff(r2_step)];           % [3 x 1]  incremental R²

fprintf('\nHierarchical regression (z-scored):\n');
fprintf('  Step 1  Onset dev alone:       R2 = %.3f\n',          r2_step(1));
fprintf('  Step 2  + Motion:              R2 = %.3f  (ΔR2 = %.3f)\n', r2_step(2), delta_r2(2));
fprintf('  Step 3  + Pre-trial std:       R2 = %.3f  (ΔR2 = %.3f)\n', r2_step(3), delta_r2(3));
fprintf('  Unexplained:                        %.3f\n',          1 - r2_step(3));

% Bootstrap 95% CI on delta R² (with replacement, n trials)
nBoot = 2000;
rng(0);
boot_dr2 = nan(nBoot, 3);
for b = 1:nBoot
    idx_b = randsample(n, n, true);
    Yb = Y_z(idx_b); Xb = X_z(idx_b,:);
    r2b1 = fitR2(Xb(:,1),   Yb);
    r2b2 = fitR2(Xb(:,1:2), Yb);
    r2b3 = fitR2(Xb(:,1:3), Yb);
    boot_dr2(b,:) = [r2b1, r2b2-r2b1, r2b3-r2b2];
end
ci_dr2 = prctile(boot_dr2, [2.5 97.5], 1);   % [2 x 3] -- lower / upper

%% ── Stage 3: Partial R² ──────────────────────────────────────────────────────

% Unique contribution = R²(full) - R²(model without this predictor)
r2_full = r2_step(3);
partial_r2 = nan(3,1);
partial_r2(1) = r2_full - fitR2(X_z(:,[2 3]), Y_z);   % unique X1
partial_r2(2) = r2_full - fitR2(X_z(:,[1 3]), Y_z);   % unique X2
partial_r2(3) = r2_full - fitR2(X_z(:,[1 2]), Y_z);   % unique X3
shared_total  = r2_full - sum(partial_r2);             % shared variance

fprintf('\nPartial R² (unique contributions):\n');
for j = 1:3
    fprintf('  %s: %.3f\n', pred_names{j}, partial_r2(j));
end
fprintf('  Shared (all combinations): %.3f\n', shared_total);

% Bootstrap CI for partial R²
boot_pr2 = nan(nBoot, 3);
for b = 1:nBoot
    idx_b = randsample(n, n, true);
    Yb = Y_z(idx_b); Xb = X_z(idx_b,:);
    rf = fitR2(Xb, Yb);
    boot_pr2(b,1) = rf - fitR2(Xb(:,[2 3]), Yb);
    boot_pr2(b,2) = rf - fitR2(Xb(:,[1 3]), Yb);
    boot_pr2(b,3) = rf - fitR2(Xb(:,[1 2]), Yb);
end
ci_pr2 = prctile(boot_pr2, [2.5 97.5], 1);   % [2 x 3]

%% ── Figures B & C ────────────────────────────────────────────────────────────

step_labels  = {'Onset dev', '+Motion', '+Pre-trial std'};
col_steps    = [0.20 0.40 0.75;   % blue  -- onset dev
                0.75 0.40 0.10;   % orange -- motion
                0.20 0.60 0.35];  % green  -- pre-trial std
col_unexp    = [0.82 0.82 0.82];  % gray -- unexplained

% ---- Figure B: Waterfall (incremental R²) ----
fig_wf = paperFig(6, 4);
ax_wf  = axes(fig_wf,'Position',[0.16 0.22 0.78 0.68]);
hold(ax_wf,'on');

base = 0;
for s = 1:3
    bar(ax_wf, s, delta_r2(s), 0.55, 'FaceColor', col_steps(s,:), 'EdgeColor','none');
    errorbar(ax_wf, s, delta_r2(s), ...
        delta_r2(s) - ci_dr2(1,s), ci_dr2(2,s) - delta_r2(s), ...
        'k', 'LineWidth', 0.8, 'CapSize', 3, 'HandleVisibility','off');
    base = base + delta_r2(s);
end
bar(ax_wf, 4, 1 - r2_full, 0.55, 'FaceColor', col_unexp, 'EdgeColor','none');
text(ax_wf, 4, (1 - r2_full)/2, sprintf('%.3f', 1-r2_full), ...
    'HorizontalAlignment','center','FontSize',5,'FontWeight','bold','Color',[0.4 0.4 0.4]);

for s = 1:3
    text(ax_wf, s, delta_r2(s) + 0.003, sprintf('%.3f', delta_r2(s)), ...
        'HorizontalAlignment','center','FontSize',5,'FontWeight','bold');
end

set(ax_wf,'XTick',1:4,'XTickLabel',[step_labels, {'Unexplained'}], ...
    'Box','off','TickDir','out','FontSize',6,'FontWeight','bold');
xtickangle(ax_wf, 20);
ylabel(ax_wf,'Variance explained (R^2)','FontSize',6,'FontWeight','bold');
title(ax_wf,sprintf('Hierarchical R^2  (full model R^2=%.3f)', r2_full), ...
    'FontSize',6,'FontWeight','bold');
ylim(ax_wf,[0, max(delta_r2)*1.25 + 0.02]);
hold(ax_wf,'off');
paperExport(fig_wf, fullfile(paper_root,'cl_mse_waterfall_r2.pdf'));

% ---- Figure C: Partial R² bars ----
fig_pr = paperFig(5, 4);
ax_pr  = axes(fig_pr,'Position',[0.20 0.22 0.74 0.68]);
hold(ax_pr,'on');

for j = 1:3
    bar(ax_pr, j, partial_r2(j), 0.55, 'FaceColor', col_steps(j,:), 'EdgeColor','none');
    errorbar(ax_pr, j, partial_r2(j), ...
        partial_r2(j) - ci_pr2(1,j), ci_pr2(2,j) - partial_r2(j), ...
        'k', 'LineWidth', 0.8, 'CapSize', 3, 'HandleVisibility','off');
    text(ax_pr, j, partial_r2(j) + 0.002, sprintf('%.3f', partial_r2(j)), ...
        'HorizontalAlignment','center','FontSize',5,'FontWeight','bold');
end

set(ax_pr,'XTick',1:3,'XTickLabel',pred_names, ...
    'Box','off','TickDir','out','FontSize',6,'FontWeight','bold');
xtickangle(ax_pr, 20);
ylabel(ax_pr,'Partial R^2 (unique contribution)','FontSize',6,'FontWeight','bold');
title(ax_pr,sprintf('Unique variance in CL MSE  (shared=%.3f)', shared_total), ...
    'FontSize',6,'FontWeight','bold');
ylim(ax_pr,[0, max(partial_r2)*1.3 + 0.01]);
hold(ax_pr,'off');
paperExport(fig_pr, fullfile(paper_root,'cl_mse_partial_r2.pdf'));

fprintf('\n[cl_mse_factors] Done. Exported:\n');
fprintf('  cl_mse_pred_corr.png\n  cl_mse_waterfall_r2.pdf\n  cl_mse_partial_r2.pdf\n');
