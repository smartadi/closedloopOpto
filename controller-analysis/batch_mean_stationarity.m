% controller-analysis -- batch-mean stationarity test.
% Run from brain_paper/ root AFTER load_sessions.m (needs `mouse`).
%
% Purpose: resolve the reviewer \todo on the variance-convergence argument
% (results.tex). Variance convergence (Fig S1) is a central-limit effect that
% holds for ANY finite-variance process, including one with a slowly drifting
% mean. To support the trial-averaging assumption we must additionally show the
% per-trial MEAN of spontaneous activity is stationary across acquisition order.
%
% Test: for each session, regress the per-trial spontaneous mean dF/F on trial
% index (acquisition order). A near-zero, non-significant slope -> stationary
% mean. We report OLS slope + p, a non-parametric Spearman trend test (robust
% to outliers), and the drift over the whole session expressed in units of the
% trial-to-trial SD.

fields  = fieldnames(mouse);
nSess   = numel(fields);
alpha   = 0.05;

slopes   = nan(nSess,1);   % %dF/F per trial
pOLS     = nan(nSess,1);
rhoSp    = nan(nSess,1);
pSp      = nan(nSess,1);
driftSD  = nan(nSess,1);   % total drift across session / SD of per-trial means
nTrials  = nan(nSess,1);

fprintf('\n============== Batch-mean stationarity (spontaneous dF/F) ==============\n');
fprintf('%-4s %-20s %-7s  %-10s  %-9s  %-9s  %-10s\n', ...
    'sess','session','nTrial','slope/tr','p(OLS)','p(Spear)','drift[SD]');
fprintf('%s\n', repmat('-',1,82));

for i = 1:nSess
    sd = mouse.(fields{i}).data.spont_dFk;     % trials x time
    if isempty(sd), continue; end
    y = mean(sd, 2, 'omitnan');                % per-trial mean over spont window
    n = numel(y);
    x = (1:n)';
    good = isfinite(y);
    y = y(good); x = x(good); n = numel(y);
    nTrials(i) = n;

    % OLS slope + p
    mdl        = fitlm(x, y);
    slopes(i)  = mdl.Coefficients.Estimate(2);
    pOLS(i)    = mdl.Coefficients.pValue(2);

    % Spearman rank trend (robust)
    [rhoSp(i), pSp(i)] = corr(x, y, 'Type','Spearman');

    % drift across whole session relative to trial-to-trial scatter
    driftSD(i) = (slopes(i) * (n-1)) / std(y);

    mk = ''; if pOLS(i) < alpha, mk = ' *'; end
    fprintf('%-4s %s %s  %-7d  %+9.4f  %-9.3f  %-9.3f  %+8.2f%s\n', ...
        fields{i}, mouse.(fields{i}).mn, mouse.(fields{i}).td, n, ...
        slopes(i), pOLS(i), pSp(i), driftSD(i), mk);
end
fprintf('%s\n', repmat('-',1,82));

% ---- aggregate summary ----
valid   = isfinite(slopes);
nValid  = sum(valid);
nSigOLS = sum(pOLS(valid) < alpha);
nSigBonf= sum(pOLS(valid) < alpha/nValid);
% sign test: are slopes balanced around zero (no systematic drift direction)?
nPos    = sum(slopes(valid) > 0);
pSign   = 2 * binocdf(min(nPos, nValid-nPos), nValid, 0.5);   % two-sided sign test

fprintf('\nSummary across %d sessions:\n', nValid);
fprintf('  median slope          : %+.4f %%dF/F per trial\n', median(slopes(valid)));
fprintf('  median |drift| (SD)    : %.2f  (session-long mean change in trial-SD units)\n', median(abs(driftSD(valid))));
fprintf('  sessions p<0.05 (OLS)  : %d / %d\n', nSigOLS, nValid);
fprintf('  sessions p<0.05 Bonf   : %d / %d  (alpha=%.4f)\n', nSigBonf, nValid, alpha/nValid);
fprintf('  slope sign balance     : %d pos / %d neg, sign-test p=%.3f\n', nPos, nValid-nPos, pSign);
if nSigBonf == 0
    fprintf('  -> No session shows significant mean drift after correction: MEAN is stationary.\n');
    fprintf('     Supports keeping the stronger claim (option i).\n');
else
    fprintf('  -> %d session(s) drift: consider softening claim (option ii) or excluding.\n', nSigBonf);
end

% ---- supplementary figure: per-trial mean vs trial index, small multiples ----
PS = paperStyle(); setPaperDefaults();
nC = 4; nR = ceil(nValid / nC);
figBM = figure('Color','w','Units','centimeters','Position',[2 2 3.2*nC 2.6*nR]);
tlo = tiledlayout(figBM, nR, nC, 'TileSpacing','compact','Padding','compact');
vi = find(valid)';
for k = 1:numel(vi)
    i = vi(k);
    sd = mouse.(fields{i}).data.spont_dFk;
    y = mean(sd, 2, 'omitnan'); x = (1:numel(y))';
    ax = nexttile(tlo); hold(ax,'on');
    plot(ax, x, y, '.', 'Color',[0.6 0.6 0.6], 'MarkerSize',4);
    b = polyfit(x, y, 1);
    plot(ax, x, polyval(b, x), '-', 'Color',[0.85 0.2 0.2], 'LineWidth',1.2);
    sigStr = ''; if pOLS(i) < alpha, sigStr = ' *'; end
    title(ax, sprintf('%s  p=%.2f%s', fields{i}, pOLS(i), sigStr), 'FontSize',6,'FontWeight','bold');
    set(ax,'Box','off','TickDir','out','FontSize',5);
end
xlabel(tlo, 'Trial index (acquisition order)', 'FontSize',6,'FontWeight','bold');
ylabel(tlo, 'Per-trial mean \DeltaF/F (%)', 'FontSize',6,'FontWeight','bold');
title(tlo, 'Spontaneous batch-mean stationarity', 'FontSize',7,'FontWeight','bold');

if isfolder('paper'), out_root = 'paper'; elseif isfolder(fullfile('..','paper')), out_root = fullfile('..','paper'); else, out_root = '.'; end
paperExport(figBM, fullfile(out_root, 'batch_mean_stationarity.png'));
