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
%   opts  .maxPoles (5) .maxZeros (4) .maxDelay (3) .tFit_s (0.5) .per_amp_fit (true)
%         .verbose (true) .ampRange ([] = all) .nBoot (0 = off)
%         .select ('aic') .minR2h (0.98)
%
% MODEL-CLASS BOUNDS AND WHY THEY WERE WIDENED (2026-08-10). The sweep used to be
% 3 poles / 3 zeros / NO input delay, and some sessions came back with a visibly poor
% reproduction of their own h(t). Two of those three bounds were doing real damage:
%   - maxDelay = 0 forced the ENTIRE onset lag (opsin kinetics + indicator rise +
%     whatever conduction there is) to be expressed as relative degree, which a
%     3-pole model pays for with poles it then cannot spend on the decay. An explicit
%     InputDelay is the physically honest place for a transport lag and costs one
%     integer parameter instead of a pole.
%   - maxPoles = 3 is only "low-order" by assertion. 5 is still low-order for a
%     control-theory claim, and AIC will not spend the extra poles unless the data
%     pays for them -- every session that was already fine keeps its old order.
% What is NOT relaxed: nz < np (strictly proper, so h(0) = 0, which onset-referencing
% depends on) and tf_ok's stability/stiffness screen. Those are correctness, not fit.
%
% SELECTION (opts.select). 'aic' is the default and still picks by AIC -- but AIC here
% is computed on ONE smoothed ~18-sample trace, where its complexity penalty is weak
% and its noise model is wrong, so it can settle on an order that plainly does not
% reproduce the curve. So there is an ESCALATION: if the AIC winner's R2_h (its unit
% response against the MEASURED h) is below opts.minR2h, the model is re-picked as the
% most PARSIMONIOUS candidate within 0.002 R2_h of the best available, and the swap is
% printed. 'r2h' applies that rule unconditionally. Either way T.selRule records which
% ran, so a reported order is never anonymous about how it was chosen.
%
% OUTPUT T: label, order (np/nz/nd), sys, poles, tau (s), dcgain, h (unit-sample response),
%   uA, R2 (LTI-constrained), gFree, gRatio (=gFree/uA), rho, R2free, R2_loao, R2_pool,
%   R2_h (fit of the selected model to the measured h -- the number panel 2C-i shows),
%   selRule, linSlope/linR2 (proportionality fit through the origin), tau_amp [nAmp x maxPoles],
%   ampFit (amplitudes used for h), tauBoot [nBoot x maxPoles], tauCI [maxPoles x 2], tauSD, ok.

if nargin < 4, opts = struct(); end
% tauMax: longest time constant a bootstrap resample may return before it is treated as
% non-identifiable and dropped from the CI. NaN = auto = the length of the fitted window,
% which is the principled bound (a tau longer than the data window is not measurable from
% that window). See the rejection block near the bootstrap for why this exists.
def = struct('maxPoles',5,'maxZeros',4,'maxDelay',3,'tFit_s',0.5,'per_amp_fit',true, ...
             'verbose',true,'ampRange',[],'nBoot',0,'select','aic','minR2h',0.98,'tauMax',NaN, ...
             'forceOrder',[],'preShow_s',0.15);
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

% ---- score EVERY surviving candidate against the measured h(t), then select ------------------
% R2_h is the number the shape panel is actually showing, so selection should be able to see it.
% Simulation is safe here because local_sweep already screened with tf_ok.
for r = 1:numel(res)
    hh = local_unit_response(res(r).sys, nPre, nPost, Ts);
    if isempty(hh), res(r).R2h = NaN; else, res(r).R2h = local_r2(h_norm, hh); end
    res(r).nPar = res(r).np + res(r).nz + 1;
end
% Re-take the AIC winner FROM THE SCORED array: local_sweep's copy predates the R2h
% field, and an absent field would make the escalation below fire unconditionally.
[~, iA] = min([res.AIC]);
[best, T.selRule] = local_select(res(iA), res, opts);
if isempty(best)
    if opts.verbose, fprintf('  [TF] %s: no candidate could be simulated\n', T.label); end
    return
end

T.sys    = best.sys;   T.np = best.np;  T.nz = best.nz;  T.nd = best.nd;
T.AIC    = best.AIC;   T.res = res;     T.R2_h = best.R2h;
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

% ---- pre-onset lead-in, for display only -----------------------------------------------------
% The fit sees t >= 0 only, so nothing here enters the model. It exists because a panel that
% starts AT the onset gives the reader no baseline to judge the dip against -- the trace appears
% to begin already falling (user, 2026-08-19). Same amplitude weighting as h_meas so the two
% segments are on one scale and can be concatenated without a seam.
iPreShow = find(t_full >= -opts.preShow_s & t_full < 0);
T.tPre   = t_full(iPreShow).';
if isempty(iPreShow)
    T.h_measPre = [];
else
    T.h_measPre = sum((DF(validAmp, iPreShow) ./ uA(validAmp)) .* w_amp, 1, 'omitnan').';
end

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
% The held-out PREDICTION itself, not just its score (2026-08-19). Without this the only
% cross-validation evidence in the struct is a single R2 number per amplitude, so nothing can
% be plotted -- and a CV figure that shows the measured trace against what a model that never
% saw it predicts is far more convincing than the number. Rows are amplitudes, columns the
% post-onset samples; NaN where the fold could not be run.
T.loao_pred = nan(nAmp, numel(iPost));
T.loao_meas = DF(:, iPost);
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
    np_ = min(numel(hLo), size(T.loao_pred,2));
    T.loao_pred(aOut, 1:np_) = uA(aOut) * hLo(1:np_).';   % scaled to THIS amplitude's drive
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
        % ---- DISCARD NON-IDENTIFIABLE RESAMPLES (2026-08-12) -------------------------------
        % A resample whose slowest pole lands marginally stable (real part -> 0-) returns
        % tau -> Inf. Measured on the 4-session set: 25% of resamples above 1000 s in
        % AL_0041 e1, 17% in AL_0048, 3% in AL_0041 e2 (AL_0033 clean at 0%). Kept in, they
        % made tauCI upper bounds of 1e9-1e12 s and a tauSD of 1.4e14 s -- and because the
        % between/within RATIO divides by that SD, the summary printed "ratio 0.00 ->
        % consistent with ONE shared time constant" no matter what the data said. That
        % conclusion was an artefact of the blow-up, not a result.
        % The bound is not a cosmetic outlier cut: the fit sees a window of tPost seconds, so
        % a time constant longer than that window is not IDENTIFIABLE from these data at all.
        % Rejections are counted and reported rather than silently dropped.
        tauMax = opts.tauMax;
        if isempty(tauMax) || ~isfinite(tauMax), tauMax = numel(iPost) * Ts; end
        T.tauMax  = tauMax;
        badB      = any(T.tauBoot > tauMax, 2) | ~isfinite(T.tauBoot(:,1));
        T.tauBootReject = mean(badB);
        T.tauBoot(badB, :) = NaN;
        nOK = sum(isfinite(T.tauBoot(:,1)));
        if nOK >= 20
            T.tauCI = [prctile(T.tauBoot, 2.5, 1).' , prctile(T.tauBoot, 97.5, 1).'];
            T.tauSD = std(T.tauBoot, 0, 1, 'omitnan').';
            if opts.verbose && T.tauBootReject > 0.02
                fprintf(['  [TF] %s: %.0f%% of bootstrap refits gave tau > %.2f s (window length)\n' ...
                         '       -- not identifiable, dropped from the CI. Report this fraction.\n'], ...
                    T.label, 100*T.tauBootReject, tauMax);
            end
        elseif opts.verbose
            fprintf('  [TF] %s: only %d/%d bootstrap refits usable -- CI not reported\n', ...
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
    fprintf('  [TF] %-24s  %dp%dz%dd | %s | tau %s s | R2h %.3f | pooled R2 %.3f | slope %.3f%s\n', ...
        T.label, T.np, T.nz, T.nd, rngStr, mat2str(round(T.tau(:).',4)), T.R2_h, T.R2_pool, ...
        T.linSlope, ciStr);
    if ~strcmp(T.selRule,'AIC')
        fprintf('       order re-picked: %s\n', T.selRule);
    end
    % A low pooled R2 with a high rho is a SIZE failure (saturation), not a model-order
    % failure -- widening the sweep cannot fix it, and saying so here stops the next
    % round of "relax the constraints" being aimed at the wrong thing.
    if isfinite(T.R2_pool) && T.R2_pool < 0.7
        fprintf(2,'       low pooled R2 (%.3f) with shape rho %.3f and gain slope %.3f -> %s\n', ...
            T.R2_pool, median(T.rho,'omitnan'), T.linSlope, ...
            i_diagnose(median(T.rho,'omitnan'), T.linSlope, T.R2_h));
    end
end
end

% =================================================================================================
function s = i_diagnose(rhoMed, slope, r2h)
% Name the failure so the next fix is aimed at the right thing.
if isfinite(r2h) && r2h < 0.9
    s = 'the MODEL misses the measured h(t) -- raise maxPoles/maxDelay';
elseif isfinite(rhoMed) && rhoMed > 0.85 && isfinite(slope) && abs(slope-1) > 0.25
    s = 'SHAPE is right, SIZE is not -- amplitude compression, not a model-order problem';
elseif isfinite(rhoMed) && rhoMed < 0.7
    s = 'per-amplitude SHAPE disagrees with h -- weak-amp SNR or genuine amp-dependent dynamics';
else
    s = 'mixed shape/size error -- read gRatio and rho per amplitude before touching the sweep';
end
end

% =================================================================================================
function r2 = local_r2(yMeas, yHat)
% R^2 of a model waveform against the measured one, over the samples finite in BOTH.
% No free scale: the model was fitted to this trace, so a gain error is a fit failure.
r2 = NaN;
m  = min(numel(yMeas), numel(yHat));
a  = yMeas(1:m);  b = yHat(1:m);
v  = isfinite(a) & isfinite(b);
if nnz(v) < 5, return; end
av = a(v);  bv = b(v);
r2 = 1 - sum((av-bv).^2)/max(sum((av-mean(av)).^2), eps);
end

% -------------------------------------------------------------------------------------------------
function [pick, rule] = local_select(bestAIC, res, opts)
% Choose the reported model. See the SELECTION note in the header for why AIC alone is
% not trusted here. `parsimonious within 0.002 of the best R2_h` is the escalation target,
% NOT `max R2_h` -- taking the outright maximum would buy an invisible amount of curve at
% the cost of poles the LTI claim then has to defend.
r2 = [res.R2h];
ok = isfinite(r2);
if ~any(ok), pick = []; rule = 'none simulable'; return; end

pick = bestAIC;  rule = 'AIC';
if isfield(bestAIC,'R2h') && isfinite(bestAIC.R2h) && ...
        ~strcmpi(opts.select,'r2h') && bestAIC.R2h >= opts.minR2h
    return                                  % AIC winner already reproduces the curve
end
cand   = find(ok & r2 >= max(r2(ok)) - 0.002);
nPar   = [res(cand).nPar];
[~, j] = min(nPar);                          % fewest parameters among the near-best fits
pick   = res(cand(j));
if strcmpi(opts.select,'r2h')
    rule = 'R2h (parsimonious)';
elseif isfield(bestAIC,'R2h') && isfinite(bestAIC.R2h)
    rule = sprintf('AIC->R2h (AIC gave %dp%dz%dd, R2h %.3f < %.2f)', ...
        bestAIC.np, bestAIC.nz, bestAIC.nd, bestAIC.R2h, opts.minR2h);
else
    rule = 'AIC->R2h (AIC winner not simulable)';
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
% nd > 0 is an explicit InputDelay in SAMPLES: the onset lag is a transport delay, and letting
% the model say so is cheaper (one integer) than making relative degree absorb it with poles.
% R2h/nPar are declared here so the array carries them even when the sweep returns empty.
best = [];  res = struct('np',{},'nz',{},'nd',{},'AIC',{},'sys',{},'R2h',{},'nPar',{});
nT = numel(h);
u  = [zeros(nPre,1); 1; zeros(nT-1,1)];
y  = [zeros(nPre,1); h(:)];
d  = iddata(y, u, Ts);  d.Tstart = -nPre*Ts;
tfOpt = tfestOptions('EnforceStability', false, 'Display', 'off');
ri = 0;
% opts.forceOrder = [np nz nd] collapses the sweep to a SINGLE fit at that order.
% Added 2026-08-14 for the fit-window scoping test: the sweep is ~100 tfest calls per
% session and its cost scales with window length, so re-sweeping at 1.0/1.5 s to ask a
% question about the WINDOW made the test 100x more expensive than the question needed
% (two runs exceeded 30 min and had to be killed). Holding the order fixed also makes the
% comparison cleaner -- otherwise a change in tau could be the order moving, not the window.
if ~isempty(opts.forceOrder)
    fo = opts.forceOrder;
    ndList = fo(3);  npList = fo(1);  nzList = fo(2);
else
    ndList = 0:opts.maxDelay;  npList = 1:opts.maxPoles;  nzList = [];
end
for nd = ndList
    for np = npList
        if isempty(opts.forceOrder), nzList = 0:min(np-1, opts.maxZeros); end
        for nz = nzList
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
