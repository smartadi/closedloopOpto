%% imp_state_trialvar.m -- TRIAL-TO-TRIAL VARIABILITY of the impulse response vs brain state.
%
% Merges and supersedes the state parts of motion_analysis.m and prestim_variance.m, which asked the
% same question through two different scripts and one confusing DV.
%
% ================================ THE CLAIM BEING TESTED =========================================
% (user, 2026-08-12)
%   H1  higher MOTION            -> LOWER  trial-to-trial variability of the impulse response
%   H2  higher PRE-TRIAL VARIANCE-> SAME or HIGHER variability
%   H3  higher DELTA ENERGY      -> SAME or HIGHER variability
%
% *** THIS IS A CLAIM ABOUT SPREAD, NOT ABOUT MEAN, AND THE TESTS HERE ARE SCALE TESTS. ***
% Established 2026-08-12: the SIGNED deviation Peak_imp - mean(Peak_imp) has NO directional
% relationship to motion (pooled r = 0.003, p = 0.894, n = 1767). Motion compresses the deviation
% distribution SYMMETRICALLY. The old |Peak dev| analyses were therefore scale tests all along --
% abs() turned a variance effect into an apparent mean effect. This script keeps the SIGNED
% deviation for display (so the funnel is visible) and tests the SPREAD explicitly.
%
% DV        dev = Peak_imp - mean(Peak_imp)  per amplitude, SIGNED, then scaled by the within-amp SD
%           so amplitudes can be pooled. Spread statistic = |dev| (a Levene score about the within-
%           amp centre, which is 0 by construction).
%
% STATES    MOT  mean |z| motion                                    power-independent  ADMISSIBLE
%           PVv  var(dF/F)                                          POWER CONFOUND
%           DPa  absolute 1-4 Hz power                              POWER CONFOUND
%           DPr  RELATIVE delta = abs(2-4 Hz) / (0.4-10 Hz)        power-independent  ADMISSIBLE
%                (canonical CL bands, matches cl_reldelta.m / imp_statedep_trials.m; was 1-4/0.5-30)
%
% ⚠ H2 AND H3 ARE PARTLY UNFALSIFIABLE AS STATED. Pre-trial variance and ABSOLUTE delta ARE signal
% power. The DV is a spread. A trial in a high-power state has more variance everywhere, so "higher
% pre-var -> same or higher variability" is close to true by construction and cannot discriminate a
% brain-state effect from an amplitude-of-everything effect. This is the confound retracted on
% 2026-07-01. RELATIVE delta (DPr) is the power-independent version and is the one that can actually
% test H3. Both are computed; PVv/DPa are printed and greyed in the figure, never interpreted.
%
% THE STIM-FREE CONTROL (the thing that makes this falsifiable). Every test is repeated on a
% PRE-ONSET, STIM-FREE quantity built the same way (deviation of the pre-window mean from its
% amp-mean). If a state predicts the spread of the stim-free control as strongly as it predicts the
% spread of the response, the effect is about ongoing signal amplitude, NOT about how the stimulus
% is processed. A claim survives only if STIM effect > PRE control.
%
% WINDOWS   All markers are strictly PRE-ONSET, so none overlaps the response window the DV is
%           measured in -- but they are NOT the same window, and this block previously said they
%           were (corrected 2026-10-02):
%             MOTION              iMot   = [-1 s, -1/fs]  cols 71:105, 35 samples
%             POWER (PVv/DPa/DPr) iState = [-1 s, -1/fs]  cols 71:105, 35 samples
%             SHAM control        iSham  = [-1.2, -1.03]s cols  64:70,  7 samples
%           ONE window for every marker, as the manuscript states (user, 2026-10-02). Up to that
%           date the power markers used -0.8..-0.03 s (26 samples) because the sham was pinned at
%           -1.0 s and the state window was pushed to start after it; that dependency is now
%           inverted -- state window fixed, sham placed before it. STV_PWR_WIN='legacy' restores
%           the old geometry, STV_MOT_WIN='legacy' the old motion window, and both together
%           reproduce the published numbers exactly. RESEARCH A4 records that strictly-pre
%           reproduces the 'peri' [-1,+0.5] s result; STV_STATE_WIN='peri' to compare,
%           STV_MOT_STAT='sq' for the mean-square motion secondary.
%
% RUN:  load_experiments;  imp_state_trialvar
%       STV_NBIN = 5; imp_state_trialvar        % change the number of state bins
% -------------------------------------------------------------------------------------------------

here = fileparts(mfilename('fullpath'));
if isempty(here) || contains(here, tempdir,'IgnoreCase',true) || contains(here,'Editor_','IgnoreCase',true)
    here = 'C:\Users\aditya\Documents\projects\brain_paper\impulse-analysis';
end
addpath(genpath(fullfile(here,'..','utils')));
assert(exist('allExperiments','var')==1 && ~isempty(allExperiments), ...
       '[STV] allExperiments absent -- run load_experiments first.');

if ~exist('STV_NBIN','var')      || isempty(STV_NBIN),      STV_NBIN = 4;        end
if ~exist('STV_STATE_WIN','var') || isempty(STV_STATE_WIN), STV_STATE_WIN = 'pre'; end
if ~exist('STV_NBOOT','var')     || isempty(STV_NBOOT),     STV_NBOOT = 2000;    end
% MOTION STATISTIC (user, 2026-10-02). 'mean' = mean of the z-scored motion energy over the
% motion window; 'sq' = mean of its square, run as a SECONDARY comparison only.
% Why 'mean' is primary: FaceMap's motion_1 is ALREADY a rectified energy (verified on
% AL_0041 2025-11-05/3: min = 0, 0.00 %% of samples negative), so squaring the z-score does
% not turn it into an energy. Averaging z within a trial gives
%     mean_window(z) = (mean_window(E) - mu_session) / sigma_session,
% exactly MONOTONE in that trial's mean energy. mean(z^2) is a second moment, minimised when
% the trial sits AT the session mean, so it scores unusually STILL trials as high as active
% ones; the two rank trials at only rho = 0.303. See RESEARCH 2026-10-02.
if ~exist('STV_MOT_STAT','var')  || isempty(STV_MOT_STAT),  STV_MOT_STAT = 'mean'; end
% 'paper' = the [-1,0) s window the manuscript states (default, 2026-10-02).
% 'legacy' = the pre-2026-10-02 behaviour, where motion shared iState (-0.8..-0.03 s).
% Kept so the published numbers can be reproduced on demand rather than from memory.
if ~exist('STV_MOT_WIN','var')   || isempty(STV_MOT_WIN),   STV_MOT_WIN = 'paper'; end
% POWER-MARKER WINDOW (user, 2026-10-02): rel-delta and abs-delta -- and PVv, which is the same
% window's variance -- now also use the [-1, 0) s the manuscript states, so EVERY Fig-2 state marker
% is measured over one window. 'legacy' restores the -0.8..-0.03 s window used up to this date.
% Two independent reasons, beyond matching the text:
%  (a) SPECTRAL RESOLUTION. local_delta takes a bare FFT of the window, so df = fs/n. At the legacy
%      26 samples df = 1.346 Hz and the 2-4 Hz numerator is ONE bin, at 2.69 Hz -- neither 2 nor 4 Hz
%      is represented. At 35 samples df = 1.000 Hz exactly and the band is THREE bins, 2/3/4 Hz.
%      The legacy "2-4 Hz power" was a single off-centre bin.
%  (b) The sham no longer has to collide with it. The sham was pinned at -1.0 s and the state window
%      was then pushed to START after it; here that dependency is INVERTED -- the state window is
%      fixed at [-1,0) and the sham is placed to END one sample before it (cols 64:70, -1.200 to
%      -1.029 s). Still outside the -0.5..0 s baseline dfImp has had removed, which was the sham's
%      actual placement requirement, and the disjointness assert below is unchanged and still passes.
if ~exist('STV_PWR_WIN','var')   || isempty(STV_PWR_WIN),   STV_PWR_WIN = 'paper'; end
% STATE SCALING (user, 2026-08-12). Default RAW: the markers keep their physical units, so an axis
% reads "motion z-score 2.5" or "pre-trial variance 20 (dF/F)^2" instead of a within-amp z that
% cannot be related to anything. Cost of raw pooling: between-session and between-amplitude offsets
% now sit in the pooled statistic, so a session that happens to have both more motion and less
% variability could create a pooled correlation on its own. That is why the pooled row is reported
% BESIDE a SESSION-STRATIFIED estimate (weighted mean of within-session rho) and the per-session
% table -- the stratified number is the one that cannot be produced by between-session structure.
% Set STV_ZSTATE=true to recover the old within-session x amplitude z-scoring.
if ~exist('STV_ZSTATE','var')    || isempty(STV_ZSTATE),    STV_ZSTATE = false;  end
% STATE SCALING, superseding the STV_ZSTATE boolean (user, 2026-08-12: "i said not to use zscore,
% normalise the state axes instead"). Modes:
%   'rank' (DEFAULT) -- within-session PERCENTILE: 0 = quietest trial of that session, 1 = most
%          extreme. Chosen because motion is not a continuous variable -- it is rest punctuated by
%          bouts, so ANY magnitude axis (raw, z, or min-max) puts ~90% of trials in the leftmost
%          tenth and the four quantile bins land on top of each other. Measured under 'norm': bin
%          medians 0.010 / 0.016 / 0.024 / 0.11, i.e. all four inside the left 12% of the axis.
%          COST, and it is a real one: the axis carries ORDER, not MAGNITUDE. A rank axis spreads
%          bins 1-3 across half the panel when they differ by ~0.01 in motion z -- physiologically
%          almost nothing. The magnitude-preserving companion is the MOTION THRESHOLD SPLIT below
%          (z > 1.5), which is where the effect actually lives; read the two together.
%   'norm' -- per session, mapped to 0-1 across the 1st-99th percentile and clipped. Same idea as
%          motion_analysis.m's motN_s but percentile- rather than min/max-anchored (plain min-max
%          is set by the single largest spike in a session). Keeps magnitude; skew and all.
%   'raw'  -- physical units, no scaling. Interpretable, but pools between-session offsets.
%   'z'    -- z-score within session x amplitude (the original; rejected as uninterpretable).
% Every mode is MONOTONE WITHIN SESSION, so each within-session Spearman -- the stratified rho and
% the whole per-session table -- is IDENTICAL across modes. Only pooled statistics and bin edges
% move. That is the point: none of the headline within-session numbers depend on this choice.
if ~exist('STV_STATESCALE','var') || isempty(STV_STATESCALE)
    if STV_ZSTATE, STV_STATESCALE = 'z'; else, STV_STATESCALE = 'rank'; end
end
switch STV_STATESCALE
    case 'rank', STATESCALE_DESC = 'within-session PERCENTILE (0-1)';
    case 'norm', STATESCALE_DESC = 'normalized 0-1 per session (p1-p99, clipped)';
    case 'raw',  STATESCALE_DESC = 'RAW (physical units)';
    case 'z',    STATESCALE_DESC = 'z-scored within session x amp';
    otherwise,   error('[STV] STV_STATESCALE must be ''rank'', ''norm'', ''raw'' or ''z''.');
end
if ~exist('STV_FS','var')        || isempty(STV_FS),        STV_FS = 35;         end
if ~exist('STV_PLOT','var')      || isempty(STV_PLOT),      STV_PLOT = true;     end
STV_FIGDIR = fullfile(here,'figs','state_trialvar');
if ~exist(STV_FIGDIR,'dir'), mkdir(STV_FIGDIR); end

fs   = STV_FS;
tAxis = -3 : 1/fs : 3;                       % dfImp column timebase (matches load_experiments tWin=3)
% NOTE: the state and sham windows are DISJOINT. Which one is derived from the other depends on
% STV_PWR_WIN -- see the block below. Default: state fixed at [-1,0), sham placed before it.
switch lower(STV_STATE_WIN)
    case 'peri', stWin = [nan,  0.5];
    otherwise,   stWin = [nan, -1/fs];       % strictly pre-onset
end

% ---- THE STIM-FREE CONTROL WINDOW (rebuilt 2026-08-12, user) -----------------------------------
% Peak_imp under peak_mode=3 is the MEAN over 0-200 ms, i.e. an L-sample window mean. A control for
% it must be the SAME STATISTIC over the SAME NUMBER OF SAMPLES. The first version of this script
% averaged the whole ~34-sample pre window, which is quieter by construction and therefore not a
% control at all -- it understated the ongoing contribution and made the comparison meaningless.
% It is also placed at -1.0 s, OUTSIDE the -0.5..0 s baseline that dfImp has already had removed;
% a sham window inside that baseline is partially constrained toward zero (measured: var 8.0 inside
% vs 17.3 outside, i.e. the constrained version halves the ongoing variance it is meant to estimate).
% DISJOINTNESS (2026-08-12, user asked what the windows were and the overlap surfaced): the sham must
% NOT sit inside the state window. It did -- 7 of the 34 state samples WERE the sham -- which makes the
% control for the power markers partly circular: the sham peak's deviation is built from the very
% samples whose variance is the predictor.
% 2026-08-12 bought that disjointness by pushing the STATE window later (-0.8 s), costing 7 of 34
% state samples. 2026-10-02 buys the SAME disjointness by moving the SHAM EARLIER instead, so the
% state window keeps the full stated [-1, 0) and nothing is spent. The sham's real requirement was
% only to sit outside the removed -0.5..0 s baseline, which -1.2..-1.03 s satisfies; it was never
% required to be at exactly -1.0 s. Asserted below, both ways.
iOn   = find(tAxis >= 0, 1);
Lresp = numel(iOn+2 : iOn + round(0.22*fs));            % response-window length (7 samples)
if strcmpi(STV_PWR_WIN,'legacy')
    % PRE-2026-10-02: sham pinned at -1.0 s, state window pushed to start after it.
    iSham = find(tAxis >= -1.0, 1) + (0:Lresp-1);
    stWin(1) = tAxis(iSham(end)) + 1/fs;
    iState   = tAxis >= stWin(1) & tAxis <= stWin(2);   % float compare: silently yields 79:104
else
    % State window FIXED at [-1, 0); sham placed to end one sample before it. Integer column
    % arithmetic, so no boundary sample is lost to a 1e-16 float comparison.
    iEnd  = iOn - 1;                                    % strictly pre-onset
    if strcmpi(STV_STATE_WIN,'peri'), iEnd = iOn + round(0.5*fs); end   % A4 comparison window
    iPow  = (iOn - round(1.0*fs)) : iEnd;               % cols 71:105 (35 samples) when 'pre'
    iSham = (iPow(1) - Lresp) : (iPow(1) - 1);          % cols 64:70, -1.200 to -1.029 s
    assert(iSham(1) >= 1, '[STV] sham window runs off the start of the trace');
    iState = false(size(tAxis));  iState(iPow) = true;
    stWin  = [tAxis(iPow(1)), tAxis(iPow(end))];
end
assert(~any(ismember(find(iState), iSham)), '[STV] state and sham windows overlap');
assert(tAxis(iSham(end)) < -0.5, '[STV] sham window has entered the removed -0.5..0 s baseline');

% ---- MOTION WINDOW: decoupled from iState (user, 2026-10-02) -------------------------------------
% Motion gets the [-1, 0) s window the manuscript actually states. It CANNOT share iState, because
% iState was pushed to start at -0.8 s so it would not overlap the sham -- and the sham occupies
% -1.000 to -0.829 s, i.e. the first fifth of [-1, 0). That disjointness exists to stop the POWER
% markers (PVv/DPa/DPr) being built from the same samples as the control they are tested against;
% both come from `df`. Motion does not: it comes from `imp.motTrace` (FaceMap), an independent
% channel, so an overlap with a df-derived sham carries no circularity. Keeping one shared window
% would mean either motion losing the stated [-1,0) or the power markers regaining the circularity.
%
% Integer column arithmetic, NOT `tAxis >= a & tAxis <= b`: the floating-point form silently drops
% boundary samples (it costs iState 2 of its intended 28 -- tAxis(78) misses stWin(1) by 1e-16).
iMot = (iOn - round(1.0*fs)) : (iOn - 1);        % [-1 s, -1/fs], 35 samples, strictly pre-onset
if strcmpi(STV_MOT_WIN,'legacy'), iMot = find(iState); end   % reproduce the pre-2026-10-02 numbers
assert(iMot(1) >= 1 && iMot(end) < iOn, '[STV] motion window outside the trace or not pre-onset');

MK = { 'MOT','Motion',            true,  local_tern(strcmpi(STV_MOT_STAT,'sq'),'mean z^2 (motion)','motion z-score')
       'PVv','Pre-trial variance',false, '(\DeltaF/F)^2'
       'DPa','Abs \delta power',  false, '(\DeltaF/F)^2'
       'DPr','Rel \delta',        true,  '2-4 / 0.4-10 Hz' };
% The unit strings above describe the RAW marker. Under 'norm'/'z' the analysis axis is no longer
% in those units, and an axis labelled with units it is not in is worse than one with none.
switch STV_STATESCALE
    case 'rank', MK(:,4) = {'within-session percentile'};
    case 'norm', MK(:,4) = {'normalized 0-1'};
    case 'z',    MK(:,4) = {'z within session \times amp'};
end
nMK = size(MK,1);
% Claim: motion DECREASES spread (trend < 0); the other three keep it SAME or HIGHER (trend >= 0).
claimDir = [-1; +1; +1; +1];

rng(7,'twister');

%% ================= (1) build the per-trial table, all sessions ==================================
T = struct('sess',[], 'amp',[], 'dev',[], 'devPre',[], 'devRaw',[], 'shmRaw',[], ...
           'MOT',[], 'PVv',[], 'DPa',[], 'DPr',[]);
nExp_s = numel(allExperiments);
labels = cell(nExp_s,1);
fprintf('\n[STV] state window %s = [%.2f %.2f] s | %d bins | %d bootstrap\n', ...
        upper(STV_STATE_WIN), stWin(1), stWin(2), STV_NBIN, STV_NBOOT);
fprintf('[STV] motion window %s = [%.2f %.2f] s (%d smp), stat = %s\n', upper(STV_MOT_WIN), ...
        tAxis(iMot(1)), tAxis(iMot(end)), numel(iMot), upper(STV_MOT_STAT));
fprintf(['[STV] power  window %+0.3f .. %+0.3f s (%d samples, df = %.3f Hz, %d bins in 2-4 Hz)\n' ...
         '[STV] sham   window %+0.3f .. %+0.3f s (%d samples)\n'], ...
        stWin(1), stWin(2), nnz(iState), fs/nnz(iState), ...
        nnz((0:nnz(iState)-1)*(fs/nnz(iState)) >= 2 & (0:nnz(iState)-1)*(fs/nnz(iState)) <= 4), ...
        tAxis(iSham(1)), tAxis(iSham(end)), numel(iSham));

for e = 1:nExp_s
    imp = allExperiments(e).imp;
    labels{e} = sprintf('%s %s e%d', allExperiments(e).mn, allExperiments(e).td, allExperiments(e).en);
    nA = numel(imp.uAmp);
    for a = 1:nA
        df = imp.dfImp{a};  pk = imp.Peak_imp{a}(:);
        if isempty(df) || isempty(pk), continue; end
        n = min([size(df,1), numel(pk), size(imp.motTrace{a},1)]);
        if n < 8, continue; end                       % need enough trials for a spread estimate
        df = df(1:n,:);  pk = pk(1:n);

        % --- DV: SIGNED deviation from the amplitude mean, scaled by within-amp SD --------------
        d  = pk - mean(pk,'omitnan');
        sd = std(d,'omitnan');   if ~isfinite(sd) || sd == 0, continue; end
        dev = d / sd;

        % --- stim-free control: MATCHED SHAM PEAK (same statistic, same length, no stimulus) -----
        pre  = mean(df(:, iSham), 2, 'omitnan');
        dpc  = pre - mean(pre,'omitnan');
        sdp  = std(dpc,'omitnan');   if ~isfinite(sdp) || sdp == 0, sdp = eps; end
        devPre = dpc / sdp;

        % --- state markers, all from the SAME pre-onset window -----------------------------------
        seg  = df(:, iState);
        motSeg = imp.motTrace{a}(1:n, iMot);
        switch lower(STV_MOT_STAT)
            case 'sq', mot = mean(motSeg.^2, 2, 'omitnan');   % SECONDARY comparison
            otherwise, mot = mean(motSeg,    2, 'omitnan');   % PRIMARY (monotone in trial energy)
        end
        pvv  = var(seg, 0, 2, 'omitnan');
        [dpa, dpr] = local_delta(seg, fs);

        T.sess   = [T.sess;   repmat(e,n,1)];
        T.amp    = [T.amp;    repmat(a,n,1)];
        T.dev    = [T.dev;    dev];
        T.devPre = [T.devPre; devPre];
        T.devRaw = [T.devRaw; d];       % RAW dF/F, for the variance decomposition below
        T.shmRaw = [T.shmRaw; dpc];     % scaling to SD=1 would destroy the magnitude comparison
        T.MOT    = [T.MOT;    mot];
        T.PVv    = [T.PVv;    pvv];
        T.DPa    = [T.DPa;    dpa];
        T.DPr    = [T.DPr;    dpr];
    end
end
fprintf('[STV] %d trials from %d sessions\n', numel(T.dev), numel(unique(T.sess)));

% ---- optional MOTION EXCLUSION (STV_MOTEXCL, added 2026-08-19) ---------------------------------
% Drops high-motion trials from the POOL entirely, so a surviving state effect cannot be movement
% wearing a different label. Threshold is the same locked project motThresh the split below uses,
% so it is not a free parameter chosen here. Off by default -- the published 2J/2K keep all trials
% and treat motion as one of the states.
% NOTE the DV was already scaled within (session x amplitude) using ALL trials of that cell, and
% that is deliberate: holding the scaling fixed keeps an excluded-trial panel on the same y-axis
% as the full one, so the two can be read against each other.
if ~exist('STV_MOTEXCL','var') || isempty(STV_MOTEXCL), STV_MOTEXCL = false; end
if ~exist('STV_MOTTHR','var')  || isempty(STV_MOTTHR),  STV_MOTTHR  = 1.5;   end
if STV_MOTEXCL
    keepM = T.MOT <= STV_MOTTHR;
    fnT = fieldnames(T);
    for iF = 1:numel(fnT), T.(fnT{iF}) = T.(fnT{iF})(keepM); end
    fprintf('[STV] MOTION EXCLUSION on: dropped %d/%d trials (motion z > %.1f), %d remain\n', ...
            nnz(~keepM), numel(keepM), STV_MOTTHR, nnz(keepM));
end

% Analysis copy of each marker. See STV_STATESCALE at the top for what each mode costs.
grp = findgroups(T.sess, T.amp);

% PER-SESSION NORMALIZER (user 2026-09-13): the raw prediction-error panels sit on a large,
% session-specific %dF/F baseline, so the quartile modulation is buried and the two panels are
% not on a common scale. Rescale each session's raw residual by that session's OWN characteristic
% spread (within-(session x amplitude)-cell pooled SD over all of its trials), so every session
% enters at unit scale and the pooled per-bin curve reads as "x the session-typical error"
% (~1 by construction). This is the spread-DV form of dividing by the session mean, and it is
% session-fair for the same reason the LME clusters on session. devRawN is marker-independent
% (depends only on grp), so compute it once here; the per-bin re-pool happens inside the loop.
uSn_norm = unique(T.sess).';
sigSess  = nan(size(uSn_norm));
for si = 1:numel(uSn_norm)
    inS = T.sess == uSn_norm(si);
    num = 0; den = 0;
    for cc = unique(grp(inS)).'
        v = T.devRaw(inS & grp == cc);  v = v(isfinite(v));
        if numel(v) < 3, continue; end
        num = num + (numel(v)-1)*var(v);  den = den + (numel(v)-1);
    end
    if den > 0, sigSess(si) = sqrt(num/den); end
end
devRawN = T.devRaw;
for si = 1:numel(uSn_norm)
    if isfinite(sigSess(si)) && sigSess(si) > 0
        m = T.sess == uSn_norm(si);  devRawN(m) = T.devRaw(m) / sigSess(si);
    end
end

for k = 1:nMK
    v = double(T.(MK{k,1})(:));
    switch STV_STATESCALE
        case 'z',    v = local_zby(v, grp);
        case 'norm', v = local_normby(v, T.sess);
        case 'rank', v = local_rankby(v, T.sess);
    end
    T.([MK{k,1} 'z']) = v;
end
fprintf('[STV] state scaling: %s\n', STATESCALE_DESC);

%% ================= (2) the scale tests ===========================================================
R = struct();
fprintf('\n%-22s %7s %9s %9s %8s %6s | %8s %11s | %7s %6s  %s\n', ...
        'state','n','rho|dev|','p','strat','agree','SDratio','CI95','BF p','trend','verdict');
for k = 1:nMK
    st = T.([MK{k,1} 'z']);
    ok = isfinite(st) & isfinite(T.dev);
    x  = st(ok);  y = T.dev(ok);  yp = T.devPre(ok);

    % --- primary: continuous scale test (Levene score |dev| vs state) -------------------------
    [rho,  p ]  = corr(abs(y),  x, 'type','Spearman');
    [rhoP, pP]  = corr(abs(yp), x, 'type','Spearman');    % stim-free control

    % --- SESSION-STRATIFIED rho: weighted mean of the WITHIN-session correlations ---------------
    % With RAW states the pooled rho can in principle be manufactured by between-session offsets
    % (a session with more motion AND less variability would do it). This estimate never compares
    % one session to another, so if it agrees with the pooled number that explanation is dead.
    uSs = unique(T.sess).';
    rs = nan(1,numel(uSs));  ws = zeros(1,numel(uSs));
    for ii = 1:numel(uSs)
        mm = (T.sess == uSs(ii)) & ok;
        if nnz(mm) < 20, continue; end
        rs(ii) = corr(abs(T.dev(mm)), st(mm), 'type','Spearman');
        ws(ii) = nnz(mm);
    end
    keepS = isfinite(rs) & ws > 0;   rs = rs(keepS);  ws = ws(keepS);
    rhoStrat = sum(rs.*ws) / max(sum(ws), eps);
    nSessAgree = nnz(sign(rs) == sign(rhoStrat));

    % --- SESSION-AWARE scale test: mixed model |dev| ~ state + (1|session) ---------------------
    % The pooled rho/p above treat 1767 trials as independent (pseudoreplication -- the exact
    % objection Nick raised for the controller Fig-4 quartiles). |dev| is the amplitude-scaled
    % deviation, so its MEAN across state is a Levene-style SCALE test; clustering on session with
    % a random intercept gives a p that respects the 4-session / 3-mouse structure. Random slope
    % is not identifiable from 4 clusters, so intercept only; mouse noted in the caption.
    pLME = NaN; pLMEsat = NaN; bLME = NaN; tLME = NaN; dfLME = NaN; ciLME = [NaN NaN];
    try
        tlme = table(abs(y), x, categorical(T.sess(ok)), 'VariableNames', {'adev','state','sess'});
        % REML + Satterthwaite (2026-10-07), matching utils/cl_olcl_lmm.m and the Methods.
        % NB: with an intercept-only session term the state slope is a WITHIN-session
        % contrast, so its Satterthwaite df stay near the trial count; the session-level
        % evidence is the n-of-4 sign agreement (nSessAgree), reported alongside.
        lme  = fitlme(tlme, 'adev ~ state + (1|sess)', 'FitMethod','REML');
        [~,~,Cl] = fixedEffects(lme, 'DFMethod','Satterthwaite'); Cl = dataset2table_safe(Cl);
        Cl   = lmm_cluster_df(Cl, numel(unique(T.sess(ok))));   % df <= nSess-1, shared rule
        ixb  = strcmp(cellstr(string(Cl.Name)), 'state');
        bLME = Cl.Estimate(ixb);  pLME = Cl.pValueC(ixb);  pLMEsat = Cl.pValue(ixb);
        tLME = Cl.tStat(ixb);     dfLME = Cl.DFc(ixb);  ciLME = [Cl.LowerC(ixb) Cl.UpperC(ixb)];
    catch MEl
        fprintf('   [STV] LME failed for %s: %s\n', MK{k,2}, MEl.message);
    end

    % --- POWER-PARTIALLED rho: what survives once signal amplitude is removed ------------------
    % log(pre-trial variance) is the gain axis. Absolute delta partials to ~0 here because it IS
    % power; anything that survives is carrying information beyond loudness.
    lgP = log(max(T.PVv(ok), eps));
    if strcmp(MK{k,1},'PVv')       % partialling pre-var on itself is degenerate, not a result
        rhoPow = NaN; pPow = NaN; rhoPowC = NaN; pPowC = NaN;
    else
        [rhoPow,  pPow ] = partialcorr(abs(y),  x, lgP, 'type','Spearman');
        [rhoPowC, pPowC] = partialcorr(abs(yp), x, lgP, 'type','Spearman');
    end

    % --- binned SD curve + Brown-Forsythe ------------------------------------------------------
    g   = local_qbin(x, STV_NBIN);
    sdB = arrayfun(@(b) std(y(g==b), 'omitnan'),  1:STV_NBIN);
    sdP = arrayfun(@(b) std(yp(g==b),'omitnan'),  1:STV_NBIN);
    bf  = local_bftest(y,  g);
    bfP = local_bftest(yp, g);

    % --- the SAME curve in %dF/F: PREDICTION UNCERTAINTY --------------------------------------
    % (user, 2026-08-19: "sd of dev is not a great explainer, we should use something simpler
    %  like prediction error in its correct units".) `y` is the deviation from the amplitude
    % mean scaled by the within-amplitude SD, so std(y) is ~1 by construction and unitless --
    % it can only say "wider or narrower than average", never how wide.
    %
    % The interpretable quantity is the residual of the simplest possible predictor: knowing
    % only the laser amplitude, predict the amplitude mean. What is left is T.devRaw, in
    % %dF/F, and its SD within a state bin is literally "if you predict the impulse response
    % from the drive alone, in this state you will be off by about this much".
    %
    % Pooled WITHIN (session x amplitude) cell, not across them. A plain std over the bin
    % would inherit the between-amplitude spread of response size -- a bin holding more
    % high-amplitude trials would look more uncertain purely because its responses are
    % bigger. Pooling within cells is the same reason the DV was scaled per amplitude in the
    % first place; this keeps that protection AND keeps the units.
    sdRaw = nan(1, STV_NBIN);
    for b = 1:STV_NBIN
        inB = (g == b);
        num = 0; den = 0;
        for cc = unique(grp(inB)).'
            v = T.devRaw(inB & grp == cc);
            v = v(isfinite(v));
            if numel(v) < 3, continue; end
            num = num + (numel(v)-1) * var(v);
            den = den + (numel(v)-1);
        end
        if den > 0, sdRaw(b) = sqrt(num/den); end
    end
    % SAME curve, per-session normalized (see PER-SESSION NORMALIZER above): within-cell pooled
    % SD of the session-rescaled residual devRawN. Dimensionless, ~1 = session-typical error.
    sdRawN = nan(1, STV_NBIN);
    for b = 1:STV_NBIN
        inB = (g == b);
        num = 0; den = 0;
        for cc = unique(grp(inB)).'
            v = devRawN(inB & grp == cc);  v = v(isfinite(v));
            if numel(v) < 3, continue; end
            num = num + (numel(v)-1)*var(v);  den = den + (numel(v)-1);
        end
        if den > 0, sdRawN(b) = sqrt(num/den); end
    end
    trend  = corr((1:STV_NBIN).', sdB(:), 'type','Spearman');
    trendP = corr((1:STV_NBIN).', sdP(:), 'type','Spearman');

    % --- effect size: SD(top bin)/SD(bottom bin) with a bootstrap CI ---------------------------
    rat = sdB(end)/max(sdB(1),eps);
    bs  = nan(STV_NBOOT,1);
    nO  = numel(y);
    for b = 1:STV_NBOOT
        s  = randi(nO, nO, 1);
        gb = local_qbin(x(s), STV_NBIN);
        lo = std(y(s(gb==1)),'omitnan');  hi = std(y(s(gb==STV_NBIN)),'omitnan');
        bs(b) = hi/max(lo,eps);
    end
    ci = quantile(bs, [0.025 0.975]);

    % --- claim check ---------------------------------------------------------------------------
    % A claim passes only if (a) the spread moves in the predicted direction, (b) it is
    % significant, and (c) it beats the stim-free control -- otherwise it is ongoing signal power.
    if claimDir(k) < 0
        moved = rho < 0 && p < 0.05 && ci(2) < 1;
    else
        moved = rho >= 0 || p >= 0.05;                 % "same or higher" -> only a DECREASE fails
    end
    beatsCtl = abs(rho) > abs(rhoP);
    if ~MK{k,3}
        verdict = 'CONFOUND - not interpreted';
    elseif moved && beatsCtl
        verdict = 'PASS';
    elseif moved
        verdict = 'pass, but NOT above stim-free control';
    else
        verdict = 'FAIL';
    end

    fprintf('%-22s %7d %9.3f %9.3g %8.3f %4d/%d | %8.2f %5.2f-%5.2f | %7.4f %6.2f  %s\n', ...
            MK{k,2}, nnz(ok), rho, p, rhoStrat, nSessAgree, numel(rs), ...
            rat, ci(1), ci(2), bf, trend, verdict);
    fprintf('%-22s %7s %9.3f %9.3g %8s %6s | %8s %11s | %7.4f %6.2f   <- STIM-FREE CONTROL\n', ...
            '  (pre-onset ctrl)','', rhoP, pP, '', '', '', '', bfP, trendP);
    if isfinite(rhoPow)
        fprintf('%-22s %7s %9.3f %9.3g %8s %6s | %8s %11s | %7s %6s   <- POWER-PARTIALLED (ctrl %+.3f)\n', ...
                '  (| log PreVar)','', rhoPow, pPow, '', '', '', '', '', '', rhoPowC);
    else
        fprintf('%-22s %7s %9s %9s %8s %6s | %8s %11s | %7s %6s   <- POWER-PARTIALLED n/a (marker IS the covariate)\n', ...
                '  (| log PreVar)','', '--','--','', '', '', '', '', '');
    end

    fprintf('%-22s %7s beta=%+.4f  p=%.3g   %d/%d sess agree (strat rho %+.3f)   <- SESSION-CLUSTERED LME (1|sess)\n', ...
            '  (session-aware)','', bLME, pLME, nSessAgree, numel(rs), rhoStrat);

    R(k).tag=MK{k,1}; R(k).name=MK{k,2}; R(k).adm=MK{k,3};
    R(k).rho=rho; R(k).p=p; R(k).rhoP=rhoP; R(k).pP=pP;
    R(k).sdB=sdB; R(k).sdP=sdP; R(k).bf=bf; R(k).bfP=bfP;
    R(k).sdRaw = sdRaw;    % same curve in %dF/F -- see the PREDICTION UNCERTAINTY block above
    R(k).sdRawN = sdRawN;  % same curve, per-session normalized (x session-typical error, ~1)
    R(k).trend=trend; R(k).trendP=trendP; R(k).ratio=rat; R(k).ci=ci;
    R(k).verdict=verdict; R(k).x=x; R(k).y=y; R(k).n=nnz(ok);
    R(k).rhoStrat=rhoStrat; R(k).rhoPerSess=rs; R(k).nSessAgree=nSessAgree;
    R(k).pLME=pLME; R(k).bLME=bLME; R(k).tLME=tLME; R(k).pLMEsat=pLMEsat; R(k).dfLME=dfLME; R(k).ciLME=ciLME; R(k).nSess=numel(rs);   % session-clustered scale test
    R(k).rhoPow=rhoPow; R(k).pPow=pPow; R(k).rhoPowC=rhoPowC; R(k).pPowC=pPowC;
    R(k).binMed = arrayfun(@(b) median(x(g==b),'omitnan'), 1:STV_NBIN);   % raw value per bin
    R(k).gbin   = g;    % bin index per trial -- so imp_state_trialvar_fig can bootstrap per-bin CIs
    R(k).sess   = T.sess(ok);
    R(k).units = MK{k,4};
end

% --- SESSION-LEVEL CI for the quartile ratio (review 2026-10-10) ----------------------------
% The trial bootstrap above treats 1767 trials as independent; the test beside the ratio is
% session-level (df = nSess-1), so the reported interval is too. R(k).ci is now the HIERARCHICAL
% bootstrap (sessions, then trials within session); the old trial-level interval is kept as
% R(k).ciTrial. Point estimate unchanged. See impulse-analysis/imp_state_hboot.m.
for k = 1:numel(R), R(k).ciTrial = R(k).ci; end
STV_H = imp_state_hboot(R, 10000, STV_NBIN, 1);
for k = 1:numel(R), R(k).ci = STV_H(k).ciHier; R(k).ratioPerSess = STV_H(k).perSess; end

%% ================= (2b) MOTION: threshold split, because quantile bins are degenerate ===========
% RAW motion is threshold-shaped: median -0.196, q75 -0.158, and only ~3% of trials exceed z=1.5.
% Equal-count quartiles therefore put bins 1-3 inside a 0.10-wide sliver of motion and the "trend"
% across them is noise -- the real contrast is top-tail vs the rest. This uses the LOCKED project
% constant motThresh = 1.5 (root CLAUDE.md) so the split is not a free parameter chosen here.
if ~exist('STV_MOTTHR','var') || isempty(STV_MOTTHR), STV_MOTTHR = 1.5; end
hiM = T.MOT > STV_MOTTHR;
if STV_MOTEXCL || ~any(hiM)
    % Nothing above threshold -- STV_MOTEXCL already removed it. The split would divide by an
    % empty group and report NaN ratios that look like results.
    MTS = struct('thr',STV_MOTTHR,'nLo',nnz(~hiM),'nHi',0,'skipped',true);
    fprintf('\n[STV] motion threshold split SKIPPED (no trials above z > %.1f).\n', STV_MOTTHR);
else
MTS = struct('thr',STV_MOTTHR,'nLo',nnz(~hiM),'nHi',nnz(hiM));
MTS.sdLo   = std(T.dev(~hiM),'omitnan');     MTS.sdHi   = std(T.dev(hiM),'omitnan');
MTS.sdLoP  = std(T.devPre(~hiM),'omitnan');  MTS.sdHiP  = std(T.devPre(hiM),'omitnan');
MTS.ratio  = MTS.sdHi/max(MTS.sdLo,eps);     MTS.ratioP = MTS.sdHiP/max(MTS.sdLoP,eps);
MTS.p  = local_bftest(T.dev,    double(hiM));
MTS.pP = local_bftest(T.devPre, double(hiM));
fprintf(['\nMOTION THRESHOLD SPLIT at z > %.1f   (n low %d, n high %d)\n' ...
         '   impulse response   SD %.3f -> %.3f   ratio %.2f   BF p %.3g\n' ...
         '   STIM-FREE control  SD %.3f -> %.3f   ratio %.2f   BF p %.3g\n'], ...
         STV_MOTTHR, MTS.nLo, MTS.nHi, MTS.sdLo, MTS.sdHi, MTS.ratio, MTS.p, ...
         MTS.sdLoP, MTS.sdHiP, MTS.ratioP, MTS.pP);
if MTS.ratioP <= MTS.ratio * 1.10
    fprintf(2,['   ** the STIM-FREE control compresses by the SAME factor (%.2f vs %.2f).\n' ...
               '      Motion reduces the variability of the ONGOING SIGNAL, and the impulse\n' ...
               '      response inherits it -- this is NOT a statement about stimulus processing. **\n'], ...
               MTS.ratioP, MTS.ratio);
end
% ---- IS THE RESPONSE ITSELF MORE REPRODUCIBLE, OR IS THE MEASUREMENT JUST QUIETER? -------------
% (user, 2026-08-12: "the claim is that motion makes the response more predictable ... if it does
%  for the non-stim case is of no consequence".) Correct, and the earlier framing of the control as
%  a SPECIFICITY test was wrong. But there IS a question the control must answer: dev is measured on
%  the actual trace, so var(dev) = response variability + ongoing activity sitting in the window. If
%  motion only shrank the second term the response would not be more reproducible -- the measurement
%  would merely be cleaner. Those are different claims and they look identical in var(dev) alone.
%  Resolved by REGRESSION, not subtraction: obs and sham are correlated (r = +0.39, the ongoing
%  signal is slow), so var(obs) - var(sham) assumes an independence that does not hold. Fit
%  obs ~ b*sham on the LOW-motion trials, apply that b to both groups, and compare the RESIDUAL
%  variance -- what is left of the response once the part predictable from a stim-free window is
%  removed. All in RAW dF/F, because the SD-normalised copies are 1 by construction.
bSham = T.shmRaw(~hiM) \ T.devRaw(~hiM);
resid = T.devRaw - bSham * T.shmRaw;
MTS.bSham = bSham;
MTS.vObs  = [var(T.devRaw(~hiM)) var(T.devRaw(hiM))];
MTS.vShm  = [var(T.shmRaw(~hiM)) var(T.shmRaw(hiM))];
MTS.vRes  = [var(resid(~hiM))    var(resid(hiM))];
fprintf(['\n   VARIANCE DECOMPOSITION (raw dF/F, sham peak at %.2f s, b = %.3f)\n' ...
         '   %-14s %10s %10s %10s\n'], tAxis(iSham(1)), bSham, 'group','var(obs)','var(sham)','var(resid)');
fprintf('   %-14s %10.3f %10.3f %10.3f\n', 'low motion',  MTS.vObs(1), MTS.vShm(1), MTS.vRes(1));
fprintf('   %-14s %10.3f %10.3f %10.3f\n', 'HIGH motion', MTS.vObs(2), MTS.vShm(2), MTS.vRes(2));
fprintf('   %-14s %10.2f %10.2f %10.2f\n', 'ratio hi/lo', MTS.vObs(2)/MTS.vObs(1), ...
        MTS.vShm(2)/MTS.vShm(1), MTS.vRes(2)/MTS.vRes(1));
MTS.ratioRes = MTS.vRes(2)/MTS.vRes(1);
if MTS.ratioRes < MTS.vShm(2)/MTS.vShm(1)
    fprintf(['   -> the RESIDUAL falls MORE than the ongoing signal does, so the response is\n' ...
             '      genuinely more reproducible in motion -- not merely less contaminated.\n']);
end
MTS.resPerSess = nan(numel(unique(T.sess)),1);
for i = 1:numel(unique(T.sess))
    uu = unique(T.sess); kk = T.sess == uu(i);
    if nnz(kk & hiM) < 8, continue; end
    MTS.resPerSess(i) = var(resid(kk & hiM)) / max(var(resid(kk & ~hiM)), eps);
end
fprintf('   per session residual ratio: %s\n', ...
        strjoin(compose('%.2f', MTS.resPerSess(isfinite(MTS.resPerSess))).', '  '));

MTS.perSess = nan(numel(unique(T.sess)),1);
uSm = unique(T.sess).';
for i = 1:numel(uSm)
    kk = T.sess == uSm(i);
    if nnz(kk & hiM) < 8, continue; end
    MTS.perSess(i) = std(T.dev(kk & hiM),'omitnan') / max(std(T.dev(kk & ~hiM),'omitnan'), eps);
end
end   % STV_MOTEXCL / no high-motion trials -> whole split block skipped

%% ================= (3) per-session replication of the admissible markers ========================
uS = unique(T.sess).';
fprintf('\nPER-SESSION rho(|dev|, state)   [admissible markers only]\n');
fprintf('%-28s %6s', 'session', 'n');
adm = find([MK{:,3}]);
for k = adm, fprintf(' %14s', MK{k,2}); end
fprintf('\n');
PS_rho = nan(numel(uS), nMK);
for i = 1:numel(uS)
    m = T.sess == uS(i);
    fprintf('%-28s %6d', labels{uS(i)}, nnz(m));
    for k = 1:nMK
        st = T.([MK{k,1} 'z']);
        okk = m & isfinite(st) & isfinite(T.dev);
        if nnz(okk) < 20, continue; end
        [rr, pp] = corr(abs(T.dev(okk)), st(okk), 'type','Spearman');
        PS_rho(i,k) = rr;
        if ismember(k, adm)
            star = '';  if pp < 0.05, star = '*'; end
            fprintf(' %13s', sprintf('%+.3f%s', rr, star));
        end
    end
    fprintf('\n');
end

%% ================= (4) figures ===================================================================
if STV_PLOT
    C.stim=[0.80 0.15 0.15]; C.ctl=[0.55 0.55 0.55];
    % PLOT ONLY THE ADMISSIBLE MARKERS (user, 2026-08-12). Pre-trial variance and absolute delta
    % are still computed and printed above -- they belong in the record -- but they are not drawn,
    % because a panel of a quantity that IS signal power plotted against a spread invites exactly
    % the reading the confound forbids. Set STV_PLOTCONF=true to draw all four.
    if ~exist('STV_PLOTCONF','var') || isempty(STV_PLOTCONF), STV_PLOTCONF = false; end
    if STV_PLOTCONF, kShow = 1:nMK; else, kShow = find([MK{:,3}]); end
    % DRAW THE STIM-FREE CONTROL? (user, 2026-08-12: "i dont need control on this analysis just yet").
    % PLOTTING knob only -- the control is still computed and still printed in the table above, so
    % nothing is lost from the record and no verdict silently changes. Turning it back on is one
    % variable. Do NOT ship a paper panel with this false: the motion claim rests on the response
    % tightening MORE than the ongoing signal does, which is unreadable without the grey trace.
    if ~exist('STV_PLOTCTRL','var') || isempty(STV_PLOTCTRL), STV_PLOTCTRL = true; end
    nC = numel(kShow);
    f1 = figure('Color','w','Position',[40 40 460*nC 720], ...
                'Name','[STV] trial variability vs brain state');
    tl = tiledlayout(f1, 3, nC, 'Padding','compact','TileSpacing','compact');

    for ci = 1:nC
        k  = kShow(ci);
        gc = local_tern(MK{k,3}, [0 0 0], [0.55 0.55 0.55]);

        % row 1 -- the funnel: SIGNED dev vs state, with the binned +/-SD envelope
        ax = nexttile(tl, ci); hold(ax,'on'); box(ax,'on');
        scatter(ax, R(k).x, R(k).y, 5, [0.55 0.65 0.85], 'filled', 'MarkerFaceAlpha',0.30);
        bc = local_bincentres(R(k).x, STV_NBIN);
        plot(ax, bc,  R(k).sdB, '-o','Color',C.stim,'MarkerFaceColor',C.stim,'LineWidth',1.6,'MarkerSize',4);
        plot(ax, bc, -R(k).sdB, '-o','Color',C.stim,'MarkerFaceColor',C.stim,'LineWidth',1.6,'MarkerSize',4);
        yline(ax,0,'k:'); ylim(ax,[-4 4]); xlim(ax, quantile(R(k).x,[0.005 0.995]));
        xlabel(ax, sprintf('%s  (%s)', MK{k,2}, MK{k,4}));
        if ci==1, ylabel(ax,'signed dev (within-amp SD)'); end
        title(ax, sprintf('%s   n=%d', MK{k,2}, R(k).n), 'FontSize',9, 'Color',gc);

        % row 2 -- spread vs state, STIM against the STIM-FREE control
        ax = nexttile(tl, nC+ci); hold(ax,'on'); box(ax,'on'); grid(ax,'on');
        % x placed at each bin's MEDIAN RAW VALUE, so the drop can be read against real units
        % ("SD falls between motion 0.2 and motion 2.5") rather than against a bin index.
        bm = R(k).binMed;
        plot(ax, bm, R(k).sdB, '-o','Color',C.stim,'MarkerFaceColor',C.stim, ...
             'LineWidth',1.8,'MarkerSize',5,'DisplayName','impulse response');
        if STV_PLOTCTRL
            plot(ax, bm, R(k).sdP, '--s','Color',C.ctl,'MarkerFaceColor',C.ctl, ...
                 'LineWidth',1.4,'MarkerSize',4,'DisplayName','pre-onset (stim-free)');
        end
        xticks(ax, round(bm,2,'significant'));
        xlim(ax, [min(bm) - 0.08*range(bm), max(bm) + 0.08*range(bm)]);
        xlabel(ax, sprintf('%s  (%s), bin median', MK{k,2}, MK{k,4}));
        if ci==1
            ylabel(ax,'SD of dev');
            if STV_PLOTCTRL, legend(ax,'Location','best','Box','off','FontSize',7); end
        end
        if STV_PLOTCTRL
            title(ax, sprintf('BF p = %.4g (ctrl %.4g)\ntrend %+.2f (ctrl %+.2f)', ...
                  R(k).bf, R(k).bfP, R(k).trend, R(k).trendP), 'FontSize',8.5, 'Color',gc);
        else
            title(ax, sprintf('BF p = %.4g\ntrend %+.2f', R(k).bf, R(k).trend), ...
                  'FontSize',8.5, 'Color',gc);
        end

        % row 3 -- effect size with bootstrap CI, against the claim's prediction
        ax = nexttile(tl, 2*nC+ci); hold(ax,'on'); box(ax,'on'); grid(ax,'on');
        % STIM bar beside its STIM-FREE control bar -- the comparison the verdict rests on
        bar(ax, 1, R(k).ratio, 0.5, 'FaceColor', C.stim, 'EdgeColor','none');
        errorbar(ax, 1, R(k).ratio, R(k).ratio-R(k).ci(1), R(k).ci(2)-R(k).ratio, ...
                 'k','LineStyle','none','LineWidth',1.2,'CapSize',10);
        ratP = R(k).sdP(end)/max(R(k).sdP(1),eps);
        if claimDir(k) < 0, ptxt = 'claim: < 1'; else, ptxt = 'claim: \geq 1'; end
        if STV_PLOTCTRL
            bar(ax, 2, ratP, 0.5, 'FaceColor', C.ctl, 'EdgeColor','none');
            xticks(ax,[1 2]); xlim(ax,[0.4 2.6]);
            xticklabels(ax,{sprintf('stim %.2f',R(k).ratio), sprintf('ctrl %.2f',ratP)});
            ttl = sprintf(['%s   strat \\rho %+.3f (%d/%d sess)   ' ...
                  '\\rho|power %+.3f (ctrl %+.3f)\n%s'], ...
                  ptxt, R(k).rhoStrat, R(k).nSessAgree, numel(R(k).rhoPerSess), ...
                  R(k).rhoPow, R(k).rhoPowC, R(k).verdict);
        else
            xticks(ax,1); xlim(ax,[0.4 1.6]);
            xticklabels(ax,{sprintf('%.2f',R(k).ratio)});
            ttl = sprintf('%s   strat \\rho %+.3f (%d/%d sess)   \\rho|power %+.3f', ...
                  ptxt, R(k).rhoStrat, R(k).nSessAgree, numel(R(k).rhoPerSess), R(k).rhoPow);
        end
        yline(ax, 1, 'k-','LineWidth',1);
        if ci==1, ylabel(ax,'SD ratio  top / bottom bin'); end
        title(ax, ttl, 'FontSize',8.5, 'Color',gc);
    end

    if STV_PLOTCTRL
        sgSub = ['RED = impulse response      GREY = SAME window, NO STIMULUS (the control)\n' ...
                 'If grey tracks red, the state changes the ONGOING signal, not stimulus processing.'];
    else
        sgSub = 'Spread of the per-trial deviation from the amplitude mean.';
    end
    % Motion and the power markers no longer share a window (2026-10-02), so the
    % title must name both -- quoting only stWin would mislabel the Motion panel.
    sgtitle(f1, sprintf(['Trial-to-trial VARIABILITY of the impulse response vs brain state   ' ...
        '(%d trials, %d sessions; motion [%.2f %.2f] s, power [%.2f %.2f] s)\n' sgSub], ...
        numel(T.dev), numel(uS), tAxis(iMot(1)), tAxis(iMot(end)), stWin(1), stWin(2)), ...
        'FontWeight','bold','FontSize',10);

    exportgraphics(f1, fullfile(STV_FIGDIR,'stv_claim.png'), 'Resolution',300);

    % ---- per-session replication -----------------------------------------------------------------
    f2 = figure('Color','w','Position',[60 60 640 420],'Name','[STV] per-session');
    ax = axes(f2); hold(ax,'on'); box(ax,'on'); grid(ax,'on');
    cols = lines(nMK);
    for k = 1:nMK
        if ~MK{k,3}, continue; end
        plot(ax, 1:numel(uS), PS_rho(:,k), '-o','Color',cols(k,:),'MarkerFaceColor',cols(k,:), ...
             'LineWidth',1.6,'MarkerSize',5,'DisplayName',MK{k,2});
    end
    hz = yline(ax,0,'k-'); hz.HandleVisibility = 'off';
    xticks(ax,1:numel(uS)); xticklabels(ax, labels(uS)); xtickangle(ax,20);
    ylabel(ax,'\rho( |dev| , state )'); ylim(ax,[-0.5 0.5]);
    legend(ax,'Location','best','Box','off','FontSize',8);
    title(ax, ['Per-session replication, ADMISSIBLE markers only' newline ...
               'H1 needs Motion BELOW zero in every session'], 'FontWeight','bold','FontSize',10);
    exportgraphics(f2, fullfile(STV_FIGDIR,'stv_persession.png'), 'Resolution',300);
end

STV = struct('T',T,'R',R,'labels',{labels},'PS_rho',PS_rho,'stWin',stWin,'nbin',STV_NBIN, ...
             'motSplit',MTS,'scale',STV_STATESCALE,'scaleDesc',STATESCALE_DESC);
fprintf('\n[STV] figures -> %s\n[STV] struct: STV\n', STV_FIGDIR);

%% ================================= local functions ==============================================
function v = local_rankby(v, s)
%LOCAL_RANKBY  Within-session percentile in (0,1). Ties share a rank (tiedrank), so a session that
% sits at rest for most trials does not get its ties spread out into a fake gradient.
v = double(v(:));
for u = unique(s(:)).'
    m = s(:) == u;
    r = tiedrank(v(m));
    v(m) = (r - 0.5) ./ numel(r);
end
end

function v = local_normby(v, s)
%LOCAL_NORMBY  Map v to 0-1 WITHIN each session, anchored on the 1st-99th percentile and clipped.
% Percentiles rather than min/max: a single motion spike sets the max and crushes every other
% trial into the bottom of the axis. Monotone within session, so within-session rank statistics
% are untouched; it only makes sessions commensurable for pooling and plotting.
v = double(v(:));
for u = unique(s(:)).'
    m = s(:) == u;
    q = quantile(v(m), [0.01 0.99]);
    if ~isfinite(q(1)) || ~isfinite(q(2)) || q(2) <= q(1)
        lo = min(v(m));  hi = max(v(m));
        if ~isfinite(hi) || hi <= lo, v(m) = 0; continue; end
        q = [lo hi];
    end
    v(m) = min(max((v(m) - q(1)) ./ (q(2) - q(1)), 0), 1);
end
end

function p = local_bftest(y, g)
%LOCAL_BFTEST  Brown-Forsythe (median-centred Levene, so no normality assumption). NaN if undefined.
p = NaN;
try
    p = vartestn(y, g, 'TestType','BrownForsythe', 'Display','off');
catch
end
end

function [dpa, dpr] = local_delta(seg, fs)
%LOCAL_DELTA  absolute 2-4 Hz power and its RELATIVE share of 0.4-10 Hz, per trial (rows of seg).
% CANONICAL rel-delta bands (2026-09-11): numerator 2-4 Hz, denominator 0.4-10 Hz -- identical to
% utils/cl_reldelta.m (controller) and utils/imp_statedep_trials.m (residual pipeline), so Fig-2 and
% Fig-4 measure the SAME state. (Was 1-4 / 0.5-30 Hz before this date.)
% Mean-removed + Hann so the DC term and edge leakage do not land in the delta band.
n = size(seg,2);
w = hannwin(n).';
x = seg - mean(seg, 2, 'omitnan');
x(~isfinite(x)) = 0;
X = abs(fft(x .* w, [], 2)).^2;
f = (0:n-1) * (fs/n);
half = 1:floor(n/2);
f = f(half);  X = X(:,half);
bD = f >= 2   & f <= 4;      % numerator: 2-4 Hz absolute power (DPa)
bT = f >= 0.4 & f <= 10;     % denominator: 0.4-10 Hz total power
dpa = sum(X(:,bD), 2);
dpr = dpa ./ max(sum(X(:,bT), 2), eps);
end

function z = local_zby(x, g)
x = double(x(:));  z = nan(size(x));
for u = unique(g(:)).'
    m = g(:) == u;
    s = std(x(m),'omitnan');
    if ~isfinite(s) || s == 0, z(m) = 0; else, z(m) = (x(m) - mean(x(m),'omitnan'))/s; end
end
end

function g = local_qbin(x, nb)
% equal-COUNT bins, so every bin's SD is estimated from the same number of trials
q = quantile(x, linspace(0,1,nb+1));  q(1) = -inf; q(end) = inf;
[~,~,g] = histcounts(x, q);
g = max(min(g, nb), 1);
end

function c = local_bincentres(x, nb)
q = quantile(x, linspace(0,1,nb+1));
c = (q(1:end-1) + q(2:end)) / 2;
end

function s = local_tern(c,a,b)
if c, s = a; else, s = b; end
end
