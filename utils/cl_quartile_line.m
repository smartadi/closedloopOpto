function cl_quartile_line(mA, eA, mB, eB, o)
%CL_QUARTILE_LINE  Two-series quartile panel, neuroscience style: points + lines, cropped y-axis.
%
%   Replaces the grouped-bar version of the Fig-4 Part-1 quartile panels (2026-08-13, user:
%   "magnify the difference ... cleaner neuroscience version").
%
%   WHY NOT JUST CROP THE BARS. A bar encodes its value as LENGTH measured from zero, so a bar
%   chart whose axis starts anywhere else misstates every ratio on it -- two bars differing by 10%
%   can be drawn to look 3x apart. That is the single most-flagged figure error in review, and it
%   is not fixed by labelling the axis. A point encodes its value as POSITION, which carries no
%   claim about zero, so a point-and-line plot may be cropped to the data range freely. Switching
%   the mark type is what BUYS the magnification -- it is not a cosmetic change on the way to it.
%
%   The y-axis is therefore fitted to the data (mean +- SEM) with a small pad rather than anchored
%   at 0. For RMSE that is also the honest choice: zero RMSE is not an attainable or meaningful
%   reference here, so the distance from zero was never the quantity of interest -- the spread
%   across quartiles and the gap between conditions are.
%
%   mA,eA / mB,eB   1 x nBins mean and SEM for series A and B
%   o               struct:
%     .lab      {2x1} legend names                 .col   2x3 RGB, row per series
%     .xlab     x-axis label                       .ylab  y-axis label
%     .star     significance annotation ('**', 'n.s.', '' to omit)
%     .legend   true/false (northoutside, horizontal)
%     .file     full path WITHOUT extension        .pdf   true = also write a vector PDF
%     .xticks   {1xnBins} tick labels              (default Q1..Qn)
%
%   See also PAPERFIG, PAPEREXPORT, PAPERLEGEND.

nB = numel(mA);
if ~isfield(o,'xticks') || isempty(o.xticks)
    o.xticks = arrayfun(@(i) sprintf('Q%d',i), 1:nB, 'UniformOutput', false);
end
if ~isfield(o,'pdf'); o.pdf = false; end
if ~isfield(o,'star'); o.star = ''; end

mA=mA(:).'; eA=eA(:).'; mB=mB(:).'; eB=eB(:).';
xq = 1:nB;

fig = paperFig(6,4); ax = gca; hold(ax,'on');

% error bars first so the markers sit on top of them
errorbar(ax, xq, mA, eA, 'LineStyle','none', 'Color',o.col(1,:), 'LineWidth',0.7, ...
    'CapSize',2, 'HandleVisibility','off');
errorbar(ax, xq, mB, eB, 'LineStyle','none', 'Color',o.col(2,:), 'LineWidth',0.7, ...
    'CapSize',2, 'HandleVisibility','off');
hA = plot(ax, xq, mA, '-o', 'Color',o.col(1,:), 'MarkerFaceColor',o.col(1,:), ...
    'MarkerEdgeColor','none', 'MarkerSize',3.5, 'LineWidth',1.0, 'DisplayName',o.lab{1});
hB = plot(ax, xq, mB, '-o', 'Color',o.col(2,:), 'MarkerFaceColor',o.col(2,:), ...
    'MarkerEdgeColor','none', 'MarkerSize',3.5, 'LineWidth',1.0, 'DisplayName',o.lab{2});

% --- the crop: fit to mean +- SEM, then pad. Never anchored at 0. ---
lo = min([mA-eA, mB-eB]);  hi = max([mA+eA, mB+eB]);
pad = 0.14 * max(hi-lo, eps);
ylo = lo - pad;  yhi = hi + pad;
if ~isempty(o.star); yhi = yhi + 0.13*(yhi-ylo); end   % headroom for the star
ylim(ax, [ylo yhi]);
xlim(ax, [0.6 nB+0.4]);

set(ax,'XTick',xq,'XTickLabel',o.xticks,'Box','off','TickDir','out', ...
    'FontSize',6,'FontWeight','bold','LineWidth',0.5);
xlabel(ax, o.xlab, 'FontSize',6,'FontWeight','bold');
ylabel(ax, o.ylab, 'FontSize',6,'FontWeight','bold');

if ~isempty(o.star)
    text(ax, mean(xq), yhi, o.star, 'HorizontalAlignment','center', ...
        'VerticalAlignment','top','FontSize',8,'FontWeight','bold');
end
if isfield(o,'legend') && o.legend
    lg = legend(ax,[hA hB],'Location','northoutside','Orientation','horizontal'); paperLegend(lg);
end

paperExport(fig, [o.file '.png']);
if o.pdf; paperExport(fig, [o.file '.pdf']); end
close(fig);
end
