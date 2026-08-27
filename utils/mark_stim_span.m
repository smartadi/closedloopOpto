function mark_stim_span(ax, x1, x2, label)
%MARK_STIM_SPAN  Shade a categorical x-span as the stim period on a windowed ratio panel.
%
% The windowed OL/CL ratio panels (variance_ratio_by_window, MSE_ratio_by_window) have four
% category dots -- Pre / 0-1 s / 1-3 s / Post -- and nothing on the panel said the two MIDDLE
% dots are the stimulation window (user, 2026-08-24). This draws a light-grey band behind them
% (same colour as addStimPatch) plus a centred "Stim" label so the stim period is unambiguous.
%
% INPUTS
%   ax     target axes.
%   x1,x2  span in DATA (category) units. Default 1.5 .. 3.5 = the two middle dots of a
%          4-window Pre / 0-1 s / 1-3 s / Post axis.
%   label  text at the top of the band. Default 'Stim'.
%
% Uses patch + text (low-level primitives), so it is safe to call after `hold off`.

if nargin < 2 || isempty(x1),    x1 = 1.5;      end
if nargin < 3 || isempty(x2),    x2 = 3.5;      end
if nargin < 4 || isempty(label), label = 'Stim'; end

yl = ylim(ax);
h  = patch(ax, [x1 x2 x2 x1], [yl(1) yl(1) yl(2) yl(2)], [0.9 0.9 0.9], ...
           'FaceAlpha', 0.3, 'EdgeColor', 'none', 'HandleVisibility', 'off');
uistack(h, 'bottom');
text(ax, (x1+x2)/2, yl(2), label, 'HorizontalAlignment', 'center', ...
     'VerticalAlignment', 'top', 'FontSize', 6, 'FontWeight', 'bold', 'Color', [0.4 0.4 0.4]);
end
