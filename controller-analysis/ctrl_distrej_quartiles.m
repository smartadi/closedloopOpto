% ctrl_distrej_quartiles.m -- STATE-DEPENDENCE of disturbance-rejection RMSE as QUARTILE CLASSES.  [DRQUART]
%
% Quartile-class replacement for the linear-slope view in ctrl_distrej_statedep.m (user 2026-09-08:
% "no linear fits, per-quartile classes"). Outcome is the disturbance-rejection RMSE (readout dFk to
% ref=-5 over [+1,+3]s, the settled window -- same metric as ctrl_disturbance_rejection.m). For each
% pre-stim STATE we bin trials into quartiles and compare OL vs CL RMSE per quartile:
%    initdev  -- |dFk_0 - ref| at onset (how far the readout sat from reference; the error fed back)
%    motion   -- mean pre-onset z-motion            (needs has_motion -> 11 sessions)
%    delta    -- pre-onset relative 1-4 Hz ratio    (normalized ncFreqSpec; power-independent state)
%
% Within each session, RMSE and state are z-scored using the combined OL+CL distribution (removes the
% session baseline, preserves the OL-vs-CL level difference), matching motion_mse_significance.m.
%
% DECOUPLING TEST (quartile analogue of the slope-flattening test): per session compute the
% Q4-Q1 RMSE gap separately for OL and CL; a smaller CL gap = the controller absorbing the
% state dependence. Paired Wilcoxon signed-rank on (gapOL, gapCL) across sessions. Also reports
% the pooled top-quartile OL-vs-CL rank-sum per state.
%
% Figure (PNG): 1x3 quartile bars (OL red / CL blue, +-SEM) with the top-quartile star.
% USAGE: run load_sessions.m, then this.

assert(exist('mouse','var') && exist('fields','var'), '[DRQUART] run load_sessions.m first.');
SESS = 1:numel(fields);  ref = -5;  c0 = 36; c1 = 71; c2 = 141;  dur = 3;
PS = paperStyle(); setPaperDefaults();
colOL = PS.col_ol;  colCL = PS.col_cl;
here_s = fileparts(mfilename('fullpath')); if isempty(here_s); here_s = fullfile(pwd,'controller-analysis'); end
figdir = fullfile(here_s,'..','paper','images','figure4');
preds = {'initdev','motion','delta'};
plab  = {'|\DeltaF/F_0 - ref| quartile','pre-stim motion quartile','pre-stim \delta ratio quartile'};

% ---- per-session extraction: z-scored state + z-scored RMSE, per condition ---------------------
Pl = struct();
for pn = preds; Pl.(pn{1}) = struct('zx',[],'zy',[],'g',[],'gapOL',[],'gapCL',[],'sess',{{}}); end
for k = SESS
    M = mouse.(fields{k}); if ~isfield(M,'data'), continue; end; d = M.data;
    if ~isfield(d,'ncDfk') || isempty(d.ncDfk), continue; end
    tag = sprintf('%s_%s%s', M.mn, M.td(6:7), M.td(9:10));
    yOL = sqrt(mean((d.ncDfk(:,c1:c2)-ref).^2,2));  yCL = sqrt(mean((d.wcDfk(:,c1:c2)-ref).^2,2));

    S = struct();
    S.initdev = {abs(d.ncDfk(:,c0)-ref), abs(d.wcDfk(:,c0)-ref)};
    if isfield(M,'has_motion') && M.has_motion && isfield(d,'ncmotion') && any(d.ncmotion(:))
        oc = size(d.ncmotion,2) - 35*dur;
        S.motion = {mean(d.ncmotion(:,1:oc),2), mean(d.wcmotion(:,1:oc),2)};
    else, S.motion = {nan(numel(yOL),1), nan(numel(yCL),1)}; end
    FPnc=[]; FPwc=[];
    if isfield(d,'ncFreqPow') && any(d.ncFreqPow(:)); FPnc=d.ncFreqPow; FPwc=d.wcFreqPow;
    elseif isfield(d,'ncFreqSpec') && any(d.ncFreqSpec(:)); FPnc=d.ncFreqSpec; FPwc=d.wcFreqSpec; end
    if ~isempty(FPnc) && isfield(d,'freqBandCtrs')
        fb=d.freqBandCtrs; dmsk=fb>=1 & fb<=4; ob=3; if isfield(d,'freqOnsetBin'); ob=d.freqOnsetBin; end
        pbins=1:max(1,ob-1);
        S.delta = {squeeze(mean(mean(FPnc(:,pbins,dmsk),2),3)), squeeze(mean(mean(FPwc(:,pbins,dmsk),2),3))};
    else, S.delta = {nan(numel(yOL),1), nan(numel(yCL),1)}; end

    % z-score RMSE within session (combined OL+CL)
    muY=mean([yOL;yCL],'omitnan'); sgY=std([yOL;yCL],'omitnan'); if sgY==0||isnan(sgY), continue; end
    zyOL=(yOL-muY)/sgY; zyCL=(yCL-muY)/sgY;

    for pn = preds; nm=pn{1};
        xOL=S.(nm){1}; xCL=S.(nm){2};
        if all(isnan(xOL))||all(isnan(xCL)), continue; end
        muX=mean([xOL;xCL],'omitnan'); sgX=std([xOL;xCL],'omitnan'); if sgX==0||isnan(sgX), continue; end
        zxOL=(xOL-muX)/sgX; zxCL=(xCL-muX)/sgX;
        oOK=isfinite(zxOL)&isfinite(zyOL); cOK=isfinite(zxCL)&isfinite(zyCL);
        if nnz(oOK)<8 || nnz(cOK)<8, continue; end
        % accumulate pooled
        Pl.(nm).zx=[Pl.(nm).zx; zxOL(oOK); zxCL(cOK)];
        Pl.(nm).zy=[Pl.(nm).zy; zyOL(oOK); zyCL(cOK)];
        Pl.(nm).g =[Pl.(nm).g;  zeros(nnz(oOK),1); ones(nnz(cOK),1)];
        % per-session Q4-Q1 gap, quartiling this session's combined state
        eS=quantile([zxOL(oOK);zxCL(cOK)],[0 .25 .5 .75 1]); eS=uniqedges(eS);
        if numel(eS)<5, continue; end
        qO=discretize(zxOL,eS); qC=discretize(zxCL,eS);
        gO=mean(zyOL(qO==4),'omitnan')-mean(zyOL(qO==1),'omitnan');
        gC=mean(zyCL(qC==4),'omitnan')-mean(zyCL(qC==1),'omitnan');
        if isfinite(gO)&&isfinite(gC)
            Pl.(nm).gapOL(end+1)=gO; Pl.(nm).gapCL(end+1)=gC; Pl.(nm).sess{end+1}=tag;
        end
    end
end

% ---- stats + console ---------------------------------------------------------------------------
% Two readouts per state:
%  (1) SHAPE per condition -- does RMSE climb Q1->Q4? pooled rank-sum Q4 vs Q1, OL and CL separately.
%      Decoupling = OL climbs (p<.05) while CL is flat (n.s.).
%  (2) DECOUPLING magnitude -- per-session |Q4-Q1| gap, signed-rank |gapOL| vs |gapCL| (CL shrinks it),
%      matching the magnitude test in ctrl_distrej_statedep.m.
fprintf('\n============ DISTURBANCE-REJECTION RMSE by STATE QUARTILE (OL vs CL) ============\n');
fprintf('predictor  n | OL Q1->Q4 climb (p)  CL Q1->Q4 climb (p) | |gap| OL vs CL smaller-in-CL p(|gap|)\n');
DQ = struct();
QB = struct();  % quartile bar data for the figure
for pn = preds; nm=pn{1};
    zx=Pl.(nm).zx; zy=Pl.(nm).zy; g=Pl.(nm).g;
    if isempty(zx), fprintf('%-9s (no data)\n',nm); continue; end
    edg=quantile(zx,[0 .25 .5 .75 1]); edg=uniqedges(edg);
    qb=discretize(zx,edg); qb(isnan(qb))=4;
    qmO=arrayfun(@(b) mean(zy(qb==b & g==0),'omitnan'),1:4);
    qmC=arrayfun(@(b) mean(zy(qb==b & g==1),'omitnan'),1:4);
    qsO=arrayfun(@(b) std(zy(qb==b & g==0),'omitnan')/sqrt(max(1,nnz(qb==b & g==0))),1:4);
    qsC=arrayfun(@(b) std(zy(qb==b & g==1),'omitnan')/sqrt(max(1,nnz(qb==b & g==1))),1:4);
    % (1) per-condition Q4-vs-Q1 climb (pooled rank-sum)
    pClimbO=ranksum(zy(qb==4 & g==0), zy(qb==1 & g==0));
    pClimbC=ranksum(zy(qb==4 & g==1), zy(qb==1 & g==1));
    dClimbO=mean(zy(qb==4 & g==0),'omitnan')-mean(zy(qb==1 & g==0),'omitnan');
    dClimbC=mean(zy(qb==4 & g==1),'omitnan')-mean(zy(qb==1 & g==1),'omitnan');
    % (2) per-session |gap| shrink test
    gO=Pl.(nm).gapOL(:); gC=Pl.(nm).gapCL(:); nG=numel(gO);
    if nG>=2, pGap=signrank(abs(gO),abs(gC)); else, pGap=NaN; end
    smCL=sum(abs(gC)<abs(gO));
    QB.(nm)=struct('qmO',qmO,'qmC',qmC,'qsO',qsO,'qsC',qsC,'pClimbO',pClimbO,'pClimbC',pClimbC);
    DQ.(nm)=struct('dClimbO',dClimbO,'pClimbO',pClimbO,'dClimbC',dClimbC,'pClimbC',pClimbC, ...
                   'medAbsGapOL',median(abs(gO)),'medAbsGapCL',median(abs(gC)),'pGap',pGap, ...
                   'nGap',nG,'smallerCL',smCL);
    fprintf('%-9s %2d | %+5.2f (%7.2g)      %+5.2f (%7.2g)     | %.2f vs %.2f   %2d/%-2d      %6.3g\n', ...
        nm,nG,dClimbO,pClimbO,dClimbC,pClimbC,median(abs(gO)),median(abs(gC)),smCL,nG,pGap);
end

% ================ FIGURE: 1x3 quartile bars, OL vs CL ==========================================
fQ = paperFig(15,4.6); tl=tiledlayout(fQ,1,3,'Padding','compact','TileSpacing','compact');
for ip=1:numel(preds); nm=preds{ip};
    ax=nexttile(tl); hold(ax,'on');
    if ~isfield(QB,nm); title(ax,[nm ' (no data)']); continue; end
    q=QB.(nm); xq=1:4; w=0.36;
    bar(ax,xq-w/2,q.qmO,w,'FaceColor',colOL,'EdgeColor','none');
    bar(ax,xq+w/2,q.qmC,w,'FaceColor',colCL,'EdgeColor','none');
    errorbar(ax,xq-w/2,q.qmO,q.qsO,'k','LineStyle','none','LineWidth',0.6,'CapSize',2);
    errorbar(ax,xq+w/2,q.qmC,q.qsC,'k','LineStyle','none','LineWidth',0.6,'CapSize',2);
    set(ax,'XTick',1:4,'XTickLabel',{'Q1','Q2','Q3','Q4'},'FontSize',7,'Box','off','TickDir','out');
    xlabel(ax,plab{ip},'FontSize',7,'FontWeight','bold');
    if ip==1, ylabel(ax,'RMSE to ref (z, within session)','FontSize',7,'FontWeight','bold'); end
    d=DQ.(nm);
    yT=max(q.qmO(4)+q.qsO(4), q.qmC(4)+q.qsC(4))+0.06;
    text(ax,4-0.18,yT,starstr(d.pClimbO),'HorizontalAlignment','center','FontSize',7.5,'FontWeight','bold','Color',colOL);
    title(ax,sprintf('%s\\newlineOL climb %+.2f (p=%.2g) / CL %+.2f (p=%.2g)',nm,d.dClimbO,d.pClimbO,d.dClimbC,d.pClimbC),'FontSize',6.8,'FontWeight','bold');
end
sgtitle(fQ,'Disturbance rejection by pre-stim state quartile (OL red / CL blue)','FontSize',9);
if ~exist(figdir,'dir'), mkdir(figdir); end
exportgraphics(fQ, fullfile(figdir,'distrej_state_quartiles.png'),'Resolution',300);
fprintf('\n[DRQUART] figure -> %s\n', fullfile(figdir,'distrej_state_quartiles.png'));

function e = uniqedges(e)
    % nudge duplicate quantile edges so discretize keeps 4 bins
    for i=2:numel(e); if e(i)<=e(i-1); e(i)=e(i-1)+eps(e(i-1))*1e3; end; end
end

function s = starstr(p)
    if p<1e-3, s='***'; elseif p<1e-2, s='**'; elseif p<0.05, s='*'; else, s='n.s.'; end
end
