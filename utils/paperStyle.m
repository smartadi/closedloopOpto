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
PS.col_ol     = [1    0    0   ];  % open-loop response  (red)
PS.col_cl     = [0    0.40 0.85];  % closed-loop response (blue; was green, 2026-07-23)
% Input command = fixed gray on every panel (context, not a compared quantity);
% mode colour is reserved for the response. Both OL/CL inputs share the gray.
PS.col_inp_ol = [0.55 0.55 0.55];  % OL laser input (gray)
PS.col_inp_cl = [0.55 0.55 0.55];  % CL laser input (gray)
PS.col_fit    = [0.2 0.4 0.8];   % TF fit / model prediction
PS.col_zero   = [0   0   0  ];   % zero / reference line

% --- per-session palette: sequential colour GRADIENT (default) ---
% Sessions are ordered, so a single-hue gradient (dark navy -> light cyan)
% distinguishes them AND is colourblind-/greyscale-safe (monotonic lightness).
% PS.sessGrad(n) samples n colours along the ramp, so it scales to any N.
PS.grad0    = [0.09 0.16 0.42];   % dark end  (session 1)
PS.grad1    = [0.40 0.76 0.88];   % light end (session N)
PS.sessGrad = @(n) interp1([0 1], [PS.grad0; PS.grad1], linspace(0,1,max(n,2)));
% *** SESSION COLOUR IS NOW FIXED BY INDEX, NOT BY HOW MANY ARE PLOTTED (2026-08-12). ***
% PS.sessGrad(n) RESAMPLES the ramp, so session 1 in a 3-session panel came out a different
% shade from session 1 in a 4-session panel -- which is what made 2C-i disagree with the
% other Fig-2 panels once AL_0048 was added as the 4th impulse session. Anchor the ramp at
% PS.NSESS and index into it by SESSION NUMBER, so session k is the same colour everywhere
% regardless of how many sessions a given panel happens to draw.
%   use:  c = PS.sessColor(k)     NOT   CS = PS.sessGrad(n); c = CS(k,:)
PS.NSESS     = 4;                          % impulse session count (AL_0041 x2, AL_0033, AL_0048)
PS.sessFix   = PS.sessGrad(PS.NSESS);
PS.sessColor = @(k) PS.sessFix(min(max(round(k),1), size(PS.sessFix,1)), :);
PS.sess      = PS.sessFix;        % default palette, indexed by session number

% --- per-session palette: QUALITATIVE (use when identity matters more than order) ---
% The gradient above encodes ORDER, which is right for a time/dose series but wrong
% for panels whose whole job is "which line is which session" -- at n>=4 a single-hue
% ramp is genuinely hard to read back off the page (user, 2026-08-10). Okabe-Ito is
% the standard 8-colour set that stays distinguishable under all three common forms
% of colour-blindness; the order below front-loads the pairs with the largest
% hue AND lightness separation, so n=2..4 (the usual case) is maximally legible.
PS.okabe    = [0.000 0.447 0.698;   % blue
               0.835 0.369 0.000;   % vermillion
               0.000 0.620 0.451;   % bluish green
               0.800 0.475 0.655;   % reddish purple
               0.902 0.624 0.000;   % orange
               0.337 0.706 0.914;   % sky blue
               0.494 0.184 0.556];  % purple (extra, beyond Okabe-Ito)
PS.sessQual = @(n) PS.okabe(mod((0:max(n,1)-1), size(PS.okabe,1)) + 1, :);

% --- sequential colormap for R^2 / correlation heatmaps (replaces flipud(gray)) ---
% Same navy family as the session gradient: near-white at 0, deep navy at 1.
% Monotonic in lightness, so it still reads correctly if printed in greyscale.
PS.cmapSeq = @(m) interp1([0 0.5 1], [0.972 0.980 1.000; 0.404 0.616 0.812; 0.055 0.129 0.353], ...
                          linspace(0,1,max(m,2)));

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
