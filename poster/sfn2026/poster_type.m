function poster_type(g)
%POSTER_TYPE  The SfN 2026 poster's type and line standard, applied to a finished figure (2026-11-10).
%   poster_type(fig)
% Sizes are at the panel's print size; the poster prints panels at PS = 2.97, so on the poster:
%   tick labels, legends     FT = 7 pt    (~21 pt)
%   axis labels, notes       FA = 7.5 pt  (~22 pt); any text below this is raised to it
%   titles                   FL = 8 pt    (~24 pt)
%   lines >= 0.6 pt, markers +20% (scatter area +44%).
% The paper's panels print at 5-6 pt (15-18 pt on the poster). Box 5 (seedfc_panel.m) set this standard.
% Used by poster_restyle.m (saved paper figures) and sine_panels.m. Layout fixes stay with the caller.
FT = 7; FA = 7.5; FL = 8;
for a = findall(g, 'Type', 'axes').'
    a.FontSize = FT;
    for lb = [a.XLabel a.YLabel]
        if ~isempty(lb.String), lb.FontSize = FA; end
    end
    if ~isempty(a.Title.String), a.Title.FontSize = FL; end
end
for t = findall(g, 'Type', 'tiledlayout').'
    for lb = [t.Title t.XLabel t.YLabel]
        if ~isempty(lb.String), lb.FontSize = FL; end
    end
end
for t = findall(g, 'Type', 'text').'
    if t.FontSize < FA && ~is_axis_label(t), t.FontSize = FA; end
end
for lg = findall(g, 'Type', 'legend').', lg.FontSize = FT; end
for cb = findall(g, 'Type', 'colorbar').', cb.FontSize = FT; cb.Label.FontSize = FA; end
for ln = findall(g, 'Type', 'line').'
    ln.LineWidth = max(ln.LineWidth, 0.6);
    if ~strcmp(ln.Marker, 'none'), ln.MarkerSize = ln.MarkerSize * 1.2; end
end
for eb = findall(g, 'Type', 'errorbar').', eb.LineWidth = max(eb.LineWidth, 0.6); eb.MarkerSize = eb.MarkerSize * 1.2; end
for sc = findall(g, 'Type', 'scatter').', sc.SizeData = sc.SizeData * 1.44; end
end

function tf = is_axis_label(t)
p = t.Parent;
tf = isa(p, 'matlab.graphics.axis.Axes') && any(t == [p.XLabel p.YLabel p.Title]);
end
