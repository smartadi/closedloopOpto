% controller-analysis/ctrl_sparse_kernel.m
% Fig 4F reviewer check (research-hub #100): does a SPARSE (lasso) contra->ipsi predictor put its
% weights at the homolog of the stim site? Runs NEXT TO the paper's ridge model; ridge stays the
% model in ctrl_pred_tag.m and in every paper number.
%
% Math approved by Aditya 2026-11-19: "Approve" (method block for the 13-session lasso run, after
% the one-session trial of lasso and elastic net he asked for and "Approve lasso"; research-hub #100;
% RESEARCH L-2026-11-19-f).
%
% For each session with a ridge Stage-2 cache (13), on the SAME spontaneous frames, temporal split,
% train z-scoring and target as that cache (reproduced exactly first, CHECK 1):
%   z_t     the p contra grid pixels at frame t, z-scored with the train mean and SD
%   e_t     y_t - mean(y_train), y = data.dFk (detrended or not, as that cache was fitted)
%   lasso   b(lambda) = argmin_b (1/2n) sum_train (e_t - b0 - z_t'b)^2 + lambda*||b||_1,  n = train frames
%           (Tibshirani 1996, doi 10.1111/j.2517-6161.1996.tb02080.x; coordinate descent as in Friedman,
%           Hastie and Tibshirani 2010, doi 10.18637/jss.v033.i01; MATLAB lasso, Standardize off since
%           z is already standardized)
%   path    50 lambdas, log spaced, from lambda_max (all weights 0) down to 1e-3*lambda_max
%   lambda  the largest lambda whose test R^2 is within 0.02 of the path's best: the ridge rule of
%           utils/ctrl_ridge_path.m. Test R^2 = 1 - SSE_test / SS_test about the test mean.
%   homolog m = the stim site reflected across the drawn midline (ctrl_brain_mask)
%   d_j     distance of grid pixel j from m, in grid steps
%   D       sum_j |b_j| d_j / sum_j |b_j|;  D_grid = mean_j d_j.  D/D_grid < 1: the weight sits nearer
%           the homolog than the grid as a whole.  share3 = share of sum |b_j| with d_j <= 3 steps.
%   stable  the chosen lambda (same absolute value) refitted on 5 consecutive blocks of the train
%           frames; pixels kept in >= 4 of 5 (after Meinshausen and Buhlmann 2010,
%           doi 10.1111/j.1467-9868.2010.00740.x, simplified: no error bound claimed)
%   leak    100 * mean Global / mean Actual over the sustained OL stim window, Global built from the
%           lasso weights exactly as ctrl_ols_ol_stimblind.m [CTRL-OL-DEPLOY] builds it from ridge
%   curves  test R^2 and D/D_grid against the number of nonzero weights, along the whole path
% Descriptive only: no test across sessions (none approved).
%
% CHECK 1  per session, the rebuilt data must reproduce the cached ridge weights, test R^2 and leak.
%          The 13 caches were not all built the same way (10 predate the 2026-09-05 fit-target
%          detrend; two AL_0039 sessions may predate the uncorrected-V list), so the V and target
%          variants are tried in turn and the one that reproduces the cache is used and reported.
%          A session that no variant reproduces gets a FRESH RIDGE REFIT on today's data instead
%          (Aditya 2026-11-19: "Fresh ridge refit"): today's ctrl_ols_ol_stimblind.m settings (V by its
%          uncorrected list, canonical dFk, fit-target detrend on), the Stage-1 frames clamped to
%          today's V by the pipeline's own small-shortfall rule (at most 10 frames), ridge lambda by the
%          ctrl_ridge_path.m rule, OL onsets and Actual rebuilt as the pipeline builds them. Ridge and
%          lasso are then compared on exactly the same data; the old cache is not used for that session.
% CHECK 3  on every reproduced session, the fresh-refit machinery must give the cached weights (lambda
%          rule) and, on the cached onsets, the cached Actual. Today's onsets are also rebuilt and the
%          number that differ from the cache is reported (the session data changed after some caches).
% CHECK 2  per session, a planted target (2 real pixels + noise) must come back as the two largest
%          lasso weights.
%
% Needs load_sessions.m (mouse, fields). Reads the SVD from the server (read-only).
% Set SK_TAGS (cellstr) in the base workspace to run a subset; the summary always covers every
% per-session result on disk.
% OUT controller-analysis/data/ctrl_sparse_kernel_<tag>.mat, data/ctrl_sparse_kernel_summary.csv,
%     controller-analysis/_preview/ctrl_sparse_kernel_summary.png, _preview/ctrl_sparse_kernel_maps.png
assert(exist('mouse','var') && exist('fields','var'), 'run controller-analysis/load_sessions.m first');
root = 'C:\Users\aditya\Documents\projects\brain_paper';
dd   = fullfile(root, 'controller-analysis', 'data');
outview = fullfile(root, 'controller-analysis', '_preview');
if ~exist(outview, 'dir'), mkdir(outview); end
SK = struct('nLam', 50, 'ratio', 1e-3, 'tol_r2', 0.02, 'nBlk', 5, 'stable', 4, 'near', 3, 'plant', [57 301]);
UNCORR_DEFAULT = {'AL_0039_0419_e1', 'AL_0039_0420_e1'};    % as ctrl_ols_ol_stimblind.m
Lc = dir(fullfile(dd, 'ctrl_ols_ol_stimblind_ridge_*.mat'));
allTags = erase(erase({Lc.name}, 'ctrl_ols_ol_stimblind_ridge_'), '.mat');
if exist('SK_TAGS', 'var') && ~isempty(SK_TAGS), runTags = SK_TAGS; else, runTags = allTags; end

for it = 1:numel(runTags)
    tag = runTags{it};
    fprintf('\n[sparse] ===== %s =====\n', tag);
    R = sk_session(mouse, fields, tag, dd, SK, any(strcmpi(tag, UNCORR_DEFAULT)));
    save(fullfile(dd, sprintf('ctrl_sparse_kernel_%s.mat', tag)), 'R');
end

% ================= summary over every session on disk =================
rows = {};  RR = {};
for it = 1:numel(allTags)
    f = fullfile(dd, sprintf('ctrl_sparse_kernel_%s.mat', allTags{it}));
    if ~exist(f, 'file'), continue; end
    S = load(f);  R = S.R;  RR{end+1} = R; %#ok<SAGROW>
    if ~R.reproduced
        rows(end+1, :) = {R.tag, 'not reproduced', '', NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN}; %#ok<SAGROW>
        continue
    end
    L = R.lasso;  k = L.path_k;
    at = @(kk) local_nearest(k, kk);
    rows(end+1, :) = {R.tag, R.variant, R.ridge_source, R.nG, R.ridge.R2te, L.R2te, L.k, R.ridge.Dratio, L.Dratio, ...
        R.ridge.share3, L.share3, R.area3, R.ridge.leak, L.leak, L.n_stable, L.stable_Dratio, ...
        L.path_Dratio(at(10)), L.path_Dratio(at(20))}; %#ok<SAGROW>
end
T = cell2table(rows, 'VariableNames', {'session', 'variant', 'ridge', 'p', 'ridge_R2', 'lasso_R2', 'lasso_k', ...
    'ridge_DDgrid', 'lasso_DDgrid', 'ridge_share3', 'lasso_share3', 'area3', 'ridge_leak', 'lasso_leak', ...
    'n_stable', 'stable_DDgrid', 'DDgrid_at10', 'DDgrid_at20'});
writetable(T, fullfile(dd, 'ctrl_sparse_kernel_summary.csv'));
disp(T);
ok = ~isnan(T.lasso_R2);
fprintf('[sparse] ridge from the cache in %d sessions, fresh refit in %d\n', nnz(strcmp(T.ridge, 'cache')), nnz(strcmp(T.ridge, 'fresh refit')));
fprintf(['[sparse] %d of %d sessions with results. Lasso at the lambda rule: median %d of median %d px kept; ' ...
         'test R^2 lasso - ridge median %+.3f (range %+.3f to %+.3f)\n'], nnz(ok), height(T), round(median(T.lasso_k(ok))), ...
         round(median(T.p(ok))), median(T.lasso_R2(ok) - T.ridge_R2(ok)), min(T.lasso_R2(ok) - T.ridge_R2(ok)), ...
         max(T.lasso_R2(ok) - T.ridge_R2(ok)));
mr = @(x) [median(x) min(x) max(x)];
fprintf(['[sparse] D/D_grid median (range): ridge %.2f (%.2f-%.2f), lasso %.2f (%.2f-%.2f), lasso stable px %.2f ' ...
         '(%.2f-%.2f), lasso at ~10 px %.2f (%.2f-%.2f), at ~20 px %.2f (%.2f-%.2f); lasso < 1 in %d of %d\n'], ...
         mr(T.ridge_DDgrid(ok)), mr(T.lasso_DDgrid(ok)), mr(T.stable_DDgrid(ok)), ...
         mr(T.DDgrid_at10(ok)), mr(T.DDgrid_at20(ok)), nnz(T.lasso_DDgrid(ok) < 1), nnz(ok));
local_figures(RR, outview);

% ======================================================================================
function R = sk_session(mouse, fields, tag, dd, SK, uncorrDefault)
fld = '';
for k = 1:numel(fields)
    s = mouse.(fields{k});
    if ~isfield(s, 'mn'), continue; end
    if strcmp(sprintf('%s_%s%s_e%d', s.mn, s.td(6:7), s.td(9:10), s.en), tag), fld = fields{k}; break; end
end
assert(~isempty(fld), 'session %s not in fields', tag);
d_s = mouse.(fld).d;  data = mouse.(fld).data;
S1 = load(fullfile(dd, sprintf('ctrl_ols_spont_%s.mat', tag)));
S2 = load(fullfile(dd, sprintf('ctrl_ols_ol_stimblind_ridge_%s.mat', tag)));
assert(strcmp(S2.target_mode, 'canonical'), '%s: target_mode %s not handled', tag, S2.target_mode);
gridIdx = S1.gridIdx;  grR = S1.grR(:);  grC = S1.grC(:);  nG = numel(gridIdx);  horizon = S1.horizon;
R = struct('tag', tag, 'reproduced', false, 'variant', '', 'nG', nG);

% ---- CHECK 1: find the V / target variant that reproduces the cached ridge ----
found = false;
for uc = [uncorrDefault, ~uncorrDefault]
    [U, V, t_svd, mimg] = cp_loadUVt(expPath(mouse.(fld).mn, mouse.(fld).td, mouse.(fld).en), 500, d_s.timeBlue, uc);
    V = double(V);  Uflat = reshape(U, size(mimg,1)*size(mimg,2), size(U,3));  clear U
    frames = S1.frames;  itr = S1.itr;  ite = S1.ite;
    nF_m = min(size(V,2), numel(t_svd));  ytrace = data.dFk(:);
    if numel(ytrace) < nF_m                                  % as ctrl_ols_ol_stimblind.m
        assert(nF_m - numel(ytrace) <= 10);  nF_m = numel(ytrace);
        keepF = frames <= nF_m;
        if ~all(keepF)
            map = cumsum(keepF);  itr = map(itr(keepF(itr)));  ite = map(ite(keepF(ite)));  frames = frames(keepF);
        end
    end
    Xg = double(Uflat(gridIdx,:)) * V;  clear Uflat V
    if max(frames) > size(Xg, 2)       % this Stage-1 frame list cannot belong to this V
        fprintf('[check 1] V %s: Stage-1 frames reach %d but V has %d frames; variant skipped\n', ...
            local_pick(uc, 'uncorrected', 'corrected'), max(frames), size(Xg, 2));
        continue
    end
    for detr = [false true]
        if detr, yb = movmedian(ytrace, horizon, 'omitnan'); else, yb = zeros(size(ytrace)); end
        yfit = ytrace - yb;
        FG = ctrl_gram_build(Xg, frames, itr, ite, yfit);
        bR = (FG.Gtr + S2.RPATH.lambda_abs*eye(nG)) \ FG.ctr;
        r2R = 1 - (FG.sse0te - 2*(bR.'*FG.cte) + bR.'*FG.Gte*bR) / FG.sste;
        db = max(abs(bR - S2.b));
        fprintf('[check 1] V %s, target %s: ridge test R^2 %.4f (cache %.4f), max |b - b_cache| %.1e\n', ...
            local_pick(uc, 'uncorrected', 'corrected'), local_pick(detr, 'detrended', 'raw'), r2R, S2.R2_te, db);
        if abs(r2R - S2.R2_te) < 1e-6 && db < 1e-6*max(abs(S2.b)) + 1e-9
            found = true;  break
        end
    end
    if found, break; end
end
if found
    % CHECK 3: the fresh-refit machinery (lambda rule, OL onsets, Actual) reproduces this cache too
    [bC, r2C, ~, ~] = local_ridge_rule(FG, SK);
    assert(max(abs(bC - S2.b)) < 1e-6*max(abs(S2.b)) + 1e-9 && abs(r2C - S2.R2_te) < 1e-6, '%s: lambda rule not reproduced', tag);
    [~, relC, AaC] = local_ol_windows(d_s, data, t_svd, ytrace, nF_m, S1.trial_dur, S2.onF);   % window code on the cached onsets
    assert(isequal(relC, S2.rel) && max(abs(AaC - S2.Aa)) < 1e-9, '%s: OL window code does not reproduce the cached Actual', tag);
    onC = local_ol_windows(d_s, data, t_svd, ytrace, nF_m, S1.trial_dur);                   % today's onsets
    R.onsets_today = onC;  R.onsets_changed = numel(onC) ~= numel(S2.onF) || any(onC(:) ~= S2.onF(:));
    fprintf('[check 3] lambda rule and OL window code reproduce the cache; today''s onsets: %d, %d differ from the cache\n', ...
        numel(onC), local_ndiff(onC, S2.onF));
    R.ridge_source = 'cache';
    onF = S2.onF;  rel = S2.rel;  Aa = S2.Aa;
else
    % FRESH RIDGE REFIT on today's data (Aditya 2026-11-19: "Fresh ridge refit"): the current
    % ctrl_ols_ol_stimblind.m settings (V by its uncorrected list, canonical dFk, fit-target detrend
    % on), the Stage-1 frames clamped to today's V with the pipeline's own small-shortfall rule, ridge
    % lambda by the ctrl_ridge_path.m rule. Lasso is then fitted on exactly the same data.
    fprintf('[sparse] %s: no variant reproduces the cached ridge -> fresh ridge refit on today''s data\n', tag);
    uc = uncorrDefault;  detr = true;
    [U, V, t_svd, mimg] = cp_loadUVt(expPath(mouse.(fld).mn, mouse.(fld).td, mouse.(fld).en), 500, d_s.timeBlue, uc);
    V = double(V);  Uflat = reshape(U, size(mimg,1)*size(mimg,2), size(U,3));  clear U
    frames = S1.frames;  itr = S1.itr;  ite = S1.ite;
    nF_m = min(size(V,2), numel(t_svd));  ytrace = data.dFk(:);  nF_m = min(nF_m, numel(ytrace));
    assert(S1.nF_m - nF_m <= 10, '%s: today''s data are %d frames short of Stage 1', tag, S1.nF_m - nF_m);
    keepF = frames <= nF_m;
    if ~all(keepF)
        map = cumsum(keepF);  itr = map(itr(keepF(itr)));  ite = map(ite(keepF(ite)));  frames = frames(keepF);
        fprintf('[fresh] dropped %d Stage-1 frame(s) beyond today''s %d frames\n', nnz(~keepF), nF_m);
    end
    Xg = double(Uflat(gridIdx,:)) * V;  clear Uflat V
    yb = movmedian(ytrace, horizon, 'omitnan');  yfit = ytrace - yb;
    FG = ctrl_gram_build(Xg, frames, itr, ite, yfit);
    [bR, r2R, lamRel, atEdge] = local_ridge_rule(FG, SK);
    [onF, rel, Aa] = local_ol_windows(d_s, data, t_svd, ytrace, nF_m, S1.trial_dur);
    fprintf('[fresh] ridge lambda %.3g x mean diag%s | test R^2 %.4f (old cache %.4f) | %d OL trials (cache %d)\n', ...
        lamRel, local_pick(atEdge, ' AT GRID EDGE', ''), r2R, S2.R2_te, numel(onF), numel(S2.onF));
    R.ridge_source = 'fresh refit';  R.ridge_lambda_rel = lamRel;  R.ridge_at_edge = atEdge;
end
R.variant = sprintf('%s V, %s target', local_pick(uc, 'uncorrected', 'corrected'), local_pick(detr, 'detrended', 'raw'));

Xs  = Xg(:, frames);
Ztr = ((Xs(:,itr) - FG.mu) ./ FG.sd).';  Zte = ((Xs(:,ite) - FG.mu) ./ FG.sd).';  clear Xs
ys  = yfit(frames);  etr = ys(itr) - FG.muY;  ete = ys(ite) - FG.muY;
r2te = @(b, b0) 1 - sum((ete - Zte*b - b0).^2) / FG.sste;
assert(abs(r2te(bR, 0) - r2R) < 1e-8);

% OL deployment windows, as [CTRL-OL-DEPLOY]
pre = -rel(1);  post = rel(end);
W = struct('bwin', 1:pre, 'swin', pre+1:pre+post, 'nRel', numel(rel), 'nTr', numel(onF), 'muY', FG.muY, 'Aa', Aa);
W.ZW = zeros(W.nTr*W.nRel, nG);  W.YB = zeros(W.nTr*W.nRel, 1);
for j = 1:W.nTr
    ii = (j-1)*W.nRel + (1:W.nRel);
    W.ZW(ii,:) = ((Xg(:, onF(j)+rel) - FG.mu) ./ FG.sd).';
    W.YB(ii)   = yb(onF(j)+rel);
end
clear Xg
leakR = local_leak(W, bR, 0);
fprintf('[%s] ridge leak %.3f%% (old cache %.3f%%)\n', R.ridge_source, leakR, S2.leak_sus);
if strcmp(R.ridge_source, 'cache')
    assert(abs(leakR - S2.leak_sus) < 1e-6, '%s: ridge leak not reproduced', tag);
end

% homolog and grid geometry
sx = S1.px_prim;  sy = S1.py_prim;
C = load(fullfile(dd, sprintf('cp_stim_site_ctrl_%s.mat', tag)));
if isfield(C, 'rowcol') && numel(C.rowcol) >= 2, sy = C.rowcol(1); sx = C.rowcol(2); end
[~, ~, mid] = ctrl_brain_mask(tag);
assert(~isempty(mid), '%s: no drawn midline', tag);
P1 = [mid.x(1) mid.y(1)];  P2 = [mid.x(end) mid.y(end)];  u = (P2 - P1)/norm(P2 - P1);
p = [sx sy];  m = 2*(P1 + dot(p - P1, u)*u) - p;                     % [col row]
ur = unique(grR);  ucol = unique(grC);  step = ur(2) - ur(1);
assert(all(diff(ur) == step) && all(diff(ucol) == step), '%s: grid is not regular', tag);
G = struct('d', hypot(grC - m(1), grR - m(2)) / step, 'grR', grR, 'grC', grC, 'm', m, 'near', SK.near);
R.site = [sx sy];  R.mirror = m;  R.step = step;  R.grR = grR;  R.grC = grC;  R.mid = mid;
R.area3 = mean(G.d <= SK.near);  R.nearest_steps = min(G.d);

% CHECK 2: planted target
rs = RandStream('twister', 'Seed', 3);  jp = SK.plant;
es  = Ztr(:,jp)*[0.6; -0.4] + 0.5*randn(rs, numel(etr), 1);
est = Zte(:,jp)*[0.6; -0.4] + 0.5*randn(rs, numel(ete), 1);
[Bp, Fp] = lasso(Ztr, es, 'Alpha', 1, 'NumLambda', 30, 'LambdaRatio', SK.ratio, 'Standardize', false);
r2p = arrayfun(@(i) 1 - sum((est - Zte*Bp(:,i) - Fp.Intercept(i)).^2) / sum((est - mean(est)).^2), 1:numel(Fp.Lambda));
okp = find(r2p >= max(r2p) - SK.tol_r2);  bp = Bp(:, okp(end));  [~, op] = sort(abs(bp), 'descend');
R.plant_ok = isequal(sort(op(1:2)).', jp);
fprintf('[check 2] planted px %s: two largest lasso weights at %s -> %s\n', mat2str(jp), mat2str(sort(op(1:2)).'), ...
    local_pick(R.plant_ok, 'recovered', 'NOT recovered'));

% ridge (cached) and lasso
R.ridge = local_loc(bR, G);  R.ridge.R2te = r2R;  R.ridge.leak = leakR;  R.b_ridge = bR;
[B, FI] = lasso(Ztr, etr, 'Alpha', 1, 'NumLambda', SK.nLam, 'LambdaRatio', SK.ratio, 'Standardize', false);
r2 = arrayfun(@(i) r2te(B(:,i), FI.Intercept(i)), 1:numel(FI.Lambda));
ok = find(r2 >= max(r2) - SK.tol_r2);  ix = ok(end);                  % Lambda ascending: last = largest
b = B(:,ix);  b0 = FI.Intercept(ix);  lam = FI.Lambda(ix);
edges = round(linspace(0, numel(etr), SK.nBlk + 1));  sel = zeros(nG, 1);
for kb = 1:SK.nBlk
    blk = edges(kb)+1:edges(kb+1);
    sel = sel + (lasso(Ztr(blk,:), etr(blk), 'Alpha', 1, 'Lambda', lam, 'Standardize', false) ~= 0);
end
L = local_loc(b, G);
L.R2te = r2(ix);  L.R2max = max(r2);  L.lambda = lam;  L.lambda_max = FI.Lambda(end);
L.at_edge = (ix == 1) || (ix == numel(FI.Lambda));  L.leak = local_leak(W, b, b0);
L.sel = sel;  L.n_stable = nnz(sel >= SK.stable);
Ls = local_loc(b .* (sel >= SK.stable), G);  L.stable_Dratio = Ls.Dratio;
PL = arrayfun(@(i) local_loc(B(:,i), G), 1:numel(FI.Lambda));
L.path_k = FI.DF;  L.path_r2 = r2;  L.path_Dratio = [PL.Dratio];  L.path_share3 = [PL.share3];  L.path_lambda = FI.Lambda;
R.lasso = L;  R.b_lasso = b;  R.reproduced = true;
fprintf(['[lasso] %d of %d px kept (lambda %.3g = %.3g x max%s) | test R^2 %.3f (ridge %.3f) | leak %.1f%% (ridge %.1f%%)\n' ...
         '        D/D_grid %.2f (ridge %.2f) | share within %d steps %.0f%% (ridge %.0f%%, area %.0f%%) | %d stable px, D/D_grid %.2f\n'], ...
    L.k, nG, lam, lam/FI.Lambda(end), local_pick(L.at_edge, ', AT PATH EDGE', ''), L.R2te, r2R, L.leak, leakR, ...
    L.Dratio, R.ridge.Dratio, SK.near, 100*L.share3, 100*R.ridge.share3, 100*R.area3, L.n_stable, L.stable_Dratio);
end

function [b, r2, lamRel, atEdge] = local_ridge_rule(FG, SK)
% utils/ctrl_ridge_path.m selection: lambda grid logspace(-8,1,28) relative to mean(diag(Gtr)); the
% largest lambda whose test R^2 is within tol_r2 of the grid's best (the catch swing is not needed
% to choose, only to report, so it is not recomputed here).
lams = logspace(-8, 1, 28);  scale = mean(diag(FG.Gtr));  nG = size(FG.Gtr, 1);
B = zeros(nG, numel(lams));  r2s = zeros(1, numel(lams));
for i = 1:numel(lams)
    B(:,i) = (FG.Gtr + lams(i)*scale*eye(nG)) \ FG.ctr;
    r2s(i) = 1 - (FG.sse0te - 2*(B(:,i).'*FG.cte) + B(:,i).'*FG.Gte*B(:,i)) / max(FG.sste, eps);
end
ix = find(r2s >= max(r2s) - SK.tol_r2, 1, 'last');
b = B(:,ix);  r2 = r2s(ix);  lamRel = lams(ix);  atEdge = (ix == 1) || (ix == numel(lams));
end

function [onF, rel, Aa] = local_ol_windows(d_s, data, t_svd, ytrace, nF_m, trial_dur, onF)
% OL onsets, window and trial-averaged Actual exactly as ctrl_ols_ol_stimblind.m [CTRL-OL-AFFECTED]
% and [CTRL-OL-DEPLOY] (Fs 35, onset filter on the 6 s SD margin, baseline [-1,0) s). Pass onF to
% skip the onset step (used to check the window code on a cache's own onsets).
Fs = 35;  post = round(trial_dur*Fs);  pre_sd = round(6.0*Fs);  pre = round(1.0*Fs);
if nargin < 7
    t_full = t_svd(:);
    ol = sort(d_s.stimStarts(data.nc(:)));  onF = zeros(numel(ol), 1);
    for j = 1:numel(ol), [~, onF(j)] = min(abs(t_full - ol(j))); end
    onF = onF(onF > pre_sd & onF + post <= nF_m);
end
rel = -pre:post;  A = zeros(numel(onF), numel(rel));
for j = 1:numel(onF), A(j,:) = ytrace(onF(j) + rel).'; end
A = A - mean(A(:, 1:pre), 2);  Aa = mean(A, 1);
end

function n = local_ndiff(a, b)
if numel(a) ~= numel(b), n = max(numel(a), numel(b)); else, n = nnz(a(:) ~= b(:)); end
end

function M = local_loc(b, G)
w = abs(b(:));  M.k = nnz(b);
M.Dratio = (sum(w .* G.d) / sum(w)) / mean(G.d);                     % NaN when every weight is 0
M.share3 = sum(w(G.d <= G.near)) / sum(w);
end

function L = local_leak(W, b, b0)
Gt = reshape(W.muY + b0 + W.ZW*b + W.YB, W.nRel, W.nTr).';
Gt = Gt - mean(Gt(:,W.bwin), 2);
L = 100 * mean(mean(Gt(:,W.swin), 1)) / mean(W.Aa(W.swin));
end

function i = local_nearest(k, kk)
[~, i] = min(abs(double(k) - kk));
end

function s = local_pick(c, a, b)
if c, s = a; else, s = b; end
end

function local_figures(RR, outview)
RR = RR(cellfun(@(r) r.reproduced, RR));  n = numel(RR);
if n == 0, return; end
% summary: path curves, and ridge vs lasso at the lambda rule
f = figure('Color', 'w', 'Units', 'centimeters', 'Position', [2 2 18 5.5]);
tl = tiledlayout(f, 1, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
ax1 = nexttile(tl);  hold(ax1, 'on');  ax2 = nexttile(tl);  hold(ax2, 'on');  ax3 = nexttile(tl);  hold(ax3, 'on');
for i = 1:n
    L = RR{i}.lasso;  c = [.55 .55 .55];
    plot(ax1, L.path_k, L.path_r2, '-', 'Color', c, 'LineWidth', 0.5);
    plot(ax1, L.k, L.R2te, 'o', 'MarkerSize', 3, 'MarkerFaceColor', 'k', 'MarkerEdgeColor', 'none');
    plot(ax2, L.path_k, L.path_Dratio, '-', 'Color', c, 'LineWidth', 0.5);
    plot(ax2, L.k, L.Dratio, 'o', 'MarkerSize', 3, 'MarkerFaceColor', 'k', 'MarkerEdgeColor', 'none');
    plot(ax3, [1 2], [RR{i}.ridge.Dratio L.Dratio], '-o', 'Color', c, 'MarkerSize', 3, 'MarkerFaceColor', c);
end
yline(ax2, 1, '--k');  yline(ax3, 1, '--k');
set([ax1 ax2], 'XScale', 'log', 'XLim', [1 600]);  set([ax1 ax2 ax3], 'FontSize', 6, 'Box', 'off', 'TickDir', 'out');
xlabel(ax1, 'Nonzero weights');  ylabel(ax1, 'Test R^2');  title(ax1, 'Lasso path, per session', 'FontSize', 7);
xlabel(ax2, 'Nonzero weights');  ylabel(ax2, 'D / D_{grid}');  title(ax2, 'Pull toward the homolog', 'FontSize', 7);
set(ax3, 'XLim', [0.6 2.4], 'XTick', [1 2], 'XTickLabel', {'Ridge', 'Lasso'});
ylabel(ax3, 'D / D_{grid}');  title(ax3, sprintf('At the \\lambda rule (%d sessions)', n), 'FontSize', 7);
exportgraphics(f, fullfile(outview, 'ctrl_sparse_kernel_summary.png'), 'Resolution', 300);
% maps: ridge | lasso per session, stable lasso px outlined, site (dot) and homolog (ring)
cmap = interp1([0 .5 1], [0.16 0.34 0.66; 1 1 1; 0.78 0.16 0.12], linspace(0, 1, 256));
nc = 8;  nr = ceil(2*n/nc);
f = figure('Color', 'w', 'Units', 'centimeters', 'Position', [1 1 30 4.2*nr]);
tl = tiledlayout(f, nr, nc, 'TileSpacing', 'tight', 'Padding', 'compact');
for i = 1:n
    R = RR{i};  [bmask, bnd] = ctrl_brain_mask(R.tag);  brain = ctrl_mean_img(R.tag);
    lo = prctile(brain(bmask), 1);  hi = prctile(brain(bmask), 99);
    g = 0.40 + 0.55*min(max((brain - lo)/max(hi - lo, eps), 0), 1);  RGB = cat(3, g, g, g);  RGB(repmat(~bmask,1,1,3)) = 1;
    ur = unique(R.grR);  ucol = unique(R.grC);  [~, ir] = ismember(R.grR, ur);  [~, ic] = ismember(R.grC, ucol);
    [ry, rx] = find(bmask);
    for q = 1:2
        ax = nexttile(tl);  hold(ax, 'on');  image(ax, RGB);
        if q == 1, b = R.b_ridge; else, b = R.b_lasso; end
        Wm = nan(numel(ur), numel(ucol));  Wm(sub2ind(size(Wm), ir, ic)) = b;
        h = imagesc(ax, ucol([1 end]), ur([1 end]), Wm);  set(h, 'AlphaData', ~isnan(Wm) & (Wm ~= 0 | q == 1));
        cm = max(abs(b));  colormap(ax, cmap);  clim(ax, [-cm cm]);
        plot(ax, bnd(:,2), bnd(:,1), '-', 'Color', [.2 .2 .2], 'LineWidth', 0.6);
        plot(ax, R.mid.x, R.mid.y, ':', 'Color', [.35 .35 .35]);
        if q == 2
            for j = find(R.lasso.sel >= 4).'
                rectangle(ax, 'Position', [R.grC(j)-R.step/2 R.grR(j)-R.step/2 R.step R.step], 'EdgeColor', 'k', 'LineWidth', 0.5);
            end
        end
        plot(ax, R.site(1), R.site(2), 'o', 'MarkerSize', 4, 'MarkerFaceColor', 'k', 'MarkerEdgeColor', 'none');
        plot(ax, R.mirror(1), R.mirror(2), 'o', 'MarkerSize', 6, 'MarkerEdgeColor', [0 .6 0], 'LineWidth', 1);
        axis(ax, 'image');  set(ax, 'YDir', 'reverse');  axis(ax, 'off');
        xlim(ax, [min(rx)-12 max(rx)+12]);  ylim(ax, [min(ry)-12 max(ry)+12]);
        if q == 1
            title(ax, {strrep(R.tag, '_', '\_'), sprintf('ridge%s %d px, D/D_{grid} %.2f', local_pick(strcmp(R.ridge_source, 'cache'), '', ' (refit)'), ...
                R.ridge.k, R.ridge.Dratio)}, 'FontSize', 6);
        else
            title(ax, {' ', sprintf('lasso %d px, D/D_{grid} %.2f', R.lasso.k, R.lasso.Dratio)}, 'FontSize', 6);
        end
    end
end
exportgraphics(f, fullfile(outview, 'ctrl_sparse_kernel_maps.png'), 'Resolution', 250);
fprintf('[sparse] wrote %s and ctrl_sparse_kernel_maps.png\n', fullfile(outview, 'ctrl_sparse_kernel_summary.png'));
end
