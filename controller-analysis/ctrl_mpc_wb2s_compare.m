function C = ctrl_mpc_wb2s_compare(sess)
%CTRL_MPC_WB2S_COMPARE  MPC replay (Fig-3 frame, 108 CL trials, 200 ms preview, lambda = 1) with the
%   whole-brain 2-s-history disturbance forecaster (mpc_arx_wb2s.py 'cl') vs our earlier forecasters.
%   Same CL folds for every model (paired). Simulation -> descriptive only.
%   Forecast quality = pooled R^2 of the departure DEP on the CL trials (targets inside the stim window).
% OUT  data/ctrl_mpc_wb2s_compare_<sess>.mat, paper/images/mpc_arx/wb2s_mpc_compare_<sess>.png
if nargin < 1, sess = 'AL_0033_0226_e2'; end
here = fileparts(mfilename('fullpath')); dataDir = fullfile(here,'data'); addpath(genpath(fullfile(here,'..','utils')));
figDir = fullfile(here,'..','paper','images','mpc_arx');
FF = load(fullfile(dataDir, sprintf('ctrl_mpc_forecasters_%s.mat', sess)), 'F','DEP','fold');
FA = load(fullfile(dataDir, sprintf('ctrl_mpc_arx_out_%s.mat', sess)), 'F','fold');
FW = load(fullfile(dataDir, sprintf('ctrl_mpc_wb2s_out_%s.mat', sess)), 'F','fold');
assert(isequal(double(FF.fold(:)), double(FA.fold(:)), double(FW.fold(:))), 'folds differ');
M = { 'ar',    'ctrl_mpc_forecasters_%s.mat', 'AR (trial-trained, MATLAB)';
      'dlinear','ctrl_mpc_forecasters_%s.mat', 'DLinear (trial-trained)';
      'pyarx', 'ctrl_mpc_arx_out_%s.mat',      'ARX + laser (session, Lu et al. recipe)';
      'roi2s', 'ctrl_mpc_wb2s_out_%s.mat',     'ROI + laser, 2-s history (direct)';
      'wbbest','ctrl_mpc_wb2s_out_%s.mat',     'ROI + laser + 100 spots, tuned (spots 286 ms)';
      'wb2s',  'ctrl_mpc_wb2s_out_%s.mat',     'ROI + laser + 100 brain spots, 2-s history'};
DEP = FF.DEP; pre = 35; N = 105; leads = [1 2 3 5 7];
nM = size(M,1); R2 = nan(nM, numel(leads)); sk7 = nan(nM,1);
for i = 1:nM
    switch M{i,2}
        case 'ctrl_mpc_forecasters_%s.mat', Fm = double(FF.F.(M{i,1}));
        case 'ctrl_mpc_arx_out_%s.mat',     Fm = double(FA.F.(M{i,1}));
        otherwise,                           Fm = double(FW.F.(M{i,1}));
    end
    for il = 1:numel(leads)
        L = leads(il); t = 1:N-L; tg = zeros(numel(t), size(DEP,1)); fc = tg;
        for k = 1:size(DEP,1), tg(:,k) = DEP(k, pre+t+L).'; fc(:,k) = Fm(t, L, k); end
        R2(i,il) = 1 - sum((tg(:)-fc(:)).^2) / sum((tg(:)-mean(tg(:))).^2);
        if L == 7, sk7(i) = sqrt(mean((tg(:)-fc(:)).^2)) / sqrt(mean(tg(:).^2)); end
    end
end
ratio = nan(nM,1); beats = ratio; rawM = nan(nM,1);
for i = 1:nM
    evalc(['T = ctrl_mpc_lqr(''frame'',''fig3'',''fcstModel'',M{i,1},''fcstFile'',M{i,2},''Lp'',7,' ...
           '''xGrid'',[1 0],''KpGrid'',0.10,''KiGrid'',1.5,''tag'',''_wb2s'');']);
    q = T.rM(:, strcmp(T.modes,'x1.00')) ./ T.rPI;
    ratio(i) = median(q); beats(i) = sum(q < 1); rawM(i) = median(T.rM(:, strcmp(T.modes,'x1.00')));
    if i == 1, perf = median(T.rM(:, strcmp(T.modes,'x0.00')) ./ T.rPI); rPI = median(T.rPI); end
    fprintf('[WB2S-MPC] %-44s R2 @ 29/57/86/143/200 ms %s | MPC/PI %.3f (%d/108) | err@200/clim %.3f\n', ...
        M{i,3}, mat2str(round(R2(i,:),3)), ratio(i), beats(i), sk7(i));
end
delete(fullfile(dataDir, sprintf('ctrl_mpc_lqr_%s_wb2s.mat', sess)));
fprintf('[WB2S-MPC] perfect preview %.3f x PI | PI replay median RMSE %.2f\n', perf, rPI);

% ---- figure ---------------------------------------------------------------------------------------
U = load(fullfile(dataDir, sprintf('ctrl_mpc_uncertainty_sweep_%s.mat', sess)));
cols = [0.20 0.45 0.75; 0.35 0.60 0.85; 0.15 0.60 0.30; 0.36 0.17 0.53; 0.91 0.48 0.37; 0.82 0.29 0.36];
fig = figure('Color','w','Position',[80 80 1500 420]);
ax = subplot(1,3,1); hold(ax,'on');
for i = 1:nM, plot(ax, leads*1000/35, R2(i,:), '-o', 'Color', cols(i,:), 'MarkerFaceColor', cols(i,:), 'LineWidth', 1.3); end
set(ax,'XScale','log'); xlabel(ax,'forecast lead (ms)'); ylabel(ax,'R^2 of disturbance forecast (CL trials)');
legend(ax, M(:,3), 'Box','off','Location','southwest','FontSize',7); title(ax,'forecast quality, 108 held-out CL trials');
ax = subplot(1,3,2); hold(ax,'on');
b = barh(ax, 1:nM, ratio, 0.6); b.FaceColor = 'flat'; b.CData = cols;
xline(ax, 1, 'Color', [0 0.4 0.85], 'LineWidth', 1.5); xline(ax, perf, ':', 'Color', [.4 .4 .4]);
for i = 1:nM, text(ax, ratio(i)+0.005, i, sprintf('%.3f  (%d/108)', ratio(i), beats(i)), 'FontSize', 8); end
set(ax,'YTick',1:nM,'YTickLabel',M(:,3),'YDir','reverse','FontSize',8); xlim(ax,[0 1.15]);
xlabel(ax,'MPC error / PI error (200 ms preview)'); title(ax,'MPC replay on the CL trials');
ax = subplot(1,3,3); hold(ax,'on');
for im = 1:numel(U.mods), plot(ax, U.xG*U.skill200(im), U.ratio(im,:), '-', 'Color', [.8 .8 .8]); end
for i = 1:nM, plot(ax, sk7(i), ratio(i), 'o', 'MarkerSize', 8, 'MarkerFaceColor', cols(i,:), 'MarkerEdgeColor','k'); end
yline(ax, 1, 'Color', [0 0.4 0.85]); set(ax,'XDir','reverse'); xlim(ax,[0 1.05]); ylim(ax,[0 1.3]);
xlabel(ax,'forecast error at 200 ms / climatology'); ylabel(ax,'MPC error / PI error');
title(ax,'on the forecast-uncertainty line (gray = earlier sweep)');
exportgraphics(fig, fullfile(figDir, sprintf('wb2s_mpc_compare_%s.png', sess)), 'Resolution', 200);
C = struct('names',{M(:,3)},'models',{M(:,1)},'R2',R2,'leads_ms',leads*1000/35,'ratio',ratio,'beats',beats, ...
           'rmse',rawM,'perfect',perf,'err200',sk7);
save(fullfile(dataDir, sprintf('ctrl_mpc_wb2s_compare_%s.mat', sess)), '-struct','C');
end
