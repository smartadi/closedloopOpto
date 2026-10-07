function f4_cl_reject_lmm()
% F4_CL_REJECT_LMM  Session-aware LMM for the CL-only disturbance-rejection panel.
% Per-trial RR = ||A-r||^2/||D||^2 (settled 1-3 s, leak-corrected D). Test whether
% RR<1 (rejection) with log(RR) ~ 1 + (1|mouse) + (1|mouse:session); the fixed
% intercept <0 <=> RR<1. Reach gate: keep sessions whose settled mean A_CL is
% within 1.5 %dF/F of ref (excludes tracking failures AL_0033_0212, AL_0051).
% Requires load_sessions.m first (mouse/fields in the workspace).
assert(evalin('base','exist(''mouse'',''var'') && exist(''fields'',''var'')'), 'run load_sessions.m first');
mouse  = evalin('base','mouse');  fields = evalin('base','fields');
here = fileparts(mfilename('fullpath')); dataDir = fullfile(here,'data');
bpData = fullfile(fileparts(here),'data');
CFG.nSV_load=500; CFG.Fs=35; CFG.pre_s=1.0; CFG.resp_s=3.0; REF=-5; REACH_TOL=1.5;

rr=[]; sess={}; mn={}; keptsess=struct('tag',{},'mnn',{},'nTr',{},'Aset',{},'medRR',{},'reach',{});
for s = 1:numel(fields)
    fld = fields{s}; M = mouse.(fld); freeAfter=false;
    if ~isfield(M,'d') || isempty(M.d)
        pth = fullfile(bpData, sprintf('%sctrl%s%s%d.mat', M.mn, M.td(6:7), M.td(9:10), M.en));
        if ~exist(pth,'file'); continue; end
        tmp=load(pth); if ~isfield(tmp,'d'); clear tmp; continue; end
        mouse.(fld).d=tmp.d; mouse.(fld).data=tmp.data; clear tmp;
        if ~isfield(mouse.(fld).d,'ref'); mouse.(fld).d.ref=-5; end
        freeAfter=true;
    end
    S = imp_build_session(mouse, fields, s, dataDir, CFG);
    if freeAfter; mouse.(fld)=rmfield(mouse.(fld),{'d','data'}); end
    if ~S.ok; continue; end
    pre=S.pre; Fs=S.Fs; ref=S.ref; bwin=1:pre; wr = pre+round(1*Fs)+1 : pre+round(CFG.resp_s*Fs);
    Gr_ol=S.Gol-mean(S.Gol(:,bwin),2); gdipOL=mean(mean(Gr_ol(:,wr),2));
    Gr_cl=S.Gcl-mean(S.Gcl(:,bwin),2); D=Gr_cl-gdipOL;
    rr_tr = sum((S.Acl(:,wr)-ref).^2,2) ./ sum(D(:,wr).^2,2);
    Aset  = mean(mean(S.Acl(:,wr),2));                       % session settled mean A_CL
    reach = abs(Aset-REF) <= REACH_TOL;
    ok = isfinite(rr_tr) & rr_tr>0;
    keptsess(end+1)=struct('tag',S.sess_tag,'mnn',S.mn,'nTr',nnz(ok),'Aset',Aset, ...
        'medRR',median(rr_tr(ok)),'reach',reach); %#ok<AGROW>
    if ~reach; continue; end                                 % REACH GATE
    rr   = [rr; rr_tr(ok)]; %#ok<AGROW>
    sess = [sess; repmat({S.sess_tag},nnz(ok),1)]; %#ok<AGROW>
    mn   = [mn;   repmat({S.mn},nnz(ok),1)]; %#ok<AGROW>
end

fprintf('\n== reach gate (settled |mean A_CL - ref| <= %.1f) ==\n', REACH_TOL);
for i=1:numel(keptsess)
    fprintf('  %-22s  A=%.2f  medRR=%.2f  %s\n', keptsess(i).tag, keptsess(i).Aset, ...
        keptsess(i).medRR, string(keptsess(i).reach));
end

T = table(log(rr), categorical(sess), categorical(mn), 'VariableNames',{'logRR','sess','mouse'});
nMouse = numel(unique(mn)); nSess = numel(unique(sess));
fprintf('\nLMM on %d trials, %d sessions, %d mice (reachers only)\n', height(T), nSess, nMouse);
% REML + Satterthwaite (2026-10-07), matching utils/cl_olcl_lmm.m and the Methods. Until
% then this fit used the fitlme defaults -- ML and RESIDUAL df (t(594) = trial count) with a
% normal 1.96*SE interval -- so the intercept was referenced against trials, not clusters.
lme = fitlme(T, 'logRR ~ 1 + (1|mouse) + (1|mouse:sess)', 'FitMethod','REML');
[~,~,C] = fixedEffects(lme, 'DFMethod','Satterthwaite'); C = dataset2table_safe(C);
C = lmm_cluster_df(C, nSess);                                % df <= nSess-1
est=C.Estimate(1); se=C.SE(1); tv=C.tStat(1); df=C.DFc(1); p2=C.pValueC(1); dfSat=C.DF(1);
p1 = tcdf(tv, df);                                           % one-sided: H1 intercept<0 => RR<1
ci = [C.LowerC(1) C.UpperC(1)];                              % t-based
fprintf('      Satterthwaite df %.2f, used df %.2f\n', dfSat, df);
fprintf('\n[LMM] log(RR) intercept = %.3f  (SE %.3f, t(%.0f)=%.2f)\n', est, se, df, tv);
fprintf('      geometric-mean RR = exp(intercept) = %.2f   95%% CI [%.2f, %.2f]\n', exp(est), exp(ci(1)), exp(ci(2)));
fprintf('      H0: intercept>=0 (RR>=1) vs H1: RR<1  -> one-sided p = %.3g   (two-sided %.3g)\n', p1, p2);
sessMed = [keptsess([keptsess.reach]).medRR];
fprintf('      [ref] session-level signrank of median RR vs 1: p=%.3g (n=%d)\n', signrank(sessMed,1), numel(sessMed));

srSess = signrank(sessMed,1);
[srSess1,~,srSt] = signrank(log(sessMed),0,'tail','left'); srV = srSt.signedrank;   % one-sided, RR<1

% ---- SESSION-CLUSTERED model (2026-10-07) ----------------------------------------------
% The nested model above tests a between-MOUSE quantity (the intercept) with 4 mice, two of
% which contribute one session each, so its Satterthwaite df are ~2.5 and mouse and session
% variance cannot be separated. The session-clustered model asks the question the panel
% shows -- do sessions reject? -- with df ~ nSess-1. BOTH are saved and BOTH are reported:
% the session model as the test, the nested model as the mouse-level caveat.
lmeS = fitlme(T, 'logRR ~ 1 + (1|sess)', 'FitMethod','REML');
[~,~,CS] = fixedEffects(lmeS, 'DFMethod','Satterthwaite'); CS = lmm_cluster_df(dataset2table_safe(CS), nSess);
sessM = struct('est',CS.Estimate(1),'se',CS.SE(1),'t',CS.tStat(1),'df',CS.DFc(1), ...
    'p1',tcdf(CS.tStat(1),CS.DFc(1)),'ci',[CS.LowerC(1) CS.UpperC(1)]);
fprintf('[LMM-sess] logRR ~ 1+(1|sess): GM RR %.2f [%.2f, %.2f], t(%.1f)=%.2f, one-sided p=%.3g\n', ...
    exp(sessM.est), exp(sessM.ci), sessM.df, sessM.t, sessM.p1);
fprintf('[sess medians] %d/%d < 1, signrank V=%d one-sided p=%.3g\n', sum(sessMed<1), numel(sessMed), srV, srSess1);
save(fullfile(dataDir,'f4_cl_reject_lmm.mat'),'T','keptsess','est','se','tv','df','dfSat','ci','p1','p2','srSess','srSess1','srV','sessM','lme','lmeS');
fprintf('  saved data/f4_cl_reject_lmm.mat\n');
end
