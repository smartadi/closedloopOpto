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
% TEST (the star): session-aware linear mixed model on z-scored RMSE, cond x state
% interaction with trials nested in sessions nested in mice
% (zrmse ~ cond*state + (1|mouse) + (1|sess)) -- the panel star is this LMM
% interaction p (Nick 2026-09-11; replaces the old session-level signed-rank, which
% is still printed to the console for reference). The 3-state forest of the same
% model is f4_2S_stats (f4_row2_stats.m). A NEGATIVE cond(CL):state term = the CL
% advantage SHRINKS at high state (gap closes); a flat gap = state-independent rejection.
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

Fs=35; ref=-5; c0=36; c1=71; c2=141; dur=3; c0_mot=71; c0_l=106; c0_p=351;
% c0_p = onset col in pncDfk/pwcDfk (controllerData buffers dFk(i-350:i+..), 350-sample
% pre => onset at col 351). Current caches store pncDfk/pwcDfk, NOT the older _l variants
% (onset col 106); the delta path falls back to these so rel-delta needs no cache rebuild.
relopts = struct('pre',2,'post',3);            % delta window -2 -> stim end (matches row 1)
colOL = PS.col_ol; colCL = PS.col_cl;
preds = {'initdev','motion','delta'};
titR2 = {'Initial deviation','Motion','Rel 2-4 Hz'};
fnout = {'f4_2A_initdev.pdf','f4_2B_motion.pdf','f4_2C_delta.pdf'};

% ---- per-session z-scored state + z-scored RMSE, per condition -------------------------------
Pl = struct();
% zx/zy/g = pooled trial arrays for the panel; gap1/gap4 = per-session Q1/Q4 gaps (primary test).
% l* = per-trial table for the LME supplement (ly outcome, lc cond, lx within-session state z,
% lq within-session quartile, lsess session id, lmouse mouse name).
for pn=preds; Pl.(pn{1})=struct('zx',[],'zy',[],'g',[],'gap1',[],'gap4',[], ...
        'ly',[],'lc',[],'lx',[],'lq',[],'lsess',[],'lmouse',{{}}); end
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
    elseif isfield(d,'pncDfk')&&~isempty(d.pncDfk)&&isfield(d,'pwcDfk')&&~isempty(d.pwcDfk)
        S.delta={cl_reldelta(d.pncDfk,c0_p,Fs,relopts), cl_reldelta(d.pwcDfk,c0_p,Fs,relopts)};
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
        % per-trial LME table (trials in sessions in mice); within-session quartile + state z
        nOk=nnz(oOK); nCk=nnz(cOK);
        Pl.(nm).ly    =[Pl.(nm).ly;    zyOL(oOK); zyCL(cOK)];
        Pl.(nm).lc    =[Pl.(nm).lc;    zeros(nOk,1); ones(nCk,1)];
        Pl.(nm).lx    =[Pl.(nm).lx;    zxOL(oOK); zxCL(cOK)];
        Pl.(nm).lq    =[Pl.(nm).lq;    qO(oOK); qC(cOK)];
        Pl.(nm).lsess =[Pl.(nm).lsess; repmat(k,nOk+nCk,1)];
        Pl.(nm).lmouse=[Pl.(nm).lmouse; repmat({M.mn},nOk+nCk,1)];
    end
end

% ---- stats + per-state figure ---------------------------------------------------------------
fprintf('\n============ ROW 2: OL-CL rejection GAP by state quartile (SESSION-LEVEL primary) ============\n');
fprintf('state     nTrials nSess | session-aware LMM cond:state (PRIMARY star)  || refs: sess signrank / pooled\n');
LME = struct();
for ip=1:numel(preds); nm=preds{ip};
    zx=Pl.(nm).zx; zy=Pl.(nm).zy; g=Pl.(nm).g;
    if isempty(zx); fprintf('%-9s (no data)\n',nm); continue; end
    edg=quantile(zx,[0 .25 .5 .75 1]); edg=uniqedges(edg);
    qb=discretize(zx,edg); qb(isnan(qb))=4;
    qmO=arrayfun(@(b) mean(zy(qb==b&g==0),'omitnan'),1:4);
    qmC=arrayfun(@(b) mean(zy(qb==b&g==1),'omitnan'),1:4);
    qsO=arrayfun(@(b) std(zy(qb==b&g==0),'omitnan')/sqrt(max(1,nnz(qb==b&g==0))),1:4);
    qsC=arrayfun(@(b) std(zy(qb==b&g==1),'omitnan')/sqrt(max(1,nnz(qb==b&g==1))),1:4);
    % SESSION-LEVEL paired test (PRIMARY, Nick 2026-09-11): one OL-CL gap per
    % session in Q1 and Q4; paired signed-rank of gap4 vs gap1 across sessions.
    % This respects session/mouse structure -- the trial-pooled OLS below ignores
    % it (pseudoreplication: 87% of "15 sessions" are 2 mice) and is kept for
    % reference in the console only; the STAR and the headline are session-level.
    g1s=Pl.(nm).gap1(:); g4s=Pl.(nm).gap4(:);
    ok=isfinite(g1s)&isfinite(g4s); g1s=g1s(ok); g4s=g4s(ok);
    dS=g4s-g1s; nSess=numel(dS);                    % per-session gap change Q4-Q1
    pSess=local_signrank(g4s,g1s);
    nAgree=nnz(sign(dS)==sign(median(dS)) & dS~=0); % sessions matching group direction
    dGapS=median(dS);                               % session-level median gap change
    % --- trial-pooled OLS interaction (REFERENCE ONLY, not reported in figure) ---
    G=g; nTr=numel(zy);
    Xd=[ones(nTr,1), G, zx, G.*zx]; bd=Xd\zy;
    resid=zy-Xd*bd; dof=max(nTr-4,1); s2=sum(resid.^2)/dof;
    covb=s2*inv(Xd'*Xd); se=sqrt(diag(covb)); tI=bd(4)/se(4);
    pGap=2*tcdf(-abs(tI),dof); bInt=bd(4);          % pooled p + beta, diagnostic only
    dGap=(qmO(4)-qmC(4))-(qmO(1)-qmC(1));           % descriptive Q4-Q1 gap change (pooled)
    % ---- session-aware LMM interaction (Nick 2026-09-11): cond x state, trials in sess in mice.
    % This (not the signed-rank) is the panel STAR; 3-state forest of the same model = f4_2S_stats.
    lyk=Pl.(nm).ly; lck=Pl.(nm).lc; lxk=Pl.(nm).lx; lqk=Pl.(nm).lq; lsk=Pl.(nm).lsess; lmk=Pl.(nm).lmouse;
    kp=isfinite(lyk)&isfinite(lck)&isfinite(lxk)&isfinite(lqk);
    lyk=lyk(kp); lck=lck(kp); lxk=lxk(kp); lqk=lqk(kp); lsk=lsk(kp); lmk=lmk(kp);
    condL=categorical(lck,[0 1],{'OL','CL'}); nSes=numel(unique(lsk)); nMse=numel(unique(lmk));
    Tc=table(lyk,condL,lxk,categorical(lsk),categorical(lmk), ...
        'VariableNames',{'zrmse','cond','sx','sess','mouse'});
    [bC,pC,ciC]=lme_inter(Tc,'zrmse ~ cond*sx + (1|mouse) + (1|sess)');   % continuous-state interaction (panel star)
    q14=ismember(lqk,[1 4]);
    Tb=table(lyk(q14),condL(q14),categorical(lqk(q14)),categorical(lsk(q14)),categorical(lmk(q14)), ...
        'VariableNames',{'zrmse','cond','q','sess','mouse'});
    [bQ,pQ,ciQ]=lme_inter(Tb,'zrmse ~ cond*q + (1|mouse) + (1|sess)');    % Q1-vs-Q4 interaction (robustness)
    LME.(nm)=struct('nTr',numel(lyk),'nSes',nSes,'nMse',nMse, ...
        'q14_beta',bQ,'q14_p',pQ,'q14_ci',ciQ,'cont_beta',bC,'cont_p',pC,'cont_ci',ciC);
    fprintf(['%-9s  %6d  %3d | LMM cond:state beta %+.3f p=%.3g  (Q1/Q4 p=%.3g)' ...
             '   || sess signrank p=%.3g  pooled p=%.3g\n'], ...
             nm,nTr,nSes,bC,pC,pQ, pSess,pGap);

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
    % decoupling star -- SESSION-AWARE LMM cond x state interaction (Nick 2026-09-11)
    text(ax,2.5,yl(2)-0.02*range(yl),sprintf('cond\\timesstate %s',starstr(pC)), ...
        'HorizontalAlignment','center','VerticalAlignment','top','FontSize',6,'FontWeight','bold','Color',[0.1 0.1 0.1]);
    text(ax,2.5,yl(2)-0.02*range(yl)-0.11*range(yl),sprintf('LMM p=%.2g',pC), ...
        'HorizontalAlignment','center','VerticalAlignment','top','FontSize',5,'Color',[0.35 0.35 0.35]);
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

%% ============ ROW 2 SUPPLEMENT: mixed-effects (LME) interaction table (Nick) ============
% The panel star IS the session-aware LMM cond x state interaction (continuous state), computed in
% the panel loop above and stored in LME. Here we just tabulate both parameterizations:
%   continuous state (all Q, = panel star):  zrmse ~ cond*sx + (1|mouse) + (1|sess)
%   Q1 vs Q4 (Nick's framing, robustness):    zrmse ~ cond*q  + (1|mouse) + (1|sess)
% Trials nested in sessions nested in mice; (1|mouse)+(1|sess) encodes the nesting (session labels
% are globally unique => each session loads on one mouse). NEGATIVE cond(CL):state = CL advantage
% SHRINKS at high state (gap closes); positive = it grows. Full 3-state forest = f4_2S_stats.
fprintf('\n============ ROW 2 LME (mixed-effects interaction, session-aware) ============\n');
fprintf('%-9s %6s %5s %5s | %-32s | %-26s\n','state','nTr','nSes','nMse','continuous cond:sx  beta  p (STAR)','Q1/Q4  cond:q  beta  p');
for ip=1:numel(preds); nm=preds{ip};
    if ~isfield(LME,nm); fprintf('%-9s (no data)\n',nm); continue; end
    E=LME.(nm);
    fprintf('%-9s %6d %5d %5d | beta %+.3f [%+.3f,%+.3f] p=%.3g | beta %+.3f [%+.3f,%+.3f] p=%.3g\n', ...
        nm,E.nTr,E.nSes,E.nMse, E.cont_beta,E.cont_ci(1),E.cont_ci(2),E.cont_p, E.q14_beta,E.q14_ci(1),E.q14_ci(2),E.q14_p);
end
try, save(fullfile('data','f4_row2_lme.mat'),'LME'); fprintf('[F4R2-LME] -> data/f4_row2_lme.mat\n'); catch ME; warning('[F4R2-LME] save skipped (%s)',ME.message); end

function e=uniqedges(e); for i=2:numel(e); if e(i)<=e(i-1); e(i)=e(i-1)+eps(e(i-1))*1e3; end; end; end
function s=starstr(p); if isnan(p), s='n.s.'; elseif p<1e-3, s='***'; elseif p<1e-2, s='**'; elseif p<0.05, s='*'; else, s='n.s.'; end; end
function p=local_signrank(a,b); try, p=signrank(a,b); catch, [~,p]=ttest(a,b); end; end

function [b,p,ci,name]=lme_inter(T,formula)
% Fit an LME and return the INTERACTION term (the one coefficient whose name contains ':').
% Robust to fit failure / rank-deficiency (returns NaN so the table still prints).
b=NaN; p=NaN; ci=[NaN NaN]; name='(none)';
try
    lme=fitlme(T,formula);
    cn=lme.CoefficientNames; ix=find(contains(cn,':'),1,'last');
    if ~isempty(ix)
        b=lme.Coefficients.Estimate(ix); p=lme.Coefficients.pValue(ix);
        ci=[lme.Coefficients.Lower(ix) lme.Coefficients.Upper(ix)]; name=cn{ix};
    end
catch ME
    warning('[F4R2-LME] fit failed (%s): %s', formula, ME.message);
end
end
