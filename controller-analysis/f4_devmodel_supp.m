% controller-analysis/f4_devmodel_supp.m
% ============================================================================
% FIGURE 4 -- SUPPLEMENTARY: error-contribution model on DEPARTURE FROM THE
% SESSION TRIAL-AVERAGE (not from ref).  [F4DEV]
%
% Bolsters the "unique contributors" claim: after removing the common evoked
% response (each session's trial-average CL trace), do the same three states
% still uniquely predict how a trial DEPARTS from the typical trial?
%
%   residual_t = wcDfk_t - mean_over_trials(wcDfk)      (per session)
%   outcome  = RMSE of residual over early (0-1 s) / late (1-3 s)
%   X1 = |residual(onset)|      (init dev FROM THE MEAN, not from ref)
%   X2 = mean rectified motion  (unchanged -- a separate behavioural channel)
%   X3 = rel 2-4 Hz             (unchanged -- a ratio, ~invariant to mean subtraction)
%
% PRIMARY (RMSE-to-ref, f4_partB_panels.m) is UNTOUCHED; this is a supplement.
% Output: paper/images/figure4/f4_1S_devmodel.pdf  + console compare to primary.
% Requires load_sessions.m.
% ============================================================================
clc; close all;
PS = paperStyle(); setPaperDefaults();
assert(exist('mouse','var') && exist('fields','var'), '[F4DEV] run load_sessions.m first.');
if exist(fullfile('paper','images'),'dir');            paper_root='paper';
elseif exist(fullfile('..','paper','images'),'dir');   paper_root=fullfile('..','paper');
else;  paper_root='paper'; warning('[F4DEV] cannot locate paper/.'); end
outdir = fullfile(paper_root,'images','figure4');

Fs=35; c0=36; c0_mot=71; c0_l=106; mot_pre=2; relopts=struct('pre',2,'post',3);
eE = c0:c0+round(1*Fs); lL = c0+round(1*Fs)+1:c0+round(3*Fs);
col = [0.20 0.40 0.75; 0.75 0.40 0.10; 0.55 0.25 0.60];
pred_names = {'Initial dev','Motion','Rel 2-4 Hz'}; staten={'init dev','motion','2-4 Hz'};
fitR2 = @(Xp,yp) 1 - sum((yp-[ones(size(Xp,1),1),Xp]*([ones(size(Xp,1),1),Xp]\yp)).^2)/max(sum((yp-mean(yp)).^2),eps);

%% ── Pool CL trials; residualize against the session trial-average ────────────
X1=[];X2=[];Xrel=[];YE=[];YL=[];SESS=[];
for k=1:numel(fields)
    s=mouse.(fields{k}); if isfield(s,'skip')&&s.skip;continue;end
    if ~isfield(s,'data');continue;end; if ~s.has_motion;continue;end
    dk=s.data; if ~isfield(dk,'wcmotion');continue;end
    dur=s.d.params.dur; nT=size(dk.wcDfk,1);
    smean = mean(dk.wcDfk,1,'omitnan');           % session trial-average CL trace
    resid = dk.wcDfk - smean;                     % departure of each trial from it
    x1 = abs(resid(:,c0));                         % init-dev FROM MEAN
    ws=max(1,c0_mot-round(mot_pre*Fs)); we=min(size(dk.wcmotion,2),c0_mot+round(dur*Fs)-1);
    x2 = mean(max(dk.wcmotion(1:nT,ws:we),0),2);   % rectified motion (same as primary)
    xrel = cl_reldelta(dk.pwcDfk_l,c0_l,Fs,relopts);
    yE = sqrt(mean(resid(1:nT,eE).^2,2));          % RMSE of departure, early
    yL = sqrt(mean(resid(1:nT,lL).^2,2));          %                     late
    m=min([nT numel(xrel)]);
    X1=[X1;x1(1:m)];X2=[X2;x2(1:m)];Xrel=[Xrel;xrel(1:m)]; %#ok<*AGROW>
    YE=[YE;yE(1:m)];YL=[YL;yL(1:m)];SESS=[SESS;repmat(k,m,1)];
end
ok=all(isfinite([X1 X2 Xrel YE YL]),2);
f=@(v) v(ok); [X1,X2,Xrel,YE,YL,SESS]=deal(f(X1),f(X2),f(Xrel),f(YE),f(YL),f(SESS));
n=numel(YE); nS=numel(unique(SESS));
Z=zscore([X1,X2,Xrel]);
fprintf('\n[F4DEV] %d CL trials / %d sessions (deviation-from-average model).\n', n, nS);

%% ── Partial R^2 per factor × window + bootstrap CI ──────────────────────────
outs={YE,YL}; nBoot=2000; rng(0);
Pr=nan(3,2); PrCI=nan(3,2,2); Rfull=nan(1,2);
for o=1:2
    y=outs{o}; rf=fitR2(Z,y); Rfull(o)=rf;
    for j=1:3, Pr(j,o)=rf-fitR2(Z(:,setdiff(1:3,j)),y); end
    bp=nan(nBoot,3);
    for b=1:nBoot
        ib=randsample(n,n,true); Xb=Z(ib,:); yb=y(ib); rfb=fitR2(Xb,yb);
        for j=1:3, bp(b,j)=rfb-fitR2(Xb(:,setdiff(1:3,j)),yb); end
    end
    ci=prctile(bp,[2.5 97.5],1); PrCI(:,o,1)=ci(1,:).'; PrCI(:,o,2)=ci(2,:).';
end
fprintf('\nDEVIATION-FROM-AVERAGE  unique R^2 by window:\n  %-12s %10s %10s\n','factor','RMSE 0-1s','RMSE 1-3s');
for j=1:3, fprintf('  %-12s %10.3f %10.3f\n', pred_names{j}, Pr(j,1),Pr(j,2)); end
fprintf('  %-12s %10.3f %10.3f\n','FULL R2', Rfull);
fprintf('(compare PRIMARY RMSE-to-ref: init 0.381/0.030, motion 0.001/0.005, 2-4Hz 0.083/0.111; full 0.41/0.14)\n');

%% ── Panel (same style as f4_1C_uniqueR2) ────────────────────────────────────
lighten=@(c) c+(1-c)*0.55;
fig=paperFig(5,4.2); ax=axes(fig); hold(ax,'on');
bw=0.34; xoff=0.19; ymax=max(PrCI(:))*1.14;
for g=1:3
    ce=lighten(col(g,:)); cl=col(g,:);
    rectangle(ax,'Position',[g-xoff-bw/2,0,bw,max(Pr(g,1),1e-4)],'FaceColor',ce,'EdgeColor','none');
    rectangle(ax,'Position',[g+xoff-bw/2,0,bw,max(Pr(g,2),1e-4)],'FaceColor',cl,'EdgeColor','none');
    errorbar(ax,g-xoff,Pr(g,1),Pr(g,1)-PrCI(g,1,1),PrCI(g,1,2)-Pr(g,1),'k','LineStyle','none','LineWidth',0.6,'CapSize',2.5);
    errorbar(ax,g+xoff,Pr(g,2),Pr(g,2)-PrCI(g,2,1),PrCI(g,2,2)-Pr(g,2),'k','LineStyle','none','LineWidth',0.6,'CapSize',2.5);
    text(ax,g,-0.045*ymax,staten{g},'Color',col(g,:),'FontSize',PS.fs,'FontWeight','bold','HorizontalAlignment','center','VerticalAlignment','top');
end
xlim(ax,[0.45 3.55]); ylim(ax,[0 ymax]);
set(ax,'XTick',[],'Box','off','TickDir','out','FontSize',PS.fs,'FontWeight','bold');
ylabel(ax,'R^2 explained','FontSize',PS.fs,'FontWeight','bold');
xL=0.60; yT=ymax*0.99; sw=0.15; sh=ymax*0.05;
rectangle(ax,'Position',[xL yT-sh sw sh],'FaceColor',[0.72 0.72 0.72],'EdgeColor','none');
text(ax,xL+sw+0.06,yT-sh/2,'0-1 s','FontSize',4.5,'FontWeight','bold','Color',[0.35 0.35 0.35],'VerticalAlignment','middle');
rectangle(ax,'Position',[xL yT-2.5*sh sw sh],'FaceColor',[0.35 0.35 0.35],'EdgeColor','none');
text(ax,xL+sw+0.06,yT-2.0*sh,'1-3 s','FontSize',4.5,'FontWeight','bold','Color',[0.35 0.35 0.35],'VerticalAlignment','middle');
text(ax,3.5,yT,sprintf('R^2_{full} %.2f / %.2f',Rfull(1),Rfull(2)),'FontSize',4.5,'FontWeight','bold','Color',[0.55 0.55 0.55],'HorizontalAlignment','right','VerticalAlignment','top');
title(ax,'departure from avg trial','FontSize',PS.fs,'FontWeight','bold');
hold(ax,'off');
try, paperExport(fig, fullfile(outdir,'f4_1S_devmodel.pdf')); catch ME, warning('[F4DEV] skip (%s)',ME.message); end
fprintf('\n[F4DEV] exported f4_1S_devmodel.pdf\n');
