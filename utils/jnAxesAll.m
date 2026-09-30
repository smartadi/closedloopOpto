function jnAxesAll(fig)
% JNAXESALL  Apply jnAxes (the JNeurosci rule book style) to EVERY axes in a figure.
%
% Rule-book compliance pass for panels that are still drawn with paperFig/paperStyle:
% call it once, after all drawing and after any local set(ax,...) calls, immediately
% before paperExport. It re-imposes Arial, tick labels 6 pt regular, axis labels and
% title 7 pt bold, ticks out, box off, axis line 0.5 pt -- see paper/FIGURE_RULEBOOK.md
% sections 3 and 4.
%
% Why this exists: Figs 2/3/5 were built on paperStyle, which uses ONE font size (6 pt
% bold) for ticks, labels and titles, and heavier line weights than the rule book. Fig 4
% was built natively on jn*. Rather than refactor every call site, this restyles the
% finished figure so all four figures land on the same spec.
%
% Note it does NOT touch line weights of already-drawn objects -- those come from
% paperStyle's lw_* constants, which were brought onto the rule-book values directly.
%
% Usage:  jnAxesAll(fig);  paperExport(fig, path);

if nargin < 1 || isempty(fig); fig = gcf; end
ax = findobj(fig, 'Type', 'axes');
for k = 1:numel(ax)
    jnAxes(ax(k));
end
end
