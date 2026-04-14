function r = analysisPlots(data,d,a)

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
close all;
%
dur = d.params.dur;
ncDfk = data.ncDfk;
wcDfk = data.wcDfk;
nc_avg = mean(ncDfk,1);
wc_avg = mean(wcDfk,1);
T= -1:0.0285:(dur+1);
Tin = 0:0.0005:dur;
Tout = 0:0.0285:dur;

k = figure()
subplot(1,2,1)
plot(T,ncDfk);hold on
plot(T,d.ref*ones(1,length(T)),'--r','Linewidth',3);hold on
plot(T,nc_avg,'k','Linewidth',3);
xline(0)
xline(dur)
xlabel('time(sec)','FontSize',12,'FontWeight','bold')
ylabel('dF/F %','FontSize',12,'FontWeight','bold')
ylim([-20 20])
xlim([-1 4])
title('Open Loop')

subplot(1,2,2)
plot(T,wcDfk);hold on
plot(T,d.ref*ones(1,length(T)),'--r','Linewidth',3);hold on
plot(T,wc_avg,'k','Linewidth',3);
xline(0)
xline(dur)
ylim([-20 20])
xlim([-1 4])
title('Closed Loop')
figure_property.Width= '16'; % Figure width on canvas
figure_property.Height= '9'; % Figure height on canvas
if a == 1
    hgexport(gcf,append('images/comp_controllers',mn,td,num2str(en),'.pdf'),figure_property); %Set desired file name
end
% exportgraphics(gcf,'P1.png','Resolution',1500)
% uiwait(k)

%% var analysis

% nc_var = var(ncDfk - nc_avg);
% wc_var = var(wcDfk - wc_avg);


nc_var = var(ncDfk);
wc_var = var(wcDfk);
% nc_var = mean(ncDfk);
% wc_var = mean(wcDfk);


% close all;
k = figure()
plot(T,nc_var,'r','LineWidth',2);hold on
plot(T,wc_var,'g','LineWidth',2);
xline(0,'LineWidth',1.5)
xline(dur,'LineWidth',1.5)
ylim([-2,12])
xlabel('time(sec)','FontSize',12,'FontWeight','bold')
ylabel('variance','FontSize',12,'FontWeight','bold')
legend('Open Loop', 'Closed loop')
title('Variance Comparision')
figure_property.Width= '16'; % Figure width on canvas
figure_property.Height= '9'; % Figure height on canvas
if a == 1
hgexport(gcf,append('images/comp_var',mn,td,num2str(en),'.pdf'),figure_property); %Set desired file name
end
% exportgraphics(gcf,'P2.png','Resolution',1500)
% uiwait(k)
%% Tracking error

% nc_var = var(ncDfk - nc_avg);
% wc_var = var(wcDfk - wc_avg);


nc_er = mean(ncDfk) - d.ref;
wc_er = mean(wcDfk) - d.ref;
% nc_var = mean(ncDfk);
% wc_var = mean(wcDfk);


% close all;
k = figure()
plot(T,nc_er,'r','LineWidth',2);hold on
plot(T,wc_er,'g','LineWidth',2);
plot(T,0*ones(1,length(T)),'--k','Linewidth',3);hold on
xline(0,'LineWidth',1.5)
xline(dur,'LineWidth',1.5)
ylim([-2,12])
legend('Feedforward', 'Feedback')
title('Average Error')
figure_property.Width= '16'; % Figure width on canvas
figure_property.Height= '9'; % Figure height on canvas
if a ==1
hgexport(gcf,append('images/comp_error',mn,td,num2str(en),'.pdf'),figure_property); %Set desired file name
end
% uiwait(k)
%%
% close all;
k = figure()
subplot(1,2,1)
plot(T,nc_var,'r','LineWidth',2);hold on
plot(T,wc_var,'g','LineWidth',2);
xline(0,'LineWidth',1.5)
xline(dur,'LineWidth',1.5)
ylim([-2,12])
xlim([-1,4])
% legend('Feedforward', 'Feedback')
title('Variance Comparision')
subplot(1,2,2)
plot(T,nc_er,'r','LineWidth',2);hold on
plot(T,wc_er,'g','LineWidth',2);
plot(T,0*ones(1,length(T)),'--k','Linewidth',3);hold on
xline(0,'LineWidth',1.5)
xline(dur,'LineWidth',1.5)
ylim([-2,12])
xlim([-1,4])
legend('Feedforward', 'Feedback')
title('Average Error')
figure_property.Width= '16'; % Figure width on canvas
figure_property.Height= '9'; % Figure height on canvas
if a==1
hgexport(gcf,append('images/comp_var_error',mn,td,num2str(en),'.pdf'),figure_property); %Set desired file name
% exportgraphics(figure(1), 'comp.pdf',figure_property);
end

% uiwait(k)



%%
k = figure()
plot(data.er_ncDfk,'or','LineWidth',2);hold on;
plot(data.er_wcDfk,'og','LineWidth',2);
legend('Open Loop','Closed Loop')
title('H2 performance per trial')
ylabel('MSE')
xlabel('Trials')

if a==1
hgexport(gcf,append('images/comp_trial_error',mn,td,num2str(en),'.pdf'),figure_property); %Set desired file name
% exportgraphics(figure(1), 'comp.pdf',figure_property);
end
% exportgraphics(gcf,'P3.png','Resolution',1500)

% uiwait(k)


%%
k = figure()
plot(data.vr_ncDfk,'or','LineWidth',2);hold on;
plot(data.vr_wcDfk,'og','LineWidth',2);
legend('feedforward','feedback')
title('variance per trial')
ylabel('variance')
xlabel('Trials')

if a==1
hgexport(gcf,append('images/comp_trial_var',mn,td,num2str(en),'.pdf'),figure_property); %Set desired file name
% exportgraphics(figure(1), 'comp.pdf',figure_property);
end
% % uiwait(k)
end

