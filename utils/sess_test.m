function S = sess_test(v, mouse, uselog)
% SESS_TEST  The paper's one session-level test (STATS_AUDIT §7, user 2026-10-27).
%
%   S = sess_test(v, mouse, uselog)
%
% v      : one number per session (n x 1)
% mouse  : the mouse of each session (n x 1 cellstr / string)
% uselog : true for ratios -- test log(v) against 0, report the geometric mean
%
% MATLAB twin of stats_v2/tests.py sess_test (same definitions, so the two pipelines can be
% checked against each other):
%   effect     mean (or geometric mean), t-based 95% CI on df = n-1
%   MAIN       one-sample t-test against 0, two-sided           -> S.p
%   backup     exact Wilcoxon signed-rank, two-sided            -> S.w_p
%   counts     k of k_n sessions share the sign of the mean
%   mice       leave-one-mouse-out t p (worst kept), and one mean per mouse (k/4, t p across mice)
% A mixed model log r ~ 1 + (1|mouse) is NOT used: with 4 mice (two with one session) the mouse
% variance is not identifiable and its Satterthwaite df collapsed to 0-1 (RESEARCH 2026-10-15).
if nargin < 3, uselog = false; end
v = double(v(:));  mouse = cellstr(string(mouse(:)));
ok = isfinite(v);  if uselog, ok = ok & v > 0; end
x = v(ok);  if uselog, x = log(x); end
m = mouse(ok);  n = numel(x);

S.n = n;  S.mean = mean(x);  df = n - 1;  se = std(x) / sqrt(n);
q = tinv(0.975, df);  lo = S.mean - q*se;  hi = S.mean + q*se;
S.t = S.mean / se;  S.df = df;  S.p = 2 * tcdf(-abs(S.t), df);
if uselog, back = @exp; else, back = @(z) z; end
S.effect = back(S.mean);  S.ci = [back(lo) back(hi)];

S.w_p = signrank(x, 0, 'method', 'exact');                 % two-sided, exact
sg = sign(S.mean);
S.k = sum(sign(x) == sg);  S.k_n = sum(x ~= 0);
S.sign = 'pos';  if sg < 0, S.sign = 'neg'; end

um = unique(m, 'stable');
S.lomo_mouse = um;  S.lomo_p = nan(numel(um), 1);
for i = 1:numel(um), S.lomo_p(i) = tp(x(~strcmp(m, um{i}))); end
[S.lomo_worst_p, iw] = max(S.lomo_p);
S.lomo_worst_mouse = um{iw};

mm = cellfun(@(u) mean(x(strcmp(m, u))), um);
S.mouse_means = back(mm);  S.mouse_k = sum(sign(mm) == sg);  S.mouse_n = numel(um);
S.mouse_p = tp(mm);
S.values = v(ok);  S.mouse = m;  S.log = uselog;
end

function p = tp(x)
% two-sided one-sample t p; NaN when it cannot be computed
if numel(x) < 2 || std(x) == 0, p = NaN; return; end
[~, p] = ttest(x);
end
