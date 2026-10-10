function H = imp_state_hboot(R, nBoot, nBin, seed)
% IMP_STATE_HBOOT  Session-level uncertainty for the Fig-2G top/bottom-quartile SD ratio.
%   H = imp_state_hboot(R)                 % R = STV_R from data/fig2g_state_stats.mat
%   H = imp_state_hboot(R, nBoot, nBin, seed)
%
% WHY (review 2026-10-10): imp_state_trialvar.m bootstraps the ratio by resampling TRIALS, which
% treats 1767 trials as independent. They are not: trials share their session (alignment, opsin,
% animal, day). The test beside the ratio is already session-level (LME, df capped at nSess-1 = 3),
% so the interval should be too. This resamples at both levels:
%   1. draw nSess sessions WITH replacement (between-session variability)
%   2. within each drawn session, resample its trials with replacement (within-session noise)
%   3. pool, re-bin by state quantile, recompute SD(top bin)/SD(bottom bin)
% Same statistic as R(k).ratio, so the point estimate is unchanged; only the interval moves.
%
% Also returns the per-session ratios (each session binned on its own) and a t-interval on the
% mean log ratio across sessions (df = nSess-1) -- the parametric session-level counterpart.
%
% CAVEAT: with 4 sessions there are only 35 distinct session multisets, so the bootstrap
% distribution is lumpy and percentile intervals from few clusters tend to UNDER-cover. Read the
% hierarchical CI together with the per-session ratios, not instead of them.
if nargin < 2 || isempty(nBoot), nBoot = 10000; end
if nargin < 3 || isempty(nBin),  nBin  = 4;     end
if nargin < 4 || isempty(seed),  seed  = 1;     end
H = struct('name',{},'ratio',{},'ciTrial',{},'ciHier',{},'perSess',{},'gmSess',{},'ciSessT',{}, ...
           'nBelow1',{},'nSess',{},'boot',{});
for k = 1:numel(R)
    rng(seed);   % reseed per state: each CI is reproducible regardless of which states run
    x = R(k).x(:); y = R(k).y(:); s = R(k).sess(:);
    ok = isfinite(x) & isfinite(y);  x = x(ok); y = y(ok); s = s(ok);
    uS = unique(s); nS = numel(uS);
    idx = arrayfun(@(u) find(s==u), uS, 'UniformOutput', false);

    % per-session ratio, each session binned on its own state distribution
    rs = nan(nS,1);
    for i = 1:nS
        rs(i) = local_ratio(x(idx{i}), y(idx{i}), nBin);
    end

    % hierarchical bootstrap
    bs = nan(nBoot,1);
    for b = 1:nBoot
        pick = randi(nS, nS, 1);
        rows = cell(nS,1);
        for j = 1:nS
            ii = idx{pick(j)};
            rows{j} = ii(randi(numel(ii), numel(ii), 1));
        end
        rr = vertcat(rows{:});
        bs(b) = local_ratio(x(rr), y(rr), nBin);
    end

    lr = log(rs);  q = tinv(0.975, nS-1);
    H(k).name    = R(k).name;
    H(k).ratio   = local_ratio(x, y, nBin);          % reproduces R(k).ratio
    H(k).ciTrial = R(k).ci;
    H(k).ciHier  = quantile(bs, [0.025 0.975]);
    H(k).perSess = rs.';
    H(k).gmSess  = exp(mean(lr));
    H(k).ciSessT = exp(mean(lr) + [-1 1]*q*std(lr)/sqrt(nS));
    H(k).nBelow1 = nnz(rs < 1);
    H(k).nSess   = nS;
    H(k).boot    = bs;
    fprintf(['%-20s ratio %.2f | trial CI [%.2f %.2f] | hier CI [%.2f %.2f] | ' ...
             'per-session %s (%d/%d <1) | sess GM %.2f, t(%d) CI [%.2f %.2f]\n'], ...
        R(k).name, H(k).ratio, H(k).ciTrial, H(k).ciHier, mat2str(rs.',2), H(k).nBelow1, nS, ...
        H(k).gmSess, nS-1, H(k).ciSessT);
end
end

function r = local_ratio(x, y, nb)
% SD of y in the top state bin over SD in the bottom bin; bins = quantiles of x (as local_qbin)
e = quantile(x, linspace(0,1,nb+1));
lo = y(x < e(2));  hi = y(x >= e(end-1));   % same edges as histcounts in local_qbin
r = std(hi,'omitnan') / max(std(lo,'omitnan'), eps);
end
