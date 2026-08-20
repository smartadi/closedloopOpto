function plot_cv_r2(cvStats, outDir)
%PLOT_CV_R2  in-sample vs held-out R2, one line per leave-one-amplitude-out fold.
%
%   plot_cv_r2(cvStats, outDir)
%   plot_cv_r2()                    % loads talk/tf_cv_stats.mat, writes next to it
%
% Split out of make_lti_cv_fig.m so the panel can be restyled from the cached fold stats
% instead of re-running imp_tf_run, which needs a cold load of the experiments (~20 min).
%
% READ THE PANEL AS PAIRS, NOT AS TWO COLUMNS. A fold whose line is FLAT failed in-sample
% just as badly as held out -- that is an amplitude the model never fitted, not evidence
% that it fails to generalise. The generalisation statistic is the paired drop in the title.

if nargin < 2 || isempty(outDir)
    outDir = fileparts(mfilename('fullpath'));
end
if nargin < 1 || isempty(cvStats)
    L = load(fullfile(outDir,'tf_cv_stats.mat'));
    cvStats = L.cvStats;
end

PS = paperStyle(); setPaperDefaults();
rIn = cvStats.in(:);  rOut = cvStats.out(:);  sess = cvStats.sess(:);
nSess = numel(unique(sess));

% Clip rather than let two extreme folds set the ylim: at the true range the other 17 folds
% collapse into a ~5%-tall band and the in-sample/held-out comparison is unreadable. Clipped
% folds are drawn at the floor AND labelled with their real values, so nothing is hidden.
YLO = -1.2;  YHI = 1.05;
clipv = @(v) max(v, YLO + 0.06);

f = paperFig(PS.f2w*1.15, PS.f2h*1.15);  ax = axes(f); hold(ax,'on');
offIdx = find(rIn < YLO | rOut < YLO);
for j = 1:numel(rIn)
    c = PS.sessColor(sess(j));
    plot(ax, [1 2], [clipv(rIn(j)) clipv(rOut(j))], '-o', 'Color', c, ...
         'MarkerFaceColor', c, 'MarkerSize', 2.5, 'LineWidth', 0.8, 'HandleVisibility','off');
end
% stack the off-scale annotations so two clipped folds cannot overprint each other
for m = 1:numel(offIdx)
    j = offIdx(m);
    text(ax, 1.5, YLO + 0.05 - (m-1)*0.115, ...
         sprintf('%.1f \\rightarrow %.1f', rIn(j), rOut(j)), ...
         'FontSize', PS.fs-1, 'FontWeight', PS.fw, 'Color', PS.sessColor(sess(j)), ...
         'HorizontalAlignment','center', 'VerticalAlignment','top', 'Clipping','off');
end

yline(ax, 0, '--', 'Color',[0.35 0.35 0.35], 'LineWidth', PS.lw_ref, 'HandleVisibility','off');
xlim(ax,[0.8 2.2]); ylim(ax,[YLO YHI]); xticks(ax,[1 2]);
xticklabels(ax, {'in-sample','held out'});
ylabel(ax, 'R^2');
set(ax,'Box','off','TickDir','out','FontSize',PS.fs,'FontWeight',PS.fw);

dR    = rIn - rOut;
nBad  = nnz(rOut < 0);
nBoth = nnz(rOut < 0 & rIn < 0);
ttl = sprintf('%d folds, %d sessions   median %.2f \\rightarrow %.2f   \\Delta %.2f', ...
              numel(rOut), nSess, median(rIn), median(rOut), median(dR));
title(ax, ttl, 'FontSize', PS.fs, 'FontWeight', PS.fw);

paperExport(f, fullfile(outDir,'tf_cv_r2.pdf'));
fprintf('[CV-R2] %d folds | in %.3f -> out %.3f | paired drop %.3f\n', ...
        numel(rOut), median(rIn), median(rOut), median(dR));
fprintf('[CV-R2] %d folds held-out < 0, of which %d ALSO fail in-sample (fit failure, not overfit)\n', ...
        nBad, nBoth);
end
