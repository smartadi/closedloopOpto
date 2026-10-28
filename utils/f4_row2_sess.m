function [R, per] = f4_row2_sess(T)
% F4_ROW2_SESS  Session-level Fig 4D test (user 2026-10-27; replaces f4_row2_fit as the star).
%
%   [R, per] = f4_row2_sess(T)
%
% T is one state's pooled table from f4_row2_pool (vars y = steady-state RMSE 1-3 s, cond{OL,CL},
% x = state, sess, mouse). Within each session the state is z-scored over that session's trials
% (OL and CL pooled, SD with n-1), so every slope is "per within-session SD". Then per session:
%   P = OLS slope of y on z, OL trials                       (PREDICTABILITY; >0 = OL error rises)
%   R = OLS slope of y on z, CL trials                       (REGULARIZABILITY; ~0 = loop holds)
%   A = slope(log y, CL) - slope(log y, OL)                  (ATTENUATION; slope of log CL/OL)
%   gap = mean y OL - mean y CL;  gap_change = P - R         (descriptive)
% and each quantity is tested across sessions with utils/sess_test (one-sample t, two-sided, df =
% n-1; exact Wilcoxon backup; leave-one-mouse-out). Same definitions as stats_v2/run_all.py, so
% the two pipelines can be checked against each other.
% R.<q> = sess_test struct for q in P, R, A, gap, gap_change; R.A_pct = 100(e^A - 1) %/SD.
% per   = one row per session.
us = unique(T.sess, 'stable');  n = numel(us);
per = table('Size', [n 10], 'VariableTypes', [{'double','string'}, repmat({'double'}, 1, 8)], ...
    'VariableNames', {'sess','mouse','nOL','nCL','P','R','logOL','logCL','A','gap'});
for i = 1:n
    m = T.sess == us(i);  y = T.y(m);  x = T.x(m);  ol = T.cond(m) == 'OL';  cl = ~ol;
    z = (x - mean(x)) / std(x);
    per(i, :) = {us(i), string(T.mouse(find(m, 1))), nnz(ol), nnz(cl), ...
        olsb(z(ol), y(ol)), olsb(z(cl), y(cl)), olsb(z(ol), log(y(ol))), olsb(z(cl), log(y(cl))), ...
        NaN, mean(y(ol)) - mean(y(cl))};
end
per.A = per.logCL - per.logOL;
per.gap_change = per.P - per.R;
R = struct();
for q = {'P', 'R', 'A', 'gap', 'gap_change'}
    R.(q{1}) = sess_test(per.(q{1}), per.mouse, false);
end
R.A_pct = 100 * (exp(R.A.effect) - 1);  R.A_pctCI = 100 * (exp(R.A.ci) - 1);
R.n = n;  R.nMouse = numel(unique(per.mouse));
end

function b = olsb(z, y)
% OLS slope with intercept
z = z(:) - mean(z);  b = sum(z .* (y(:) - mean(y))) / sum(z.^2);
end
