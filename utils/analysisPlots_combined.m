function analysisPlots_combined(data, d)
% Exports 5 separate panel figures for external layout.
%   paper/images/figure3/panel_A.pdf  – single trial example  (OL left | CL right)
%   paper/images/figure3/panel_B.pdf  – all trials + average  (OL left | CL right)
%   paper/images/figure3/panel_C.pdf  – average inputs        (OL left | CL right)
%   paper/images/figure3/panel_D.pdf  – variance over time    (3×3.5 cm)
%   paper/images/figure3/panel_E.pdf  – MSE half-violin       (3×3 cm)
%
% Style is fully delegated to paperStyle / setPaperDefaults / paperAxes / paperLegend.
% Individual panel sizes are the only local formatting.

PW = 8.9;   % cm — panels A / B / C
PS = paperStyle();
setPaperDefaults();
if ~isfield(d, 'ref'); d.ref = -5; end
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

colOL    = PS.col_ol;
colCL    = PS.col_cl;
colInpOL = PS.col_inp_ol;
colInpCL = PS.col_inp_cl;
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
PH_A = 4;
fig_A = paperFig(PW, PH_A);

bm = 0.12; tm = 0.12;
axH = 1 - bm - tm;
ax_A = axes(fig_A, 'Position', [c1L, bm, cW, axH]);
ax_B = axes(fig_A, 'Position', [c2L, bm, cW, axH]);

hold(ax_A, 'on');
plot(ax_A, T, zeros(1,length(T)), 'k', 'LineWidth', PS.lw_zero, 'HandleVisibility','off');
plot(ax_A, tt(k_nc:k2_nc)-tt(k_nc), 5*v(k_nc:k2_nc), ...
    'Color', colInpOL, 'LineWidth', PS.lw_inp, 'HandleVisibility','off');
plot(ax_A, T, dFk((i_nc-3*35):(i_nc+35*(dur+3))), ...
    'Color', colOL, 'LineWidth', PS.lw_mean, 'HandleVisibility','off');
plot(ax_A, Tref, d.ref*ones(1,length(Tref)), '--k', 'LineWidth', PS.lw_ref, 'HandleVisibility','off');
xline(ax_A, 0, 'HandleVisibility','off');
xline(ax_A, dur, 'HandleVisibility','off');
ylim(ax_A, [-10 10]); xlim(ax_A, [-3 dur+3]);
addStimPatch(ax_A, x1, x2);
line(ax_A, [0 0], [6 8], 'Color', colInpOL, 'LineWidth', PS.lw_mean, 'Clipping','off', 'HandleVisibility','off');
text(ax_A, -0.1, 8, '1 mW', 'Color', colInpOL, ...
    'HorizontalAlignment','right', 'VerticalAlignment','middle', 'Clipping','off');
uistack(findobj(ax_A,'Type','line'), 'top');
hold(ax_A, 'off');
paperAxes(ax_A, 'XLength', 1, 'YLength', 3, 'XLabel', '1 s', 'YLabel', '3% dF/F');
text(ax_A, 0.5, 1.06, 'Open-Loop', 'Units','normalized', ...
    'HorizontalAlignment','center', 'Clipping','off');
text(ax_A, 3*dur/4, 7, 'OL Stim', 'Color', colInpOL, ...
    'HorizontalAlignment','center', 'Clipping','off');

hold(ax_B, 'on');
plot(ax_B, T, zeros(1,length(T)), 'k', 'LineWidth', PS.lw_zero, 'HandleVisibility','off');
plot(ax_B, tt(k_wc:k2_wc)-tt(k_wc), 4*v(k_wc:k2_wc), ...
    'Color', colInpCL, 'LineWidth', PS.lw_inp, 'HandleVisibility','off');
hOL_s  = plot(ax_B, NaN, NaN, 'Color', colOL, 'LineWidth', PS.lw_mean);
hCL_s  = plot(ax_B, T, dFk((i_wc-3*35):(i_wc+35*(dur+3))), 'Color', colCL, 'LineWidth', PS.lw_mean);
hRef_s = plot(ax_B, Tref, d.ref*ones(1,length(Tref)), '--k', 'LineWidth', PS.lw_ref);
xline(ax_B, 0, 'HandleVisibility','off');
xline(ax_B, dur, 'HandleVisibility','off');
ylim(ax_B, [-10 10]); xlim(ax_B, [-3 dur+3]);
addStimPatch(ax_B, x1, x2);
uistack(findobj(ax_B,'Type','line'), 'top');
lgd = legend(ax_B, [hOL_s hCL_s hRef_s], {'Open-Loop','Closed-Loop','Ref'}, ...
    'Orientation','horizontal');
paperLegend(lgd);
lgd.Units = 'normalized';
lgd.Position(2) = 0.01;
lgd.Position(1) = 0.5 - lgd.Position(3)/2;
hold(ax_B, 'off');
paperAxes(ax_B);
text(ax_B, 0.5, 1.06, 'Closed-Loop', 'Units','normalized', ...
    'HorizontalAlignment','center', 'Clipping','off');
text(ax_B, 3*dur/4, 7, 'CL Stim', 'Color', colInpCL, ...
    'HorizontalAlignment','center', 'Clipping','off');

linkaxes([ax_A ax_B], 'x');
paperExport(fig_A, 'paper/images/figure3/panel_A.pdf');

%% B: all trials + average -----------------------------------------------
PH_B = 4;
fig_B = paperFig(PW, PH_B);

bm = 0.12; tm = 0.12;
axH = 1 - bm - tm;
ax_C = axes(fig_B, 'Position', [c1L, bm, cW, axH]);
ax_D = axes(fig_B, 'Position', [c2L, bm, cW, axH]);

nc_std = std(pncDfk, 0, 1);
hold(ax_C, 'on');
plot(ax_C, T, zeros(1,length(T)), 'k', 'LineWidth', PS.lw_zero, 'HandleVisibility','off');
fill(ax_C, [Tp fliplr(Tp)], [nc_avg+nc_std fliplr(nc_avg-nc_std)], ...
    colOL, 'FaceAlpha', PS.fa, 'EdgeColor','none', 'HandleVisibility','off');
plot(ax_C, Tref, d.ref*ones(1,length(Tref)), '--k', 'LineWidth', PS.lw_ref, 'HandleVisibility','off');
plot(ax_C, Tp, nc_avg, 'Color', colOL, 'LineWidth', PS.lw_mean, 'HandleVisibility','off');
xline(ax_C, 0, 'HandleVisibility','off');
xline(ax_C, dur, 'HandleVisibility','off');
ylim(ax_C, [-10 10]); xlim(ax_C, [-3 dur+3]);
addStimPatch(ax_C, x1, x2);
uistack(findobj(ax_C,'Type','line'), 'top');
hold(ax_C, 'off');
paperAxes(ax_C, 'XLength', 0.01, 'YLength', 3, 'XLabel', ' ', 'YLabel', '3% dF/F');

wc_std = std(pwcDfk, 0, 1);
hold(ax_D, 'on');
plot(ax_D, T, zeros(1,length(T)), 'k', 'LineWidth', PS.lw_zero, 'HandleVisibility','off');
fill(ax_D, [Tp fliplr(Tp)], [wc_avg+wc_std fliplr(wc_avg-wc_std)], ...
    colCL, 'FaceAlpha', PS.fa, 'EdgeColor','none', 'HandleVisibility','off');
plot(ax_D, Tref, d.ref*ones(1,length(Tref)), '--k', 'LineWidth', PS.lw_ref, 'HandleVisibility','off');
plot(ax_D, Tp, wc_avg, 'Color', colCL, 'LineWidth', PS.lw_mean, 'HandleVisibility','off');
xline(ax_D, 0, 'HandleVisibility','off');
xline(ax_D, dur, 'HandleVisibility','off');
ylim(ax_D, [-10 10]); xlim(ax_D, [-3 dur+3]);
addStimPatch(ax_D, x1, x2);
uistack(findobj(ax_D,'Type','line'), 'top');
hold(ax_D, 'off');
paperAxes(ax_D);

linkaxes([ax_C ax_D], 'x');
paperExport(fig_B, 'paper/images/figure3/panel_B.pdf');

%% C: average inputs -----------------------------------------------------
PH_C = 3;
fig_C = paperFig(PW, PH_C);

bm = 0.15; tm = 0.08;
axH = 1 - bm - tm;
ax_E = axes(fig_C, 'Position', [c1L, bm, cW, axH]);
ax_F = axes(fig_C, 'Position', [c2L, bm, cW, axH]);

nc_inp_mean = mean(nc_inp, 1);
nc_inp_std  = std(nc_inp, 0, 1);
hold(ax_E, 'on');
plot(ax_E, T, zeros(1,length(T)), 'k', 'LineWidth', PS.lw_zero, 'HandleVisibility','off');
fill(ax_E, [Tin fliplr(Tin)], [3*(nc_inp_mean+nc_inp_std) fliplr(3*(nc_inp_mean-nc_inp_std))], ...
    colInpOL, 'FaceAlpha', PS.fa, 'EdgeColor','none', 'HandleVisibility','off');
plot(ax_E, Tin, 3*nc_inp_mean, 'Color', colInpOL, 'LineWidth', PS.lw_mean, 'HandleVisibility','off');
plot(ax_E, Tref, d.ref*ones(1,length(Tref)), '--k', 'LineWidth', PS.lw_ref, 'HandleVisibility','off');
xline(ax_E, 0, 'HandleVisibility','off');
xline(ax_E, dur, 'HandleVisibility','off');
ylim(ax_E, [-2 5]); xlim(ax_E, [-3 dur+3]);
addStimPatch(ax_E, x1, x2);
uistack(findobj(ax_E,'Type','line'), 'top');
hold(ax_E, 'off');
paperAxes(ax_E, 'XLength', 0.01, 'YLength', 2, 'XLabel', ' ', 'YLabel', '1 mW');

wc_inp_mean = mean(wc_inp, 1);
wc_inp_std  = std(wc_inp, 0, 1);
hold(ax_F, 'on');
plot(ax_F, T, zeros(1,length(T)), 'k', 'LineWidth', PS.lw_zero, 'HandleVisibility','off');
fill(ax_F, [Tin fliplr(Tin)], [3*(wc_inp_mean+wc_inp_std) fliplr(3*(wc_inp_mean-wc_inp_std))], ...
    colInpCL, 'FaceAlpha', PS.fa, 'EdgeColor','none', 'HandleVisibility','off');
plot(ax_F, Tin, 3*wc_inp_mean, 'Color', colInpCL, 'LineWidth', PS.lw_mean, 'HandleVisibility','off');
plot(ax_F, Tref, d.ref*ones(1,length(Tref)), '--k', 'LineWidth', PS.lw_ref, 'HandleVisibility','off');
xline(ax_F, 0, 'HandleVisibility','off');
xline(ax_F, dur, 'HandleVisibility','off');
ylim(ax_F, [-1 4]); xlim(ax_F, [-3 dur+3]);
addStimPatch(ax_F, x1, x2);
uistack(findobj(ax_F,'Type','line'), 'top');
hold(ax_F, 'off');
paperAxes(ax_F);

linkaxes([ax_E ax_F], 'x');
paperExport(fig_C, 'paper/images/figure3/panel_C.pdf');

%% D: variance over time -------------------------------------------------
PH_D = 3.5;
PW_D = 3;
fig_D = paperFig(PW_D, PH_D);

lm2 = 0.13; rm2 = 0.05; bm2 = 0.12; tm2 = 0.08;
ax_var = axes(fig_D, 'Position', [lm2, bm2, 1-lm2-rm2, 1-bm2-tm2]);

nc_var = var(pncDfk);
wc_var = var(pwcDfk);

hold(ax_var, 'on');
plot(ax_var, Tp, nc_var, 'Color', colOL, 'LineWidth', PS.lw_mean);
plot(ax_var, Tp, wc_var, 'Color', colCL, 'LineWidth', PS.lw_mean);
xline(ax_var, 0,   'LineWidth', PS.lw_zero, 'HandleVisibility','off');
xline(ax_var, dur, 'LineWidth', PS.lw_zero, 'HandleVisibility','off');
ylim(ax_var, [-2 12]); xlim(ax_var, [-3 dur+3]);
addStimPatch(ax_var, x1, x2);
uistack(findobj(ax_var,'Type','line'), 'top');
hold(ax_var, 'off');
paperAxes(ax_var, 'XLength', 1, 'YLength', 0.01, 'XLabel', '1 s', 'YLabel', ' ');
text(ax_var, -0.12, 0.5, 'Variance across trials', ...
    'Units','normalized', 'Rotation', 90, ...
    'HorizontalAlignment','center', 'VerticalAlignment','middle', ...
    'Color','k', 'Clipping','off');

paperExport(fig_D, 'paper/images/figure3/panel_D.pdf');

%% E: MSE half-violin ----------------------------------------------------
PH_E = 3;
PW_E = 3;
fig_E = paperFig(PW_E, PH_E);

lm2e = 0.13; rm2e = 0.05; bm2e = 0.15; tm2e = 0.10;
ax_mse = axes(fig_E, 'Position', [lm2e, bm2e, 1-lm2e-rm2e, 1-bm2e-tm2e]);

halfWidth = 0.3;
alphaFill = PS.fa;
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
    'Color','k', 'Clipping','off');
paperAxes(ax_mse);

paperExport(fig_E, 'paper/images/figure3/panel_E.pdf');

end

% addStimPatch lives in utils/ and is on the path
