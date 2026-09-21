%% make_statedep_grant.m -- grant fig:statedep in the PAPER Figure-4 row-2 style.
% Borrows the published panel grammar (grouped OL/CL bars per within-session state
% quartile + OL-CL gap trend line + cond x state LMM star) instead of violins.
% Two states that carry the story: Movement (motion) and pre-stim 2-4 Hz (delta).
% Outcome = disturbance-rejection RMSE over [+1,+3] s, z-scored within session
% (removes session baseline, keeps OL-vs-CL level) -- identical to f4_row2_quartiles.
% Self-contained single figure with a shared y-label + legend; exports ONE PNG.
% Run after: r_lean=0; load_sessions;   (needs mouse/fields with full data)
clc; close all;
PS = paperStyle(); setPaperDefaults();
assert(exist('mouse','var') && exist('fields','var'), 'run load_sessions.m (full) first.');
colOL = PS.col_ol; colCL = PS.col_cl; colGap = [0.15 0.15 0.15];
OUT = 'C:\Users\aditya\Documents\projects\draft\grant_2026_10_YazdanSteinmetz\figs2\ctrl_statedep.png';

[POOL,~] = f4_row2_pool(mouse, fields);
states = {'motion','delta'};
titl   = {'Movement','Pre-stimulus 2\times4 Hz'};      % placeholder dash fixed below
titl   = {'Movement','Pre-stimulus 2-4 Hz'};
xlabs  = {'Movement quartile','Pre-stim 2-4 Hz quartile'};

fig = paperFig(6.2, 6.8);
tl  = tiledlayout(fig,2,1,'Padding','compact','TileSpacing','compact');
YL  = [-0.65 1.40];

for ip = 1:numel(states)
    nm = states{ip}; T = POOL.(nm);
    % ---- per-session z-score (combined OL+CL), then pool (matches the paper panel) ----
    us = unique(T.sess); zx=[]; zy=[]; g=[];
    for s = us(:)'
        idx = T.sess==s; y = T.y(idx); x = T.x(idx); c = double(T.cond(idx)=='CL');
        muY=mean(y,'omitnan'); sgY=std(y,'omitnan'); if sgY==0||isnan(sgY); continue; end
        muX=mean(x,'omitnan'); sgX=std(x,'omitnan'); if sgX==0||isnan(sgX); continue; end
        zy=[zy;(y-muY)/sgY]; zx=[zx;(x-muX)/sgX]; g=[g;c];
    end
    edg = quantile(zx,[0 .25 .5 .75 1]); edg = uniqedges(edg);
    qb  = discretize(zx,edg); qb(isnan(qb))=4;
    qmO=nan(1,4);qmC=nan(1,4);qsO=nan(1,4);qsC=nan(1,4);
    for b=1:4
        oo=qb==b&g==0; cc=qb==b&g==1;
        qmO(b)=mean(zy(oo),'omitnan'); qmC(b)=mean(zy(cc),'omitnan');
        qsO(b)=std(zy(oo),'omitnan')/sqrt(max(1,nnz(oo)));
        qsC(b)=std(zy(cc),'omitnan')/sqrt(max(1,nnz(cc)));
    end
    gapq = qmO-qmC;
    pC = f4_row2_fit(T).decP;                         % session-aware LMM cond x state (the star)

    ax = nexttile(tl); hold(ax,'on');
    yline(ax,0,'-','Color',[0.6 0.6 0.6],'LineWidth',0.5);
    xq=1:4; w=0.36;
    bar(ax,xq-w/2,qmO,w,'FaceColor',colOL,'EdgeColor','none');
    bar(ax,xq+w/2,qmC,w,'FaceColor',colCL,'EdgeColor','none');
    errorbar(ax,xq-w/2,qmO,qsO,'k','LineStyle','none','LineWidth',0.5,'CapSize',2);
    errorbar(ax,xq+w/2,qmC,qsC,'k','LineStyle','none','LineWidth',0.5,'CapSize',2);
    plot(ax,xq,gapq,'-o','Color',colGap,'MarkerFaceColor',colGap,'MarkerSize',2.5,'LineWidth',0.9);
    set(ax,'XTick',1:4,'XTickLabel',{'Q1','Q2','Q3','Q4'},'Box','off','TickDir','out', ...
        'FontSize',PS.fs,'FontWeight','bold');
    xlim(ax,[0.4 4.6]); ylim(ax,YL); yl=ylim(ax);
    xlabel(ax,xlabs{ip},'FontSize',PS.fs,'FontWeight','bold');
    title(ax,sprintf('%s  (%d tr)',titl{ip},height(T)),'FontSize',PS.fs,'FontWeight','bold');
    text(ax,2.5,yl(2)-0.02*range(yl),sprintf('cond\\timesstate %s',starstr(pC)), ...
        'HorizontalAlignment','center','VerticalAlignment','top','FontSize',6,'FontWeight','bold','Color',[0.1 0.1 0.1]);
    text(ax,2.5,yl(2)-0.02*range(yl)-0.12*range(yl),sprintf('LMM p=%.2g',pC), ...
        'HorizontalAlignment','center','VerticalAlignment','top','FontSize',5,'Color',[0.35 0.35 0.35]);
    ylabel(ax,'Rejection RMSE to ref (z)','FontSize',PS.fs,'FontWeight','bold');
    if ip==1
        xL=0.62; yTop=yl(2)-0.06*range(yl); dh=0.105*range(yl);
        plot(ax,xL,yTop,'s','MarkerFaceColor',colOL,'MarkerEdgeColor','none','MarkerSize',5);
        text(ax,xL+0.16,yTop,'Open loop','FontSize',5,'FontWeight','bold','Color',colOL,'VerticalAlignment','middle');
        plot(ax,xL,yTop-dh,'s','MarkerFaceColor',colCL,'MarkerEdgeColor','none','MarkerSize',5);
        text(ax,xL+0.16,yTop-dh,'Closed loop','FontSize',5,'FontWeight','bold','Color',colCL,'VerticalAlignment','middle');
        plot(ax,xL,yTop-2*dh,'o','MarkerFaceColor',colGap,'MarkerEdgeColor','none','MarkerSize',3);
        text(ax,xL+0.16,yTop-2*dh,'OL-CL gap','FontSize',5,'FontWeight','bold','Color',colGap,'VerticalAlignment','middle');
    end
    hold(ax,'off');
end
exportgraphics(fig, OUT, 'Resolution', 300);
fprintf('[statedep-grant] wrote %s\n', OUT);

function e=uniqedges(e); for i=2:numel(e); if e(i)<=e(i-1); e(i)=e(i-1)+eps(e(i-1))*1e3; end; end; end
function s=starstr(p); if isnan(p), s='n.s.'; elseif p<1e-3, s='***'; elseif p<1e-2, s='**'; elseif p<0.05, s='*'; else, s='n.s.'; end; end
