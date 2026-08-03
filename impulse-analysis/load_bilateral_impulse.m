%% load_bilateral_impulse.m -- register AL_0048's two-spot impulse session as impulse sessions
%
% The 4th impulse dataset (user, 2026-08-02) is AL_0048 2026-07-15 `opto_bilateralImpulse638`:
% ONE widefield recording (exp 1) in which a galvo alternates between TWO spots, one per
% hemisphere -- LEFT = excitatory opsin (positive dF/F), RIGHT = inhibitory (negative). It is
% therefore registered as TWO entries in `allExperiments` (site 'L' and site 'R'), each holding
% only that side's onsets, so every downstream stage (site cache, ROI, stim-blind contra->ipsi,
% state-dependence) treats a site exactly like an ordinary single-site impulse session. The
% contra/ipsi assignment follows automatically: cp_roi_masks calls the hemisphere containing the
% primary pixel IPSI, so the SAME drawn ROI file serves both sites with the sides swapped.
%
% WHY A SEPARATE LOADER: this is a Signals experiment, not the closed-loop controller rig, so it
% has no input_params.csv/states.csv/params.mat and `loadData` cannot open it. Everything needed
% is in Timeline: lightCommand638 (onsets + amplitude), galvoX/galvoY (which spot), and the blue
% widefield SVD + timestamps.
%
% ONSETS (verified 2026-08-02 on 2026-07-15/1): threshold 0.3 V with a 60 ms debounce gives
% EXACTLY 600 onsets = 100 per amp per side x 3 amps x 2 sides, matching the block design
% (800 trials = 600 firing + 200 sham). Command plateaus are 0.4 / 1.0 / 1.6 V. galvoX is
% -1.83 V (left) / +2.67 V (right), galvoY constant 4.58 V. The 200 amp-0 SHAM trials fire no
% laser and are absent here (recovering them needs the Block<->Timeline clock map, as in the
% Python sub-area's RECOVER_SHAM).
%
% SITE: data-derived, per the project rule. The per-pixel DOSE SLOPE map (response regressed on
% amplitude) is searched within SITE_RAD px of the galvo-calibrated spot, taking the max on the
% excitatory side and the min on the inhibitory side. Calibration comes from the session's own
% hardwareInfo.json (mmPerV_X 1.1111, mmPerV_Y -1.0753, bregmaOffset 0.4424/1.8099), which puts
% the two spots at (-2.52,-2.98) and (+2.48,-2.98) mm from bregma -- i.e. the intended mirrored
% design. Pixel registration is the widefield rig constant (57.8 px/mm) with bregma at
% (x=215, y=250) px: the grid module's BREGMA_PX x=280 is ~65 px off for THIS session, a shift
% that both spots agree on independently (see RESEARCH 2026-08-02).
%
% ⚠ KNOWN ASYMMETRY (RESEARCH 2026-08-02): on the INHIBITORY side the strongest suppression is
% NOT at the illuminated spot but ~2.6 mm anterior ([row 272 col 355], -2.05% at the top amp vs
% -1.16% at the spot). SITE_MODE selects which one this loader uses. 'calibrated' (default) keeps
% the readout at the illuminated spot = the actuator, which is what an impulse/TF analysis is
% about; 'response' takes the global strongest focus instead. This is a real experimental
% finding (likely inhibitory-opsin expression offset from the intended target), not a bug --
% do not silently switch modes without saying which was used.
%
% MOTION: the session records BOTH face.mp4 and eye.mp4; the project uses FACE, not eye (user,
% 2026-08-02). What was missing is only the Facemap output (face_proc.mat) -- see [BLI-MOTION]
% and `run_facemap.py`. Once that exists, motion is available here exactly as in the other
% sessions; until then mv_z is NaN and a warning says so.
%
% RUN: after load_experiments.m (which builds `allExperiments` for the 3 original sessions);
% this APPENDS entries 4 (L) and 5 (R).
% ---------------------------------------------------------------------------------

%% [BLI-CFG] --------------------------------------------------------------------
BLI.mn = 'AL_0048';  BLI.td = '2026-07-15';  BLI.en = 1;
BLI.sig = 'lightCommand638';
BLI.thr = 0.3;  BLI.debounce_s = 0.06;   % laser onset detection
BLI.plateau_s = 0.02;                    % window over which the command amplitude is read
BLI.ampTol = 0.1;                        % amplitude rounding (V)
BLI.nSV = 500;  BLI.kern = 10;           % SVD comps; kernel half-width (px) for the dF readout
BLI.SITE_RAD = 35;                       % search radius (px) around the calibrated spot
BLI.SITE_MODE = 'calibrated';            % 'calibrated' (spot, DEFAULT) | 'response' (global focus)
BLI.dip_win = [0 0.20];                  % energy window (project-locked peak_mode=3)
BLI.win_s = 3.0;                         % +/- window for the per-trial traces
% galvo volts->mm (this session's hardwareInfo.json) + pixel registration
BLI.mmPerV = [1.1111111111111112, -1.075268817204301];
BLI.bregmaOffV = [0.44240536910566763, 1.8098660744628157];
BLI.bregma_px = [215, 250];              % (x,y) px -- x corrected for THIS session (see header)
BLI.px_per_mm = [57.8, -57.8];

if ~exist('impulseDir','var') || isempty(impulseDir)
    impulseDir = fileparts(which('load_bilateral_impulse'));
    if isempty(impulseDir); impulseDir = 'C:\Users\aditya\Documents\projects\brain_paper\impulse-analysis'; end
end
BLI.dataDir = fullfile(impulseDir,'data');
if ~exist('allExperiments','var')
    error('[BLI] run load_experiments.m first (need `allExperiments`).');
end

%% [BLI-ONSETS] Timeline -> onsets, amplitude, side --------------------------------
[tt_b, v_b]  = getTLanalog(BLI.mn, BLI.td, BLI.en, BLI.sig);
[~,   gx_b]  = getTLanalog(BLI.mn, BLI.td, BLI.en, 'galvoX');
fsDAQ = 1/median(diff(tt_b));
ix = find(v_b(2:end) > BLI.thr & v_b(1:end-1) <= BLI.thr) + 1;
if ~isempty(ix)
    ix = ix([true; diff(tt_b(ix)) > BLI.debounce_s]);          % debounce
end
nPl = round(BLI.plateau_s*fsDAQ);  nPre = round(0.01*fsDAQ);
onT   = tt_b(ix);
onAmp = arrayfun(@(i) max(v_b(i:min(i+nPl,numel(v_b)))), ix);
onAmp = round(onAmp/BLI.ampTol)*BLI.ampTol;
onGx  = arrayfun(@(i) median(gx_b(max(1,i-nPre):i)), ix);
onSide = sign(onGx);                                            % -1 = LEFT spot, +1 = RIGHT spot
fprintf('[BLI] %s %s e%d: %d laser onsets | amps %s | L %d / R %d\n', BLI.mn, BLI.td, BLI.en, ...
    numel(onT), mat2str(unique(onAmp)'), nnz(onSide<0), nnz(onSide>0));

%% [BLI-MOTION] face-camera motion energy ------------------------------------------
% Motion state = FACEMAP's `motion_1` (same definition as every other session:
% load_experiments does `mv = d.motion.motion_1(1:2:end)` then z-scores). The face camera is
% triggered with the widefield at 2 frames per blue frame, hence the 1:2:end.
% AL_0048 2026-07-15 shipped face.mp4 + face_ROI.mat but NO face_proc.mat -- the video was
% recorded and never processed. `impulse-analysis/run_facemap.py` produces it with AL_0041's
% settings (sbin=4, motSVD only); it is searched for on the server first, then locally.
% Eye video exists too and is deliberately NOT used (user, 2026-08-02).
mvz_b = [];
faceCands = { fullfile(expPath(BLI.mn,BLI.td,BLI.en),'face_proc.mat'), ...
              fullfile(BLI.dataDir, sprintf('%s_%s_%d_face_proc.mat', BLI.mn, BLI.td, BLI.en)) };
for fc = faceCands
    if exist(fc{1},'file')
        Fp = load(fc{1},'motion_1');
        if isfield(Fp,'motion_1') && ~isempty(Fp.motion_1)
            mvraw = double(Fp.motion_1(:));
            mvz_b = zscore(mvraw(1:2:end));            % face frames -> blue-frame cadence
            fprintf('[BLI] motion: %d face frames -> %d samples from %s\n', ...
                numel(mvraw), numel(mvz_b), fc{1});
        end
        break
    end
end
if isempty(mvz_b)
    warning(['[BLI] no face_proc.mat found -- motion state unavailable for this session. ' ...
             'Run: impulse-analysis/run_facemap.py --subject %s --date %s --exp %d'], BLI.mn, BLI.td, BLI.en);
end

%% [BLI-SVD] widefield + calibrated spot pixels ------------------------------------
serverRoot = expPath(BLI.mn, BLI.td, BLI.en);
[U_b, V_b, t_b, mimg_b] = loadUVt(serverRoot, BLI.nSV);
V_b = double(V_b);  t_b = t_b(:);  [nYb,nXb] = size(mimg_b);
Ufb = reshape(U_b, nYb*nXb, size(U_b,3));
Fs_b = 1/mean(diff(t_b));
onF_all = arrayfun(@(x) find(t_b >= x, 1, 'first'), onT, 'uni',0);
okOn = ~cellfun(@isempty, onF_all);
onF_all = cell2mat(onF_all(okOn));  onT = onT(okOn);  onAmp = onAmp(okOn);  onSide = onSide(okOn);

mmx = (median(onGx(onSide<0)) - BLI.bregmaOffV(1))*BLI.mmPerV(1);      % LEFT spot, mm
mmx(2) = (median(onGx(onSide>0)) - BLI.bregmaOffV(1))*BLI.mmPerV(1);   % RIGHT spot, mm
[~, gy_b] = getTLanalog(BLI.mn, BLI.td, BLI.en, 'galvoY');
mmy = (median(gy_b(ix)) - BLI.bregmaOffV(2))*BLI.mmPerV(2);
spot_row = BLI.bregma_px(2) + mmy*BLI.px_per_mm(2);
spot_col = BLI.bregma_px(1) + mmx*BLI.px_per_mm(1);
fprintf('[BLI] galvo-calibrated spots: L (%.2f, %.2f) mm -> [row %.0f col %.0f] | R (%.2f, %.2f) -> [row %.0f col %.0f]\n', ...
    mmx(1), mmy, spot_row, spot_col(1), mmx(2), mmy, spot_row, spot_col(2));

% per-pixel dose-slope map per side (response 30-150 ms minus baseline -200-0 ms, regressed on amp)
uA = unique(onAmp);  nAb = numel(uA);
swb = round(0.03*Fs_b):round(0.15*Fs_b);  bwb = round(-0.2*Fs_b):-1;
respMap = @(sel) mean(cell2mat(arrayfun(@(f) (mean(Ufb*V_b(:,f+swb),2) - mean(Ufb*V_b(:,f+bwb),2)), ...
                     onF_all(sel)', 'uni',0)), 2);
xa = uA(:) - mean(uA);  denA = sum(xa.^2);

sides = {'L','R'};  signs = [+1 -1];       % L = excitatory (max), R = inhibitory (min)
for sI = 1:2
    if sI==1, selSide = onSide < 0; else, selSide = onSide > 0; end   % L = galvoX<0, R = galvoX>0
    Sm = zeros(nYb*nXb, nAb);
    for a = 1:nAb, Sm(:,a) = respMap(selSide & onAmp==uA(a)); end
    slope = reshape((Sm*xa)/denA ./ max(mimg_b(:),eps)*100, nYb, nXb);

    tagS = sprintf('%s_%s%s_e%d_%s', BLI.mn, BLI.td(6:7), BLI.td(9:10), BLI.en, sides{sI});
    siteFile = fullfile(BLI.dataDir, sprintf('cp_stim_site_%s.mat', tagS));
    if exist(siteFile,'file')
        st = load(siteFile);  rc = double(st.rowcol);
        fprintf('[BLI] %s: cached site [row %d col %d]\n', tagS, rc);
    else
        if strcmpi(BLI.SITE_MODE,'response')
            if signs(sI) > 0, [dv,li] = max(slope(:)); else, [dv,li] = min(slope(:)); end
            [rc(1), rc(2)] = ind2sub([nYb nXb], li);
        else
            rr = max(1,round(spot_row)-BLI.SITE_RAD):min(nYb,round(spot_row)+BLI.SITE_RAD);
            cc = max(1,round(spot_col(sI))-BLI.SITE_RAD):min(nXb,round(spot_col(sI))+BLI.SITE_RAD);
            sub = slope(rr,cc);
            if signs(sI) > 0, [dv,li] = max(sub(:)); else, [dv,li] = min(sub(:)); end
            [a1,b1] = ind2sub(size(sub), li);  rc = [rr(a1) cc(b1)];
        end
        st = struct('rowcol', rc, 'depth', dv, 'mode', BLI.SITE_MODE, 'src', 'load_bilateral_impulse dose-slope');
        save(siteFile, '-struct', 'st');
        fprintf('[BLI] %s: site [row %d col %d] slope %+.2f %%/V (mode=%s) -> cached\n', tagS, rc, dv, BLI.SITE_MODE);
    end

    % --- kernel dF/F trace at the site (same construction as load_experiments) ----
    k = BLI.kern;  r0 = rc(1);  c0 = rc(2);
    rows = r0-k:r0+k;  cols = c0-k:c0+k;
    idxK = sub2ind([nYb nXb], repmat(rows(:),numel(cols),1), repelem(cols(:),numel(rows),1));
    mIk  = mean(mimg_b(idxK));
    dF_b = (mean(Ufb(idxK,:),1) * V_b) / max(mIk,eps) * 100;

    % --- per-amp trial structure (imp), matching the load_experiments contract -----
    winS = round(BLI.win_s*Fs_b);  relW = -winS:winS;
    dipC = winS + (round(BLI.dip_win(1)*Fs_b)+1 : round(BLI.dip_win(2)*Fs_b)) + 1;
    imp = struct();
    imp.uAmp = num2cell(uA(:));
    [imp.Peak_imp, imp.Peak_imp_dev, imp.mot, imp.freqSpec, imp.dfImp, imp.motTrace, ...
     imp.p_var, imp.startTimes, imp.resp_map, imp.base_map] = deal(cell(nAb,1));
    imp.Peak_imp_mean = nan(nAb,1);  imp.mot_mean = nan(nAb,1);
    DF_imp_b = nan(nAb, numel(relW));
    for a = 1:nAb
        selA = selSide & onAmp==uA(a);
        fA = onF_all(selA);
        fA = fA(fA > winS & fA + winS <= numel(dF_b));
        imp.startTimes{a} = t_b(fA);
        trM = cell2mat(arrayfun(@(f) dF_b(f+relW), fA', 'uni',0)');
        trM = trM - mean(trM(:, relW < 0 & relW >= -round(0.5*Fs_b)), 2);   % [-0.5,0]s baseline
        imp.dfImp{a} = trM;
        imp.Peak_imp{a} = mean(trM(:, dipC), 2);
        imp.Peak_imp_mean(a) = mean(imp.Peak_imp{a}, 'omitnan');
        imp.Peak_imp_dev{a} = imp.Peak_imp{a} - imp.Peak_imp_mean(a);
        % per-trial motion, IDENTICAL definition to load_experiments: sum of z-scored motion
        % energy over +/-35 samples (+/-1 s) around onset, plus the windowed trace.
        if ~isempty(mvz_b)
            nMv = numel(mvz_b);  cumMv = [0; cumsum(mvz_b)];
            i0 = max(1, fA-35);  i1 = min(nMv, fA+35);
            imp.mot{a} = (cumMv(i1+1) - cumMv(i0));
            idxM = min(max(fA(:) + relW, 1), nMv);
            imp.motTrace{a} = mvz_b(idxM);
        else
            imp.mot{a} = nan(numel(fA),1);
            imp.motTrace{a} = nan(numel(fA), numel(relW));
        end
        imp.mot_mean(a) = mean(imp.mot{a},'omitnan');
        DF_imp_b(a,:) = mean(trM,1,'omitnan');
    end

    e = numel(allExperiments) + 1;
    allExperiments(e).mn = BLI.mn;  allExperiments(e).td = BLI.td;  allExperiments(e).en = BLI.en;
    allExperiments(e).site = sides{sI};          % NEW field: which galvo spot this entry is
    allExperiments(e).sess_tag = tagS;           % NEW: site-qualified tag for the ROI/site caches
    allExperiments(e).imp = imp;
    allExperiments(e).uAmp = uA(:);
    allExperiments(e).DF_imp = DF_imp_b;
    allExperiments(e).dF = dF_b(:);
    allExperiments(e).timeBlue = t_b;
    if ~isempty(mvz_b)
        mvz_e = mvz_b(1:min(numel(mvz_b), numel(t_b)));
        mvz_e(end+1:numel(t_b)) = NaN;           % pad if the camera stopped a frame early
        allExperiments(e).mv_z = mvz_e;
    else
        allExperiments(e).mv_z = nan(numel(t_b),1);
    end
    allExperiments(e).mimg = mimg_b;
    allExperiments(e).mI1 = mIk;
    allExperiments(e).brainMask = mimg_b(:) > 0.1*max(mimg_b(:));
    allExperiments(e).groupLabels = repelem(string(uA(:)), cellfun(@numel, imp.Peak_imp));
    allExperiments(e).allVals = cell2mat(imp.Peak_imp);
    fprintf('[BLI] registered as allExperiments(%d)  site %s  | trials/amp %s\n', ...
        e, sides{sI}, mat2str(cellfun(@numel, imp.Peak_imp)'));
end
fprintf(['[BLI] DONE. AL_0048 is entries %d (L, excitatory) and %d (R, inhibitory).\n' ...
         '      Next: ONE ROI draw for this mouse -- run the pipeline with selExp = %d; cp_roi_masks\n' ...
         '      opens once and the same cp_roi2_ file serves BOTH sites (ipsi = side of the primary px).\n'], ...
    numel(allExperiments)-1, numel(allExperiments), numel(allExperiments)-1);
