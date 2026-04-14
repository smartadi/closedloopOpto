function r = analysisPlots_var(data,d,a)

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




% Ref=[];
% for j = 1: length(d.stimStarts)
%     [a i] = min(abs(d.timeBlue - d.stimStarts((j))));
%     Ref = [Ref; d.ref_var(i:i+35*(d.params.dur))'];
% end
% 
% rref = Ref(end,:)



Ref=[];
j = nc(1)
    [a i] = min(abs(d.timeBlue - d.stimStarts(j)));
    Ref = [Ref;(-5)*d.iputs(i:i+35*(d.params.dur))'];


rref = Ref(end,:)


% Tin = 0:0.0005:stimDur(j);
Tout = -3:0.0285:dur+3;
Tref = 0:0.0285:dur;
figure()
ax1 = subplot(1,2,1)
hA = plot(Tout,dFk((i-(3*35)):(i+35*(dur+3))),'r','LineWidth',3);hold on
hB = plot(Tref,rref,'--k','LineWidth',2)
hC = plot(tt(k:k2)-tt(k),2*v(k:k2),'b','LineWidth',3)
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
shortCornerAxes_plot(gca,'Frac',0.10,'XLabel','Time (s)','YLabel','\DeltaF/F','LineWidth',5)

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
hD = plot(Tout,dFk((i-(3*35)):(i+35*(dur+3))),'Color',[0,0.5,0],'LineWidth',3);hold on
hB = plot(Tref,rref,'--k','LineWidth',2)
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


legend(ax2, [hA hD hC hB], {'Closed Loop', 'Open Loop','Stim', 'Ref'}, ...
    'Location','northeast', ...
    'Box','off', FontSize=12, FontWeight='bold')
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
nc_avg = mean(pncDfk,1);
wc_avg = mean(pwcDfk,1);
T= -3:0.0285:(dur+3);
Tin = 0:0.0005:dur;
Tout = 0:0.0285:dur;

%% Error
figure()
subplot(1,2,1)
plot(Tout,abs(data.ncDfk(:,1*35:(1+dur)*35) - rref),'Color', [1 0 0 0.1],'LineWidth',0.5);hold on;
plot(Tout,abs(mean(data.ncDfk(:,1*35:(1+dur)*35) - rref)),'Color', [1 0 0],'LineWidth',4);hold on;
yline(0)
ylim([-1,10])
shortCornerAxes_plot(gca,'Frac',0.10,'XLabel','Time (s)','YLabel','Error \DeltaF/F','LineWidth',5)


subplot(1,2,2)
plot(Tout,abs(data.wcDfk(:,1*35:(1+dur)*35) - rref),'Color', [0 0.5 0 0.1],'LineWidth',0.5);hold on;
plot(Tout,abs(mean(data.wcDfk(:,1*35:(1+dur)*35) - rref)),'Color', [0 0.5 0],'LineWidth',4);hold on;
yline(0)
ylim([-1,10])
shortCornerAxes_plot(gca,'Frac',0.20,'XLabel','Time (s)','YLabel','Error \DeltaF/F','LineWidth',5)
%% full experiment




figure()

% Column (vertical band) to shade
x1 = 0;
x2 = (dur);

size(T)
size(pncDfk)
% ref = [zeros(1,35*3), d.ref*ones(1,3*35),zeros(1,35*3+1)];
Tref = 0:1/35:dur;
ax1 = subplot(1,2,1)
plot(T,pncDfk,'Color', [1 0 0 0.1],'LineWidth',0.5);hold on
% plot(T,d.ref*ones(1,length(T)),'--k','Linewidth',3);hold on
% plot(T,ref,'--k','Linewidth',3);hold on
plot(Tref,rref,'--k','LineWidth',2)

% plot(Tref,d.ref*ones(3*35+1),'--k','Linewidth',3);hold on
plot(T,nc_avg,'r','Linewidth',3);
plot(Tin,data.ncInp,'b','LineWidth',3);
xline(0)
xline(dur)
shortCornerAxes_plot(gca,'Frac',0.10,'XLabel','Time (s)','YLabel','\DeltaF/F','LineWidth',5)

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

% Keep data on top
uistack(findobj(gca,'Type','line'),'top')
hold off
% yticklabels([])

% title('Open Loop')
% ax = gca;
% ax.FontWeight = 'bold';
ax2 = subplot(1,2,2)
plot(T,pwcDfk,'Color', [0 0.5 0 0.1],'LineWidth',0.5);hold on
plot(Tref,rref,'--k','LineWidth',2)
% plot(Tref,d.ref*ones(3*35+1),'--k','Linewidth',3);hold on
plot(T,wc_avg,'Color', [0 0.5 0],'Linewidth',3);
plot(Tin,mean(data.wcInp),'b','LineWidth',3);
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
%%

% 
% figure()
% 
% % Column (vertical band) to shade
% x1 = 0;
% x2 = (dur);
% 
% 
% % ref = [zeros(1,35*3), d.ref*ones(1,3*35),zeros(1,35*3+1)];
% Tref = 0:1/35:dur;
% Ti = -1:1/2000:(dur+1);
% ax1 = subplot(1,2,1)
% plot(Ti,data.inp_nc,'Color', [1 0 0.5 0.1],'LineWidth',0.5);hold on
% % plot(T,d.ref*ones(1,length(T)),'--k','Linewidth',3);hold on
% % plot(T,ref,'--k','Linewidth',3);hold on
% plot(Tref,rref,'--k','LineWidth',2)
% 
% % plot(Tref,d.ref*ones(3*35+1),'--k','Linewidth',3);hold on
% plot(Ti,mean(data.inp_nc),'Color', [1 0 0.5],'Linewidth',3);
% xline(0)
% xline(dur)
% shortCornerAxes_plot(gca,'Frac',0.10,'XLabel','Time (s)','YLabel','\DeltaF/F','LineWidth',5)
% 
% % shortCornerAxes(gca, 'XLabel','Time(s)', 'YLabel','\DeltaF/F', 'Frac',0.10,'LineWidth',5);
% % xlabel('time(sec)','FontSize',12,'FontWeight','bold')
% % ylabel('dF/F %','FontSize',12,'FontWeight','bold')
% ylim([-10 10])
% xlim([-3,6])
% yl = ylim;   % current y-limits
% 
% patch([x1 x2 x2 x1], ...
%       [yl(1) yl(1) yl(2) yl(2)], ...
%       [0.9 0.9 0.9], ...
%       'FaceAlpha', 0.3, ...
%       'EdgeColor', 'none');
% 
% % Keep data on top
% uistack(findobj(gca,'Type','line'),'top')
% hold off
% % yticklabels([])
% 
% % title('Open Loop')
% % ax = gca;
% % ax.FontWeight = 'bold';
% ax2 = subplot(1,2,2)
% plot(Ti,data.inp_wc,'Color', [0 0.5 0.5 0.1],'LineWidth',0.5);hold on
% plot(Tref,rref,'--k','LineWidth',2)
% % plot(Tref,d.ref*ones(3*35+1),'--k','Linewidth',3);hold on
% plot(Ti,mean(data.inp_wc),'Color', [0 0.5 0.5],'Linewidth',3);
% xline(0)
% xline(dur)
% ylim([-10 10])
% xlim([-3,6])
% % xlabel('time(sec)','FontSize',12,'FontWeight','bold')
% 
% yl = ylim;   % current y-limits
% 
% patch([x1 x2 x2 x1], ...
%       [yl(1) yl(1) yl(2) yl(2)], ...
%       [0.9 0.9 0.9], ...
%       'FaceAlpha', 0.3, ...
%       'EdgeColor', 'none');
% 
% xticklabels([])
% yticklabels([])
% set(gca, ...
%     'Box','off', ...
%     'XColor','none', ...
%     'YColor','none', ...
%     'TickDir','out', ...
%     'XTick',[], ...
%     'YTick',[], ...
%     'Color','none');
% 
% 
% 
% % set([ax1 ax2], 'Units','normalized');
% % 
% % leftMargin   = 0.08;
% % rightMargin  = 0.03;
% % bottomMargin = 0.18;
% % topMargin    = 0.08;
% % gap          = 0.05;
% % 
% % axW = (1 - leftMargin - rightMargin - gap)/2;
% % axH = 1 - bottomMargin - topMargin;
% % 
% % ax1.Position = [leftMargin,              bottomMargin, axW, axH];
% % ax2.Position = [leftMargin + axW + gap,  bottomMargin, axW, axH];
% % % Keep data on top
% % uistack(findobj(gca,'Type','line'),'top')
% % hold off
% % yticklabels([])
% % ax = gca;
% % ax.FontWeight = 'bold';
% % title('Closed Loop')
% % figure_property.Width= '16'; % Figure width on canvas
% % figure_property.Height= '9'; % Figure height on canvas
% % if a == 1
% %     hgexport(gcf,append('images/comp_controllers',mn,td,num2str(en),'.pdf'),figure_property); %Set desired file name
% % end
% % % exportgraphics(gcf,'P1.png','Resolution',1500)
% % uiwait(k)

%% var analysis

% nc_var = var(ncDfk - nc_avg);
% wc_var = var(wcDfk - wc_avg);


nc_var = var(pncDfk,1,1);
wc_var = var(pwcDfk,1,1);
% nc_var = mean(ncDfk);
% wc_var = mean(wcDfk);

display('var size')
size(nc_var)

% close all;
figure()
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
shortCornerAxes_plot(gca,'Frac',0.10,'XLabel','Time (s)','YLabel','Variance','LineWidth',5)

% Keep data on top
uistack(findobj(gca,'Type','line'),'top')
hold off



%%
figure(); hold on;

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
    plot([k+0.1], [ muB], 'g*', 'LineWidth', 1.5);

ax.FontSize = 16
xticks([])

shortCornerAxes_plot(gca,'Frac',0.10,'XLabel','MSE','YLabel','Trials','LineWidth',5)




end

