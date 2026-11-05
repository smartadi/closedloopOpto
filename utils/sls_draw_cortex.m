function h = sls_draw_cortex(ax, varargin)
% SLS_DRAW_CORTEX  Draw the Allen CCF dorsal cortex outlines (lab style repo data).
%
% In mm from bregma (schematics, target maps), setting limits and equal aspect:
%   sls_draw_cortex(ax)
%   hold(ax,'on'); A = sls_atlas(); plot(ax, A.grid(:,1), A.grid(:,2), 'k.')
%
% Over a widefield image, in pixels (limits untouched; rows increase posteriorly):
%   sls_draw_cortex(ax, 'BregmaPx', [col row], 'PxPerMM', pxmm)
%
% Options: 'Color' [0.7 0.7 0.7] | 'LineWidth' 0.5 (0.3 over images) | 'SetLimits' true
%          (mm only) | 'PadMM' 0.3 | 'BregmaAP' 5.40 (atlas mm; 5.20 in LiMatveevEtAl2027)
% Returns the line handles. Accurate to about +/-0.2 mm in AP (bregma varies by subject).
%
% See also SLS_ATLAS.

if nargin < 1 || isempty(ax), ax = gca; end
p = inputParser;
p.addParameter('Color', [0.7 0.7 0.7]);
p.addParameter('LineWidth', []);
p.addParameter('SetLimits', true);
p.addParameter('PadMM', 0.3);
p.addParameter('BregmaAP', 5.40);
p.addParameter('BregmaPx', []);
p.addParameter('PxPerMM', []);
p.parse(varargin{:});
o = p.Results;

A = sls_atlas('BregmaAP', o.BregmaAP);
segs = A.outlines;
inPx = ~isempty(o.BregmaPx);
if inPx
    assert(~isempty(o.PxPerMM), 'sls_draw_cortex:px', 'Give PxPerMM with BregmaPx.');
    bx = o.BregmaPx(1); by = o.BregmaPx(2);
    segs = cellfun(@(s) [s(:,1) * o.PxPerMM + bx, by - s(:,2) * o.PxPerMM], segs, ...
        'UniformOutput', false);
    lw = o.LineWidth; if isempty(lw), lw = 0.3; end
else
    lw = o.LineWidth; if isempty(lw), lw = 0.5; end
end

held = ishold(ax); hold(ax, 'on');
h = gobjects(numel(segs), 1);
for k = 1:numel(segs)
    h(k) = plot(ax, segs{k}(:,1), segs{k}(:,2), '-', 'Color', o.Color, 'LineWidth', lw);
end
uistack(h, 'bottom');
if ~held, hold(ax, 'off'); end

if ~inPx && o.SetLimits
    pts = vertcat(segs{:});
    xlim(ax, [min(pts(:,1)) max(pts(:,1))] + o.PadMM * [-1 1]);
    ylim(ax, [min(pts(:,2)) max(pts(:,2))] + o.PadMM * [-1 1]);
    daspect(ax, [1 1 1]);
end
end
