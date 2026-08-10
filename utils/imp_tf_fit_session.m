function T = imp_tf_fit_session(A, fs, tWin, opts)
%IMP_TF_FIT_SESSION  Fit the impulse LTI model for ONE session and score amplitude correctness.
%
% Headless engine behind impulse-analysis/imp_tf_xsess.m. Reproduces tf_fit.m's fitting path
% (amplitude-normalised h(t), tfest order sweep, AIC selection, LOAO) and adds the pieces the
% amplitude question needs, which tf_fit.m does not currently separate.
%
% WHY THE EXTRA SCORES. tf_fit.m predicts each amplitude as uA(a)*h(t) and reports one R^2. That
% R^2 mixes two different failures: the response having the wrong SHAPE, and the response having
% the wrong SIZE. Under LTI both are forbidden, but they mean different things when violated --
% wrong shape breaks time-invariance, wrong size breaks proportionality (saturation). So here each
% amplitude gets, in addition to the LTI-constrained R^2:
%   gFree(a) = <y_a, h> / <h,h>     free gain: the best-fitting amplitude for that response
%   rho(a)   = corr(y_a, h)         SHAPE agreement, scale-free (immune to any gain error)
%   R2free(a)                       R^2 once the gain is free -> what is left is pure shape error
% Under LTI, gFree(a) is proportional to uA(a) with slope = 1 (after the h normalisation below)
% and rho(a) is constant across amplitudes. Departures are the finding, not the nuisance.
%
% AMPLITUDE-INVARIANCE OF THE DYNAMICS (opts.per_amp_fit, default true): a separate model is also
% fitted to EACH amplitude on its own. If the poles move with amplitude, the system is not LTI in
% the amplitude dimension no matter how good the pooled fit looks. Low amplitudes are noisy and
% these fits often fail; failures come back NaN rather than being silently dropped.
%
% INPUTS
% CROSS-SESSION COMPARISON SUPPORT. Two options exist purely so sessions can be compared fairly:
%   opts.ampRange  restrict the amplitudes used to BUILD h(t) to [lo hi] V. Sessions here do not
%                  span the same drive range (AL_0033 0.5-4.9 V over 9 amps; AL_0041 0.7-2.7 V
%                  over 4-6), and h is amp^2-weighted, so an unrestricted fit sets AL_0033's time
%                  constants from its 3.7-4.9 V responses and AL_0041's from ~2.7 V. If the
%                  dynamics depend on amplitude at all, a tau difference between those fits is an
%                  amplitude-range artefact, not a session difference. Fitting every session over
%                  the COMMON range makes the comparison like-for-like. Scoring still covers every
%                  amplitude, so extrapolation beyond the fit range stays visible.
%   opts.nBoot     bootstrap over TRIALS (resample within amplitude -> rebuild the amp-averages ->
%                  refit at the SELECTED order -> tau). Gives a within-session CI, without which
%                  three different tau values cannot be told from fit noise. The order is held
%                  fixed across draws on purpose: re-sweeping would plot model-selection jitter.
%
% INPUTS
%   A     one element of allExperiments (needs .DF_imp, .uAmp, .mn, .td, .en; .imp.dfImp for nBoot)
%   fs    frame rate (Hz)                    tWin  half-width of the DF_imp window (s)
%   opts  .maxPoles (3) .maxZeros (3) .maxDelay (0) .tFit_s (0.5) .per_amp_fit (true)
%         .verbose (true) .ampRange ([] = all) .nBoot (0 = off)
%
% OUTPUT T: label, order (np/nz/nd), sys, poles, tau (s), dcgain, h (unit-sample response),
%   uA, R2 (LTI-constrained), gFree, gRatio (=gFree/uA), rho, R2free, R2_loao, R2_pool,
%   linSlope/linR2 (proportionality fit through the origin), tau_amp [nAmp x maxPoles],
%   ampFit (amplitudes used for h), tauBoot [nBoot x maxPoles], tauCI [maxPoles x 2], tauSD, ok.

if nargin < 4, opts = struct(); end
def = struct('maxPoles',3,'maxZeros',3,'maxDelay',0,'tFit_s',0.5,'per_amp_fit',true, ...
             'verbose',true,'ampRange',[],'nBoot',0);
fn = fieldnames(def);
for i = 1:numel(fn), if ~isfield(opts,fn{i}) || isempty(opts.(fn{i})), opts.(fn{i}) = def.(fn{i}); end, end

% Identity fields are carried SEPARATELY from `label`. `label` is a display string
% (axis ticks, printouts); callers that need the mouse -- e.g. counting how many
% ANIMALS the sessions come from, which the caption must state -- must not have to
% parse it back out.
T = struct('label',sprintf('%s %s e%d', A.mn, A.td, A.en), ...
           'mn',A.mn, 'td',A.td, 'en',A.en, 'ok',false);
Ts = 1/fs;

DF   = A.DF_imp;
uA   = A.uAmp(:);
nAmp = numel(uA);
t_full = -tWin : Ts : tWin;
iPost  = find(t_full >= 0 & t_full <= opts.tFit_s);
nPost  = numel(iPost);

% ---- amplitude-normalised impulse response h(t) --------------------------------------------
% Dividing each amplitude's trial-average by its input voltage is ALREADY the LTI assumption: if
% the system is linear the rows collapse onto one h(t). The amp^2 weighting lets the high-SNR
% strong amplitudes set the time constants (an unweighted mean drags the poles toward the noisy
% weak-amp shape). Zero-amplitude rows are gap-fill placeholders and are excluded.
validAmp = uA > 0;
if ~isempty(opts.ampRange)
    validAmp = validAmp & uA >= opts.ampRange(1)-1e-9 & uA <= opts.ampRange(2)+1e-9;
end
T.ampRange = opts.ampRange;  T.ampFit = uA(validAmp);
if nnz(validAmp) < 2
    if opts.verbose
        fprintf('  [TF] %s: fewer than 2 amplitudes in the fit range %s -- skipped\n', ...
            T.label, mat2str(opts.ampRange));
    end
    return
end
w_amp  = uA(validAmp).^2;  w_amp = w_amp/sum(w_amp);
h_rows = DF(validAmp, iPost) ./ uA(validAmp);
h_norm = sum(h_rows .* w_amp, 1, 'omitnan').';
validT = isfinite(h_norm);
nT_h   = nnz(validT);
if nT_h < opts.maxPoles + 3
    if opts.verbose, fprintf('  [TF] %s: too few finite samples in h(t) -- skipped\n', T.label); end
    return
end

nPre = opts.maxPoles + opts.maxZeros + 2;        % toolbox wants lead-in zeros for transient data
[best, res] = local_sweep(h_norm(validT), nPre, Ts, opts);
if isempty(best)
    if opts.verbose, fprintf('  [TF] %s: every order failed or was rejected as unsafe\n', T.label); end
    return
end

T.sys    = best.sys;   T.np = best.np;  T.nz = best.nz;  T.nd = best.nd;
T.AIC    = best.AIC;   T.res = res;
T.poles  = pole(best.sys);
T.tau    = sort(-1./real(T.poles(real(T.poles) < 0)), 'descend');   % time constants, slowest first
T.dcgain = dcgain(best.sys);
T.uA     = uA;
T.nAmpUsed = nnz(validAmp);

% ---- unit-sample response of the selected model (the reference waveform for every score) -----
hHat = local_unit_response(best.sys, nPre, nPost, Ts);
if isempty(hHat)
    if opts.verbose, fprintf('  [TF] %s: could not simulate the selected model\n', T.label); end
    return
end
T.h = hHat;  T.tPost = t_full(iPost).';
% MEASURED amplitude-normalised impulse response -- the empirical counterpart of T.h.
% This is exactly what the sweep was fitted to (amp^2-weighted mean of DF/uA over the
% amplitudes in range), kept so a figure can plot measured-vs-fit without refitting.
T.h_meas = h_norm;

% ---- per-amplitude scores -------------------------------------------------------------------
R2 = nan(nAmp,1); gFree = nan(nAmp,1); rho = nan(nAmp,1); R2free = nan(nAmp,1);
yPool = []; ypPool = [];
for a = 1:nAmp
    y = DF(a, iPost).';
    v = isfinite(y) & isfinite(hHat);
    if nnz(v) < 5, continue; end
    yv = y(v);  hv = hHat(v);
    sstot = max(sum((yv - mean(yv)).^2), eps);

    yhat_lti = uA(a)*hv;                                   % LTI-CONSTRAINED: gain forced to uA
    R2(a)    = 1 - sum((yv - yhat_lti).^2)/sstot;

    gFree(a) = (hv.'*yv)/max(hv.'*hv, eps);                % best-fitting gain for this amplitude
    R2free(a)= 1 - sum((yv - gFree(a)*hv).^2)/sstot;       % residual once size is free = shape error
    if std(hv) > 0 && std(yv) > 0
        rho(a) = corr(yv, hv);                             % scale-free shape agreement
    end
    yPool = [yPool; yv]; ypPool = [ypPool; yhat_lti];      %#ok<AGROW>
end
T.R2 = R2;  T.gFree = gFree;  T.rho = rho;  T.R2free = R2free;
T.gRatio = gFree ./ uA;                                    % flat under LTI; falls where it saturates
T.gRatio(uA <= 0) = NaN;
if numel(yPool) > 1
    T.R2_pool = 1 - sum((yPool-ypPool).^2)/max(sum((yPool-mean(yPool)).^2), eps);
else
    T.R2_pool = NaN;
end

% ---- amplitude correctness: proportionality of gFree to uA ----------------------------------
% LTI predicts gFree = uA exactly (h was normalised by amplitude), i.e. a line through the origin
% with slope 1. Fit through the origin and report slope + R^2; slope < 1 with a falling gRatio is
% compression/saturation, which is the specific way this preparation departs from linear.
lin = isfinite(gFree) & uA > 0;
if nnz(lin) >= 2
    T.linSlope = (uA(lin).'*gFree(lin))/max(uA(lin).'*uA(lin), eps);
    ss = sum((gFree(lin) - T.linSlope*uA(lin)).^2);
    T.linR2 = 1 - ss/max(sum((gFree(lin)-mean(gFree(lin))).^2), eps);
else
    T.linSlope = NaN;  T.linR2 = NaN;
end

% ---- LOAO: refit without one amplitude, predict it -------------------------------------------
% The direct generalisation test. A drop from R2 to R2_loao at a given amplitude means the model
% built from the OTHER amplitudes does not extrapolate to it -- amplitude-dependent dynamics.
validIdx = find(validAmp);
R2_loao  = nan(nAmp,1);
for k = 1:numel(validIdx)
    aOut = validIdx(k);  trainIdx = validIdx(validIdx ~= aOut);
    if numel(trainIdx) < 2, continue; end
    w  = uA(trainIdx).^2;  w = w/sum(w);
    hn = sum((DF(trainIdx, iPost) ./ uA(trainIdx)) .* w, 1, 'omitnan').';
    vt = isfinite(hn);
    if nnz(vt) < opts.maxPoles + 3, continue; end
    sysLo = local_fit_one(hn(vt), nPre, Ts, best.np, best.nz, best.nd);
    if isempty(sysLo), continue; end
    hLo = local_unit_response(sysLo, nPre, nPost, Ts);
    if isempty(hLo), continue; end
    y = DF(aOut, iPost).';  v = isfinite(y) & isfinite(hLo);
    if nnz(v) < 5, continue; end
    R2_loao(aOut) = 1 - sum((y(v) - uA(aOut)*hLo(v)).^2)/max(sum((y(v)-mean(y(v))).^2), eps);
end
T.R2_loao = R2_loao;

% ---- per-amplitude models: do the DYNAMICS move with amplitude? ------------------------------
tau_amp = nan(nAmp, opts.maxPoles);
if opts.per_amp_fit
    for a = 1:nAmp
        if uA(a) <= 0, continue; end
        y = DF(a, iPost).'/uA(a);  v = isfinite(y);
        if nnz(v) < opts.maxPoles + 3, continue; end
        sysA = local_fit_one(y(v), nPre, Ts, best.np, best.nz, best.nd);
        if isempty(sysA), continue; end
        p = pole(sysA);  tt = sort(-1./real(p(real(p) < 0)), 'descend');
        tau_amp(a, 1:min(numel(tt), opts.maxPoles)) = tt(1:min(numel(tt), opts.maxPoles)).';
    end
end
T.tau_amp = tau_amp;

% ---- bootstrap over trials -> within-session CI on the time constants -------------------------
% Without this, three sessions with three different tau are uninterpretable: you cannot tell a real
% inter-experiment difference from fit noise. Resampling TRIALS (not time points) is the right unit
% because trials are the independent replicates. The model ORDER is held at the selected value
% across draws -- re-sweeping would make the CI a picture of model-selection instability instead of
% parameter uncertainty.
T.tauBoot = [];  T.tauCI = [];  T.tauSD = [];
if opts.nBoot > 0
    if ~isfield(A,'imp') || ~isfield(A.imp,'dfImp')
        if opts.verbose, fprintf('  [TF] %s: no per-trial dfImp -- bootstrap skipped\n', T.label); end
    else
        T.tauBoot = local_boot_tau(A.imp.dfImp, uA, validAmp, iPost, nPre, Ts, best, opts);
        nOK = sum(all(isfinite(T.tauBoot(:,1)),2));
        if nOK >= 20
            T.tauCI = [prctile(T.tauBoot, 2.5, 1).' , prctile(T.tauBoot, 97.5, 1).'];
            T.tauSD = std(T.tauBoot, 0, 1, 'omitnan').';
        elseif opts.verbose
            fprintf('  [TF] %s: only %d/%d bootstrap refits succeeded -- CI not reported\n', ...
                nOK, opts.nBoot, T.label);
        end
    end
end
T.ok = true;

if opts.verbose
    ciStr = '';
    if ~isempty(T.tauCI) && ~isempty(T.tau)
        ciStr = sprintf(' | tau1 95%%CI [%.0f %.0f] ms', 1000*T.tauCI(1,1), 1000*T.tauCI(1,2));
    end
    rngStr = 'all amps';
    if ~isempty(opts.ampRange), rngStr = sprintf('%.1f-%.1f V', opts.ampRange(1), opts.ampRange(2)); end
    fprintf('  [TF] %-24s  %dp%dz%dd | %s | tau %s s | pooled R2 %.3f | slope %.3f%s\n', ...
        T.label, T.np, T.nz, T.nd, rngStr, mat2str(round(T.tau(:).',4)), T.R2_pool, T.linSlope, ciStr);
end
end

% =================================================================================================
function tb = local_boot_tau(dfImp, uA, validAmp, iPost, nPre, Ts, best, opts)
% Trial bootstrap: for each draw, resample trials WITH REPLACEMENT within every fitted amplitude,
% rebuild that amplitude's trial average, rebuild the amp^2-weighted h(t), refit at the fixed
% selected order, and take the time constants. Draws whose refit fails or is unsafe come back NaN.
idx = find(validAmp);
tb  = nan(opts.nBoot, opts.maxPoles);
w   = uA(idx).^2;  w = w/sum(w);
for b = 1:opts.nBoot
    DFb = nan(numel(idx), numel(iPost));
    bad = false;
    for j = 1:numel(idx)
        tr = dfImp{idx(j)};
        if isempty(tr) || size(tr,1) < 2, bad = true; break; end
        pick = randi(size(tr,1), size(tr,1), 1);
        DFb(j,:) = mean(tr(pick, iPost), 1, 'omitnan');
    end
    if bad, continue; end
    hn = sum((DFb ./ uA(idx)) .* w, 1, 'omitnan').';
    vt = isfinite(hn);
    if nnz(vt) < best.np + 3, continue; end
    sysB = local_fit_one(hn(vt), nPre, Ts, best.np, best.nz, best.nd);
    if isempty(sysB), continue; end
    p  = pole(sysB);
    tt = sort(-1./real(p(real(p) < 0)), 'descend');
    n  = min(numel(tt), opts.maxPoles);
    tb(b, 1:n) = tt(1:n).';
end
end

% =================================================================================================
function [best, res] = local_sweep(h, nPre, Ts, opts)
% tfest sweep over (nd, np, nz) with nz < np (strictly proper -> h(0)=0, which onset-referencing
% depends on). AIC picks the winner. Unsafe fits are screened by tf_ok BEFORE anything simulates.
best = [];  res = struct('np',{},'nz',{},'nd',{},'AIC',{},'sys',{});
nT = numel(h);
u  = [zeros(nPre,1); 1; zeros(nT-1,1)];
y  = [zeros(nPre,1); h(:)];
d  = iddata(y, u, Ts);  d.Tstart = -nPre*Ts;
tfOpt = tfestOptions('EnforceStability', false, 'Display', 'off');
ri = 0;
for nd = 0:opts.maxDelay
    for np = 1:opts.maxPoles
        for nz = 0:min(np-1, opts.maxZeros)
            try
                s = tfest(d, np, nz, tfOpt, 'InputDelay', nd*Ts);
            catch
                continue
            end
            if ~tf_ok(s, Ts), continue; end
            ri = ri+1;
            res(ri).np = np; res(ri).nz = nz; res(ri).nd = nd;
            res(ri).AIC = aic(s); res(ri).sys = s;
        end
    end
end
if ri == 0, return; end
[~, ib] = min([res.AIC]);
best = res(ib);
end

% -------------------------------------------------------------------------------------------------
function sys = local_fit_one(h, nPre, Ts, np, nz, nd)
% Refit ONE fixed order (used by LOAO and the per-amplitude fits). Returns [] on failure or on an
% unsafe fit, so callers record NaN rather than crashing MATLAB in sssim.
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
% Response to a UNIT SAMPLE, matching tf_fit.m's construction exactly so the numbers here are
% directly comparable to the single-session script. Returns [] if the simulation is unsafe.
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
