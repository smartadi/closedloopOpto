% controller-analysis/cl_factor_slope_panels.m
% Figure-4 canonical factor panels: PER-SESSION PAIRED OL->CL SLOPE plots.
%
% Why this panel type (supersedes the pooled quartile bars for the headline):
%   the OL-vs-CL claim rests on a per-session-slope signed-rank test (unit =
%   session). Pooled quartile bars average across sessions with different
%   baselines, so between-session structure makes the 1-2 Hz NULL panel rise
%   about as much as the 2-4 Hz panel even though the session-level stats
%   separate them cleanly. This panel plots the exact quantity the test uses --
%   each session's slope of (within-session z-scored) RMSE on the factor, OL and
%   CL joined by a line -- so the picture matches the statistic. A dropping line
%   = feedback flattens that factor's effect (decoupling); a flat pair = no
%   decoupling; a rising line = CL steeper.
%
% Four factors. Motion/delta are OL-vs-CL DECOUPLING panels; init-dev is an
% EARLY-vs-LATE window panel (its claim is "transient only", not a loop contrast).
% Windows/measures identical to the source scripts so the numbers reproduce:
%   initdev   |dF/F(onset)-ref|  EARLY 0-1 s vs LATE 1-3 s (within CL)
%             [claim: affects the transient phase only, decays in the settled window]
%             (OL-vs-CL full-window slopes still printed as a methods positive control)
%   motion    mean z-motion onset->end  FULL 0-3 s  [manuscript decoupling, **]
%   delta24   rel 2-4 Hz (band/total)   LATE 1-3 s  [the hard-to-control band, *]
%   delta12   rel 1-2 Hz (band/total)   LATE 1-3 s  [NULL specificity control]
%
% Stat printed/annotated = signed-rank on (slopeOL, slopeCL) across sessions
% (the OL-vs-CL interaction), identical to cl_factor_olcl_panels /
% cl_factor_claim_panels.
%
% Requires: load_sessions.m has run (mouse, fields in workspace).
clc; close all;
PS = paperStyle(); setPaperDefaults();
if exist(fullfile('paper','images'),'dir'); paper_root='paper';
elseif exist(fullfile('..','paper','images'),'dir'); paper_root=fullfile('..','paper');
else; paper_root='paper'; warning('cannot locate paper/ -- exporting locally.'); end
outdir = fullfile(paper_root,'images','figure4');

Fs=35; c0=36; c0_l=106; nSess=numel(fields);
earlyEnd = c0+round(1*Fs);
earlyC = c0 : earlyEnd;                          % transient 0-1 s
lateC  = c0+round(1*Fs)+1 : c0+round(3*Fs);      % settled 1-3 s
sa=c0_l-round(2*Fs); sb=c0_l+round(3*Fs);        % -2 s -> stim end
bp = @(seg,lo,hi) local_bp(seg,Fs,lo,hi);
slp= @(x,y) local_slp(x,y);
zpool = @(a,b) deal((a-mean([a;b]))/std([a;b]), (b-mean([a;b]))/std([a;b]));

% per-session slope accumulators for each factor
S.initdev_wl = nan(nSess,2);   % [EARLY LATE] within CL  (the panel)
S.initdev_lp = nan(nSess,2);   % [OL CL] full window      (methods positive control)
S.motion     = nan(nSess,2);   % [OL CL]
S.delta24    = nan(nSess,2);   % [OL CL]
S.delta12    = nan(nSess,2);   % [OL CL]

for k=1:nSess
    s=mouse.(fields{k});
    if isfield(s,'skip')&&s.skip; continue; end
    if ~isfield(s,'data'); continue; end
    dk=s.data; ref=s.d.ref;

    % ---- full-window RMSE (0-3 s), used by init-dev & motion (matches manuscript) ----
    yFo=dk.er_ncDfk(:); yFc=dk.er_wcDfk(:);

    % ---- early / late window RMSE ----
    yEc=sqrt(mean((dk.wcDfk(:,earlyC)-ref).^2,2));   % CL transient 0-1 s
    yLo=sqrt(mean((dk.ncDfk(:,lateC)-ref).^2,2));    % OL settled 1-3 s
    yLc=sqrt(mean((dk.wcDfk(:,lateC)-ref).^2,2));    % CL settled 1-3 s

    % ===== init-dev =====
    xo=abs(dk.ncDfk(:,c0)-ref); xc=abs(dk.wcDfk(:,c0)-ref);
    % (a) EARLY-vs-LATE within CL -- the "transient only" claim (the panel)
    if numel(xc)>=10
        gz=isfinite(xc)&isfinite(yEc)&isfinite(yLc); xcg=xc(gz);
        zE=(yEc(gz)-mean(yEc(gz)))/std(yEc(gz)); zL=(yLc(gz)-mean(yLc(gz)))/std(yLc(gz));
        S.initdev_wl(k,:)=[slp(xcg,zE) slp(xcg,zL)];
    end
    % (b) OL-vs-CL full window -- positive control (printed, not plotted)
    S.initdev_lp(k,:)=pair_slope(xo,xc,yFo,yFc,zpool,slp);

    % ===== motion (full window) -- motion sessions only =====
    if s.has_motion && isfield(dk,'wcmotion') && isfield(dk,'ncmotion')
        dur=s.d.params.dur;
        [xo,xc]=motion_meas(dk,dur,Fs);
        S.motion(k,:)=pair_slope(xo,xc,yFo,yFc,zpool,slp);
    end

    % ===== delta relative sub-bands (late window) =====
    nc=dk.pncDfk_l; wc=dk.pwcDfk_l;
    x24o=arrayfun(@(t) bp(nc(t,sa:sb),2,4)/max(bp(nc(t,sa:sb),0.4,10),eps),(1:size(nc,1))');
    x24c=arrayfun(@(t) bp(wc(t,sa:sb),2,4)/max(bp(wc(t,sa:sb),0.4,10),eps),(1:size(wc,1))');
    x12o=arrayfun(@(t) bp(nc(t,sa:sb),1,2)/max(bp(nc(t,sa:sb),0.4,10),eps),(1:size(nc,1))');
    x12c=arrayfun(@(t) bp(wc(t,sa:sb),1,2)/max(bp(wc(t,sa:sb),0.4,10),eps),(1:size(wc,1))');
    S.delta24(k,:)=pair_slope(x24o,x24c,yLo,yLc,zpool,slp);
    S.delta12(k,:)=pair_slope(x12o,x12c,yLo,yLc,zpool,slp);
end

% ---- panels ----
clear P                                       % avoid dissimilar-struct clash with a stale P
gE=[0.45 0.75 0.50]; gL=[0.10 0.45 0.20];   % early(light)/late(dark) green for init-dev
P(1)=struct('key','initdev','data',S.initdev_wl,'xl','Initial deviation','lab',{{'Early','Late'}},'cA',gE,'cB',gL,'ttl','transient only');
P(2)=struct('key','motion', 'data',S.motion, 'xl','Motion',         'lab',{{'OL','CL'}},'cA',PS.col_ol,'cB',PS.col_cl,'ttl','decoupling');
P(3)=struct('key','delta24','data',S.delta24,'xl','Relative 2-4 Hz','lab',{{'OL','CL'}},'cA',PS.col_ol,'cB',PS.col_cl,'ttl','hard-to-control band');
P(4)=struct('key','delta12','data',S.delta12,'xl','Relative 1-2 Hz','lab',{{'OL','CL'}},'cA',PS.col_ol,'cB',PS.col_cl,'ttl','null control');

fprintf('\n=== per-session paired slope (z-RMSE vs factor) ===\n');
for i=1:numel(P)
    D=P(i).data; v=isfinite(D(:,1))&isfinite(D(:,2));
    sA=D(v,1); sB=D(v,2); p=signrank(sA,sB);
    fprintf('%-8s n=%2d | %-5s %+.3f  %-5s %+.3f | %s-vs-%s p=%.4g -> %s   (%s)\n', ...
        P(i).key,sum(v),P(i).lab{1},median(sA),P(i).lab{2},median(sB), ...
        P(i).lab{1},P(i).lab{2},p,sig_star(p),P(i).ttl);
    mk_slope(sA,sB,outdir,['factor_slope_' P(i).key],sig_star(p),P(i).xl,PS,i==2,P(i).lab,P(i).cA,P(i).cB);
end

% init-dev extras: each window vs 0 (early significant, late collapses) + OL/CL positive control
vw=isfinite(S.initdev_wl(:,1))&isfinite(S.initdev_wl(:,2));
fprintf('  init-dev EARLY vs 0: %+.3f p=%.4g | LATE vs 0: %+.3f p=%.4g  (~%.0fx collapse)\n', ...
    median(S.initdev_wl(vw,1)),signrank(S.initdev_wl(vw,1)), ...
    median(S.initdev_wl(vw,2)),signrank(S.initdev_wl(vw,2)), ...
    abs(median(S.initdev_wl(vw,1))/median(S.initdev_wl(vw,2))));
vp=isfinite(S.initdev_lp(:,1))&isfinite(S.initdev_lp(:,2));
fprintf('  init-dev positive control (OL-vs-CL full window): OL %+.3f CL %+.3f p=%.4g -> %s\n', ...
    median(S.initdev_lp(vp,1)),median(S.initdev_lp(vp,2)),signrank(S.initdev_lp(vp,1),S.initdev_lp(vp,2)), ...
    sig_star(signrank(S.initdev_lp(vp,1),S.initdev_lp(vp,2))));
fprintf('\n[cl_factor_slope_panels] exported factor_slope_{initdev,motion,delta24,delta12} (.png/.pdf)\n');

%% ---- helpers ----
function ab=pair_slope(xo,xc,yo,yc,zpool,slp)
    m1=min(numel(xo),numel(yo)); m2=min(numel(xc),numel(yc));
    xo=xo(1:m1); yo=yo(1:m1); xc=xc(1:m2); yc=yc(1:m2);
    g1=isfinite(xo)&isfinite(yo); g2=isfinite(xc)&isfinite(yc);
    xo=xo(g1); yo=yo(g1); xc=xc(g2); yc=yc(g2);
    if numel(yo)<10||numel(yc)<10; ab=[NaN NaN]; return; end
    [zo,zc]=zpool(yo,yc);
    ab=[slp(xo,zo) slp(xc,zc)];
end
function [xnc,xcl]=motion_meas(dk,dur,Fs)
    nc=dk.ncmotion; wc=dk.wcmotion; ncol=size(nc,2);
    onset=ncol-Fs*dur; ws=max(1,onset); we=min(ncol,onset+dur*Fs);
    xnc=mean(nc(:,ws:we),2); xcl=mean(wc(:,ws:we),2);
end
function mk_slope(sA,sB,outdir,base,star,xl,~,legend_on,lab,cA,cB)
    dnA=legend_name(lab{1}); dnB=legend_name(lab{2});  % OL/CL -> full words for the legend
    n=numel(sA); x1=1; x2=2;
    fig=paperFig(6,4); ax=gca; hold(ax,'on');
    yline(ax,0,'-','Color',[0.6 0.6 0.6],'LineWidth',0.5,'HandleVisibility','off');
    for i=1:n
        plot(ax,[x1 x2],[sA(i) sB(i)],'-','Color',[0.75 0.75 0.75],'LineWidth',0.4,'HandleVisibility','off');
    end
    hA=plot(ax,x1*ones(n,1),sA,'o','MarkerSize',3,'MarkerFaceColor',cA,'MarkerEdgeColor','none','DisplayName',dnA);
    hB=plot(ax,x2*ones(n,1),sB,'o','MarkerSize',3,'MarkerFaceColor',cB,'MarkerEdgeColor','none','DisplayName',dnB);
    % mean +- SEM (bold) just outside the cloud
    errorbar(ax,x1-0.22,mean(sA),std(sA)/sqrt(n),'o','Color','k','MarkerFaceColor',cA, ...
        'MarkerEdgeColor','k','MarkerSize',4,'LineWidth',0.8,'CapSize',3,'HandleVisibility','off');
    errorbar(ax,x2+0.22,mean(sB),std(sB)/sqrt(n),'o','Color','k','MarkerFaceColor',cB, ...
        'MarkerEdgeColor','k','MarkerSize',4,'LineWidth',0.8,'CapSize',3,'HandleVisibility','off');
    set(ax,'XTick',[x1 x2],'XTickLabel',lab,'Box','off','TickDir','out', ...
        'FontSize',6,'FontWeight','bold'); xlim(ax,[0.5 2.5]);
    ylabel(ax,'Slope: z-RMSE vs factor','FontSize',6,'FontWeight','bold');
    xlabel(ax,xl,'FontSize',6,'FontWeight','bold');
    yl=ylim(ax); text(ax,1.5,yl(2),star,'HorizontalAlignment','center','VerticalAlignment','top', ...
        'FontSize',8,'FontWeight','bold'); ylim(ax,[yl(1) yl(2)+0.12*range(yl)]);
    if legend_on; lg=legend(ax,[hA hB],'Location','northoutside','Orientation','horizontal'); paperLegend(lg); end
    paperExport(fig,fullfile(outdir,[base '.png'])); paperExport(fig,fullfile(outdir,[base '.pdf'])); close(fig);
end
function b=local_slp(x,y); x=x(:);y=y(:);g=isfinite(x)&isfinite(y); B=polyfit(x(g),y(g),1); b=B(1); end
function s=legend_name(t)
    switch t; case 'OL'; s='Open loop'; case 'CL'; s='Closed loop'; otherwise; s=t; end
end
function s=sig_star(p)
    if p<1e-3;s='***';elseif p<1e-2;s='**';elseif p<0.05;s='*';else;s='n.s.';end
end
function p=local_bp(seg,Fs,lo,hi)
    seg=detrend(double(seg(:)).','linear'); N=numel(seg);
    w=hann(N).'; P=abs(fft(seg.*w)).^2; P=P(1:floor(N/2)+1);
    fr=(0:floor(N/2))*Fs/N; p=sum(P(fr>=lo & fr<hi));
end
