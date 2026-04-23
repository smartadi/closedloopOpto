function r = analysisPlots_var_paper(data,d,a)

en = d.en;
mn = d.mn;
td = d.td;

dur = d.params.dur;
dFk = data.dFk;
nc = data.nc;
wc = data.wc;
t = d.timeBlue;
trial = 6;

j = nc(trial);
[~, i]  = min(abs(t - d.stimStarts(j)));
[~, i2] = min(abs(t - d.stimEnds(j)));

tt = d.inpTime;
v  = d.inpVals;

[~, k]  = min(abs(tt - d.stimStarts(j)));
[~, k2] = min(abs(tt - d.stimEnds(j)));

% Build variable reference from input signal
Ref = [];
j0  = nc(1);
[~, ir] = min(abs(d.timeBlue - d.stimStarts(j0)));
Ref = [Ref; (-5)*d.iputs(ir:ir+35*(d.params.dur))'];
rref = Ref(end,:);

Tout = -3:0.0285:dur+3;
Tref = 0:0.0285:dur;

%% Single trial
fig = figure('Color','w'); hold on;
fig.Units    = 'inches';
fig.Position = [1, 1, 10, 4];

ax1 = subplot(1,2,1);
plot(Tout, 0*ones(1,length(Tout)), 'k', 'LineWidth', 1, 'HandleVisibility','off'); hold on
hA = plot(Tout, dFk((i-(3*35)):(i+35*(dur+3))), 'r', 'LineWidth', 3);
hB = plot(Tref, rref, '--k', 'LineWidth', 2);
hC = plot(tt(k:k2)-tt(k), 2*v(k:k2), 'b', 'LineWidth', 3);

ylim([-10 10])
xlim([-3, 6])
xline(0)
xline(dur)
yl = ylim;
x1 = 0; x2 = dur;
patch([x1 x2 x2 x1], [yl(1) yl(1) yl(2) yl(2)], [0.9 0.9 0.9], ...
    'FaceAlpha', 0.3, 'EdgeColor', 'none');
shortCornerAxes_plot(gca, 'XLength', 1, 'YLength', 3, ...
    'XLabel', '1 sec', 'YLabel', '3% dF/F', 'LineWidth', 5, 'LabelGap', 0.04)

uistack(findobj(gca,'Type','line'), 'top')
hold off
box off
xticklabels([])
yticklabels([])

j = wc(trial);
[~, i]  = min(abs(t - d.stimStarts(j)));
[~, i2] = min(abs(t - d.stimEnds(j)));
[~, k]  = min(abs(tt - d.stimStarts(j)));
[~, k2] = min(abs(tt - d.stimEnds(j)));

ax2 = subplot(1,2,2);
plot(Tout, 0*ones(1,length(Tout)), 'k', 'LineWidth', 1, 'HandleVisibility','off'); hold on
hD = plot(Tout, dFk((i-(3*35)):(i+35*(dur+3))), 'Color', [0,0.5,0], 'LineWidth', 3);
plot(Tref, rref, '--k', 'LineWidth', 2)
plot(tt(k:k2)-tt(k), 2*v(k:k2), 'b', 'LineWidth', 3)

ylim([-10 10])
xlim([-3, 6])
xline(0)
xline(dur)
yl = ylim;
patch([x1 x2 x2 x1], [yl(1) yl(1) yl(2) yl(2)], [0.9 0.9 0.9], ...
    'FaceAlpha', 0.3, 'EdgeColor', 'none');

uistack(findobj(gca,'Type','line'), 'top')
hold off
box off
xticklabels([])
yticklabels([])
set(gca, 'Box','off', 'XColor','none', 'YColor','none', ...
    'TickDir','out', 'XTick',[], 'YTick',[], 'Color','none');

legend(ax2, [hA hD hC hB], {'Open-Loop','Closed-Loop','Stim','Ref'}, ...
    'Location','northeast', 'Box','off', FontSize=12, FontWeight='bold')

exportgraphics(fig, 'paper/single_trial_var.png', 'Resolution', 300);

%% Trial average
dur     = d.params.dur;
pncDfk  = data.pncDfk;
pwcDfk  = data.pwcDfk;
nc_avg  = mean(pncDfk, 1);
wc_avg  = mean(pwcDfk, 1);
T    = -3:0.0285:(dur+3);
Tin  = 0:0.0005:dur;
Tref = 0:1/35:dur;

nc_inp = data.ncInp;
wc_inp = data.wcInp;

fig = figure('Color','w'); hold on;
fig.Units    = 'inches';
fig.Position = [1, 1, 10, 4];

x1 = 0; x2 = dur;

ax1 = subplot(1,2,1);
plot(Tout, 0*ones(1,length(Tout)), 'k', 'LineWidth', 1, 'HandleVisibility','off'); hold on
plot(T, pncDfk, 'Color', [1 0 0 0.1], 'LineWidth', 0.5);
plot(Tref, rref, '--k', 'LineWidth', 2); hold on
plot(T, nc_avg, 'r', 'LineWidth', 3);
plot(Tin, 2*mean(nc_inp), 'b', 'LineWidth', 3);
xline(0); xline(dur)
ylim([-10 10]); xlim([-3, 6])
yl = ylim;
patch([x1 x2 x2 x1], [yl(1) yl(1) yl(2) yl(2)], [0.9 0.9 0.9], ...
    'FaceAlpha', 0.3, 'EdgeColor', 'none');
shortCornerAxes_plot(gca, 'XLength', 1, 'YLength', 3, ...
    'XLabel', '1 sec', 'YLabel', '3% dF/F', 'LineWidth', 5, 'LabelGap', 0.04)

uistack(findobj(gca,'Type','line'), 'top')
hold off

ax2 = subplot(1,2,2);
plot(Tout, 0*ones(1,length(Tout)), 'k', 'LineWidth', 1, 'HandleVisibility','off'); hold on
plot(T, pwcDfk, 'Color', [0 0.5 0 0.1], 'LineWidth', 0.5);
plot(Tref, rref, '--k', 'LineWidth', 2); hold on
plot(T, wc_avg, 'Color', [0 0.5 0], 'LineWidth', 3);
plot(Tin, 2*mean(wc_inp), 'b', 'LineWidth', 3);
xline(0); xline(dur)
ylim([-10 10]); xlim([-3, 6])
yl = ylim;
patch([x1 x2 x2 x1], [yl(1) yl(1) yl(2) yl(2)], [0.9 0.9 0.9], ...
    'FaceAlpha', 0.3, 'EdgeColor', 'none');

xticklabels([]); yticklabels([])
set(gca, 'Box','off', 'XColor','none', 'YColor','none', ...
    'TickDir','out', 'XTick',[], 'YTick',[], 'Color','none');

exportgraphics(fig, 'paper/trial_average_var.png', 'Resolution', 300);

%% Variance
nc_var = var(pncDfk);
wc_var = var(pwcDfk);

fig = figure('Color','w'); hold on;
fig.Units    = 'inches';
fig.Position = [1, 1, 6, 4];

plot(T, nc_var, 'r', 'LineWidth', 2); hold on
plot(T, wc_var, 'Color', [0 0.5 0], 'LineWidth', 2);
xline(0, 'LineWidth', 1.5); xline(dur, 'LineWidth', 1.5)
ylim([-2, 12])
yl = ylim;
patch([x1 x2 x2 x1], [yl(1) yl(1) yl(2) yl(2)], [0.9 0.9 0.9], ...
    'FaceAlpha', 0.3, 'EdgeColor', 'none');
shortCornerAxes_plot(gca, 'XLength', 1, 'YLength', 2, ...
    'XLabel', '1 sec', 'YLabel', 'Variance', 'LineWidth', 5, 'LabelGap', 0.04)

uistack(findobj(gca,'Type','line'), 'top')
hold off

exportgraphics(fig, 'paper/variance_var.png', 'Resolution', 300);

%% MSE distribution
fig = figure('Color','w'); hold on;
fig.Units    = 'inches';
fig.Position = [1, 1, 6, 4];

halfWidth = 0.3;
alphaFill = 0.5;
k     = 1;
colA  = [1 0 0];
colB  = [0 0.5 0];

[fA, yA] = ksdensity(data.er_ncDfk);
fA = fA / max(fA) * halfWidth;
fill([k - fA, k*ones(size(fA))], [yA, fliplr(yA)], colA, ...
    'FaceAlpha', alphaFill, 'EdgeColor','none');
muA = mean(data.er_ncDfk);
plot([k - 0.1], [muA], 'r*', 'LineWidth', 1.5);

[fB, yB] = ksdensity(data.er_wcDfk);
fB = fB / max(fB) * halfWidth;
fill([k + fB, k*ones(size(fB))], [yB, fliplr(yB)], colB, ...
    'FaceAlpha', alphaFill, 'EdgeColor','none');
muB = mean(data.er_wcDfk);
plot([k + 0.1], [muB], 'g*', 'LineWidth', 5);

xticklabels([]); yticklabels([])
set(gca, 'Box','off', 'XColor','none', 'YColor','none', ...
    'TickDir','out', 'XTick',[], 'YTick',[], 'Color','none');

yl = ylim; xl = xlim;
text(xl(1) - 0.1*diff(xl), mean(yl), 'Trial MSE', ...
    'Color','k', 'FontSize', 12, 'FontWeight','bold', ...
    'HorizontalAlignment','center', 'VerticalAlignment','bottom', ...
    'Rotation', 90, 'Clipping','off');

exportgraphics(fig, 'paper/MSE_distribution_var.png', 'Resolution', 300);

end
