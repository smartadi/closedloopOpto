clear; close all;

% ---- Data ----
x = linspace(0,10,400);
y = 0.05*sin(2*pi*0.6*x) + 0.02*randn(size(x));

figure('Color','w','Position',[100 100 520 380]);
plot(x,y,'k','LineWidth',1.5);
hold on;

ax = gca;

% ---- Hide default axes completely ----
ax.Color  = 'none';
ax.Box    = 'off';
ax.XColor = 'none';
ax.YColor = 'none';

% ---- Get limits ----
xl = xlim;
yl = ylim;

% ---- Draw short corner axes ----
dx = 0.12 * diff(xl);   % x-axis length
dy = 0.12 * diff(yl);   % y-axis length

x0 = xl(1);
y0 = yl(1);

plot([x0 x0+dx], [y0 y0], 'k', 'LineWidth',5)
plot([x0 x0], [y0 y0+dy], 'k', 'LineWidth',5)

% ---- Manual labels (since axes are hidden) ----
text(mean([x0 x0+dx]), y0 - 0.08*diff(yl), 'Time (s)', ...
    'HorizontalAlignment','center', ...
    'FontWeight','bold','FontSize',12,'FontName','Arial');

text(x0 - 0.08*diff(xl), mean([y0 y0+dy]), '\DeltaF/F', ...
    'Rotation',90,'HorizontalAlignment','center', ...
    'FontWeight','bold','FontSize',12,'FontName','Arial');

%%

figure()

plot(x, y, 'k', 'LineWidth', 1.5);
shortCornerAxes(gca, 'XLabel','Time (s)', 'YLabel','\DeltaF/F', 'Frac',0.10,'LineWidth',5);
%   shortCornerAxes(gca,'LineWidth',1.2);       % corner line width
