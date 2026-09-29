function jnAxes(ax)
% JNAXES  Apply the JNeurosci axes/font/line style to one axes (call after drawing).
% Arial; tick labels 6 pt regular; axis labels + title 7 pt bold; thin ticks out; box off.
if nargin < 1 || isempty(ax); ax = gca; end
S = jnStyle();
set(ax, 'FontName',S.font, 'FontSize',S.fs_tick, 'FontWeight',S.fw_tick, ...
    'TickDir','out', 'Box','off', 'LineWidth',S.lw_axis, 'TickLength',[0.02 0.02]);
lab = [ax.XLabel, ax.YLabel];
set(lab, 'FontName',S.font, 'FontSize',S.fs_label, 'FontWeight',S.fw_label);
set(ax.Title, 'FontName',S.font, 'FontSize',S.fs_label, 'FontWeight',S.fw_label);
end
