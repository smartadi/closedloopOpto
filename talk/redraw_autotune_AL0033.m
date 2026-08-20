%% redraw_autotune_AL0033.m -- the AL_0033 auto-tune path + cost, talk version
%
% The published autotune_convergence_*.pdf were made 2026-06-29 by a script version that
% is not in the repo (grep of the full history finds nothing that draws a (Kp,Ki) path or
% an axis labelled "tune iteration"). This redraws that figure from the source arrays so
% the panel can be changed at all -- and fixes the thing that prompted it: the white star
% sat ON the winning point and hid its colour. It is now offset with a leader line.
%
% SOURCE (the rule in controller-tuning/CLAUDE.md): accepted gains `Kdata.npy` + accepted
% costs `Kval.npy`. NOT input_params, which logs every applied candidate including
% rejected probes. That is why the grey "whiskers" of the published figure are absent
% here -- they were rejected probes, drawn without being labelled as such.
%
% Session: AL_0033 2025-03-17 e3 -- one of only two recorded sessions with a live online
% cost (the other is AL_0034 10-25 e1). Writes PDF + PNG into talk/.

root   = 'C:\Users\aditya\Documents\projects\brain_paper';
outDir = fullfile(root,'talk');
addpath(genpath(fullfile(root,'utils')));
addpath(fullfile(root,'controller-tuning'));
cd(root);

MN = 'AL_0033';  TD = '2025-03-17';  EN = 3;
r  = expPath(MN, TD, EN);
K  = double(readNPY(fullfile(r,'Kdata.npy')));      % accepted (Kp, Ki) per iteration
V  = double(readNPY(fullfile(r,'Kval.npy')));       % accepted cost per iteration

% Trailing slots are pre-allocated and never evaluated -- they log cost 0, which is not a
% cost of zero. Drop them before anything is plotted or the colour scale collapses.
keep = V > 0;
K = K(keep,:);  V = V(keep);
it = (0:numel(V)-1).';
[Jbest, ib] = min(V);
fprintf('[AUTOTUNE] %s %s e%d | %d accepted iterations | cost %.1f -> %.1f | best (%.4g, %.4g)\n', ...
        MN, TD, EN, numel(V), V(1), Jbest, K(ib,1), K(ib,2));

setPaperDefaults();  PS = paperStyle();

%% ---- (a) the 2-D gain path ---------------------------------------------------------
f1 = paperFig(5, 4.2);  ax = axes(f1); hold(ax,'on');
plot(ax, K(:,1), K(:,2), '-', 'Color', [0.55 0.55 0.55], 'LineWidth', 1.0);
scatter(ax, K(:,1), K(:,2), 46, V, 'filled', 'MarkerEdgeColor','k', 'LineWidth',0.4);
plot(ax, K(1,1), K(1,2), 'o', 'MarkerSize', 11, 'MarkerEdgeColor','k', 'LineWidth', 1.0);
text(ax, K(1,1), K(1,2), '  start', 'FontSize', PS.fs, 'FontWeight', PS.fw, ...
     'VerticalAlignment','top');
xlabel(ax, 'K_p');  ylabel(ax, 'K_i');
axis(ax,'tight');
xl = xlim(ax); yl = ylim(ax);
xlim(ax, xl + 0.14*diff(xl)*[-1 1]);  ylim(ax, yl + 0.14*diff(yl)*[-1 1]);
colormap(ax, parula);
cb = colorbar(ax);  cb.Label.String = 'cost  J';  cb.FontSize = PS.fs;
cb.Label.FontWeight = PS.fw;
set(ax,'FontSize',PS.fs,'FontWeight',PS.fw,'TickDir','out','Box','off');
starOffset(ax, K(ib,1), K(ib,2), PS);            % <- offset, so the node's colour shows
paperExport(f1, fullfile(outDir,'autotune_path_AL_0033_0317.pdf'));

%% ---- (b) the cost curve ------------------------------------------------------------
f2 = paperFig(5, 4.2);  ax2 = axes(f2); hold(ax2,'on');
stairs(ax2, it, V, '-', 'Color', PS.col_cl, 'LineWidth', PS.lw_mean);
scatter(ax2, it, V, 34, V, 'filled', 'MarkerEdgeColor','k', 'LineWidth',0.4);
colormap(ax2, parula);
xlabel(ax2, 'tune iteration');  ylabel(ax2, 'cost  J');
xlim(ax2, [-0.4 it(end)+0.4]);
set(ax2,'FontSize',PS.fs,'FontWeight',PS.fw,'TickDir','out','Box','off');
starOffset(ax2, it(ib), V(ib), PS, 'dir', [-0.06 0.10]);
paperExport(f2, fullfile(outDir,'autotune_cost_AL_0033_0317.pdf'));

fprintf('[AUTOTUNE] wrote autotune_path / autotune_cost _AL_0033_0317.pdf -> %s\n', outDir);
