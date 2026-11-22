% controller-analysis/ctrl_sparse_kernel_cl.m
% Ridge vs lasso contra->ipsi Global on the spot (research-hub #100): R^2 on the spot before each trial,
% and the Global and the Fig 4H disturbance on CL trials, for every session of ctrl_sparse_kernel.m.
%
% Math approved by Aditya 2026-11-21: "Approve (c)" and "approve" (method block on research-hub #100 and
% in the brain_paper session chat; option (c) for the slow baseline yb; RESEARCH L-2026-11-21-a).
% No new formula: R2_pre, D and RR are reused as defined.
%
% Per session, for ridge and lasso (weights, lambda and data variant from ctrl_sparse_kernel_<tag>.mat;
% each model rebuilt on its own V, Stage-1 frames, train z-scoring and target, R.variant):
%   Global   G(t) = muY + b0 + z(t)'b, z = the contra grid pixels z-scored with the train mean and SD,
%            muY = mean train target, b0 = lasso intercept (0 for ridge). In target units: no yb add-back.
%   yb       1400-frame (horizon) moving median of y = data.dFk when the target was detrended, else 0.
%   trials   as imp_build_session.m: onsets d_s.stimStarts(data.nc) (OL) and (data.wc) (CL), nearest SVD
%            frame, -1 s to the end of stimulation; A = data.dFk.
%   R2_pre   internal_model_principle.m lines 145-147: over the 35 frames of [-1,0) s, all trials of one
%            condition pooled, R2 = 1 - sum (A' - G')^2 / sum (A' - mean A')^2.
%            (c) A' = A - yb, G' = G   (approved: scored in the target the model was fitted on)
%            (a) A' = A,      G' = G + yb   (b) A' = A, G' = G   (extra columns; equal to (c) when yb = 0)
%   D        f4_cl_reject_lmm.m lines 42-44: Gr = G - mean of G over [-1,0) s per trial; g_OL = mean of Gr
%            over OL trials and (1,3] s; D = Gr(CL) - g_OL. G as in (b), as that code builds it.
%   RR       per CL trial sum_(1,3] s (A - r)^2 / sum D^2, r = d.ref (-5); session geometric mean (the 4H dot).
%   gate     biasFrac = (mean settled A_CL - r)^2 / mean settled (A_CL - r)^2 > 1/3 is outside Fig 4H.
% Checks: saved ridge and lasso weights reproduce their saved test R^2 on the rebuilt data; on CHECK_TAG
% (cached ridge) the OL R2_pre(b) and the CL Actual equal what imp_build_session.m gives; the largest
% change in mean D over (1,3] s when yb is added back to G is reported.
% Descriptive: no test.
%
% Needs load_sessions.m (mouse, fields) and ctrl_sparse_kernel.m results. Reads the SVD from the server
% (read-only). Set SKCL_TAGS (cellstr) in the base workspace to run a subset, or SKCL_TAGS = 'none' to
% redraw only; the table and figure always cover every per-session result on disk.
% OUT controller-analysis/data/ctrl_sparse_kernel_cl_<tag>.mat, data/ctrl_sparse_kernel_cl_summary.csv,
%     controller-analysis/_preview/ctrl_sparse_kernel_cl.png
assert(exist('mouse','var') && exist('fields','var'), 'run controller-analysis/load_sessions.m first');
root = 'C:\Users\aditya\Documents\projects\brain_paper';
dd   = fullfile(root, 'controller-analysis', 'data');
outview = fullfile(root, 'controller-analysis', '_preview');
CFG = struct('nSV_load', 500, 'Fs', 35, 'pre_s', 1.0, 'resp_s', 3.0, 'bias_max', 1/3);
CHECK_TAG = 'AL_0033_0415_e2';                       % the 4F session, ridge from the cache
Ls = dir(fullfile(dd, 'ctrl_sparse_kernel_AL_*.mat'));
allTags = erase(erase({Ls.name}, 'ctrl_sparse_kernel_'), '.mat');
if exist('SKCL_TAGS', 'var') && ~isempty(SKCL_TAGS), runTags = SKCL_TAGS; else, runTags = allTags; end
if ischar(runTags) && strcmp(runTags, 'none'), runTags = {}; end    % table and figure from disk only

for it = 1:numel(runTags)
    tag = runTags{it};
    fprintf('\n[sk-cl] ===== %s =====\n', tag);
    C = skcl_session(mouse, fields, tag, dd, CFG, strcmp(tag, CHECK_TAG));
    save(fullfile(dd, sprintf('ctrl_sparse_kernel_cl_%s.mat', tag)), 'C');
end

% ================= table and figure over every session on disk =================
CC = {};
for it = 1:numel(allTags)
    f = fullfile(dd, sprintf('ctrl_sparse_kernel_cl_%s.mat', allTags{it}));
    if exist(f, 'file'), S = load(f); CC{end+1} = S.C; end %#ok<SAGROW>
end
CC = [CC{:}];
T = struct2table(rmfield(CC, {'tt', 'mA', 'mG', 'mD', 'sD', 'dur'}));
writetable(T, fullfile(dd, 'ctrl_sparse_kernel_cl_summary.csv'));
disp(T(:, {'session', 'ridge_source', 'nOL', 'nCL', 'R2te_ridge', 'R2te_lasso', 'R2preOL_ridge', 'R2preOL_lasso', ...
    'R2preCL_ridge', 'R2preCL_lasso', 'RR_ridge', 'RR_lasso', 'in4H', 'plant_ok'}));
skcl_figure(CC, outview);

% ======================================================================================
function C = skcl_session(mouse, fields, tag, dd, CFG, doCheck)
fld = '';
for k = 1:numel(fields)
    s = mouse.(fields{k});
    if ~isfield(s, 'mn'), continue; end
    if strcmp(sprintf('%s_%s%s_e%d', s.mn, s.td(6:7), s.td(9:10), s.en), tag), fld = fields{k}; selField = k; break; end
end
assert(~isempty(fld), 'session %s not in fields', tag);
M = mouse.(fld);
if ~isfield(M, 'd') || isempty(M.d)                  % as f4_cl_reject_lmm.m
    tmp = load(fullfile(fileparts(fileparts(dd)), 'data', sprintf('%sctrl%s%s%d.mat', M.mn, M.td(6:7), M.td(9:10), M.en)));
    M.d = tmp.d;  M.data = tmp.data;  clear tmp
    mouse.(fld) = M;
end
d_s = M.d;  data = M.data;
S1 = load(fullfile(dd, sprintf('ctrl_ols_spont_%s.mat', tag)));
R  = getfield(load(fullfile(dd, sprintf('ctrl_sparse_kernel_%s.mat', tag))), 'R'); %#ok<GFLD>
assert(R.reproduced, '%s: no ridge/lasso result', tag);
uc = contains(R.variant, 'uncorrected');  detr = contains(R.variant, 'detrended');
horizon = S1.horizon;  gridIdx = S1.gridIdx;

% ---- the data each model was fitted on, as ctrl_sparse_kernel.m rebuilds it ----
[U, V, t_svd, mimg] = cp_loadUVt(expPath(M.mn, M.td, M.en), CFG.nSV_load, d_s.timeBlue, uc);
V = double(V);  Uflat = reshape(U, size(mimg,1)*size(mimg,2), size(U,3));  clear U
frames = S1.frames;  itr = S1.itr;  ite = S1.ite;  ytrace = data.dFk(:);
nF_m = min(size(V,2), numel(t_svd));
if strcmp(R.ridge_source, 'fresh refit'), nF_m = min(nF_m, numel(ytrace)); end
if numel(ytrace) < nF_m, assert(nF_m - numel(ytrace) <= 10); nF_m = numel(ytrace); end
keepF = frames <= nF_m;
if ~all(keepF)
    map = cumsum(keepF);  itr = map(itr(keepF(itr)));  ite = map(ite(keepF(ite)));  frames = frames(keepF);
end
Xg = double(Uflat(gridIdx,:)) * V;  nFv = size(V, 2);  clear Uflat V
if detr, yb = movmedian(ytrace, horizon, 'omitnan'); else, yb = zeros(size(ytrace)); end
FG = ctrl_gram_build(Xg, frames, itr, ite, ytrace - yb);
Xs = Xg(:, frames);
Ztr = ((Xs(:,itr) - FG.mu) ./ FG.sd).';  Zte = ((Xs(:,ite) - FG.mu) ./ FG.sd).';  clear Xs
ys = ytrace - yb;  ys = ys(frames);  etr = ys(itr) - FG.muY;  ete = ys(ite) - FG.muY;
bR = R.b_ridge;  bL = R.b_lasso;  b0 = mean(etr) - mean(Ztr, 1)*bL;      % MATLAB lasso intercept
r2te = @(b, c) 1 - sum((ete - Zte*b - c).^2) / FG.sste;
fprintf('[check] test R^2 ridge %.6f (saved %.6f), lasso %.6f (saved %.6f), lasso b0 %.2e\n', ...
    r2te(bR, 0), R.ridge.R2te, r2te(bL, b0), R.lasso.R2te, b0);
assert(abs(r2te(bR, 0) - R.ridge.R2te) < 1e-8 && abs(r2te(bL, b0) - R.lasso.R2te) < 1e-8, '%s: weights do not reproduce the saved test R^2', tag);
clear Ztr Zte
Gb = FG.muY + (((Xg - FG.mu) ./ FG.sd).' * [bR bL]) + [0 b0];             % [nF x 2] Global, target units
clear Xg

% ---- trials as imp_build_session.m ----
Fs = CFG.Fs;  pre = round(CFG.pre_s*Fs);  post = round(S1.trial_dur*Fs);  rel = -pre:post;
t_full = t_svd(:);  nF = min(nFv, numel(t_full));
if numel(ytrace) < nF, assert(nF - numel(ytrace) <= 10); nF = numel(ytrace); end
onOL = skcl_onsets(sort(d_s.stimStarts(data.nc(:))), t_full, pre, post, nF);
onCL = skcl_onsets(sort(d_s.stimStarts(data.wc(:))), t_full, pre, post, nF);
cut = @(x, on) x(on + rel);                                                % [n x nRel] (on is a column)
if isfield(d_s, 'ref') && ~isempty(d_s.ref), ref = d_s.ref; else, ref = -5; end
bwin = 1:pre;  wr = pre + round(1*Fs) + 1 : pre + round(CFG.resp_s*Fs);
r2pre = @(A, G) 1 - sum((A(:,bwin) - G(:,bwin)).^2, 'all') / sum((A(:,bwin) - mean(A(:,bwin), 'all')).^2, 'all');

C = struct('session', tag, 'variant', R.variant, 'ridge_source', R.ridge_source, 'nOL', numel(onOL), 'nCL', numel(onCL), ...
    'R2te_ridge', R.ridge.R2te, 'R2te_lasso', R.lasso.R2te, 'lasso_k', R.lasso.k, 'plant_ok', R.plant_ok);
nm = {'ridge', 'lasso'};
Aol = cut(ytrace, onOL);  Acl = cut(ytrace, onCL);  YBol = cut(yb, onOL);  YBcl = cut(yb, onCL);
mA = mean(Acl - mean(Acl(:,bwin), 2), 1);  mG = zeros(2, numel(rel));  mD = mG;  sD = mG;  dDyb = 0;
for m = 1:2
    Gol = cut(Gb(:,m), onOL);  Gcl = cut(Gb(:,m), onCL);
    C.(['R2preOL_' nm{m}])   = r2pre(Aol - YBol, Gol);           % (c)
    C.(['R2preCL_' nm{m}])   = r2pre(Acl - YBcl, Gcl);
    C.(['R2preOL_a_' nm{m}]) = r2pre(Aol, Gol + YBol);           % (a)
    C.(['R2preCL_a_' nm{m}]) = r2pre(Acl, Gcl + YBcl);
    C.(['R2preOL_b_' nm{m}]) = r2pre(Aol, Gol);                  % (b)
    C.(['R2preCL_b_' nm{m}]) = r2pre(Acl, Gcl);
    [D, rr] = skcl_disturbance(Gol, Gcl, Acl, bwin, wr, ref);
    ok = isfinite(rr) & rr > 0;
    C.(['RR_' nm{m}]) = exp(mean(log(rr(ok))));
    Dy = skcl_disturbance(Gol + YBol, Gcl + YBcl, Acl, bwin, wr, ref);
    dDyb = max(dDyb, max(abs(mean(Dy(:,wr), 1) - mean(D(:,wr), 1))));
    mG(m,:) = mean(Gcl - mean(Gcl(:,bwin), 2), 1);  mD(m,:) = mean(D, 1);  sD(m,:) = std(D, 0, 1);
end
Aset = mean(mean(Acl(:,wr), 2));  msErr = mean(mean((Acl(:,wr) - ref).^2, 2));
C.biasFrac = (Aset - ref)^2 / msErr;  C.in4H = C.biasFrac <= CFG.bias_max;  C.dD_yb = dDyb;
C.tt = rel/Fs;  C.mA = mA;  C.mG = mG;  C.mD = mD;  C.sD = sD;  C.dur = S1.trial_dur;
fprintf(['[sk-cl] OL %d, CL %d trials | R2_pre(c) OL ridge %.3f lasso %.3f | CL ridge %.3f lasso %.3f | ' ...
         'RR ridge %.3f lasso %.3f | biasFrac %.2f | max |mean D change| with yb %.3g\n'], C.nOL, C.nCL, ...
    C.R2preOL_ridge, C.R2preOL_lasso, C.R2preCL_ridge, C.R2preCL_lasso, C.RR_ridge, C.RR_lasso, C.biasFrac, dDyb);

if doCheck   % the cached ridge through the paper's own front end must give the same numbers
    S = imp_build_session(mouse, fields, selField, dd, CFG);
    assert(S.ok, '%s: imp_build_session failed: %s', tag, S.msg);
    r2b = r2pre(S.Aol, S.Gol);
    fprintf('[check] imp_build_session: OL R2_pre(b) %.6f (here %.6f); CL Actual max |diff| %.2e; Gol max |diff| %.2e\n', ...
        r2b, C.R2preOL_b_ridge, max(abs(S.Acl - Acl), [], 'all'), max(abs(S.Gol - cut(Gb(:,1), onOL)), [], 'all'));
    assert(isequal(size(S.Acl), size(Acl)) && max(abs(S.Acl - Acl), [], 'all') < 1e-9 && abs(r2b - C.R2preOL_b_ridge) < 1e-6, ...
        '%s: does not match imp_build_session', tag);
end
end

function on = skcl_onsets(starts, t_full, pre, post, nF)   % deal_trials in imp_build_session.m
on = zeros(numel(starts), 1);
for j = 1:numel(starts), [~, on(j)] = min(abs(t_full - starts(j))); end
on = on(on > pre & on + post <= nF);
end

function [D, rr] = skcl_disturbance(Gol, Gcl, Acl, bwin, wr, ref)   % f4_cl_reject_lmm.m lines 42-45
Gr_ol = Gol - mean(Gol(:,bwin), 2);  gdipOL = mean(mean(Gr_ol(:,wr), 2));
D = (Gcl - mean(Gcl(:,bwin), 2)) - gdipOL;
rr = sum((Acl(:,wr) - ref).^2, 2) ./ sum(D(:,wr).^2, 2);
end

function skcl_figure(CC, outview)
cR = [0.13 0.40 0.80];  cL = [0.90 0.45 0.10];  n = numel(CC);
nRow = ceil(n/2);  pitch = 3.1;  H = pitch*nRow + 2.0;  w = 3.3;
fig = figure('Color', 'w', 'Units', 'centimeters', 'Position', [2 1 17.6 H], 'Visible', 'off');
for i = 1:n
    C = CC(i);  r = ceil(i/2);  c = mod(i-1, 2);  x0 = 1.0 + c*8.8;  y0 = H - 1.0 - r*pitch;
    note = {};
    if strcmp(C.session, 'AL_0033_0415_e2'), note{end+1} = '4F'; end %#ok<AGROW>
    if ~C.in4H, note{end+1} = 'outside 4H'; end %#ok<AGROW>
    if ~C.plant_ok, note{end+1} = 'lasso unreliable'; end %#ok<AGROW>
    if strcmp(C.ridge_source, 'fresh refit'), note{end+1} = 'ridge refit'; end %#ok<AGROW>
    ttl = strrep(C.session, '_', ' ');
    if ~isempty(note), ttl = sprintf('%s (%s)', ttl, strjoin(note, ', ')); end
    ttl = {ttl, sprintf('R^2 pre CL: ridge %.2f, lasso %.2f      RR: ridge %.2f, lasso %.2f', ...
        C.R2preCL_ridge, C.R2preCL_lasso, C.RR_ridge, C.RR_lasso)};
    a = axes('Units', 'centimeters', 'Position', [x0 y0 w 1.9]);  hold(a, 'on');
    patch(a, [0 C.dur C.dur 0], [-1e3 -1e3 1e3 1e3], [0.93 0.93 0.93], 'EdgeColor', 'none');
    plot(a, C.tt, C.mA, 'k', 'LineWidth', 1.0);
    plot(a, C.tt, C.mG(1,:), 'Color', cR, 'LineWidth', 1.0);  plot(a, C.tt, C.mG(2,:), 'Color', cL, 'LineWidth', 1.0);
    yl = [min([C.mA C.mG(:)']) max([C.mA C.mG(:)'])];  yl = yl + [-0.1 0.1]*diff(yl);  ylim(a, yl);  xlim(a, [C.tt(1) C.tt(end)]);
    title(a, ttl, 'FontSize', 6, 'FontWeight', 'bold', 'HorizontalAlignment', 'left', 'Units', 'normalized', 'Position', [0 1.02]);
    skcl_ax(a, r == nRow, '\DeltaF/F (%)');
    b = axes('Units', 'centimeters', 'Position', [x0 + 4.25 y0 w 1.9]);  hold(b, 'on');
    for m = [1 2]
        col = cR*(m == 1) + cL*(m == 2);
        fill(b, [C.tt fliplr(C.tt)], [C.mD(m,:) + C.sD(m,:), fliplr(C.mD(m,:) - C.sD(m,:))], col, 'FaceAlpha', 0.15, 'EdgeColor', 'none');
        plot(b, C.tt, C.mD(m,:), 'Color', col, 'LineWidth', 1.0);
    end
    xline(b, [1 3], ':', 'Color', [0.5 0.5 0.5]);  xlim(b, [C.tt(1) C.tt(end)]);
    skcl_ax(b, r == nRow, 'D (%)');
end
annotation(fig, 'textbox', [0.01 1 - 0.9/H 0.98 0.8/H], 'String', ...
    {'CL trials. Left: trial means, baseline-subtracted over [-1,0) s: Actual (black), Global ridge (blue), Global lasso (orange); grey, stimulation.', ...
     'Right: disturbance D of Fig 4H, mean \pm SD over CL trials, ridge (blue) and lasso (orange); dotted, the 1-3 s window of RR.'}, ...
    'EdgeColor', 'none', 'FontSize', 6, 'Interpreter', 'tex');
exportgraphics(fig, fullfile(outview, 'ctrl_sparse_kernel_cl.png'), 'Resolution', 300);
close(fig);
fprintf('[sk-cl] wrote %s\n', fullfile(outview, 'ctrl_sparse_kernel_cl.png'));
end

function skcl_ax(a, lastRow, yl)
set(a, 'FontSize', 6, 'TickDir', 'out', 'LineWidth', 0.5, 'Box', 'off', 'Layer', 'top');
ylabel(a, yl, 'FontSize', 6);
if lastRow, xlabel(a, 'Time from onset (s)', 'FontSize', 6); end
end
