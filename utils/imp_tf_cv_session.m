function C = imp_tf_cv_session(A, fs, tWin, T, opts)
%IMP_TF_CV_SESSION  Trial-level cross-validation of the impulse LTI fit, ONE session.
%
% WHY THIS EXISTS. The 2C-i shape panel and imp_tf_fit_session's R2_h are IN-SAMPLE: the
% model is fitted to the amplitude-averaged h(t) and then scored against that SAME h(t).
% LOAO (leave-one-amplitude-out) holds out an amplitude but still fits and tests on trial
% AVERAGES, so it never sees fresh trials -- it measures dose extrapolation, not overfit.
% This routine holds out TRIALS: it answers "does the fitted plant reproduce the impulse
% response of repeats it was never shown", which is the honest generalisation test the
% in-sample panel cannot give.
%
% METHOD -- repeated stratified split-half over trials, BOTH directions.
%   * Within EACH amplitude the trials are randomly permuted and split in half. Splitting
%     WITHIN amplitude (stratified) keeps both halves spanning the full dose range, so
%     h(t) is built the identical amp^2-weighted way on each half and the split is not a
%     disguised leave-one-amplitude-out. This is the "randomise both datasets first" step.
%   * Half 1 -> build h1(t), refit the model, predict half 2's measured h2(t); then the
%     reverse (fit h2, predict h1). Both directions use every split, so nSplit random
%     partitions give 2*nSplit independent held-out fits.
%   * The model ORDER is held at the session's full-data selection (T.np/nz/nd) and only
%     the coefficients are refitted on each half. Re-selecting order per fold would fold
%     model-selection instability into the CV and needs the full order sweep per fold; the
%     trial bootstrap in imp_tf_fit_session makes the same fixed-order choice. ORDER
%     SELECTION IS THEREFORE NOT ITSELF CROSS-VALIDATED -- the caption must say so.
%
% TWO held-out R^2 per split, because "the fit generalises" is two claims:
%   R2_out    amplitude-normalised. The prediction carries the model's own DC gain, so a
%             gain mismatch on the held-out half counts against it. The honest number.
%   R2_shape  each trace peak-normalised by ITS OWN peak before R^2 -> gain removed, pure
%             SHAPE agreement, matching the peak-normalised 2C-i panel.
% R2_in is the matched IN-SAMPLE control: the SAME train model scored on its OWN half, so
% the in-sample vs held-out gap is apples-to-apples (same order, same trial count).
%
% INPUTS
%   A     one allExperiments entry; needs .imp.dfImp (per-trial, cell{amp}=nTrial x nTime),
%         .uAmp, .DF_imp
%   fs    frame rate (Hz)              tWin  half-width of the DF_imp window (s)
%   T     the full-data fit for this session (imp_tf_fit_session output) -> order + window
%   opts  .nSplit (100) .seed (7) .minTrials (6, per half per amplitude)
%         .nPre (11 = default maxPoles+maxZeros+2, matches the fit path) .verbose (true)
%         .perAmp (true) also accumulate per-AMPLITUDE held-out traces for the single-session
%                 supplementary panel (measured held-out vs LTI prediction at each drive).
%
% OUTPUT C: label, mn, ok, np/nz/nd, nSplit, nOK, reject (fraction of folds that failed),
%   R2_out [2nSplit x 1], R2_shape [2nSplit x 1], R2_in [2nSplit x 1],
%   tPost, h_meas_cv (mean held-out measured, amp-norm), h_pred_cv (mean held-out prediction),
%   R2h_full (=T.R2_h, the in-sample fit shown in 2C-i, for reference),
%   amp (when perAmp): .uA [nAmp x 1], .idx (amplitudes with CV data), .n [nAmp x 1] folds,
%       .meas [nAmp x nPost] split-averaged held-out MEASURED trace (%dF/F, at true drive),
%       .pred [nAmp x nPost] split-averaged held-out LTI PREDICTION (uA*hHat), .R2 [nAmp x 1].

if nargin < 5, opts = struct(); end
def = struct('nSplit',100,'seed',7,'minTrials',6,'nPre',11,'verbose',true,'perAmp',true);
fn = fieldnames(def);
for i = 1:numel(fn), if ~isfield(opts,fn{i}) || isempty(opts.(fn{i})), opts.(fn{i}) = def.(fn{i}); end, end

C = struct('label', T.label, 'mn', T.mn, 'ok', false);
if ~isfield(T,'ok') || ~T.ok
    if opts.verbose, fprintf('  [CV] %s: no usable full-data fit -- CV skipped\n', T.label); end
    return
end
if ~isfield(A,'imp') || ~isfield(A.imp,'dfImp') || isempty(A.imp.dfImp)
    if opts.verbose, fprintf('  [CV] %s: no per-trial dfImp -- CV skipped\n', T.label); end
    return
end

Ts     = 1/fs;
t_full = -tWin : Ts : tWin;
nPost  = numel(T.h);
iPost  = find(t_full >= 0, 1) + (0:nPost-1);          % same post-onset window as the fit
iPost  = iPost(iPost <= numel(t_full));
if numel(iPost) ~= nPost
    if opts.verbose, fprintf('  [CV] %s: window mismatch -- CV skipped\n', T.label); end
    return
end

uA   = A.uAmp(:);
dfI  = A.imp.dfImp(:);
nAmp = min(numel(uA), numel(dfI));

% Amplitudes usable for CV: positive drive AND enough trials to halve with minTrials each.
useAmp = false(nAmp,1);
nTr    = zeros(nAmp,1);
for a = 1:nAmp
    if uA(a) <= 0 || isempty(dfI{a}), continue; end
    nTr(a) = size(dfI{a}, 1);
    useAmp(a) = nTr(a) >= 2*opts.minTrials;
end
idxA = find(useAmp);
if numel(idxA) < 2
    if opts.verbose
        fprintf('  [CV] %s: fewer than 2 amplitudes with >= %d trials/half -- CV skipped\n', ...
            T.label, opts.minTrials);
    end
    return
end
w = uA(idxA).^2;  w = w/sum(w);                        % amp^2 weighting, as the fit uses

np = T.np;  nz = T.nz;  nd = T.nd;  nPre = opts.nPre;
rng(opts.seed, 'twister');

R2out = nan(2*opts.nSplit,1);  R2shp = nan(2*opts.nSplit,1);  R2in = nan(2*opts.nSplit,1);
accMeas = zeros(nPost,1);  accPred = zeros(nPost,1);  nAcc = 0;
% per-amplitude held-out accumulators (measured vs LTI prediction at each drive)
ampMeas = zeros(nAmp, nPost);  ampPred = zeros(nAmp, nPost);  ampN = zeros(nAmp,1);

for s = 1:opts.nSplit
    % ---- stratified split: permute each amplitude's trials, halve within amplitude ----
    H1 = cell(numel(idxA),1);  H2 = cell(numel(idxA),1);
    for j = 1:numel(idxA)
        a  = idxA(j);
        p  = randperm(nTr(a));
        c  = floor(nTr(a)/2);
        H1{j} = p(1:c);  H2{j} = p(c+1:end);
    end
    hA = local_build_h(dfI, idxA, uA, iPost, w, H1);
    hB = local_build_h(dfI, idxA, uA, iPost, w, H2);

    % ---- both directions: fit one half, predict the other ----
    [ro1, rs1, ri1, pr1] = local_fit_predict(hA, hB, np, nz, nd, nPre, Ts, nPost);
    [ro2, rs2, ri2, pr2] = local_fit_predict(hB, hA, np, nz, nd, nPre, Ts, nPost);
    R2out(2*s-1) = ro1;  R2shp(2*s-1) = rs1;  R2in(2*s-1) = ri1;
    R2out(2*s)   = ro2;  R2shp(2*s)   = rs2;  R2in(2*s)   = ri2;

    % ---- accumulate held-out measured/predicted for the overlay ----
    if ~isempty(pr1) && all(isfinite(hB)), accMeas = accMeas + hB;  accPred = accPred + pr1; nAcc = nAcc + 1; end
    if ~isempty(pr2) && all(isfinite(hA)), accMeas = accMeas + hA;  accPred = accPred + pr2; nAcc = nAcc + 1; end

    % ---- per-amplitude held-out traces: measured (test half) vs LTI prediction uA*hHat ----
    % pr1 is the unit response of the model trained on H1 -> predicts the H2 measured trace;
    % pr2 trained on H2 -> predicts H1. Both halves contribute a held-out measurement per amp.
    if opts.perAmp
        for j = 1:numel(idxA)
            a = idxA(j);
            if ~isempty(pr1)
                ampMeas(a,:) = ampMeas(a,:) + mean(dfI{a}(H2{j}, iPost), 1, 'omitnan');
                ampPred(a,:) = ampPred(a,:) + (uA(a) * pr1(:)).';
                ampN(a) = ampN(a) + 1;
            end
            if ~isempty(pr2)
                ampMeas(a,:) = ampMeas(a,:) + mean(dfI{a}(H1{j}, iPost), 1, 'omitnan');
                ampPred(a,:) = ampPred(a,:) + (uA(a) * pr2(:)).';
                ampN(a) = ampN(a) + 1;
            end
        end
    end
end

C.ok        = true;
C.np = np;  C.nz = nz;  C.nd = nd;
C.nSplit    = opts.nSplit;
C.R2_out    = R2out;
C.R2_shape  = R2shp;
C.R2_in     = R2in;
C.nOK       = sum(isfinite(R2out));
C.reject    = mean(~isfinite(R2out));
C.tPost     = T.tPost(:);
C.h_meas_cv = accMeas / max(nAcc,1);
C.h_pred_cv = accPred / max(nAcc,1);
C.R2h_full  = T.R2_h;

if opts.perAmp
    keep = ampN > 0;
    amp = struct('uA', uA, 'idx', find(keep), 'n', ampN, ...
                 'meas', ampMeas ./ max(ampN,1), 'pred', ampPred ./ max(ampN,1), ...
                 'R2', nan(nAmp,1));
    for a = find(keep).'
        amp.R2(a) = local_r2(amp.meas(a,:).', amp.pred(a,:).');   % on split-averaged held-out traces
    end
    C.amp = amp;
end

if opts.verbose
    fprintf(['  [CV] %-24s  %dp%dz%dd | %d splits x2 dir | held-out R2 %.3f [%.3f %.3f] ' ...
             '| shape %.3f | in-sample %.3f | %.0f%% folds failed\n'], ...
        T.label, np, nz, nd, opts.nSplit, median(R2out,'omitnan'), ...
        prctile(R2out,25), prctile(R2out,75), median(R2shp,'omitnan'), ...
        median(R2in,'omitnan'), 100*C.reject);
end
end

% =================================================================================================
function h = local_build_h(dfI, idxA, uA, iPost, w, sub)
% amp^2-weighted, amplitude-normalised mean impulse response from a TRIAL SUBSET.
% Identical construction to imp_tf_fit_session's h_norm, but averaging only sub{j} trials.
rows = nan(numel(idxA), numel(iPost));
for j = 1:numel(idxA)
    tr = dfI{idxA(j)};
    rows(j,:) = mean(tr(sub{j}, iPost), 1, 'omitnan') ./ uA(idxA(j));
end
h = sum(rows .* w, 1, 'omitnan').';
end

% -------------------------------------------------------------------------------------------------
function [r2out, r2shape, r2in, pred] = local_fit_predict(hTrain, hTest, np, nz, nd, nPre, Ts, nPost)
% Fit the fixed order to hTrain, simulate its unit response, score against hTest (held out)
% and against hTrain (in-sample control). pred = the held-out prediction waveform (amp-norm).
r2out = NaN; r2shape = NaN; r2in = NaN; pred = [];
vt = isfinite(hTrain);
if nnz(vt) < np + 3, return; end
sys = local_fit_one(hTrain(vt), nPre, Ts, np, nz, nd);
if isempty(sys), return; end
hHat = local_unit_response(sys, nPre, nPost, Ts);
if isempty(hHat), return; end
pred    = hHat(:);
r2out   = local_r2(hTest,  hHat);                 % held out, amplitude-normalised
r2in    = local_r2(hTrain, hHat);                 % in-sample control, same model
r2shape = local_r2_shape(hTest, hHat);            % held out, peak-normalised (shape only)
end

% -------------------------------------------------------------------------------------------------
function sys = local_fit_one(h, nPre, Ts, np, nz, nd)
% Refit ONE fixed order. Mirrors imp_tf_fit_session's local_fit_one exactly (same lead-in,
% InputDelay in samples, tf_ok safety screen) so CV numbers are comparable to the fit path.
sys = [];
nT = numel(h);
if nT < np + 3, return; end
u = [zeros(nPre,1); 1; zeros(nT-1,1)];
y = [zeros(nPre,1); h(:)];
d = iddata(y, u, Ts);  d.Tstart = -nPre*Ts;
try
    s = tfest(d, np, nz, tfestOptions('EnforceStability',false,'Display','off'), 'InputDelay', nd*Ts);
catch
    return
end
if tf_ok(s, Ts), sys = s; end
end

% -------------------------------------------------------------------------------------------------
function h = local_unit_response(sys, nPre, nPost, Ts)
% Unit-sample response, matching imp_tf_fit_session so waveforms are directly comparable.
h = [];
if ~tf_ok(sys, Ts), return; end
u = [zeros(nPre,1); 1; zeros(nPost-1,1)];
try
    o = sim(sys, iddata([], u, Ts));
catch
    return
end
h = o.OutputData(nPre+1 : nPre+nPost);
if numel(h) ~= nPost || any(~isfinite(h)), h = []; end
end

% -------------------------------------------------------------------------------------------------
function r2 = local_r2(yMeas, yHat)
% R^2 with NO free scale: the prediction carries the model's gain, so a gain error is a
% miss. Over the samples finite in both.
r2 = NaN;
m  = min(numel(yMeas), numel(yHat));
a  = yMeas(1:m);  b = yHat(1:m);
v  = isfinite(a) & isfinite(b);
if nnz(v) < 5, return; end
av = a(v);  bv = b(v);
r2 = 1 - sum((av-bv).^2)/max(sum((av-mean(av)).^2), eps);
end

% -------------------------------------------------------------------------------------------------
function r2 = local_r2_shape(yMeas, yHat)
% Shape-only R^2: peak-normalise EACH trace by its own peak before comparing, so a pure
% gain mismatch does not count -- this is the number the peak-normalised 2C-i panel implies.
r2 = NaN;
m  = min(numel(yMeas), numel(yHat));
a  = yMeas(1:m);  b = yHat(1:m);
v  = isfinite(a) & isfinite(b);
if nnz(v) < 5, return; end
av = a(v);  bv = b(v);
sa = max(abs(av));  sb = max(abs(bv));
if sa == 0 || sb == 0, return; end
av = av/sa;  bv = bv/sb;
r2 = 1 - sum((av-bv).^2)/max(sum((av-mean(av)).^2), eps);
end
