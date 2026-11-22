% controller-analysis/f4_reject_lasso.m
% Fig 4H with the lasso predictor, step 2 (research-hub #100): the 4H statistic from the lasso
% disturbance, next to ridge refitted on today's data and the saved paper run (ridge, Stage-2 caches).
%
% Math approved by Aditya 2026-11-21: "Approve" (lasso becomes the contra->ipsi predictor for Fig 4F-4H;
% D, RR and the 4H statistic as defined; RESEARCH L-2026-11-21-b), "Yes, compute 4H", and "approve" (the
% method block for this script; L-2026-11-21-c).
% No new formula: everything below is f4_cl_reject_lmm.m applied to the per-trial RR of
% ctrl_sparse_kernel_cl.m (C.trial.rr, column 1 ridge today, column 2 lasso; same CL trials as
% imp_build_session.m, checked there on AL_0033_0415_e2).
%   RR        per CL trial sum over (1,3] s of (A - r)^2 / sum D^2; trials with finite RR > 0
%   gate      biasFrac <= 1/3 (A only): 11 of 13 sessions
%   THE test  per session the mean log RR; two-sided one-sample t-test across sessions (utils/sess_test,
%             uselog), geometric mean with a t CI on nSess - 1 df (session rule, 2026-10-27)
%   reference session mixed model log RR ~ 1 + (1|sess), REML, Satterthwaite df capped at nSess - 1
%             (utils/lmm_cluster_df), one-sided p for RR < 1, as f4_cl_reject_lmm.m
%   all 13    the same session test without the gate (sensitivity, as STall)
% The saved paper run (data/f4_cl_reject_lmm.mat, 2026-10-10) has no session test; it is computed here
% from its saved trial table T with the same function.
% OUT controller-analysis/data/f4_cl_reject_lmm_lasso.mat (same variable names as f4_cl_reject_lmm.mat:
%     T, ST, sessTab, TA, STall, sessTabAll, sessM, lmeS), data/f4_reject_lasso_sessions.csv
root = 'C:\Users\aditya\Documents\projects\brain_paper';
dd   = fullfile(root, 'controller-analysis', 'data');
addpath(fullfile(root, 'utils'));
Ls = dir(fullfile(dd, 'ctrl_sparse_kernel_cl_AL_*.mat'));
CC = cell(1, numel(Ls));
for i = 1:numel(Ls), S = load(fullfile(dd, Ls(i).name)); CC{i} = S.C; end
CC = [CC{:}];
assert(all(arrayfun(@(c) isfield(c, 'trial'), CC)), 'rerun ctrl_sparse_kernel_cl.m (no per-trial arrays)');

nm = {'ridge today', 'lasso'};  R = struct();
for m = 1:2
    [T, TA] = local_tables(CC, m);
    [ST, sessTab] = local_sess_logrr(T);
    [STall, sessTabAll] = local_sess_logrr(TA);
    [sessM, lmeS] = local_sess_lmm(T);
    R(m).name = nm{m};  R(m).T = T;  R(m).TA = TA;  R(m).ST = ST;  R(m).sessTab = sessTab;
    R(m).STall = STall;  R(m).sessTabAll = sessTabAll;  R(m).sessM = sessM;  R(m).lmeS = lmeS;
end
P = load(fullfile(dd, 'f4_cl_reject_lmm.mat'));                    % paper run, ridge from the Stage-2 caches
[STp, sessTabP] = local_sess_logrr(P.T);
R(3).name = 'paper (ridge cache)';  R(3).T = P.T;  R(3).ST = STp;  R(3).sessTab = sessTabP;  R(3).sessM = P.sessM;

% ---- per-session geometric-mean RR, gated sessions ----
u = R(2).sessTab.sess;
fprintf('\n[4H-lasso] session geometric-mean RR (trials), %d gated sessions\n', numel(u));
fprintf('  %-17s %-9s %18s %18s %18s\n', 'session', 'label', R(3).name, R(1).name, R(2).name);
rows = {};
for i = 1:numel(u)
    g = nan(1, 3);  n = nan(1, 3);
    for m = 1:3
        j = find(strcmp(cellstr(R(m).sessTab.sess), u{i}));
        if ~isempty(j), g(m) = R(m).sessTab.gmRR(j);  n(m) = R(m).sessTab.nTr(j); end
    end
    lab = paper_session_label(u{i});
    fprintf('  %-17s %-9s %12.2f (%3d) %12.2f (%3d) %12.2f (%3d)\n', u{i}, lab, g(3), n(3), g(1), n(1), g(2), n(2));
    rows(end+1, :) = {u{i}, lab, g(3), n(3), g(1), n(1), g(2), n(2)}; %#ok<SAGROW>
end
writetable(cell2table(rows, 'VariableNames', {'session', 'label', 'gmRR_paper', 'nTr_paper', 'gmRR_ridge_today', ...
    'nTr_ridge_today', 'gmRR_lasso', 'nTr_lasso'}), fullfile(dd, 'f4_reject_lasso_sessions.csv'));

% ---- the 4H statistic ----
for m = [3 1 2]
    s = R(m).ST;
    fprintf(['[4H-lasso] %-20s session test (gated): GM RR %.2f [%.2f, %.2f], t(%d) = %.2f, two-sided p = %.3g, ' ...
             'Wilcoxon p = %.3g, %d/%d sessions < 1, LOMO worst p = %.3g (%s), mice %d/%d\n'], R(m).name, s.effect, s.ci, ...
        s.df, s.t, s.p, s.w_p, s.k, s.n, s.lomo_worst_p, s.lomo_worst_mouse, s.mouse_k, s.mouse_n);
    q = R(m).sessM;
    fprintf('[4H-lasso] %-20s session mixed model (reference): GM RR %.2f [%.2f, %.2f], t(%.1f) = %.2f, one-sided p = %.3g\n', ...
        R(m).name, exp(q.est), exp(q.ci), q.df, q.t, q.p1);
    if m < 3
        a = R(m).STall;
        fprintf('[4H-lasso] %-20s all %d sessions: GM RR %.2f [%.2f, %.2f], t(%d) = %.2f, two-sided p = %.3g, %d/%d < 1\n', ...
            R(m).name, a.n, a.effect, a.ci, a.df, a.t, a.p, a.k, a.n);
    end
end

% ---- save the lasso result under the f4_cl_reject_lmm.mat names (for f4_cl_reject_panel.m) ----
T = R(2).T;  ST = R(2).ST;  sessTab = R(2).sessTab;  TA = R(2).TA;  STall = R(2).STall;
sessTabAll = R(2).sessTabAll;  sessM = R(2).sessM;  lmeS = R(2).lmeS;  %#ok<NASGU>
save(fullfile(dd, 'f4_cl_reject_lmm_lasso.mat'), 'T', 'ST', 'sessTab', 'TA', 'STall', 'sessTabAll', 'sessM', 'lmeS');
fprintf('[4H-lasso] saved data/f4_cl_reject_lmm_lasso.mat and data/f4_reject_lasso_sessions.csv\n');

% ======================================================================================
function [T, TA] = local_tables(CC, m)     % trial tables, gated (T) and all sessions (TA)
lr = {};  ss = {};  mo = {};  g = {};
for i = 1:numel(CC)
    C = CC(i);  rr = C.trial.rr(:, m);  ok = isfinite(rr) & rr > 0;
    lr{i} = log(rr(ok));  ss{i} = repmat({C.session}, nnz(ok), 1);  mo{i} = repmat({C.session(1:7)}, nnz(ok), 1);
    g{i} = repmat(logical(C.in4H), nnz(ok), 1);
end
lr = vertcat(lr{:});  ss = vertcat(ss{:});  mo = vertcat(mo{:});  g = vertcat(g{:});
TA = table(lr, categorical(ss), categorical(mo), 'VariableNames', {'logRR', 'sess', 'mouse'});
T = TA(g, :);  T.sess = removecats(T.sess);  T.mouse = removecats(T.mouse);
end

function [ST, tab] = local_sess_logrr(T)   % f4_cl_reject_lmm.m sess_logrr, unchanged
[us, ~, gi] = unique(T.sess, 'stable');
ml = accumarray(gi, T.logRR, [], @mean);
mo = arrayfun(@(i) char(T.mouse(find(gi == i, 1))), (1:numel(us))', 'UniformOutput', false);
tab = table(cellstr(us), mo, exp(ml), accumarray(gi, 1), 'VariableNames', {'sess', 'mouse', 'gmRR', 'nTr'});
ST = sess_test(exp(ml), mo, true);
end

function [sessM, lmeS] = local_sess_lmm(T)  % f4_cl_reject_lmm.m session-clustered model, unchanged
nSess = numel(unique(T.sess));
lmeS = fitlme(T, 'logRR ~ 1 + (1|sess)', 'FitMethod', 'REML');
[~, ~, CS] = fixedEffects(lmeS, 'DFMethod', 'Satterthwaite');  CS = lmm_cluster_df(dataset2table_safe(CS), nSess);
sessM = struct('est', CS.Estimate(1), 'se', CS.SE(1), 't', CS.tStat(1), 'df', CS.DFc(1), ...
    'p1', tcdf(CS.tStat(1), CS.DFc(1)), 'ci', [CS.LowerC(1) CS.UpperC(1)]);
end
