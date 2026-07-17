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

% --- canonical color palette ---
PS.col_ol     = [1   0   0  ];   % open-loop mean trace
PS.col_cl     = [0  0.5  0  ];   % closed-loop mean trace
PS.col_inp_ol = [1   0   1  ];   % OL laser input
PS.col_inp_cl = [0  0.5  1  ];   % CL laser input
PS.col_fit    = [0.2 0.4 0.8];   % TF fit / model prediction
PS.col_zero   = [0   0   0  ];   % zero / reference line

% --- per-session palette (3 sessions) with a colorblind-safe alternate ---
% Toggle with a base-workspace global:  global PAPER_CB; PAPER_CB = true;
% Legacy = blue/red/green (red-green is not colorblind-safe).
% CB alternate = ColorBrewer Dark2 (teal/orange/purple), flagged colorblind-safe.
PS.sess_rgb = [0.20 0.40 0.80;    % S1 blue
               0.80 0.20 0.20;    % S2 red
               0.20 0.80 0.40];   % S3 green
PS.sess_cb  = [0.106 0.620 0.467; % S1 teal   (#1b9e77)
               0.851 0.373 0.008; % S2 orange (#d95f02)
               0.459 0.439 0.702];% S3 purple (#7570b3)
global PAPER_CB
if ~isempty(PAPER_CB) && PAPER_CB
    PS.sess = PS.sess_cb;  PS.cb = true;   PS.cbtag = '_cb';
else
    PS.sess = PS.sess_rgb; PS.cb = false;  PS.cbtag = '';
end

% --- legend ---
PS.lgd_token = [6 6];   % ItemTokenSize for all legends

% --- axes defaults (for setPaperDefaults) ---
PS.ax_box     = 'off';
PS.ax_tickdir = 'out';
end
