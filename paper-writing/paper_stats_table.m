function T = paper_stats_table()
% PAPER_STATS_TABLE  One row per statistical claim in results.tex -> STATS_TABLE.csv.
%   T = paper_stats_table();
% The manuscript quotes THIS table (NUMBERS.md rule: the paper quotes a file, the file quotes
% a run). It only LOADS the saved outputs of the producers; it recomputes nothing, so a stale
% number here means a producer was not re-run. Producers, in the order to run them:
%   fig3_olcl_stats             -> data/fig3_olcl_lmm.mat        (Fig 3 LMMs + signed-rank)
%   variance_mse.m (Fr + G2r)   -> data/fig3_ratio_stats.mat     (Fig 3H/3I session-level CL/OL ratios)
%   f4_row2_quartiles.m         -> data/f4_row2_lme.mat, data/f4_motion_slopes.mat (Fig 4D)
%   f4_cl_reject_lmm            -> controller-analysis/data/f4_cl_reject_lmm.mat (Fig 4G)
%   imp_state_trialvar.m        -> data/fig2g_state_stats.mat (save STV_R=R after the run)
% Convention for every mixed-model row (2026-10-07): REML, Satterthwaite df capped at
% nSessions-1 (utils/lmm_cluster_df.m), t-based 95% CI, exact p; 'sided' says 1 or 2.
root = fileparts(fileparts(mfilename('fullpath')));
dd   = fullfile(root,'data');
rows = cell(0,16);
    function add(id,fig,claim,eff,unit,ci,test,sn,sv,df,p,sided,n,nunit,src)
        rows(end+1,:) = {id,fig,claim,eff,unit,ci(1),ci(2),test,sn,sv,df,p,sided,n,nunit,src};
    end

% ---------------- Figure 2G : impulse-response deviation vs pre-stimulus state ----------------
S = load(fullfile(dd,'fig2g_state_stats.mat')); R = S.STV_R;
lab = struct('MOT','motion','DPr','relative 2-4 Hz','DPa','absolute 2-4 Hz');
% DV label follows the producer's mode (2026-10-12: L2 time-course error is the paper DV).
if isfield(R,'dvMode') && strcmp(R(1).dvMode,'l2')
    dvS = sprintf('L2 error (0-%.1f s)', R(1).l2Win);  spS = 'RMS';
else
    dvS = '|dev|';  spS = 'SD';
end
for t = {'MOT','DPr','DPa'}
    r = R(strcmp({R.tag},t{1}));
    % Q4/Q1 ratio (user 2026-10-16): one ratio per session from the drawn per-session curves
    % (sdRawNs), summarised as their geometric mean with the per-session range. Replaces the
    % pooled-trial ratio + hierarchical-bootstrap CI: 4 sessions give only 35 session draws,
    % and the pooled ratio did not match the panel's equal-weight session mean (motion 0.64 vs 0.58).
    rs = r.sdRawNs(:,end) ./ r.sdRawNs(:,1);
    add(['2G_' t{1} '_ratio'],'2G',sprintf('Q4/Q1 %s ratio, %s (%d/%d sessions on the side of 1 of the mean)', ...
        spS, lab.(t{1}), nnz(sign(log(rs)) == sign(mean(log(rs)))), numel(rs)), ...
        exp(mean(log(rs))),'ratio',[min(rs) max(rs)], ...
        'geometric mean of per-session ratios (range = min-max)','','',NaN,NaN,'',numel(rs),'sessions','imp_state_trialvar');
    % PRIMARY (2026-10-12, user): per-session slopes, one-sample t across sessions. The old
    % intercept-only LMM is anti-conservative (trial-based SE) and is no longer tabulated.
    sl = r.SL;
    add(['2G_' t{1} '_slope'],'2G',sprintf('per-session slope of %s on state, %s (%d/%d sessions agree)',dvS,lab.(t{1}),sl.nAgree,sl.nSess), ...
        sl.b,[spS ' per within-session SD of state'],sl.ci,'one-sample t on per-session OLS slopes','t',sl.t,sl.df,sl.p,'2', ...
        sl.nSess,'sessions','imp_state_trialvar');
    % Pooled-trial Spearman rho: effect size only (pooled p would pseudo-replicate trials).
    add(['2G_' t{1} '_rho'],'2G',['Spearman ' dvS ' vs state (pooled trials, descriptive), ' lab.(t{1})],r.rho,'rho',[NaN NaN], ...
        'Spearman (no p: trials not independent)','','',NaN,NaN,'',r.n,'trials','imp_state_trialvar');
    add(['2G_' t{1} '_ctrl'],'2G',['stimulus-free control (descriptive), ' lab.(t{1})],r.rhoP,'rho',[NaN NaN], ...
        'Spearman (no p: trials not independent)','','',NaN,NaN,'',r.n,'trials','imp_state_trialvar');
    if isfield(r,'sdPNs')
        % response/control per quartile, per session; Q4/Q1 of that ratio (descriptive; drawn in
        % Fig S2 column B, quoted in Results 2026-10-16)
        rc = r.sdRawNs ./ r.sdPNs;  rc = rc(:,end) ./ rc(:,1);
        add(['2G_' t{1} '_stimctrl'],'S-SQ',['response/control ' spS ' ratio, Q4/Q1, ' lab.(t{1})], ...
            exp(mean(log(rc))),'ratio',[min(rc) max(rc)], ...
            'geometric mean of per-session ratios (range = min-max)','','',NaN,NaN,'',numel(rc),'sessions','imp_state_trialvar');
        rp = r.sdPNs(:,end) ./ r.sdPNs(:,1);
        add(['2G_' t{1} '_ctrlratio'],'2G',['stimulus-free control Q4/Q1 ' spS ' ratio, ' lab.(t{1})], ...
            exp(mean(log(rp))),'ratio',[min(rp) max(rp)], ...
            'geometric mean of per-session ratios (range = min-max)','','',NaN,NaN,'',numel(rp),'sessions','imp_state_trialvar');
    end
end
% Supplementary state-quartile figure (imp_state_quartile_supp.m -> sq_stats.csv). Session-level
% tests on per-session quartile curves: Q4 vs mean(Q1-3), and the same contrast on the
% response/control ratio ("beyond control"), each a one-sample t on 4 session log ratios.
sqf = fullfile(root,'paper','images','supplementary','state_quartile','sq_stats.csv');
if exist(sqf,'file')
    SQ = readtable(sqf, 'TextType','string');
    sqTag = struct('MOT',"Motion",'DPr',"Relative δ power",'DPa',"Absolute δ power");
    for t = {'MOT','DPr','DPa'}
        q = SQ(SQ.state == sqTag.(t{1}), :);
        if isempty(q), continue; end
        add(['2G_' t{1} '_q4'],'S-SQ',['Q4 / mean(Q1-3) RMS, per-session curves, ' lab.(t{1})], ...
            q.rmsQ4,'ratio',[NaN NaN],'one-sample t on per-session log ratios','','',3,q.p_rmsQ4,'2', ...
            4,'sessions','imp_state_quartile_supp');
        add(['2G_' t{1} '_beyondctrl'],'S-SQ',['response/control RMS, Q4 vs mean(Q1-3), ' lab.(t{1})], ...
            q.beyondCtrl,'ratio',[NaN NaN],'one-sample t on per-session log ratios','','',3,q.p_beyondCtrl,'2', ...
            4,'sessions','imp_state_quartile_supp');
    end
end
if isfield(R,'ctlRespSD')
    v = R(1).ctlRespSD;
    add('2G_ctl_resp_spread','2G',sprintf('control/response within-session %s, range over sessions', spS), ...
        median(v),'ratio',[min(v) max(v)],'per-session range (min-max)','','',NaN,NaN,'',numel(v),'sessions','imp_state_trialvar');
end

% ---------------- Figure 3 : OL vs CL ---------------------------------------------------------
S = load(fullfile(dd,'fig3_olcl_lmm.mat')); G = S.G3;
lab3 = struct('rmse_full','RMSE 0-3 s','rmse_early','RMSE 0-1 s','rmse_late','RMSE 1-3 s', ...
              'var_stim','log variance 0-3 s','var_early','log variance 0-1 s','var_late','log variance 1-3 s');
for m = fieldnames(lab3)'
    g = G.(m{1}); isv = startsWith(m{1},'var');
    add(['3_' m{1} '_lmm'],'3',['CL-OL gap, ' lab3.(m{1})],g.lmm_gap,tern(isv,'log units','%dF/F'),g.lmm_ci, ...
        'CORROBORATING trial-level LMM y~cond+(1+cond|sess)+(1|mouse)','t',g.lmm_t,g.lmm_df,g.lmm_p,'2',g.nSess,'sessions','fig3_olcl_stats');
    add(['3_' m{1} '_sr'],'3',sprintf('CORROBORATING per-session signed-rank, %s (%d/%d sessions CL<OL)',lab3.(m{1}),g.nAgree,g.nSess), ...
        g.medRatio,'median OL/CL',[NaN NaN],'Wilcoxon signed-rank','V',g.sr_V,NaN,g.sr_p,'2',g.nSess,'sessions','fig3_olcl_stats');
end
% Fig 3H (RMSE) / 3I (variance): ONE scheme (2026-10-15). Unit = session; ratio = CL/OL (<1 = CL
% better); effect = geometric mean [95% CI]; PRIMARY = LMM log(r)~1+(1|mouse), Satterthwaite;
% also one-sample t on log r; Wilcoxon on log r corroborating. Source: variance_mse.m Fr/G2r.
S = load(fullfile(dd,'fig3_ratio_stats.mat')); R3 = S.R3;
panel3 = struct('rmse',{{'3H','RMSE'}},'var',{{'3I','variance'}});
wl = struct('pre','pre (-3-0 s)','early','0-1 s','late','1-3 s','full','0-3 s','post','post');
for mt = {'rmse','var'}
    pn = panel3.(mt{1});
    for w = {'pre','early','late','full','post'}
        r = R3.(mt{1}).(w{1});  id = [pn{1} '_' mt{1} '_' w{1}];
        lbl = sprintf('CL/OL %s ratio, %s (%d/%d sessions <1; %.1f%% lower)',pn{2},wl.(w{1}),r.nBelow1,r.n,r.pctLower);
        add([id '_lmm'],pn{1},['PRIMARY ' lbl],r.geo,'geometric-mean ratio',r.geoCI, ...
            'LMM log(r)~1+(1|mouse), Satterthwaite','t',r.lmm_t,r.lmm_df,r.lmm_p,'2',r.n,'sessions','variance_mse');
        if isnan(r.lmm_p)          % Satterthwaite df failed (0/NaN): project fallback df = n-1
            add([id '_lmmfb'],pn{1},['LMM, df fallback n-1 (Satterthwaite df=0) ' lbl],r.lmm_ratio,'LMM ratio',r.lmm_ratioCIc, ...
                'LMM log(r)~1+(1|mouse), df=n-1 (lmm_cluster_df)','t',r.lmm_t,r.lmm_dfc,r.lmm_pc,'2',r.n,'sessions','variance_mse');
        end
        add([id '_t'],pn{1},lbl,r.geo,'geometric-mean ratio',r.geoCI, ...
            'one-sample t on log ratio','t',r.t_t,r.t_df,r.t_p,'2',r.n,'sessions','variance_mse');
        add([id '_w'],pn{1},['CORROBORATING ' lbl],r.median,'median ratio',[NaN NaN], ...
            'Wilcoxon signed-rank on log ratio','V',r.w_V,NaN,r.w_p,'2',r.n,'sessions','variance_mse');
    end
end

% ---------------- Figure 4D : state quartiles ---------------------------------------------------
S = load(fullfile(dd,'f4_row2_lme.mat')); L = S.LME;
lab4 = struct('initdev','initial deviation','motion','motion','delta','relative 2-4 Hz','absdelta','absolute 1-4 Hz');
for st = fieldnames(lab4)'
    E = L.(st{1}); r = E.Rf; mdl = 'LMM y~cond*state+(1+cond|sess)+(state-1|sess)+(1|mouse)';
    u = '%dF/F RMSE per SD of state';
    add(['4D_' st{1} '_gap'],'4D',['CL-OL gap at mean state, ' lab4.(st{1})],r.gap,'%dF/F RMSE',r.gapCI, ...
        mdl,'t',r.gapT,r.gapDF,r.gapP,'2',E.nSes,'sessions','f4_row2_quartiles');
    add(['4D_' st{1} '_pred'],'4D',['predictability (OL slope), ' lab4.(st{1})],r.slope,u,r.slopeCI, ...
        mdl,'t',r.slopeT,r.slopeDF,r.slopeP,'2',E.nSes,'sessions','f4_row2_quartiles');
    add(['4D_' st{1} '_reg'],'4D',['regularizability (CL slope), ' lab4.(st{1})],r.reg,u,r.regCI, ...
        [mdl ', CL reference'],'t',r.regT,r.regDF,r.regP,'2',E.nSes,'sessions','f4_row2_quartiles');
    add(['4D_' st{1} '_att'],'4D-att',['attenuation (slope of log CL/OL), ' lab4.(st{1})],r.att,'log ratio per SD of state',r.attCI, ...
        'LMM log(y)~cond*state+(1+cond|sess)+(state-1|sess)+(1|mouse)','t',r.attT,r.attDF,r.attP,'2',E.nSes,'sessions','f4_row2_quartiles');
    add(['4D_' st{1} '_gaptrend'],'4D-disc',['gap trend (cond x state, Discussion), ' lab4.(st{1})],r.dec,u,r.decCI, ...
        mdl,'t',r.decT,r.decDF,r.decP,'2',E.nSes,'sessions','f4_row2_quartiles');
end
S = load(fullfile(dd,'f4_motion_slopes.mat')); M = S.MOTSLOPE;
add('4_motslope_OL','4','within-session OL slope, RMSE on motion',M.medOL,'median z/z',[NaN NaN], ...
    'Wilcoxon signed-rank vs 0','V',M.VOL,NaN,M.pOL,'2',M.n,'sessions','f4_row2_quartiles');
add('4_motslope_CL','4','within-session CL slope, RMSE on motion',M.medCL,'median z/z',[NaN NaN], ...
    'Wilcoxon signed-rank vs 0','V',M.VCL,NaN,M.pCL,'2',M.n,'sessions','f4_row2_quartiles');
add('4_motslope_diff','4',sprintf('OL vs CL slope (%d/%d sessions OL>CL)',sum(M.sO>M.sC),M.n),median(M.sO-M.sC),'median diff',[NaN NaN], ...
    'Wilcoxon signed-rank','V',M.VD,NaN,M.pD,'2',M.n,'sessions','f4_row2_quartiles');

% ---------------- Figure 4G : disturbance rejection ----------------------------------------------
S = load(fullfile(root,'controller-analysis','data','f4_cl_reject_lmm.mat'));
nS = numel(unique(S.T.sess)); nM = numel(unique(S.T.mouse)); sm = S.sessM;
add('4G_sess','4G',sprintf('geometric-mean RR, session-clustered (%d trials, %d mice)',height(S.T),nM),exp(sm.est),'RR',exp(sm.ci), ...
    'LMM logRR~1+(1|sess)','t',sm.t,sm.df,sm.p1,'1',nS,'sessions','f4_cl_reject_lmm');
add('4G_nested','4G','geometric-mean RR, mouse-nested',exp(S.est),'RR',exp(S.ci), ...
    'LMM logRR~1+(1|mouse)+(1|mouse:sess)','t',S.tv,S.df,S.p1,'1',nM,'mice','f4_cl_reject_lmm');
ks = S.keptsess([S.keptsess.keep]); med = [ks.medRR];
add('4G_sessmed','4G',sprintf('session median RR < 1 in %d/%d sessions',sum(med<1),numel(med)),median(med),'median RR',[NaN NaN], ...
    'Wilcoxon signed-rank on log median RR','V',S.srV,NaN,S.srSess1,'1',numel(med),'sessions','f4_cl_reject_lmm');

% ---------------- Figure 4G : open- vs closed-loop rejection (Results L193; added 2026-10-13) ----
S = load(fullfile(root,'controller-analysis','data','f4_rr_denominator_check.mat')); D = S.RRD([S.RRD.keep]);
nK = numel(D);
pairs = {'RR',        [D.RR_ol],      [D.RR_cl],      'energy ratio RR (OL vs CL)';
         'offshare',  [D.offShare_ol],[D.offShare_cl],'standing-offset share of residual (OL vs CL)';
         'RRfluct',   [D.RRfluct_ol], [D.RRfluct_cl], 'fluctuation energy / disturbance (OL vs CL)'};
for i = 1:size(pairs,1)
    o = pairs{i,2}; c = pairs{i,3};
    [p1,~,st] = signrank(o, c, 'tail','right');          % one-sided: feedback lowers it
    add(['4G_olcl_' pairs{i,1}],'4G',sprintf('%s; CL lower in %d/%d sessions',pairs{i,4},sum(c<o),nK), ...
        median(o),sprintf('median OL (CL %.3g)',median(c)),[NaN NaN],'Wilcoxon signed-rank, one-sided OL>CL', ...
        'V',st.signedrank,NaN,p1,'1',nK,'sessions','f4_rr_denominator_check');
end

% ---------------- Figure 6 (MPC replay, promoted from supplement 2026-10-16) -------------------
% SIMULATION on one session (AL_0033 2025-02-26, 108 CL trials): descriptive only, no tests.
% Source: controller-analysis/mpc_direct.py run with MPCD_RD=0.1 MPCD_ORD=0.1 MPCD_TAG=_lam01
% (timing lag 0, user decision 2026-10-12). Columns of rmse/Y: PI (recorded) | MPC | perfect-prediction MPC.
% _noCL (2026-10-16, canonical): the controller's VARX is trained on spontaneous + OL data only (MPCD_NOCL=1)
S = load(fullfile(root,'controller-analysis','data','mpc_direct_AL_0033_0226_e2_lam01_noCL.mat'));
nm = cellstr(S.names);  rr = S.rmse;  nT = size(rr,1);
for j = 1:numel(nm)
    add(sprintf('6_rmse_%d',j),'6',sprintf('median per-trial RMSE 1-3 s, %s',nm{j}),median(rr(:,j)),'%dF/F',[NaN NaN], ...
        'median (simulation, descriptive)','','',NaN,NaN,'',nT,'trials','mpc_direct');
end
q = rr(:,2) ./ rr(:,1);
add('6_ratio','6',sprintf('MPC/PI RMSE ratio, median; MPC lower on %d/%d trials',nnz(q<1),nT),median(q),'ratio',[NaN NaN], ...
    'median (simulation, descriptive)','','',NaN,NaN,'',nT,'trials','mpc_direct');
w = round(S.Fs)+1 : size(S.Y,1);                      % 1-3 s after onset (Y starts at onset)
v = squeeze(mean(var(S.Y(w,:,:),0,2),1));
add('6_var','6','across-trial variance 1-3 s, MPC / PI',v(2)/v(1),'ratio',[NaN NaN], ...
    'mean over window of across-trial variance (simulation, descriptive)','','',NaN,NaN,'',nT,'trials','mpc_direct');

% ---------------- Figure 6 sine (MPC replay on the 1 Hz sine reference, panels I-M, 2026-10-16) --------------
% SIMULATION on one session (AL_0048 2026-07-14/1, right hemisphere, Fig 5's session): descriptive only.
% Source: controller-analysis/mpc_direct_sine.py (MPCD_RD=0.1). RMSE over the full 4 s window vs the target;
% phase lag / gain from a 1 Hz fundamental fit to the trial average (Fig 5H); variance = across-trial variance
% averaged over the window. MPC / perfect are replayed on every CL and CL+p trial and paired with that recording.
S = load(fullfile(root,'controller-analysis','data','mpc_direct_sine_AL_0048_0714_e1_noCL.mat'));   % _noCL canonical
sr = cellstr(S.summary_rows); sm = S.summary; cnd = double(S.cond(:)); rRec = S.rmse_rec(:);
for j = 1:numel(sr)
    add(sprintf('6s_rmse_%d',j),'6 sine',sprintf('median per-trial RMSE 0-4 s, %s',sr{j}),sm(j,1),'%dF/F',[NaN NaN], ...
        'median (simulation, descriptive)','','',NaN,NaN,'',sm(j,5),'trials','mpc_direct_sine');
    add(sprintf('6s_lag_%d',j),'6 sine',sprintf('phase lag of trial average (1 Hz fit), %s',sr{j}),sm(j,2),'deg',[NaN NaN], ...
        'fundamental fit to trial average (descriptive)','','',NaN,NaN,'',sm(j,5),'trials','mpc_direct_sine');
    add(sprintf('6s_var_%d',j),'6 sine',sprintf('across-trial variance 0-4 s, %s',sr{j}),sm(j,4),'(%dF/F)^2',[NaN NaN], ...
        'mean over window of across-trial variance (descriptive)','','',NaN,NaN,'',sm(j,5),'trials','mpc_direct_sine');
end
sn = cellstr(S.sim_names); bl = {3,'CL'; 0,'CL+p'};
for b = 1:2
    msk = cnd == bl{b,1}; vr = sm(strcmp(sr, ['rec ' bl{b,2}]), 4);
    for j = 1:numel(sn)
        q = S.rmse_sim(msk,j) ./ rRec(msk);
        add(sprintf('6s_ratio_%s_%s',sn{j},bl{b,2}),'6 sine',sprintf('%s/%s RMSE ratio, median; lower on %d/%d trials', ...
            sn{j},bl{b,2},nnz(q<1),nnz(msk)),median(q),'ratio',[NaN NaN],'median (simulation, descriptive)','','',NaN,NaN,'', ...
            nnz(msk),'trials','mpc_direct_sine');
        vs = sm(strcmp(sr, sprintf('%s on %s', sn{j}, bl{b,2})), 4);
        add(sprintf('6s_varratio_%s_%s',sn{j},bl{b,2}),'6 sine',sprintf('across-trial variance 0-4 s, %s / %s (same trials)', ...
            sn{j},bl{b,2}),vs/vr,'ratio',[NaN NaN],'mean over window of across-trial variance (simulation, descriptive)', ...
            '','',NaN,NaN,'',nnz(msk),'trials','mpc_direct_sine');
    end
end

T = cell2table(rows,'VariableNames',{'id','figure','claim','effect','unit','ci_lo','ci_hi','test', ...
    'stat_name','stat','df','p','sided','n','n_unit','source'});
out = fullfile(root,'paper-writing','STATS_TABLE.csv');
writetable(T,out);
fprintf('[stats] %d rows -> %s\n', height(T), out);
end
function s = tern(c,a,b), if c, s=a; else, s=b; end, end
