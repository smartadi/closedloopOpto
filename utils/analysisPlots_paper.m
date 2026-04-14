function r = analysisPlots_paper(data,d,a)

% d.input_params = readmatrix(append(serverRoot,"/data/input_params.csv"));
% % frames = readmatrix(append(serverRoot,"/frames.csv"));
% d.states = dlmread(append(serverRoot,"/data/states.csv"),' ');
% d.params = load(append(serverRoot,"/data/params.mat"));
en = d.en;
mn = d.mn;
td = d.td;
% 
% %% Load Timeline Data
% 
% sigName = 'lightCommand';
% [tt, v] = getTLanalog(mn, td, en, sigName);
% d.inpTime = tt;
% d.inpVals  = v;
% d.lightRaw = readNPY(append(serverRoot,'/lightCommand.raw.npy'));
% d.lightTime = readNPY(append(serverRoot,'/lightCommand.timestamps_Timeline.npy'));
% 
% d.wfExp = readNPY(append(serverRoot,'/widefieldExposure.timestamps_Timeline.npy'));
% d.wfTime = readNPY(append(serverRoot,'/widefieldExposure.raw.npy'));
% 
% 
% wf_times = tt(d.wfTime(2:end)>1 & d.wfTime(1:end-1)<=1);
% % t = wf_times(2:2:end);
% d.timeBlue = wf_times(1:2:end);
%
% d.mv = d.motion.motion_1(1:2:end,1);

% d = mouse.m10.d;
dur = d.params.dur;
% data = mouse.m10.data;
dFk = data.dFk;
nc = data.nc;
wc = data.wc;
t = d.timeBlue;
trial=6;

j = nc(trial)
[a i] = min(abs(t - d.stimStarts(j)));
[a i2] = min(abs(t - d.stimEnds(j)));


tt = d.inpTime;
v = d.inpVals;

[a k] = min(abs(tt - d.stimStarts(j)));
[a k2] = min(abs(tt - d.stimEnds(j)));



% Tin = 0:0.0005:stimDur(j);
Tout = -3:0.0285:dur+3;
Tref = 0:0.0285:dur;

fig= figure('Color','w'); hold on;
fig.Units    = 'inches';
fig.Position = [1, 1, 10, 4];


ax1 = subplot(1,2,1)
plot(Tout,0*ones(1,length(Tout)),'k','LineWidth',1, 'HandleVisibility','off');hold on
hA = plot(Tout,dFk((i-(3*35)):(i+35*(dur+3))),'r','LineWidth',3);hold on
hB = plot(Tref,-5*ones(1,length(Tref)),'--k','LineWidth',2)


hC = plot(tt(k:k2)-tt(k),2*v(k:k2),'b','LineWidth',3)

% Vertical scale bar for input (blue): 2 plot units = 1 V (signal is 2*v)
inpSBx = -3;
line(ax1, [0 0], [6, 8], ...
    'Color','b', 'LineWidth', 3, 'Clipping','off', 'HandleVisibility','off');
text(ax1, 0 - 0.1, 7, '0.2 mW', ...
    'Color','b', 'FontSize', 10, 'FontWeight','bold', ...
    'HorizontalAlignment','right', 'VerticalAlignment','middle', 'Clipping','off');


text(ax1, -3 - 0.1, 0, '0', ...
    'Color','k', 'FontSize', 10, ...
    'HorizontalAlignment','right', 'VerticalAlignment','middle', 'Clipping','off');

% shortCornerAxes(gca, 'XLabel','Time(s)', 'YLabel','\DeltaF/F', 'Frac',0.10,'LineWidth',5);


ylim([-10 10])
xlim([-3,6])
xline(0)
xline(3)
% ylabel('dF/F','FontSize',12,'FontWeight','bold')
% xlabel('time(secs)','FontSize',12,'FontWeight','bold')
yl = ylim;   % current y-limits
x1 = 0;
x2 = 3;
patch([x1 x2 x2 x1], ...
      [yl(1) yl(1) yl(2) yl(2)], ...
      [0.9 0.9 0.9], ...
      'FaceAlpha', 0.3, ...
      'EdgeColor', 'none');
% shortCornerAxes_plot(gca,'Frac',0.10,'XLabel','Time (s)','YLabel','\DeltaF/F','LineWidth',5)

 shortCornerAxes_plot(gca, 'XLength', 1, 'YLength', 3, ...
      'XLabel', '1 sec', 'YLabel', '3% dF/F', 'LineWidth', 5,'LabelGap',  0.04)


% Keep data on top
uistack(findobj(gca,'Type','line'),'top')
hold off
box off
xticklabels([])
yticklabels([])



j = wc(trial)
[a i] = min(abs(t - d.stimStarts(j)));
[a i2] = min(abs(t - d.stimEnds(j)));


tt = d.inpTime;
v = d.inpVals;

[a k] = min(abs(tt - d.stimStarts(j)));
[a k2] = min(abs(tt - d.stimEnds(j)));



ax2 = subplot(1,2,2)
plot(Tout,0*ones(1,length(Tout)),'k','LineWidth',1, 'HandleVisibility','off');hold on
hD = plot(Tout,dFk((i-(3*35)):(i+35*(dur+3))),'Color',[0,0.5,0],'LineWidth',3);hold on
plot(Tref,-5*ones(1,length(Tref)),'--k','LineWidth',2)
plot(tt(k:k2)-tt(k),2*v(k:k2),'b','LineWidth',3)
% shortCornerAxes(gca, 'XLabel','', 'YLabel','', 'Frac',0.0,'LineWidth',0);
ylim([-10 10])
xlim([-3,6])
xline(0)
xline(3)
yl = ylim;   % current y-limits
x1 = 0;
x2 = 3;
patch([x1 x2 x2 x1], ...
      [yl(1) yl(1) yl(2) yl(2)], ...
      [0.9 0.9 0.9], ...
      'FaceAlpha', 0.3, ...
      'EdgeColor', 'none');

uistack(findobj(gca,'Type','line'),'top')
hold off
box off
xticklabels([])
yticklabels([])
set(gca, ...
    'Box','off', ...
    'XColor','none', ...
    'YColor','none', ...
    'TickDir','out', ...
    'XTick',[], ...
    'YTick',[], ...
    'Color','none');


legend(ax2, [hA hD hC hB], {'Open-Loop', 'Closed-Loop','Stim', 'Ref'}, ...
    'Location','northeast', ...
    'Box','off', FontSize=12, FontWeight='bold')


exportgraphics(fig, 'paper/single_trial.png', 'Resolution', 300);
%%%%%%%%%%%%%%%%%%%%%
% set([ax1 ax2], 'Units','normalized');
% 
% leftMargin   = 0.08;
% rightMargin  = 0.03;
% bottomMargin = 0.18;
% topMargin    = 0.08;
% gap          = 0.05;
% 
% axW = (1 - leftMargin - rightMargin - gap)/2;
% axH = 1 - bottomMargin - topMargin;
% 
% ax1.Position = [leftMargin,              bottomMargin, axW, axH];
% ax2.Position = [leftMargin + axW + gap,  bottomMargin, axW, axH];

%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%
dur = d.params.dur;
ncDfk = data.ncDfk;
wcDfk = data.wcDfk;

pncDfk = data.pncDfk(:,246:end);
pwcDfk = data.pwcDfk(:,246:end);

pncDfk = data.pncDfk;
pwcDfk = data.pwcDfk;
nc_avg = mean(pncDfk,1);
wc_avg = mean(pwcDfk,1);
T= -3:0.0285:(dur+3);
Tin = 0:0.0005:dur;
% Tout = 0:0.0285:dur;

%% full experiment

nc_inp  = data.ncInp;
wc_inp  = data.wcInp;

fig= figure('Color','w'); hold on;
fig.Units    = 'inches';
fig.Position = [1, 1, 10, 4];



% Column (vertical band) to shade
x1 = 0;
x2 = 3;

size(T)
size(pncDfk)
ref = [zeros(1,35*3), d.ref*ones(1,3*35),zeros(1,35*3+1)];
Tref = 0:1/35:3;
ax1 = subplot(1,2,1)
plot(Tout,0*ones(1,length(Tout)),'k','LineWidth',1, 'HandleVisibility','off');hold on
plot(T,pncDfk,'Color', [1 0 0 0.1],'LineWidth',0.5);hold on



% plot(T,d.ref*ones(1,length(T)),'--k','Linewidth',3);hold on
% plot(T,ref,'--k','Linewidth',3);hold on
plot(Tref,d.ref*ones(3*35+1),'--k','Linewidth',3);hold on
plot(T,nc_avg,'r','Linewidth',3);

plot(Tin,2*mean(nc_inp),'b','LineWidth',3);
xline(0)
xline(dur)
% shortCornerAxes_plot(gca,'Frac',0.10,'XLabel','Time (s)','YLabel','\DeltaF/F','LineWidth',5)
 % shortCornerAxes_plot(gca, 'XLength', 1, 'YLength', 1, ...
 %      'XLabel', '1 sec', 'YLabel', '1% dF/F', 'LineWidth', 5,'LabelGap',  0.03)
text(ax1, -3 - 0.1, 0, '0', ...
    'Color','k', 'FontSize', 10, ...
    'HorizontalAlignment','right', 'VerticalAlignment','middle', 'Clipping','off');

% shortCornerAxes(gca, 'XLabel','Time(s)', 'YLabel','\DeltaF/F', 'Frac',0.10,'LineWidth',5);
% xlabel('time(sec)','FontSize',12,'FontWeight','bold')
% ylabel('dF/F %','FontSize',12,'FontWeight','bold')
ylim([-10 10])
xlim([-3,6])
yl = ylim;   % current y-limits
patch([x1 x2 x2 x1], ...
      [yl(1) yl(1) yl(2) yl(2)], ...
      [0.9 0.9 0.9], ...
      'FaceAlpha', 0.3, ...
      'EdgeColor', 'none');
 shortCornerAxes_plot(gca, 'XLength', 1, 'YLength', 3, ...
      'XLabel', '1 sec', 'YLabel', '3% dF/F', 'LineWidth', 5,'LabelGap',  0.04)



% Keep data on top
uistack(findobj(gca,'Type','line'),'top')
hold off
% yticklabels([])

% title('Open Loop')
% ax = gca;
% ax.FontWeight = 'bold';
ax2 = subplot(1,2,2)
plot(Tout,0*ones(1,length(Tout)),'k','LineWidth',1, 'HandleVisibility','off');hold on
plot(T,pwcDfk,'Color', [0 0.5 0 0.1],'LineWidth',0.5);hold on
plot(Tref,d.ref*ones(3*35+1),'--k','Linewidth',3);hold on
plot(T,wc_avg,'Color', [0 0.5 0],'Linewidth',3);

plot(Tin,2*mean(wc_inp),'b','LineWidth',3);
xline(0)
xline(dur)
ylim([-10 10])
xlim([-3,6])
% xlabel('time(sec)','FontSize',12,'FontWeight','bold')

yl = ylim;   % current y-limits

patch([x1 x2 x2 x1], ...
      [yl(1) yl(1) yl(2) yl(2)], ...
      [0.9 0.9 0.9], ...
      'FaceAlpha', 0.3, ...
      'EdgeColor', 'none');





xticklabels([])
yticklabels([])
set(gca, ...
    'Box','off', ...
    'XColor','none', ...
    'YColor','none', ...
    'TickDir','out', ...
    'XTick',[], ...
    'YTick',[], ...
    'Color','none');

exportgraphics(fig, 'paper/trial_average.png', 'Resolution', 300);


% set([ax1 ax2], 'Units','normalized');
% 
% leftMargin   = 0.08;
% rightMargin  = 0.03;
% bottomMargin = 0.18;
% topMargin    = 0.08;
% gap          = 0.05;
% 
% axW = (1 - leftMargin - rightMargin - gap)/2;
% axH = 1 - bottomMargin - topMargin;
% 
% ax1.Position = [leftMargin,              bottomMargin, axW, axH];
% ax2.Position = [leftMargin + axW + gap,  bottomMargin, axW, axH];
% % Keep data on top
% uistack(findobj(gca,'Type','line'),'top')
% hold off
% yticklabels([])
% ax = gca;
% ax.FontWeight = 'bold';
% title('Closed Loop')
% figure_property.Width= '16'; % Figure width on canvas
% figure_property.Height= '9'; % Figure height on canvas
% if a == 1
%     hgexport(gcf,append('images/comp_controllers',mn,td,num2str(en),'.pdf'),figure_property); %Set desired file name
% end
% % exportgraphics(gcf,'P1.png','Resolution',1500)
% uiwait(k)

%% var analysis

% nc_var = var(ncDfk - nc_avg);
% wc_var = var(wcDfk - wc_avg);


nc_var = var(pncDfk);
wc_var = var(pwcDfk);
% nc_var = mean(ncDfk);
% wc_var = mean(wcDfk);


% close all;
fig= figure('Color','w'); hold on;
fig.Units    = 'inches';
fig.Position = [1, 1, 6, 4];

plot(T,nc_var,'r','LineWidth',2);hold on
plot(T,wc_var,'Color', [0 0.5 0],'LineWidth',2);
xline(0,'LineWidth',1.5)
xline(dur,'LineWidth',1.5)
ylim([-2,12])

% shortCornerAxes(gca, 'XLabel','Time(s)', 'YLabel','Variance', 'Frac',0.10,'LineWidth',5);
% xlabel('time(sec)','FontSize',12,'FontWeight','bold')
% ylabel('variance','FontSize',12,'FontWeight','bold')
% legend('Open Loop', 'Closed loop')
yl = ylim;   % current y-limits

patch([x1 x2 x2 x1], ...
      [yl(1) yl(1) yl(2) yl(2)], ...
      [0.9 0.9 0.9], ...
      'FaceAlpha', 0.3, ...
      'EdgeColor', 'none');
 shortCornerAxes_plot(gca, 'XLength', 1, 'YLength', 2, ...
      'XLabel', '1 sec', 'YLabel', 'Variance', 'LineWidth', 5,'LabelGap',  0.04)

% Keep data on top
uistack(findobj(gca,'Type','line'),'top')
hold off





% % title('Variance Comparision')
% figure_property.Width= '16'; % Figure width on canvas
% figure_property.Height= '9'; % Figure height on canvas
% if a == 1
% hgexport(gcf,append('images/comp_var',mn,td,num2str(en),'.pdf'),figure_property); %Set desired file name
% end
% exportgraphics(gcf,'P2.png','Resolution',1500)
% uiwait(k)



exportgraphics(fig, 'paper/variance.png', 'Resolution', 300);



%%


fig= figure('Color','w'); hold on;
fig.Units    = 'inches';
fig.Position = [1, 1, 6, 4];
% figure(); hold on;

halfWidth = 0.3;
alphaFill = 0.5;


k=1
colA = [1 0 0];
colB = [0  0.5 0];


    [fA, yA] = ksdensity(data.er_ncDfk);
    fA = fA / max(fA) * halfWidth;

    fill([k - fA, k*ones(size(fA))], ...
         [yA,      fliplr(yA)], ...
         colA, 'FaceAlpha', alphaFill, 'EdgeColor','none');

    % Mean line A
    muA = mean(data.er_ncDfk);
    plot([ k - 0.1], [ muA], 'r*', 'LineWidth', 1.5);

    % -------- Distribution B (right) --------
    [fB, yB] = ksdensity(data.er_wcDfk);
    fB = fB / max(fB) * halfWidth;

    fill([k + fB, k*ones(size(fB))], ...
         [yB,      fliplr(yB)], ...
         colB, 'FaceAlpha', alphaFill, 'EdgeColor','none');

    % Mean line B
    muB = mean(data.er_wcDfk);
    plot([k+0.1], [ muB], 'g*', 'LineWidth', 5);



xticklabels([])
yticklabels([])
set(gca, ...
    'Box','off', ...
    'XColor','none', ...
    'YColor','none', ...
    'TickDir','out', ...
    'XTick',[], ...
    'YTick',[], ...
    'Color','none');

% shortCornerAxes_plot(gca,'Frac',0.10,'XLabel','MSE','YLabel','Trial Error','LineWidth',5)

yl = ylim;
xl = xlim;
text(xl(1) - 0.1*diff(xl), mean(yl), 'Trial MSE', ...
    'Color','k', 'FontSize', 12, 'FontWeight','bold', ...
    'HorizontalAlignment','center', 'VerticalAlignment','bottom', ...
    'Rotation', 90, 'Clipping','off');


exportgraphics(fig, 'paper/MSE_disttribution.png', 'Resolution', 300);

end

