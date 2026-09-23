function G3 = fig3_olcl_stats(verbose)
% FIG3_OLCL_STATS  Single source of the Fig-3 OL-vs-CL statistics.
% Computes, for every OL-vs-CL claim in Figure 3, the session-aware LMM
% (PRIMARY, Nick-approved / Fig-4-matching: y ~ cond + (1+cond|sess) + (1|mouse),
% via utils/cl_olcl_lmm.m) alongside the per-session Wilcoxon signed-rank (COMPANION).
% Reads ONLY the small `data` struct from each controller cache (no SVD reload),
% prints a side-by-side table, and SAVES data/fig3_olcl_lmm.mat (struct G3) so the
% panel scripts (variance_mse.m stars, pooled_new_mice.m title) annotate from ONE place.
%
%   G3 = fig3_olcl_stats;            % compute, print, save
%   G3 = fig3_olcl_stats(false);     % quiet
%
% Metrics (all windows relative to stim onset; ref = -5 %dF/F):
%   rmse_full  : per-trial tracking RMSE over [0,3]s   (panels E/G/H)
%   rmse_early : per-trial tracking RMSE over [0,1]s   (panel J, settling)
%   rmse_late  : per-trial tracking RMSE over [1,3]s   (panel J, steady-state)
%   var_stim   : per-trial variance-contribution over [0,3]s  (panels D/F/I)
%   var_early  : per-trial variance-contribution over [0,1]s  (panel I)
%   var_late   : per-trial variance-contribution over [1,3]s  (panel I)
% Variance has no per-trial replicate, so its LMM response is the per-trial windowed
% squared deviation from the trial-mean trace, on a log scale (a mixed dispersion test);
% its signed-rank companion is the classic per-session across-trial variance.

if nargin < 1 || isempty(verbose), verbose = true; end
here    = fileparts(mfilename('fullpath'));
dataDir = fullfile(here, '..', 'data');
D = dir(fullfile(dataDir,'*ctrl*.mat')); nS = numel(D);

c0 = 36; c1 = 71; c2 = 141; ref = -5;   % onset / +1s / +3s cols in ncDfk; reference %dF/F
re  = @(M,a,b) sqrt(mean((M(:,a:b)-ref).^2, 2));                 % per-trial windowed RMSE
vc  = @(M,a,b) mean((M(:,a:b)-mean(M(:,a:b),1)).^2, 2);          % per-trial variance contribution

% per-trial long records + per-session companions
metrics = {'rmse_full','rmse_early','rmse_late','var_stim','var_early','var_late'};
L = struct(); for m=metrics, L.(m{1}) = initrec(); end
sMed = struct();                                    % per-session values for signrank
for m=metrics, sMed.(m{1}) = struct('ol',nan(nS,1),'cl',nan(nS,1)); end
mouseList = cell(nS,1);

for k = 1:nS
    S = load(fullfile(dataDir,D(k).name),'data'); d = S.data;
    mo = regexp(D(k).name,'AL_\d+','match','once'); mouseList{k} = mo;
    N = d.ncDfk; W = d.wcDfk;

    % ---- RMSE metrics ----
    put('rmse_full',  d.er_ncDfk(:),      d.er_wcDfk(:));       % cached [0,3]s RMSE
    put('rmse_early', re(N,c0,c1),        re(W,c0,c1));         % [0,1]s
    put('rmse_late',  re(N,c1+1,c2),      re(W,c1+1,c2));       % [1,3]s

    % ---- variance metrics: per-trial contribution (LMM on log), across-trial var (signrank) ----
    putvar('var_stim',  N,W, c0,   c2);
    putvar('var_early', N,W, c0,   c1);
    putvar('var_late',  N,W, c1+1, c2);
end

% ---- fit LMM (primary) + signrank (companion) per metric ----
for m = metrics
    key = m{1};
    R = cl_olcl_lmm(L.(key).y, L.(key).cond, L.(key).sess, L.(key).mouse);
    ol = sMed.(key).ol; cl = sMed.(key).cl;
    sr = signrank(ol, cl);
    G3.(key) = struct('lmm_p',R.gapP, 'lmm_gap',R.gap, 'lmm_ci',R.gapCI, ...
        'sr_p',sr, 'mouseSD',R.mouseSD, 'sessSD',R.sessSD, 'randslope',R.randslope, ...
        'nAgree',sum(cl<ol), 'nSess',nS, 'n',R.n);
end

G3.meta = struct('date',datestr(now,'yyyy-mm-dd'), ...
    'model','y ~ cond + (1+cond|sess) + (1|mouse)', ...
    'nSess',nS, 'nMouse',numel(unique(mouseList)), ...
    'mouseCounts',{tabulate_mice(mouseList)}, ...
    'note','LMM primary (Nick-approved, Fig-4-matching); signrank per-session companion.');

outMat = fullfile(dataDir,'fig3_olcl_lmm.mat');
save(outMat,'G3');

if verbose
    fprintf('\n==== Fig-3 OL-vs-CL statistics (LMM primary / signrank companion) ====\n');
    fprintf('%d sessions / %d mice   model: %s\n', nS, G3.meta.nMouse, G3.meta.model);
    fprintf('%-12s %11s %12s %20s %11s %8s %6s %6s\n', ...
        'metric','LMM p','signrank p','LMM gap [95%CI]','mouseSD','sessSD','rs','agree');
    for m = metrics
        g = G3.(m{1});
        fprintf('%-12s %11.2g %12.2g   %+6.3f [%+.2f %+.2f] %11.2g %8.3f %6d %5d/%d\n', ...
            m{1}, g.lmm_p, g.sr_p, g.lmm_gap, g.lmm_ci(1), g.lmm_ci(2), ...
            g.mouseSD, g.sessSD, g.randslope, g.nAgree, g.nSess);
    end
    fprintf('gap = cond_CL (CL-OL): <0 => CL lower/better.  mouseSD~0 => not mouse-driven.\n');
    fprintf('saved -> %s\n', outMat);
end

    % ---- nested helpers (share L / sMed / k) ----
    function put(key, ol, cl)
        L.(key) = addrows(L.(key), ol, 'OL', k, mo);
        L.(key) = addrows(L.(key), cl, 'CL', k, mo);
        sMed.(key).ol(k) = median(ol); sMed.(key).cl(k) = median(cl);
    end
    function putvar(key, N, W, a, b)
        vN = vc(N,a,b); vC = vc(W,a,b);
        L.(key) = addrows(L.(key), log(vN+eps), 'OL', k, mo);
        L.(key) = addrows(L.(key), log(vC+eps), 'CL', k, mo);
        % companion = classic per-session across-trial variance over the window
        sMed.(key).ol(k) = mean(var(N(:,a:b),0,1));
        sMed.(key).cl(k) = mean(var(W(:,a:b),0,1));
    end
end

function T = initrec(), T = struct('y',[],'cond',{{}},'sess',[],'mouse',{{}}); end

function T = addrows(T, yv, cond, s, mo)
    yv = yv(:); n = numel(yv);
    T.y     = [T.y; yv];
    T.cond  = [T.cond; repmat({cond}, n, 1)];
    T.sess  = [T.sess; repmat(s, n, 1)];
    T.mouse = [T.mouse; repmat({mo}, n, 1)];
end

function C = tabulate_mice(ml)
    u = unique(ml); C = cell(numel(u),2);
    for i=1:numel(u), C{i,1}=u{i}; C{i,2}=sum(strcmp(ml,u{i})); end
end
