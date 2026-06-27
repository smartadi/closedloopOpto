% controller-tuning/gain_grid.m
% PAPER FIGURE 1 (secondary analysis): controller-gain GRID cost surface J(Kp,Ki).
% Shows that sweeping a grid of PI controllers yields a cost surface with a clear
% minimum -> justifies the gains used in the main CL analysis.
%
% RUN ORDER: run load_grid.m FIRST (defines workspace struct G), then this script.

if ~exist('G','var')
    error('Run load_grid.m first (G not found in workspace).');
end

setPaperDefaults();
PS = paperStyle();

%% ---- knobs --------------------------------------------------------------
SEL      = 2;                                   % grid session index into G (2 = AL_0033 03-03, 13-node 2D grid)
out_dir  = fullfile('paper','images','tuning');
if ~isfolder(out_dir); mkdir(out_dir); end
g = G(SEL);
tag = sprintf('%s_%s%se%d', g.mn, g.td(6:7), g.td(9:10), g.en);

Kp = g.C(:,1); Ki = g.C(:,2); J = g.J;
[Jmin, im] = min(J);
nKp = numel(unique(Kp)); nKi = numel(unique(Ki));
fprintf('gain_grid: %s | %d nodes (%d Kp x %d Ki) | min J=%.3g at (Kp=%g, Ki=%g)\n', ...
    tag, numel(J), nKp, nKi, Jmin, Kp(im), Ki(im));

%% ---- Figure 1: cost surface / curve ------------------------------------
fig1 = paperFig(6, 5);
ax = axes(fig1); hold(ax,'on');

if nKp > 1 && nKi > 1
    % --- 2D surface: interpolate to a regular grid for a filled contour ---
    try
        upK = linspace(min(Kp), max(Kp), 60);
        upI = linspace(min(Ki), max(Ki), 60);
        [GX,GY] = meshgrid(upK, upI);
        F  = scatteredInterpolant(Kp, Ki, J, 'natural', 'none');
        GZ = F(GX, GY);
        contourf(ax, GX, GY, GZ, 12, 'LineColor','none');
    catch ME
        warning('gain_grid:surfInterp', 'surface interp failed (%s) - showing scatter only.', ME.message);
    end
    scatter(ax, Kp, Ki, 14, J, 'filled', 'MarkerEdgeColor','k', 'LineWidth',0.3);
    plot(ax, Kp(im), Ki(im), 'p', 'MarkerSize',9, ...
        'MarkerFaceColor','w', 'MarkerEdgeColor','k', 'LineWidth',0.6);
    xlabel(ax, 'K_p'); ylabel(ax, 'K_i');
    colormap(ax, parula);
    cb = colorbar(ax); cb.Label.String = 'cost  J'; cb.FontSize = PS.fs;
    cb.Label.FontWeight = PS.fw;
else
    % --- 1D sweep: only one gain varied -> cost curve with SEM ---
    if nKp > 1; xv = Kp; xl = 'K_p'; else; xv = Ki; xl = 'K_i'; end
    [xv, ord] = sort(xv); Js = J(ord); Se = g.Jsem(ord);
    errorbar(ax, xv, Js, Se, '-o', 'Color', PS.col_cl, ...
        'LineWidth', PS.lw_mean, 'MarkerFaceColor', PS.col_cl, 'MarkerSize', 3);
    [~,imc] = min(Js);
    plot(ax, xv(imc), Js(imc), 'p', 'MarkerSize',9, ...
        'MarkerFaceColor','w', 'MarkerEdgeColor','k', 'LineWidth',0.6);
    xlabel(ax, xl); ylabel(ax, 'cost  J');
end
title(ax, sprintf('J(K_p,K_i)  %s', strrep(tag,'_','\_')), 'FontSize', PS.fs, 'FontWeight', PS.fw);
paperExport(fig1, fullfile(out_dir, sprintf('gain_cost_surface_%s.png', tag)));

%% ---- Figure 2 (supplement): per-controller mean response ---------------
% One subplot per grid node: mean dF/F +/- std with setpoint line. Evidence
% behind the cost surface (good gains hold dF/F at ref; poor gains oscillate).
nNodes = numel(J);
nc = ceil(sqrt(nNodes)); nr = ceil(nNodes/nc);
fig2 = paperFig(2.6*nc, 2.2*nr);
tl = tiledlayout(fig2, nr, nc, 'TileSpacing','compact', 'Padding','compact');
tt = g.tt;
for k = 1:nNodes
    axk = nexttile(tl); hold(axk,'on');
    mu = g.nodeMean(k,:); sd = g.nodeStd(k,:);
    good = ~isnan(mu);
    if any(good)
        fill(axk, [tt(good) fliplr(tt(good))], [mu(good)+sd(good) fliplr(mu(good)-sd(good))], ...
            PS.col_cl, 'FaceAlpha', PS.fa, 'EdgeColor','none');
        plot(axk, tt(good), mu(good), 'Color', PS.col_cl, 'LineWidth', PS.lw_mean);
    end
    yline(axk, g.ref, '--', 'Color', PS.col_zero, 'LineWidth', PS.lw_ref);
    xline(axk, 0, 'Color', PS.col_zero, 'LineWidth', PS.lw_zero);
    xline(axk, 3, 'Color', PS.col_zero, 'LineWidth', PS.lw_zero);
    xlim(axk, [tt(1) tt(end)]); ylim(axk, [-8 4]);
    title(axk, sprintf('(%.2g,%.2g) J=%.2g', Kp(k), Ki(k), J(k)), ...
        'FontSize', PS.fs, 'FontWeight', PS.fw);
end
title(tl, sprintf('per-controller mean dF/F   %s', strrep(tag,'_','\_')), ...
    'FontSize', PS.fs, 'FontWeight', PS.fw);
paperExport(fig2, fullfile(out_dir, sprintf('gain_node_traces_%s.png', tag)));

fprintf('gain_grid: exported cost surface + node traces to %s\n', out_dir);
