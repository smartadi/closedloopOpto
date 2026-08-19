% impulse-analysis -- extracted from Impulse_mouseDataAnalysis_all.m
% Run from impulse-analysis/ directory.

%% Data analysis Script

% Absolute output root -- immune to MATLAB CWD.
% which() finds this file on the path; fallback to pwd if run section-by-section.
le_path    = which('load_experiments');
if isempty(le_path), le_path = fullfile(pwd, 'load_experiments.m'); end
impulseDir = fileparts(le_path);

% Add utils and impulse-analysis/ itself (so which('contra_prediction') works)
addpath(genpath(fullfile(impulseDir, '..', 'utils')));
addpath(impulseDir);
clear le_path

% add pixel configuration



% Recompute paths wiped by clear all. Prefer which() (finds the on-path file, not
% the temp Editor_* copy MATLAB makes when a section is run); fall back to
% mfilename only if it is not a temp path.
le2 = which('load_experiments');
if ~isempty(le2)
    impulseDir = fileparts(le2);
else
    mf = fileparts(mfilename('fullpath'));
    if ~isempty(mf) && ~(contains(mf, tempdir, 'IgnoreCase', true) || ...
                         contains(mf, 'Editor_', 'IgnoreCase', true))
        impulseDir = mf;
    end   % else keep the impulseDir computed above
end
clear le2 mf
paperRoot  = fullfile(impulseDir, '..', 'paper');

%% experiment name - define all experiments

experiments = {
    'AL_0041', '2025-12-02', 1, 'lightCommand638';
    'AL_0041', '2025-12-02', 2, 'lightCommand638';

    % 'AL_0033', '2025-01-18', 1, 'lightCommand'; % no violet ?
    'AL_0033', '2025-01-29', 1, 'lightCommand';

    % 'AL_0033', '2025-01-29', 1, 'lightCommand';
};

% Storage for combined results
allExperiments = struct();

%% Loop through all experiments
for expIdx = 1:size(experiments, 1)
    mn = experiments{expIdx, 1};
    td = experiments{expIdx, 2};
    en = experiments{expIdx, 3};
    sigName = experiments{expIdx, 4};
    
    fprintf('Processing experiment %d/%d: %s, %s, en=%d, signal=%s\n', ...
        expIdx, size(experiments,1), mn, td, en, sigName);

% get data
% (utils already on path — added before clear all above)
    
    
serverRoot = expPath(mn, td, en);
    
d = loadData(serverRoot,mn,td,en);

% Run Movie
% sigName is now set from experiments array
[tt, v] = getTLanalog(mn, td, en, sigName);
    serverRoot = expPath(mn, td, en);

tInd = 1;
traces(tInd).t = tt;
traces(tInd).v = v;
traces(tInd).name = sigName;
traces(tInd).lims = [0 5];


nSV = 500;

[U, V, t, mimg] = loadUVt(serverRoot, nSV);
%
mv   = d.motion.motion_1(1:2:end);
mv_z = zscore(mv);
% movieWithTracesSVD(U, V, t, traces, [], []);

% find stims

% [stimStarts, stimEnds] = detectStimEvents(tt, v, ...
%     'MinDist', 4, ...
%     'ThreshFrac', 0.05);

[stimStarts, stimEnds, uAmp, idxByAmp] = detectStimEvents_idx(tt, v, ...
    'AmpTol', 0.1, 'MinDist', 4);



% ============================
% FILL MISSING (ZERO) STARTS
% ============================
EventPeriod_sec = 5;                      % expected stim spacing
GapThresh_sec   = 1.5 * EventPeriod_sec;  % trigger insertion
MaxInsert       = 1000;                   % safety cap
DedupTol_sec    = 0.5 * EventPeriod_sec; % de-dup tolerance

detS = stimStarts(:);
insS = [];

if numel(detS) >= 2
    for i = 1:numel(detS)-1
        gap = detS(i+1) - detS(i);

        if gap > GapThresh_sec
            nMissing = round(gap / EventPeriod_sec) - 1;
            if nMissing < 1
                nMissing = floor(gap / EventPeriod_sec) - 1;
            end

            if nMissing > 0
                nMissing = min(nMissing, MaxInsert);
                newS = detS(i) + (1:nMissing)' * EventPeriod_sec;

                % keep strictly inside the gap
                newS = newS(newS < detS(i+1) - 0.25*EventPeriod_sec);

                insS = [insS; newS];
            end
        end
    end
end

% ============================
% REBUILD PER-EVENT AMP FOR DETECTED EVENTS (from uAmp + idxByAmp)
% ============================
nDet = numel(detS);
ampDet = nan(nDet,1);
for k = 1:numel(uAmp)
    ampDet(idxByAmp{k}) = uAmp(k);
end
if any(isnan(ampDet))
    warning('Some detected events were not assigned an amplitude. Check idxByAmp coverage.');
end

% ============================
% MERGE STARTS + AMPS, SORT TOGETHER, THEN DEDUP
% ============================
allS   = [detS; insS];
allAmp = [ampDet; zeros(numel(insS),1)];   % inserted => 0 amplitude

[allS, ord]   = sort(allS, 'ascend');
allAmp        = allAmp(ord);

% De-duplicate near-equal times (keep first)
if ~isempty(allS)
    keep = [true; diff(allS) > DedupTol_sec];
    allS   = allS(keep);
    allAmp = allAmp(keep);
end

% ============================
% REBUILD uAmp / idxByAmp CONSISTENTLY WITH FILLED + SORTED EVENTS
% ============================
% If you want tolerance-binning here too, do it now:
AmpTol = 0.1;  % keep consistent with your call above
if AmpTol > 0
    ampKey = round(allAmp / AmpTol) * AmpTol;
else
    ampKey = allAmp;
end

uAmp_filled = unique(ampKey, 'stable');         % keep stable order first
[uAmp_filled, sortOrder] = sort(uAmp_filled);   % then sort amplitudes

idxByAmp_filled = cell(numel(uAmp_filled),1);
for kk = 1:numel(uAmp_filled)
    idxByAmp_filled{kk} = find(ampKey == uAmp_filled(kk));
end

% ---- final outputs you'll use ----
stimStarts_filled = allS;
uAmp_filled       = uAmp_filled;
idxByAmp_filled   = idxByAmp_filled;

% (optional) overwrite originals
stimStarts = stimStarts_filled;
uAmp       = uAmp_filled;
idxByAmp   = idxByAmp_filled;

save(fullfile(impulseDir, 'data', sprintf('stim_vars_%s_%s_en%d.mat', mn, td, en)), 'uAmp', 'idxByAmp', 'stimStarts');


% get dF/F
% d.mv = d.motion.motion_1(1:2:end);

% 
UU = reshape(U, 560*560, nSV);
brainMask_e = mimg(:) > 0.1 * max(mimg(:));   % exclude dim background
UU_brain_e  = UU(brainMask_e, :);             % nBrainPx Ã— nSV


F=[];
pixel  = d.params.pixel;
j=1;
k = d.params.kernel;
mI=[];
for i = 1:length(V)
            mimg_kernel = mimg(pixel(j,2)-k:pixel(j,2)+k,pixel(j,1)-k:pixel(j,1)+k);
            mI = [mI,mean(mimg_kernel,'all')];
            imkernel = U(pixel(j,2)-k:pixel(j,2)+k,pixel(j,1)-k:pixel(j,1)+k,:);
            % size(imkernel)
            imstack = mean(imkernel,[1,2]);
            % size(imstack)   
            F = [F,reshape(imstack,[1,500])*V(:,i)];
end
%

dF = F/mI(1)*100;

% dF = F;




% sort dF by impulse, but define "peak inhibition" at a fixed time point
fs      = 35;    % Hz
tWin    = 3.0;   % seconds for DF_imp window (+/-)
winSamp = round(tWin * fs);

% ---- Peak_imp method (switch here) ----
% 2 : per-trial min within Â±5-sample window around trial-average trough
% 3 : mean dF/F over fixed 0â€“200 ms post-onset window
% peak_mode = 2;
peak_mode = 3;

% Session-level spectrogram (matches controllerData.m convention)
specWin = 2 * fs;           % 70-sample Hann window â†’ Î”f = 0.5 Hz
specHop = fs;               % 35-sample hop â†’ 1-s steps
nBands  = 20;               % bands 0â€“10 Hz, one FFT bin each
[S_spec, ~, t_spec] = spectrogram(dF, hann(specWin), specWin-specHop, specWin, fs);
S_bands = abs(S_spec(1:nBands, :)).^2;   % absolute power, (\DeltaF/F)^2 Hz^-1
S_norm  = S_bands ./ (sum(S_bands, 1) + eps);   % kept for reference, not used for freqSpec
freqBandCtrs = (0:nBands-1)*0.5 + 0.25;          % 0.25, 0.75, â€¦, 9.75 Hz

nAmp = length(uAmp);
imp = struct();
imp.uAmp         = num2cell(uAmp(:));
imp.Peak_imp     = cell(nAmp,1);
imp.Peak_imp_dev = cell(nAmp,1);
imp.mot          = cell(nAmp,1);
imp.freqSpec     = cell(nAmp,1);
imp.dfImp        = cell(nAmp,1);
imp.motTrace     = cell(nAmp,1);
imp.Peak_imp_mean = nan(nAmp,1);
imp.mot_mean      = nan(nAmp,1);
imp.p_var         = cell(nAmp,1);
imp.startTimes    = cell(nAmp,1);
imp.resp_map      = cell(nAmp,1);   % brain-pixel dF/F response (peak âˆ’ baseline)
imp.base_map      = cell(nAmp,1);   % brain-pixel dF/F during baseline window

DF_imp   = nan(nAmp, 2*winSamp+1);
t_win    = -3:1/35:3;
cumMv    = [0; cumsum(mv_z(:))];          % for vectorised motion sums
dt_spec  = t_spec(2) - t_spec(1);
iSpec_hw = round(1.0 / dt_spec);          % Â±1 s in spectrogram bins
nF  = numel(dF);
nMv = numel(mv_z);
t0  = d.timeBlue(1);
for i = 1:length(uAmp)
    impulseNums  = idxByAmp{i};
    startTimes_i = stimStarts(impulseNums);

    % vectorised nearest-frame lookup (avoids per-trial linear scan)
    bAll  = round((startTimes_i(:) - t0) * fs) + 1;
    bAll  = max(1, min(nF, bAll));
    valid = (bAll - winSamp) >= 1 & (bAll + winSamp) <= min(nF, nMv);
    bAll  = bAll(valid);
    valid_start = startTimes_i(valid)';
    nV    = numel(bAll);

    % Spatial maps: trial-averaged dF/F in SVD space, brain pixels only
    % Baseline: âˆ’500 ms to 0 ms;  Peak: 0 to +200 ms (matches peak_mode=3)
    iBase_off = (-round(0.5*fs)):(-1);
    iPeak_off = 1 : round(0.2*fs);
    if nV > 0
        bBase = bAll(:) + iBase_off;            % nV Ã— nBase frame indices
        bPeak = bAll(:) + iPeak_off;            % nV Ã— nPeak frame indices
        V_base_m = mean(V(:, bBase(:)), 2);     % nSV Ã— 1, mean over all baseline frames
        V_peak_m = mean(V(:, bPeak(:)), 2);
        imp.resp_map{i} = UU_brain_e * (V_peak_m - V_base_m) / mI(1) * 100;
        imp.base_map{i} = UU_brain_e * V_base_m / mI(1) * 100;
    else
        imp.resp_map{i} = zeros(sum(brainMask_e), 1);
        imp.base_map{i} = zeros(sum(brainMask_e), 1);
    end

    if nV == 0
        df_imp = zeros(0, 2*winSamp+1);
        mot      = zeros(1, 0);
        motTrace = zeros(0, 2*winSamp+1);
        freqSpec = nan(0, nBands);
    else
        % df_imp and motTrace: extract all trials at once via index matrix
        idxMat   = bAll(:) + (-winSamp:winSamp);              % nV Ã— nSamp
        baseline = reshape(dF(bAll), nV, 1);                  % force nV Ã— 1
        df_imp   = bsxfun(@minus, dF(idxMat), baseline);      % nV Ã— nSamp
        motTrace = mv_z(idxMat);                               % nV Ã— nSamp

        % motion cumsum over Â±35 samples (Â±1 s) â€” wide window kept for analysis flexibility
        i0_mot = max(1,   bAll - 35);
        i1_mot = min(nMv, bAll + 35);
        mot    = (cumMv(i1_mot + 1) - cumMv(i0_mot))';   % 1 Ã— nV

        % freqSpec: pre-allocated, integer-index spectrogram slice per trial
        freqSpec = nan(nV, nBands);
        for j = 1:nV
            ic   = round(((bAll(j)-1)/fs - t_spec(1)) / dt_spec) + 1;
            i_lo = max(1, ic - iSpec_hw);
            i_hi = min(size(S_norm,2), ic + iSpec_hw);
            freqSpec(j,:) = mean(S_bands(:, i_lo:i_hi), 2)';
        end
    end

    % p_imp: trial-level inhibition depth.
    % df_imp columns: winSamp+1 = stim onset (= 0 by construction).
    if ~isempty(df_imp)
        mean_resp  = mean(df_imp, 1);
        post_start = winSamp + 2;          % first sample strictly after onset
        [~, pk]    = min(mean_resp(post_start:end));
        avg_peak   = post_start - 1 + pk;  % trial-average trough index

        if peak_mode == 2
            % Option 2: per-trial min within Â±5 samples of trial-average trough.
            % Allows latency jitter; Â±143 ms search window bounds noise.
            hw       = 5;
            srch     = max(post_start, avg_peak-hw) : min(size(df_imp,2), avg_peak+hw);
            p_imp    = min(df_imp(:, srch), [], 2);

        else  % peak_mode == 3
            % Option 3: mean dF/F over 0â€“200 ms post-onset.
            % Integrates total inhibition energy; insensitive to peak timing.
            win3     = post_start : min(size(df_imp,2), winSamp + round(0.22*fs));
            p_imp    = mean(df_imp(:, win3), 2);
        end
    else
        p_imp = zeros(0, 1);
    end
    % plot(t_win,df_imp,'Color',[0,0,i/(length(uAmp))],'LineWidth',3);
    % plot(t_win,mean(df_imp),'Color',[1,0,i/(length(uAmp))],'LineWidth',5);

    imp.Peak_imp{i}     = p_imp;
    imp.mot{i}          = mot(:);
    imp.Peak_imp_dev{i} = abs(p_imp - mean(p_imp, 'omitnan'));
    imp.freqSpec{i}     = freqSpec;
    imp.dfImp{i}        = df_imp;
    imp.motTrace{i}     = motTrace;

    imp.Peak_imp_mean(i) = mean(p_imp, 'omitnan');
    imp.mot_mean(i)      = mean(mot,   'omitnan');

    mu_p = mean(p_imp, 'omitnan');

    imp.p_var{i}      = p_imp - mu_p;
    imp.startTimes{i} = valid_start;


    if ~isempty(df_imp)
        DF_imp(i,:) = mean(df_imp, 1);
    end

end

% Store results for this experiment
tmp         = cellfun(@(v) v(:), imp.Peak_imp, 'UniformOutput', false);
allVals     = vertcat(tmp{:});
nPerAmp     = cellfun(@numel, imp.Peak_imp);
groupLabels = repelem(string(cell2mat(imp.uAmp(:))), nPerAmp(:));

allExperiments(expIdx).mn = mn;
allExperiments(expIdx).td = td;
allExperiments(expIdx).en = en;
allExperiments(expIdx).allVals = allVals;
allExperiments(expIdx).groupLabels = groupLabels;
allExperiments(expIdx).imp = imp;
allExperiments(expIdx).DF_imp = DF_imp;
allExperiments(expIdx).uAmp      = uAmp;
allExperiments(expIdx).dF        = dF;
allExperiments(expIdx).timeBlue  = d.timeBlue;
allExperiments(expIdx).mv_z          = mv_z;
allExperiments(expIdx).freqBandCtrs  = freqBandCtrs;
allExperiments(expIdx).brainMask     = brainMask_e;
allExperiments(expIdx).mimg          = mimg;
allExperiments(expIdx).mI1           = mI(1);

end  % End of experiment loop

% Shared time vector used by prestim_variance, spectral_heatmap, etc.
t_win_imp = -tWin : 1/fs : tWin;

%% [LE-BILATERAL] append AL_0048 (dual-opsin, site R) as session 4 --------------------------------
% User 2026-08-10: AL_0048 is part of the impulse session set, so loading the set should produce it.
% It is DELEGATED to load_bilateral_impulse rather than duplicated here -- that script owns the galvo
% calibration, the site resolution, the bregma registration and the ant_rc convention, and a second
% copy of any of those is how the two loaders would quietly stop agreeing.
%
% Appended LAST, so indices 1-3 are unchanged and every locked default that refers to a session by
% number (selExp = 3 = AL_0033, the primary) still points where it always did.
%
% ⚠ TWO CONSEQUENCES OF LOADING IT BY DEFAULT, both real:
%   1. Scripts that sweep `1:numel(allExperiments)` (imp_tf_xsess's TFX_SEL, imp_run_all's RA_SEL,
%      dose_response, ...) now silently include AL_0048. That is the point of the change, but it
%      means the session set is no longer 3 unless a caller says so.
%   2. AL_0048 is NOT a fourth replicate of the same measurement. On the inhibitory side the readout
%      sits ~2.6 mm from the ILLUMINATED spot (the calibrated spot has no usable dose-response), so
%      SITE_MODE='response' puts it on the anterior focus: this session measures the response of a
%      CONNECTED region, not of illuminated tissue. Any TF or local-effect claim including it must
%      say so. See load_bilateral_impulse.m's header and RESEARCH 2026-08-02.
% Set LE_BILATERAL = false before running to get the 3 original sessions only.
if ~exist('LE_BILATERAL','var') || isempty(LE_BILATERAL), LE_BILATERAL = true; end
if LE_BILATERAL && ~any(arrayfun(@(A) strcmp(A.mn,'AL_0048'), allExperiments))
    fprintf('\n[LE] appending AL_0048 (dual-opsin, inhibitory site) -> load_bilateral_impulse\n');
    try
        load_bilateral_impulse
    catch LE_err
        % Do NOT fail the whole load: the 3 original sessions are complete and usable, and most
        % callers only need them. But do NOT fail quietly either -- a caller that expected 4 sessions
        % and silently got 3 would produce a cross-session result over the wrong set.
        fprintf(2, ['[LE] ** AL_0048 NOT appended: %s **\n' ...
                    '     allExperiments holds %d session(s). Anything cross-session below is over\n' ...
                    '     those only. Re-run load_bilateral_impulse on its own to see the full error.\n'], ...
                LE_err.message, numel(allExperiments));
    end
end
fprintf('[LE] allExperiments: %d session(s) -> %s\n', numel(allExperiments), ...
        strjoin(arrayfun(@(A) sprintf('%s %s e%d', A.mn, A.td, A.en), allExperiments, 'UniformOutput',false), ' | '));