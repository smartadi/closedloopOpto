function analysisPlots_combined(data, d)
% Exports 5 separate panel figures, all 8.9 cm wide, for external layout.
%   paper/panel_A.pdf  – single trial example  (OL left | CL right)
%   paper/panel_B.pdf  – all trials + average  (OL left | CL right)
%   paper/panel_C.pdf  – average inputs        (OL left | CL right)
%   paper/panel_D.pdf  – variance over time    (single panel)
%   paper/panel_E.pdf  – MSE half-violin       (single panel)
%
% All figures are W=8.9 cm wide with uniform font sizes (8–9 pt).
% Scale all to the same display width in external software for matching text.

PW = 8.9;   % cm (= 3.5 inches)
dur    = d.params.dur;
t      = d.timeBlue;
tt     = d.inpTime;
v      = d.inpVals;

dFk    = data.dFk;
nc     = data.nc;
wc     = data.wc;
pncDfk = data.pncDfk;
pwcDfk = data.pwcDfk;
nc_inp = data.ncInp;
wc_inp = data.wcInp;

nc_avg = mean(pncDfk, 1);
wc_avg = mean(pwcDfk, 1);

trial = 10;

T    = (-3*35  : 35*(dur+3)) / 35;
Tp   = (-10*35 : 35*(dur+3)) / 35;
Tref = (0      : 35*dur)     / 35;
Tin  = (0      : dur*2000)   / 2000;

colOL    = [1 0 0];
colCL    = [0 0.5 0];
colInpOL = [1 0 1];
colInpCL = [0 0.5 1];
x1 = 0; x2 = dur;

jnc = nc(trial);
[~, i_nc]  = min(abs(t  - d.stimStarts(jnc)));
[~, k_nc]  = min(abs(tt - d.stimStarts(jnc)));
[~, k2_nc] = min(abs(tt - d.stimEnds(jnc)));

jwc = wc(trial);
[~, i_wc]  = min(abs(t  - d.stimStarts(jwc)));
[~, k_wc]  = min(abs(tt - d.stimStarts(jwc)));
[~, k2_wc] = min(abs(tt - d.stimEnds(jwc)));

% Shared 2-column layout (normalised)
lm = 0.08; rm = 0.02; cg = 0.03;
cW  = (1 - lm - rm - cg) / 2;
c1L = lm;
c2L = lm + cW + cg;

%% A: single trial -------------------------------------------------------
PH_A = 5;
PW = 8;
fig_A = figure('Color','w', 'Units','centimeters', 'Position',[0 0 PW PH_A]);

bm = 0.12; tm = 0.12;
axH = 1 - bm - tm;
ax_A = axes(fig_A, 'Position', [c1L, bm, cW, axH]);
ax_B = axes(fig_A, 'Position', [c2L, bm, cW, axH]);

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
line(ax_A, [0 0], [6 8], 'Color', colInpOL, 'LineWidth', 1.5, 'Clipping','off', 'HandleVisibility','off');
text(ax_A, -0.1, 8, '1 mW', 'Color', colInpOL, 'FontSize', 6, ...
    'HorizontalAlignment','right', 'VerticalAlignment','middle', 'Clipping','off');
uistack(findobj(ax_A,'Type','line'), 'top');
hold(ax_A, 'off');
shortCornerAxes_plot(ax_A, 'XLength', 1, 'YLength', 3, ...
    'XLabel', '1 sec', 'YLabel', '3% dF/F', 'LineWidth', 2, 'LabelGap', 0.05);
cleanAxes(ax_A);
% text(ax_A, -0.08, 0.97, 'A', 'Units','normalized', 'FontSize', 9, 'FontWeight','bold', 'Clipping','off');
text(ax_A, 0.5,   1.06, 'Open-Loop', 'Units','normalized', 'FontSize', 6, 'FontWeight','bold', ...
    'HorizontalAlignment','center', 'Clipping','off');
text(ax_A, 3*dur/4, 4, 'OL Stim', 'Color', colInpOL, 'FontSize', 6, ...
    'HorizontalAlignment','center', 'FontWeight','bold', 'Clipping','off');

hold(ax_B, 'on');
plot(ax_B, T, zeros(1,length(T)), 'k', 'LineWidth', 0.5, 'HandleVisibility','off');
plot(ax_B, tt(k_wc:k2_wc)-tt(k_wc), 4*v(k_wc:k2_wc), ...
    'Color', colInpCL, 'LineWidth', 0.75, 'HandleVisibility','off');
hOL_s  = plot(ax_B, NaN, NaN, 'Color', colOL, 'LineWidth', 1.5);
hCL_s  = plot(ax_B, T, dFk((i_wc-3*35):(i_wc+35*(dur+3))), 'Color', colCL, 'LineWidth', 1.5);
hRef_s = plot(ax_B, Tref, d.ref*ones(1,length(Tref)), '--k', 'LineWidth', 1);
xline(ax_B, 0, 'HandleVisibility','off');
xline(ax_B, dur, 'HandleVisibility','off');
ylim(ax_B, [-10 10]); xlim(ax_B, [-3 dur+3]);
addStimPatch(ax_B, x1, x2);
uistack(findobj(ax_B,'Type','line'), 'top');
lgd = legend(ax_B, [hOL_s hCL_s hRef_s], {'Open-Loop','Closed-Loop','Ref'}, ...
    'Location','southeast', 'Box','off', 'FontSize', 6, 'FontWeight','bold');
lgd.ItemTokenSize = [8 4];
hold(ax_B, 'off');
cleanAxes(ax_B);
text(ax_B, 0.5,   1.06, 'Closed-Loop', 'Units','normalized', 'FontSize', 6, 'FontWeight','bold', ...
    'HorizontalAlignment','center', 'Clipping','off');
text(ax_B, 3*dur/4, 4, 'CL Stim', 'Color', colInpCL, 'FontSize', 6, ...
    'HorizontalAlignment','center', 'FontWeight','bold', 'Clipping','off');

linkaxes([ax_A ax_B], 'x');
exportgraphics(fig_A, 'paper/panel_A.pdf', 'ContentType','vector');

%% B: all trials + average -----------------------------------------------
PH_B = 5;
fig_B = figure('Color','w', 'Units','centimeters', 'Position',[0 0 PW PH_B]);

bm = 0.10; tm = 0.07;
axH = 1 - bm - tm;
ax_C = axes(fig_B, 'Position', [c1L, bm, cW, axH]);
ax_D = axes(fig_B, 'Position', [c2L, bm, cW, axH]);

hold(ax_C, 'on');
plot(ax_C, T, zeros(1,length(T)), 'k', 'LineWidth', 0.5, 'HandleVisibility','off');
plot(ax_C, Tp, pncDfk, 'Color', [colOL 0.1], 'LineWidth', 0.5, 'HandleVisibility','off');
plot(ax_C, Tref, d.ref*ones(1,length(Tref)), '--k', 'LineWidth', 1, 'HandleVisibility','off');
plot(ax_C, Tp, nc_avg, 'Color', colOL, 'LineWidth', 1.5, 'HandleVisibility','off');
xline(ax_C, 0, 'HandleVisibility','off');
xline(ax_C, dur, 'HandleVisibility','off');
ylim(ax_C, [-10 10]); xlim(ax_C, [-3 dur+3]);
addStimPatch(ax_C, x1, x2);
uistack(findobj(ax_C,'Type','line'), 'top');
hold(ax_C, 'off');
shortCornerAxes_plot(ax_C, 'XLength', 0.01, 'YLength', 3, ...
    'XLabel', ' ', 'YLabel', '3% dF/F', 'LineWidth', 2.5, 'LabelGap', 0.04);
cleanAxes(ax_C);
% text(ax_C, -0.08, 0.97, 'B', 'Units','normalized', 'FontSize', 9, 'FontWeight','bold', 'Clipping','off');

hold(ax_D, 'on');
plot(ax_D, T, zeros(1,length(T)), 'k', 'LineWidth', 0.5, 'HandleVisibility','off');
plot(ax_D, Tp, pwcDfk, 'Color', [colCL 0.1], 'LineWidth', 0.5, 'HandleVisibility','off');
plot(ax_D, Tref, d.ref*ones(1,length(Tref)), '--k', 'LineWidth', 1, 'HandleVisibility','off');
plot(ax_D, Tp, wc_avg, 'Color', colCL, 'LineWidth', 1.5, 'HandleVisibility','off');
xline(ax_D, 0, 'HandleVisibility','off');
xline(ax_D, dur, 'HandleVisibility','off');
ylim(ax_D, [-10 10]); xlim(ax_D, [-3 dur+3]);
addStimPatch(ax_D, x1, x2);
uistack(findobj(ax_D,'Type','line'), 'top');
hold(ax_D, 'off');
cleanAxes(ax_D);

linkaxes([ax_C ax_D], 'x');
exportgraphics(fig_B, 'paper/panel_B.pdf', 'ContentType','image', 'Resolution',300);

%% C: average inputs -----------------------------------------------------
PH_C = 3;
fig_C = figure('Color','w', 'Units','centimeters', 'Position',[0 0 PW PH_C]);

bm = 0.15; tm = 0.08;
axH = 1 - bm - tm;
ax_E = axes(fig_C, 'Position', [c1L, bm, cW, axH]);
ax_F = axes(fig_C, 'Position', [c2L, bm, cW, axH]);

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
% text(ax_E, -0.08, 0.97, 'C', 'Units','normalized', 'FontSize', 9, 'FontWeight','bold', 'Clipping','off');

hold(ax_F, 'on');
plot(ax_F, T, zeros(1,length(T)), 'k', 'LineWidth', 0.5, 'HandleVisibility','off');
plot(ax_F, Tin, 3*wc_inp, 'Color', [colInpCL 0.05], 'LineWidth', 0.5, 'HandleVisibility','off');
plot(ax_F, Tin, 3*mean(wc_inp), 'Color', colInpCL, 'LineWidth', 1.5, 'HandleVisibility','off');
plot(ax_F, Tref, d.ref*ones(1,length(Tref)), '--k', 'LineWidth', 1, 'HandleVisibility','off');
xline(ax_F, 0, 'HandleVisibility','off');
xline(ax_F, dur, 'HandleVisibility','off');
ylim(ax_F, [-1 4]); xlim(ax_F, [-3 dur+3]);
addStimPatch(ax_F, x1, x2);
uistack(findobj(ax_F,'Type','line'), 'top');
hold(ax_F, 'off');
cleanAxes(ax_F);

linkaxes([ax_E ax_F], 'x');
exportgraphics(fig_C, 'paper/panel_C.pdf', 'ContentType','image', 'Resolution',300);

%% D: variance over time -------------------------------------------------
PH_D = 5;
PW = 3;
fig_D = figure('Color','w', 'Units','centimeters', 'Position',[0 0 PW PH_D]);

lm2 = 0.13; rm2 = 0.05; bm2 = 0.12; tm2 = 0.08;
ax_var = axes(fig_D, 'Position', [lm2, bm2, 1-lm2-rm2, 1-bm2-tm2]);

nc_var = var(pncDfk);
wc_var = var(pwcDfk);

hold(ax_var, 'on');
plot(ax_var, Tp, nc_var, 'Color', colOL, 'LineWidth', 1);
plot(ax_var, Tp, wc_var, 'Color', colCL, 'LineWidth', 1);
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
    'FontSize', 6, 'FontWeight','bold', 'Color','k', 'Clipping','off');
% text(ax_var, -0.10, 0.95, 'D', 'Units','normalized', 'FontSize', 9, 'FontWeight','bold', 'Clipping','off');

exportgraphics(fig_D, 'paper/panel_D.pdf', 'ContentType','vector');

%% E: MSE half-violin ----------------------------------------------------
PH_E = 5;
Pw = 3;
fig_E = figure('Color','w', 'Units','centimeters', 'Position',[0 0 PW PH_E]);

lm2e = 0.13; rm2e = 0.05; bm2e = 0.15; tm2e = 0.10;
ax_mse = axes(fig_E, 'Position', [lm2e, bm2e, 1-lm2e-rm2e, 1-bm2e-tm2e]);

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
    'Units','normalized', 'Rotation', 90, ...
    'HorizontalAlignment','center', 'VerticalAlignment','middle', ...
    'FontSize', 6, 'FontWeight','bold', 'Color','k', 'Clipping','off');
cleanAxes(ax_mse);
% text(ax_mse, -0.10, 0.95, 'E', 'Units','normalized', 'FontSize', 9, 'FontWeight','bold', 'Clipping','off');

exportgraphics(fig_E, 'paper/panel_E.pdf', 'ContentType','vector');

end

% addStimPatch and cleanAxes live in utils/ and are on the path
