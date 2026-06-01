function checkLayout(widths, heights, total, gap, label)
% checkLayout — verify whether a row of panels fits within available space.
%
% HOW ILLUSTRATOR SCALES:
%   All panels in a row are scaled to a common height (the tallest panel).
%   Widths scale proportionally: scaled_W = W * (row_H / H).
%   This function replicates that logic and reports slack / overflow.
%
% USAGE:
%   checkLayout(widths, heights)              % row, 17 cm figure, 0.3 cm gap
%   checkLayout(widths, heights, total)       % custom total (e.g. 8.1 for right col)
%   checkLayout(widths, heights, total, gap)  % custom gap
%   checkLayout(widths, heights, total, gap, 'Fig2 row1')  % with label
%
% EXAMPLES:
%   checkLayout([5 5 6], [4 4 4], 17, 0.3, 'Fig2 row1')
%   checkLayout([3 3],   [3.5 3], 8.1, 0.3, 'Fig3 right col row1')
%   checkLayout([8.9 8.9 8.9], [4 4 3], 17, 0, 'Fig3 left col — column check, use heights')
%
% FOR COLUMN CHECKS (stacked panels, check total height):
%   Swap the role: pass heights as "widths" and the available column height as "total".
%   checkLayout([4 4 3], [1 1 1], 17, 0.5, 'Fig3 col1 heights')
%   (set all heights=1 so no scaling occurs, just sum the values + gaps)
%
% NOTE: gap is the inter-panel whitespace in the assembled Illustrator figure.
%   Typical: 0.3–0.5 cm between panels in a row; 0.3–0.4 cm between rows.

if nargin < 3 || isempty(total); total = 17;  end
if nargin < 4 || isempty(gap);   gap   = 0.3; end
if nargin < 5 || isempty(label); label = '';  end

n        = numel(widths);
row_h    = max(heights);
scale    = row_h ./ heights;
scaled_w = widths .* scale;
used     = sum(scaled_w) + gap * (n - 1);
slack    = total - used;

if ~isempty(label)
    fprintf('\n=== %s ===\n', label);
else
    fprintf('\n');
end
fprintf('Uniform row height: %.2f cm\n', row_h);
fprintf('%-8s  %-12s  %-8s  %-12s  %-8s\n', ...
    'Panel', 'Export W×H', 'Scale', 'Scaled W×H', 'Source');
for i = 1:n
    fprintf('  #%-4d  %g × %g       ×%.3f    %.2f × %.2f\n', ...
        i, widths(i), heights(i), scale(i), scaled_w(i), row_h);
end
fprintf('  Panels: %.2f cm  +  %d gaps × %.2f = %.2f cm total\n', ...
    sum(scaled_w), n-1, gap, used);
fprintf('  Available: %.2f cm\n', total);
if slack >= 0
    fprintf('  Slack:    +%.2f cm  ✓\n', slack);
else
    pct = 100 * abs(slack) / used;
    fprintf('  OVERFLOW:  %.2f cm  ✗   (shrink each panel by ~%.0f%%)\n', ...
        abs(slack), pct);
    target_h = row_h * (1 - pct/100);
    fprintf('  Fix: scale row height from %.2f → %.2f cm\n', row_h, target_h);
end
end
