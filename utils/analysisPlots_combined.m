function analysisPlots_combined(data, d)
% Two combined paper figures:
%   Fig 1 (combined_trials.png)       – 3-row × 2-col, rows labelled A/B/C
%     Row A: single trial example     (OL left | CL right)
%     Row B: all trials + average     (OL left | CL right)
%     Row C: average inputs (short)   (OL left | CL right)
%   Fig 2 (combined_variance_MSE.png) – 2-row × 1-col (portrait)
%     A: variance over time | B: MSE half-violin + scatter
%
% Figure sizes set to exact print dimensions (2/3 + 1/3 of 7" page width):
%   fig1 = 4.67 x 6.5 in  |  fig2 = 2.33 x 6.5 in
% Use width=\linewidth inside each subfigure in LaTeX; scale factor = 1.
ss = 1.0;
dur    = d.params.dur;
t      = d.timeBlue;
tt     = d.inpTime;
v      = d.inpVals;

dFk    = data.dFk;
nc     = data.nc;
wc     = data.wc;
pncDfk = data.pncDfk(:, 246:end);
pwcDfk = data.pwcDfk(:, 246:end);
nc_inp = data.ncInp;
wc_inp = data.wcInp;

nc_avg = mean(pncDfk, 1);
wc_avg = mean(pwcDfk, 1);

trial = 10;

T    = -3:0.0285:dur+3;
Tref = 0:1/35:dur;
Tin  = 0:0.0005:dur;

colOL    = [1 0 0];
colCL    = [0 0.5 0];
colInpOL = [1 0 1];
colInpCL = [0 0.5 1];
x1 = 0; x2 = dur;

% Single trial index lookup
jnc = nc(trial);
[~, i_nc]  = min(abs(t  - d.stimStarts(jnc)));
[~, k_nc]  = min(abs(tt - d.stimStarts(jnc)));
[~, k2_nc] = min(abs(tt - d.stimEnds(jnc)));

jwc = wc(trial);
[~, i_wc]  = min(abs(t  - d.stimStarts(jwc)));
[~, k_wc]  = min(abs(tt - d.stimStarts(jwc)));
[~, k2_wc] = min(abs(tt - d.stimEnds(jwc)));


%% Figure 1: 3-row x 2-col ------------------------------------------

fig1 = figure('Color','w');
fig1.Units    = 'inches';
fig1.Position = [1 1 4.67/ss 6.5/ss];

% Normalized layout: margins, gaps, column/row sizes
lm = 0.07; rm = 0.02; bm = 0.05; tm = 0.04;
cg = 0.01; rg = 0.05;
cW   = (1 - lm - rm - cg) / 2;
c1L  = lm;
c2L  = lm + cW + cg;
avH  = 1 - bm - tm - 2*rg;
rH3  = avH / 5;        % input row  (~20%)
rH12 = avH * 2 / 5;   % signal rows (~40% each)
r3B  = bm;
r2B  = r3B + rH3 + rg;
r1B  = r2B + rH12 + rg;

ax_A = axes(fig1, 'Position', [c1L r1B cW rH12]);
ax_B = axes(fig1, 'Position', [c2L r1B cW rH12]);
ax_C = axes(fig1, 'Position', [c1L r2B cW rH12]);
ax_D = axes(fig1, 'Position', [c2L r2B cW rH12]);
ax_E = axes(fig1, 'Position', [c1L r3B cW rH3]);
ax_F = axes(fig1, 'Position', [c2L r3B cW rH3]);

% ---- A: OL single trial ----
hold(ax_A, 'on');
plot(ax_A, T, zeros(1,length(T)), 'k', 'LineWidth', 0.5, 'HandleVisibility','off');
plot(ax_A, tt(k_nc:k2_nc)-tt(k_nc), 5*v(k_nc:k2_nc), ...
    'Color', colInpOL, 'LineWidth', 0.75, 'HandleVisibility','off');
plot(ax_A, T, dFk((i_nc-3*35):(i_nc+35*(dur+3))), ...
    'Color', colOL, 'LineWidth', 1.5, 'HandleVisibility','off');
plot(ax_A, Tref, d.ref*ones(1,length(Tref)), '--k', 'LineWidth', 1, 'HandleVisibility','off');
xline(ax_A, 0, 'HandleVisibility','off');
xline(ax_A, dur, 'HandleVisibility','off');
ylim(ax_A, [-10 10]); xlim(ax_A, [-3 dur+3]);
addStimPatch(ax_A, x1, x2);
line(ax_A, [0 0], [6 8], 'Color', colInpOL, 'LineWidth', 1.5, ...
    'Clipping','off', 'HandleVisibility','off');
text(ax_A, -0.1, 7, '1 mW', 'Color', colInpOL, 'FontSize', 6, ...
    'HorizontalAlignment','right', 'VerticalAlignment','middle', 'Clipping','off');
uistack(findobj(ax_A,'Type','line'), 'top');
hold(ax_A, 'off');
shortCornerAxes_plot(ax_A, 'XLength', 1, 'YLength', 3, ...
    'XLabel', '1 sec', 'YLabel', '3% dF/F', 'LineWidth', 2.5, 'LabelGap', 0.04);
cleanAxes(ax_A);
text(ax_A, -0.08, 0.95, 'A', 'Units','normalized', 'FontSize', 9, ...
    'FontWeight','bold', 'Clipping','off');

% ---- B: CL single trial + legend ----
hold(ax_B, 'on');
plot(ax_B, T, zeros(1,length(T)), 'k', 'LineWidth', 0.5, 'HandleVisibility','off');
plot(ax_B, tt(k_wc:k2_wc)-tt(k_wc), 4*v(k_wc:k2_wc), ...
    'Color', colInpCL, 'LineWidth', 0.75, 'HandleVisibility','off');
hOL_s  = plot(ax_B, NaN, NaN, 'Color', colOL, 'LineWidth', 1.5);
hCL_s  = plot(ax_B, T, dFk((i_wc-3*35):(i_wc+35*(dur+3))), ...
    'Color', colCL, 'LineWidth', 1.5);
hRef_s = plot(ax_B, Tref, d.ref*ones(1,length(Tref)), '--k', 'LineWidth', 1);
xline(ax_B, 0, 'HandleVisibility','off');
xline(ax_B, dur, 'HandleVisibility','off');
ylim(ax_B, [-10 10]); xlim(ax_B, [-3 dur+3]);
addStimPatch(ax_B, x1, x2);
uistack(findobj(ax_B,'Type','line'), 'top');
legend(ax_B, [hOL_s hCL_s hRef_s], {'Open-Loop','Closed-Loop','Ref'}, ...
    'Location','northeast', 'Box','off', 'FontSize', 7, 'FontWeight','bold');
hold(ax_B, 'off');
cleanAxes(ax_B);
text(ax_A, 3*dur/4, 4, 'OL Stim', 'Color', colInpOL, 'FontSize', 6, ...
    'HorizontalAlignment','center', 'FontWeight','bold', 'Clipping','off');
text(ax_B, 3*dur/4, 4, 'CL Stim', 'Color', colInpCL, 'FontSize', 6, ...
    'HorizontalAlignment','center', 'FontWeight','bold', 'Clipping','off');

% ---- C: OL all trials + average ----
hold(ax_C, 'on');
plot(ax_C, T, zeros(1,length(T)), 'k', 'LineWidth', 0.5, 'HandleVisibility','off');
plot(ax_C, T, pncDfk, 'Color', [colOL 0.1], 'LineWidth', 0.5, 'HandleVisibility','off');
plot(ax_C, Tref, d.ref*ones(1,length(Tref)), '--k', 'LineWidth', 1, 'HandleVisibility','off');
plot(ax_C, T, nc_avg, 'Color', colOL, 'LineWidth', 1.5, 'HandleVisibility','off');
xline(ax_C, 0, 'HandleVisibility','off');
xline(ax_C, dur, 'HandleVisibility','off');
ylim(ax_C, [-10 10]); xlim(ax_C, [-3 dur+3]);
addStimPatch(ax_C, x1, x2);
uistack(findobj(ax_C,'Type','line'), 'top');
hold(ax_C, 'off');
shortCornerAxes_plot(ax_C, 'XLength', 0.01, 'YLength', 3, ...
    'XLabel', ' ', 'YLabel', '3% dF/F', 'LineWidth', 2.5, 'LabelGap', 0.04);
cleanAxes(ax_C);
text(ax_C, -0.08, 0.95, 'B', 'Units','normalized', 'FontSize', 9, ...
    'FontWeight','bold', 'Clipping','off');

% ---- D: CL all trials + average ----
hold(ax_D, 'on');
plot(ax_D, T, zeros(1,length(T)), 'k', 'LineWidth', 0.5, 'HandleVisibility','off');
plot(ax_D, T, pwcDfk, 'Color', [colCL 0.1], 'LineWidth', 0.5, 'HandleVisibility','off');
plot(ax_D, Tref, d.ref*ones(1,length(Tref)), '--k', 'LineWidth', 1, 'HandleVisibility','off');
plot(ax_D, T, wc_avg, 'Color', colCL, 'LineWidth', 1.5, 'HandleVisibility','off');
xline(ax_D, 0, 'HandleVisibility','off');
xline(ax_D, dur, 'HandleVisibility','off');
ylim(ax_D, [-10 10]); xlim(ax_D, [-3 dur+3]);
addStimPatch(ax_D, x1, x2);
uistack(findobj(ax_D,'Type','line'), 'top');
hold(ax_D, 'off');
cleanAxes(ax_D);

% ---- E: OL average input ----
hold(ax_E, 'on');
plot(ax_E, T, zeros(1,length(T)), 'k', 'LineWidth', 0.5, 'HandleVisibility','off');
plot(ax_E, Tin, 3*nc_inp, 'Color', [colInpOL 0.1], 'LineWidth', 0.5, 'HandleVisibility','off');
plot(ax_E, Tin, 3*mean(nc_inp), 'Color', colInpOL, 'LineWidth', 1.5, 'HandleVisibility','off');
plot(ax_E, Tref, d.ref*ones(1,length(Tref)), '--k', 'LineWidth', 1, 'HandleVisibility','off');
xline(ax_E, 0, 'HandleVisibility','off');
xline(ax_E, dur, 'HandleVisibility','off');
ylim(ax_E, [-2 5]); xlim(ax_E, [-3 dur+3]);
addStimPatch(ax_E, x1, x2);
uistack(findobj(ax_E,'Type','line'), 'top');
hold(ax_E, 'off');
shortCornerAxes_plot(ax_E, 'XLength', 0.01, 'YLength', 2, ...
    'XLabel', ' ', 'YLabel', '1 mW', 'LineWidth', 2.5, 'LabelGap', 0.08);
cleanAxes(ax_E);
text(ax_E, -0.08, 0.95, 'C', 'Units','normalized', 'FontSize', 9, ...
    'FontWeight','bold', 'Clipping','off');

% ---- F: CL average input ----
hold(ax_F, 'on');
plot(ax_F, T, zeros(1,length(T)), 'k', 'LineWidth', 0.5, 'HandleVisibility','off');
plot(ax_F, Tin, 3*wc_inp, 'Color', [colInpCL 0.05], 'LineWidth', 0.5, 'HandleVisibility','off');
plot(ax_F, Tin, 3*mean(wc_inp), 'Color', colInpCL, 'LineWidth', 1.5, 'HandleVisibility','off');
plot(ax_F, Tref, d.ref*ones(1,length(Tref)), '--k', 'LineWidth', 1, 'HandleVisibility','off');
xline(ax_F, 0, 'HandleVisibility','off');
xline(ax_F, dur, 'HandleVisibility','off');
ylim(ax_F, [-2 5]); xlim(ax_F, [-3 dur+3]);
addStimPatch(ax_F, x1, x2);
uistack(findobj(ax_F,'Type','line'), 'top');
hold(ax_F, 'off');
cleanAxes(ax_F);

% Column header labels
annotation(fig1, 'textbox', ...
    [c1L + cW/2 - 0.07, r1B + rH12 + 0.005, 0.14, 0.03], ...
    'String', 'Open-Loop', 'FontSize', 9, 'FontWeight','bold', ...
    'EdgeColor','none', 'HorizontalAlignment','center', 'VerticalAlignment','middle');
annotation(fig1, 'textbox', ...
    [c2L + cW/2 - 0.07, r1B + rH12 + 0.005, 0.14, 0.03], ...
    'String', 'Closed-Loop', 'FontSize', 9, 'FontWeight','bold', ...
    'EdgeColor','none', 'HorizontalAlignment','center', 'VerticalAlignment','middle');

linkaxes([ax_A ax_B ax_C ax_D ax_E ax_F], 'x');
exportgraphics(fig1, 'paper/combined_trials.png', 'Resolution', 300);


%% Figure 2: Variance + MSE -----------------------------------------

fig2 = figure('Color','w');
fig2.Units    = 'inches';
fig2.Position = [1 1 2.33/ss 6.5/ss];

% Stacked portrait: variance on top, MSE below
lm2 = 0.13; rm2 = 0.05; bm2 = 0.05; tm2 = 0.04;
rg2  = 0.07;
panW = 1 - lm2 - rm2;
avH2 = 1 - bm2 - tm2 - rg2;
varH = avH2 * 0.55;
mseH = avH2 * 0.45;
mseB = bm2;
varB = bm2 + mseH + rg2;

ax_var = axes(fig2, 'Position', [lm2 varB panW varH]);
ax_mse = axes(fig2, 'Position', [lm2 mseB panW mseH]);

% ---- A: Variance over time ----
nc_var = var(pncDfk);
wc_var = var(pwcDfk);

hold(ax_var, 'on');
hOL_v = plot(ax_var, T, nc_var, 'Color', colOL, 'LineWidth', 1);
hCL_v = plot(ax_var, T, wc_var, 'Color', colCL, 'LineWidth', 1);
xline(ax_var, 0,   'LineWidth', 0.75, 'HandleVisibility','off');
xline(ax_var, dur, 'LineWidth', 0.75, 'HandleVisibility','off');
ylim(ax_var, [-2 12]); xlim(ax_var, [-3 dur+3]);
addStimPatch(ax_var, x1, x2);
uistack(findobj(ax_var,'Type','line'), 'top');
hold(ax_var, 'off');
shortCornerAxes_plot(ax_var, 'XLength', 1, 'YLength', 0.01, ...
    'XLabel', '1 sec', 'YLabel', ' ', 'LineWidth', 2.5, 'LabelGap', 0.04);
cleanAxes(ax_var);
text(ax_var, -0.12, 0.5, 'Variance across trials', ...
    'Units','normalized', 'Rotation', 90, ...
    'HorizontalAlignment','center', 'VerticalAlignment','middle', ...
    'FontSize', 8, 'FontWeight','bold', 'Color','k', 'Clipping','off');
text(ax_var, -0.10, 0.95, 'D', 'Units','normalized', 'FontSize', 9, ...
    'FontWeight','bold', 'Clipping','off');


% ---- B: MSE half-violin + jitter scatter ----
halfWidth = 0.3;
alphaFill = 0.5;
k_pos     = 1;

[fA, yA] = ksdensity(data.er_ncDfk);
fA = fA / max(fA) * halfWidth;

[fB, yB] = ksdensity(data.er_wcDfk);
fB = fB / max(fB) * halfWidth;

hold(ax_mse, 'on');

fill(ax_mse, [k_pos - fA, k_pos*ones(1,length(fA))], [yA, fliplr(yA)], ...
    colOL, 'FaceAlpha', alphaFill, 'EdgeColor','none', 'HandleVisibility','off');
fill(ax_mse, [k_pos + fB, k_pos*ones(1,length(fB))], [yB, fliplr(yB)], ...
    colCL, 'FaceAlpha', alphaFill, 'EdgeColor','none', 'HandleVisibility','off');

plot(ax_mse, k_pos - 0.1, mean(data.er_ncDfk), 'r*', ...
    'MarkerSize', 5, 'LineWidth', 1, 'HandleVisibility','off');
plot(ax_mse, k_pos + 0.1, mean(data.er_wcDfk), '*', 'Color', colCL, ...
    'MarkerSize', 5, 'LineWidth', 1, 'HandleVisibility','off');

hold(ax_mse, 'off');

text(ax_mse, -0.12, 0.5, 'Trial MSE', ...
    'Units','normalized', 'Rotation',90, ...
    'HorizontalAlignment','center', 'VerticalAlignment','middle', ...
    'FontSize',8, 'FontWeight','bold', 'Color','k', 'Clipping','off');

cleanAxes(ax_mse);
text(ax_mse, -0.10, 0.95, 'E', 'Units','normalized', 'FontSize', 9, ...
    'FontWeight','bold', 'Clipping','off');

exportgraphics(fig2, 'paper/combined_variance_MSE.png', 'Resolution', 300);

end


%% Local helpers ----------------------------------------------------

function addStimPatch(ax, x1, x2)
    yl = ylim(ax);
    patch(ax, [x1 x2 x2 x1], [yl(1) yl(1) yl(2) yl(2)], ...
        [0.9 0.9 0.9], 'FaceAlpha', 0.3, 'EdgeColor','none');
end

function cleanAxes(ax)
    set(ax, 'Box','off', 'XColor','none', 'YColor','none', ...
        'TickDir','out', 'XTick', [], 'YTick', [], 'Color','none');
end
