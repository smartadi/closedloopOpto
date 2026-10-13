function S = stv_sess_slopes(dv, state, sess, minN)
% STV_SESS_SLOPES  Session-level inference for Fig 2G: one slope per session, t-test across sessions.
%   S = stv_sess_slopes(dv, state, sess)        % minN = 20 trials per session
%
% Within each session, OLS slope of dv on state, with state z-scored WITHIN that session (so a
% slope is "dv units per within-session SD of state"). The slopes are then the data: a
% one-sample t-test across sessions (df = nSess-1). This is the summary-statistic approach to
% a random-slope model. With 4 sessions it replaces the intercept-only LMM
% dv ~ state + (1|sess), whose slope SE is trial-based and which the paper's own simulation
% (Methods, false-positive rate 0.115-0.645 without a random slope) shows is anti-conservative.
% User 2026-10-12: per-session slopes are the 2G inference.
%
% Returns: b (mean slope), t, df, p (two-sided), ci (95% t), slopes (per session),
% nAgree (sessions whose slope has the sign of the mean), nSess.
if nargin < 4 || isempty(minN), minN = 20; end
dv = dv(:); state = state(:); sess = sess(:);
ok = isfinite(dv) & isfinite(state) & isfinite(sess);
dv = dv(ok); state = state(ok); sess = sess(ok);
us = unique(sess);  sl = nan(numel(us),1);
for j = 1:numel(us)
    m = sess == us(j);
    if nnz(m) < minN || std(state(m)) == 0, continue; end
    xz = (state(m) - mean(state(m))) / std(state(m));
    c  = [ones(nnz(m),1) xz] \ dv(m);
    sl(j) = c(2);
end
sl = sl(isfinite(sl));  n = numel(sl);
S = struct('b',NaN,'t',NaN,'df',n-1,'p',NaN,'ci',[NaN NaN],'slopes',sl.','nAgree',NaN,'nSess',n);
if n < 2, return; end
[~, p, ci, st] = ttest(sl);
S.b = mean(sl);  S.t = st.tstat;  S.p = p;  S.ci = ci(:).';
S.nAgree = nnz(sign(sl) == sign(S.b));
end
