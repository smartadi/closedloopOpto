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

ref = -5;                               % reference %dF/F (project default, = d.ref)
if isempty(which('trialwin')); addpath(genpath(fullfile(here,'..','utils'))); end

% Windows are resolved per session from the array geometry (utils/trialwin),
% replacing the literals c0 = 36 / c1 = 71 / c2 = 141 that used to sit here
% (2026-10-02). Those were right only for dur = 3 AND only for the `dfk` array:
% `motion` is also 176 columns at dur = 3 but its onset is 35 samples later, so
% the same literals applied to it would have been one second wrong with nothing
% to flag it. trialwin looks the onset up by array name and ERRORS rather than
% clamping when a span does not fit.
re  = @(M,ix) sqrt(mean((M(:,ix)-ref).^2, 2));                   % per-trial windowed RMSE
vc  = @(M,ix) mean((M(:,ix)-mean(M(:,ix),1)).^2, 2);             % per-trial variance contribution

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

    % dfk is 35*(dur+2)+1 columns, so this derives dur AND asserts the array is
    % the shape trialwin assumes -- a cache built with a different dur fails
    % loudly here instead of being silently windowed as though it were dur = 3.
    dur = (size(N,2)-1)/35 - 2;
    assert(dur == fix(dur) && dur > 0, 'fig3_olcl_stats:shape', ...
           '%s: ncDfk has %d columns, which is not 35*(dur+2)+1.', D(k).name, size(N,2));
    iFull  = trialwin('dfk', [0 3], dur);     % 36:141 at dur = 3
    iEarly = trialwin('dfk', [0 1], dur);     % 36:71
    iLate  = trialwin('dfk', [1 3], dur);     % 71:141 ...
    iLate(1) = [];                            % ... minus the +1 s sample, so that
                                              % early and late do not share it
                                              % (this reproduces the old c1+1).

    % ---- RMSE metrics ----
    put('rmse_full',  d.er_ncDfk(:),      d.er_wcDfk(:));       % cached [0,3]s RMSE
    put('rmse_early', re(N,iEarly),       re(W,iEarly));        % [0,1]s
    put('rmse_late',  re(N,iLate),        re(W,iLate));         % (1,3]s

    % ---- variance metrics: per-trial contribution (LMM on log), across-trial var (signrank) ----
    putvar('var_stim',  N,W, iFull);
    putvar('var_early', N,W, iEarly);
    putvar('var_late',  N,W, iLate);
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
    function putvar(key, N, W, ix)
        vN = vc(N,ix); vC = vc(W,ix);
        L.(key) = addrows(L.(key), log(vN+eps), 'OL', k, mo);
        L.(key) = addrows(L.(key), log(vC+eps), 'CL', k, mo);
        % companion = classic per-session across-trial variance over the window
        sMed.(key).ol(k) = mean(var(N(:,ix),0,1));
        sMed.(key).cl(k) = mean(var(W(:,ix),0,1));
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
