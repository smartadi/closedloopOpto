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
if ~exist('SEL','var'); SEL = 2; end           % grid session index into G (2 = AL_0033 03-03, 13-node 2D grid); honors a pre-set SEL for batch runs
out_dir  = fullfile('paper','images','tuning');
if exist('GG_OUTDIR','var') && ~isempty(GG_OUTDIR); out_dir = GG_OUTDIR; end   % talk re-export
if ~isfolder(out_dir); mkdir(out_dir); end
% GG_MARKPT = [Kp Ki]: mark THIS point instead of the grid's own minimum (2026-08-19,
% user). Used to drop the ONLINE AUTO-TUNE's converged gains onto the exhaustive cost
% surface -- the two methods are independent, so where the search lands relative to the
% swept basin is the claim, and two stars on one axis would muddle it. The point is not
% a grid node, so it is drawn ON its location (nothing underneath to hide) rather than
% offset the way starOffset treats a node.
if ~exist('GG_MARKPT','var'); GG_MARKPT = []; end
if ~exist('GG_MARKLBL','var'); GG_MARKLBL = 'auto-tune'; end
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
    if isempty(GG_MARKPT)
        % STAR SET OFF THE NODE, NOT ON IT (2026-08-19, user). Drawn on top of the winning
        % node the white star hid the one datum the panel exists to report -- the colour of
        % the minimum. Offset by a fixed fraction of the axis span with a hairline leader.
        starOffset(ax, Kp(im), Ki(im), PS);
    else
        plot(ax, GG_MARKPT(1), GG_MARKPT(2), 'p', 'MarkerSize', 13, ...
            'MarkerFaceColor','w', 'MarkerEdgeColor','k', 'LineWidth', 0.9);
        if ~isempty(GG_MARKLBL)
            % Offset in DATA units, not leading spaces -- a 13 pt star is wider than any
            % space run, and the label sat on top of it.
            text(ax, GG_MARKPT(1) + 0.04*diff(xlim(ax)), GG_MARKPT(2), GG_MARKLBL, ...
                'FontSize', PS.fs, 'FontWeight', PS.fw, 'Color','k', ...
                'HorizontalAlignment','left', 'VerticalAlignment','middle');
        end
        fprintf('gain_grid: marking (%.4g, %.4g) [%s] instead of the grid minimum\n', ...
                GG_MARKPT(1), GG_MARKPT(2), GG_MARKLBL);
    end
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
    starOffset(ax, xv(imc), Js(imc), PS);
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
    xline(axk, g.cwin(2), 'Color', PS.col_zero, 'LineWidth', PS.lw_zero);  % stim-off / cost-window end (4 s for 10-17 dur=4)
    xlim(axk, [tt(1) tt(end)]); ylim(axk, [-8 4]);
    title(axk, sprintf('(%.2g,%.2g) J=%.2g', Kp(k), Ki(k), J(k)), ...
        'FontSize', PS.fs, 'FontWeight', PS.fw);
end
title(tl, sprintf('per-controller mean dF/F   %s', strrep(tag,'_','\_')), ...
    'FontSize', PS.fs, 'FontWeight', PS.fw);
paperExport(fig2, fullfile(out_dir, sprintf('gain_node_traces_%s.png', tag)));

fprintf('gain_grid: exported cost surface + node traces to %s\n', out_dir);
