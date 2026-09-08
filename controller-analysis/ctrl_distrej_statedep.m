% ctrl_distrej_statedep.m -- STATE-DEPENDENCE of disturbance-rejection RMSE, OL vs CL.  [DRSTATE]
%
% Does the controller make performance LESS dependent on the pre-stim brain state? For each trial the
% outcome is the disturbance-rejection RMSE (readout dFk to ref=-5 over [+1,+3]s, the same metric as
% ctrl_disturbance_rejection.m). Three pre-stim STATE predictors:
%    motion   -- mean z-motion over the pre-onset window (needs has_motion)
%    delta    -- pre-onset delta-band (1-4 Hz) power  (mean over pre bins x delta bands of *FreqPow)
%    initdev  -- |dFk_0 - ref| at stim onset (how far the readout sat from reference)
%
% For each session and condition (OL=data.nc, CL=data.wc) the predictor is z-scored WITHIN session
% (across that session's OL+CL trials, so ranges align) and an OLS slope of RMSE-vs-state is fit
% (units: %dF/F RMSE per SD of state). OL vs CL is compared PAIRED across the 13 sessions
% (Wilcoxon signed-rank on the slope pairs) -- session as unit, matching ctrl_disturbance_rejection.
% A flatter CL slope = the controller absorbing brain-state dependence.
%
% Figures (PNG): (A) 1x3 pooled scatter, OL red vs CL blue + regression lines; (B) per-session
% OL-vs-CL slope pairs per predictor. USAGE: run load_sessions.m, then this.

assert(exist('mouse','var') && exist('fields','var'), '[DRSTATE] run load_sessions.m first.');
SESS = 1:numel(fields);  ref = -5;  c0=36; c1=71; c2=141;  dur = 3;   % all loaded sessions incl. new-rig (2026-09-07)
colOL=[0.85 0.16 0.14]; colCL=[0.13 0.34 0.79];
here_s = fileparts(mfilename('fullpath')); if isempty(here_s); here_s=fullfile(pwd,'controller-analysis'); end
figdir = fullfile(here_s,'..','paper','images','figure4');
preds  = {'motion','delta','initdev'};
plab   = {'pre-stim motion (z)','pre-stim \delta ratio (z, norm.)','|\DeltaF/F_0 - ref| (z)'};

% ---- per-session extraction + slope fits ------------------------------------------------------
P = struct();
for pn = preds; P.(pn{1}) = struct('bOL',[],'bCL',[],'sess',{{}},'x',[],'y',[],'g',[]); end
for k = SESS
    M = mouse.(fields{k}); if ~isfield(M,'data'), continue; end; d = M.data;
    if ~isfield(d,'ncDfk')||isempty(d.ncDfk), continue; end
    tag = sprintf('%s_%s%s',M.mn,M.td(6:7),M.td(9:10));
    yOL = sqrt(mean((d.ncDfk(:,c1:c2)-ref).^2,2));   yCL = sqrt(mean((d.wcDfk(:,c1:c2)-ref).^2,2));

    S = struct();
    S.initdev = {abs(d.ncDfk(:,c0)-ref), abs(d.wcDfk(:,c0)-ref)};
    % motion (pre-onset window)
    if isfield(M,'has_motion') && M.has_motion && isfield(d,'ncmotion') && any(d.ncmotion(:))
        oc = size(d.ncmotion,2) - 35*dur;                       % onset column in the motion window
        S.motion = {mean(d.ncmotion(:,1:oc),2), mean(d.wcmotion(:,1:oc),2)};
    else, S.motion = {nan(numel(yOL),1), nan(numel(yCL),1)}; end
    % delta (pre-onset bins x 1-4 Hz bands). Prefer absolute ncFreqPow; these caches only carry the
    % NORMALIZED ncFreqSpec (power ratio), so fall back to it like trial_state_mse.m -- a delta-ratio
    % state index (rebuild caches with r_ctrl=0 for absolute power if a paper panel needs it).
    FPnc=[]; FPwc=[];
    if isfield(d,'ncFreqPow') && any(d.ncFreqPow(:)); FPnc=d.ncFreqPow; FPwc=d.wcFreqPow;
    elseif isfield(d,'ncFreqSpec') && any(d.ncFreqSpec(:)); FPnc=d.ncFreqSpec; FPwc=d.wcFreqSpec; end
    if ~isempty(FPnc) && isfield(d,'freqBandCtrs')
        fb = d.freqBandCtrs; dmsk = fb>=1 & fb<=4;
        ob = 3; if isfield(d,'freqOnsetBin'); ob = d.freqOnsetBin; end
        pbins = 1:max(1,ob-1);                                  % pre-onset spectral bins
        S.delta = {squeeze(mean(mean(FPnc(:,pbins,dmsk),2),3)), ...
                   squeeze(mean(mean(FPwc(:,pbins,dmsk),2),3))};
    else, S.delta = {nan(numel(yOL),1), nan(numel(yCL),1)}; end

    for pn = preds; nm=pn{1};
        xOL=S.(nm){1}; xCL=S.(nm){2};
        if all(isnan(xOL)) || all(isnan(xCL)), continue; end
        mu=mean([xOL;xCL],'omitnan'); sg=std([xOL;xCL],'omitnan'); if sg==0||isnan(sg), continue; end
        zOL=(xOL-mu)/sg; zCL=(xCL-mu)/sg;
        oOK=isfinite(zOL)&isfinite(yOL); cOK=isfinite(zCL)&isfinite(yCL);
        if nnz(oOK)<8 || nnz(cOK)<8, continue; end
        bO=polyfit(zOL(oOK),yOL(oOK),1); bC=polyfit(zCL(cOK),yCL(cOK),1);
        P.(nm).bOL(end+1)=bO(1); P.(nm).bCL(end+1)=bC(1); P.(nm).sess{end+1}=tag;
        P.(nm).x=[P.(nm).x; zOL(oOK); zCL(cOK)];
        P.(nm).y=[P.(nm).y; yOL(oOK); yCL(cOK)];
        P.(nm).g=[P.(nm).g; zeros(nnz(oOK),1); ones(nnz(cOK),1)];
    end
end

% ---- pooled paired stats + console table ------------------------------------------------------
fprintf('\n============ STATE-DEPENDENCE of disturbance-rejection RMSE (OL vs CL) ============\n');
fprintf('flattening test = signed-rank on |slope| (does CL shrink state-dependence magnitude)\n');
fprintf('predictor  n  medSlopeOL medSlopeCL | med|OL| med|CL|  p(|slope|)  flatter-in-CL\n');
ST = struct();
for pn = preds; nm=pn{1};
    bO=P.(nm).bOL(:); bC=P.(nm).bCL(:); n=numel(bO);
    if n<2, fprintf('%-9s %2d   (insufficient)\n',nm,n); continue; end
    p = local_signrank(abs(bO),abs(bC)); flat = sum(abs(bC)<abs(bO));
    ST.(nm)=struct('bOL',bO,'bCL',bC,'p',p,'n',n,'medO',median(bO),'medC',median(bC), ...
                   'medAO',median(abs(bO)),'medAC',median(abs(bC)));
    fprintf('%-9s %2d   %+9.3f  %+9.3f | %7.3f %7.3f  %9.3g     %d/%d\n', ...
        nm,n,median(bO),median(bC),median(abs(bO)),median(abs(bC)),p,flat,n);
end

% ================ FIGURE A : pooled scatter, OL vs CL, per predictor ============================
fA = local_fig(15,5);  tl=tiledlayout(fA,1,3,'Padding','compact','TileSpacing','compact');
for ip=1:numel(preds); nm=preds{ip};
    ax=nexttile(tl); hold(ax,'on');
    x=P.(nm).x; y=P.(nm).y; g=P.(nm).g;
    if isempty(x); title(ax,[nm ' (no data)']); continue; end
    io=g==0; ic=g==1;
    scatter(ax,x(io),y(io),6,colOL,'filled','MarkerFaceAlpha',0.12);
    scatter(ax,x(ic),y(ic),6,colCL,'filled','MarkerFaceAlpha',0.12);
    xr=linspace(prctile(x,1),prctile(x,99),50);
    bO=polyfit(x(io),y(io),1); bC=polyfit(x(ic),y(ic),1);
    plot(ax,xr,polyval(bO,xr),'-','Color',colOL,'LineWidth',2);
    plot(ax,xr,polyval(bC,xr),'-','Color',colCL,'LineWidth',2);
    xlabel(ax,plab{ip},'FontSize',8); if ip==1; ylabel(ax,'RMSE to ref (%\DeltaF/F), [+1,+3]s','FontSize',8); end
    xlim(ax,[prctile(x,1) prctile(x,99)]);
    if isfield(ST,nm); s=ST.(nm);
        title(ax,sprintf('%s   (paired p=%.2g, n=%d)\\newlineOL %+.2f vs CL %+.2f /SD',nm,s.p,s.n,s.medO,s.medC),'FontSize',7.5);
    else; title(ax,nm,'FontSize',8); end
    grid(ax,'on'); set(ax,'FontSize',7);
end
sgtitle(fA,'State-dependence of disturbance rejection: RMSE vs pre-stim state (OL red / CL blue)','FontSize',9);
local_save(fA, fullfile(figdir,'distrej_statedep_scatter.png'));

% ================ FIGURE B : per-session OL-vs-CL slope pairs ==================================
fB = local_fig(9,5); axB=axes(fB,'Units','normalized','Position',[0.12 0.16 0.84 0.74]); hold(axB,'on');
xc=0; xt=[]; xtl={};
for ip=1:numel(preds); nm=preds{ip};
    if ~isfield(ST,nm); continue; end; s=ST.(nm); xc=xc+1;
    for i=1:s.n; plot(axB,[xc-0.18 xc+0.18],[s.bOL(i) s.bCL(i)],'-','Color',[0.78 0.78 0.8],'LineWidth',0.6); end
    plot(axB,(xc-0.18)*ones(s.n,1),s.bOL,'o','Color',colOL,'MarkerFaceColor',colOL,'MarkerSize',4);
    plot(axB,(xc+0.18)*ones(s.n,1),s.bCL,'o','Color',colCL,'MarkerFaceColor',colCL,'MarkerSize',4);
    plot(axB,xc-0.18,median(s.bOL),'_','Color','k','MarkerSize',16,'LineWidth',2);
    plot(axB,xc+0.18,median(s.bCL),'_','Color','k','MarkerSize',16,'LineWidth',2);
    xt(end+1)=xc; xtl{end+1}=sprintf('%s\\newlinep=%.2g',nm,s.p); %#ok<AGROW,SAGROW>
end
yline(axB,0,'k:'); set(axB,'XTick',xt,'XTickLabel',xtl,'FontSize',7.5); xlim(axB,[0.4 xc+0.6]);
ylabel(axB,'slope: \DeltaRMSE / SD state','FontSize',8);
title(axB,'State-dep slope OL(red) vs CL(blue), per session (\_ = median)','FontSize',7.5);
local_save(fB, fullfile(figdir,'distrej_statedep_slopes.png'));

% NOTE (2026-09-07): the init-dev decoupling result (OL steep / CL flat, paired p=0.013)
% is a SUPPLEMENTARY analysis, NOT a Fig-4 panel -- these are regression/slope figures and
% the user chose to carry decoupling via the decomposition bars (cl_rmse_factor_windows)
% instead. The two PNGs above are kept as diagnostics; no vector panel is exported.

DRSTATE = ST;
fprintf('\n[DRSTATE] figures -> %s\n', figdir);

% ---- helpers ---------------------------------------------------------------------------------
function p = local_signrank(a,b); try, p=signrank(a,b); catch, [~,p]=ttest(a,b); end; end
function f = local_fig(w,h); if exist('paperFig','file'), f=paperFig(w,h); else, f=figure('Color','w','Units','centimeters','Position',[3 3 w h]); end; end
function local_save(f,p); if ~exist(fileparts(p),'dir'), mkdir(fileparts(p)); end; exportgraphics(f,p,'Resolution',300); fprintf('[DRSTATE]   %s\n',p); end
