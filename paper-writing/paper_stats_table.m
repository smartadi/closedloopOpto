function T = paper_stats_table()
% PAPER_STATS_TABLE  One row per statistical claim in results.tex -> STATS_TABLE.csv.
%   T = paper_stats_table();
% The manuscript quotes THIS table (NUMBERS.md rule: the paper quotes a file, the file quotes
% a run). It only LOADS the saved outputs of the producers; it recomputes nothing, so a stale
% number here means a producer was not re-run. Producers, in the order to run them:
%   fig3_olcl_stats             -> data/fig3_olcl_lmm.mat        (Fig 3 LMMs + signed-rank)
%   variance_mse.m              -> data/fig3h_ratio_signrank.mat  (Fig 3H window ratios)
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
for t = {'MOT','DPr','DPa'}
    r = R(strcmp({R.tag},t{1}));
    add(['2G_' t{1} '_ratio'],'2G',['Q4/Q1 SD ratio, ' lab.(t{1})],r.ratio,'ratio',r.ci, ...
        'bootstrap','','',NaN,NaN,'',r.n,'trials','imp_state_trialvar');
    add(['2G_' t{1} '_lmm'],'2G',sprintf('|dev| ~ state, %s (%d/%d sessions agree)',lab.(t{1}),r.nSessAgree,r.nSess), ...
        r.bLME,'SD per unit state',r.ciLME,'LMM |dev|~state+(1|sess)','t',r.tLME,r.dfLME,r.pLME,'2', ...
        r.nSess,'sessions','imp_state_trialvar');
    add(['2G_' t{1} '_rho'],'2G',['Spearman |dev| vs state (pooled trials), ' lab.(t{1})],r.rho,'rho',[NaN NaN], ...
        'Spearman','','',NaN,r.p,'2',r.n,'trials','imp_state_trialvar');
    add(['2G_' t{1} '_ctrl'],'2G',['stimulus-free control, ' lab.(t{1})],r.rhoP,'rho',[NaN NaN], ...
        'Spearman','','',NaN,r.pP,'2',r.n,'trials','imp_state_trialvar');
end

% ---------------- Figure 3 : OL vs CL ---------------------------------------------------------
S = load(fullfile(dd,'fig3_olcl_lmm.mat')); G = S.G3;
lab3 = struct('rmse_full','RMSE 0-3 s','rmse_early','RMSE 0-1 s','rmse_late','RMSE 1-3 s', ...
              'var_stim','log variance 0-3 s','var_early','log variance 0-1 s','var_late','log variance 1-3 s');
for m = fieldnames(lab3)'
    g = G.(m{1}); isv = startsWith(m{1},'var');
    add(['3_' m{1} '_lmm'],'3',['CL-OL gap, ' lab3.(m{1})],g.lmm_gap,tern(isv,'log units','%dF/F'),g.lmm_ci, ...
        'LMM y~cond+(1+cond|sess)+(1|mouse)','t',g.lmm_t,g.lmm_df,g.lmm_p,'2',g.nSess,'sessions','fig3_olcl_stats');
    add(['3_' m{1} '_sr'],'3',sprintf('per-session signed-rank, %s (%d/%d sessions CL<OL)',lab3.(m{1}),g.nAgree,g.nSess), ...
        g.medRatio,'median OL/CL',[NaN NaN],'Wilcoxon signed-rank','V',g.sr_V,NaN,g.sr_p,'2',g.nSess,'sessions','fig3_olcl_stats');
end
S = load(fullfile(dd,'fig3h_ratio_signrank.mat')); F = S.F3H;
for w = {'pre','early','late','post'}
    f = F.(w{1});
    add(['3H_' w{1}],'3H',['OL/CL variance ratio, window ' w{1}],f.medRatio,'median ratio',[NaN NaN], ...
        'Wilcoxon signed-rank','V',f.V,NaN,f.p,'2',f.n,'sessions','variance_mse');
end

% ---------------- Figure 4D : state quartiles ---------------------------------------------------
S = load(fullfile(dd,'f4_row2_lme.mat')); L = S.LME;
lab4 = struct('initdev','initial deviation','motion','motion','delta','relative 2-4 Hz','absdelta','absolute 1-4 Hz');
for st = fieldnames(lab4)'
    E = L.(st{1}); r = E.Rf; mdl = 'LMM y~cond*state+(1+cond|sess)+(1|mouse)';
    u = '%dF/F RMSE per SD of state';
    add(['4D_' st{1} '_gap'],'4D',['CL-OL gap at mean state, ' lab4.(st{1})],r.gap,'%dF/F RMSE',r.gapCI, ...
        mdl,'t',r.gapT,r.gapDF,r.gapP,'2',E.nSes,'sessions','f4_row2_quartiles');
    add(['4D_' st{1} '_pred'],'4D',['predictability (OL slope), ' lab4.(st{1})],r.slope,u,r.slopeCI, ...
        mdl,'t',r.slopeT,r.slopeDF,r.slopeP,'2',E.nSes,'sessions','f4_row2_quartiles');
    add(['4D_' st{1} '_reg'],'4D',['regularizability (CL slope), ' lab4.(st{1})],r.reg,u,r.regCI, ...
        [mdl ', CL reference'],'t',r.regT,r.regDF,r.regP,'2',E.nSes,'sessions','f4_row2_quartiles');
    add(['4D_' st{1} '_att'],'4D-att',['attenuation (slope of log CL/OL), ' lab4.(st{1})],r.att,'log ratio per SD of state',r.attCI, ...
        'LMM log(y)~cond*state+(1+cond|sess)+(1|mouse)','t',r.attT,r.attDF,r.attP,'2',E.nSes,'sessions','f4_row2_quartiles');
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

T = cell2table(rows,'VariableNames',{'id','figure','claim','effect','unit','ci_lo','ci_hi','test', ...
    'stat_name','stat','df','p','sided','n','n_unit','source'});
out = fullfile(root,'paper-writing','STATS_TABLE.csv');
writetable(T,out);
fprintf('[stats] %d rows -> %s\n', height(T), out);
end
function s = tern(c,a,b), if c, s=a; else, s=b; end, end
