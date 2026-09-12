% controller-analysis/f4_row2_quartiles.m
% ============================================================================
% FIGURE 4 -- ROW 2 PAPER PANELS  [F4R2]
% "The closed-loop rejection benefit is state-dependent."
%
% For each brain-state, bin trials into quartiles (Q1..Q4 on the combined OL+CL
% state distribution, within session) and show OL vs CL disturbance-rejection
% RMSE per quartile. The CLAIM is NOT "CL < OL" (that is Figure 3) -- it is how
% the OL-CL GAP (the rejection benefit) CHANGES from Q1 to Q4.
%
% STATES -- defined IDENTICALLY to row 1 (f4_partB_panels / cl_rmse_factor_windows),
% on the OL (nc) and CL (wc) buffers:
%   initdev = |dFk(onset) - ref|
%   motion  = mean rectified movement mean(max(mot,0)) over -2 s -> stim end (has_motion only)
%   delta   = cl_reldelta rel 2-4 Hz over -2 s -> stim end
% Outcome = disturbance-rejection RMSE to ref over [+1,+3] s (settled window),
% z-scored within session across the combined OL+CL trials (removes session
% baseline, keeps the OL-vs-CL level difference).
%
% TEST (the star): per session compute gap = mean(zRMSE_OL) - mean(zRMSE_CL) in
% Q1 and in Q4; paired Wilcoxon signed-rank of gap(Q4) vs gap(Q1) across sessions.
% A shrinking gap at high state = feedback helps less there (the irreducible
% disturbance); a stable gap = state-independent rejection.
%
% OUTPUT: three vector PDFs (paper/images/figure4/): f4_2A_initdev.pdf,
%         f4_2B_motion.pdf, f4_2C_delta.pdf.   Requires load_sessions.m first.
% ============================================================================
clc; close all;
PS = paperStyle(); setPaperDefaults();
assert(exist('mouse','var') && exist('fields','var'), '[F4R2] run load_sessions.m first.');

if exist(fullfile('paper','images'),'dir');            paper_root = 'paper';
elseif exist(fullfile('..','paper','images'),'dir');   paper_root = fullfile('..','paper');
else;  paper_root = 'paper'; warning('[F4R2] cannot locate paper/.'); end
outdir = fullfile(paper_root,'images','figure4');
if ~exist(outdir,'dir'); mkdir(outdir); end

Fs=35; ref=-5; c0=36; c1=71; c2=141; dur=3; c0_mot=71; c0_l=106;
relopts = struct('pre',2,'post',3);            % delta window -2 -> stim end (matches row 1)
colOL = PS.col_ol; colCL = PS.col_cl;
preds = {'initdev','motion','delta'};
titR2 = {'Initial deviation','Motion','Rel 2-4 Hz'};
fnout = {'f4_2A_initdev.pdf','f4_2B_motion.pdf','f4_2C_delta.pdf'};

% ---- per-session z-scored state + z-scored RMSE, per condition -------------------------------
Pl = struct();
for pn=preds; Pl.(pn{1})=struct('zx',[],'zy',[],'g',[],'gap1',[],'gap4',[]); end
for k=1:numel(fields)
    M=mouse.(fields{k}); if ~isfield(M,'data'); continue; end; d=M.data;
    if ~isfield(d,'ncDfk')||isempty(d.ncDfk)||~isfield(d,'wcDfk')||isempty(d.wcDfk); continue; end
    nO=size(d.ncDfk,1); nC=size(d.wcDfk,1);
    yOL=sqrt(mean((d.ncDfk(:,c1:c2)-ref).^2,2));
    yCL=sqrt(mean((d.wcDfk(:,c1:c2)-ref).^2,2));

    S=struct();
    S.initdev={abs(d.ncDfk(:,c0)-ref), abs(d.wcDfk(:,c0)-ref)};
    hasM = isfield(M,'has_motion')&&M.has_motion&&isfield(d,'ncmotion')&&any(d.ncmotion(:))&&isfield(d,'wcmotion');
    if hasM
        wsO=max(1,c0_mot-round(2*Fs)); weO=min(size(d.ncmotion,2),c0_mot+round(dur*Fs)-1);
        wsC=max(1,c0_mot-round(2*Fs)); weC=min(size(d.wcmotion,2),c0_mot+round(dur*Fs)-1);
        S.motion={mean(max(d.ncmotion(:,wsO:weO),0),2), mean(max(d.wcmotion(:,wsC:weC),0),2)};
    else, S.motion={nan(nO,1),nan(nC,1)}; end
    if isfield(d,'pncDfk_l')&&~isempty(d.pncDfk_l)&&isfield(d,'pwcDfk_l')&&~isempty(d.pwcDfk_l)
        S.delta={cl_reldelta(d.pncDfk_l,c0_l,Fs,relopts), cl_reldelta(d.pwcDfk_l,c0_l,Fs,relopts)};
    else, S.delta={nan(nO,1),nan(nC,1)}; end

    muY=mean([yOL;yCL],'omitnan'); sgY=std([yOL;yCL],'omitnan'); if sgY==0||isnan(sgY); continue; end
    zyOL=(yOL-muY)/sgY; zyCL=(yCL-muY)/sgY;

    for pn=preds; nm=pn{1};
        xOL=S.(nm){1}; xCL=S.(nm){2};
        if all(isnan(xOL))||all(isnan(xCL)); continue; end
        muX=mean([xOL;xCL],'omitnan'); sgX=std([xOL;xCL],'omitnan'); if sgX==0||isnan(sgX); continue; end
        zxOL=(xOL-muX)/sgX; zxCL=(xCL-muX)/sgX;
        oOK=isfinite(zxOL)&isfinite(zyOL); cOK=isfinite(zxCL)&isfinite(zyCL);
        if nnz(oOK)<8||nnz(cOK)<8; continue; end
        Pl.(nm).zx=[Pl.(nm).zx; zxOL(oOK); zxCL(cOK)];
        Pl.(nm).zy=[Pl.(nm).zy; zyOL(oOK); zyCL(cOK)];
        Pl.(nm).g =[Pl.(nm).g;  zeros(nnz(oOK),1); ones(nnz(cOK),1)];
        % per-session gap in Q1 and Q4 (quartile on this session's combined state)
        eS=quantile([zxOL(oOK);zxCL(cOK)],[0 .25 .5 .75 1]); eS=uniqedges(eS);
        if numel(eS)<5; continue; end
        qO=discretize(zxOL,eS); qC=discretize(zxCL,eS);
        g1=mean(zyOL(qO==1),'omitnan')-mean(zyCL(qC==1),'omitnan');
        g4=mean(zyOL(qO==4),'omitnan')-mean(zyCL(qC==4),'omitnan');
        if isfinite(g1)&&isfinite(g4); Pl.(nm).gap1(end+1)=g1; Pl.(nm).gap4(end+1)=g4; end
    end
end

% ---- stats + per-state figure ---------------------------------------------------------------
fprintf('\n============ ROW 2: OL-CL rejection GAP by state quartile (TRIAL-LEVEL) ============\n');
fprintf('state     nTrials nSess | dGap(Q4-Q1)  interaction beta   t      p\n');
for ip=1:numel(preds); nm=preds{ip};
    zx=Pl.(nm).zx; zy=Pl.(nm).zy; g=Pl.(nm).g;
    if isempty(zx); fprintf('%-9s (no data)\n',nm); continue; end
    edg=quantile(zx,[0 .25 .5 .75 1]); edg=uniqedges(edg);
    qb=discretize(zx,edg); qb(isnan(qb))=4;
    qmO=arrayfun(@(b) mean(zy(qb==b&g==0),'omitnan'),1:4);
    qmC=arrayfun(@(b) mean(zy(qb==b&g==1),'omitnan'),1:4);
    qsO=arrayfun(@(b) std(zy(qb==b&g==0),'omitnan')/sqrt(max(1,nnz(qb==b&g==0))),1:4);
    qsC=arrayfun(@(b) std(zy(qb==b&g==1),'omitnan')/sqrt(max(1,nnz(qb==b&g==1))),1:4);
    % TRIAL-LEVEL interaction (pooled, no session structure): does the OL-CL gap
    % depend on state?  zRMSE ~ 1 + cond + state + cond:state ; test cond:state.
    G=g; nTr=numel(zy); nG=numel(Pl.(nm).gap1);
    Xd=[ones(nTr,1), G, zx, G.*zx]; bd=Xd\zy;
    resid=zy-Xd*bd; dof=max(nTr-4,1); s2=sum(resid.^2)/dof;
    covb=s2*inv(Xd'*Xd); se=sqrt(diag(covb)); tI=bd(4)/se(4);
    pGap=2*tcdf(-abs(tI),dof); bInt=bd(4);
    dGap=(qmO(4)-qmC(4))-(qmO(1)-qmC(1));           % descriptive Q4-Q1 gap change (pooled)
    fprintf('%-9s  %6d  %3d | %+.2f        %+.3f          %+.2f  %8.3g\n', nm,nTr,nG,dGap,bInt,tI,pGap);

    % ---- panel ----
    fq=paperFig(5,4.6); ax=axes(fq); hold(ax,'on');
    yline(ax,0,'-','Color',[0.6 0.6 0.6],'LineWidth',0.5);
    xq=1:4; w=0.36;
    bar(ax,xq-w/2,qmO,w,'FaceColor',colOL,'EdgeColor','none');
    bar(ax,xq+w/2,qmC,w,'FaceColor',colCL,'EdgeColor','none');
    errorbar(ax,xq-w/2,qmO,qsO,'k','LineStyle','none','LineWidth',0.5,'CapSize',2);
    errorbar(ax,xq+w/2,qmC,qsC,'k','LineStyle','none','LineWidth',0.5,'CapSize',2);
    % gap trend line (OL-CL per quartile) - the tested quantity
    gapq=qmO-qmC;
    plot(ax,xq,gapq,'-o','Color',[0.15 0.15 0.15],'MarkerFaceColor',[0.15 0.15 0.15], ...
        'MarkerSize',2.5,'LineWidth',0.9);
    set(ax,'XTick',1:4,'XTickLabel',{'Q1','Q2','Q3','Q4'},'Box','off','TickDir','out', ...
        'FontSize',PS.fs,'FontWeight','bold');
    ylim(ax,[-0.65 1.40]); yl=ylim(ax);   % common range across the 3 panels (gap trends comparable)
    % gap-change star (Q1 vs Q4 gap), placed over the gap line span
    text(ax,2.5,yl(2)-0.02*range(yl),sprintf('\\Deltagap %s',starstr(pGap)), ...
        'HorizontalAlignment','center','VerticalAlignment','top','FontSize',6,'FontWeight','bold','Color',[0.1 0.1 0.1]);
    title(ax,sprintf('%s  (%d tr)',titR2{ip},nTr),'FontSize',PS.fs,'FontWeight','bold');
    if ip==1
        ylabel(ax,'RMSE to ref (z)','FontSize',PS.fs,'FontWeight','bold');
        % compact legend
        xL=1.05; yTop=yl(2)-0.03*range(yl); dh=0.10*range(yl);
        plot(ax,xL,yTop,'s','MarkerFaceColor',colOL,'MarkerEdgeColor','none','MarkerSize',5);
        text(ax,xL+0.14,yTop,'OL','FontSize',5,'FontWeight','bold','Color',colOL,'VerticalAlignment','middle');
        plot(ax,xL,yTop-dh,'s','MarkerFaceColor',colCL,'MarkerEdgeColor','none','MarkerSize',5);
        text(ax,xL+0.14,yTop-dh,'CL','FontSize',5,'FontWeight','bold','Color',colCL,'VerticalAlignment','middle');
        plot(ax,xL,yTop-2*dh,'o','MarkerFaceColor',[0.15 0.15 0.15],'MarkerEdgeColor','none','MarkerSize',3);
        text(ax,xL+0.14,yTop-2*dh,'gap','FontSize',5,'FontWeight','bold','Color',[0.15 0.15 0.15],'VerticalAlignment','middle');
    end
    hold(ax,'off');
    try, paperExport(fq, fullfile(outdir,fnout{ip})); catch ME, warning('[F4R2] skip %s (%s)',fnout{ip},ME.message); end
end
fprintf('\n[F4R2] row-2 panels -> %s\n', outdir);

function e=uniqedges(e); for i=2:numel(e); if e(i)<=e(i-1); e(i)=e(i-1)+eps(e(i-1))*1e3; end; end; end
function s=starstr(p); if isnan(p), s='n.s.'; elseif p<1e-3, s='***'; elseif p<1e-2, s='**'; elseif p<0.05, s='*'; else, s='n.s.'; end; end
function p=local_signrank(a,b); try, p=signrank(a,b); catch, [~,p]=ttest(a,b); end; end
