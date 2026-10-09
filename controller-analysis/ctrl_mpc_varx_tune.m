function S = ctrl_mpc_varx_tune(sess, rdGrid)
%CTRL_MPC_VARX_TUNE  Tune the VARX-forecast MPC for the CL replay (Fig-3 frame, 108 CL trials, 200 ms preview).
%   Grid: every forecaster variant in data/ctrl_mpc_varx_tune_<sess>.mat (mpc_varx_tune.py: VARX L/lambda/Q +
%   forecast smoothing across leads / across origins) plus the AR baseline, x the MPC's Delta-u penalty rd.
%   Objective = median per-trial MPC/PI RMSE ratio. To avoid tuning and reporting on the same trials, the
%   config is SELECTED on the odd CL trials and REPORTED on the even ones (and on all 108). The AR baseline
%   gets the same treatment (its own best rd on odd trials). Simulation -> descriptive only.
% OUT  data/ctrl_mpc_varx_tune_res_<sess>.mat, paper/images/mpc_arx/varx_mpc_tune_<sess>.png
if nargin < 1 || isempty(sess), sess = 'AL_0033_0226_e2'; end
if nargin < 2 || isempty(rdGrid), rdGrid = [0.3 1 3 10]; end
here = fileparts(mfilename('fullpath')); dataDir = fullfile(here,'data'); addpath(genpath(fullfile(here,'..','utils')));
figDir = fullfile(here,'..','paper','images','mpc_arx');
V = load(fullfile(dataDir, sprintf('ctrl_mpc_varx_tune_%s.mat', sess)), 'names');
names = [{'ar'}, cellstr(V.names(:).')];
files = [{'ctrl_mpc_forecasters_%s.mat'}, repmat({'ctrl_mpc_varx_tune_%s.mat'}, 1, numel(names)-1)];
nF = numel(names); nR = numel(rdGrid);
Q = []; perf = nan(1, nR);
for ir = 1:nR
    for i = 1:nF
        evalc(['T = ctrl_mpc_lqr(''frame'',''fig3'',''fcstModel'',names{i},''fcstFile'',files{i},''Lp'',7,' ...
               '''xGrid'',[1 0],''KpGrid'',0.10,''KiGrid'',1.5,''rd'',rdGrid(ir),''tag'',''_vt'');']);
        q = T.rM(:, strcmp(T.modes,'x1.00')) ./ T.rPI;
        if isempty(Q), Q = nan(numel(q), nF, nR); end
        Q(:, i, ir) = q;
        if i == 1, perf(ir) = median(T.rM(:, strcmp(T.modes,'x0.00')) ./ T.rPI); end
        fprintf('[VT] rd=%-4g %-16s MPC/PI median %.3f | odd %.3f even %.3f\n', rdGrid(ir), names{i}, ...
            median(q), median(q(1:2:end)), median(q(2:2:end)));
    end
end
delete(fullfile(dataDir, sprintf('ctrl_mpc_lqr_%s_vt.mat', sess)));
odd = squeeze(median(Q(1:2:end,:,:), 1)); even = squeeze(median(Q(2:2:end,:,:), 1)); all_ = squeeze(median(Q, 1));
beats = squeeze(sum(Q < 1, 1));
varx = 2:nF;
[~, iv] = min(reshape(odd(varx,:), [], 1)); [iF, iR] = ind2sub([numel(varx) nR], iv); iF = varx(iF);
[~, iRa] = min(odd(1,:));
iBase = find(strcmp(names, 'L10_lam100')); iRb = find(rdGrid == 1);
fprintf('[VT] SELECTED (odd trials): %s, rd=%g\n', names{iF}, rdGrid(iR));
fprintf('[VT] report  | even | all (beats PI)\n');
fprintf('[VT] VARX tuned  %-14s rd=%-4g  %.3f | %.3f (%d/%d)\n', names{iF}, rdGrid(iR), even(iF,iR), all_(iF,iR), beats(iF,iR), size(Q,1));
fprintf('[VT] VARX base   L10_lam100     rd=1     %.3f | %.3f (%d/%d)\n', even(iBase,iRb), all_(iBase,iRb), beats(iBase,iRb), size(Q,1));
fprintf('[VT] AR tuned                   rd=%-4g  %.3f | %.3f (%d/%d)\n', rdGrid(iRa), even(1,iRa), all_(1,iRa), beats(1,iRa), size(Q,1));
fprintf('[VT] perfect preview by rd: %s\n', mat2str(round(perf,3)));

fig = figure('Color','w','Position',[80 80 1500 520]);
ax = subplot(1,2,1); imagesc(ax, odd); colormap(ax, flipud(parula)); cb = colorbar(ax); cb.Label.String = 'median MPC/PI (odd trials = selection set)';
set(ax, 'YTick', 1:nF, 'YTickLabel', strrep(names,'_','\_'), 'XTick', 1:nR, 'XTickLabel', compose('rd=%g', rdGrid), 'FontSize', 8);
for i = 1:nF, for ir = 1:nR, text(ax, ir, i, sprintf('%.3f', odd(i,ir)), 'HorizontalAlignment','center', 'FontSize', 7); end, end
hold(ax,'on'); plot(ax, iR, iF, 'ks', 'MarkerSize', 22, 'LineWidth', 2);
title(ax, 'tuning grid: forecaster variant x MPC \Deltau penalty (selected = box)');
ax = subplot(1,2,2); hold(ax,'on');
lab = {sprintf('AR (rd=%g)', rdGrid(iRa)), 'VARX base (L10, \lambda100, rd=1)', sprintf('VARX tuned (%s, rd=%g)', strrep(names{iF},'_','\_'), rdGrid(iR))};
vals = [even(1,iRa) all_(1,iRa); even(iBase,iRb) all_(iBase,iRb); even(iF,iR) all_(iF,iR)];
b = bar(ax, vals, 0.8); b(1).FaceColor = [0.2 0.45 0.75]; b(2).FaceColor = [0.75 0.75 0.75];
for i = 1:3, text(ax, i-0.15, vals(i,1)+0.01, sprintf('%.3f', vals(i,1)), 'HorizontalAlignment','center','FontSize',8);
             text(ax, i+0.15, vals(i,2)+0.01, sprintf('%.3f', vals(i,2)), 'HorizontalAlignment','center','FontSize',8); end
yline(ax, 1, 'Color', [0 0.4 0.85]); set(ax, 'XTick', 1:3, 'XTickLabel', lab, 'FontSize', 8); ylim(ax, [0.7 1.05]);
ylabel(ax, 'median MPC error / PI error'); legend(ax, {'even trials (held out from tuning)','all 108'}, 'Box','off','Location','northeast');
title(ax, 'MPC replay, 200 ms preview');
exportgraphics(fig, fullfile(figDir, sprintf('varx_mpc_tune_%s.png', sess)), 'Resolution', 170);
S = struct('names',{names},'rdGrid',rdGrid,'Q',Q,'odd',odd,'even',even,'all',all_,'beats',beats,'perfect',perf, ...
           'sel',names{iF},'selRd',rdGrid(iR),'arRd',rdGrid(iRa));
save(fullfile(dataDir, sprintf('ctrl_mpc_varx_tune_res_%s.mat', sess)), '-struct','S');
end
