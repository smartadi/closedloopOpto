% controller-tuning/auto_tune.m
% PAPER FIGURE 2 (secondary analysis): AUTO-TUNING convergence.
% Zero-order / model-free optimization adapts (Kp,Ki) online; the stored gain
% trajectory + per-trial cost show the controller converging toward low cost
% (ideally the same region as the grid minimum in gain_grid.m).
%
% RUN ORDER: run load_grid.m FIRST (defines workspace struct A), then this script.

if ~exist('A','var')
    error('Run load_grid.m first (A not found in workspace).');
end

setPaperDefaults();
PS = paperStyle();

%% ---- knobs --------------------------------------------------------------
if ~exist('SEL','var'); SEL = 1; end            % auto-tune session index into A; honors a pre-set SEL for batch runs
out_dir = fullfile('paper','images','tuning');
if ~isfolder(out_dir); mkdir(out_dir); end
a = A(SEL);
tag = sprintf('%s_%s%se%d', a.mn, a.td(6:7), a.td(9:10), a.en);

trial = a.trial; Kp = a.Kp; Ki = a.Ki; cost = a.costTr; gate = a.gate;
valid = gate & ~isnan(cost);

% running-best cost over evaluated (gated) trials
bestCost = nan(size(cost));
cur = inf;
for j = 1:numel(cost)
    if valid(j) && cost(j) < cur; cur = cost(j); end
    bestCost(j) = cur;
end
[~, jStar] = min(cost + ~valid*1e9);            % trial achieving global min cost
fprintf('auto_tune: %s | %d trials | converged ~ (Kp=%g, Ki=%g) cost=%.3g at trial %d\n', ...
    tag, numel(trial), Kp(jStar), Ki(jStar), cost(jStar), trial(jStar));

%% ---- Figure: gains + cost vs iteration ---------------------------------
fig = paperFig(6, 6);
tl  = tiledlayout(fig, 2, 1, 'TileSpacing','compact', 'Padding','compact');

% (top) gain trajectory: Kp left axis, Ki right axis
ax1 = nexttile(tl);
yyaxis(ax1,'left');
plot(ax1, trial, Kp, '-', 'Color', PS.col_cl, 'LineWidth', PS.lw_mean);
ylabel(ax1, 'K_p'); ax1.YColor = PS.col_cl;
yyaxis(ax1,'right');
plot(ax1, trial, Ki, '-', 'Color', PS.col_fit, 'LineWidth', PS.lw_mean);
ylabel(ax1, 'K_i'); ax1.YColor = PS.col_fit;
xline(ax1, trial(jStar), ':', 'Color', PS.col_zero, 'LineWidth', PS.lw_zero);
xlim(ax1, [trial(1) trial(end)]);
title(ax1, sprintf('auto-tune  %s', strrep(tag,'_','\_')), 'FontSize', PS.fs, 'FontWeight', PS.fw);

% (bottom) per-trial cost + running best
ax2 = nexttile(tl); hold(ax2,'on');
plot(ax2, trial(~valid), cost(~valid), 'o', 'MarkerSize',2.5, ...
    'MarkerEdgeColor',[0.7 0.7 0.7], 'HandleVisibility','off');     % gated-out, faint
plot(ax2, trial(valid),  cost(valid),  'o', 'MarkerSize',2.5, ...
    'MarkerFaceColor',[0.4 0.4 0.4], 'MarkerEdgeColor','none');     % evaluated
plot(ax2, trial, bestCost, '-', 'Color', PS.col_cl, 'LineWidth', PS.lw_mean);
plot(ax2, trial(jStar), cost(jStar), 'p', 'MarkerSize',9, ...
    'MarkerFaceColor','w', 'MarkerEdgeColor','k', 'LineWidth',0.6);
xlim(ax2, [trial(1) trial(end)]);
xlabel(ax2, 'trial (iteration)'); ylabel(ax2, 'cost  J');
lg = legend(ax2, {'per-trial','running best'}, 'Box','off', ...
    'Location','northeast', 'FontSize', PS.fs);
lg.ItemTokenSize = PS.lgd_token;

paperExport(fig, fullfile(out_dir, sprintf('autotune_convergence_%s.png', tag)));
fprintf('auto_tune: exported convergence figure to %s\n', out_dir);
