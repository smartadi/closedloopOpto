function PS = paperStyle()
% PAPERSTYLE  Shared style constants for all paper figures.
% Usage:  PS = paperStyle();
%         plot(ax, x, y, 'Color', col, 'LineWidth', PS.lw_mean);
%         shortCornerAxes_plot(ax, 'XLength', 1, 'YLength', 3, ...
%             'XLabel', '1 s', 'YLabel', '3%', ...
%             'LineWidth', PS.sca_lw, 'LabelGap', PS.sca_gap, ...
%             'FontSize', PS.fs, 'FontWeight', PS.fw);

% --- line widths ---
PS.lw_mean  = 1.5;   % mean / average trace
PS.lw_fit   = 1.2;   % TF fit or prediction
PS.lw_trial = 0.4;   % individual trial traces
PS.lw_ref   = 1.0;   % dashed reference line
PS.lw_inp   = 0.75;  % input / laser trace
PS.lw_zero  = 0.5;   % zero / baseline line

% --- text ---
PS.fs = 6;       % font size (pt)
PS.fw = 'bold';  % font weight

% --- shading ---
PS.fa = 0.2;     % FaceAlpha for ±std ribbon

% --- shortCornerAxes_plot ---
PS.sca_lw  = 1.5;   % LineWidth
PS.sca_gap = 0.05;  % LabelGap
end
