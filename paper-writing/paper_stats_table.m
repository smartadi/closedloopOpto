function T = paper_stats_table()
% PAPER_STATS_TABLE  One row per statistical claim in results.tex -> STATS_TABLE.csv.
%   T = paper_stats_table();
% The manuscript quotes THIS table (NUMBERS.md rule: the paper quotes a file, the file quotes
% a run). It only LOADS the saved outputs of the producers; it recomputes nothing, so a stale
% number here means a producer was not re-run. Producers, in the order to run them:
%   variance_mse.m (Fr + G2r)   -> data/fig3_ratio_stats.mat     (Fig 3H/3I session-level CL/OL ratios)
%   ctrl_best_fixed_ol.m        -> controller-analysis/data/ctrl_best_fixed_ol.mat (best fixed input)
%   f4_row2_quartiles.m         -> data/f4_row2_sess.mat (Fig 4D session-level P/R/A)
%   f4_cl_reject_lmm            -> controller-analysis/data/f4_cl_reject_lmm.mat (Fig 4G)
%   imp_state_trialvar.m        -> data/fig2g_state_stats.mat (save STV_R=R after the run)
% SESSION RULE (2026-10-27, STATS_AUDIT §7) for Figs 3 and 4D: one value per session, one-sample t
% across sessions (two-sided, df = n-1, t CI), via utils/sess_test.m; the extra columns carry the
% exact Wilcoxon p, sessions/mice agreeing in sign, the leave-one-mouse-out worst p, the Holm p
% (Fig 4D) and a role (main / secondary / control / descriptive). Fig 4G rows are still the
% mixed-model convention (REML, Satterthwaite df capped at nSessions-1, utils/lmm_cluster_df.m)
% until f4_cl_reject_lmm is re-run on the fixed onsets; 'sided' says 1 or 2.
root = fileparts(fileparts(mfilename('fullpath')));
dd   = fullfile(root,'data');
rows = cell(0,22);
    function add(id,fig,claim,eff,unit,ci,test,sn,sv,df,p,sided,n,nunit,src,X)
        % X (optional, 2026-10-27 session rule): role, w_p, k_n, mice, lomo_p, holm_p
        if nargin < 16, X = struct(); end
        x = struct('role','','w_p',NaN,'k_n','','mice','','lomo_p',NaN,'holm_p',NaN);
        for f = fieldnames(X)', x.(f{1}) = X.(f{1}); end
        rows(end+1,:) = {id,fig,claim,eff,unit,ci(1),ci(2),test,sn,sv,df,p,sided,n,nunit,src, ...
                         x.role,x.w_p,x.k_n,x.mice,x.lomo_p,x.holm_p};
    end
    function addS(id,fig,claim,S,unit,role,src,holm)
        % one session-level test row from a utils/sess_test struct (two-sided t, df = n-1)
        if nargin < 8, holm = NaN; end
        add(id,fig,claim,S.effect,unit,S.ci,'one-sample t across sessions','t',S.t,S.df,S.p,'2', ...
            S.n,'sessions',src,struct('role',role,'w_p',S.w_p,'k_n',sprintf('%d/%d',S.k,S.k_n), ...
            'mice',sprintf('%d/%d',S.mouse_k,S.mouse_n),'lomo_p',S.lomo_worst_p,'holm_p',holm));
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
% SESSION RULE (2026-10-27, STATS_AUDIT §7). Unit = session; ratio = CL/OL (<1 = CL better);
% effect = geometric mean [95% CI]; the test = one-sample t on log r across sessions (two-sided,
% df = n-1), with the exact Wilcoxon, sessions/mice below one and the leave-one-mouse-out worst p
% as columns. Role: 'main' = 0-3 s, 'secondary' = 0-1 / 1-3 s, 'control' = pre/post (ratio + CI
% only in the paper; their p is kept here but not quoted). The LMM log(r)~1+(1|mouse) rows and the
% trial-level CORROBORATING rows (fig3_olcl_stats, 3_*_lmm / 3_*_sr) are retired: the mouse
% variance is not identifiable with 4 mice and those rows repeated the same claims.
S = load(fullfile(dd,'fig3_ratio_stats.mat')); R3 = S.R3;
panel3 = struct('rmse',{{'3H','RMSE'}},'var',{{'3I','variance'}});
wl = struct('pre','pre (-3-0 s)','early','0-1 s','late','1-3 s','full','0-3 s','post','post');
role3 = struct('pre','control','early','secondary','late','secondary','full','main','post','control');
for mt = {'rmse','var'}
    pn = panel3.(mt{1});
    for w = {'pre','early','late','full','post'}
        r = R3.(mt{1}).(w{1});  id = [pn{1} '_' mt{1} '_' w{1}];
        lbl = sprintf('CL/OL %s ratio, %s (%d/%d sessions <1; %.1f%% lower)',pn{2},wl.(w{1}),r.nBelow1,r.n,r.pctLower);
        addS(id,pn{1},lbl,r.st,'geometric-mean ratio',role3.(w{1}),'variance_mse');
    end
end
% Review M1 (2026-10-20): CL vs the best fixed OL input, same scheme as 3H
% (controller-analysis/ctrl_best_fixed_ol.m -> controller-analysis/data/ctrl_best_fixed_ol.mat).
B = load(fullfile(root,'controller-analysis','data','ctrl_best_fixed_ol.mat'));
for w = {'early','late','full'}
    r = B.ST.(w{1}).cl_best;  id = ['3H_best_' w{1}];
    lbl = sprintf('CL/best-fixed-OL RMSE ratio, %s (%d/%d sessions <1; %.1f%% lower)', ...
                  wl.(w{1}), r.nBelow1, r.n, r.pctLower);
    addS(id,'3H',lbl,r.st,'geometric-mean ratio',role3.(w{1}),'ctrl_best_fixed_ol');
end
% Did feedback move the command toward the best fixed input? (quoted in Results; added 2026-10-27)
qc = quantile(B.T.cStar,[0.25 0.75]);
add('3H_best_cstar','3H','best fixed input / OL input, median (IQR as CI columns)',median(B.T.cStar),'ratio',qc, ...
    'descriptive','','',NaN,NaN,'',height(B.T),'sessions','ctrl_best_fixed_ol',struct('role','descriptive'));
add('3H_best_cmd_rho','3H',sprintf('mean CL / OL command (1-3 s), median %.2f, vs best fixed input across sessions', ...
    median(B.T.uCLrel)),B.SP.rho,'Spearman rho',[NaN NaN],'Spearman rank correlation','rho',B.SP.rho,NaN,B.SP.p,'2', ...
    B.SP.n,'sessions','ctrl_best_fixed_ol',struct('role','secondary'));

% ---------------- Figure 4D : state dependence ---------------------------------------------------
% SESSION RULE (user 2026-10-27): per session, OLS slopes of steady-state RMSE on the within-session
% z-scored state (utils/f4_row2_sess.m); one-sample t across sessions. Stars in the panel = raw p
% (each P, R, A per state is its own question); holm_p = Holm within P+R (8) and A (4), Table 4 column.
% gap and gap trend (P - R) are descriptive ('not interpreted'). The LMM (f4_row2_lme.mat) and the
% motion-only Wilcoxon slopes (f4_motion_slopes.mat) are retired from the table.
S = load(fullfile(dd,'f4_row2_sess.mat')); SS = S.SESS;
lab4 = struct('initdev','initial deviation','motion','motion','delta','relative 2-4 Hz','absdelta','absolute 1-4 Hz');
u = '%dF/F RMSE per SD of state';
for st = fieldnames(lab4)'
    E = SS.(st{1});
    addS(['4D_' st{1} '_gap'],'4D',['OL-CL gap in mean RMSE, ' lab4.(st{1})],E.gap,'%dF/F RMSE','descriptive','f4_row2_quartiles');
    addS(['4D_' st{1} '_pred'],'4D',['predictability (OL slope), ' lab4.(st{1})],E.P,u,'main','f4_row2_quartiles',E.P.holm_p);
    addS(['4D_' st{1} '_reg'],'4D',['regularizability (CL slope), ' lab4.(st{1})],E.R,u,'main','f4_row2_quartiles',E.R.holm_p);
    addS(['4D_' st{1} '_att'],'4D-att',['attenuation (slope of log CL/OL), ' lab4.(st{1})],E.A,'log ratio per SD of state','main','f4_row2_quartiles',E.A.holm_p);
    addS(['4D_' st{1} '_gaptrend'],'4D-disc',['gap trend (OL minus CL slope; not interpreted), ' lab4.(st{1})],E.gap_change,u,'descriptive','f4_row2_quartiles');
end

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
    'stat_name','stat','df','p','sided','n','n_unit','source', ...
    'role','wilcoxon_p','sessions_agree','mice_agree','lomo_worst_p','holm_p'});
out = fullfile(root,'paper-writing','STATS_TABLE.csv');
writetable(T,out);
fprintf('[stats] %d rows -> %s\n', height(T), out);
end
function s = tern(c,a,b), if c, s=a; else, s=b; end, end
