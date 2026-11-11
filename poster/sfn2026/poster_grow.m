function s = poster_grow(g, name)
%POSTER_GROW  Type and lines for a poster panel that is placed larger than the print scale (SfN poster v7).
%   s = poster_grow(fig, name)
% Aditya (2026-11-10): the space the bullets left in boxes 3 and 4 goes to larger panels. poster_swap_all.py
% places panel <name> at PS * s instead of PS. So that its type, lines and markers still print at the poster
% standard (poster_type.m), this scales them by 1/s; the geometry is untouched, so the plots print s times
% larger. Run it after poster_type, poster_lab_axes and the panel's own fixes, just before printing.
% Writes panels/poster/<name>_raw.grow holding s, which poster_swap_all.py reads (deleted when s = 1).
% The same as box 2's shrink_type (fig2_jn_panels.m), with legend line samples too.
% Approved by Aditya 2026-11-10: "Approve".
G = struct('cl_trial', 1.10, 'cl_rmse', 1.10, 'cl_avg', 1.10, 'cl_var', 1.10, ...
           'sine_avg', 1.10, 'sine_lag', 1.15, 'sine_rmse', 1.15, 'sine_var', 1.15);
s = 1;
if isfield(G, name), s = G.(name); end
side = fullfile(fileparts(mfilename('fullpath')), 'panels', 'poster', [name '_raw.grow']);
if s == 1
    if isfile(side), delete(side); end
    return
end
k = 1 / s;
h = findall(g, '-property', 'FontSize');
sz = arrayfun(@(o) o.FontSize, h);                 % read every size first: an axes' FontSize change rescales
for j = 1:numel(h), h(j).FontSize = sz(j) * k; end % its labels, which must not be scaled twice
for o = findall(g, '-property', 'LineWidth').', o.LineWidth = o.LineWidth * k; end
for o = findall(g, '-property', 'MarkerSize').', o.MarkerSize = o.MarkerSize * k; end
for o = findall(g, 'Type', 'scatter').', o.SizeData = o.SizeData * k^2; end
for o = findall(g, 'Type', 'errorbar').', o.CapSize = o.CapSize * k; end
for o = findall(g, 'Type', 'legend').', o.ItemTokenSize = o.ItemTokenSize * k; end
for a = findall(g, 'Type', 'axes').', a.TickLength = a.TickLength * k; end
fid = fopen(side, 'w'); fprintf(fid, '%.4f', s); fclose(fid);
end
