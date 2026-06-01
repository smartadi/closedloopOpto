function paperAxes(ax, varargin)
% PAPERAXES  Clean axes; optionally draw a corner scale bar.
%
% paperAxes(ax)
%   Applies cleanAxes only — no scale bar.
%
% paperAxes(ax, 'XLength',1, 'YLength',3, 'XLabel','1 s', 'YLabel','3%')
%   Applies cleanAxes, then draws a corner scale bar.
%   Pass only data-space arguments:
%     XLength, YLength, XLabel, YLabel, Corner, Frac, Color
%   Do NOT pass LineWidth / LabelGap / FontSize / FontWeight —
%   these are injected automatically from paperStyle().
%
% Fixes the ordering bug where cleanAxes was called before
% shortCornerAxes_plot: this wrapper always does cleanAxes first.
PS = paperStyle();
cleanAxes(ax);
if ~isempty(varargin)
    shortCornerAxes_plot(ax, varargin{:}, ...
        'LineWidth',  PS.sca_lw, ...
        'LabelGap',   PS.sca_gap, ...
        'FontSize',   PS.fs, ...
        'FontWeight', PS.fw);
end
end
