%% make_fig11_grid.m -- grant Fig 11 as ONE 2x3 image, identical template both rows.
% Row 1 = constant (static) target; Row 2 = sine target with model-based preview.
% Each row: (1) CL vs OL comparison on the best session (trial-avg mean +/- SEM);
%           (2) variance reduction across sessions;  (3) RMSE improvement across sessions.
% OL=red, CL/CL+preview=blue throughout. Reads the two scratchpad dumps.
clc; close all; PS=paperStyle();
S=r_load('C:\Users\aditya\AppData\Local\Temp\claude\C--Users-aditya-Documents-projects-brain-paper\69483c53-45a2-45f3-9e5d-0965ff7a6be0\scratchpad\const_fig11.mat');
Q=r_load('C:\Users\aditya\AppData\Local\Temp\claude\C--Users-aditya-Documents-projects-brain-paper\69483c53-45a2-45f3-9e5d-0965ff7a6be0\scratchpad\sine_fig11.mat');
OUT='C:\Users\aditya\Documents\projects\draft\grant_2026_10_YazdanSteinmetz\figs2\cl_controller.png';
cOL=PS.col_ol; cCL=PS.col_cl; fs=PS.fs;
rows={S,Q}; clLab={'CL','CL+preview'}; rowName={'Constant target','Sine target + preview'};

fig=figure('Color','w','Units','centimeters','Position',[1 1 16 8.4]);
tl=tiledlayout(fig,2,3,'TileSpacing','compact','Padding','compact');

for r=1:2
    D=rows{r};
    % ---------- P1: CL vs OL trace comparison (best session) ----------
    ax=nexttile(tl); hold(ax,'on');
    yl=[min([D.ol_mean-D.ol_sem, D.cl_mean-D.cl_sem]) max([D.ol_mean+D.ol_sem, D.cl_mean+D.cl_sem])];
    yl=yl+[-.08 .08]*range(yl);
    patch(ax,[D.laser(1) D.laser(2) D.laser(2) D.laser(1)],[yl(1) yl(1) yl(2) yl(2)], ...
        [0.92 0.92 0.92],'EdgeColor','none');
    band(ax,D.t,D.ol_mean,D.ol_sem,cOL); band(ax,D.t,D.cl_mean,D.cl_sem,cCL);
    hOL=plot(ax,D.t,D.ol_mean,'Color',cOL,'LineWidth',PS.lw_mean);
    hCL=plot(ax,D.t,D.cl_mean,'Color',cCL,'LineWidth',PS.lw_mean);
    if r==1; plot(ax,D.laser,[D.ref D.ref],'k--','LineWidth',PS.lw_ref);
    else;    plot(ax,D.tref,D.ref,'k--','LineWidth',PS.lw_ref); end
    hold(ax,'off'); xlim(ax,[D.t(1) D.t(end)]); ylim(ax,yl);
    xlabel(ax,'Time (s)','FontSize',fs,'FontWeight','bold');
    ylabel(ax,'\DeltaF/F (%)','FontSize',fs,'FontWeight','bold');
    title(ax,{rowName{r},'single session (best)'},'FontSize',fs,'FontWeight','bold');
    stylize(ax,fs);
    lg=legend([hOL hCL],{'OL',clLab{r}},'Location','southeast'); set(lg,'Box','off','FontSize',5);

    % ---------- P2: variance reduction across sessions ----------
    ax=nexttile(tl); paired(ax,D.varOL,D.varCL,cOL,cCL,clLab{r},fs);
    ylabel(ax,'Across-trial variance','FontSize',fs,'FontWeight','bold');
    title(ax,{'Variance, across sessions',sprintf('n=%d, %s',numel(D.varOL),pstr(D.pVar))},'FontSize',fs,'FontWeight','bold');

    % ---------- P3: RMSE improvement across sessions ----------
    ax=nexttile(tl);
    if isfield(D,'medOL'); paired(ax,D.medOL,D.medCL,cOL,cCL,clLab{r},fs); nR=numel(D.medOL);
    else;                  paired(ax,D.rmseOL,D.rmseCL,cOL,cCL,clLab{r},fs); nR=numel(D.rmseOL); end
    ylabel(ax,'Trial RMSE (%\DeltaF/F)','FontSize',fs,'FontWeight','bold');
    title(ax,{'RMSE, across sessions',sprintf('n=%d, %s',nR,pstr(D.pRMSE))},'FontSize',fs,'FontWeight','bold');
end
exportgraphics(fig,OUT,'Resolution',300);
fprintf('[fig11] wrote %s\n',OUT);

% ---- helpers ----
function s=r_load(p); s=load(p); end
function band(ax,t,m,e,c); fill(ax,[t fliplr(t)],[m+e fliplr(m-e)],c,'FaceAlpha',0.18,'EdgeColor','none'); end
function stylize(ax,fs); set(ax,'Box','off','TickDir','out','FontSize',fs,'FontWeight','bold'); end
function s=pstr(p)
  if isnan(p), s='n.s.'; elseif p<1e-3, s=sprintf('p=%.0e',p); else, s=sprintf('p=%.3g',p); end
end
function paired(ax,a,b,cOL,cCL,clLab,fs)
  hold(ax,'on'); a=a(:); b=b(:);
  for i=1:numel(a); plot(ax,[1 2],[a(i) b(i)],'-','Color',[0.7 0.7 0.7],'LineWidth',0.4); end
  plot(ax,ones(size(a)),a,'o','MarkerFaceColor',cOL,'MarkerEdgeColor','none','MarkerSize',3.5);
  plot(ax,2*ones(size(b)),b,'o','MarkerFaceColor',cCL,'MarkerEdgeColor','none','MarkerSize',3.5);
  plot(ax,[0.82 1.18],[median(a) median(a)],'-','Color',cOL,'LineWidth',2);
  plot(ax,[1.82 2.18],[median(b) median(b)],'-','Color',cCL,'LineWidth',2);
  hold(ax,'off'); xlim(ax,[0.5 2.5]);
  set(ax,'XTick',[1 2],'XTickLabel',{'OL',clLab},'Box','off','TickDir','out','FontSize',fs,'FontWeight','bold');
  yl=ylim(ax); ylim(ax,[min(0,yl(1)) yl(2)+0.05*range(yl)]);
end
