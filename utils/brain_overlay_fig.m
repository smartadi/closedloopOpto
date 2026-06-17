function [fig, ax_bg, ax_ov] = brain_overlay_fig(mimg, w_cm, h_cm, ax_pos)
% Gray brain background + transparent overlay axes for kernel maps.
if nargin < 4; ax_pos = [0.06 0.08 0.70 0.84]; end
fig   = figure('Color','w','Units','centimeters','Position',[2 2 w_cm h_cm]);
ax_bg = axes(fig,'Position',ax_pos);
imagesc(ax_bg, mimg'); colormap(ax_bg, gray);
clim(ax_bg, [prctile(mimg(:),1), prctile(mimg(:),99)]);
axis(ax_bg,'image','off');
ax_ov           = axes(fig,'Position',ax_bg.Position);
ax_ov.Color     = 'none';
ax_ov.XLim      = ax_bg.XLim;
ax_ov.YLim      = ax_bg.YLim;
ax_ov.YDir      = 'reverse';
ax_ov.XLimMode  = 'manual';
ax_ov.YLimMode  = 'manual';
set(ax_ov,'XTick',[],'YTick',[],'Box','off');
hold(ax_ov,'on');
end
