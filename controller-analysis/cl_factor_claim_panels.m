% controller-analysis/cl_factor_claim_panels.m
% Claim-specific Fig-4 companion panels. Leaves cl_factor_olcl_panels.m untouched.
%
% Claim 2 -- "delta waves are harder to control":
%   naive absolute delta is the signal-power confound; the DEFENSIBLE test is the
%   POWER-INDEPENDENT relative delta (band 1-4 Hz / total 0.4-10 Hz) in the LATE
%   (settled, 1-3 s) window. Panel: relative-delta quartiles vs late RMSE, OL vs CL.
%
% Claim 3 -- "initial deviation doesn't affect control":
%   full-window coupling is circular (onset sample sits inside the RMSE window).
%   The honest test is the window contrast: init-dev drives the EARLY transient
%   but not the settled LATE window. Panel: init-dev quartiles, CL RMSE, early vs late.
%
% Both: per-session slope of z-scored RMSE on the factor, Wilcoxon signed-rank
% (unit = session), quartile bars raw + z, title-less png + pdf.
%
% Requires: load_sessions.m has run (mouse, fields in workspace).
clc; close all;
PS = paperStyle(); setPaperDefaults();

if exist(fullfile('paper','images'),'dir'); paper_root='paper';
elseif exist(fullfile('..','paper','images'),'dir'); paper_root=fullfile('..','paper');
else; paper_root='paper'; warning('cannot locate paper/ -- exporting locally.'); end
outdir = fullfile(paper_root,'images','figure4');

Fs=35; c0=36; c0_l=106; nBins=4;
earlyC = c0 : c0+round(1*Fs);                 % 0 -> 1 s
lateC  = c0+round(1*Fs)+1 : c0+round(3*Fs);   % 1 -> 3 s
sa=c0_l-round(2*Fs); sb=c0_l+round(3*Fs);     % -2 -> stim end
bp=@(seg,lo,hi) local_bp(seg,Fs,lo,hi);
zwin=@(y1,y2) deal((y1-mean([y1;y2]))/std([y1;y2]), (y2-mean([y1;y2]))/std([y1;y2]));
slp=@(x,y) local_slp(x,y);

% accumulators
c2.rmO=cell(1,nBins); c2.rmC=cell(1,nBins); c2.zmO=cell(1,nBins); c2.zmC=cell(1,nBins);
c2.sOL=[]; c2.sCL=[];
c3.reE=cell(1,nBins); c3.reL=cell(1,nBins); c3.zeE=cell(1,nBins); c3.zeL=cell(1,nBins);
c3.sE=[]; c3.sL=[];

for k=1:numel(fields)
    s=mouse.(fields{k}); if isfield(s,'skip')&&s.skip;continue;end; if ~isfield(s,'data');continue;end
    dk=s.data; ref=s.d.ref;
    nc=dk.pncDfk_l; wc=dk.pwcDfk_l;

    % --- outcomes (RMSE, per window) ---
    rEo=sqrt(mean((dk.ncDfk(:,earlyC)-ref).^2,2)); rLo=sqrt(mean((dk.ncDfk(:,lateC)-ref).^2,2));
    rEc=sqrt(mean((dk.wcDfk(:,earlyC)-ref).^2,2)); rLc=sqrt(mean((dk.wcDfk(:,lateC)-ref).^2,2));

    % --- Claim 2 factor: relative delta ---
    rdO=arrayfun(@(t) bp(nc(t,sa:sb),1,4)/max(bp(nc(t,sa:sb),0.4,10),eps),(1:size(nc,1))');
    rdC=arrayfun(@(t) bp(wc(t,sa:sb),1,4)/max(bp(wc(t,sa:sb),0.4,10),eps),(1:size(wc,1))');
    % z-score LATE rmse within session (pooled OL+CL)
    [zLo,zLc]=zwin(rLo,rLc);
    c2.sOL(end+1)=slp(rdO,zLo); c2.sCL(end+1)=slp(rdC,zLc);
    edg=quantile([rdO;rdC],linspace(0,1,nBins+1)); edg(1)=-inf; edg(end)=inf;
    bO=discretize(rdO,edg); bC=discretize(rdC,edg);
    for b=1:nBins
        c2.rmO{b}=[c2.rmO{b}; rLo(bO==b)]; c2.rmC{b}=[c2.rmC{b}; rLc(bC==b)];
        c2.zmO{b}=[c2.zmO{b}; zLo(bO==b)]; c2.zmC{b}=[c2.zmC{b}; zLc(bC==b)];
    end

    % --- Claim 3 factor: initial deviation (CL) ---
    idC=abs(dk.wcDfk(:,c0)-ref);
    % z-score each CL window by its own CL distribution
    zEc=(rEc-mean(rEc))/std(rEc); zLcc=(rLc-mean(rLc))/std(rLc);
    c3.sE(end+1)=slp(idC,zEc); c3.sL(end+1)=slp(idC,zLcc);
    edg3=quantile(idC,linspace(0,1,nBins+1)); edg3(1)=-inf; edg3(end)=inf;
    b3=discretize(idC,edg3);
    for b=1:nBins
        c3.reE{b}=[c3.reE{b}; rEc(b3==b)]; c3.reL{b}=[c3.reL{b}; rLc(b3==b)];
        c3.zeE{b}=[c3.zeE{b}; zEc(b3==b)]; c3.zeL{b}=[c3.zeL{b}; zLcc(b3==b)];
    end
end

% ---- stats ----
p2_cl0 = signrank(c2.sCL);  p2_int = signrank(c2.sOL, c2.sCL);
p3_e0  = signrank(c3.sE);   p3_l0  = signrank(c3.sL);
fprintf('\nCLAIM 2 (relative delta, LATE window): CL slope %+.3f (vs0 p=%.4g) | OL %+.3f | interaction p=%.4g\n', ...
    median(c2.sCL),p2_cl0,median(c2.sOL),p2_int);
fprintf('CLAIM 3 (init-dev, CL): EARLY slope %+.3f (p=%.4g) | LATE slope %+.3f (p=%.4g)\n', ...
    median(c3.sE),p3_e0,median(c3.sL),p3_l0);

%% ---- Claim 2 panel: OL vs CL, relative-delta quartiles, LATE RMSE ----
for mi=1:2
    if mi==1; bO=c2.rmO; bC=c2.rmC; ylab='RMSE 1-3 s (%\DeltaF/F)'; suf='';
    else;     bO=c2.zmO; bC=c2.zmC; ylab='RMSE 1-3 s (z)';         suf='_z'; end
    mO=cellfun(@mean,bO); eO=cellfun(@(x)std(x)/sqrt(max(numel(x),1)),bO);
    mC=cellfun(@mean,bC); eC=cellfun(@(x)std(x)/sqrt(max(numel(x),1)),bC);
    fig=paperFig(6,4); ax=gca; hold(ax,'on'); xq=1:nBins; w=0.35;
    bar(ax,xq-w/2,mO,w,'FaceColor',PS.col_ol,'EdgeColor','none','DisplayName','Open loop');
    bar(ax,xq+w/2,mC,w,'FaceColor',PS.col_cl,'EdgeColor','none','DisplayName','Closed loop');
    errorbar(ax,xq-w/2,mO,eO,'k','LineStyle','none','LineWidth',0.6,'CapSize',2,'HandleVisibility','off');
    errorbar(ax,xq+w/2,mC,eC,'k','LineStyle','none','LineWidth',0.6,'CapSize',2,'HandleVisibility','off');
    set(ax,'XTick',1:nBins,'XTickLabel',{'Q1','Q2','Q3','Q4'},'Box','off','TickDir','out','FontSize',6,'FontWeight','bold');
    xlabel(ax,'Relative delta quartile (low \rightarrow high)','FontSize',6,'FontWeight','bold');
    ylabel(ax,ylab,'FontSize',6,'FontWeight','bold');
    yl=ylim(ax); text(ax,mean([1 nBins]),yl(2),sig_star(p2_int),'HorizontalAlignment','center', ...
        'VerticalAlignment','top','FontSize',8,'FontWeight','bold'); ylim(ax,[yl(1) yl(2)+0.10*range(yl)]);
    lg=legend(ax,'Location','northwest'); paperLegend(lg);
    paperExport(fig,fullfile(outdir,['claim2_delta_rel_late' suf '.png']));
    paperExport(fig,fullfile(outdir,['claim2_delta_rel_late' suf '.pdf'])); close(fig);
end

%% ---- Claim 3 panel: CL, init-dev quartiles, EARLY vs LATE RMSE ----
col_e=[0.45 0.75 0.50]; col_l=[0.10 0.45 0.20];
for mi=1:2
    if mi==1; bE=c3.reE; bL=c3.reL; ylab='RMSE (%\DeltaF/F)'; suf='';
    else;     bE=c3.zeE; bL=c3.zeL; ylab='RMSE (z)';         suf='_z'; end
    mE=cellfun(@mean,bE); eE=cellfun(@(x)std(x)/sqrt(max(numel(x),1)),bE);
    mL=cellfun(@mean,bL); eL=cellfun(@(x)std(x)/sqrt(max(numel(x),1)),bL);
    fig=paperFig(6,4); ax=gca; hold(ax,'on'); xq=1:nBins; w=0.35;
    bar(ax,xq-w/2,mE,w,'FaceColor',col_e,'EdgeColor','none','DisplayName','0-1 s (transient)');
    bar(ax,xq+w/2,mL,w,'FaceColor',col_l,'EdgeColor','none','DisplayName','1-3 s (settled)');
    errorbar(ax,xq-w/2,mE,eE,'k','LineStyle','none','LineWidth',0.6,'CapSize',2,'HandleVisibility','off');
    errorbar(ax,xq+w/2,mL,eL,'k','LineStyle','none','LineWidth',0.6,'CapSize',2,'HandleVisibility','off');
    set(ax,'XTick',1:nBins,'XTickLabel',{'Q1','Q2','Q3','Q4'},'Box','off','TickDir','out','FontSize',6,'FontWeight','bold');
    xlabel(ax,'Initial deviation quartile (low \rightarrow high)','FontSize',6,'FontWeight','bold');
    ylabel(ax,ylab,'FontSize',6,'FontWeight','bold');
    lg=legend(ax,'Location','northwest'); paperLegend(lg);
    paperExport(fig,fullfile(outdir,['claim3_initdev_early_late' suf '.png']));
    paperExport(fig,fullfile(outdir,['claim3_initdev_early_late' suf '.pdf'])); close(fig);
end
fprintf('\n[cl_factor_claim_panels] exported claim2_delta_rel_late(.png/.pdf,_z) + claim3_initdev_early_late(.png/.pdf,_z)\n');

%% ---- helpers ----
function s=sig_star(p)
    if p<1e-3; s='***'; elseif p<1e-2; s='**'; elseif p<0.05; s='*'; else; s='n.s.'; end
end
function b=local_slp(x,y); x=x(:);y=y(:);g=isfinite(x)&isfinite(y); B=polyfit(x(g),y(g),1); b=B(1); end
function p=local_bp(seg,Fs,lo,hi)
    seg=detrend(double(seg(:)).','linear'); N=numel(seg);
    w=hann(N).'; P=abs(fft(seg.*w)).^2; P=P(1:floor(N/2)+1);
    fr=(0:floor(N/2))*Fs/N; p=sum(P(fr>=lo & fr<hi));
end
