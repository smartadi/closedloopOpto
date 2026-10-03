function jn_fit_canvas(fig)
%JN_FIT_CANVAS  Shrink a figure's axes until ALL its content sits inside the canvas, so the
%               tight-cropped vector export is no bigger than the size we designed.
%
% WHY: exportgraphics(...,'ContentType','vector') crops the page to the CONTENT bounding box.
% MATLAB positions an axes by its PLOT BOX and happily lets labels sit outside the figure.
% Our panels make this worse on purpose: several draw the y label as a manual rotated text at
% an axes-normalized x of about -0.32, which for a 3.4 cm panel lands ~0.7 cm OUTSIDE the
% canvas. The panel looks right on screen and exports at the wrong size -- imp_response was
% 3.85 cm wide against a 3.40 cm canvas.
%
% MATLAB's own PositionConstraint='outerposition' does NOT fix this: it only accounts for the
% decorations it owns (ticks, xlabel/ylabel/title), not for free-standing text objects. Tried
% first, moved the page by 0.00 cm.
%
% WHAT IT DOES: measure every text/legend/colorbar in figure-normalized units, find how far
% the content spills past each edge, and inset the axes by exactly that much. Text in
% axes-normalized or data units rides along with the axes, so the spill shrinks; iterate a few
% times because moving the axes changes the extents. The plot box gets slightly smaller and
% the panel becomes the size the manifest says it is -- the intended trade.
%
% Applied ONLY to panels measured as oversized (see paper_final_mirror), so panels that
% already fit keep their exact layout.
if nargin < 1 || isempty(fig) || ~isgraphics(fig), return; end

tl = findall(fig, 'Type', 'tiledlayout');
for k = 1:numel(tl)
    try, tl(k).Padding = 'tight'; catch, end
    try, tl(k).TileSpacing = 'tight'; catch, end
end

ax = findall(fig, 'Type', 'axes');
ax = ax(arrayfun(@(a) ~isa(a.Parent,'matlab.graphics.layout.TiledChartLayout'), ax));
if isempty(ax), drawnow; return; end

% Legends and colorbars are placed independently of the axes, so insetting the axes does not
% move them. Clamp them into the canvas first -- tf_cv_single's legend ran 0.58 cm past the
% right edge and was the sole reason that panel exported oversized.
for obj = [findall(fig,'Type','legend'); findall(fig,'Type','colorbar')]'
    try
        obj.Units = 'normalized'; p = obj.Position;
        p(3) = min(p(3), 1); p(4) = min(p(4), 1);
        p(1) = min(max(p(1), 0), 1 - p(3));
        p(2) = min(max(p(2), 0), 1 - p(4));
        obj.Position = p;
    catch
    end
end

% A tiled layout owns its tiles' placement, so insetting individual axes does nothing. Inset
% the LAYOUT's OuterPosition instead, measuring the spill from the tiles it contains.
% (f4_state_exemplars is a 1xN exemplar row and overflowed by 0.33 x 0.26 cm this way.)
for k = 1:numel(tl)
    t = tl(k);
    for iter = 1:5
        drawnow;
        tax = findall(t, 'Type', 'axes');
        [sL, sR, sB, sT] = local_spill(fig, tax);
        if max([sL sR sB sT]) < 0.002, break; end
        try
            t.Units = 'normalized'; op = t.OuterPosition;
            np = [op(1)+sL, op(2)+sB, op(3)-sL-sR, op(4)-sB-sT];
            if np(3) > 0.05 && np(4) > 0.05, t.OuterPosition = np; else, break; end
        catch
            break;
        end
    end
end

for iter = 1:5
    drawnow;
    [dL, dR, dB, dT] = local_spill(fig, ax);
    if max([dL dR dB dT]) < 0.002, break; end          % < 0.2% of the canvas: done
    moved = false;
    for k = 1:numel(ax)
        a = ax(k);
        try
            a.Units = 'normalized';
            p = a.Position;
            np = [p(1)+dL, p(2)+dB, p(3)-dL-dR, p(4)-dB-dT];
            if np(3) > 0.05 && np(4) > 0.05           % never collapse the plot box
                a.Position = np; moved = true;
            end
        catch
        end
    end
    if ~moved, break; end
end
drawnow;
end

% ---------------------------------------------------------------------------------------
function [dL, dR, dB, dT] = local_spill(fig, ax)
% How far the content spills past each edge of the canvas, in figure-normalized units.
x0 = 0; x1 = 1; y0 = 0; y1 = 1;
for k = 1:numel(ax)
    a = ax(k);
    try, a.Units = 'normalized'; ap = a.Position; catch, continue; end

    % Tick labels are drawn by the ruler, NOT as text objects, so the loop below never sees
    % them. TightInset is exactly the margin they (plus xlabel/ylabel/title) need. Without
    % this, tf_cv_2D_sidebar's 0.47 cm of vertical overflow was invisible to the fitter.
    try
        ti = a.TightInset;
        x0 = min(x0, ap(1) - ti(1));  x1 = max(x1, ap(1) + ap(3) + ti(3));
        y0 = min(y0, ap(2) - ti(2));  y1 = max(y1, ap(2) + ap(4) + ti(4));
    catch
    end

    for t = findall(a, 'Type', 'text')'
        s = t.String;
        if isempty(s) || all(cellfun(@(c) isempty(strtrim(char(c))), cellstr(s))), continue; end
        if strcmpi(get(t,'Visible'),'off'), continue; end
        u = t.Units;
        try
            t.Units = 'normalized';                  % normalized to the PARENT AXES
            e = t.Extent;
            t.Units = u;
        catch
            try, t.Units = u; catch, end
            continue;
        end
        % axes-normalized -> figure-normalized
        fx0 = ap(1) + e(1)        * ap(3);   fx1 = ap(1) + (e(1)+e(3)) * ap(3);
        fy0 = ap(2) + e(2)        * ap(4);   fy1 = ap(2) + (e(2)+e(4)) * ap(4);
        if isfinite(fx0) && abs(fx0) < 10    % ignore absurd placements (blank sentinels)
            x0 = min(x0, fx0); x1 = max(x1, fx1);
            y0 = min(y0, fy0); y1 = max(y1, fy1);
        end
    end
end
for obj = [findall(fig,'Type','legend'); findall(fig,'Type','colorbar')]'
    try
        obj.Units = 'normalized'; p = obj.Position;
        x0 = min(x0, p(1)); x1 = max(x1, p(1)+p(3));
        y0 = min(y0, p(2)); y1 = max(y1, p(2)+p(4));
    catch
    end
end
dL = max(0, -x0);  dR = max(0, x1 - 1);
dB = max(0, -y0);  dT = max(0, y1 - 1);
end
