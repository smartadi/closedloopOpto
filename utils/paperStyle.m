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

% --- per-session palette: sequential colour GRADIENT (default) ---
% Sessions are ordered, so a single-hue gradient (dark navy -> light cyan)
% distinguishes them AND is colourblind-/greyscale-safe (monotonic lightness).
% PS.sessGrad(n) samples n colours along the ramp, so it scales to any N.
PS.grad0    = [0.09 0.16 0.42];   % dark end  (session 1)
PS.grad1    = [0.40 0.76 0.88];   % light end (session N)
PS.sessGrad = @(n) interp1([0 1], [PS.grad0; PS.grad1], linspace(0,1,max(n,2)));
PS.sess     = PS.sessGrad(3);     % default 3-session gradient

% Legacy qualitative palettes kept for reference / older scripts.
PS.sess_rgb = [0.20 0.40 0.80; 0.80 0.20 0.20; 0.20 0.80 0.40];  % blue/red/green
PS.sess_cb  = [0.106 0.620 0.467; 0.851 0.373 0.008; 0.459 0.439 0.702]; % Dark2

global PAPER_CB
% The gradient is itself CB-safe, so the toggle no longer swaps palettes; it
% only appends '_cb' to filenames for anyone producing a tagged variant.
if ~isempty(PAPER_CB) && PAPER_CB
    PS.cb = true;   PS.cbtag = '_cb';
else
    PS.cb = false;  PS.cbtag = '';
end

% --- legend ---
PS.lgd_token = [6 6];   % ItemTokenSize for all legends

% --- axes defaults (for setPaperDefaults) ---
PS.ax_box     = 'off';
PS.ax_tickdir = 'out';
end
