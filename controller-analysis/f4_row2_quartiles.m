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
%   motion  = MEAN z-motion over -2 s -> stim end (f4_motion_stat; set F4_MOT_STAT='sq'
%             before running for the mean-square secondary)
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
% OUTPUT (paper/images/figure4/):
%   - FOUR individual vector PDFs (kept for reference/supplement), each ~4.25 cm, own y-axis,
%     legend only on init-dev, colored title: f4_2A_initdev/2B_motion/2C_delta/2D_absdelta.pdf.
%   - ONE stitched 17 cm paper figure f4_row2_quartiles.pdf: 1x4 sharing a COMMON y-axis
%     (ticks+label only on the leftmost tile), legend on init-dev only, state-colored titles.
%     This stitched version is the main-text panel.
%   No cond x state tag on any panel (the LMM decoupling p is still printed to console + f4_2S_stats).
%   DISPLAY (user 2026-10-10, supersedes the 2026-10-02 pooled decision): the main panels are
%   SESSION-LEVEL -- each session's OL/CL quartile means on its own combined-state quartile
%   edges, then mean +/- SEM across sessions (n = sessions). The old pooled-trial view
%   (pooled quartiles, trial SEM) is still written as the fallback *_pooled.pdf.
%   Requires load_sessions.m first.
% ============================================================================
clc; close all;
PS = paperStyle(); setPaperDefaults();
assert(exist('mouse','var') && exist('fields','var'), '[F4R2] run load_sessions.m first.');

if exist(fullfile('paper','images'),'dir');            paper_root = 'paper';
elseif exist(fullfile('..','paper','images'),'dir');   paper_root = fullfile('..','paper');
else;  paper_root = 'paper'; warning('[F4R2] cannot locate paper/.'); end
outdir = fullfile(paper_root,'images','figure4');
outdir2 = fullfile(paper_root,'images','figure4');   % working copy (stitched main panel); final via paper_final_mirror
if ~exist(outdir,'dir'); mkdir(outdir); end
if ~exist(outdir2,'dir'); mkdir(outdir2); end

Fs=35; ref=-5; c0=36; c1=71; c2=141; dur=3; c0_mot=71; c0_l=106; c0_p=351;
% c0_p = onset col in pncDfk/pwcDfk (controllerData buffers dFk(i-350:i+..), 350-sample
% pre => onset at col 351). Current caches store pncDfk/pwcDfk, NOT the older _l variants
% (onset col 106); the delta path falls back to these so rel-delta needs no cache rebuild.
% STATE WINDOW (2026-10-02): 'peri' (published, -2..+3 s) | 'pre2' | 'pre1'. ONE definition,
% utils/f4_state_window.m, shared with f4_row2_pool / f4_error_decomp / f4_state_exemplars.
% It must reach BOTH the pool (the star) and the inline block below (the bars).
if ~exist('F4_STATE_WIN','var') || isempty(F4_STATE_WIN), F4_STATE_WIN = 'peri'; end
W_state = f4_state_window(F4_STATE_WIN);
fprintf('[F4R2] state window: %s\n', W_state.label);
relopts = struct('pre',2,'post',3,'rel_idx',W_state.spec,'bandpow',W_state.bandpow);   % window from f4_state_window
colOL = PS.col_ol; colCL = PS.col_cl;
preds = {'initdev','motion','delta','absdelta'};
titR2 = {'Initial deviation','Motion','Rel 2-4 Hz','Abs \delta'};
titCol = [0.20 0.40 0.75; 0.75 0.40 0.10; 0.35 0.55 0.30; 0.55 0.25 0.60];  % init,motion,rel,abs -> match state exemplars/decomp
fnout = {'f4_2A_initdev.pdf','f4_2B_motion.pdf','f4_2C_delta.pdf','f4_2D_absdelta.pdf'};

% ---- session-aware LMM: SHARED with f4_row2_stats.m so the panel star == f4_2S_stats decoupling p.
% Same pool (f4_row2_pool) + same model (f4_row2_fit): RMSE~cond*state_wc+(1+cond|sess)+(1|mouse).
% MOTION STATISTIC: 'mean' (primary) | 'sq' (secondary). Set F4_MOT_STAT before running.
% It must reach BOTH the pool below and the panel's own binning block, or the bars and the
% star disagree -- which is exactly what happened on 2026-10-01.
if ~exist('F4_MOT_STAT','var') || isempty(F4_MOT_STAT), F4_MOT_STAT = 'mean'; end
[POOLs,~] = f4_row2_pool(mouse,fields,F4_MOT_STAT,F4_STATE_WIN); FIT = struct();
for pn=preds; FIT.(pn{1}) = f4_row2_fit(POOLs.(pn{1})); end

% ---- per-session z-scored state + z-scored RMSE, per condition -------------------------------
Pl = struct();
% zx/zy/g = pooled trial arrays for the panel; gap1/gap4 = per-session Q1/Q4 gaps (primary test).
% l* = per-trial table for the LME supplement (ly outcome, lc cond, lx within-session state z,
% lq within-session quartile, lsess session id, lmouse mouse name).
% sqO/sqC = per-session quartile means [nSess x 4] (SESSION-LEVEL display, 2026-10-10).
for pn=preds; Pl.(pn{1})=struct('zx',[],'zy',[],'g',[],'gap1',[],'gap4',[],'sqO',[],'sqC',[], ...
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
        mcO = c0_mot + W_state.mot;  mcO = mcO(mcO>=1 & mcO<=size(d.ncmotion,2));
        mcC = c0_mot + W_state.mot;  mcC = mcC(mcC>=1 & mcC<=size(d.wcmotion,2));
        % Same statistic as the pool, via the SHARED utils/f4_motion_stat.m. These two
        % blocks are duplicated pooling code and DIVERGED on 2026-10-01 (pool switched to
        % the mean square, this copy not), so the bars binned one ordering while the star
        % above them tested another. One function now, so that cannot recur.
        S.motion = f4_motion_stat(d.ncmotion(:,mcO), d.wcmotion(:,mcC), F4_MOT_STAT);
    else, S.motion={nan(nO,1),nan(nC,1)}; end
    if isfield(d,'pncDfk_l')&&~isempty(d.pncDfk_l)&&isfield(d,'pwcDfk_l')&&~isempty(d.pwcDfk_l)
        [rO,cO]=cl_reldelta(d.pncDfk_l,c0_l,Fs,relopts); [rC,cC]=cl_reldelta(d.pwcDfk_l,c0_l,Fs,relopts);
    elseif isfield(d,'pncDfk')&&~isempty(d.pncDfk)&&isfield(d,'pwcDfk')&&~isempty(d.pwcDfk)
        [rO,cO]=cl_reldelta(d.pncDfk,c0_p,Fs,relopts); [rC,cC]=cl_reldelta(d.pwcDfk,c0_p,Fs,relopts);
    else, rO=nan(nO,1); rC=nan(nC,1); cO.delta=rO; cC.delta=rC; end
    S.delta={rO,rC};
    adlog=@(v) reshape(log10(max(double(v(:)),eps)),[],1);
    S.absdelta={adlog(cO.delta), adlog(cC.delta)};    % log10 abs 1-4 Hz power, same window as rel

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
        % per-session quartile means on the SAME within-session edges (session-level display)
        Pl.(nm).sqO(end+1,:)=arrayfun(@(b) mean(zyOL(qO==b & oOK),'omitnan'),1:4);
        Pl.(nm).sqC(end+1,:)=arrayfun(@(b) mean(zyCL(qC==b & cOK),'omitnan'),1:4);
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
% ---- FOUR INDIVIDUAL PANELS (user 2026-09-28): one standalone PDF per state, sized to sit
% side by side in a 17 cm row in Illustrator (4 x ~4.25 cm). NOT stitched into one figure. ----
% ABSOLUTE, 2026-10-02. This was `fullfile('_preview')` -- relative, so it resolved against
% whatever the cwd happened to be. Run from the project root it created a SECOND preview dir
% at brain_paper/_preview/ while the PNGs everyone looks at live in controller-analysis/
% _preview/, so the stitched panel's PNG read as hours stale while its PDF was current.
outview=fullfile(fileparts(which('f4_row2_quartiles')),'_preview');
if ~exist(outview,'dir'); mkdir(outview); end
PQ=struct('qmO',{},'qmC',{},'qsO',{},'qsC',{},'qmOp',{},'qmCp',{},'qsOp',{},'qsCp',{},'medO',{},'medC',{},'iqO',{},'iqC',{},'predP',{},'predUp',{},'ctrlP',{},'ctrlUp',{});   % per-state quantities for the stitched figure
for ip=1:numel(preds); nm=preds{ip};
    zx=Pl.(nm).zx; zy=Pl.(nm).zy; g=Pl.(nm).g;
    if isempty(zx); fprintf('%-9s (no data)\n',nm); continue; end
    % POOLED-TRIAL view (the 2026-10-02 display, kept as the FALLBACK -> *_pooled.pdf):
    % quartiles on the pooled within-session z, trial-level SEM.
    edg=quantile(zx,[0 .25 .5 .75 1]); edg=uniqedges(edg);
    qb=discretize(zx,edg); qb(isnan(qb))=4;
    qmOp=arrayfun(@(b) mean(zy(qb==b&g==0),'omitnan'),1:4);
    qmCp=arrayfun(@(b) mean(zy(qb==b&g==1),'omitnan'),1:4);
    qsOp=arrayfun(@(b) std(zy(qb==b&g==0),'omitnan')/sqrt(max(1,nnz(qb==b&g==0))),1:4);
    qsCp=arrayfun(@(b) std(zy(qb==b&g==1),'omitnan')/sqrt(max(1,nnz(qb==b&g==1))),1:4);
    % SESSION-LEVEL view (MAIN panel, user 2026-10-10, same move as Fig 2G): each session's
    % quartile means on its OWN combined-state edges, then mean +/- SEM ACROSS SESSIONS
    % (sessions weighted equally, matching the session-aware LMM the panel reports).
    sO=Pl.(nm).sqO; sC=Pl.(nm).sqC;
    % alternative summary (user 2026-10-10 asked mean vs median/IQR): median across sessions,
    % error bar = interquartile range of the session values (asymmetric, [below; above]).
    medO=median(sO,1,'omitnan'); medC=median(sC,1,'omitnan');
    qO_=prctile(sO,[25 75],1); qC_=prctile(sC,[25 75],1);
    iqO=[medO-qO_(1,:); qO_(2,:)-medO]; iqC=[medC-qC_(1,:); qC_(2,:)-medC];
    qmO=mean(sO,1,'omitnan'); qmC=mean(sC,1,'omitnan');
    qsO=std(sO,0,1,'omitnan')./sqrt(max(1,sum(isfinite(sO),1)));
    qsC=std(sC,0,1,'omitnan')./sqrt(max(1,sum(isfinite(sC),1)));
    fprintf('[F4R2 sess] %-9s n=%2d sessions | OL %s | CL %s\n',nm,size(sO,1), ...
        sprintf('%+.2f ',qmO),sprintf('%+.2f ',qmC));
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
    % ---- session-aware LMM interaction (SHARED f4_row2_fit): the panel STAR. IDENTICAL to the
    % f4_2S_stats forest decoupling p (same pool, same model: RMSE~cond*state_wc+(1+cond|sess)+(1|mouse)).
    Rf=FIT.(nm); pC=Rf.decP; bC=Rf.dec;
    LME.(nm)=struct('nTr',height(POOLs.(nm)),'nSes',numel(unique(POOLs.(nm).sess)), ...
        'nMse',numel(unique(POOLs.(nm).mouse)),'dec_beta',bC,'dec_p',pC,'dec_ci',Rf.decCI, ...
        'gap_beta',Rf.gap,'gap_p',Rf.gapP,'gap_ci',Rf.gapCI,'randslope',Rf.randslope, ...
        'Rf',rmfield(Rf,'lme'));
    fprintf(['%-9s  %6d  %3d | LMM cond:state beta %+.3f p=%.3g%s' ...
             '   || sess signrank p=%.3g  pooled p=%.3g\n'], ...
             nm,nTr,LME.(nm).nSes,bC,pC,tern(Rf.randslope,'',' (rand-int)'), pSess,pGap);

    % ---- two-concept annotation stats (from the SAME LMM) ----
    % Predictability = trend of OPEN-LOOP outcome (xw main effect, OL ref). OL error UP -> predictability DOWN.
    % Controllability = trend of REJECTION FRACTION (-dec). gap widens (dec<0) -> controllability UP.
    % Satterthwaite p from f4_row2_fit (2026-10-07). Was lme.Coefficients = residual df.
    bOL=Rf.slope; predP=Rf.slopeP; predUp = bOL<0;                 % predictability arrow up iff OL improves
    % Second property is REGULARIZABILITY (CL slope on state), not the gap trend (2026-10-07):
    % the gap trend cannot tell "OL worsens while CL holds" from "CL worsens". The variables
    % keep their old ctrl* names so the draw/stash code below is unchanged.
    ctrlP=Rf.regP; ctrlUp = Rf.reg<0;                              % regularizability arrow up iff CL error FALLS
    fprintf('           predictability %s (OL slope %+.3f p=%.2g) | regularizability %s (CL slope %+.3f p=%.2g) | attenuation %+.3f p=%.2g | gap trend %+.3f p=%.2g\n', ...
        tern(predUp,'UP','DOWN'),bOL,predP, tern(ctrlUp,'UP','DOWN'),Rf.reg,ctrlP, Rf.att,Rf.attP, Rf.dec,Rf.decP);

    % stash per-state quantities so the stitched paper figure reuses them (no recompute)
    PQ(ip)=struct('qmO',qmO,'qmC',qmC,'qsO',qsO,'qsC',qsC,'qmOp',qmOp,'qmCp',qmCp,'qsOp',qsOp,'qsCp',qsCp, ...
                  'medO',medO,'medC',medC,'iqO',iqO,'iqC',iqC, ...
                  'predP',predP,'predUp',predUp,'ctrlP',ctrlP,'ctrlUp',ctrlUp); %#ok<AGROW>

    % ---- separate standalone panel: keep its own y-axis; legend ONLY on init-dev; colored title ----
    figP=jnFig(jnPanelWidth('double',4),3.3); ax=axes(figP);   % jn* v2 sizing
    draw_panel(ax, qmO,qmC,qsO,qsC, colOL,colCL, PS, titR2{ip}, titCol(ip,:), true, ip==1, ...
        predP,predUp,ctrlP,ctrlUp,'points');
    % ---- F4Q_GRANT: grant copies of 2B/2C at the EXACT printed width (opt-in, 2026-09-30) ----
    % Set F4Q_GRANT = {targetCm, outDir} to ALSO write fig:pid C,D for the R01. The locked
    % paper PDFs in outdir are written either way -- this branch never touches them. These
    % panels are natural 4.25 cm shown at 2.305 cm, a 0.54x reduction that put 6 pt labels
    % and a 5 pt annotation on the page at 3.3 pt and 2.7 pt. Exporting at the printed width
    % makes the scale 1.0, so the sizes set here are the sizes a reader sees.
    if exist('F4Q_GRANT','var')==1 && ~isempty(F4Q_GRANT) && any(ip==[2 3])
        figG=jnFig(F4Q_GRANT{1},1.95); axG=axes(figG);
        draw_panel(axG, qmO,qmC,qsO,qsC, colOL,colCL, PS, titR2{ip}, titCol(ip,:), true, false, ...
            predP,predUp,ctrlP,ctrlUp);
        title(axG,''); ylabel(axG,'');    % LaTeX prints the panel title; a rotated
                                          % 'RMSE to ref (z)' at 11 pt is ~90 pt against a
                                          % ~38 pt plot height and can only clip
        delete(findobj(axG,'Type','text'));   % 'P up**' / 'C n.s.' are two more lines of
                                              % text than a 65 pt panel holds; the caption
                                              % already explains the black gap line
        % Ticks 6 pt, not 8 (user 2026-09-30: "ticks are too big you can make them small").
        set(axG,'FontSize',6,'FontWeight','bold','XTick',[1 4],'XTickLabel',{'Q1','Q4'}, ...
                'Position',[0.26 0.21 0.71 0.73]);
        % Round tick values, not the axis limits: '-0.65' at 8 pt bold is ~22 pt and its
        % minus sign fell off the left edge of the exact page. '-0.5' fits the margin.
        set(axG,'YTick',[-0.5 0 1],'YTickLabel',{'-0.5','0','1'});
        pG=get(figG,'Position');
        set(figG,'PaperUnits','centimeters','PaperSize',[F4Q_GRANT{1} pG(4)], ...
                 'PaperPosition',[0 0 F4Q_GRANT{1} pG(4)],'PaperPositionMode','manual', ...
                 'Units','centimeters','Position',[pG(1) pG(2) F4Q_GRANT{1} pG(4)]);
        if ~exist(F4Q_GRANT{2},'dir'), mkdir(F4Q_GRANT{2}); end
        outG=fullfile(F4Q_GRANT{2},fnout{ip});     % vector: zoomable with no raster ceiling
        print(figG,'-dpdf','-vector',outG);
        fprintf('[F4R2 grant] %s -> %.3f cm page (vector)\n',outG,F4Q_GRANT{1});
        close(figG);
    end
    try
        paperExport(figP, fullfile(outdir,fnout{ip}));
        paperExport(figP, fullfile(outview,strrep(fnout{ip},'.pdf','.png')));
    catch ME, warning('[F4R2] export skip %s (%s)',fnout{ip},ME.message); end
    % FALLBACK standalone (pooled-trial view, the pre-2026-10-10 display) -> *_pooled.pdf
    figPp=jnFig(jnPanelWidth('double',4),3.3); axp=axes(figPp);
    draw_panel(axp, qmOp,qmCp,qsOp,qsCp, colOL,colCL, PS, titR2{ip}, titCol(ip,:), true, ip==1, ...
        predP,predUp,ctrlP,ctrlUp);
    try
        paperExport(figPp, fullfile(outdir,strrep(fnout{ip},'.pdf','_pooled.pdf')));
    catch ME, warning('[F4R2] export skip pooled %s (%s)',fnout{ip},ME.message); end
end
fprintf('\n[F4R2] row-2 four individual panels -> %s\n', outdir);

% ---- STITCHED paper figure: 1x4 sharing ONE y-axis (ticks+label only on leftmost), legend on init-dev ----
% Two views (2026-10-10): SESSION-LEVEL = main panel f4_row2_quartiles.pdf (in MANIFEST);
% POOLED-TRIAL = fallback f4_row2_quartiles_pooled.pdf (working dir only, not in MANIFEST).
% + MEDIAN view (session median, IQR across sessions) -> f4_row2_quartiles_median.pdf (alternative).
VIEWS={'session','f4_row2_quartiles'; 'pooled','f4_row2_quartiles_pooled'; 'median','f4_row2_quartiles_median'};
for iv=1:size(VIEWS,1)
    figR=jnFig(16.5,3.3); tlR=tiledlayout(figR,1,4,'TileSpacing','compact','Padding','tight');   % jn* v2 stitched: 16.5 canvas -> crops to ~16.6, fits 17.6 col w/ clearance
    for ip=1:numel(preds)
        if numel(PQ)<ip || isempty(PQ(ip).qmO); continue; end
        ax=nexttile(tlR);
        q=PQ(ip);
        switch VIEWS{iv,1}
            case 'session', m={q.qmO,q.qmC,q.qsO,q.qsC}; sty='points';
            case 'median',  m={q.medO,q.medC,q.iqO,q.iqC}; sty='points';
            otherwise,      m={q.qmOp,q.qmCp,q.qsOp,q.qsCp}; sty='bars';
        end
        draw_panel(ax, m{:}, colOL,colCL, PS, ...
            titR2{ip}, titCol(ip,:), ip==1, ip==1, ...   % showY only leftmost; legend only leftmost
            PQ(ip).predP,PQ(ip).predUp,PQ(ip).ctrlP,PQ(ip).ctrlUp,sty);
    end
    title(tlR,'Effect of state on controller performance','FontSize',PS.fs,'FontWeight','bold');
    xlabel(tlR,'sorted state quartile bins','FontSize',PS.fs,'FontWeight','bold');   % common x-label
    try
        paperExport(figR, fullfile(outdir2,[VIEWS{iv,2} '.pdf']));
        paperExport(figR, fullfile(outview,[VIEWS{iv,2} '.png']));
    catch ME, warning('[F4R2] stitched export skip (%s)',ME.message); end
    fprintf('[F4R2] row-2 STITCHED (%s view) -> %s\\%s.pdf\n', VIEWS{iv,1}, outdir2, VIEWS{iv,2});
end

%% ============ ROW 2 SUPPLEMENT: mixed-effects (LME) interaction table (Nick) ============
% The panel star IS the session-aware LMM cond x state interaction, computed by the SHARED helper
% f4_row2_fit on the SHARED pool f4_row2_pool -- so these numbers are IDENTICAL to the f4_2S_stats
% forest (f4_row2_stats.m).  Model:  RMSE ~ cond*state_wc + (1+cond|sess) + (1|mouse)  (state
% centered within session; random OL/CL slope per session).  cond_CL:state_wc = DECOUPLING
% (NEGATIVE = CL advantage shrinks at high state); cond_CL = OL-CL gap at mean state.
fprintf('\n============ ROW 2 LME (session-aware, SHARED with f4_2S_stats) ============\n');
fprintf('%-9s %6s %5s %5s | %-34s | %-26s\n','state','nTr','nSes','nMse','cond:state  beta  p (DECOUPLING/STAR)','cond_CL gap  beta  p');
for ip=1:numel(preds); nm=preds{ip};
    if ~isfield(LME,nm); fprintf('%-9s (no data)\n',nm); continue; end
    E=LME.(nm);
    fprintf('%-9s %6d %5d %5d | beta %+.3f [%+.3f,%+.3f] p=%.3g | beta %+.3f [%+.3f,%+.3f] p=%.3g\n', ...
        nm,E.nTr,E.nSes,E.nMse, E.dec_beta,E.dec_ci(1),E.dec_ci(2),E.dec_p, E.gap_beta,E.gap_ci(1),E.gap_ci(2),E.gap_p);
end
% ---- within-session motion slopes, OL vs CL (Results text, 2026-10-07) -------------------
% Per session, RMSE and motion are z-scored within session AND condition, then regressed
% per condition; slopes compared across the 11 motion sessions by signed-rank. Reproduces the
% quoted +0.13 / -0.05 / 11-of-11 exactly; moved here from a console run so it is rebuildable.
Tm=POOLs.motion; usm=unique(Tm.sess); zsf=@(v)(v-mean(v))/std(v); sO=nan(numel(usm),1); sC=sO;
for i=1:numel(usm), mm=Tm.sess==usm(i); yv=Tm.y(mm); xv=Tm.x(mm); oo=Tm.cond(mm)=='OL'; ll=~oo;
    bb=polyfit(zsf(xv(oo)),zsf(yv(oo)),1); sO(i)=bb(1); bb=polyfit(zsf(xv(ll)),zsf(yv(ll)),1); sC(i)=bb(1); end
[pO,~,sto]=signrank(sO); [pC,~,stc]=signrank(sC); [pD,~,std_]=signrank(sO,sC);
MOTSLOPE=struct('sO',sO,'sC',sC,'n',numel(usm),'medOL',median(sO),'medCL',median(sC), ...
    'VOL',sto.signedrank,'pOL',pO,'VCL',stc.signedrank,'pCL',pC,'VD',std_.signedrank,'pD',pD,'nOLgtCL',sum(sO>sC));
bpRoot=fileparts(fileparts(mfilename('fullpath')));   % absolute: run() changes the CWD
try, save(fullfile(bpRoot,'data','f4_motion_slopes.mat'),'MOTSLOPE'); catch, end
try, save(fullfile(bpRoot,'data','f4_row2_lme.mat'),'LME'); fprintf('[F4R2-LME] -> data/f4_row2_lme.mat\n'); catch ME; warning('[F4R2-LME] save skipped (%s)',ME.message); end

function draw_panel(ax, qmO,qmC,qsO,qsC, colOL,colCL, PS, ttl, titleCol, showY, showLegend, predP,predUp,ctrlP,ctrlUp,sty)
% sty: 'bars' (pooled fallback, the original look) | 'points' (session views, user 2026-10-10:
% point-and-line, OL/CL offset in x). qs* is a 1x4 symmetric error or a 2x4 [below; above].
    if nargin<17 || isempty(sty), sty='bars'; end
% One OL/CL-by-quartile panel. Colored title; optional y-axis + legend.
% Two-concept annotation (top-right): Predictability + Regularizability, each an up/down arrow
% with significance stars (n.s. if p>=0.05). Predictability = OL slope, Regularizability = CL slope.
    hold(ax,'on');
    yline(ax,0,'-','Color',[0.6 0.6 0.6],'LineWidth',0.5);
    xq=1:4; w=0.36;
    lohi=@(e) deal(e(1,:), e(end,:));          % 1x4 -> symmetric; 2x4 -> [below; above]
    [lO,hO]=lohi(qsO); [lC,hC]=lohi(qsC);
    if strcmp(sty,'points')
        dx=0.12;
        errorbar(ax,xq-dx,qmO,lO,hO,'-o','Color',colOL,'MarkerFaceColor',colOL,'MarkerEdgeColor','none', ...
            'MarkerSize',3.5,'LineWidth',1.0,'CapSize',0);
        errorbar(ax,xq+dx,qmC,lC,hC,'-o','Color',colCL,'MarkerFaceColor',colCL,'MarkerEdgeColor','none', ...
            'MarkerSize',3.5,'LineWidth',1.0,'CapSize',0);
    else
        bar(ax,xq-w/2,qmO,w,'FaceColor',colOL,'EdgeColor','none');
        bar(ax,xq+w/2,qmC,w,'FaceColor',colCL,'EdgeColor','none');
        errorbar(ax,xq-w/2,qmO,lO,hO,'k','LineStyle','none','LineWidth',0.5,'CapSize',2);
        errorbar(ax,xq+w/2,qmC,lC,hC,'k','LineStyle','none','LineWidth',0.5,'CapSize',2);
    end
    % OL-CL gap line REMOVED 2026-10-07 (user): the gap trend is a Discussion quantity now,
    % and drawing it invited reading it as the panel's second property.
    set(ax,'XTick',1:4,'XTickLabel',{'Q1','Q2','Q3','Q4'},'Box','off','TickDir','out', ...
        'FontSize',PS.fs,'FontWeight','bold');
    % ylim lower edge -0.95 (2026-10-10): Abs-delta CL Q1 is -0.74 (session view) and was
    % clipped at the old -0.65 in BOTH views.
    xlim(ax,[0.35 4.65]); ylim(ax,[-0.95 1.40]); yl=ylim(ax);
    title(ax,ttl,'FontSize',PS.fs,'FontWeight','bold','Color',titleCol);   % colored to match state exemplars
    % ---- two-concept annotation (top-center, black): predictability + controllability, arrow + stars ----
    % First/leftmost panel spells the names out; the rest abbreviate to P / C.
    if showLegend, pN='Predictability'; cN='Regularizability'; else, pN='P'; cN='R'; end
    yA=yl(2)-0.02*range(yl); dyA=0.085*range(yl);
    text(ax,2.5,yA,     [pN ' ' arrowstars(predP,predUp)],'Interpreter','tex','HorizontalAlignment','center', ...
        'VerticalAlignment','top','FontSize',5,'FontWeight','bold','Color',[0 0 0]);
    text(ax,2.5,yA-dyA, [cN ' ' arrowstars(ctrlP,ctrlUp)],'Interpreter','tex','HorizontalAlignment','center', ...
        'VerticalAlignment','top','FontSize',5,'FontWeight','bold','Color',[0 0 0]);
    if showY
        ylabel(ax,'RMSE to ref (z)','FontSize',PS.fs,'FontWeight','bold');
    else
        set(ax,'YTickLabel',[]);
    end
    if showLegend
        xL=0.5; yTop=yl(2)-0.03*range(yl); dh=0.10*range(yl);   % far-left so it clears the centered annotation
        mk=tern(strcmp(sty,'points'),'o','s');   % legend glyph matches the plot style
        plot(ax,xL,yTop,mk,'MarkerFaceColor',colOL,'MarkerEdgeColor','none','MarkerSize',5);
        text(ax,xL+0.14,yTop,'OL','FontSize',5,'FontWeight','bold','Color',colOL,'VerticalAlignment','middle');
        plot(ax,xL,yTop-dh,mk,'MarkerFaceColor',colCL,'MarkerEdgeColor','none','MarkerSize',5);
        text(ax,xL+0.14,yTop-dh,'CL','FontSize',5,'FontWeight','bold','Color',colCL,'VerticalAlignment','middle');
    end
    hold(ax,'off');
    jnAxes(ax);   % jn* v2: Arial, regular ticks, bold labels/title, TickDir out
    if ~showY, set(ax,'YTickLabel',[]); end   % jnAxes restores ticklabels; re-hide on non-leftmost
end
function s=arrowstars(p,isUp)
% arrow (up/down) + significance stars; 'n.s.' if p>=0.05.
    nst=(p<0.05)+(p<0.01)+(p<0.001);
    if nst==0, s='n.s.'; return; end
    if isUp, ar='\uparrow'; else, ar='\downarrow'; end
    s=[ar repmat('*',1,nst)];
end
function e=uniqedges(e); for i=2:numel(e); if e(i)<=e(i-1); e(i)=e(i-1)+eps(e(i-1))*1e3; end; end; end
function s=starstr(p); if isnan(p), s='n.s.'; elseif p<1e-3, s='***'; elseif p<1e-2, s='**'; elseif p<0.05, s='*'; else, s='n.s.'; end; end
function p=local_signrank(a,b); try, p=signrank(a,b); catch, [~,p]=ttest(a,b); end; end
function s=tern(c,a,b); if c, s=a; else, s=b; end; end
