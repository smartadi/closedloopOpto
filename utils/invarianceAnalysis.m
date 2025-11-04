%% Invariance analysis

function invarianceAnalysis(data,d)

wc=data.wc;
nc=data.nc;
tt = d.inpTime;
v = d.inpVals;

er_wcDfk = data.er_wcDfk;
er_ncDfk = data.er_ncDfk;

pwcDfk = data.pwcDfk;
pncDfk = data.pncDfk;

er = sort(er_wcDfk);
ner = sort(er_ncDfk);
dur = d.params.dur
t = d.timeBlue;

% close all;
inv_wc = data.wcDfk(:,35:35*(dur+1));
inv_nc = data.ncDfk(:,35:35*(dur+1));

var_inv_wc = var(reshape(inv_wc.',1,[]));
var_inv_nc = var(reshape(inv_nc.',1,[]));


inv_wc = data.wcDfk(:,35:35*(dur+1));
inv_nc = data.ncDfk(:,35:35*(dur+1));

inv_wcl = data.pwcDfk;
inv_ncl = data.pncDfk;


var_wc = var(inv_wc);
var_nc = var(inv_nc);

var_wcl = var(inv_wcl);
var_ncl = var(inv_ncl);

inv_wc_max = max(inv_wc);
inv_wc_min = min(inv_wc);

inv_nc_max = max(inv_nc);
inv_nc_min = min(inv_nc);

inv_nc_mean = mean(inv_nc,1);
inv_wc_mean = mean(inv_wc,1);

NCvol = sum(inv_nc_max - inv_nc_mean - inv_nc_min)
WCvol = sum(inv_wc_max - inv_wc_mean - inv_wc_min)

% Invariance vol reduction
vol_red = (NCvol - WCvol)*100/NCvol

ts = 0:1/35:dur;


er_nc = (5+mean(mean(inv_nc,1)))*100/5
er_wc = (5+mean(mean(inv_wc,1)))*100/5


figure()
subplot(1,2,1)
plot(ts,inv_nc,'LineWidth',0.3,'HandleVisibility','off');hold on;
plot(ts,-5*ones(1,length(ts)),'k','LineWidth',2,'HandleVisibility','off'); hold on;
plot(ts,mean(inv_nc,1),'r','LineWidth',3);hold on;
plot(ts,inv_nc_max,'k','LineWidth',2,'HandleVisibility','off');
plot(ts,inv_nc_min,'k','LineWidth',2);
% plot(ts,sqrt(var_inv_nc)*ones(1,length(ts))+mean(inv_nc,1),'--k','LineWidth',2);
% plot(ts,-sqrt(var_inv_nc)*ones(1,length(ts))+mean(inv_nc,1),'--k','LineWidth',2,'HandleVisibility','off');

plot(ts,sqrt(var_nc).*ones(1,length(ts))+mean(inv_nc,1),'--k','LineWidth',3,'HandleVisibility','off');
plot(ts,-sqrt(var_nc).*ones(1,length(ts))+mean(inv_nc,1),'--k','LineWidth',3);

legend('trail average','min-max','deviation')
title(append('FFC, avg error=',num2str(er_nc),'%'))
xlabel('time','FontSize',12,'FontWeight','bold')
ylabel('dF/F','FontSize',12,'FontWeight','bold')
ylim([-15 15])
a = get(gca,'XTickLabel');
set(gca,'XTickLabel',a,'FontName','Times','fontsize',14)

subplot(1,2,2)
plot(ts,inv_wc,'LineWidth',0.3,'HandleVisibility','off');hold on;
plot(ts,-5*ones(1,length(ts)),'k','LineWidth',2,'HandleVisibility','off'); hold on;
plot(ts,mean(inv_wc,1),'r','LineWidth',3);hold on;
plot(ts,inv_wc_max,'k','LineWidth',1.5,'HandleVisibility','off');
plot(ts,inv_wc_min,'k','LineWidth',1.5);

plot(ts,sqrt(var_wc).*ones(1,length(ts))+mean(inv_wc,1),'--k','LineWidth',3,'HandleVisibility','off');
plot(ts,-sqrt(var_wc).*ones(1,length(ts))+mean(inv_wc,1),'--k','LineWidth',3);% plot(ts,-5*ones(1,length(ts)),'--r','LineWidth',1,'HandleVisibility','off');
% legend('trail average','min-max','std dev')
title(append('FBC, avg error=',num2str(er_wc),'%'))
ylim([-15 15])
xlabel('time','FontSize',14,'FontWeight','bold')
ylabel('dF/F','FontSize',14,'FontWeight','bold')
a = get(gca,'XTickLabel');
set(gca,'XTickLabel',a,'FontName','Times','fontsize',14)
sgtitle('dF/F traces')

% % figure()
% subplot(2,2,3)
% % plot(ts,inv_nc,'LineWidth',0.3,'HandleVisibility','off');hold on;
% % plot(ts,-5*ones(1,length(ts)),'--r','LineWidth',1,'HandleVisibility','off'); hold on;
% % plot(ts,mean(inv_nc,1),'--k','LineWidth',3.5);hold on;
% plot(ts,inv_nc_max - inv_nc_mean ,'k','LineWidth',2,'HandleVisibility','off');hold on;
% plot(ts,inv_nc_min - inv_nc_mean,'k','LineWidth',2);
% plot(ts,sqrt(var_inv_nc)*ones(1,length(ts)),'--k','LineWidth',2);
% plot(ts,-sqrt(var_inv_nc)*ones(1,length(ts)),'--k','LineWidth',2,'HandleVisibility','off');
% legend('min-max','std dev','FontSize',14,'FontWeight','Bold')
% title('dF/F envelope wrt avg')
% ylim([-15 15]) 
% xlabel('time','FontSize',14,'FontWeight','bold')
% ylabel('relative dF/F ','FontSize',14,'FontWeight','bold')
% a = get(gca,'XTickLabel');
% set(gca,'XTickLabel',a,'FontName','Times','fontsize',14)
% 
% 
% subplot(2,2,4)
% % plot(ts,inv_wc,'LineWidth',0.3,'HandleVisibility','off');hold on;
% % plot(ts,-5*ones(1,length(ts)),'--r','LineWidth',1,'HandleVisibility','off'); hold on;
% % plot(ts,mean(inv_wc,1),'--k','LineWidth',3.5);hold on;
% plot(ts,inv_wc_max - inv_wc_mean,'k','LineWidth',2,'HandleVisibility','off'); hold on;
% plot(ts,inv_wc_min - inv_wc_mean,'k','LineWidth',2);
% 
% plot(ts,sqrt(var_inv_wc)*ones(1,length(ts)),'--k','LineWidth',2);
% plot(ts,-sqrt(var_inv_wc)*ones(1,length(ts)),'--k','LineWidth',2,'HandleVisibility','off');
% 
% plot(ts,sqrt(var_wc).*ones(1,length(ts)),'--g','LineWidth',2,'HandleVisibility','off');
% plot(ts,-sqrt(var_wc).*ones(1,length(ts)),'--g','LineWidth',2,'HandleVisibility','off');
% 
% 
% % plot(ts,-5*ones(1,length(ts)),'--r','LineWidth',1,'HandleVisibility','off');
% % legend('min-max','std dev','FontSize',14,'FontWeight','Bold')
% % title('dF/F traces FBC variance')
% title(append('dF/F envelope size reduction ',num2str(vol_red),'%'))
% ylim([-15 15])
% xlabel('time','FontSize',14,'FontWeight','bold')
% % ylabel('dF/F relative to trial-average','FontSize',18,'FontWeight','bold')
% a = get(gca,'XTickLabel');
% set(gca,'XTickLabel',a,'FontName','Times','fontsize',14)
red_ratio = sum(var_wc/var_nc);

figure()
plot(ts,var_wc,'g','LineWidth',2);hold on;
plot(ts,var_nc,'r','LineWidth',2);
legend('FBC','FFC')
xlabel('time','FontSize',14,'FontWeight','bold')
ylabel('variance','FontSize',14,'FontWeight','bold')
title(append('variance across experiment, reduction ratio = ',num2str(red_ratio)))


tsl = -10:1/35:6;
figure()
plot(tsl,var_wcl,'g','LineWidth',2);hold on;
plot(tsl,var_ncl,'r','LineWidth',2);
legend('FBC','FFC')
xlabel('time','FontSize',14,'FontWeight','bold')
ylabel('variance','FontSize',14,'FontWeight','bold')
title(append('variance across experiment, reduction ratio = ',num2str(red_ratio)))
xline(0,'LineWidth',2,'HandleVisibility','off')
xline(3,'LineWidth',2,'HandleVisibility','off')
xlim([-5,6])

%Inv Volumes

NCvol = sum(inv_nc_max - inv_nc_mean - inv_nc_min)
WCvol = sum(inv_wc_max - inv_wc_mean - inv_wc_min)

% Invariance vol reduction
vol_red = (NCvol - WCvol)*100/NCvol

%
m = min(inv_nc_mean);
m2 = mean(inv_nc_mean(end-35:end))
j = 7;
figure()
% plot(ts,inv_nc);hold on;
plot(ts,inv_nc_mean - m2,'r','LineWidth', 2);hold on;
% plot(ts,m*ones(1,length(inv_nc_mean)),'--k','LineWidth', 2);hold on;
% plot(ts,m2*ones(1,length(inv_nc_mean)),'--k','LineWidth', 2);hold on;
plot(ts,0*ones(1,length(inv_nc_mean)),'--k','LineWidth', 2);hold on;

xlabel('time')
ylabel('dF/F wrt mean')
% ylim([-8 2])
title('Step response deviation from mean')
end