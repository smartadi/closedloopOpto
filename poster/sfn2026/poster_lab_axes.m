function poster_lab_axes(g, snap)
%POSTER_LAB_AXES  The lab's axis style on a poster panel, keeping the poster's type sizes (2026-11-10).
%   poster_lab_axes(fig)
%   poster_lab_axes(fig, false)   % no SnapSpines: for panels that place labels from the axis limits
% Aditya picked the lab axes for the SfN poster (2026-11-10, from a lab-style Fig 3 he liked). This runs the
% lab's own restyler, sls_style_fig: axis lines 1 pt, ticks in (4 pt), no box, axis ends on the first and
% last tick where nothing drawn falls outside (SnapSpines), grey reference lines 0.5 pt dashed, legends
% and colour bars plain. Diverging maps are left alone (box 5's brown-teal and box 8's red-blue stay).
% Then it puts back the poster type sizes that sls_style_fig resets to the paper's 6 / 7 pt, makes every
% text regular weight, and left-aligns axes titles.
% Invisible axes (overlays holding text and scale bars in cm) are hidden from sls_style_fig: SnapSpines
% would move their limits, and everything placed on them with it.
% The paper keeps the jn style; this is for poster copies only (CLAUDE.md: lab defaults are open choices).
inv = findall(g, 'Type', 'axes', 'Visible', 'off');
hv = arrayfun(@(a) a.HandleVisibility, inv, 'UniformOutput', false);
set(inv, 'HandleVisibility', 'off');
ax = findobj(g, 'Type', 'axes');
fs = arrayfun(@(a) a.FontSize, ax);
lab = cell(numel(ax), 1); lfs = lab;
for k = 1:numel(ax)
    L = [ax(k).XLabel, ax(k).Title];
    for y = 1:numel(ax(k).YAxis), L(end + 1) = ax(k).YAxis(y).Label; end %#ok<AGROW>
    lab{k} = L; lfs{k} = arrayfun(@(t) t.FontSize, L);
end
lg = findobj(g, 'Type', 'legend'); lgs = arrayfun(@(l) l.FontSize, lg);
if nargin < 2, snap = true; end
sls_style_fig(g, 'Diverging', false, 'SnapSpines', snap);
for k = 1:numel(ax)
    ax(k).FontSize = fs(k);
    for j = 1:numel(lab{k}), lab{k}(j).FontSize = lfs{k}(j); end
    if ~isempty(ax(k).Title.String), ax(k).TitleHorizontalAlignment = 'left'; end
end
for k = 1:numel(lg), lg(k).FontSize = lgs(k); end
for k = 1:numel(inv), inv(k).HandleVisibility = hv{k}; end
set(findall(g, 'Type', 'text'), 'FontWeight', 'normal');
set(findall(g, 'Type', 'textboxshape'), 'FontWeight', 'normal');
for t = findall(g, 'Type', 'tiledlayout').'
    set([t.Title t.XLabel t.YLabel], 'FontWeight', 'normal');
end
end
