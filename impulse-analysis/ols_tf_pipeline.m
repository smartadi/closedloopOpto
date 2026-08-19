% ols_tf_pipeline.m -- CLEAN TF-based contra->ipsi stim-blind pipeline (assembled 2026-07-13 from ols_pixel_predictor_wip.m).
% Linear stream: SETUP -> TF affected-detection -> stim-blind contra model (residual=dip) -> residual state-dependence -> batch.
% Run section-by-section after load_experiments.m. Explorers/diagnostics are in the APPENDIX (end).
% NOTE: sec10 matched-filter is kept ONLY as the seed for sec10T pixel-picking; the TF detector (sec10T2) governs downstream.
% To drive the model from TF: in sec10T2 set affect_mode = tf and tf_run = full (full nGxnA map, ~min serial).
%% (1) Paths + config
close all;
here = fileparts(mfilename('fullpath'));
% When a *section* is run (Ctrl+Enter) or a selection is evaluated, MATLAB executes
% a temp copy under %TEMP%\Editor_*, so mfilename points there. Discard any such
% temp path so we never resolve dataDir to ...\Editor_xxxx\data.
if ~isempty(here) && (contains(here, tempdir, 'IgnoreCase', true) || ...
                      contains(here, 'Editor_', 'IgnoreCase', true))
    here = '';
end
% robustly locate impulse-analysis/ (the dir that actually contains data/), so the
% ROI + site caches are found regardless of pwd or how the script is launched.
% Last-resort absolute anchor for this single-machine repo.
knownDir = 'C:\Users\aditya\Documents\projects\brain_paper\impulse-analysis';
cand = {here, fullfile(pwd,'impulse-analysis'), pwd, fullfile(pwd,'..','impulse-analysis'), knownDir};
impulseDir = '';
for c = cand
    if ~isempty(c{1}) && exist(fullfile(c{1},'data'),'dir'), impulseDir = c{1}; break; end
end
if isempty(impulseDir)
    if exist(fullfile(knownDir,'data'),'dir'),  impulseDir = knownDir;
    elseif ~isempty(here),                      impulseDir = here;
    else,                                       impulseDir = fullfile(pwd,'impulse-analysis'); end
end
utilsDir   = fullfile(impulseDir,'..','utils');
dataDir    = fullfile(impulseDir,'data');
addpath(utilsDir);  addpath(genpath(utilsDir));
if exist(fullfile('paper','images'),'dir'),        paper_root = 'paper';
elseif exist(fullfile('..','paper','images'),'dir'),paper_root = fullfile('..','paper');
else,                                               paper_root = 'paper';  end

if exist('selExp_override','var') && ~isempty(selExp_override)
    selExp = selExp_override;                 % batch-driver hook (default preserved below)
else
    selExp = 3;        % experiment index (default 3 = AL_0033 2025-01-29)
end
nSV_load  = 500;      % SVD components to load
Fs        = 35;       % frame rate (Hz)
nGrid     = 500;      % tight contra grid size
edgeMargin= 12;       % drop grid nodes whose (2*em+1)^2 neighborhood isn't fully in-mask
                      %   (erodes the mask edge -> no unstable boundary/corner pixels get weight;
                      %    RAISE this to pull the grid further inside the brain)
dip_win_s = 0.300;    % INHIBITION-ENERGY / dip window (s) post-onset. Data-driven (S15 SETTLETIME):
                      %   trough ~114-143 ms, median RECOVERY ~314 ms, rebound peak ~550 ms.
                      %   0.300 captures the full recovery WITHOUT touching the rebound (was 0.200,
                      %   which cut inhibition off mid-recovery). Used by BLEED/BLEEDCHAR/SETTLETIME/
                      %   STIMBLIND-SELECT (§17d) so the dip window has ONE source of truth.
settle_s  = 2.0;      % post-onset settle before an interstim window starts (s)
trainFrac = 2/3;      % temporal train fraction (first block = train)
maxFrm    = 60000;    % cap on spontaneous frames used
fit_mode  = 'lasso';  % 'ols' | 'ridge' | 'lasso'.  SPARSITY comes ONLY from lasso (L1);
                      % ridge (L2) NEVER zeros weights -> no number makes 'ridge' sparse.
ridge     = 0.2;      % L2 term. In 'lasso' mode = the ELASTIC-NET L2 (fraction ~0..1):
                      %   0   = pure lasso (can pick one px arbitrarily from a correlated cluster)
                      %   >0  = elastic net: still sparse, but groups/stabilizes neighbor clusters
                      % (In 'ridge' mode it's a plain L2 penalty and gives NO sparsity at any value.)
l1_frac   = 0.1;      % *** SPARSITY KNOB (lasso/enet) ***  L1 penalty / lambda_max in (0,1):
                      %     HIGHER = sparser (fewer active px, lower R^2)
                      %     LOWER  = denser  (more active px, higher R^2 -> approaches OLS as ->0)
debias    = true;     % refit plain OLS on the Lasso-SELECTED pixels (removes L1 shrinkage,
                      %     recovers most of the R^2 lost to the penalty while KEEPING sparsity)
USE_DATA_SITE = true; % localise the site from data (recommended), not params.pixel
RUN_ALLSESS   = false; % §18: OFF by default in this WIP. §18's engine local_stimblind_session now uses
                      %   the SELECT sparse far-from-ipsi stim-blind (repointed 2026-07-18); it keys off the energy-based
                      %   bledA affected map, not TF detection. Turn on for the cross-session batch.
allSelExp     = [3 1 2];  % sessions for §18 combined run: AL_0033 e3, AL_0041 e1, AL_0041 e2
RUN_SESSION_VIEWER = true;  % §20: open the orientation-normalized interactive map with a session
                      %   picker (pick session -> brain + sparse contra weights; click ipsi to refit).
disp_orient = 'auto'; % DISPLAY orientation of ALL brain-map overlays (§8,§10,§14,§16,§17b,§20).
                      %   'auto'      = pick_orient auto-normalizes (ipsi right, midline vertical)
                      %   'transpose' = canonical imagesc(mimg') anatomical view (brain vertical)
                      %   'native'|'rot90'|'rot180'|'rot270'|'fliplr'|'flipud' = fixed dihedral view
                      % DISPLAY-ONLY: overlay + grid + click-to-refit follow the SAME transform, so
                      % pixel selection is unaffected by this choice (proven consistent for any op).

% BATCH-DRIVER HOOK. Any field of an `OLS_OVERRIDE` struct in the caller's workspace replaces the
% knob of the same name, so a driver can run this script headless (e.g. RUN_ALLSESS=true,
% allSelExp=[3 1 2], affect_mode='matched' to skip the interactive TF gate) WITHOUT editing the
% file and leaving the edited knobs behind for the next person. Applied here for the knobs above and
% again after §10T2's affect_mode. eval is the only way to write a script-scope variable by name.
if exist('OLS_OVERRIDE','var') && isstruct(OLS_OVERRIDE)
    for f_ = fieldnames(OLS_OVERRIDE).'
        if exist(f_{1},'var'), eval([f_{1} ' = OLS_OVERRIDE.(f_{1});']); end   %#ok<EVLDIR>
    end
end

% HEADS-UP for batch runs, printed BEFORE the ~minutes of setup rather than discovered after it.
% §18 [ALLSESS] sits AFTER the §10T3 selector, and that selector BLOCKS on uiwait (~line 755) until
% "CONFIRM selection & build model" is pressed. So RUN_ALLSESS=true ALONE does not get you to the
% cross-session batch: an unconfirmed selector ends the run with no ALLSESS and no error, which is
% what `imp_state_xsess`'s "no ALLSESS in the workspace" is really reporting. Say so up front.
if RUN_ALLSESS
    predMode = 'tf';                                          % §10T2's default, unless the driver overrides it
    if exist('OLS_OVERRIDE','var') && isstruct(OLS_OVERRIDE) && isfield(OLS_OVERRIDE,'affect_mode')
        predMode = OLS_OVERRIDE.affect_mode;
    end
    if strcmpi(predMode,'tf')
        fprintf(2, ['[ALLSESS] RUN_ALLSESS=true with affect_mode=''tf'': this run WILL BLOCK at the ' ...
            '§10T3 selector.\n' ...
            '          -> press "CONFIRM selection & build model" to continue on to §17d/§17c/§18, OR\n' ...
            '          -> set OLS_OVERRIDE.affect_mode=''matched'' to run headless. §18''s engine keys off\n' ...
            '             the energy-based bledA map (never affected_tf), so the CROSS-SESSION numbers are\n' ...
            '             identical either way -- only this run''s single-session §17d/§17c gating changes.\n']);
    else
        fprintf('[ALLSESS] RUN_ALLSESS=true, affect_mode=''%s'' -> headless; the §10T3 CONFIRM gate is skipped.\n', predMode);
    end
end

% Reproducibility: seed the RNG so the 0V bootstrap nulls (§10 affect, §14 bleedchar, validation) are
% IDENTICAL run-to-run. This removes the borderline-pixel flip-flop (pixels near the z-threshold flipping
% in/out every run) that made stim-affected detection inconsistent -- the score is deterministic, only the
% bootstrapped null had sampling noise. Seed + more draws (below) = stable, reproducible detection.
rng(7,'twister');

if ~exist('allExperiments','var') || isempty(allExperiments)
    error('ols_pixel_predictor: run load_experiments.m first.');
end
mn = allExperiments(selExp).mn;  td = allExperiments(selExp).td;  en = allExperiments(selExp).en;
fprintf('ols_pixel_predictor: %s %s en=%d\n', mn, td, en);

% (2) Load SVD + session params
y_full  = allExperiments(selExp).dF(:);
t_full  = allExperiments(selExp).timeBlue(:);
serverRoot = expPath(mn, td, en);
[U_cp, V_cp, ~, mimg_cp] = loadUVt(serverRoot, nSV_load);
[nY_cp, nX_cp] = size(mimg_cp);
nSV_cp = size(U_cp, 3);

% Cache tag for the site + ROI files. Bilateral two-spot sessions (AL_0048) register one
% entry PER GALVO SITE under the SAME mn/td/en, so those entries carry a site-qualified
% `sess_tag` (e.g. AL_0048_0715_e1_R); without it two sites would collide on one cache name.
if isfield(allExperiments, 'sess_tag') && ~isempty(allExperiments(selExp).sess_tag)
    sess_tag_cp = allExperiments(selExp).sess_tag;
else
    sess_tag_cp = sprintf('%s_%s%s_e%d', mn, td(6:7), td(9:10), en);
end

% loadData only works on the closed-loop controller rig (needs input_params.csv / states.csv /
% params.mat). The bilateral impulse session is a Signals experiment with none of those, so its
% nominal pixel/kernel come from the loader instead. With USE_DATA_SITE the pixel is overwritten
% by the data-derived site below anyway; k_prim falls back to the project default 10.
try
    d_tmp   = loadData(serverRoot, mn, td, en);
    py_prim = double(d_tmp.params.pixel(1));
    px_prim = double(d_tmp.params.pixel(2));
    k_prim  = double(d_tmp.params.kernel);
    clear d_tmp
catch
    py_prim = NaN;  px_prim = NaN;  k_prim = 10;
    fprintf('[SETUP] no controller-rig params for %s (Signals session) -- using the data-derived site, k_prim=%d\n', ...
        sess_tag_cp, k_prim);
end

% (3) Data-derived photostim site + retarget y_full (same as [CP-SITE])
if USE_DATA_SITE
    site_file = fullfile(dataDir, sprintf('cp_stim_site_%s.mat', sess_tag_cp));
    if exist(site_file,'file')
        SS = load(site_file);  stim_rc = double(SS.rowcol);
        fprintf('[SITE] loaded cached site [row %d col %d]\n', stim_rc);
    else
        imp_v = allExperiments(selExp).imp;  uA_v = allExperiments(selExp).uAmp;
        [~, iMx] = max(uA_v);  sv = imp_v.startTimes{iMx}(:);      % strongest-amp onsets
        onF = zeros(numel(sv),1);
        for jv = 1:numel(sv), [~, onF(jv)] = min(abs(t_full - sv(jv))); end
        st = cp_find_stim_site(U_cp, double(V_cp), mimg_cp, onF, 'fs', Fs);
        stim_rc = double(st.rowcol);  save(site_file,'-struct','st');
        fprintf('[SITE] computed + cached site [row %d col %d]\n', stim_rc);
    end
    px_prim = stim_rc(1);  py_prim = stim_rc(2);
    kr = max(1,px_prim-k_prim):min(nY_cp,px_prim+k_prim);
    kc = max(1,py_prim-k_prim):min(nX_cp,py_prim+k_prim);
    [KR,KC] = ndgrid(kr,kc);  kidx = sub2ind([nY_cp,nX_cp], KR(:), KC(:));
    Ur = reshape(U_cp, nY_cp*nX_cp, nSV_cp);  mI_st = mean(mimg_cp(kr,kc),'all');
    y_full = ((mean(Ur(kidx,:),1) * double(V_cp)) / mI_st * 100).';
    clear Ur KR KC kidx
    fprintf('[SITE] retargeted y_full at site (mI=%.3g)\n', mI_st);
end
nF_m = min(numel(y_full), size(V_cp,2));

% (4) Contra (predictor) hemisphere mask + stim-onset list
% REUSE the existing mask — never redraw here. Priority: (a) a contra mask already in
% the workspace (valid_cp_svd, from contra_prediction.m); (b) the cached ROI geometry
% (cp_roi2_*.mat, loaded — no draw); (c) error with instructions. The draw GUI only
% ever opens from contra_prediction.m S04, which is the single source of truth.
roi_file = fullfile(dataDir, sprintf('cp_roi2_%s.mat', sess_tag_cp));
if exist('valid_cp_svd','var') && exist('ipsi_mask_cp','var') && isequal(size(valid_cp_svd),[nY_cp nX_cp])
    contra_mask = logical(valid_cp_svd);  ipsi_mask = logical(ipsi_mask_cp);
    fprintf('[MASK] reusing contra + ipsi masks from workspace\n');
elseif exist(roi_file,'file')
    M = cp_roi_masks(mimg_cp, roi_file, px_prim, py_prim, ...
                     struct('redefine', false, 'thr_pctile', 20, 'plot', false));
    contra_mask = M.contra;  ipsi_mask = M.ipsi;   % loaded from cache, no draw
    fprintf('[MASK] loaded contra + ipsi masks from cache: %s\n', roi_file);
else
    error(['[MASK] no masks found (workspace valid_cp_svd/ipsi_mask_cp absent; cache missing:\n  %s\n' ...
           'Run contra_prediction.m section S04 once to draw + cache the ROI, then re-run this. ' ...
           'Not opening the draw GUI here.'], roi_file);
end

imp_data = allExperiments(selExp).imp;  uAmp = allExperiments(selExp).uAmp;
all_starts = [];
for ia = 1:numel(uAmp)
    if uAmp(ia) <= 0, continue; end
    all_starts = [all_starts; imp_data.startTimes{ia}(:)];   %#ok<AGROW>
end
all_starts = sort(all_starts);

% (5) Tight ~nGrid pixel regular grid over the contra mask
mask = logical(contra_mask);
[rC,cC] = find(mask);
rmn=min(rC); rmx=max(rC); cmn=min(cC); cmx=max(cC);
d = max(1, round(sqrt(nnz(mask)/nGrid)));
gridIdx = [];
for it = 1:12
    [GR,GC] = ndgrid(rmn:d:rmx, cmn:d:cmx);
    ln = sub2ind([nY_cp,nX_cp], GR(:), GC(:));  ln = ln(mask(ln));
    if numel(ln) >= nGrid || d==1, gridIdx = ln; break; end
    d = max(1, d-1);
end
if isempty(gridIdx), gridIdx = ln; end
% Keep the FULL uniform lattice at spacing d. (Do NOT linspace-trim to exactly nGrid —
% that drops nodes in a periodic stripe pattern and leaves regular empty gaps.) The only
% remaining holes are where the contra mask is false: off-brain edges + low-intensity
% pixels excluded by the mask's intensity floor (vessels/dark regions) — those are real.
[grR,grC] = ind2sub([nY_cp,nX_cp], gridIdx);
% drop EDGE/CORNER nodes: keep a node only if its full (2*em+1)^2 neighborhood is inside
% the mask (an erosion). Boundary pixels are low-SNR and otherwise get spurious weight.
em = edgeMargin;
keep = (grR>em) & (grR<=nY_cp-em) & (grC>em) & (grC<=nX_cp-em);
for g = find(keep(:).')
    blk = mask(grR(g)-em:grR(g)+em, grC(g)-em:grC(g)+em);
    if ~all(blk(:)), keep(g) = false; end
end
gridIdx = gridIdx(keep);  grR = grR(keep);  grC = grC(keep);
nG = numel(gridIdx);
fprintf('[GRID] %d interior contra pixels (uniform %d-px lattice, %d-px edge margin; target %d)\n', ...
    nG, d, em, nGrid);

% (6) Spontaneous interstim frames (post-settle) — same split as [CP-HEMI]
ons = zeros(numel(all_starts),1);
for j = 1:numel(all_starts), [~,ons(j)] = min(abs(t_full - all_starts(j))); end
settle = round(settle_s*Fs);  frames = [];
for j = 1:numel(ons)
    i0 = ons(j) + settle;                       % start settle_s (2 s) after onset
    if j < numel(ons), i1 = ons(j+1)-2; else, i1 = nF_m; end   % end 2 frames before next onset
    i0 = max(i0,1);  i1 = min(i1,nF_m);
    if i1 >= i0, frames = [frames, i0:i1]; end   %#ok<AGROW>
end
frames = unique(frames);  frames = frames(isfinite(y_full(frames)'));
if numel(frames) > maxFrm, frames = frames(round(linspace(1,numel(frames),maxFrm))); end
nTr = floor(trainFrac*numel(frames));
itr = 1:nTr;  ite = nTr+1:numel(frames);

% (7) Precompute the FIXED contra-grid design + fast fit operator
% The 200-pixel contra regressors do NOT depend on the target, so we build the
% z-scored design + a QR (or ridge) fit operator ONCE. Each clicked ipsi pixel then
% only needs a new target vector -> instant refit.
Uflat = reshape(U_cp, nY_cp*nX_cp, nSV_cp);
Xg = double(Uflat(gridIdx,:)) * double(V_cp(:,frames));    % [nG x nFrm] raw grid activity (fixed)
mu_p = mean(Xg(:,itr),2);  sd_p = std(Xg(:,itr),0,2);  sd_p(sd_p==0) = 1;   % TRAIN z-score
Ztr = ((Xg(:,itr) - mu_p)./sd_p).';  Zte = ((Xg(:,ite) - mu_p)./sd_p).';
Ate = [ones(numel(ite),1) Zte];                            % test design w/ intercept (ols/ridge)

D = struct();  D.fit_mode = lower(fit_mode);
switch D.fit_mode
    case 'lasso'                                           % L1 (+ optional L2 = elastic net)
        D.Ztr = Ztr;  D.G = Ztr.'*Ztr;  D.Gdiag = diag(D.G);  D.l1_frac = l1_frac;  D.ridge = ridge;
    case 'ridge'
        Atr = [ones(numel(itr),1) Ztr];  Rg = ridge*eye(nG+1);  Rg(1,1) = 0;
        D.fitOp = (Atr.'*Atr + Rg) \ Atr.';                % coef = fitOp*ytr
    otherwise                                              % ols
        Atr = [ones(numel(itr),1) Ztr];  [Qa,Ra] = qr(Atr,0);
        D.fitOp = @(yv) Ra \ (Qa.'*yv);                    % coef = fitOp(ytr)
end

% package everything the refit + click callback need
D.debias=debias;
D.Uflat=Uflat; D.V=V_cp; D.frames=frames; D.itr=itr; D.ite=ite;
D.mu_p=mu_p; D.sd_p=sd_p; D.Ate=Ate;
D.grR=grR; D.grC=grC; D.gridIdx=gridIdx; D.nY=nY_cp; D.nX=nX_cp;
D.mimg=mimg_cp; D.k=k_prim; D.Fs=Fs; D.ipsi=logical(ipsi_mask);

% ---- ONE display-orientation transform shared by ALL brain-map overlays (§8,§10,§14,§16,§17b) ----
% resolve_orient turns the disp_orient knob into a Torient: 'auto' = pick_orient auto-normalizes
% (ipsi right, midline vertical); any other value forces a fixed dihedral view (e.g. 'transpose' =
% canonical imagesc(mimg')). Every overlay draws Torient.imgOp(mimg) and places grid/site via
% orient_fwd, and clicks invert through the SAME Torient, so the choice is display-only and pixel
% selection is unaffected on any session.
Torient = resolve_orient(disp_orient, contra_mask, ipsi_mask, px_prim, py_prim, nY_cp, nX_cp, ...
                         get_ant_rc(allExperiments(selExp)));
[dspGr, dspGc] = orient_fwd(Torient, grR, grC);            % grid pixels -> display (row,col)
[dspSr, dspSc] = orient_fwd(Torient, px_prim, py_prim);    % laser site  -> display (row,col)
oI_ = Torient.imgOp(mimg_cp);  dspImg = (oI_-min(oI_(:)))/max(max(oI_(:))-min(oI_(:)),eps);  % oriented brain [Hd x Wd]


%% ==================================================================
% STAGE 1 -- EVOKED PREP + TF-BASED AFFECTED DETECTION
% ==================================================================

% (10) [AFFECT] TASK 2 — per-amp IMPULSE-RESPONSE detection (matched filter to the stim impulse)
% Question (task 2): per amplitude, which contra pixels show a genuine STIM-LOCKED IMPULSE response
% (not slow non-stim wander)?  A window-mean-vs-0V-null test is a BAD metric: it flags any deviation
% in the window (false positives from ongoing fluctuations) and cancels/misses biphasic impulses
% (false negatives). So we test the impulse SHAPE directly with a MATCHED FILTER:
%   template  T = the PRIMARY-pixel evoked impulse at the strongest amp (cleanest dip+rebound),
%                 DEMEANED + unit-norm over [onset -> settle]  -> a constant offset / slow drift
%                 projects to ~0 (kills the false positives), and the whole waveform is used at once
%                 (catches the biphasic impulses the mean missed).
%   score  s_pa = < pixel-p evoked at amp a (demeaned over the window), T >   (matched-filter output)
%   null       = the SAME projection applied to size-matched 0 V bootstrap trial-averages (per pixel)
% Pixel is "stim-affected at amp a" if |z(s)| > impulse_z vs that 0 V null; corr = cosine to T (shape
% match, reported). BASELINE = 0 V catch trials (or a spont pseudo-catch if a session has none — so
% AL_0041 e2 falls back automatically). Output `affected` [nG x nA] feeds the TASK-3 stim-blind
% selection (uses the UNAFFECTED pixels). The data-driven recovery/settle landmarks are still read
% per amp from the primary impulse (used for the window + the §16b viewer marks).
bleed_preSec  = 0.5;   bleed_postSec = 1.0;    % baseline / post window (s)
bleed_nRand   = 1000;  threshFactor  = 1.0;    % 0V-bootstrap draws (raised 200->1000: shrinks the null's
                                               %   sampling error so borderline pixels stop flipping); evoked
                                               %   must exceed threshFactor*null(95%)
maxBaseTrl    = 500;                            % cap 0 V trials used (gap-fill amp-0 can be many)

mI_grid = double(mimg_cp(gridIdx));                                          % [nG x 1] baseline F
Xpct = (double(Uflat(gridIdx,:)) * single(V_cp)) ./ single(mI_grid) * 100;  % %dF/F [nG x nFrames]
nFall = size(Xpct,2);
preN = round(bleed_preSec*Fs);  postN = round(bleed_postSec*Fs);  rel = (-preN:postN);
Wb = numel(rel);  postCols = (preN+1):Wb;                                    % columns at/after onset

% --- 0 V baseline: trial-average of the amp-0 (catch) onsets --------------------------
% If the session has NO 0 V catch trials (e.g. AL_0041 e2), sample a per-session "no-stim"
% baseline from the SPONTANEOUS gaps between impulse trials (midpoint of each inter-onset gap,
% kept clear of neighbouring impulses). Unlike a true 0 V catch this does not carry the
% shutter/galvo command artifact, but the PRIMARY §17b stim-blind model baselines per-trial
% pre-onset (does not use this), so it is unaffected; here the bleed null becomes
% evoked-vs-spontaneous rather than evoked-vs-command.
ia0 = find(uAmp==0, 1);
if isempty(ia0)
    impF = zeros(numel(all_starts),1);
    for j=1:numel(all_starts), [~,impF(j)] = min(abs(t_full - all_starts(j))); end
    impF = sort(impF);
    mids  = round((impF(1:end-1)+impF(2:end))/2);                          % inter-trial gap midpoints
    gapok = (impF(2:end)-impF(1:end-1)) > (preN+postN+round(1.5*Fs));      % enough clear room
    onF0  = mids(gapok);
    onF0  = onF0(onF0-preN>=1 & onF0+postN<=nFall);
    fprintf('[BLEED] no 0 V catch -> %d pseudo-catch windows sampled from inter-trial spontaneous gaps\n', numel(onF0));
else
    onF0 = local_onsets(imp_data.startTimes{ia0}(:), t_full, preN, postN, nFall);
end
if numel(onF0) > maxBaseTrl, onF0 = onF0(round(linspace(1,numel(onF0),maxBaseTrl))); end  % cap
nT0 = numel(onF0);
if nT0 < 2, error('[BLEED] only %d usable 0 V trials — need >=2 for a baseline.', nT0); end
[m0, blk0] = local_periavg(Xpct, onF0, rel, preN, nG, Wb);                   % [nG x Wb] 0 V baseline

amps = uAmp(uAmp>0);  nA = numel(amps);
mResp = nan(nG,Wb,nA);  nT_amp = zeros(nA,1);  onFcell = cell(nA,1);  blkA = cell(nA,1);   % blkA: per-trial pre-stim-baselined evoked
for ai = 1:nA
    onF = local_onsets(imp_data.startTimes{find(uAmp==amps(ai),1)}(:), t_full, preN, postN, nFall);
    nT = numel(onF);  nT_amp(ai) = nT;  onFcell{ai} = onF;
    if nT==0, continue; end
    [mA, bA] = local_periavg(Xpct, onF, rel, preN, nG, Wb);
    mResp(:,:,ai) = mA - m0;                                              % evoked EXCESS over 0 V [nG x Wb] (kept for §10 / SETTLE / SELECT)
    blkA{ai} = bA - mean(bA(:,1:preN,:), 2);                             % [nG x Wb x nT] per-trial, PRE-STIM baseline removed (detector input)
end

% --- data-driven per-amp INHIBITION [onset->recovery] + REBOUND [recovery->settle] windows ---------
% landmarks from the PRIMARY-pixel evoked impulse (cleanest signal), so no hardcoded window is used.
y0tr = double(reshape(y_full(onF0(:).'+rel(:)),Wb,nT0)); y0tr = y0tr - mean(y0tr(1:preN,:),1); y0p = mean(y0tr,2);
% Tolerance factors defining the recovery + settle bands. SINGLE SOURCE OF TRUTH for the inhibition/
% settle landmarks — §15 [SETTLETIME] reuses the per-amp windows (recMs/setMs), trough (troughMs/troughDf)
% and bands (recTol/setTol) stored here rather than recomputing them; do not re-declare these there.
recTolFac = 0.05;   % recovery band = max(2*baselineSD, recTolFac*|trough|)
setTolFac = 0.10;   % settle   band = max(2*baselineSD, setTolFac*|trough|)
inhCols = cell(nA,1);  rebCols = cell(nA,1);  recMs = nan(nA,1);  setMs = nan(nA,1);  mAmpP = nan(Wb,nA);
troughMs = nan(nA,1);  troughDf = nan(nA,1);  recTol = nan(nA,1);  setTol = nan(nA,1);   % trough + bands (for §15)
for ai = 1:nA
    onF = onFcell{ai};  if isempty(onF), continue; end
    tra = double(reshape(y_full(onF(:).'+rel(:)),Wb,numel(onF)));  tra = tra - mean(tra(1:preN,:),1);
    mp  = mean(tra,2) - y0p;  mAmpP(:,ai) = mp;  bsd = std(mp(1:preN));  seg = mp((preN+1):Wb);
    [dTr,iLoc] = min(seg);  iT = preN + iLoc;  tol = max(2*bsd, recTolFac*abs(dTr));   % trough + recovery band
    rc = iT - 1 + find(mp(iT:Wb) >= -tol, 1, 'first');                            % recovery = 1st return to baseline
    if isempty(rc) || rc<=preN, rc = min(Wb, preN+round(dip_win_s*Fs)); end
    tolS = max(2*bsd, setTolFac*abs(dTr));  lb = find(abs(mp((preN+1):Wb)) > tolS, 1, 'last');  % settle = last excursion
    se = preN + max(lb,1);  if isempty(lb), se = rc; end
    r1 = min(rc+1, Wb);
    inhCols{ai} = (preN+1):rc;  rebCols{ai} = r1:max(r1, se);
    recMs(ai) = rel(rc)/Fs*1000;  setMs(ai) = rel(min(se,Wb))/Fs*1000;
    troughMs(ai) = rel(iT)/Fs*1000;  troughDf(ai) = dTr;  recTol(ai) = tol;  setTol(ai) = tolS;   % landmarks for §15
end

% --- IMPULSE-RESPONSE detection: matched filter to the stim impulse SHAPE vs a per-pixel 0V null ----
impulse_z = 2.0;   % SIGNED z of the matched-filter score vs 0V null (amplitude gate; scales w/ amp)
corr_min  = 0.40;  % AND require SIGNED cosine-to-template >= this (SHAPE gate). Both are SIGNED (not |.|)
                   %   so ONLY inhibition (a dip in the template direction) is flagged -- a positive/
                   %   up-going deflection anti-correlates with the dip template and is REJECTED. This
                   %   kills the far, positive-peak false positives (they are not stim inhibition).
% ONE fixed canonical template + ONE window for all amps (both prior per-amp variants failed): a single
% strong-amp template decorrelates from weak low-amp impulses (0% at 0.5-3.2 V), while a per-amp template
% has an UNSTABLE data-driven window — a noisy weak-amp template's ">20% of peak" tail sprawls to ~1000 ms
% and picks up hemodynamic wander (spurious 65% at 0.5 V). Fix: build the template from the STRONG-HALF
% amps AVERAGED (high SNR -> clean, stable dip+rebound SHAPE), derive the window from THAT clean average,
% then apply the same shape+window at every amp. Amplitude is handled by the z-gate (bigger evoked ->
% bigger score -> bigger z); the shape is amplitude-invariant (trough ~143 ms, rebound ~571 ms per §15).
[~,ord] = sort(amps,'descend');  useA = ord(1:max(1,round(nA/2)));   % strongest half of amps (clean shape)
Tcan = mean(mAmpP(:,useA),2,'omitnan');                             % [Wb x 1] clean averaged primary impulse
% Template = the INHIBITION (dip) portion only, NOT dip+rebound. The rebound is amp-DEPENDENT (height
% 0.40 at 1.1 V -> 1.19 at 4.9 V per §15), so a dip+rebound template decorrelates from low/mid-amp dip
% pixels (which have the dip but little rebound) -> they fail the corr gate and the detector reads 0% at
% 1.1-3.2 V despite a clear dip (BLEEDCHAR/FARPIX both find tens of px there). The DIP is the
% amplitude-invariant neural-impulse signature (trough ~143 ms at every amp). Window = onset -> the clean
% template's recovery (first return toward baseline after the trough) -> data-driven, no hardcoded window.
segC = Tcan((preN+1):Wb);  bsdC = std(Tcan(1:preN));  [dTrC,iLc] = min(segC);
tolC = max(2*bsdC, 0.05*abs(dTrC));
rcC  = iLc - 1 + find(segC(iLc:end) >= -tolC, 1, 'first');          % recovery = end of inhibition
if isempty(rcC) || rcC<3, rcC = round(dip_win_s*Fs); end
wcols = (preN+1):min(Wb, preN+rcC);                                 % onset -> recovery (dip only)
Tw = Tcan(wcols);  Tw = Tw - mean(Tw);  Tw = Tw/max(norm(Tw),eps);  % demeaned unit dip template (fixed across amps)
affected = false(nG,nA);  zImp = nan(nG,nA);  corrImp = nan(nG,nA);
% PEAK-TIME gate: a pixel is characterized as stim-affected ONLY if its LARGEST evoked deflection (the
% "evoked peak", |amp-0V| over the full post-onset window) lands within peak_max_ms of onset. The genuine
% stim inhibition troughs at ~143 ms (§15, amplitude-invariant), so anything peaking late is non-stim
% wander (hemodynamic / slow behavioral drift) that happened to slope like the dip inside the 286 ms
% matched-filter window. Without this, such late deviations get mischaracterized as bleed. (Only removes
% false positives on the AFFECTED side; unaffected-pixel identification is unchanged.)
peak_max_ms = 700;
postAll = (preN+1):Wb;  tPostMs = rel(postAll)/Fs*1000;              % post-onset time axis (ms)
peakMsA = nan(nG,nA);                                                % evoked-peak time per px/amp (audit)
fprintf('\n[AFFECT] per-amp IMPULSE-SHAPE match — matched filter over %.0f ms (|z|>%.1f AND |corr|>%.2f AND peak<=%dms):\n', ...
    1000*numel(wcols)/Fs, impulse_z, corr_min, peak_max_ms);
fprintf('   %-8s %6s | %10s %14s\n','amp(V)','nTrl','%%affected','med|corr| (aff)');
for ai = 1:nA
    nT = nT_amp(ai);  if nT==0, continue; end
    Ev = mResp(:,wcols,ai);  Ev = Ev - mean(Ev,2);                    % pixel evoked over window, demeaned
    s  = Ev*Tw;                                                       % [nG x 1] matched-filter score
    corrImp(:,ai) = s ./ max(sqrt(sum(Ev.^2,2)), eps);              % cosine to template (Tw is unit-norm)
    nd = nan(nG,bleed_nRand);                                         % per-pixel 0V null of the SAME projection
    for r = 1:bleed_nRand
        bb = blk0(:,:, randi(nT0, nT, 1));  mb = mean(bb - mean(bb(:,1:preN,:),2), 3) - m0;
        e = mb(:,wcols);  e = e - mean(e,2);  nd(:,r) = e*Tw;
    end
    zImp(:,ai) = (s - mean(nd,2))./max(std(nd,0,2),eps);
    [~,iPk] = max(abs(mResp(:,postAll,ai)),[],2);                     % time of biggest evoked deflection
    peakMsA(:,ai) = tPostMs(iPk(:));  peakOK = peakMsA(:,ai) <= peak_max_ms;
    affected(:,ai) = (zImp(:,ai) > impulse_z) & (corrImp(:,ai) > corr_min) & peakOK;  % DIP dir + early peak
    fprintf('   %-8.2f %6d | %9.0f%% | %14.2f\n', amps(ai), nT, ...
        100*nnz(affected(:,ai))/nG, median(corrImp(affected(:,ai),ai),'omitnan'));
end
% legacy names for the per-amp map figure + click-verifier below (affected = stimDev > nullThr holds)
stimDev = zImp;  nullThr = impulse_z*ones(nG,nA);

gB = dspImg;                                                               % oriented brain (Torient) — also used by §10T3 TF map
% --- OLD matched-filter map + per-trial click-verifier. OFF by default: the pipeline is TF-based,
%     so the affected-pixel clicker is §10T3 (tfmap_click). Set true to inspect the raw seed labels. ---
show_matched_map = false;
if show_matched_map
    figB = figure('Color','w','Name','BLEED — definitely stim-affected contra pixels (per amp)', ...
        'Units','pixels','Position',[100 60 1200 780]);
    nCols = min(nA,3);  nRows = ceil(nA/nCols);  axB = gobjects(nA,1);
    for ai=1:nA
        ax = subplot(nRows,nCols,ai,'Parent',figB);  hold(ax,'on');
        image(ax, repmat(gB,[1 1 3]));  axis(ax,'image','off');  set(ax,'YDir','reverse');
        aff = affected(:,ai);
        scatter(ax, dspGc(~aff), dspGr(~aff), 12, [0.75 0.75 0.75], 'filled', 'MarkerEdgeColor',[0.4 0.4 0.4], 'LineWidth',0.2);
        scatter(ax, dspGc(aff),  dspGr(aff),  20, 'k', 'filled', 'MarkerEdgeColor','k');
        plot(ax, dspSc, dspSr, 'r+', 'MarkerSize',12, 'LineWidth',1.6);
        title(ax, sprintf('%.2f V   %d/%d affected', amps(ai), nnz(aff), nG), 'FontSize',12,'FontWeight','bold');
        axB(ai) = ax;
    end
    sgtitle(figB, sprintf('Definitely stim-affected contra grid px (black)  %s %s e%d  — click a pixel to inspect', ...
        mn, td, en), 'FontSize',13,'FontWeight','bold');
    DB = struct('axB',axB,'amps',amps,'grR',grR,'grC',grC,'gdR',dspGr,'gdC',dspGc, ...
                'mResp',mResp,'stimDev',stimDev, ...
                'nullThr',nullThr,'affected',affected,'rel',rel,'Fs',Fs,'postCols',postCols, ...
                'nT_amp',nT_amp,'nT0',nT0,'preN',preN, ...
                'Xpct',Xpct,'onFcell',{onFcell},'onF0',onF0, ...          % per-trial pull for the verifier
                'gimg',gB,'site',[px_prim py_prim],'sdR',dspSr,'sdC',dspSc); % brain + site (orig + display)
    guidata(figB, DB);  set(figB,'WindowButtonDownFcn',@bleed_click);
    fprintf('[BLEED] click any pixel -> VERIFIER: per-trial traces + 0V baseline + spatial location/distance.\n');
end

%% =====================================================================
% §10T [AFFECT-TF] -- per-pixel biphasic (inhibition -> rebound) TF fit
%   A contra pixel is "stim-affected" at an amp iff a low-order transfer function fit
%   to its trial-averaged evoked (a) explains the response better than the 0V noise
%   floor (VAF beats a per-amp 0V-null gate) AND (b) is a net INHIBITION (fitted
%   impulse-response dip < 0). A 2nd-order TF NATURALLY carries the inhibition->rebound
%   shape (complex poles -> a dip then an overshoot). We do NOT require the trough time
%   to match the ipsi reference -- that over-strict gate made the old detector miss real
%   responses (e.g. g241 @ 4.3V); the biphasic shape is the TEMPLATE we fit, and
%   fit-quality + net-dip is the acceptance. Baseline = each trial's own PRE-STIM mean
%   (blkA, built in §10). MEX-free Prony fit (no tfest/sim -> cannot hit the sssim crash).
%   Sensitivity = tf_sens: threshold = vafGate/tf_sens, so >1 -> more affected, <1 stricter.
% =====================================================================
% --- TF fit knobs (adjustable) ---
tf_np = 2;  tf_nz = 1;  tf_nd = 0;   % fixed TF order [poles zeros delay] (used only if tf_sweep=false).
tf_sweep = true;                     % AIC-sweep the order per pixel (<= tf_maxP/tf_maxZ). ON by default so a
                                     % LONGER/STRONGER rebound gets its OWN 3rd pole (a distinct slow rebound mode),
                                     % while simple dips stay 2-pole -> AIC guards against blanket over-fitting.
tf_maxP  = 3;  tf_maxZ = 2;          % sweep ceiling. 3 poles = onset-rise + inhibition + rebound as 3 modes
                                     % (2p couples dip & rebound timescales -> can't fit a strong slow rebound; see 4.3 V).
tf_sens  = 1;                        % SENSITIVITY: divides the pre-stim (+ optional VAF) threshold. >1 -> MORE affected. Live slider.
                                     % NOTE: this is only the STARTING value -- if a confirmed sens has been
                                     % saved for this session it is restored below (see tf_reuseSens).
tf_reuseSens = true;                 % REUSE the last CONFIRMED tf_sens for this session instead of re-selecting
                                     % every run (consistency: the affected set feeding §17d/§17c/§18 stays FIXED
                                     % across runs). Restored only if the TF-fit cache key still matches.
                                     % Set false (or delete data/tf_sens_<sess>.mat) to choose a new one.
if exist('OLS_OVERRIDE','var') && isstruct(OLS_OVERRIDE) && isfield(OLS_OVERRIDE,'tf_reuseSens')
    tf_reuseSens = OLS_OVERRIDE.tf_reuseSens;   % batch-driver hook (declared after §1's hook, so applied here)
end
tf_nBoot = 60;                       % 0V-null VAF draws per amp (for the VAF display + optional gate)
tf_vafFloor = 15;                    % floor under the per-amp 0V-null VAF (display only)
% VAF-vs-0V-null is NO LONGER a detection gate: with the flexible stmcb+sweep fit, a fit to 0V noise scores
% ~ as high as a fit to signal, so that gate self-defeats (nothing beats its own noise ceiling). Kept as an
% OPTIONAL absolute shape-quality floor only.
tf_useVAF = false;                   % if true, ALSO require VAFtf > tf_vafMin (absolute, NOT the null). Default OFF.
tf_vafMin = 40;                      % absolute VAF floor (%) when tf_useVAF -- rejects garbage-shaped fits, not noise
tf_reqReb = false;                   % KEEP FALSE. Rebound is NOT a detection criterion: a small genuine
                                     % effect may have no rebound at all (user 2026-08-05). Retained only
                                     % as a reported diagnostic. Recovery (tf_recFracMax) is the shape test.
tf_rebMin = 0.05;                    % if tf_reqReb: min reboundRatio (rebound height / dip depth)
% ---- SHAPE GATE (2026-08-05) -- what makes a fit an IMPULSE response rather than a ramp ------------
% THE BUG THIS FIXES: DIPgate is min() of the fitted response over [0, tf_dipCapSec] -- a pure DEPTH
% statistic with no information about whether the response ever comes back. A monotonically descending
% fit reaches its minimum at the LAST sample of the cap window, so it not only passes the old gate, it
% scores DEEPER than a genuine dip-and-recover with the same early slope -> ramps were preferentially
% selected (g241 @ 3.7 V, AL_0041 e2). Two shape tests, both computed on the SAME capN window the gate
% uses (the old reboundRatio was computed over the longer fit window nT -- a real inconsistency):
%   TROUGH TIME  the trough must occur INSIDE a plausible band, not pinned to the window edge. Session
%                landmarks put the real trough at 114-143 ms (§15), so a ramp -- trough at capN = 400 ms
%                -- fails on this alone. This is the cheapest, highest-yield test.
%   RECOVERY     recFrac = y(capN)/dip = how much of the dip is STILL present at the end of the window.
%                ramp ~1 (or >1); dip-and-recover ~0; overshoot < 0. Requiring recFrac <= max ACCEPTS a
%                response that merely returns to baseline (no rebound needed) and rejects one that does
%                not. Consistent with the session's own median recovery ~314 ms (see dip_win_s note).
tf_useShape   = true;                % apply the trough-band + recovery tests (set false for the old depth-only rule)
tf_recMaxFac  = 2.0;                 % RECOVERY test: the pixel's evoked must return to its baseline band within
                                     % this multiple of the IPSI recovery time. >1 because a contra pixel is driven
                                     % THROUGH the network and may legitimately recover later than ipsi -- the same
                                     % asymmetry the trough band encodes. (Superseded tf_recFracMax as the gate.)
tf_recFracMax = 0.30;                % DIAGNOSTIC ONLY since 2026-08-05: fraction of the FITTED dip still remaining
                                     % at capN. No longer gates -- it rejected pixels whose DATA had visibly
                                     % recovered but whose sluggish fixed-order fit had not (g406 @ 2.7 V).
% ---- LEARNED gate window (2026-08-05): take it from the IPSI response, not a constant ---------------
% The gate window is now the ipsi INHIBITION LOBE for THIS amplitude: onset -> ipsi recovery, i.e.
% numel(inhCols{ai}), computed per amp per session at §10. Why this landmark and not a scaled trough:
% rebCols{ai} starts at rc+1, so capping at recovery makes the gate window EXACTLY the inhibition lobe
% and DISJOINT from the rebound lobe by construction -- the property dip_win_s=0.300 was hand-tuned to
% approximate, now obtained exactly, per amp, per session, with no constant to maintain. It also removes
% a real inconsistency: dip_win_s calls itself the single source of truth for the dip window while
% tf_dipCapSec was a second, hard-coded one used only by the detector.
% Trough band scales off the ipsi trough ASYMMETRICALLY: a contra pixel driven through the network
% should trough with ipsi or LATER, never meaningfully earlier, so a symmetric band would spend its
% lower half on physically implausible latencies. Session-adaptive matters for AL_0048, whose readout
% sits 2.6 mm from the illumination and has no reason to share AL_0033's latency.
tf_capFromIpsi = true;               % false -> fall back to the fixed tf_dipCapSec / tf_troughMs below
tf_troughFac   = [0.6 2.5];          % admissible trough band as a multiple of the ipsi trough time
tf_troughMs    = [60 250];           % FALLBACK trough band (ms), used only where the ipsi landmark is missing
tf_smoothN = 3;                      % pre-fit smoothing (movmean samples, ~85 ms) -- tames the noise the fit amplifies; 1 = off
% BASELINE significance gate (PRIMARY): the inhibition trough must be DEEPER than the pixel's own baseline
% fluctuation -- measured over a long window BEFORE stim AND (optionally) the settled activity AFTER the
% response. A multiple of the baseline SD OR its max ABS deviation about the mean (worst swing EITHER way,
% up or down -- a pixel that swings +2 spontaneously is that noisy, so a -2 dip is not significant). Rejects pixels whose "dip"
% is within normal fluctuation, independent of fit quality. All on the trial-averaged footing (as the trough).
tf_preSec      = 4;                  % pre-stim baseline window (s) BEFORE onset
tf_usePost     = true;               % ALSO pool post-response (settled) activity into the baseline floor
tf_postStartSec= 0.8;                % post-stim baseline starts here (after the response; >= fit window end)
tf_postSec     = 4;                  % desired post-stim baseline length (s); auto-clamped to the next stim onset
tf_kSD     = 2.5;                    % trough must exceed tf_kSD x baseline SD (the trial-mean trough is already
                                     % noise-reduced, so ~2.5x is a real, not over-strict, bar)
tf_kRange  = 1;                      % ...and the floor also uses tf_kRange x |max abs baseline deviation, EITHER way| (max of the two)
Ts = 1/Fs;  nPreZ = tf_maxP+tf_maxZ+2;   % (nPreZ unused by the fit; kept for the helper signature)
tf_refAmpIdx = nA;

% FIXED fit window: onset -> +tf_winSec (captures the full inhibition + a long/strong rebound). User-set,
% same for every amp; supersedes the per-amp landmark window. Widen tf_winSec if some regions' rebound runs
% past it (at the cost of fitting more late hemodynamic drift).
tf_winSec = 0.6;                                             % 600 ms
winA = cell(nA,1);
for a = 1:nA
    winA{a} = (preN+1):min(Wb, preN+round(tf_winSec*Fs));
end
tf_win = winA{tf_refAmpIdx};

% DIP-CAP: the STIM-driven inhibition trough must occur EARLY. The fit spans the full tf_winSec (needs the
% tail to shape the rebound), but the dip used for GATING is searched only within [0, tf_dipCapSec] -- a
% deeper trough LATER in the window is natural drift/second dip, not the stim response, so it must not gate.
% LIVE knob (not in the cache key): re-thresholds off the cached fitted impulse responses, no refit.
tf_dipCapSec = 0.4;                                          % 400 ms (stim trough ~114 ms; margin for slower regions)
tms = rel/Fs*1000;                                            % peri-onset time axis (ms) -- §10T precedes §15
recMsA = recMs(:);  setMsA = setMs(:);                        % §10 dip/rebound landmarks (inspector shading)
for ai = 1:nA
    if ~isfinite(recMsA(ai)), recMsA(ai) = 300; end
    if ~isfinite(setMsA(ai)), setMsA(ai) = rel(tf_win(end))/Fs*1000; end
end
affect_mode = 'tf';                                          % 'matched' (=§10) | 'tf' (=this) -> which map feeds §17b
if exist('OLS_OVERRIDE','var') && isstruct(OLS_OVERRIDE) && isfield(OLS_OVERRIDE,'affect_mode')
    affect_mode = OLS_OVERRIDE.affect_mode;                  % batch-driver hook (see top of file)
end

% ---- BASELINE fluctuation per pixel: PRE-stim (tf_preSec s before) + POST-response (settled) activity ----
% This floor is compared to the FITTED dip DIPtf (trough of the fit to the trial-MEAN evoked), so it MUST be
% on the same trial-averaged footing: we TRIAL-AVERAGE each baseline window first, then take SD + worst-min --
% else a fit to an averaged trace (noise reduced by sqrt(nT)) vs raw single-trial fluctuation is a
% ~sqrt(nT)-too-high bar (nothing passes). PRE window clamped to what every trial has (<= tf_preSec). POST window (after the response, from
% tf_postStartSec) clamped to the nearest NEXT stim onset (any amp or 0V) so it stays stim-free. Each window
% is DC-removed per trial (separately), trial-averaged, and the two averaged traces are POOLED for the stats.
allOn  = sort([cell2mat(cellfun(@(x)x(:),onFcell(:),'uni',0)); onF0(:)]);   % every stim onset in the session
preN4  = round(tf_preSec*Fs);  psF = round(tf_postStartSec*Fs);  guardF = 3;
preStd = nan(nG,nA);  preRange = nan(nG,nA);
for a = 1:nA
    onF = onFcell{a};  if isempty(onF), preStd(:,a)=inf; preRange(:,a)=inf; continue; end
    base = zeros(nG,0);                                     % pooled trial-averaged baseline trace
    pn = min(preN4, min(onF)-1);                            % PRE: clamp so every trial has a full window
    if pn >= 4
        idx = onF(:).' + (-pn:-1).';
        pre = reshape(double(Xpct(:, idx(:))), nG, pn, numel(onF));  pre = pre - mean(pre,2);
        base = [base, mean(pre,3)];                         %#ok<AGROW>  trial-averaged pre trace
    end
    if tf_usePost                                           % POST: settled activity, clamped to next stim
        plmax = inf;
        for o = onF(:).'
            nn = allOn(allOn > o);
            if isempty(nn), gap = nFall - o; else, gap = nn(1) - o; end
            plmax = min(plmax, gap - psF - guardF);
        end
        pl = min(round(tf_postSec*Fs), plmax);
        if pl >= 4
            idxp = onF(:).' + (psF:(psF+pl-1)).';
            post = reshape(double(Xpct(:, idxp(:))), nG, pl, numel(onF));  post = post - mean(post,2);
            base = [base, mean(post,3)];                    %#ok<AGROW>  trial-averaged post trace
        end
    end
    if size(base,2) < 4, preStd(:,a)=inf; preRange(:,a)=inf; continue; end
    preStd(:,a)   = std(base, 0, 2);                        % SD over the pooled trial-averaged baseline
    preRange(:,a) = max(max(base,[],2), -min(base,[],2));   % MAX ABS deviation about the mean (worst swing EITHER way)
end
preThr = max(tf_kSD.*preStd, tf_kRange.*preRange);          % [nG x nA] required inhibition depth (baseline gate)

fprintf('\n[AFFECT-TF] biphasic (inhib->rebound) TF fit | order %s | win 0..%.0f ms (ref %.1f V) | dip-cap 0..%.0f ms | 0V-null %d/amp | tf_sens=%.2f\n', ...
    ternstr(tf_sweep, sprintf('sweep<=%dp%dz',tf_maxP,tf_maxZ), sprintf('%dp%dz%dd',tf_np,tf_nz,tf_nd)), ...
    1000*rel(tf_win(end))/Fs, amps(tf_refAmpIdx), 1000*tf_dipCapSec, tf_nBoot, tf_sens);

% ---- per-pixel fit + per-amp 0V-null VAF gate + CACHE -----------------------------------------------
tf_useCache  = true;
tf_cacheFile = fullfile(dataDir, sprintf('tf_affected_%s_%s%s_e%d.mat', mn, td(6:7), td(9:10), en));
tf_cacheKey  = struct('winEnds',cellfun(@(w)w(end),winA(:)).','order',[tf_np tf_nz tf_nd],'sweep',tf_sweep, ...
                      'maxPZ',[tf_maxP tf_maxZ],'smoothN',tf_smoothN,'nBoot',tf_nBoot,'vafFloor',tf_vafFloor, ...
                      'nT_amp',nT_amp(:).','algo','biphasic_stmcb_v3','nG',nG,'nA',nA);
nWin = max(cellfun(@numel, winA(:)));                             % fitted-response length (fixed window -> same all amps)
tf_loaded = false;
if tf_useCache && exist(tf_cacheFile,'file')
    Cc = load(tf_cacheFile);
    if isfield(Cc,'key') && isequaln(Cc.key, tf_cacheKey)
        VAFtf=Cc.VAFtf; DIPtf=Cc.DIPtf; TRtf=Cc.TRtf; REBtf=Cc.REBtf; DELtf=Cc.DELtf; DIPrawtf=Cc.DIPrawtf; YItf=Cc.YItf; vafGate=Cc.vafGate;
        tf_loaded=true;  fprintf('  [cache] loaded per-pixel TF fit maps -> skipped fitting\n');
    else
        fprintf('  [cache] params changed -> recomputing\n');
    end
end
if ~tf_loaded
    VAFtf=nan(nG,nA); DIPtf=nan(nG,nA); TRtf=nan(nG,nA); REBtf=nan(nG,nA); DELtf=nan(nG,nA); DIPrawtf=nan(nG,nA);
    YItf=nan(nG,nWin,nA);                                          % fitted impulse responses (for the LIVE dip-cap gate)
    vafGate=nan(nA,1);  rng(0);  tstart=tic;
    for a = 1:nA
        if nT_amp(a)==0, vafGate(a)=inf; continue; end
        wa = winA{a};  mu = mean(blkA{a},3);                          % [nG x Wb] pre-stim-baselined trial mean
        DIPrawtf(:,a) = min(mu(:,wa),[],2);                           % RAW trough depth (display/reference only; gate uses fitted DIPtf)
        for g = 1:nG                                                  % serial (parfor worker output crashes the MCP layer)
            r = mu(g,wa).';                                           % windowed trial mean
            if tf_smoothN>1, r = smoothdata(r,'movmean',tf_smoothN); end   % tame the noise Prony/stmcb amplify
            r = r - r(1);                                             % onset-referenced (r(1)=0 = the fit's h[0])
            if tf_sweep, [sys,v,ch] = proto_fitTF(r,Ts,tf_maxP,tf_maxZ,tf_nd,nPreZ,[]);
            else,        [sys,v,ch] = proto_fitTF_fix(r,Ts,tf_np,tf_nz,tf_nd,nPreZ,[]); end
            VAFtf(g,a)=v; DIPtf(g,a)=ch.dip; TRtf(g,a)=ch.troughMs; REBtf(g,a)=ch.reboundRatio; DELtf(g,a)=ch.delayMs;
            YItf(g,1:numel(wa),a) = proto_sim(sys, numel(wa), Ts, nPreZ);   % cache the fitted impulse response
        end
        % 0V-null VAF floor: fit the SAME procedure (sweep or fixed) to 0V pseudo-averages (matched trial
        % count) -> 95th pctile. Must match the real fit: a swept fit grabs more VAF from noise, so the gate
        % rises to compensate (else the extra sweep freedom would over-detect).
        vn = nan(tf_nBoot,1);
        for b = 1:tf_nBoot
            sel = randi(nT0, nT_amp(a), 1);  pav = mean(blk0(:,:,sel),3) - m0;   % 0V pseudo-avg [nG x Wb]
            gg  = randi(nG);  r = pav(gg,wa).';
            if tf_smoothN>1, r = smoothdata(r,'movmean',tf_smoothN); end
            r = r - r(1);
            if tf_sweep, [~,vn(b)] = proto_fitTF(r,Ts,tf_maxP,tf_maxZ,tf_nd,nPreZ,[]);
            else,        [~,vn(b)] = proto_fitTF_fix(r,Ts,tf_np,tf_nz,tf_nd,nPreZ,[]); end
        end
        vafGate(a) = max(tf_vafFloor, prctile(vn(~isnan(vn)),95));
    end
    fprintf('  fit %d px x %d amp + 0V-null in %.0f s\n', nG, nA, toc(tstart));
    if tf_useCache
        key=tf_cacheKey; save(tf_cacheFile,'VAFtf','DIPtf','TRtf','REBtf','DELtf','DIPrawtf','YItf','vafGate','key');
        fprintf('  [cache] saved per-pixel TF fit maps -> %s\n', tf_cacheFile);
    end
end

% per-pixel trial-mean map (pre-stim baselined) for the §10T3 inspector (cheap; recomputed from blkA)
muMap = nan(nG,Wb,nA);
for a = 1:nA, if nT_amp(a)>0, muMap(:,:,a) = mean(blkA{a},3); end, end

% ---- DATA-SIDE shape landmarks: trough + RECOVERY measured on the trial-averaged EVOKED --------------
% Shape is judged on the DATA, not on the fitted response, using the SAME recovery definition ipsi uses
% (§10, ~line 383): first return after the trough to within max(2*baselineSD, recTolFac*|trough|).
% TWO REASONS (2026-08-05, after g406 @ 2.7 V AL_0041 e2 was rejected with the trace visibly recovered):
%  (1) FIT SLUGGISHNESS -- the fixed-order TF lags the sharp real dip (TASKS #183). Judging recovery on
%      the fit rejects pixels whose DATA plainly returns: g406's fit was still 57% down at the window
%      edge while its evoked had recovered. The detector must answer a question about the RECORDING.
%  (2) CONSISTENCY -- ipsi's own trough/recovery landmarks are measured on its trial-averaged evoked,
%      so measuring contra the same way keeps ONE definition of "recovers" in the project.
% Recovery is searched over the WHOLE fit window, not up to capN: a contra pixel is driven THROUGH the
% network, so it may legitimately recover LATER than ipsi (the same asymmetry the trough band encodes).
% Requiring it to be back exactly when ipsi is back was the error in the previous revision.
% The FITTED values (DIPgate/RECfrac below) are retained and printed alongside -- their divergence from
% these is itself the #183 diagnostic.
TRdatMs = nan(nG,nA);  RECdatMs = nan(nG,nA);  DIPdat = nan(nG,nA);  hasRec = false(nG,nA);
for a = 1:nA
    if nT_amp(a)==0, continue; end
    wa = winA{a};  Y = muMap(:,wa,a);  Y = Y - Y(:,1);            % onset-referenced evoked, same window as the fit
    nw = size(Y,2);
    [dv, it] = min(Y, [], 2);
    DIPdat(:,a) = dv;  TRdatMs(:,a) = (it-1)/Fs*1000;
    tolg = max(2*preStd(:,a), recTolFac*abs(dv));                 % SAME band form as the ipsi landmark
    for g = 1:nG
        k = it(g) - 1 + find(Y(g,it(g):nw) >= -tolg(g), 1, 'first');
        if ~isempty(k), RECdatMs(g,a) = (k-1)/Fs*1000;  hasRec(g,a) = true; end
    end
end

% GATED dip = deepest point of the FITTED response within the early cap window [0, tf_dipCapSec]. A deeper
% trough later in the window is natural drift, not the stim dip, so it must not gate. Derived FRESH from the
% cached fitted impulse responses YItf (like preThr) -> tf_dipCapSec is a LIVE knob, no refit on change.
% PER-AMP gate window, learned from the ipsi inhibition lobe (see tf_capFromIpsi above).
capNa = nan(nA,1);  trBandA = nan(nA,2);  capFallback = false(nA,1);
DIPgate = nan(nG,nA);  TRcapMs = nan(nG,nA);  RECfrac = nan(nG,nA);
for ai = 1:nA
    if tf_capFromIpsi && ~isempty(inhCols{ai}) && isfinite(troughMs(ai)) && troughMs(ai) > 0
        capNa(ai)     = min(nWin, numel(inhCols{ai}));            % onset -> ipsi recovery, THIS amp
        trBandA(ai,:) = troughMs(ai) * tf_troughFac;              % band scaled off the ipsi trough
    else
        capNa(ai)     = min(nWin, round(tf_dipCapSec*Fs)+1);      % fallback: the old fixed window
        trBandA(ai,:) = tf_troughMs;
        capFallback(ai) = true;
    end
    cN  = max(1, capNa(ai));
    Yc  = YItf(:,1:cN,ai);
    [dv, it] = min(Yc, [], 2);                                    % depth AND its position (position = the shape info)
    DIPgate(:,ai) = dv;
    TRcapMs(:,ai) = (it-1)/Fs*1000;                               % trough TIME within the gate window (ms)
    RECfrac(:,ai) = Yc(:,cN) ./ min(dv, -eps);                    % dip remaining at capN: ~1 ramp, ~0 recovered, <0 overshoot
end
if any(capFallback)
    % Not silent: a fallback means that amp's ipsi never recovered, which is itself worth knowing --
    % and it reverts to the hard-coded window, so the gate is no longer the learned one for that amp.
    warning(['[AFFECT-TF] amp(s) %s have no usable ipsi recovery landmark -> gate window fell back to the ' ...
             'FIXED %.0f ms / trough band [%g %g] ms. Those amps are not gated on the learned window.'], ...
             mat2str(find(capFallback).'), 1000*tf_dipCapSec, tf_troughMs(1), tf_troughMs(2));
end
fprintf('  gate window (learned from ipsi inhibition lobe): ');
fprintf('%.0f ms ', 1000*(capNa-1)/Fs);  fprintf('| trough bands: ');
fprintf('[%.0f-%.0f] ', trBandA.');  fprintf('\n');

% ---- PROVISIONAL affected mask (re-thresholded live in §10T3) ----
% PRIMARY: the FITTED EARLY-window dip (DIPgate = deepest fit point in [0, tf_dipCapSec], as drawn in the
% inspector) must beat the baseline fluctuation floor (both scaled by tf_sens). The fit is zeroed at onset so
% DIPgate IS the denoised stim drop; preThr is already the fluctuation about the MEAN pre-stim activity (base
% is per-trial DC-removed) -> directly comparable, no raw-onset-sample term. VAF-vs-null is NOT a gate.
% ---- RESTORE the last CONFIRMED sensitivity (run-to-run consistency) -------------------------------
% The per-pixel TF fit MAPS are cached (tf_cacheFile), but the HUMAN DECISION made at the §10T3 selector
% -- tf_sens -- was not. So every run re-thresholded at the default and asked for a fresh CONFIRM, and any
% drift in that slider silently changed the affected set, and therefore §17d/§17c/§18, between runs. The
% confirmed value is now saved on CONFIRM and restored here, keyed by the SAME tf_cacheKey as the fit maps:
% if the fit params change, the saved sens is DISCARDED rather than silently reapplied to different maps.
tf_sensFile = fullfile(dataDir, sprintf('tf_sens_%s_%s%s_e%d.mat', mn, td(6:7), td(9:10), en));
% Key covers the fit params AND the gate rule: a saved sens chosen under the old depth-only gate is not a
% valid selection under the shape gate, so changing tf_useShape/troughMs/recFracMax must invalidate it.
tf_sensKey = struct('fit',tf_cacheKey,'useShape',tf_useShape,'trBandA',trBandA,'capNa',capNa(:).', ...
                    'capFromIpsi',tf_capFromIpsi,'troughFac',tf_troughFac, ...
                    'recMaxFac',tf_recMaxFac,'recMs',recMs(:).','recTolFac',recTolFac, ...
                    'recFracMax',tf_recFracMax,'dipCapSec',tf_dipCapSec, ...
                    'useVAF',tf_useVAF,'vafMin',tf_vafMin,'reqReb',tf_reqReb,'rebMin',tf_rebMin);
tf_sensRestored = false;  tfSaved = [];
if tf_reuseSens && exist(tf_sensFile,'file')
    tfSaved = load(tf_sensFile);
    if isfield(tfSaved,'key') && isequaln(tfSaved.key, tf_sensKey)
        tf_sens = tfSaved.tf_sens;  tf_sensRestored = true;
        fprintf('  [sens] RESTORED confirmed tf_sens=%.2f (saved %s) -> selector will NOT block this run\n', ...
                tf_sens, tfSaved.saved_on);
    else
        fprintf('  [sens] saved tf_sens found but the TF-fit params or the GATE RULE changed -> discarded; a fresh CONFIRM is required\n');
        tfSaved = [];
    end
end

g_dip = (DIPgate < 0);
g_pre = (-DIPgate > preThr./max(tf_sens,eps));
g_vaf = true(nG,nA);  if tf_useVAF, g_vaf = (VAFtf > tf_vafMin); end
g_tr  = true(nG,nA);  g_rec = true(nG,nA);
if tf_useShape                                                   % SHAPE: impulse-like, not a ramp
    g_tr  = (TRdatMs >= trBandA(:,1).') & (TRdatMs <= trBandA(:,2).');   % DATA trough inside this amp's ipsi-derived band
    g_rec = hasRec & (RECdatMs <= tf_recMaxFac * recMs(:).');            % DATA returns to baseline, within tf_recMaxFac x ipsi recovery
end
affected_tf = g_dip & g_pre & g_vaf & g_tr & g_rec;
if tf_reqReb, affected_tf = affected_tf & (REBtf > tf_rebMin); end        % OFF by design: see tf_reqReb note
fprintf('  gate pass (of %d px-amp): dip<0 %d | baseline %d | %s | DATA trough[%.0f-%.0f ms] %d | DATA recovers<=%.1fx ipsi %d -> AFFECTED %d @ tf_sens=%.2f\n', ...
        nG*nA, nnz(g_dip), nnz(g_pre), ...
        ternstr(tf_useVAF, sprintf('VAF>%.0f %d', tf_vafMin, nnz(g_vaf)), 'VAF off'), ...
        min(trBandA(:,1)), max(trBandA(:,2)), nnz(g_tr), tf_recMaxFac, nnz(g_rec), nnz(affected_tf), tf_sens);
% fit-vs-data divergence = the TASKS #183 sluggish-fit diagnostic, surfaced rather than left implicit
fitRecOK = RECfrac <= tf_recFracMax;
fprintf('  [fit-vs-data] the RETIRED fitted-recovery rule would reject %d px-amp that the DATA rule accepts (sluggish fits)\n', ...
        nnz(g_dip & g_pre & g_vaf & g_tr & g_rec & ~fitRecOK));
if tf_useShape
    fprintf('  shape gate rejected %d px-amp that the old depth-only rule would have ACCEPTED (ramps + edge-troughs)\n', ...
            nnz((g_dip & g_pre & g_vaf) & ~(g_tr & g_rec)));
end
fprintf('  per-amp affected: '); fprintf('%d ',sum(affected_tf,1));
fprintf('(vs §10 matched: '); fprintf('%d ',sum(affected,1)); fprintf(')\n');

% Cross-check: with the cache key matched the maps are identical, so re-thresholding at the restored sens
% MUST reproduce the saved mask bit-for-bit. If it does not, something outside the key changed the maps and
% this run is NOT the selection you confirmed -- say so loudly rather than proceeding on a different set.
if tf_sensRestored && isstruct(tfSaved) && isfield(tfSaved,'affected_tf')
    if isequal(tfSaved.affected_tf, affected_tf)
        fprintf('  [sens] mask reproduces the saved CONFIRMED selection exactly (%d px-amp)\n', nnz(affected_tf));
    else
        warning(['[AFFECT-TF] restored tf_sens=%.2f reproduces a DIFFERENT mask than the one saved with it ' ...
                 '(%d vs %d px-amp) despite a matching cache key -- the fit maps changed outside the key. ' ...
                 'Do NOT trust this run''s §17d/§17c/§18 until that is explained.'], ...
                 tf_sens, nnz(affected_tf), nnz(tfSaved.affected_tf));
    end
end

% NOTE: the commit `affected := affected_tf` + the AFFECT_TF struct are DEFERRED to §10T3 below -- they run
% only AFTER the user confirms tf_sens on the interactive selector, so §17b/§17d build on the CONFIRMED set.
% affected_tf above is the PROVISIONAL mask shown when the selector opens.

%% =====================================================================
% §10T3 [AFFECT-TF-SELECT] interactive pixel SELECTOR (gates the model build)
%   Per-amp grid; affected pixels (affected_tf) in BLACK. Tune the NULL PERCENTILE (slider) to grow/shrink
%   the selection live, click a pixel to inspect WHY it flagged/missed (its excess trace vs the 0V-null RMS
%   band), then press CONFIRM -> the script commits `affected` and builds the stim-blind model on THAT set.
%   The script BLOCKS at this figure (uiwait) until Confirm, so selection strictly precedes modelling.
%   The "Refit SELECT model" button re-fits the SPARSE, distance-weighted contra->ipsi model on the
%   CURRENT sensitivity's unaffected px and shows its Actual/Global/Local decomposition (see prep below).
% =====================================================================

% ---- SELECT-MODEL prep: operators for the interactive "Refit SELECT model" button --------------------
% The SELECT model (§17d) is a SPARSE, DISTANCE-WEIGHTED spont contra->ipsi fit: maximize spont R^2 with an
% L1 penalty whose weight GROWS toward the ipsi stim site, so surviving predictors are FEW and FAR from ipsi
% (least stim-contaminated). Penalty p_i = 1/gamma_i; weighted lasso solved by column-rescaling b=gamma.*a
% then uniform cd_lasso (see select_wlasso). Computed here from pre-selector data so the button can refit at
% the current sensitivity; mirrors §17's spont operators + §17b's per-amp z-evoked (a few s of recompute).
select_l1frac  = 0;       % *** NO SPARSITY (user 2026-08-05) *** L1 strength as a fraction of max|rescaled Z'y|.
                          % 0 = OFF -> select_wlasso solves the weighted-ridge problem in closed form, keeps EVERY
                          % unaffected predictor, and maximises held-out SPONTANEOUS R^2 (which is the only thing
                          % R^2 is measured on here -- the stim windows are scored by leak/capture, not R^2).
                          % >0 restores sparsity (0.15 was the value through 2026-08-04).
select_ridge   = 0;       % Weighted-L2 strength as a fraction of mean(diag(Gz)), applied THROUGH the same 1/gamma
                          % distance weights. READ THIS BEFORE LEAVING IT AT 0: the far-from-ipsi prior was carried
                          % ENTIRELY by the L1 weights, so with select_l1frac=0 and select_ridge=0 there is NO
                          % distance prior left -- the fit is plain OLS on every unaffected pixel, near-ipsi ones
                          % included. That maximises R^2 but lets near-ipsi predictors absorb stim signal, which
                          % shows up as HIGHER LEAK / smaller Local. Raise this to dial the prior back in without
                          % reintroducing sparsity (ridge never zeros a weight).
select_penNear = 2.0;     % L1 weight AT the ipsi site (expensive -> near-ipsi predictors dropped)
select_penFar  = 0.2;     % L1 weight at the FARTHEST px (cheap -> far predictors retained)
selDist  = hypot(dspGc(:)-dspSc, dspGr(:)-dspSr);                       % each contra px -> ipsi stim site (display px)
selDn    = (selDist-min(selDist))/max(max(selDist)-min(selDist),eps);   % normalize distance to [0,1]
selPen   = select_penNear*(1-selDn) + select_penFar*selDn;             % per-px L1 weight: HIGH near ipsi, LOW far
selGamma = 1./selPen;                                                  % lasso column-rescale gains (LARGE far, small near)
selYsp = double(y_full(frames));  selYtr=selYsp(itr);  selMuY=mean(selYtr);   % spont operators (z-space; = §17)
selGz  = Ztr.'*Ztr;  selcz = Ztr.'*(selYtr-selMuY);
sellamR = max(1e-6, select_ridge)*mean(diag(selGz));   % 1e-6 = numerical floor; select_ridge = the real weighted-L2
selDipCols = (preN+1):min(Wb, preN+round(dip_win_s*Fs));
selEvZ=cell(nA,1); selAA=cell(nA,1); selDc=cell(nA,1); selRc=cell(nA,1); selSc=cell(nA,1);   % per-amp z-evoked + windows
for ai = 1:nA
    onF=onFcell{ai}; nT=numel(onF); if nT==0, continue; end
    dc=inhCols{ai}; if isempty(dc), dc=selDipCols; end;  rc=rebCols{ai};
    idx=onF(:).'+rel(:);
    Zp=(double(Uflat(gridIdx,:))*double(V_cp(:,idx(:)))-mu_p)./sd_p; Zp=reshape(Zp,nG,Wb,nT);
    evZ=mean(Zp,3); evZ=evZ-mean(evZ(:,1:preN),2);
    aA=mean(reshape(double(y_full(idx(:))),Wb,nT),2); aA=aA-mean(aA(1:preN));
    if ~isempty(rc), se=rc(end); else, se=dc(end); end
    selEvZ{ai}=evZ; selAA{ai}=aA; selDc{ai}=dc; selRc{ai}=rc; selSc{ai}=(preN+1):max(se,dc(end));
end

figT = figure('Color','w','Units','normalized','Position',[0.04 0.06 0.92 0.87], ...
    'Name','TF-AFFECT SELECTOR — tune SENSITIVITY, click to inspect, then CONFIRM to build the model');
nColT = ceil(sqrt(nA));  nRowT = ceil(nA/nColT);
axT = gobjects(nA,1);  hAff = gobjects(nA,1);  hUn = gobjects(nA,1);
for ai = 1:nA
    axT(ai) = subplot(nRowT, nColT, ai);
    imagesc(axT(ai), gB);  colormap(axT(ai), gray);  axis(axT(ai),'image','off');  hold(axT(ai),'on');
    aff = affected_tf(:,ai);
    hUn(ai)  = scatter(axT(ai), dspGc(~aff), dspGr(~aff), 12, [0.75 0.75 0.75],'filled','MarkerEdgeColor',[0.4 0.4 0.4],'LineWidth',0.2);
    hAff(ai) = scatter(axT(ai), dspGc(aff), dspGr(aff), 20, 'k','filled','MarkerEdgeColor','k');
    plot(axT(ai), dspSc, dspSr, 'r+','MarkerSize',12,'LineWidth',1.6);
    title(axT(ai), sprintf('%.1f V   %d aff', amps(ai), nnz(aff)), 'FontSize',10,'FontWeight','bold');
end
sgtitle('§10T3 biphasic-TF affected map — click a pixel to inspect its TF fit vs the 0V-null gate', ...
        'FontWeight','bold');

% --- LIVE sensitivity slider: re-thresholds affected_tf from the cached TF-fit maps (NO refit) ----
uicontrol(figT,'Style','text','Units','normalized','Position',[0.14 0.005 0.16 0.028], ...
    'String','sensitivity  (fewer \leftarrow  \rightarrow more)','FontWeight','bold','BackgroundColor','w','HorizontalAlignment','right');
hSens = uicontrol(figT,'Style','slider','Units','normalized','Position',[0.31 0.008 0.26 0.022], ...
    'Min',0.3,'Max',3,'Value',tf_sens,'SliderStep',[0.01 0.05],'Tag','sensSlider');
hSensTxt = uicontrol(figT,'Style','text','Units','normalized','Position',[0.58 0.005 0.20 0.028], ...
    'String',sprintf('tf\\_sens = %.2f   (%d aff total)', tf_sens, nnz(affected_tf)), ...
    'FontWeight','bold','BackgroundColor','w','HorizontalAlignment','left');
% REFIT button: refit the SPARSE distance-weighted SELECT model on the CURRENT sensitivity's unaffected px
uicontrol(figT,'Style','pushbutton','Units','normalized','Position',[0.005 0.004 0.145 0.032], ...
    'String','Refit SELECT model','FontWeight','bold','BackgroundColor',[0.80 0.86 0.98], ...
    'Callback',@(varargin)select_refit_btn(figT));
% CONFIRM button: commits the current sensitivity-thresholded selection and unblocks the model build
uicontrol(figT,'Style','pushbutton','Units','normalized','Position',[0.79 0.004 0.19 0.032], ...
    'String','CONFIRM selection & build model','FontWeight','bold','BackgroundColor',[0.72 0.90 0.72], ...
    'Callback',@(varargin)uiresume(figT));

DBT = struct('axT',axT,'hAff',hAff,'hUn',hUn,'hSensTxt',hSensTxt,'sens',tf_sens, ...
    'amps',amps,'grR',grR,'grC',grC,'gdC',dspGc,'gdR',dspGr,'dspGc',dspGc,'dspGr',dspGr,'dspSc',dspSc,'dspSr',dspSr, ...
    'mAmpP',mAmpP,'muMap',muMap,'rel',rel,'recMsA',recMsA,'setMsA',setMsA,'preN',preN,'Wb',Wb, ...
    'winA',{winA},'np',tf_np,'nz',tf_nz,'nd',tf_nd,'nPreZ',nPreZ,'Ts',Ts,'reqReb',tf_reqReb,'rebMin',tf_rebMin, ...
    'sweep',tf_sweep,'maxP',tf_maxP,'maxZ',tf_maxZ,'smoothN',tf_smoothN, ...
    'affected_tf',affected_tf,'VAF',VAFtf,'DIP',DIPtf,'DIPgate',DIPgate,'capNa',capNa,'dipCapSec',tf_dipCapSec, ...
    'useShape',tf_useShape,'trBandA',trBandA,'recFracMax',tf_recFracMax,'TRcapMs',TRcapMs,'RECfrac',RECfrac, ...
    'capFallback',capFallback,'TRdatMs',TRdatMs,'RECdatMs',RECdatMs,'hasRec',hasRec, ...
    'recMaxFac',tf_recMaxFac,'recMsA2',recMs(:),'recTolFac',recTolFac,'preStd',preStd, ...
    'TR',TRtf,'REB',REBtf,'DEL',DELtf,'vafGate',vafGate, ...
    'preThr',preThr,'DIPraw',DIPrawtf,'useVAF',tf_useVAF,'vafMin',tf_vafMin, ...
    'selGz',selGz,'selcz',selcz,'sellamR',sellamR,'selMuY',selMuY,'selGamma',selGamma,'selL1frac',select_l1frac, ...
    'selEvZ',{selEvZ},'selAA',{selAA},'selDc',{selDc},'selRc',{selRc},'selSc',{selSc},'ttc',rel/Fs,'gB',gB, ...
    'Xpct',Xpct,'onFcell',{onFcell},'onF0',onF0,'Fs',Fs,'nFall',nFall,'ctxSec',2);   % ±ctxSec s wide click view
guidata(figT, DBT);
set(hSens,'Callback',@(s,~)tfmap_sens(figT,s));                       % fires on release
addlistener(hSens,'ContinuousValueChange',@(s,~)tfmap_sens(figT,s));  % + live update while dragging
set(figT,'WindowButtonDownFcn',@tfmap_button);
fprintf('[AFFECT-TF-SELECT] SELECTOR open: drag SENSITIVITY (higher = more px, lower = fewer), click a pixel to inspect,\n');
fprintf('                   press "Refit SELECT model" to preview the sparse far-from-ipsi model at this selection,\n');
fprintf('                   then "CONFIRM selection & build model". The script WAITS here until you confirm.\n');

% ---- GATE: block until the user CONFIRMS, then commit `affected` and let the model build downstream ----
if strcmpi(affect_mode,'tf')
    if tf_sensRestored
        % Selection already made (and saved) on an earlier run -> do not ask again, do not block.
        % The selector figure stays open as a read-only view; dragging it now has no effect on this run.
        fprintf('  [sens] REUSING the confirmed selection -> CONFIRM gate SKIPPED (selector is inspection-only).\n');
        fprintf('         To pick a new one: set tf_reuseSens=false, or delete\n         %s\n', tf_sensFile);
    else
        if isgraphics(figT), uiwait(figT); end                   % block until CONFIRM (or the window is closed)
        if isgraphics(figT)
            DBT = guidata(figT);  affected_tf = DBT.affected_tf;  tf_sens = DBT.sens;   % the CONFIRMED selection
        else
            warning('[AFFECT-TF] selector closed without CONFIRM -> using the last provisional selection (tf_sens=%.2f).', tf_sens);
        end
        % Persist the human decision so every later run rebuilds the SAME affected set. Saved with the fit-map
        % cache key, so it self-invalidates if the TF fit is recomputed with different params.
        key = tf_sensKey;  saved_on = char(datetime('now','Format','yyyy-MM-dd HH:mm'));
        save(tf_sensFile,'tf_sens','affected_tf','key','saved_on');
        fprintf('  [sens] SAVED confirmed tf_sens=%.2f -> %s\n', tf_sens, tf_sensFile);
    end
    affected = affected_tf;
    fprintf('  [CONFIRMED] tf_sens=%.2f -> affected := affected_tf (', tf_sens); fprintf('%d ',sum(affected_tf,1)); fprintf('cells) -> feeds §17b\n');
else
    fprintf('  affect_mode=matched -> §10 map unchanged (interactive selector is display-only)\n');
end

AFFECT_TF = struct('mode',affect_mode,'affected_tf',affected_tf,'VAF',VAFtf,'dip',DIPtf,'dipGate',DIPgate,'troughMs',TRtf, ...
    'reboundRatio',REBtf,'delayMs',DELtf,'dipRaw',DIPrawtf,'preThr',preThr,'preStd',preStd,'preRange',preRange, ...
    'vafGate',vafGate,'order',[tf_np tf_nz tf_nd],'winA',{winA},'winSec',tf_winSec,'dipCapSec',tf_dipCapSec, ...
    'refAmp',tf_refAmpIdx,'sens',tf_sens,'reqReb',tf_reqReb,'kSD',tf_kSD,'kRange',tf_kRange, ...
    'preSec',tf_preSec,'usePost',tf_usePost,'postStartSec',tf_postStartSec,'postSec',tf_postSec,'algo','biphasic_stmcb_v3');
fprintf('[AFFECT-TF] -> AFFECT_TF (affected_tf[nG x nA] + VAF / dip / rebound maps, confirmed @ tf_sens=%.2f)\n', tf_sens);


%% ==================================================================
% STAGE 1b -- RESPONSE LANDMARKS (feed the stim-blind)
% ==================================================================

%% (15) [SETTLETIME] Dip-window AUDIT + REBOUND landmarks (consumes §10's landmarks)
% The trough and the recovery/settle WINDOWS are computed ONCE in §10 (data-driven per-amp landmarks
% from the primary-pixel evoked: mAmpP / recMs / setMs / troughMs / inhCols / rebCols, plus the
% recTol/setTol bands). This cell is now a pure CONSUMER of those — it no longer recomputes them or
% re-declares the tolerance factors (that was a duplicate code path with the same 0.05/0.10 constants).
% It OWNS only what §10 does not: the post-recovery REBOUND peak, the REBOUND-SETTLE landmark (rebound
% has died down = honest end of the biphasic response), the audit of the dip_win_s knob, and the figure.
st_win = dip_win_s;                                    % window in use (s), for the audit + figure reference
tms    = rel/Fs*1000;                                  % peri-onset time axis (ms)
nA_s   = numel(amps);

mAmp = mAmpP;  Ltr = troughMs;  Dtr = troughDf;  Lrec = recMs;  Lset = setMs;   % <-- §10 landmarks (single source)
Lreb = nan(nA_s,1);  Dreb = nan(nA_s,1);  Lrbs = nan(nA_s,1);                    % rebound peak/height + rebound-settle (this cell)
fprintf('\n[SETTLETIME] primary-pixel impulse landmarks (§10 windows + rebound; per amp):\n');
fprintf('   amp(V)  nTrl | trough(ms)  depth | recover(ms) | reboundPk(ms)  height | rebSettle(ms) | settle(ms)\n');
for ai = 1:nA_s
    onF = onFcell{ai};  nT = numel(onF);
    if nT==0 || isempty(inhCols{ai}), continue; end
    m = mAmpP(:,ai);  rc = inhCols{ai}(end);  tolR = recTol(ai);  tolS = setTol(ai);   % from §10

    iRb = NaN;                                          % rebound = max positive lobe after recovery
    if rc < Wb
        [dRb, iRl] = max(m(rc:Wb));  iR = rc + iRl - 1;
        if dRb > tolR, Dreb(ai) = dRb;  Lreb(ai) = tms(iR);  iRb = iR; end
    end

    % REBOUND-settle (target #3): the honest "rebound has died down" landmark = AFTER the rebound
    % peak, the first sustained (>=2 consecutive frames) return into the settle band. Unlike the
    % full-settle (last excursion ANYWHERE), it is not corrupted by late trial-avg noise, so it is
    % stable across amps (~770 ms) and is the principled end of the biphasic stim response.
    if ~isnan(iRb) && iRb < Wb
        ms  = smoothdata(m,'movmean',3);                % light smoothing kills trial-avg jitter
        inb = abs(ms(iRb:Wb)) <= tolS;                  % within settle band after the rebound peak
        kk  = find(inb(1:end-1) & inb(2:end), 1, 'first');
        if ~isempty(kk), Lrbs(ai) = tms(iRb + kk - 1); end
    end

    fprintf('   %-6.2f %5d | %8.0f %7.3f | %9.0f | %11s %7s | %13s | %8.0f\n', ...
        amps(ai), nT, Ltr(ai), Dtr(ai), Lrec(ai), ...
        ternchar(isnan(Lreb(ai)),'   --',sprintf('%6.0f',Lreb(ai))), ...
        ternchar(isnan(Dreb(ai)),'  --',sprintf('%5.3f',Dreb(ai))), ...
        ternchar(isnan(Lrbs(ai)),'   --',sprintf('%6.0f',Lrbs(ai))), Lset(ai));
end

medRec = median(Lrec,'omitnan');
medRbs = median(Lrbs,'omitnan');
fprintf('   --> median recovery (end-of-inhibition) = %.0f ms   (current window = %.0f ms)\n', medRec, st_win*1000);
fprintf('   --> median REBOUND-settle (rebound died down = end of biphasic response) = %.0f ms  [n=%d amps]\n', ...
        medRbs, nnz(~isnan(Lrbs)));
if isfinite(medRec)
    if medRec < st_win*1000-15
        fprintf('       %.0f ms OVER-includes: it reaches into the post-inhibition REBOUND by ~%.0f ms.\n', st_win*1000, st_win*1000-medRec);
    elseif medRec > st_win*1000+15
        fprintf('       %.0f ms UNDER-includes: inhibition is still recovering (by ~%.0f ms).\n', st_win*1000, medRec-st_win*1000);
    else
        fprintf('       200 ms is well matched to the data-derived recovery time.\n');
    end
end

% ---- figure: overlaid impulses w/ landmarks (left) + landmark-vs-amp (right) ----
figS = figure('Color','w','Name','[SETTLETIME] impulse landmarks','Position',[80 80 1150 460]);
cmapS = parula(nA_s);
axL = subplot(1,2,1); hold(axL,'on');  box(axL,'on');
for ai = 1:nA_s
    if all(isnan(mAmp(:,ai))), continue; end
    plot(axL, tms, mAmp(:,ai), '-', 'Color',cmapS(ai,:), 'LineWidth',1.3, ...
        'DisplayName',sprintf('%.2f V',amps(ai)));
    if ~isnan(Ltr(ai)),  plot(axL, Ltr(ai),  Dtr(ai),  'v', 'Color',cmapS(ai,:), 'MarkerFaceColor',cmapS(ai,:), 'HandleVisibility','off'); end
    if ~isnan(Lreb(ai)), plot(axL, Lreb(ai), Dreb(ai), '^', 'Color',cmapS(ai,:), 'MarkerFaceColor',cmapS(ai,:), 'HandleVisibility','off'); end
end
yl = ylim(axL);
plot(axL, [0 0], yl, 'k:', 'HandleVisibility','off');
plot(axL, st_win*1000*[1 1], yl, 'r--', 'LineWidth',1.2, 'DisplayName',sprintf('%.0f ms (current)',st_win*1000));
if isfinite(medRec), plot(axL, medRec*[1 1], yl, 'g--', 'LineWidth',1.2, 'DisplayName','median recovery'); end
if isfinite(medRbs), plot(axL, medRbs*[1 1], yl, '--', 'Color',[0 .5 .8], 'LineWidth',1.2, 'DisplayName','median rebound-settle'); end
yline(axL, 0, 'Color',[.6 .6 .6], 'HandleVisibility','off');
xlabel(axL,'time from onset (ms)'); ylabel(axL,'evoked \DeltaF/F (amp - 0V, %)');
title(axL,'trial-avg impulse @ primary pixel  (\itv\rm=trough, \it\wedge\rm=rebound)','FontSize',10,'FontWeight','bold');
legend(axL,'Location','southeast','FontSize',7); xlim(axL,[tms(1) tms(end)]);

axR = subplot(1,2,2); hold(axR,'on');  box(axR,'on');
plot(axR, amps, Ltr,  '-o', 'Color',[0.85 0.2 0.2], 'MarkerFaceColor',[0.85 0.2 0.2], 'DisplayName','trough');
plot(axR, amps, Lrec, '-s', 'Color',[0.1 0.5 0.1], 'MarkerFaceColor',[0.1 0.5 0.1], 'DisplayName','recovery (end of inhib)');
plot(axR, amps, Lreb, '-^', 'Color',[0.2 0.3 0.9], 'MarkerFaceColor',[0.2 0.3 0.9], 'DisplayName','rebound peak');
plot(axR, amps, Lrbs, '-v', 'Color',[0 0.5 0.8], 'MarkerFaceColor',[0 0.5 0.8], 'DisplayName','rebound-settle');
plot(axR, amps, Lset, '-d', 'Color',[0.4 0.4 0.4], 'MarkerFaceColor',[0.4 0.4 0.4], 'DisplayName','full settle');
yline(axR, st_win*1000, 'r--', sprintf('%.0f ms',st_win*1000), 'LineWidth',1.2, 'LabelHorizontalAlignment','left', 'HandleVisibility','off');
xlabel(axR,'amplitude (V)'); ylabel(axR,'time from onset (ms)');
title(axR,'landmark timing vs amplitude','FontSize',10,'FontWeight','bold');
legend(axR,'Location','northwest','FontSize',7); grid(axR,'on');

SETTLE = struct('amps',amps,'tms',tms,'mAmp',mAmp,'tTrough',Ltr,'dTrough',Dtr, ...
                'tRecover',Lrec,'tRebound',Lreb,'dRebound',Dreb,'tReboundSettle',Lrbs,'tSettle',Lset, ...
                'medRecover',medRec,'medReboundSettle',medRbs,'win_ms',st_win*1000);

% [FARPIX section REMOVED 2026-07-06] It only characterized a far, positive-going population and split
% flagged px by SIGN -- but that far positive population is NOT a stim effect we want to consider, and
% the §10 affect detector now flags INHIBITION ONLY (signed dip-direction match), so nothing far/positive
% is ever classified as stim-affected. FARPIX fed nothing downstream (SELECT §17d uses the §10T `affected`),
% so removing it changes no result -- it just removes a confusing, unused diagnostic.


%% ==================================================================
%% STAGE 2 -- STIM-BLIND CONTRA MODEL (unaffected px predict ipsi; residual = dip)
%% ==================================================================

%% (17) [SPONT-OLS] shared spontaneous contra->ipsi training (feeds §17d SELECT)
% Trains the unconstrained spont contra->ipsi OLS ONCE (z-space, §6 train/test split) and defines the
% shared reporting windows. SELECT (§17d) deploys these operators per amp with its sparse, distance-
% weighted (far-from-ipsi) fit; §17c (state-dep) and §18 (all-session) reuse the SELECT weights. Two
% predictors were retired ahead of it: the greedy per-amp pixel-removal model (2026-07-14) and the
% KKT dip-blinded NATIVE model (2026-07-18) -- see §17a. SELECT is now the sole stim-blind model.
dipCols = (preN+1):min(Wb, preN+round(dip_win_s*Fs));       % reporting dip window (data-driven default)
ttc = rel/Fs;                                               % peri-onset time axis (s) for trace figures
y_sp = double(y_full(frames));  ytr = y_sp(itr);  yte = y_sp(ite);  muY = mean(ytr);  ytrc = ytr - muY;
Gz = Ztr.'*Ztr;  cz = Ztr.'*ytrc;  lamR = 1e-6*mean(diag(Gz));  sstot = max(sum((yte-mean(yte)).^2),eps);
lamSel = max(1e-6, select_ridge)*mean(diag(Gz));   % SELECT's own regulariser: kept separate from lamR so
                                                   % raising the distance prior does not perturb other fits

% (greedy predictor removed 2026-07-14; NATIVE KKT predictor removed 2026-07-18 — SELECT §17d is the sole model)

%% (17a) [SHARED-OPS] per-amp evoked + fit operators shared by SELECT (§17d), STATEDEP (§17c) and §18
% Everything below is model-AGNOSTIC prep: the per-amp trial-averaged evoked in z-space, the kept
% (stim-UNAFFECTED) pixel set per amp, the ridge-factorised spont operators, the shared parametric biphasic
% basis, and the HONEST pre/post-stim prediction-R^2 designs. §17d [STIMBLIND-SELECT] consumes these.
% [RETIRED 2026-07-18] The former §17b [STIMBLIND-NATIVE] predictor (keep ALL unaffected px, zero the dip by
% a KKT equality constraint on a K-window blind subspace) and its §17bV validation were REMOVED. NATIVE
% cancelled the dip by construction, which guarantees ~100% dip capture but makes the capture uninformative;
% SELECT instead earns its residual by choosing FEW, FAR-from-ipsi predictors, so its leak is an honest
% readout. SELECT is now the SOLE stim-blind model and feeds the paper's state-dependence analysis.
ncN = min(nA,3);  nrN = ceil(nA/ncN);
% shared parametric biphasic basis (fixed shapes from §15 landmarks: dip peak ~143 ms, rebound peak ~571 ms)
tms_on = (rel(:)-rel(preN+1))/Fs*1000;  posT = tms_on>=0;
gDip = zeros(Wb,1);  gReb = zeros(Wb,1);
gDip(posT) = (tms_on(posT).^2).*exp(-tms_on(posT)/71.5);  if any(gDip>0), gDip=gDip/max(gDip); end   % peak 143 ms
gReb(posT) = (tms_on(posT).^2).*exp(-tms_on(posT)/285);   if any(gReb>0), gReb=gReb/max(gReb); end    % peak 571 ms
% ---- cache per-amp evoked + fit operators ONCE (all independent of nblind) ----
evZc=cell(nA,1); aAc=cell(nA,1); dcc=cell(nA,1); rcc=cell(nA,1); scc=cell(nA,1); Sc=cell(nA,1); dGc=cell(nA,1); b0c=cell(nA,1);
% SPLIT-HALF evoked, for §17e's trial-split blindness control. Built here because Zp (the per-trial
% block) already exists in this loop -- computing it again later would mean a second SVD reconstruction.
% Halves are a SEEDED permutation (rng(7) at §1), so the split is identical run-to-run.
evZcA=cell(nA,1); aAcA=cell(nA,1); evZcB=cell(nA,1); aAcB=cell(nA,1);
for ai = 1:nA
    onF=onFcell{ai}; nT=numel(onF); if nT==0, continue; end
    dc=inhCols{ai}; if isempty(dc), dc=dipCols; end;  rc=rebCols{ai};
    idx=onF(:).'+rel(:);
    Zp=(double(Uflat(gridIdx,:))*double(V_cp(:,idx(:)))-mu_p)./sd_p; Zp=reshape(Zp,nG,Wb,nT);
    evZ=mean(Zp,3); evZ=evZ-mean(evZ(:,1:preN),2);
    yTr=reshape(double(y_full(idx(:))),Wb,nT);
    aA=mean(yTr,2); aA=aA-mean(aA(1:preN));
    if nT >= 4                                            % split-half evoked (A = select, B = validate)
        pp=randperm(nT); hA=pp(1:floor(nT/2)); hB=pp(floor(nT/2)+1:end);
        eA=mean(Zp(:,:,hA),3); evZcA{ai}=eA-mean(eA(:,1:preN),2);
        eB=mean(Zp(:,:,hB),3); evZcB{ai}=eB-mean(eB(:,1:preN),2);
        yA=mean(yTr(:,hA),2); aAcA{ai}=yA-mean(yA(1:preN));
        yB=mean(yTr(:,hB),2); aAcB{ai}=yB-mean(yB(1:preN));
    end
    if ~isempty(rc), se=rc(end); else, se=dc(end); end
    active=~affected(:,ai); if nnz(active)<5, active=true(nG,1); end;  S=find(active);
    evZc{ai}=evZ; aAc{ai}=aA; dcc{ai}=dc; rcc{ai}=rc; scc{ai}=(preN+1):max(se,dc(end));
    Sc{ai}=S; dGc{ai}=decomposition(Gz(S,S)+lamR*eye(numel(S))); b0c{ai}=dGc{ai}\cz(S);
end
% ---- per-amp pre/post-stim FRAME designs for the HONEST prediction-R^2 metric (2026-07-13) -------
% The old "non-stim R^2" is computed on the trial-AVERAGED evoked, which OUTSIDE the stim window is ~0
% signal + averaging noise -> its R^2 measures noise-vs-noise and is MEANINGLESS (it read 0.16-0.56 even
% when the predictor was excellent). The RIGHT metric applies the blinded weights to the RAW per-trial
% pre-onset and post-settle frames (real ongoing activity) and asks how well the prediction tracks the
% ipsi site there. On AL_0033 this reads ~0.95 (vs the lying 0.32). Precomputed ONCE (indep. of nblind).
r2f = @(y,yh) 1 - sum((y(:)-yh(:)).^2)/max(sum((y(:)-mean(y(:))).^2),eps);
Zpre=cell(nA,1); ypre=cell(nA,1); Zpost=cell(nA,1); ypost=cell(nA,1);
for ai = 1:nA
    onF=onFcell{ai}; if isempty(onF)||isempty(evZc{ai}), continue; end
    frPre =onF(:).'+rel(1:preN).';              frPre =frPre(:).';
    frPost=onF(:).'+rel(scc{ai}(end)+1:Wb).';   frPost=frPost(:).';
    frPre =frPre( frPre>=1  & frPre<=size(V_cp,2));
    frPost=frPost(frPost>=1 & frPost<=size(V_cp,2));
    Zpre{ai} =((double(Uflat(gridIdx,:))*double(V_cp(:,frPre)))-mu_p)./sd_p;   ypre{ai} =y_full(frPre);
    Zpost{ai}=((double(Uflat(gridIdx,:))*double(V_cp(:,frPost)))-mu_p)./sd_p;  ypost{ai}=y_full(frPost);
end

%% (17c0) [RIDGE-SWEEP] sweep the far-from-ipsi prior, then PICK the operating point
% Runs BEFORE §17e/§17d so the chosen `select_ridge` actually reaches the fit. (The first version of this
% sat after §17d and was therefore diagnostic-only: it printed a table while §17d had already run at
% select_ridge=0 -- i.e. dense OLS with NO distance prior, which is the configuration that lost the
% residual capture. Figures moved to §17f; only the compute + pick live here.)
%
% WHY A PRIOR AND NOT A CONSTRAINT. "Predictors should be far from the stim site" is a claim about where
% bleed and direct effects live, formed WITHOUT reference to the dip -- so it does NOT guarantee blindness
% and leak stays an honest measurement. That is the difference from §17b NATIVE's KKT equality (retired)
% and from an evoked-subspace projection: those make capture true by construction.
% Reference: [CP-CLEANRES] (S13, RRR lineage) held the residual at ~73% of the actual dip.
ridge_grid   = [0 1e-4 3e-4 1e-3 3e-3 1e-2 3e-2 0.1 0.3 1 3];   % fractions of mean(diag(Gz))
ridge_pick   = 'auto';   % 'auto' = minimise leak subject to R^2 >= ridge_r2min | 'off' = keep select_ridge as set
ridge_r2min  = 0.92;     % ABSOLUTE held-out SPONTANEOUS R^2 floor the pick must respect (user 2026-08-05)
% BATCH-DRIVER HOOK. These are declared after §1's OLS_OVERRIDE block, so apply the override here.
% CRITICAL for cross-session work: leaving ridge_pick='auto' makes EVERY session tune its own prior,
% which is per-dataset parameter selection and is NOT one strategy applied to all sessions. A driver
% pooling state-dependence across sessions must pass ridge_pick='off' + a FROZEN select_ridge.
for f_ = {'ridge_grid','ridge_pick','ridge_r2min','select_ridge'}
    if exist('OLS_OVERRIDE','var') && isstruct(OLS_OVERRIDE) && isfield(OLS_OVERRIDE,f_{1})
        eval([f_{1} ' = OLS_OVERRIDE.(f_{1});']);   %#ok<EVLDIR>
    end
end
nRG   = numel(ridge_grid);
sw_r2 = nan(nRG,nA);  sw_leak = nan(nRG,nA);  sw_wdist = nan(nRG,nA);  sw_wmax = nan(nRG,nA);
haveDist = exist('selDist','var') && numel(selDist)==nG;        % weight-centroid diagnostic (display px)
mdG = mean(diag(Gz));
fprintf('\n[RIDGE-SWEEP] far-from-ipsi weighted-L2 prior: held-out spont R^2 vs leak (dense, no sparsity)\n');
fprintf('   %-12s %10s %10s %10s   %s\n','select_ridge','spontR2','leak%','capture%','mean |w| dist from ipsi (px)');
for ri = 1:nRG
    lamS = max(1e-6, ridge_grid(ri))*mdG;
    for ai = 1:nA
        if isempty(evZc{ai}), continue; end
        S = Sc{ai};  g = selGamma(S);
        b = zeros(nG,1);
        b(S) = (Gz(S,S) + lamS*diag(1./max(g,eps).^2)) \ cz(S);
        yg = (b.'*evZc{ai}).';  yg = yg - mean(yg(1:preN));
        Adip = mean(aAc{ai}(dcc{ai}));  Gdip = mean(yg(dcc{ai}));
        sw_leak(ri,ai) = 100*Gdip/Adip;                          % Global as % of Actual = LEAK
        sw_r2(ri,ai)   = 1 - sum((yte - (muY + Zte*b)).^2)/sstot;% held-out SPONTANEOUS R^2 (the only R^2 here)
        aw = abs(b);  sw_wmax(ri,ai) = max(aw);
        if haveDist && sum(aw) > 0, sw_wdist(ri,ai) = sum(aw.*selDist(:))/sum(aw); end
    end
    fprintf('   %-12.4g %10.4f %10.1f %10.1f   %s\n', ridge_grid(ri), median(sw_r2(ri,:),'omitnan'), ...
        median(sw_leak(ri,:),'omitnan'), 100-median(sw_leak(ri,:),'omitnan'), ...
        ternstr(haveDist, sprintf('%.1f', median(sw_wdist(ri,:),'omitnan')), 'n/a'));
end
r2med = median(sw_r2,2,'omitnan');  lkmed = median(sw_leak,2,'omitnan');

% ---- PICK: strongest prior (lowest leak) whose held-out spontaneous R^2 still clears the floor -------
if strcmpi(ridge_pick,'auto')
    ok = find(r2med >= ridge_r2min);
    if isempty(ok)
        [bestR2, iBest] = max(r2med);
        warning(['[RIDGE-SWEEP] NO grid point reaches spont R^2 >= %.3f (best %.4f at ridge %.4g). ' ...
                 'Picking the best-R^2 point and leaving the prior weak -- raise the grid resolution or ' ...
                 'lower ridge_r2min before reading anything into the leak.'], ridge_r2min, bestR2, ridge_grid(iBest));
    else
        [~,k] = min(lkmed(ok));  iBest = ok(k);
    end
    select_ridge = ridge_grid(iBest);
    lamSel = max(1e-6, select_ridge)*mdG;                        % <-- what §17e/§17d actually use
    sellamR = max(1e-6, select_ridge)*mean(diag(selGz));         % keep the §10T3 refit button consistent
    fprintf(2,'   [PICK] select_ridge = %.4g  ->  spont R^2 %.4f (floor %.2f), leak %.0f%%, capture %.0f%%\n', ...
            select_ridge, r2med(iBest), ridge_r2min, lkmed(iBest), 100-lkmed(iBest));
    fprintf('   This value now feeds §17e/§17d/§17c and everything downstream of them.\n');
else
    [~,iBest] = min(abs(ridge_grid - select_ridge));
    fprintf('   [PICK] ridge_pick=off -> keeping select_ridge = %.4g (spont R^2 %.4f, leak %.0f%%)\n', ...
            select_ridge, r2med(iBest), lkmed(iBest));
end
iCur = iBest;
if all(lkmed > 50)
    fprintf(2,['   ** NO ridge value gets leak below 50%%: the far-from-ipsi prior alone cannot separate the\n' ...
               '      stim-predictive direction from the spont-predictive one. That is an IDENTIFIABILITY\n' ...
               '      result (cf. [CP-KRECON]: coupling is distributed, not focal), not a tuning failure. **\n']);
end
RIDGESWEEP = struct('grid',ridge_grid,'r2',sw_r2,'leak',sw_leak,'wdist',sw_wdist,'wmax',sw_wmax, ...
                    'r2med',r2med,'leakmed',lkmed,'current',select_ridge,'iCur',iCur, ...
                    'r2min',ridge_r2min,'pick',ridge_pick,'mn',mn,'td',td,'en',en);

%% (17e) [GREEDY-BLIND] optional POOLED pixel-pruning layer feeding §17d
% Removes stim-carrying pixels from the predictor set WITHOUT constraining the weights (contrast §17b
% NATIVE's KKT equality, retired 2026-07-18 because it always succeeds and so says nothing). Starts from
% the INTERSECTION of the detector's unaffected sets across amplitudes -- pooled, so ONE predictor set
% serves every amp and per-amp leak stays comparable. Engine + both controls: utils/imp_greedy_blind.m.
% Set greedy_on=false to feed §17d the raw detector set (the 2026-08-05 dense-SELECT behaviour).
greedy_on      = true;
greedy_tolL    = 0.10;   % target mean |leak| (fraction of the actual dip predicted by the survivors)
greedy_r2floor = 0.90;   % FAIL if held-out spont R^2 drops below this fraction of the full-set R^2
greedy_batch   = 0.01;   % fraction of the live set dropped per step (RFE-style, keeps the search fast)
greedy_nRand   = 5;      % random-exclusion control repeats
for f_ = {'greedy_on','greedy_tolL','greedy_r2floor','greedy_batch','greedy_nRand'}   % batch-driver hook
    if exist('OLS_OVERRIDE','var') && isstruct(OLS_OVERRIDE) && isfield(OLS_OVERRIDE,f_{1})
        eval([f_{1} ' = OLS_OVERRIDE.(f_{1});']);   %#ok<EVLDIR>
    end
end
S_greedy = [];  GREEDY = [];
if greedy_on
    Upool = Sc{1};                                       % pooled candidates = unaffected at EVERY amp
    for ai = 2:nA, if ~isempty(Sc{ai}), Upool = intersect(Upool, Sc{ai}); end, end
    okA = find(~cellfun(@isempty, evZcA(:).'));          % amps with a usable trial split
    mkD = @(EV,AA) deal(cellfun(@(e,d) mean(e(:,d),2), EV(okA), dcc(okA), 'uni',0), ...
                        cellfun(@(a,d) mean(a(d)),     AA(okA), dcc(okA)));
    [evDipSel, actDipSel] = mkD(evZcA, aAcA);            % SELECT half
    [evDipVal, actDipVal] = mkD(evZcB, aAcB);            % VALIDATION half (never seen by the search)
    GP = struct('Gz',Gz,'cz',cz,'gamma',selGamma,'lam',lamSel,'Zte',Zte,'yte',yte,'muY',muY, ...
                'sstot',sstot,'evDipSel',{evDipSel},'actDipSel',actDipSel, ...
                'evDipVal',{evDipVal},'actDipVal',actDipVal,'U',Upool);
    GREEDY = imp_greedy_blind(GP, struct('tol',greedy_tolL,'r2_floor',greedy_r2floor, ...
                'batch_frac',greedy_batch,'nRand',greedy_nRand,'verbose',true));
    if strcmp(GREEDY.status,'CONVERGED')
        S_greedy = GREEDY.S;
    else
        % A failed search must NOT quietly hand §17d a mutilated predictor set: fall back to the full
        % detector set and say so, so the run is a dense-SELECT run rather than a half-pruned unknown.
        warning(['[GREEDY-BLIND] status=%s -> NOT applying the pruned set. §17d runs on the full detector ' ...
                 'set (dense SELECT). A failure here is a RESULT: at this R^2 floor the stim-predictive ' ...
                 'and spont-predictive directions are not separable.'], GREEDY.status);
    end
end

%% (17d) [STIMBLIND-SELECT] *** PRIMARY *** SPARSE, DISTANCE-WEIGHTED spont OLS on unaffected px (FAR from ipsi)
% THE stim-blind model (sole predictor since NATIVE was retired 2026-07-18). Spont-trained contra->ipsi
% prediction on the stim-UNAFFECTED pixel set (§10T detector), with TWO soft constraints on the fit:
% (a) SPARSITY (L1) and (b) a spatial prior that PENALISES weights near the ipsi stim site, so surviving
% predictors are FEW and FAR from ipsi (least stim-contaminated). No explicit dip-blinding: the residual
% carries the dip only insofar as those distal predictors are stim-blind, so the
% LEAK (Global dip as % of Actual) is an HONEST readout of selection+distance quality:
%     leak ~ 0  => distal unaffected px already produce ~zero stim dip (validates selection + far-weighting)
%     leak > 0  => some stim signal still leaks through the chosen predictors
% Since Local = Actual - Global exactly, dip-capture = 100 - leak. Fit = select_wlasso(Gz,cz,S,selGamma,...)
% -- the SAME solver the interactive "Refit SELECT model" button uses, at the CONFIRMED sensitivity.
% selGamma/select_l1frac come from the §10T3 SELECT-model prep. §17c (state-dep) and §18 consume these weights.
As_dip=nan(nA,1); Gs_dip=nan(nA,1); Ls_dip=nan(nA,1);              % DIP lobe (Actual/Global/Local)
As_reb=nan(nA,1); Gs_reb=nan(nA,1); Ls_reb=nan(nA,1);             % REBOUND lobe
r2s_pre=nan(nA,1); r2s_post=nan(nA,1); nUse_s=zeros(nA,1);        % HONEST per-frame pre/post pred R2 + #ACTIVE px
kDipS=nan(nA,1); kRebS=nan(nA,1);                                 % shared parametric biphasic gains per amp
trAs=cell(nA,1); trGs=cell(nA,1); trLs=cell(nA,1); trMs=cell(nA,1); useMaskS=false(nG,nA); bUseS=cell(nA,1);
fprintf('\n[STIMBLIND-SELECT] SPARSE distance-weighted (far-from-ipsi) spont OLS on unaffected px; dip carried by DISTAL selection:\n');
fprintf('   %-6s %4s | %5s | %14s | %8s %8s %8s | %8s %8s\n','amp','nTr','nAct','predR2 pre/post','dipAct','dipGlob','dipLoc','rebAct','rebLoc');
for ai = 1:nA
    if isempty(evZc{ai}), continue; end
    S=Sc{ai};
    if ~isempty(S_greedy), S = S_greedy; end     % §17e pruned POOLED set (same for every amp) when it converged
    aA=aAc{ai};  dc=dcc{ai};  rc=rcc{ai};  stimCols=scc{ai};
    bfull = select_wlasso(Gz, cz, S, selGamma, select_l1frac, lamSel); % far-from-ipsi weighted fit (DENSE by default)
    act = bfull~=0;  nUse_s(ai)=nnz(act);  useMaskS(:,ai)=act;  bUseS{ai}=bfull;
    yg=(bfull.'*evZc{ai}).';  yg=yg-mean(yg(1:preN));      % Global = sparse distal prediction of the ipsi evoked
    rL=aA-yg;                                              % Local  = residual (carries the dip if predictors are stim-blind)
    r2s_pre(ai)  = r2f(ypre{ai},  muY+(Zpre{ai}.'*bfull));
    r2s_post(ai) = r2f(ypost{ai}, muY+(Zpost{ai}.'*bfull));
    As_dip(ai)=mean(aA(dc)); Gs_dip(ai)=mean(yg(dc)); Ls_dip(ai)=mean(rL(dc));
    if ~isempty(rc), As_reb(ai)=mean(aA(rc)); Gs_reb(ai)=mean(yg(rc)); Ls_reb(ai)=mean(rL(rc)); end
    B=[gDip(stimCols) gReb(stimCols)];  kk=B\rL(stimCols);  kDipS(ai)=kk(1); kRebS(ai)=kk(2);  trMs{ai}=gDip*kk(1)+gReb*kk(2);
    trAs{ai}=aA(:); trGs{ai}=yg(:); trLs{ai}=rL(:);
    fprintf('   %-6.2f %4d | %5d | %6.3f / %6.3f | %8.3f %8.3f %8.3f | %8.3f %8.3f\n', ...
        amps(ai), nT_amp(ai), nUse_s(ai), r2s_pre(ai), r2s_post(ai), As_dip(ai), Gs_dip(ai), Ls_dip(ai), As_reb(ai), Ls_reb(ai));
end
capDipS = median(100*Ls_dip./As_dip,'omitnan');  leakDipS = median(100*Gs_dip./As_dip,'omitnan');  capRebS = median(100*Ls_reb./As_reb,'omitnan');
fprintf('   --> median DIP in residual %.0f%% (LEAK into prediction %.0f%%) | median REBOUND in residual %.0f%% | HONEST pred R^2 pre %.3f / post %.3f\n', ...
    capDipS, leakDipS, capRebS, median(r2s_pre,'omitnan'), median(r2s_post,'omitnan'));

% --- Fig 1: dip + rebound dose curves + per-amp capture (Global here is the LEAK, not ~0 by construction) --
figSB1 = figure('Color','w','Name','[STIMBLIND-SELECT] dip+rebound dose + per-amp capture','Position',[90 90 1320 420]);
axD=subplot(1,3,1,'Parent',figSB1); hold(axD,'on'); box(axD,'on');
plot(axD,amps,As_dip,'-o','Color','k','LineWidth',1.8,'MarkerFaceColor','k','DisplayName','Actual');
plot(axD,amps,Gs_dip,'-s','Color',[.85 .2 .2],'LineWidth',1.4,'MarkerFaceColor',[.85 .2 .2],'DisplayName','Global (LEAK)');
plot(axD,amps,Ls_dip,'-^','Color',[.1 .4 .85],'LineWidth',1.4,'MarkerFaceColor',[.1 .4 .85],'DisplayName','Local (residual)');
yline(axD,0,'k:'); xlabel(axD,'amplitude (V)'); ylabel(axD,'dip \DeltaF/F %'); legend(axD,'Location','southwest','FontSize',7);
title(axD,sprintf('DIP lobe  (median %.0f%% in residual, %.0f%% leak)',capDipS,leakDipS),'FontSize',9,'FontWeight','bold');
axR=subplot(1,3,2,'Parent',figSB1); hold(axR,'on'); box(axR,'on');
plot(axR,amps,As_reb,'-o','Color','k','LineWidth',1.8,'MarkerFaceColor','k','DisplayName','Actual');
plot(axR,amps,Gs_reb,'-s','Color',[.85 .2 .2],'LineWidth',1.4,'MarkerFaceColor',[.85 .2 .2],'DisplayName','Global (leak)');
plot(axR,amps,Ls_reb,'-^','Color',[.1 .4 .85],'LineWidth',1.4,'MarkerFaceColor',[.1 .4 .85],'DisplayName','Local (residual)');
yline(axR,0,'k:'); xlabel(axR,'amplitude (V)'); ylabel(axR,'rebound \DeltaF/F %'); legend(axR,'Location','northwest','FontSize',7);
title(axR,sprintf('REBOUND lobe  (median %.0f%% in residual)',capRebS),'FontSize',9,'FontWeight','bold');
axC=subplot(1,3,3,'Parent',figSB1); hold(axC,'on'); box(axC,'on');
plot(axC,amps,100*Ls_dip./As_dip,'-^','Color',[.1 .4 .85],'LineWidth',1.6,'MarkerFaceColor',[.1 .4 .85],'DisplayName','dip captured');
plot(axC,amps,100*Gs_dip./As_dip,'-s','Color',[.85 .2 .2],'LineWidth',1.6,'MarkerFaceColor',[.85 .2 .2],'DisplayName','leak into prediction');
yline(axC,100,'k:'); yline(axC,0,'k:'); xlabel(axC,'amplitude (V)'); ylabel(axC,'% of actual dip'); ylim(axC,[-30 130]); legend(axC,'Location','east','FontSize',7);
title(axC,'per-amp capture vs leak (sparse-distal selection)','FontSize',9,'FontWeight','bold');
sgtitle(figSB1,'STIMBLIND-SELECT: sparse, weighted FAR from ipsi -> Global carries the LEAK; residual captures the dip as far as the distal predictors are stim-blind','FontWeight','bold');

% --- Fig 2: per-amp Actual / Global / Local + shared biphasic model overlay ------------------------------
figSB2 = figure('Color','w','Name','[STIMBLIND-SELECT] per-amp Actual/Global/Local + biphasic model','Position',[70 50 1300 780]);
for ai=1:nA
    ax=subplot(nrN,ncN,ai); hold(ax,'on'); box(ax,'on');
    if isempty(trAs{ai}), title(ax,sprintf('%.2f V: n/a',amps(ai))); continue; end
    plot(ax, ttc, trAs{ai}, 'k-','LineWidth',1.6,'DisplayName','Actual');
    plot(ax, ttc, trGs{ai}, '-','Color',[.85 .2 .2],'LineWidth',1.3,'DisplayName','Global (sparse distal pred)');
    plot(ax, ttc, trLs{ai}, '-','Color',[.1 .4 .85],'LineWidth',1.3,'DisplayName','Local (residual)');
    plot(ax, ttc, trMs{ai}, '--','Color',[0 .6 .2],'LineWidth',1.2,'DisplayName','biphasic model');
    xline(ax,0,'k:'); yline(ax,0,'k:'); xlim(ax,[-.5 1]);
    title(ax,sprintf('%.2f V (%d act | dip %.0f%%, leak %.0f%%)',amps(ai),nUse_s(ai), ...
        100*Ls_dip(ai)/As_dip(ai), 100*Gs_dip(ai)/As_dip(ai)),'FontSize',8,'FontWeight','bold');
    if ai==1, legend(ax,'Location','southeast','FontSize',5); ylabel(ax,'\DeltaF/F %'); end
    if ai>nA-ncN, xlabel(ax,'t re onset (s)'); end
end
sgtitle('STIMBLIND-SELECT: sparse + FAR-from-ipsi -> if the red (Global) dips, stim signal LEAKED through the distal predictors; blue (residual) is the recovered dip','FontWeight','bold');

STIMBLIND_SELECT = struct('amps',amps,'ActualDip',As_dip,'GlobalDip',Gs_dip,'LocalDip',Ls_dip, ...
                   'ActualReb',As_reb,'GlobalReb',Gs_reb,'LocalReb',Ls_reb, ...
                   'trA',{trAs},'trG',{trGs},'trL',{trLs},'trModel',{trMs},'bUseS',{bUseS},'useMaskS',useMaskS, ...
                   'r2pre',r2s_pre,'r2post',r2s_post,'nUse',nUse_s,'kDip',kDipS,'kReb',kRebS, ...
                   'dipCols',dipCols,'rel',rel,'Fs',Fs,'preN',preN, ...
                   'l1frac',select_l1frac,'penNear',select_penNear,'penFar',select_penFar,'selGamma',selGamma, ...
                   'medDipCapPct',capDipS,'medDipLeakPct',leakDipS,'medRebCapPct',capRebS,'mn',mn,'td',td,'en',en);


%% (17f) [RIDGE-SWEEP-FIG] figures for the sweep computed in §17c0 (compute lives there so the PICK can
% reach §17d; this section only draws). Kept separate so re-plotting never re-fits.
if exist('RIDGESWEEP','var') && isstruct(RIDGESWEEP)
    ridge_grid = RIDGESWEEP.grid;  nRG = numel(ridge_grid);
    sw_wdist = RIDGESWEEP.wdist;   haveDist = any(isfinite(sw_wdist(:)));
    r2med = RIDGESWEEP.r2med;  lkmed = RIDGESWEEP.leakmed;  iCur = RIDGESWEEP.iCur;
    ridge_sweep_figure(RIDGESWEEP, mn, td, en);
end


%% ==================================================================
%% STAGE 3 -- STATE-DEPENDENCE OF THE RESIDUAL
%% ==================================================================

%% (17c) [STATEDEP] Trial-by-trial state-dependence of the LOCAL (stim-blind residual) dip
% The per-amp TRIAL-AVERAGED Local dip (§17d SELECT) is the MEAN stim effect. Question (journal 2026-06-16):
% does the SINGLE-TRIAL Local dip vary with brain state at stim onset -- i.e. is the local stim
% response itself state-dependent, beyond baseline prediction noise? For each trial we build the
% SELECT stim-blind (§17d) prediction from THAT trial's own contra pixels (bUseS*Z_trial), subtract
% from the trial's actual ipsi -> single-trial Local residual; its 0-200 ms dip is the per-trial
% stim effect (DV). We z-score the DV WITHIN amplitude (removes the dose-response mean = the
% trial-averaged Local dip) so only the trial-to-trial spread AROUND that mean is tested.
%     DECISIVE TEST:  partialcorr( localDip_zWithinAmp , state | dev_pre[, dev_post] )     [Spearman]
% dev_pre = pre-onset (-0.2..0 s) residual energy = per-trial prediction quality with NO stim, partialled
% out so a state effect means the STIM response is state-dependent, not just a noisier baseline fit. We ALSO
% report the partial controlling for BOTH dev_pre AND dev_post (settled tail +0.8..+1.0 s, another stim-free
% prediction-quality probe) to guard against within-trial non-stationarity of the fit across the onset, and a
% state<->dev_pre/post COLLINEARITY table so a null partial reads as "no effect" vs "no power left after
% partialling". A real effect survives raw + partial(pre) + partial(pre+post) + the trustworthy-half re-run.
% State defs are IDENTICAL to CP-RES / cp_residual_core (2026-06-26 windows): MOTION = total |z| of
% the session motion trace over [-2,+0.5]s; PRE-VAR = var(y) over [-1,+0.5]s; PRE-DELTA = 1-4 Hz
% power over the same window. CRITICAL (RESEARCH 2026-07-01/02, CP-PREDQ): raw var and ABSOLUTE
% delta are SIGNAL-POWER CONFOUNDS (both ~ signal power, entangled with the DV magnitude); the
% admissible POWER-INDEPENDENT states are MOTION and RELATIVE delta (delta/total). All four are
% reported; the two confounded ones are flagged, not interpreted as genuine state-dependence.
% The per-trial DV + state computation itself lives in utils/imp_statedep_trials.m -- the SAME
% function the headless per-session engine (§18) calls, so the interactive result here and the
% cross-session batch cannot drift apart on a window constant. Window definitions are documented
% there; they are the 2026-06-26 cp_residual_core windows.
%
% session motion trace (same source as cp_residual_core: 2x-sampled -> decimate to blue rate)
% PREFER the trace the loader already put on the experiment entry (`mv_z`, z-scored at blue
% cadence). Sessions loaded outside the controller rig -- e.g. the AL_0048 bilateral impulse,
% registered by load_bilateral_impulse.m -- have no input_params.csv, so `loadData` throws and
% motion would silently be NaN even though the face video was processed. Fall back to loadData
% for the original sessions, which do not carry mv_z on the entry.
motz_full = [];
if isfield(allExperiments, 'mv_z') && ~isempty(allExperiments(selExp).mv_z) && ...
        any(isfinite(allExperiments(selExp).mv_z))
    motz_full = double(allExperiments(selExp).mv_z(:));
    fprintf('[STATEDEP] motion from allExperiments(%d).mv_z (%d samples)\n', selExp, numel(motz_full));
else
    try
        dM = loadData(serverRoot, mn, td, en);
        if isfield(dM,'motion') && isfield(dM.motion,'motion_1')
            mot_full = double(dM.motion.motion_1(1:2:end));
            motz_full = (mot_full - mean(mot_full,'omitnan'))/max(std(mot_full,'omitnan'),eps);
        end
        clear dM
    catch ME
        fprintf('[STATEDEP] motion trace unavailable (%s) -> Motion column will be NaN.\n', ME.message);
    end
end

% ---- per-trial DVs + state markers (shared engine; see utils/imp_statedep_trials.m) -------------
% THREE candidate DVs on the same dip window, each z-scored WITHIN amp so the dose-response mean
% (the trial-averaged Local dip) is removed and only the trial-to-trial spread is tested:
%   (1) DIPmean  SIGNED mean residual over dc, minus the amp mean. <0 = deeper than the template.
%   (2) GAIN     template gain <r,mu>/<mu,mu>. Shape-aware (whole window profile), SIGNED.
%   (3) L1DEV    mean |r - mu|: UNSIGNED deviation = per-trial UNPREDICTABILITY. Cannot cancel a
%                deep-then-shallow mixture the way a signed mean can.
% DV-primacy is decided from the data (2026-07-18): the 2026-07-01 A2 result was that at the true
% laser focus the SIGNED effect collapses while L1 survives -> the defensible claim may be
% PREDICTABILITY, not response size.
ST_ = imp_statedep_trials(struct('Uflat',Uflat,'gridIdx',gridIdx,'V',V_cp,'mu_p',mu_p,'sd_p',sd_p, ...
        'y_full',y_full,'nF',nF_m,'onFcell',{onFcell},'bUse',{bUseS},'dipCols',{inhCols}, ...
        'rel',rel,'preN',preN,'Wb',Wb,'Fs',Fs,'amps',amps,'motz',motz_full,'wantTraces',true));
DVz=ST_.DVz; GNz=ST_.GAINz; L1z=ST_.L1DEVz; LD=ST_.LD; PRE=ST_.PRE; POST=ST_.POST;
MOT=ST_.MOT; PVv=ST_.PVv; DPa=ST_.DPa; DPr=ST_.DPr;
AMPv=ST_.AMPv; AMPi=ST_.AMPi; TRi=ST_.TRi; ldMean=ST_.ldMean; ldStd=ST_.ldStd;
trAll=ST_.trA; ygAll=ST_.trG; rlAll=ST_.trL;   % per-trial traces for TRIALPRED + clickable scatter

% --- Fig (TRIALPRED): 5 example trials/amp — row1 ipsi actual+pred(+amp-avg), row2 residual(+avg) ---
% Requested "before state-dep": shows the per-trial decomposition the state test operates on. Top row
% = actual ipsi (thin grey) & stim-blind prediction (thin red) for 5 trials, with the amp-average
% actual (thick black) and predicted (thick red) overlaid. Bottom row = each trial's residual (thin
% blue) and the amp-average residual (thick blue). Prediction is the SELECT §17d stim-blind model.
nEx = 5;  ttTP = rel(:)/Fs;
figTP = figure('Color','w','Name','[TRIALPRED] per-trial ipsi prediction + residual (5 trials/amp)','Position',[25 60 1560 520]);
for ai = 1:nA
    if isempty(trAll{ai}), continue; end
    A=trAll{ai}; YG=ygAll{ai}; RL=rlAll{ai}; nT=size(A,2);
    exj = unique(round(linspace(1,nT,min(nEx,nT))));            % 5 evenly-spaced example trials (deterministic)
    ax1=subplot(2,nA,ai); hold(ax1,'on'); box(ax1,'on');
    for j=exj, plot(ax1,ttTP,A(:,j), '-','Color',[.62 .62 .62],'LineWidth',0.4); end
    for j=exj, plot(ax1,ttTP,YG(:,j),'-','Color',[.95 .62 .62],'LineWidth',0.4); end
    plot(ax1,ttTP,mean(A,2), 'k-','LineWidth',1.8);
    plot(ax1,ttTP,mean(YG,2),'-','Color',[.85 .2 .2],'LineWidth',1.5);
    xline(ax1,0,'k:'); yline(ax1,0,'k:'); xlim(ax1,[-.5 1]);
    title(ax1,sprintf('%.2f V (n=%d)',amps(ai),nT),'FontSize',8,'FontWeight','bold');
    if ai==1, ylabel(ax1,'ipsi \DeltaF/F %'); legend(ax1,{'actual (trial)','pred (trial)','amp-avg actual','amp-avg pred'},'FontSize',5,'Location','south'); end
    ax2=subplot(2,nA,nA+ai); hold(ax2,'on'); box(ax2,'on');
    for j=exj, plot(ax2,ttTP,RL(:,j),'-','Color',[.55 .7 .98],'LineWidth',0.4); end
    plot(ax2,ttTP,mean(RL,2),'-','Color',[.1 .4 .85],'LineWidth',1.8);
    xline(ax2,0,'k:'); yline(ax2,0,'k:'); xlim(ax2,[-.5 1]);
    if ai==1, ylabel(ax2,'residual \DeltaF/F %'); legend(ax2,{'residual (trial)','amp-avg residual'},'FontSize',5,'Location','south'); end
    xlabel(ax2,'t re onset (s)');
end
sgtitle(figTP, sprintf('TRIALPRED  %s %s e%d  —  top: actual (blk) vs stim-blind pred (red), thin=%d trials / thick=amp-avg;  bottom: per-trial residual (thin) + amp-avg (thick)', ...
    mn,td,en,nEx),'FontWeight','bold','FontSize',9);
zf = @(x)(x-mean(x,'omitnan'))./max(std(x,'omitnan'),eps);
% [TRUST CONTROL] pre-stim prediction error = how much we can trust each trial's deviation. A trial whose
% stim-blind prediction already fails BEFORE onset (large pre-onset residual energy) has an untrustworthy
% dip deviation -- it may be baseline mis-fit, not a state effect. We (i) quantify how strongly deviation
% MAGNITUDE tracks pre-error, and (ii) re-run every state partial on the TRUSTWORTHY half (pre-error below
% the session median). A state effect that survives on well-predicted trials is genuine, not a fit artifact.
preZ     = zf(PRE);                                        % z-scored pre-stim prediction error (trust axis; low=trustworthy)
trust_ok = PRE <= median(PRE,'omitnan');                  % trustworthy half: well-predicted baseline
trust_r  = corr(abs(DVz), PRE, 'type','Spearman','rows','complete');   % does |deviation| track pre-error?
cLimTrust = [prctile(preZ,5) prctile(preZ,95)];  if diff(cLimTrust)<=0, cLimTrust=[-1 1]; end
% state covariates z-scored across the session (matches motThresh convention)
STc = {'Motion',            zf(MOT), true , 'power-indep';
       'Pre-var',           zf(PVv), false, 'POWER-CONFOUND';
       'Pre-\delta (abs)',  zf(DPa), false, 'POWER-CONFOUND';
       'Rel-\delta',        zf(DPr), true , 'power-indep'};
% ---- CONTROL COLLINEARITY: how much prediction-quality overlaps each state (= how much the partial removes) ----
% dev_pre / dev_post are the residual ENERGY in a stim-free window BEFORE onset and in the SETTLED tail. They
% measure the predictor's per-trial quality with NO stim -> partialling them isolates state-dependence of the
% STIM response from state-dependence of the baseline fit. But if a state (e.g. variance) is strongly collinear
% with prediction quality, partialling removes shared variance and the test LOSES POWER -- report it so a null
% partial can be read as "no effect" vs "no power left".
colPre=nan(4,1); colPost=nan(4,1);
fprintf('\n[STATEDEP CONTROL] state <-> prediction-quality collinearity (Spearman; large |rho| => partial loses power):\n');
fprintf('   %-16s %10s %10s   %-14s\n','state','rho(pre)','rho(post)','class');
for s=1:4
    st=STc{s,2};  m=isfinite(st)&isfinite(PRE)&isfinite(POST);
    if nnz(m)>10, colPre(s)=corr(st(m),PRE(m),'type','Spearman'); colPost(s)=corr(st(m),POST(m),'type','Spearman'); end
    fprintf('   %-16s %+10.3f %+10.3f   %-14s\n', regexprep(STc{s,1},'\\',''), colPre(s), colPost(s), STc{s,4});
end
% ---- DV COMPARISON: run the SAME partial on all three candidate DVs so primacy is decided from data ----
DVset = {'DIPmean (signed)', DVz, 'signed mean residual over dc, minus amp mean';
         'GAIN (template)',  GNz, 'shape-aware <r,mu>/<mu,mu> vs the amp template';
         'L1DEV (unsigned)', L1z, 'mean |r-mu| = per-trial UNPREDICTABILITY'};
fprintf('\n[STATEDEP] single-trial Local-dip DV vs brain state  (z-within-amp; partials control prediction quality; Spearman):\n');
fprintf('   [trust] Spearman(|DV_dipmean|, pre-stim error) = %+.3f  (>0 => noisier baseline fits inflate the deviation)\n', trust_r);
% partial columns: p|pre = control dev_pre only; p|pre+post = control BOTH stim-free windows jointly (2-covariate
% partial) -> guards against within-trial non-stationarity of prediction quality across the onset.
rhoP=nan(4,3); pvP=nan(4,3); rhoPP=nan(4,3); pvPP=nan(4,3); rhoR=nan(4,3); rhoT=nan(4,3); pvT=nan(4,3);
for d = 1:size(DVset,1)
    DVd = DVset{d,2};
    fprintf('   -- DV %-18s (%s)\n', DVset{d,1}, DVset{d,3});
    fprintf('   %-16s %9s %11s %8s | %10s   %-14s\n','state','p|pre','p|pre+post','raw','trust','class');
    for s=1:4
        st = STc{s,2};  m = isfinite(DVd)&isfinite(st)&isfinite(PRE)&isfinite(POST);
        if nnz(m) > 10
            [rhoP(s,d),pvP(s,d)]   = partialcorr(DVd(m), st(m), PRE(m), 'type','Spearman');
            [rhoPP(s,d),pvPP(s,d)] = partialcorr(DVd(m), st(m), [PRE(m) POST(m)], 'type','Spearman');  % control BOTH windows
            rhoR(s,d)              = corr(DVd(m), st(m), 'type','Spearman','rows','complete');
        end
        mt = m & trust_ok;                                % trustworthy half only (well-predicted baseline)
        if nnz(mt) > 10, [rhoT(s,d),pvT(s,d)] = partialcorr(DVd(mt), st(mt), PRE(mt), 'type','Spearman'); end
        mk  = '';  if pvP(s,d) <0.05, mk =' *'; end
        mkP = '';  if pvPP(s,d)<0.05, mkP='*'; end
        mkT = ' '; if pvT(s,d) <0.05, mkT='*'; end
        fprintf('   %-16s %+9.3f %+10.3f%s %+8.3f | %+9.3f%s  %-14s%s\n', regexprep(STc{s,1},'\\',''), ...
                rhoP(s,d), rhoPP(s,d), mkP, rhoR(s,d), rhoT(s,d), mkT, STc{s,4}, mk);
    end
end
fprintf('   NOTE: window = 0-%.0f ms Local residual, z-within amp. For the SIGNED DVs (DIPmean, GAIN) rho<0 => the\n', 1000*dip_win_s);
fprintf('         trial response is DEEPER/larger than the amp template in that state; rho>0 => shallower. For L1DEV\n');
fprintf('         (unsigned) rho>0 => the response is LESS PREDICTABLE in that state (magnitude, no direction).\n');
fprintf('         p|pre = partial on pre-onset pred-error; p|pre+post = partial on BOTH stim-free windows; "trust" =\n');
fprintf('         p|pre on the well-predicted half. A REAL effect survives all three. Interpret Motion + Rel-\\delta only.\n');
fprintf('   [DV-PRIMACY] compare the admissible rows (Motion, Rel-delta) across the three DVs: if the SIGNED DVs\n');
fprintf('         collapse while L1DEV survives, the defensible claim is PREDICTABILITY, not response size (cf. A2 2026-07-01).\n');

% --- Fig A: trial-averaged Local dip (the §17b NATIVE mean) with single-trial spread -----------
figST1 = figure('Color','w','Name','[STATEDEP] trial-avg Local dip + single-trial spread','Position',[70 90 560 460]);
axS=axes(figST1); hold(axS,'on'); box(axS,'on');
errorbar(axS, amps, ldMean, ldStd, '-o','Color','k','LineWidth',1.6,'MarkerFaceColor','k','CapSize',4,'DisplayName','trial-avg Local dip \pm SD');
plot(axS, amps, STIMBLIND_SELECT.LocalDip, 's','Color',[.1 .4 .85],'MarkerFaceColor',[.1 .4 .85],'DisplayName','§17d SELECT Local (check)');
yline(axS,0,'k:'); xlabel(axS,'amplitude (V)'); ylabel(axS,sprintf('0-%.0f ms Local dip (\\DeltaF/F %%)',1000*dip_win_s));
title(axS,'per-amp trial-averaged Local dip (bars = single-trial SD = what STATEDEP explains)','FontSize',9,'FontWeight','bold');
legend(axS,'Location','southwest','FontSize',7);

% --- Fig B: single-trial Local dip (z-within-amp) vs each state -------------------------------
figST2 = figure('Color','w','Name','[STATEDEP] Local dip vs brain state','Position',[40 40 1320 360]);
axP = gobjects(1,4);
for s=1:4
    ax=subplot(1,4,s); hold(ax,'on'); box(ax,'on');  axP(s)=ax;
    st=STc{s,2}; m=isfinite(DVz)&isfinite(st)&isfinite(PRE);
    scatter(ax, st(m), DVz(m), 12, preZ(m),'filled','MarkerFaceAlpha',0.6);   % color = pre-stim error (trust)
    colormap(ax,parula); clim(ax,cLimTrust);
    if s==4, cb=colorbar(ax); cb.Label.String='pre-stim error (z): low = trustworthy'; end
    if nnz(m)>2
        pco=polyfit(st(m),DVz(m),1); xx=linspace(min(st(m)),max(st(m)),2);
        plot(ax, xx, polyval(pco,xx), 'r-','LineWidth',1.4);
    end
    admis = STc{s,3};
    tcol = [0 0 0];  if ~admis, tcol = [.6 .3 0]; end
    ttl = sprintf('%s  \\rho_{part}=%+.2f (trust %+.2f)', STc{s,1}, rhoP(s,1), rhoT(s,1));   % col 1 = DIPmean (the plotted DV)
    title(ax, ttl, 'FontSize',9,'FontWeight','bold','Color', tcol);
    if ~admis, xlabel(ax, {STc{s,4}; '(not interpreted)'},'FontSize',7,'Color',[.6 .3 0]);
    else,      xlabel(ax, sprintf('%s (z)',regexprep(STc{s,1},'\\',''))); end
    if s==1, ylabel(ax,'Local dip dev (signed, z)'); end
    yline(ax,0,'k:');
end
sgtitle(sprintf('STATEDEP  %s %s e%d  —  single-trial SIGNED Local dip dev vs brain state  (color=pre-stim error/trust; dev_{pre} partialled; interpret Motion + Rel-\\delta only)  —  CLICK a point \\rightarrow that trial''s traces', ...
    mn,td,en),'FontWeight','bold','FontSize',9);
% clickable: click any scatter point -> that trial's actual/predicted ipsi + residual (vs amp-average)
SDc = struct('axPanels',axP, ...
             'stateZ',{{STc{1,2},STc{2,2},STc{3,2},STc{4,2}}}, 'stateName',{{STc{1,1},STc{2,1},STc{3,1},STc{4,1}}}, ...
             'DVz',DVz, 'ampIdx',AMPi, 'trialIdx',TRi, ...
             'trAll',{trAll}, 'ygAll',{ygAll}, 'rlAll',{rlAll}, 'inhCols',{inhCols}, ...
             'tt',rel(:)/Fs, 'dipCols',dipCols, 'amps',amps, ...
             'motz',motz_full, 'onF',{onFcell}, 'rel',rel(:), 'preN',preN);   % motion panel in the click view
guidata(figST2, SDc);  set(figST2,'WindowButtonDownFcn',@statedep_click);
fprintf('[STATEDEP] scatter is clickable -> click a point to see that trial''s actual/pred/residual traces.\n');

% rho_* are [4 states x 3 DVs]; DV column order = dvLabel (DIPmean, GAIN, L1DEV). Column 1 is the DV plotted
% in Fig B. DV-primacy for the paper is chosen by comparing the admissible rows (Motion, Rel-delta) across columns.
STATEDEP = struct('DVz',DVz,'GAINz',GNz,'L1DEVz',L1z,'dvLabel',{{'DIPmean','GAIN','L1DEV'}}, ...
                  'dev_pre',PRE,'dev_post',POST,'amp',AMPv, ...
                  'ctrl_collin_pre',colPre,'ctrl_collin_post',colPost, ...
                  'Motion',MOT,'PreVar',PVv,'PreDeltaAbs',DPa,'RelDelta',DPr, ...
                  'stateLabel',{{'Motion','PreVar','PreDeltaAbs','RelDelta'}}, ...
                  'rho_partial',rhoP,'p_partial',pvP,'rho_partial_prepost',rhoPP,'p_partial_prepost',pvPP, ...
                  'rho_raw',rhoR,'admissible',[true false false true], ...
                  'rho_partial_trust',rhoT,'p_partial_trust',pvT,'trust_r',trust_r,'pre_error',PRE,'trust_ok',trust_ok, ...
                  'ldMean',ldMean,'ldStd',ldStd,'dipCols',dipCols,'dip_win_s',dip_win_s, ...
                  'motAvailable',~isempty(motz_full),'mn',mn,'td',td,'en',en);

%% (17c2) [STATEDEP-VAR] the state effect is on VARIABILITY (dispersion), not the mean -- + held-out permutation p
% The signed-deviation LINEAR fit (§17c) is ~flat, but the single-trial Local dip cloud FANS OUT with the
% state marker: the finding is heteroscedastic -- the local (residual) stim response is MORE VARIABLE when
% the state marker is high, NOT shifted in mean. So the right statistic measures SPREAD, not slope:
%   metric      : |within-amp-centered Local dip| = |dip_j - <dip>_amp|  (per-trial response variability)
%   finding plot: dispersion (MAD) of that metric across state QUANTILE bins -> a RISING curve = the claim
%   statistic   : partial Spearman( |dev| , state | pre-error )   (rank, robust to the fan shape)
% HELD-OUT PERMUTATION p (how p is computed): amp-means for centering come from a TRAIN split; |dev|, the
% statistic and the permutations are evaluated on the TEST split only (no trial both defines & tests). The
% null is built by SHUFFLING the state labels across test trials N times (breaks trial<->state pairing but
% keeps each marginal) and recomputing the statistic; p = (1 + #{|null| >= |real|}) / (N+1) = probability
% of a variability<->state association this strong by chance. Power caveat as everywhere: pre-var & abs-delta
% are signal-power confounds (bigger signal -> bigger residual deviation ~tautologically); the ADMISSIBLE
% claim is the power-independent markers Motion & Rel-delta.
rng(11,'twister');                                            % reproducible held-out split + permutations
nPermV = 2000;  nBinV = 5;                                    % permutations; state quantile bins
Vstate = {'Motion', MOT, true; 'Pre-var', PVv, false; 'Pre-\delta (abs)', DPa, false; 'Rel-\delta', DPr, true};
% deterministic held-out split: within each amp, alternate trials train/test (balances amp + preserves n)
teMask = false(numel(LD),1);
for a = 1:nA
    ia = find(AMPi==a);  teMask(ia(2:2:end)) = true;         % even-position trials within amp -> TEST
end
trMask = ~teMask;
% full-data |dev| (for the descriptive dispersion plot only; uses all trials' amp-mean)
absDevAll = abs(DVz);                                         % |signed z-within-amp deviation|
% pre-compute test-split |dev| about TRAIN amp-means (for the held-out statistic + permutation)
devHO = nan(numel(LD),1);
for a = 1:nA
    mtr = trMask & AMPi==a;  mte = teMask & AMPi==a;
    if nnz(mtr)>0, devHO(mte) = abs(LD(mte) - mean(LD(mtr),'omitnan')); end
end

fprintf('\n[STATEDEP-VAR] local-response VARIABILITY vs state (dispersion, not mean) — held-out permutation p (N=%d, %d bins):\n', nPermV, nBinV);
fprintf('   %-16s %10s %10s   %-14s\n','state','heldout_rho','perm_p','class');
rhoHO=nan(4,1); pHO=nan(4,1); Vnull=cell(4,1); binMed=nan(4,nBinV); binLo=nan(4,nBinV); binHi=nan(4,nBinV); binX=nan(4,nBinV);
for s = 1:4
    st = Vstate{s,2}(:);
    % held-out statistic + permutation p
    mte = teMask & isfinite(devHO) & isfinite(st) & isfinite(PRE);
    if nnz(mte) > 10
        rhoHO(s) = partialcorr(devHO(mte), st(mte), PRE(mte), 'type','Spearman');
        idx = find(mte);  nI = numel(idx);  nul = nan(nPermV,1);
        for k = 1:nPermV
            nul(k) = partialcorr(devHO(idx), st(idx(randperm(nI))), PRE(idx), 'type','Spearman');
        end
        pHO(s) = (1 + sum(abs(nul) >= abs(rhoHO(s)))) / (nPermV+1);
        Vnull{s} = nul;
    else
        Vnull{s} = nan(nPermV,1);
    end
    % descriptive dispersion across state quantile bins (all trials; MAD + bootstrap CI)
    md = isfinite(absDevAll) & isfinite(st);
    xs = st(md);  ys = absDevAll(md);
    if numel(xs) > nBinV*4
        edg = quantile(xs, linspace(0,1,nBinV+1));  edg(1)=-inf; edg(end)=inf;
        for bb = 1:nBinV
            inb = xs>=edg(bb) & xs<edg(bb+1);  yb = ys(inb);
            if nnz(inb) >= 5
                binMed(s,bb) = median(yb,'omitnan');  binX(s,bb) = median(xs(inb),'omitnan');
                bs = nan(500,1);  nb = numel(yb);
                for r = 1:500, bs(r) = median(yb(randi(nb,nb,1)),'omitnan'); end
                binLo(s,bb) = prctile(bs,2.5);  binHi(s,bb) = prctile(bs,97.5);
            end
        end
    end
    mk = '';  if pHO(s) < 0.05, mk = ' *'; end
    fprintf('   %-16s %+10.3f %10.4f   %-14s%s\n', regexprep(Vstate{s,1},'\\',''), rhoHO(s), pHO(s), ...
        ternstr(Vstate{s,3},'power-indep','POWER-CONFOUND'), mk);
end
fprintf('   NOTE: rho>0 => local-response variability RISES with the state marker (heteroscedastic). Interpret\n');
fprintf('         Motion + Rel-\\delta only (pre-var & abs-\\delta scale with signal power ~ trivially).\n');

% --- Fig A (NO p-value): the finding -- dispersion of the Local dip vs state quantile bins ------
figSV1 = figure('Color','w','Name','[STATEDEP-VAR] local-response variability vs state (finding)','Position',[60 80 1180 330]);
for s = 1:4
    ax = subplot(1,4,s); hold(ax,'on'); box(ax,'on');
    good = isfinite(binX(s,:)) & isfinite(binMed(s,:));
    if any(good)
        xb = binX(s,good);  yb = binMed(s,good);  lo = binLo(s,good);  hi = binHi(s,good);
        fill(ax,[xb fliplr(xb)],[lo fliplr(hi)],[.75 .82 .95],'EdgeColor','none','FaceAlpha',0.6);
        plot(ax, xb, yb, '-o','Color',[.1 .4 .85],'LineWidth',1.8,'MarkerFaceColor',[.1 .4 .85]);
    end
    admis = Vstate{s,3};  tcol = [0 0 0];  if ~admis, tcol = [.6 .3 0]; end
    title(ax, Vstate{s,1}, 'FontSize',9,'FontWeight','bold','Color',tcol);
    if ~admis, xlabel(ax,{'(power-confound';'not interpreted)'},'FontSize',7,'Color',[.6 .3 0]);
    else,      xlabel(ax, sprintf('%s (z)',regexprep(Vstate{s,1},'\\',''))); end
    if s==1, ylabel(ax,'|Local dip dev| (MAD \pm boot CI)'); end
end
sgtitle(sprintf('STATEDEP-VAR  %s %s e%d  —  single-trial LOCAL-response variability RISES with state (heteroscedastic finding; interpret Motion + Rel-\\delta)', ...
    mn,td,en),'FontWeight','bold','FontSize',9);

% --- Fig B (WITH p-value): held-out permutation null -> shows HOW p is computed -----------------
figSV2 = figure('Color','w','Name','[STATEDEP-VAR] held-out permutation p','Position',[80 60 1180 330]);
for s = 1:4
    ax = subplot(1,4,s); hold(ax,'on'); box(ax,'on');
    nul = Vnull{s};
    if any(isfinite(nul)), histogram(ax, nul, 30, 'FaceColor',[.6 .6 .6],'EdgeColor','none'); end
    if isfinite(rhoHO(s)), xline(ax, rhoHO(s), 'r-','LineWidth',1.8); end
    xline(ax, 0, 'k:');
    admis = Vstate{s,3};  tcol = [0 0 0];  if ~admis, tcol = [.6 .3 0]; end
    title(ax, sprintf('%s: p=%.3f',Vstate{s,1}, pHO(s)), 'FontSize',9,'FontWeight','bold','Color',tcol);
    xlabel(ax,'partial \rho (|dev| vs state)');  if s==1, ylabel(ax,'permutation count'); end
end
sgtitle(sprintf('STATEDEP-VAR  %s %s e%d  —  HELD-OUT permutation null (grey) vs real held-out \\rho (red):  p = frac(|null| \\geq |real|)  —  interpret Motion + Rel-\\delta', ...
    mn,td,en),'FontWeight','bold','FontSize',9);

STATEDEP_VAR = struct('stateLabel',{{'Motion','PreVar','PreDeltaAbs','RelDelta'}}, ...
                      'rho_heldout',rhoHO,'p_perm',pHO,'admissible',[true false false true], ...
                      'nPerm',nPermV,'nBin',nBinV,'binX',binX,'binMedian',binMed,'binLo',binLo,'binHi',binHi, ...
                      'teMask',teMask,'trMask',trMask,'mn',mn,'td',td,'en',en);


%% ==================================================================
%% STAGE 4 -- CROSS-SESSION BATCH
%% ==================================================================

%% (18) [ALLSESS-STIMBLIND] combined PRIMARY stim-blind decomposition across ALL sessions
% Runs the §17d SELECT stim-blind model HEADLESS for every session in allSelExp (default the three
% impulse datasets), so the local-only effect can be compared across mice/sessions in one place.
% Each session is decomposed exactly as §17d: per amp, KEEP the stim-UNAFFECTED contra pixels (per-amp
% ~bledA), fit the contra->ipsi spont OLS with the distance-weighted L1 penalty (few predictors, all FAR
% from ipsi) -> Global (carries the honest LEAK); Local (residual) = Actual - Global. Reuses the same
% cached site + ROI (cp_stim_site_*.mat,
% cp_roi2_*.mat) as the single-session path; NEVER opens the draw GUI. Outputs:
%   (a) one per-amp Actual/Global/Local trial-average figure per session,
%   (b) a combined Local-effect dose curve (Local dip vs amplitude, one line per session),
%   (c) the ALLSESS cell array of per-session structs for downstream comparison.
% Gated by RUN_ALLSESS so ordinary single-session runs are not tripled in cost.
if RUN_ALLSESS
    cfg = struct('nSV_load',nSV_load,'Fs',Fs,'nGrid',nGrid,'edgeMargin',edgeMargin, ...
                 'settle_s',settle_s,'trainFrac',trainFrac,'maxFrm',maxFrm, ...
                 'USE_DATA_SITE',USE_DATA_SITE,'dataDir',dataDir, ...
                 'bleed_preSec',bleed_preSec,'bleed_postSec',bleed_postSec, ...
                 'maxBaseTrl',maxBaseTrl,'dip_win_s',dip_win_s, ...
                 'select_l1frac',select_l1frac,'select_penNear',select_penNear,'select_penFar',select_penFar, ...
                 'select_ridge',select_ridge);
    ALLSESS = cell(numel(allSelExp),1);
    fprintf('\n[ALLSESS-STIMBLIND] combined PRIMARY stim-blind across %d sessions %s:\n', ...
            numel(allSelExp), mat2str(allSelExp));
    for si = 1:numel(allSelExp)
        S = local_stimblind_session(allSelExp(si), cfg, allExperiments);
        ALLSESS{si} = S;
        fprintf('   %-24s: full-grid spont R^2 %.4f | %d amps, grid %d, couple %.0f ms (null %.0f ms), median %.0f%% Local\n', ...
                S.label, S.r2_ols, numel(S.amps), S.nG, 1000*S.couple_win_s, 1000*S.null_win_s, S.medLocalPct);
        for ai = 1:numel(S.amps)
            fprintf('      %5.2f V | A %+.3f  G %+.3f  L %+.3f  (%3.0f%% Local)\n', ...
                    S.amps(ai), S.Actual(ai), S.Global(ai), S.Local(ai), 100*S.Local(ai)/S.Actual(ai));
        end
    end

    % --- (a) per-session per-amp trial-average panels (Actual / Global / Local) ----------
    for si = 1:numel(ALLSESS)
        S = ALLSESS{si};  na = numel(S.amps);  tt = S.rel/S.Fs;
        nc = min(na,5);  nr = ceil(na/nc);
        figure('Color','w','Name',sprintf('[ALLSESS] stim-blind trial avg — %s',S.label), ...
               'Position',[40 40 300*nc 240*nr]);
        for ai = 1:na
            ax = subplot(nr,nc,ai); hold(ax,'on'); box(ax,'on');
            if isempty(S.trA{ai}), title(ax,sprintf('%.2f V (n/a)',S.amps(ai))); continue; end
            plot(ax,tt,S.trA{ai},'k-','LineWidth',1.6);
            plot(ax,tt,S.trG{ai},'-','Color',[.85 .2 .2],'LineWidth',1.3);
            plot(ax,tt,S.trL{ai},'-','Color',[.1 .4 .85],'LineWidth',1.3);
            xline(ax,0,'k:'); yline(ax,0,'k:'); xlim(ax,[-.5 1]);
            title(ax,sprintf('%.2f V  (%.0f%% Local)',S.amps(ai),100*S.Local(ai)/S.Actual(ai)), ...
                  'FontSize',9,'FontWeight','bold');
            if ai==1
                legend(ax,{'Actual','Global (clean contra pred)','Local (residual=stim)'}, ...
                       'FontSize',6,'Location','best');
                ylabel(ax,'\DeltaF/F %');
            end
            if ai>na-nc, xlabel(ax,'t re onset (s)'); end
        end
        sgtitle(sprintf('STIM-BLIND (per-amp clean pixels) — %s   (full-grid spont R^2 %.3f, median %.0f%% Local)', ...
                S.label, S.r2_ols, S.medLocalPct),'FontWeight','bold');
    end

    % --- (a2) per-session bleed characterization (§13/§14 headless) for every session ----
    fprintf('\n[ALLSESS-BLEEDCHAR] per-session bleed-affected classification (coupling-window abs energy):\n');
    for si = 1:numel(ALLSESS)
        S = ALLSESS{si};
        local_bleedchar_session(S.BC, S.label, 1.28, 300);   % bc_z_thr=1.28, 300 bootstrap (match §14)
    end

    % --- (b) combined Local-effect dose curve (one line per session) ---------------------
    figure('Color','w','Name','[ALLSESS] Local-effect dose curves','Position',[80 80 640 460]);
    hold on; box on;  cols = lines(numel(ALLSESS));
    for si = 1:numel(ALLSESS)
        S = ALLSESS{si};
        plot(S.amps, S.Local, '-o', 'Color',cols(si,:), 'MarkerFaceColor',cols(si,:), ...
             'LineWidth',1.6, 'DisplayName',S.label);
    end
    yline(0,'k:'); xlabel('amplitude (V)'); ylabel(sprintf('Local dip (\\DeltaF/F %%, 0-%.0f ms)',1000*dip_win_s));
    title('STIM-BLIND Local-effect dose curve across sessions','FontWeight','bold');
    legend('Location','best','FontSize',8);
end

% (§20 SESSION-VIEWER merged into §8 — the interactive session-picker map now runs there.)

% ================================ local functions ================================

%% ==================================================================
%% APPENDIX -- interactive explorers + diagnostics (optional, out of main flow)
%% ==================================================================

%% (8) Interactive map with a SESSION PICKER — pick session; click an IPSI pixel -> refit
% The ONE interactive contra->ipsi map (formerly split across the old §8 single-session map and
% §20 picker; consolidated 2026-07-06). A dropdown picks any session in allSelExp; its brain loads
% in the disp_orient view (default 'auto': ipsi right, midline vertical), the laser site is marked
% (green +), and the sparse contra-grid weights predicting the site pixel are shown. Click any IPSI
% pixel -> the contra weights refit to predict it (same fit_mode/l1_frac model as §7). The click ->
% pixel mapping inverts through the SAME Torient, so selection is never transposed on any session
% (verified). The CURRENT selExp is pre-seeded from the data already loaded in §1-§7, so the viewer
% opens ON it instantly (no 17 s reload); switching to another session loads + caches it once.
if RUN_SESSION_VIEWER
    cfgV = struct('nSV_load',nSV_load,'Fs',Fs,'nGrid',nGrid,'edgeMargin',edgeMargin, ...
                  'settle_s',settle_s,'trainFrac',trainFrac,'maxFrm',maxFrm, ...
                  'USE_DATA_SITE',USE_DATA_SITE,'dataDir',dataDir,'fit_mode',fit_mode, ...
                  'l1_frac',l1_frac,'ridge',ridge,'debias',debias,'disp_orient',disp_orient);
    D.T = Torient;                                              % keep D self-describing in the cache
    preload = struct('sel',selExp,'D',D,'px',px_prim,'py',py_prim,'T',Torient);
    % allSelExp is the 3-session default list; drop anything not actually loaded (a single-session
    % workspace -- e.g. the AL_0048-only run -- would otherwise index past the end of allExperiments)
    viewList = allSelExp(allSelExp >= 1 & allSelExp <= numel(allExperiments));
    if isempty(viewList); viewList = selExp; end
    local_session_viewer(cfgV, allExperiments, viewList, preload);
    fprintf('\n[VIEWER] session-picker map (%s): pick a session; click any IPSI pixel -> contra weights refit.\n', fit_mode);
else
    % viewer disabled -> record the site-pixel weights headlessly for the current session
    [bpix, cv, ~, ~, nAct] = ols_refit(D, px_prim, py_prim);
    OLS = struct('gridIdx',gridIdx,'gridRC',[grR grC],'bpix',bpix,'cv',cv,'nG',nG, ...
                 'fit_mode',fit_mode,'l1_frac',l1_frac,'ridge',ridge,'nActive',nAct, ...
                 'mn',mn,'td',td,'en',en);
    fprintf('\n[OLS] viewer off; site-pixel weights recorded: R^2=%.3f, %d/%d px active (%s).\n', cv, nAct, nG, fit_mode);
end

%% ==================================================================
%% LOCAL FUNCTIONS (shared)
%% ==================================================================

function [bpix, cv, yte, yhat_te, nActive] = ols_refit(D, row, col)
% Refit the fixed contra-grid map to a NEW ipsi target pixel (kernel-mean %dF/F around
% row,col with half-width D.k). fit_mode = ols | ridge | lasso (L1 sparsity).
% Returns per-pixel weights, held-out R^2, held-out traces, and #active pixels.
kr = max(1,row-D.k):min(D.nY,row+D.k);  kc = max(1,col-D.k):min(D.nX,col+D.k);
[KR,KC] = ndgrid(kr,kc);  kidx = sub2ind([D.nY,D.nX], KR(:), KC(:));
mI = mean(D.mimg(kr,kc),'all');
y_all = (mean(D.Uflat(kidx,:),1) * D.V) / max(mI,eps) * 100;   % [1 x nAllFrames] %dF/F (single)
y_sp  = double(y_all(D.frames)).';                             % cast only the spont subset
ytr = y_sp(D.itr);  yte = y_sp(D.ite);
switch D.fit_mode
    case 'lasso'                                              % L1 (+ optional L2 = elastic net)
        muy = mean(ytr);  c = D.Ztr.' * (ytr - muy);
        lam1 = D.l1_frac * max(abs(c));                       % L1 penalty (sparsity), scaled to target
        lam2 = D.ridge * median(D.Gdiag);                     % L2 penalty (grouping); 0 = pure lasso
        betaz = cd_lasso(D.G, c, D.Gdiag, lam1, lam2);
        S = find(betaz ~= 0);                                 % selected (active) pixels
        if D.debias && ~isempty(S)                            % refit OLS on the support (unshrink)
            As  = [ones(numel(D.itr),1) D.Ztr(:,S)];
            cs  = As \ ytr;
            betaz = zeros(numel(betaz),1);  betaz(S) = cs(2:end);
            yhat_te = cs(1) + D.Ate(:,1+S) * cs(2:end);
        else
            yhat_te = muy + D.Ate(:,2:end) * betaz;
        end
    case 'ridge'
        coef = D.fitOp * ytr;  betaz = coef(2:end);  yhat_te = D.Ate * coef;
    otherwise                                                % ols
        coef = D.fitOp(ytr);   betaz = coef(2:end);  yhat_te = D.Ate * coef;
end
bpix = betaz ./ D.sd_p;
cv = sseExplainedCal(yte(:).', yhat_te(:).');
nActive = nnz(betaz);
end

function b = cd_lasso(G, c, dg, lam1, lam2)
% Coordinate-descent ELASTIC NET:
%   min_b  1/2||y - Z b||^2 + lam1*||b||_1 + (lam2/2)*||b||_2^2
% using precomputed G = Z'Z, c = Z'(y - mean(y)), dg = diag(G). lam2=0 -> pure Lasso.
% Z is the standardized contra-grid design (intercept handled by centering y). The L2
% term just adds lam2 to each coordinate's denominator, which shrinks + groups
% correlated pixels while the L1 soft-threshold keeps the solution sparse.
if nargin < 5 || isempty(lam2), lam2 = 0; end
p = numel(c);  b = zeros(p,1);  Gb = zeros(p,1);
for it = 1:400
    maxd = 0;
    for j = 1:p
        rj  = c(j) - Gb(j) + dg(j)*b(j);                     % partial residual for coord j
        bj  = sign(rj) * max(abs(rj)-lam1, 0) / (dg(j)+lam2); % soft-threshold + L2 shrink
        dbj = bj - b(j);
        if dbj ~= 0
            Gb = Gb + G(:,j)*dbj;  b(j) = bj;
            if abs(dbj) > maxd, maxd = abs(dbj); end
        end
    end
    if maxd < 1e-6*max(1, max(abs(b))), break; end
end
end

function ridge_sweep_figure(RS, mn, td, en)
% §17f figure for the §17c0 sweep. Pure drawing -- never re-fits, so re-plotting is free.
grid_ = RS.grid;  nRG = numel(grid_);  r2med = RS.r2med;  lkmed = RS.leakmed;  iCur = RS.iCur;
haveDist = any(isfinite(RS.wdist(:)));
f = figure('Color','w','Name','[RIDGE-SWEEP] spont R^2 vs leak','Position',[80 80 1180 420]);
axA = subplot(1,3,1,'Parent',f); hold(axA,'on'); box(axA,'on');          % THE trade-off curve
plot(axA, lkmed, r2med, '-o','Color',[.1 .4 .85],'LineWidth',1.6,'MarkerFaceColor',[.1 .4 .85]);
plot(axA, lkmed(iCur), r2med(iCur), 'p','MarkerSize',15,'MarkerFaceColor',[.9 .3 .1],'MarkerEdgeColor','k');
yline(axA, RS.r2min, 'k--','LineWidth',1.1);                             % the R^2 floor the pick respected
text(axA, min(lkmed), RS.r2min, sprintf('  R^2 floor %.2f',RS.r2min),'FontSize',7,'VerticalAlignment','bottom');
for ri = 1:nRG, text(axA, lkmed(ri), r2med(ri), sprintf('  %.4g',grid_(ri)),'FontSize',6); end
xlabel(axA,'leak: Global dip as % of Actual'); ylabel(axA,'held-out SPONTANEOUS R^2');
title(axA,'the actual trade-off (star = PICKED)','FontSize',9,'FontWeight','bold');
axB = subplot(1,3,2,'Parent',f); hold(axB,'on'); box(axB,'on');
yyaxis(axB,'left');  plot(axB, 1:nRG, r2med, '-o','LineWidth',1.5); ylabel(axB,'spont R^2');
yyaxis(axB,'right'); plot(axB, 1:nRG, 100-lkmed,'-s','LineWidth',1.5); ylabel(axB,'residual capture (%)');
xline(axB, iCur, 'k:','LineWidth',1.2);
set(axB,'XTick',1:nRG,'XTickLabel',compose('%.4g',grid_),'XTickLabelRotation',45);
xlabel(axB,'select\_ridge'); title(axB,'both objectives vs the knob','FontSize',9,'FontWeight','bold');
axC = subplot(1,3,3,'Parent',f); hold(axC,'on'); box(axC,'on');
if haveDist
    plot(axC, 1:nRG, median(RS.wdist,2,'omitnan'), '-o','Color',[.2 .6 .2],'LineWidth',1.5);
    ylabel(axC,'mean |w| distance from ipsi (px)');
    title(axC,'is the prior actually moving weight away?','FontSize',9,'FontWeight','bold');
    set(axC,'XTick',1:nRG,'XTickLabel',compose('%.4g',grid_),'XTickLabelRotation',45); xlabel(axC,'select\_ridge');
else
    text(axC,0.5,0.5,'selDist unavailable','HorizontalAlignment','center'); axis(axC,'off');
end
sgtitle(f, sprintf(['RIDGE-SWEEP  %s %s e%d  --  dense weighted-L2 far-from-ipsi prior.  ' ...
    'R^2 is HELD-OUT SPONTANEOUS; leak is measured on the stim windows.'], mn, td, en),'FontWeight','bold','FontSize',9);
end

function b = select_wlasso(G, c, S, gamma, l1frac, lamR)
% SELECT model: SPARSE, DISTANCE-WEIGHTED spont contra->ipsi fit restricted to predictor set S:
%   min_b ||y - Z_S b||^2 + lam1 * sum_i (1/gamma_i)|b_i| + lam2||b||^2
% The 1/gamma_i penalty GROWS toward the ipsi site (gamma small near, large far), so near-ipsi predictors
% are expensive (dropped) and far ones cheap (retained) -> few predictors, all FAR from ipsi. Solved by
% column-rescaling b_i = gamma_i a_i, which turns the weighted L1 into a UNIFORM lasso in a (cd_lasso).
b = zeros(size(G,1),1);
if isempty(S), return; end
g   = gamma(S);
Gs  = (g*g.') .* G(S,S);                     % Z~'Z~  with Z~ = Z_S diag(g)
cs  = g .* c(S);                             % Z~'(y - mean)
dgs = diag(Gs);
if l1frac <= 0
    % NO-SPARSITY path (default since 2026-08-05). lam1 = 0 makes the objective purely quadratic, so
    % solve it in closed form rather than running coordinate descent to the same answer. Note what the
    % gamma rescaling becomes here: b_i = gamma_i a_i, and a ridge lamR||a||^2 equals lamR*sum(b_i/gamma_i)^2
    % -- so the far-from-ipsi prior SURVIVES as a WEIGHTED L2 whose strength is set entirely by lamR. At the
    % default lamR (1e-6, a numerical stabiliser) that prior is negligible and this is plain OLS over the
    % whole unaffected set; pass a real ridge (select_ridge) to make it bite without zeroing any weight.
    a = (Gs + lamR*eye(numel(S))) \ cs;
else
    lam1 = l1frac * max(abs(cs));            % L1 scaled to the rescaled target
    a = cd_lasso(Gs, cs, dgs, lam1, lamR);   % uniform lasso (+ tiny ridge lamR)
end
b(S) = g .* a;                               % undo the rescale
end

function select_refit_btn(figT)
% §10T3 "Refit SELECT model": refit + preview the sparse, far-from-ipsi SELECT model at the CURRENT
% sensitivity. Per amp: S = unaffected px (this sensitivity) -> weighted lasso b -> Global=b'*evZ,
% Local=Actual-Global. Draws dip/rebound dose curves (Actual/Global=LEAK/Local), the strongest-amp weight
% map (sparse, distal), and per-amp traces. Reuses one figure so repeated presses update in place.
DB = guidata(figT);  nA = numel(DB.amps);  amps = DB.amps;  ttc = DB.ttc;  preN = DB.preN;
As=nan(nA,1); Gd=nan(nA,1); Ld=nan(nA,1); Ar=nan(nA,1); Gr=nan(nA,1); Lr=nan(nA,1);
nUse=zeros(nA,1); nAct=zeros(nA,1); trA=cell(nA,1); trG=cell(nA,1); trL=cell(nA,1); bA=cell(nA,1);
for ai=1:nA
    if isempty(DB.selEvZ{ai}), continue; end
    aff=DB.affected_tf(:,ai); active=~aff; if nnz(active)<5, active=true(size(active)); end;  S=find(active);
    b = select_wlasso(DB.selGz, DB.selcz, S, DB.selGamma, DB.selL1frac, DB.sellamR);
    yg=(b.'*DB.selEvZ{ai}).'; yg=yg-mean(yg(1:preN));  aA=DB.selAA{ai};  rL=aA-yg;
    dc=DB.selDc{ai};  rc=DB.selRc{ai};
    As(ai)=mean(aA(dc)); Gd(ai)=mean(yg(dc)); Ld(ai)=mean(rL(dc));
    if ~isempty(rc), Ar(ai)=mean(aA(rc)); Gr(ai)=mean(yg(rc)); Lr(ai)=mean(rL(rc)); end
    nUse(ai)=numel(S); nAct(ai)=nnz(b~=0); trA{ai}=aA(:); trG{ai}=yg(:); trL{ai}=rL(:); bA{ai}=b;
end
capD=median(100*Ld./As,'omitnan'); leakD=median(100*Gd./As,'omitnan'); capR=median(100*Lr./Ar,'omitnan');
fprintf('[SELECT-REFIT] tf_sens=%.2f  median dip capture %.0f%% (leak %.0f%%) | reb capture %.0f%% | active px/amp: ', DB.sens, capD, leakD, capR);
fprintf('%d ', nAct);  fprintf('\n');

f = findobj('Type','figure','Name','SELECT model (sparse, far-from-ipsi)');
if isempty(f), f = figure('Name','SELECT model (sparse, far-from-ipsi)','Color','w','Units','normalized','Position',[0.10 0.08 0.80 0.82]); else, clf(f); figure(f); end
nC=3; nR=ceil((3+nA)/nC);
ax=subplot(nR,nC,1,'Parent',f); hold(ax,'on'); box(ax,'on');
plot(ax,amps,As,'-o','Color','k','LineWidth',1.6,'MarkerFaceColor','k','DisplayName','Actual');
plot(ax,amps,Gd,'-s','Color',[.85 .2 .2],'LineWidth',1.3,'MarkerFaceColor',[.85 .2 .2],'DisplayName','Global (LEAK)');
plot(ax,amps,Ld,'-^','Color',[.1 .4 .85],'LineWidth',1.3,'MarkerFaceColor',[.1 .4 .85],'DisplayName','Local (residual)');
yline(ax,0,'k:'); xlabel(ax,'amp (V)'); ylabel(ax,'dip \DeltaF/F %'); legend(ax,'Location','southwest','FontSize',7);
title(ax,sprintf('DIP  (cap %.0f%%, leak %.0f%%)',capD,leakD),'FontSize',9,'FontWeight','bold');
ax=subplot(nR,nC,2,'Parent',f); hold(ax,'on'); box(ax,'on');
plot(ax,amps,Ar,'-o','Color','k','LineWidth',1.6,'MarkerFaceColor','k','DisplayName','Actual');
plot(ax,amps,Gr,'-s','Color',[.85 .2 .2],'LineWidth',1.3,'MarkerFaceColor',[.85 .2 .2],'DisplayName','Global');
plot(ax,amps,Lr,'-^','Color',[.1 .4 .85],'LineWidth',1.3,'MarkerFaceColor',[.1 .4 .85],'DisplayName','Local');
yline(ax,0,'k:'); xlabel(ax,'amp (V)'); ylabel(ax,'rebound \DeltaF/F %'); title(ax,sprintf('REBOUND (cap %.0f%%)',capR),'FontSize',9,'FontWeight','bold');
ax=subplot(nR,nC,3,'Parent',f); hold(ax,'on');
aiR=find(~cellfun(@isempty,bA),1,'last');
if ~isempty(aiR)
    gg=double(DB.gB); gg=(gg-min(gg(:)))/max(max(gg(:))-min(gg(:)),eps);
    image(ax, repmat(gg,[1 1 3])); axis(ax,'image','off'); set(ax,'YDir','reverse');
    w=bA{aiR}; act=w~=0; wsc=max(abs(w))+eps;
    scatter(ax,DB.dspGc(~act),DB.dspGr(~act),8,[.7 .7 .7],'filled');
    scatter(ax,DB.dspGc(act), DB.dspGr(act), 26, w(act),'filled','MarkerEdgeColor',[.2 .2 .2],'LineWidth',0.3);
    sM=linspace(0,1,128)'; colormap(ax,[[sM sM ones(128,1)];[ones(128,1) 1-sM 1-sM]]); clim(ax,[-wsc wsc]);
    plot(ax,DB.dspSc,DB.dspSr,'g+','MarkerSize',12,'LineWidth',1.8);
    title(ax,sprintf('%.1f V weights: %d active / %d avail (far from ipsi +)',amps(aiR),nnz(act),nUse(aiR)),'FontSize',9,'FontWeight','bold');
end
for ai=1:nA
    ax=subplot(nR,nC,3+ai,'Parent',f); hold(ax,'on'); box(ax,'on');
    if isempty(trA{ai}), title(ax,sprintf('%.1f V n/a',amps(ai))); continue; end
    plot(ax,ttc,trA{ai},'k-','LineWidth',1.4,'DisplayName','Actual');
    plot(ax,ttc,trG{ai},'-','Color',[.85 .2 .2],'LineWidth',1.1,'DisplayName','Global');
    plot(ax,ttc,trL{ai},'-','Color',[.1 .4 .85],'LineWidth',1.1,'DisplayName','Local');
    xline(ax,0,'k:'); yline(ax,0,'k:'); xlim(ax,[-.5 1]);
    title(ax,sprintf('%.1f V (%d act, dip %.0f%%)',amps(ai),nAct(ai),100*Ld(ai)/As(ai)),'FontSize',8,'FontWeight','bold');
    if ai==1, legend(ax,'Location','southeast','FontSize',5); ylabel(ax,'\DeltaF/F %'); end
end
sgtitle(f,sprintf('SELECT model @ tf_sens=%.2f — SPARSE, weighted FAR from ipsi (L1frac=%.2f).  Global(red)=leak, Local(blue)=recovered dip',DB.sens,DB.selL1frac),'FontWeight','bold');
end

function bleed_click(figB, ~)
% Click a pixel in any per-amp subplot -> inspect that pixel's peri-stim response.
DB = guidata(figB);
for ai = 1:numel(DB.axB)
    ax = DB.axB(ai);  cp = ax.CurrentPoint;  x = cp(1,1);  y = cp(1,2);
    xl = ax.XLim;  yl = ax.YLim;
    if x>=xl(1) && x<=xl(2) && y>=yl(1) && y<=yl(2)
        [~,p] = min((DB.gdC - x).^2 + (DB.gdR - y).^2);   % x=display col, y=display row
        bleed_detail(DB, p, ai);  return;
    end
end
end

function onF = local_onsets(st, t_full, preN, postN, nFall)
% Nearest movie frame to each stim start-time, keeping only windows fully inside the movie.
onF = zeros(numel(st),1);
for j = 1:numel(st), [~,onF(j)] = min(abs(t_full - st(j))); end
onF = onF(onF-preN>=1 & onF+postN<=nFall);
end

function [m, blk] = local_periavg(Xpct, onF, rel, preN, nG, Wb)
% Peri-onset block [nG x Wb x nTrials] and its pre-window-baselined trial average [nG x Wb].
blk = reshape(Xpct(:,(onF(:).'+rel(:))), nG, Wb, numel(onF));
m = mean(blk - mean(blk(:,1:preN,:),2), 3);
end

function s = ternstr(cond, a, b)
% tiny string-ternary helper (MATLAB has no ?: operator): returns a if cond else b.
if cond, s = a; else, s = b; end
end

function tfmap_button(fig, ~)
% §10T3 click router: click a pixel -> open the biphasic-TF-fit inspector for it.
DB = guidata(fig);  [ai,p] = tfmap_hit(DB);  if isempty(ai), return; end
tfmap_detail(DB, p, ai);
end

function tfmap_sens(figT, hSlider)
% §10T3 LIVE sensitivity re-threshold from the CACHED TF-fit maps (NO refit). threshold = vafGate/sens:
% higher sens -> lower VAF bar -> MORE affected; lower -> stricter. affected = VAF>thr & dip<0
% (& reboundRatio>rebMin if reqReb). Mirrors the batch rule in §10T exactly.
DB = guidata(figT);
s = get(hSlider,'Value');  DB.sens = s;  tot = 0;
for ai = 1:numel(DB.amps)
    aff = (-DB.DIPgate(:,ai) > DB.preThr(:,ai)/max(s,eps));   % PRIMARY: FITTED early-window dip vs baseline floor
    if DB.useVAF, aff = aff & (DB.VAF(:,ai) > DB.vafMin); end                     % optional absolute VAF floor
    if DB.useShape                                                                % SHAPE, measured on the DATA
        aff = aff & (DB.TRdatMs(:,ai) >= DB.trBandA(ai,1)) & (DB.TRdatMs(:,ai) <= DB.trBandA(ai,2));
        aff = aff & DB.hasRec(:,ai) & (DB.RECdatMs(:,ai) <= DB.recMaxFac*DB.recMsA2(ai));
    end
    if DB.reqReb, aff = aff & (DB.REB(:,ai) > DB.rebMin); end
    DB.affected_tf(:,ai) = aff;  tot = tot + nnz(aff);
    set(DB.hUn(ai),  'XData', DB.dspGc(~aff), 'YData', DB.dspGr(~aff));
    set(DB.hAff(ai), 'XData', DB.dspGc(aff),  'YData', DB.dspGr(aff));
    title(DB.axT(ai), sprintf('%.1f V   %d aff', DB.amps(ai), nnz(aff)), 'FontSize',10,'FontWeight','bold');
end
set(DB.hSensTxt, 'String', sprintf('tf\\_sens = %.2f   (%d aff total)', s, tot));
guidata(figT, DB);
end

function [ai,p] = tfmap_hit(DB)
% locate the clicked amp-subplot + its nearest grid pixel (display coords)
ai = [];  p = [];
for k = 1:numel(DB.axT)
    ax = DB.axT(k);  cp = ax.CurrentPoint;  x = cp(1,1);  y = cp(1,2);
    if x>=ax.XLim(1) && x<=ax.XLim(2) && y>=ax.YLim(1) && y<=ax.YLim(2)
        [~,p] = min((DB.gdC - x).^2 + (DB.gdR - y).^2);  ai = k;  return;
    end
end
end

function tfmap_detail(DB, p, ai)
% §10T3 inspector: refit the clicked pixel's biphasic TF to its onset-referenced trial-mean evoked (the
% EXACT §10T computation), overlay the fitted impulse response on the data + wider peri-onset context, and
% report VAF vs the 0V-null gate, the dip, and the rebound ratio. MEX-free Prony fit -- no crash.
% The GATED dip is the deepest fit point WITHIN the cap [0, dipCapSec] (grey dashed line); the red marker is
% that gated dip, and the gate is 'gated dip < baseline floor'. The full-window trough is reported for reference.
Fs = DB.Fs;  wa = DB.winA{ai};  vg = DB.vafGate(ai)/max(DB.sens,eps);   % current VAF threshold at the slider sens
mu = DB.muMap(p,:,ai);  mu = mu(:);                                     % pre-stim-baselined trial mean [Wb x 1] (force column)
rr = mu(wa);  if DB.smoothN>1, rr = smoothdata(rr,'movmean',DB.smoothN); end   % match the batch pre-fit smoothing
r1 = rr(1);  r = rr - r1;                                               % onset-referenced (the fitted data, r(1)=0)
if DB.sweep, [sys, vaf, ch] = proto_fitTF(r, DB.Ts, DB.maxP, DB.maxZ, DB.nd, DB.nPreZ, []);
else,        [sys, vaf, ch] = proto_fitTF_fix(r, DB.Ts, DB.np, DB.nz, DB.nd, DB.nPreZ, []); end
yhat = proto_sim(sys, numel(wa), DB.Ts, DB.nPreZ);                      % fitted impulse response
sflr = -DB.preThr(p,ai)/max(DB.sens,eps);                              % baseline depth floor (negative), fit-onset frame
capN = max(1, min(numel(yhat), DB.capNa(ai)));                        % dip-cap: THIS amp's ipsi-learned inhibition lobe
[dipCap, iCap] = min(yhat(1:capN));                                    % GATED early-window fitted dip + its index
vafOK = ~DB.useVAF || vaf > DB.vafMin;  dipOK = dipCap < 0;  preOK = dipCap < sflr;  rebOK = ~DB.reqReb || ch.reboundRatio > DB.rebMin;
% FIT-side shape values -- DIAGNOSTIC ONLY (they no longer gate). Shown next to the DATA values so a
% sluggish fit is visible as a divergence rather than silently deciding anything (TASKS #183).
trCapMs = (iCap-1)/Fs*1000;                                            % FIT trough time inside the gate window
recFrac = yhat(capN) / min(dipCap, -eps);                              % FIT dip remaining at capN: ~1 ramp, ~0 recovered
% SHAPE is judged on the DATA (see §10T). Recompute this pixel's evoked landmarks the same way.
rd = r(:);  [dvD, itD] = min(rd);  trDatMs = (itD-1)/Fs*1000;
tolD = max(2*DB.preStd(p,ai), DB.recTolFac*abs(dvD));
kD   = itD - 1 + find(rd(itD:end) >= -tolD, 1, 'first');
if isempty(kD), recDatMs = NaN; hasRecD = false; else, recDatMs = (kD-1)/Fs*1000; hasRecD = true; end
recLim = DB.recMaxFac*DB.recMsA2(ai);
trOK  = ~DB.useShape || (trDatMs >= DB.trBandA(ai,1) && trDatMs <= DB.trBandA(ai,2));
recOK = ~DB.useShape || (hasRecD && recDatMs <= recLim);
if dipOK && preOK && vafOK && rebOK && trOK && recOK, why = 'AFFECTED';
elseif ~preOK,              why = 'not (dip within baseline floor)';   % PRIMARY gate
elseif ~dipOK,              why = 'not (no dip)';
elseif ~vafOK,              why = 'not (VAF<min)';
elseif ~trOK,               why = sprintf('not (DATA trough %.0f ms outside [%.0f %.0f] -> ramp/edge-trough)', trDatMs, DB.trBandA(ai,1), DB.trBandA(ai,2));
elseif ~recOK && ~hasRecD,  why = sprintf('not (DATA never returns to its baseline band within the %.0f ms fit window)', 1000*numel(rd)/Fs);
elseif ~recOK,              why = sprintf('not (DATA recovers at %.0f ms > limit %.0f ms = %.1fx ipsi)', recDatMs, recLim, DB.recMaxFac);
else,                       why = 'not (no rebound)'; end
xfull = DB.rel(:)/Fs;  xw = DB.rel(wa);  xw = xw(:)/Fs;  rRefA = DB.mAmpP(:,ai);   % context + ipsi ref (force column)
w0 = DB.rel(wa(1))/Fs;  w1 = DB.rel(wa(end))/Fs;                        % fit window span (s)
f = findobj('Type','figure','Name','TF pixel inspector');
if isempty(f), f = figure('Name','TF pixel inspector','Color','w','Position',[700 200 820 480]); else, clf(f); figure(f); end
ax = axes(f);  hold(ax,'on');  box(ax,'on');
dat = [mu; r(:); sflr];  yl = [min(dat) max(dat)];  if ~(diff(yl)>0), yl = [-1 1]; end
patch(ax,[w0 w1 w1 w0],[yl(1) yl(1) yl(2) yl(2)],[1 .94 .82],'EdgeColor','none','FaceAlpha',0.7);   % fit window
plot(ax, xfull, mu,   '-', 'Color',[.55 .55 .55], 'LineWidth',1.0);    % full peri-onset context (trial mean)
plot(ax, xw,   r,     'k',   'LineWidth',1.7);                         % onset-referenced evoked (fitted data)
plot(ax, xw,   yhat,  'r--', 'LineWidth',1.5);                         % biphasic TF fit over the window
plot(ax, xfull, rRefA,'Color',[.3 .5 .8], 'LineWidth',1.0);          % ipsi reference (this amp)
plot(ax, [w0 w1], sflr*[1 1], ':', 'Color',[0 .55 0], 'LineWidth',1.4);   % baseline depth floor (trough must go below)
plot(ax, xw(capN)*[1 1], yl, '--', 'Color',[.5 .5 .5], 'LineWidth',1.0, 'HandleVisibility','off');   % dip-cap boundary
plot(ax, xw(iCap), dipCap, 'v', 'MarkerFaceColor','r', 'MarkerEdgeColor','k', 'MarkerSize',7, 'HandleVisibility','off');   % GATED dip
xline(ax,0,'k-','LineWidth',0.6);  yline(ax,0,':','Color',[.6 .6 .6]);
xlim(ax,[xfull(1) xfull(end)]);  ylim(ax,yl+0.08*diff(yl)*[-1 1]);
legend(ax,{'fit window','trial mean','evoked (fit data)','TF fit','ipsi ref','baseline floor'},'Location','best','FontSize',8);
xlabel(ax,'t re onset (s)');  ylabel(ax,'\DeltaF/F % (pre-stim ref)');
title(ax, sprintf(['g%d @ %.1fV | VAF=%.0f%%(0Vnull %.0f) rebR=%.2f (diagnostic only) | gate dip(\\leq%.0fms, ipsi lobe%s)=%.2f vs floor %.2f\n' ...
    'SHAPE(DATA): trough %.0f ms (band [%.0f %.0f]) | recovers %.0f ms (limit %.0f = %.1fx ipsi)   [fit: trough %.0f ms, recFrac %.2f -- diagnostic] -> %s'], ...
    p, DB.amps(ai), vaf, vg, ch.reboundRatio, 1000*(capN-1)/Fs, ternstr(DB.capFallback(ai),' FALLBACK',''), dipCap, sflr, ...
    trDatMs, DB.trBandA(ai,1), DB.trBandA(ai,2), recDatMs, recLim, DB.recMaxFac, trCapMs, recFrac, why), 'FontSize',9);
end

function [sys, vaf, ch, ord] = proto_fitTF(r, Ts, maxP, maxZ, maxD, nPreZ, opt) %#ok<INUSD>
% §10T framing-A: SWEEP (na,nb) and keep the AIC-best low-order DISCRETE model for an impulse-response
% vector r (evoked, t=0 at first sample). *** MEX-FREE *** (Prony least-squares fit + filter; NO tfest,
% NO sim/impulse -> never touches the crashing controllib sssim MEX). Returns a discrete sys struct
% {b,a,ir}, in-window VAF (%), characteristics, and the selected order ord=[na nb 0]. maxD ignored (delay 0).
r = r(:);  nT = numel(r);
bestC = inf;  sys = [];  ord = [NaN NaN 0];
for na = 1:maxP
    for nb = 0:min(na-1, maxZ)                          % nb<na => strictly proper (h[0]=0), matches onset ref
        [bb, aa, ok] = ba_fit(r, na, nb);
        if ~ok, continue; end
        yh = filter(bb, aa, [1; zeros(nT-1,1)]);
        if any(~isfinite(yh)), continue; end            % unstable fit blew up -> skip (filter itself can't crash)
        sse = sum((r - yh).^2);  k = na + nb + 1;
        aicv = nT*log(max(sse/nT, eps)) + 2*k;          % AIC-like parsimony criterion (no likelihood needed)
        if aicv < bestC, bestC = aicv; sys = struct('b',bb,'a',aa,'ir',yh); ord = [na nb 0]; end
    end
end
[vaf, ch] = proto_vafch(sys, r, nT, Ts, nPreZ);
end

function [sys, vaf, ch] = proto_fitTF_fix(r, Ts, np, nz, nd, nPreZ, opt) %#ok<INUSD>
% §10T2: fit ONE DISCRETE model at a FIXED order (na=np, nb=nz; nd ignored, delay=0) to the impulse
% response r. *** MEX-FREE ***: Prony least-squares (a single \ solve) + filter -> NO tfest, NO sim, so it
% CANNOT access-violate. A degenerate/unstable fit just yields a poor VAF and is rejected by the gate.
r = r(:);  nT = numel(r);
nMin = 2*(np + nz + 1);                                  % need comfortably more samples than parameters
if nT < nMin || ~all(isfinite(r)) || std(r) < eps
    sys = [];  [vaf, ch] = proto_vafch(sys, r, nT, Ts, nPreZ);  return;
end
[bb, aa, ok] = ba_fit(r, np, nz);
if ok
    yh = filter(bb, aa, [1; zeros(nT-1,1)]);
    if all(isfinite(yh)), sys = struct('b',bb,'a',aa,'ir',yh); else, sys = []; end
else
    sys = [];
end
[vaf, ch] = proto_vafch(sys, r, nT, Ts, nPreZ);
end

function [b, a, ok] = ba_fit(h, na, nb)
% MEX-free rational fit of impulse response h. Steiglitz-McBride (stmcb) = Prony-seeded OUTPUT-ERROR: it
% iterates with filter() to minimise the actual output error, so it is MUCH better than raw Prony on noisy
% trial-averages (raw Prony fits the noisy recursion and gives bad poles). stmcb never touches sssim ->
% cannot crash. Falls back to prony_fit if stmcb is unavailable/errors. na = poles, nb = numerator zeros.
h = h(:);  ok = false;  b = zeros(nb+1,1);  a = [1; zeros(na,1)];
try
    [bb, aa] = stmcb(h, nb, na);                          % NOTE: stmcb signature is (h, nb, na)
    if all(isfinite(bb)) && all(isfinite(aa)) && aa(1) ~= 0
        b = bb(:);  a = aa(:);  ok = true;
    end
catch
end
if ~ok, [b, a, ok] = prony_fit(h, na, nb); end
end

function [b, a, ok] = prony_fit(h, na, nb)
% PRONY'S METHOD: fit a discrete B(z)/A(z) (na denominator, nb numerator zeros) to impulse response h by
% LINEAR least squares -- pure algebra, no iteration, no simulation, cannot crash. Denominator from the
% shift equations  h[n] + a1 h[n-1] + ... + a_na h[n-na] = 0  (n = max(nb+1,na)..N-1); numerator from
% b[n] = h[n] + sum_k a_k h[n-k]  (n = 0..nb). Returns a=[1 a1..ana], b=[b0..bnb], ok=false if degenerate.
h = h(:);  N = numel(h);
a = [1; zeros(na,1)];  b = zeros(nb+1,1);  ok = false;
rows = max(nb+1, na) : (N-1);                            % 0-indexed equation rows
if numel(rows) < na, return; end
H = zeros(numel(rows), na);  y = zeros(numel(rows), 1);
for i = 1:numel(rows)
    n = rows(i);
    for k = 1:na, H(i,k) = h(n-k + 1); end               % h[n-k]  (MATLAB is 1-indexed)
    y(i) = -h(n + 1);                                    % -h[n]
end
if rcond(H.'*H + eps*eye(na)) < 1e-12, return; end       % degenerate normal equations -> reject cleanly
atail = H \ y;
if any(~isfinite(atail)), return; end
a = [1; atail];
for n = 0:nb
    acc = h(n + 1);
    for k = 1:min(n, na), acc = acc + a(k+1)*h(n-k + 1); end
    b(n+1) = acc;
end
ok = all(isfinite(b));
end

function h = sys_impulse(sys, nT, Ts)
% MEX-FREE unit-impulse response over nT samples. Replaces sim()/impulse() (which route through the
% crashing controllib sssim MEX). Handles the two model kinds in play:
%   - DISCRETE fit struct {b,a,ir}  -> its cached ir, else filter(b,a,impulse); pure recursion, cannot crash.
%   - CONTINUOUS best_sys (idtf/tf) -> partial-fraction (residue) sum of exp(pole*t); algebraic, cannot crash.
h = zeros(nT,1);
if isempty(sys), return; end
if isstruct(sys)
    if isfield(sys,'ir') && numel(sys.ir) >= nT, h = sys.ir(:); h = h(1:nT); return; end
    if isfield(sys,'b'),  h = filter(sys.b, sys.a, [1; zeros(nT-1,1)]);  return; end
    return;
end
% continuous LTI object -> impulse response via residues (no state-space sim)
try
    [num, den] = tfdata(sys, 'v');
    [rr, pp, kk] = residue(num, den);
    t = (0:nT-1).'*Ts;
    i = 1;
    while i <= numel(pp)
        m = 1;                                          % pole multiplicity (repeated poles -> t^j factors)
        while i+m <= numel(pp) && abs(pp(i+m)-pp(i)) < 1e-9*max(1,abs(pp(i))), m = m + 1; end
        for j = 0:m-1
            h = h + real( rr(i+j) * (t.^j / factorial(j)) .* exp(pp(i)*t) );
        end
        i = i + m;
    end
    if ~isempty(kk), h(1) = h(1) + sum(kk); end          % direct term at t=0 (strictly proper -> empty)
catch
    h = zeros(nT,1);
end
end

function [vaf, ch] = proto_vafch(sys, r, nT, Ts, nPreZ) %#ok<INUSD>
% shared: in-window VAF (%) + characteristics for a fitted sys ([] -> reject cleanly). MEX-free.
if isempty(sys), vaf = -100; ch = proto_chars([], Ts, nT); return; end
yhat = sys_impulse(sys, nT, Ts);
if any(~isfinite(yhat)), vaf = -100; ch = proto_chars([], Ts, nT); return; end   % blown-up fit -> reject
vaf = max(-100, 100*(1 - sum((r-yhat).^2)/max(sum((r-mean(r)).^2), eps)));        % floor so nulls stay finite
ch  = proto_chars(sys, Ts, nT);
end

function yhat = proto_sim(sys, nT, Ts, nPreZ) %#ok<INUSD>
% unit-impulse response over nT samples (post-onset window). MEX-free (see sys_impulse).
yhat = sys_impulse(sys, nT, Ts);
end

function ch = proto_chars(sys, Ts, nT)
% Characteristics from a fitted model's impulse response (MEX-free): trough time/depth, rebound peak/ratio,
% 5%-settle time. delay=0 (onset ref); slowTau left NaN (unused by the detector).
ch = struct('delayMs',0,'troughMs',NaN,'dip',NaN,'reboundMs',NaN, ...
            'reboundRatio',NaN,'settleMs',NaN,'slowTauMs',NaN);
if isempty(sys), return; end
yi = sys_impulse(sys, nT, Ts);
if any(~isfinite(yi)), return; end
tiMs = (0:nT-1).'*Ts*1000;
[dip, iTr] = min(yi);   ch.dip = dip;   ch.troughMs = tiMs(iTr);
if iTr < numel(yi)
    [reb, iRl] = max(yi(iTr:end));  ch.reboundMs = tiMs(iTr+iRl-1);
    ch.reboundRatio = max(reb,0) / max(abs(dip), eps);
else
    ch.reboundRatio = 0;
end
tol = 0.05*max(abs(yi));
lastEx = find(abs(yi) > tol, 1, 'last');
if ~isempty(lastEx), ch.settleMs = tiMs(lastEx); end
end

% [RETIRED 2026-07-18] native_project (the NATIVE KKT stim-blind projection helper) was removed together with
% §17b/§17bV -- SELECT (select_wlasso) is now the sole stim-blind fit, in both the main script and §18.

function statedep_click(fig, ~)
% [STATEDEP] click a scatter point in any of the 4 state panels -> that trial's actual/predicted ipsi
% (vs the amp-average) on top, its residual (vs amp-average residual) in the middle, and the trial's
% MOTION trace at the bottom (2026-08-05). Motion is on the panel because it is the state most likely to
% explain an outlier mechanically -- a running bout mid-window shows up here immediately, where the
% single pre-onset motion SCALAR on the scatter axis cannot show it. Panel is omitted if the session has
% no motion trace (AL_0048 before its Facemap output existed), rather than drawn empty.
SD = guidata(fig);  ax = get(fig,'CurrentAxes');
pidx = find(SD.axPanels==ax,1);  if isempty(pidx), return; end
cp = get(ax,'CurrentPoint');  xc = cp(1,1);  yc = cp(1,2);
x = SD.stateZ{pidx}(:);  y = SD.DVz(:);  m = isfinite(x)&isfinite(y);
xl = get(ax,'XLim');  yl = get(ax,'YLim');
d = ((x-xc)/max(diff(xl),eps)).^2 + ((y-yc)/max(diff(yl),eps)).^2;  d(~m) = inf;
[dm,k] = min(d);  if ~isfinite(dm), return; end
ai = SD.ampIdx(k);  tj = SD.trialIdx(k);
A = SD.trAll{ai};  YG = SD.ygAll{ai};  RL = SD.rlAll{ai};  tt = SD.tt;
dc = SD.dipCols;  ic = SD.inhCols{ai};  if ~isempty(ic), dc = ic; end
hasMot = isfield(SD,'motz') && ~isempty(SD.motz) && isfield(SD,'onF') && ~isempty(SD.onF{ai});
nRowP  = 2 + double(hasMot);
figure('Color','w','Name',sprintf('STATEDEP trial — %.2f V, trial %d',SD.amps(ai),tj),'Position',[220 140 660 240*nRowP]);
axa = subplot(nRowP,1,1);  hold(axa,'on');  box(axa,'on');
plot(axa,tt,mean(A,2), '-','Color',[.6 .6 .6],'LineWidth',1.2,'DisplayName','amp-avg actual');
plot(axa,tt,mean(YG,2),'-','Color',[.95 .62 .62],'LineWidth',1.2,'DisplayName','amp-avg pred');
plot(axa,tt,A(:,tj),  'k-','LineWidth',1.9,'DisplayName','actual (this trial)');
plot(axa,tt,YG(:,tj), '-','Color',[.85 .2 .2],'LineWidth',1.5,'DisplayName','stim-blind pred');
xline(axa,0,'k:'); yline(axa,0,'k:'); xlim(axa,[-.5 1]);  legend(axa,'Location','best','FontSize',7);
ylabel(axa,'ipsi \DeltaF/F %');
title(axa,sprintf('%s = %+.2f (z)   |   %.2f V, trial %d',regexprep(SD.stateName{pidx},'\\',''),SD.stateZ{pidx}(k),SD.amps(ai),tj),'FontWeight','bold');
axb = subplot(nRowP,1,2);  hold(axb,'on');  box(axb,'on');
plot(axb,tt,mean(RL,2),'-','Color',[.6 .75 1],'LineWidth',1.2,'DisplayName','amp-avg residual');
plot(axb,tt,RL(:,tj), '-','Color',[.1 .4 .85],'LineWidth',1.9,'DisplayName','residual (this trial)');
xline(axb,tt(dc(1)),'m:'); xline(axb,tt(dc(end)),'m:');
xline(axb,0,'k:'); yline(axb,0,'k:'); xlim(axb,[-.5 1]);  legend(axb,'Location','best','FontSize',7);
ylabel(axb,'residual \DeltaF/F %');
if ~hasMot, xlabel(axb,'t re onset (s)'); end

% --- MOTION for this trial, on the SAME peri-onset window as the traces above --------------------
if hasMot
    onF = SD.onF{ai};  nMz = numel(SD.motz);
    IDX = onF(:).' + SD.rel;                                   % [Wb x nT] frame indices, all trials
    okA = IDX >= 1 & IDX <= nMz;
    M = nan(size(IDX));  M(okA) = SD.motz(IDX(okA));           % out-of-range stays NaN, never clipped
    mavg = mean(M,2,'omitnan');  mtr = M(:,tj);
    axc = subplot(nRowP,1,3);  hold(axc,'on');  box(axc,'on');
    plot(axc,tt,mavg,'-','Color',[.65 .65 .65],'LineWidth',1.2,'DisplayName','amp-avg motion');
    plot(axc,tt,mtr, '-','Color',[.85 .45 .1],'LineWidth',1.9,'DisplayName','motion (this trial)');
    % shade the strictly pre-onset window the motion STATE scalar is measured over, so a within-window
    % running bout is visually separable from a genuinely high pre-stim baseline.
    yl2 = ylim(axc);
    patch(axc,[tt(1) tt(max(SD.preN,1)) tt(max(SD.preN,1)) tt(1)],[yl2(1) yl2(1) yl2(2) yl2(2)], ...
          [.92 .92 .82],'EdgeColor','none','FaceAlpha',0.55,'HandleVisibility','off');
    uistack(findobj(axc,'Type','patch'),'bottom');
    xline(axc,tt(dc(1)),'m:'); xline(axc,tt(dc(end)),'m:');
    xline(axc,0,'k:'); yline(axc,0,'k:'); xlim(axc,[-.5 1]);
    legend(axc,'Location','best','FontSize',7);
    xlabel(axc,'t re onset (s)');  ylabel(axc,'motion (z)');
    if isfinite(SD.stateZ{1}(k))
        title(axc,sprintf('motion state for this trial = %+.2f (z)   [shaded = pre-onset window it is measured over]', ...
              SD.stateZ{1}(k)),'FontSize',8,'FontWeight','normal');
    end
end
end

function S = local_stimblind_session(sel, cfg, allExperiments)
% HEADLESS reproduction of the minimal §2-§7,§10,§17d pipeline for ONE session, returning the
% PRIMARY SELECT stim-blind (Actual/Global/Local) decomposition. Mirrors the main-script math
% (site retarget, cached ROI, uniform eroded grid, spont train/test split, sparse distance-weighted
% far-from-ipsi lasso) but skips every interactive/diagnostic figure. Used by §18 to compare the
% local effect across sessions. Requires cached cp_stim_site_*.mat + cp_roi2_*.mat (no draw GUI).
mn = allExperiments(sel).mn;  td = allExperiments(sel).td;  en = allExperiments(sel).en;
label = sprintf('%s %s e%d', mn, td, en);
Fs = cfg.Fs;

% --- (2) SVD + session params ---------------------------------------------------------
y_full = allExperiments(sel).dF(:);  t_full = allExperiments(sel).timeBlue(:);
serverRoot = expPath(mn, td, en);
[U_cp, V_cp, ~, mimg_cp] = loadUVt(serverRoot, cfg.nSV_load);
[nY,nX] = size(mimg_cp);  nSV = size(U_cp,3);
d_tmp = loadData(serverRoot, mn, td, en);
py_prim = double(d_tmp.params.pixel(1));  px_prim = double(d_tmp.params.pixel(2));
k_prim = double(d_tmp.params.kernel);  clear d_tmp

% --- (3) data-derived site + retarget y_full ------------------------------------------
if cfg.USE_DATA_SITE
    site_file = fullfile(cfg.dataDir, sprintf('cp_stim_site_%s_%s%s_e%d.mat', mn, td(6:7), td(9:10), en));
    if exist(site_file,'file')
        SS = load(site_file);  stim_rc = double(SS.rowcol);
    else
        imp_v = allExperiments(sel).imp;  uA_v = allExperiments(sel).uAmp;
        [~,iMx] = max(uA_v);  sv = imp_v.startTimes{iMx}(:);
        onF = zeros(numel(sv),1);  for jv=1:numel(sv), [~,onF(jv)] = min(abs(t_full - sv(jv))); end
        st = cp_find_stim_site(U_cp, double(V_cp), mimg_cp, onF, 'fs', Fs);
        stim_rc = double(st.rowcol);  save(site_file,'-struct','st');
    end
    px_prim = stim_rc(1);  py_prim = stim_rc(2);
    kr = max(1,px_prim-k_prim):min(nY,px_prim+k_prim);
    kc = max(1,py_prim-k_prim):min(nX,py_prim+k_prim);
    [KR,KC] = ndgrid(kr,kc);  kidx = sub2ind([nY,nX],KR(:),KC(:));
    Ur = reshape(U_cp,nY*nX,nSV);  mI_st = mean(mimg_cp(kr,kc),'all');
    y_full = ((mean(Ur(kidx,:),1)*double(V_cp))/mI_st*100).';  clear Ur
end
nF_m = min(numel(y_full), size(V_cp,2));

% --- (4) contra mask (cache only) + stim onsets ---------------------------------------
roi_file = fullfile(cfg.dataDir, sprintf('cp_roi2_%s_%s%s_e%d.mat', mn, td(6:7), td(9:10), en));
if ~exist(roi_file,'file')
    error('[ALLSESS] missing ROI cache for %s:\n  %s\nDraw it once via contra_prediction.m S04.', label, roi_file);
end
M = cp_roi_masks(mimg_cp, roi_file, px_prim, py_prim, struct('redefine',false,'thr_pctile',20,'plot',false));
mask = logical(M.contra);
imp_data = allExperiments(sel).imp;  uAmp = allExperiments(sel).uAmp;
all_starts = [];
for ia = 1:numel(uAmp)
    if uAmp(ia) <= 0, continue; end
    all_starts = [all_starts; imp_data.startTimes{ia}(:)]; %#ok<AGROW>
end
all_starts = sort(all_starts);

% --- (5) uniform eroded grid over the contra mask -------------------------------------
[rC,cC] = find(mask);  rmn=min(rC); rmx=max(rC); cmn=min(cC); cmx=max(cC);
d = max(1, round(sqrt(nnz(mask)/cfg.nGrid)));  gridIdx = [];  ln = [];
for it = 1:12
    [GR,GC] = ndgrid(rmn:d:rmx, cmn:d:cmx);  ln = sub2ind([nY,nX],GR(:),GC(:));  ln = ln(mask(ln));
    if numel(ln) >= cfg.nGrid || d==1, gridIdx = ln; break; end
    d = max(1, d-1);
end
if isempty(gridIdx), gridIdx = ln; end
[grR,grC] = ind2sub([nY,nX], gridIdx);  em = cfg.edgeMargin;
keep = (grR>em) & (grR<=nY-em) & (grC>em) & (grC<=nX-em);
for g = find(keep(:).')
    blk = mask(grR(g)-em:grR(g)+em, grC(g)-em:grC(g)+em);
    if ~all(blk(:)), keep(g) = false; end
end
gridIdx = gridIdx(keep);  grR = grR(keep);  grC = grC(keep);  nG = numel(gridIdx);

% --- (6) spontaneous interstim frames + train/test split ------------------------------
ons = zeros(numel(all_starts),1);
for j = 1:numel(all_starts), [~,ons(j)] = min(abs(t_full - all_starts(j))); end
settle = round(cfg.settle_s*Fs);  frames = [];
for j = 1:numel(ons)
    i0 = ons(j) + settle;  if j<numel(ons), i1 = ons(j+1)-2; else, i1 = nF_m; end
    i0 = max(i0,1);  i1 = min(i1,nF_m);
    if i1 >= i0, frames = [frames, i0:i1]; end %#ok<AGROW>
end
frames = unique(frames);  frames = frames(isfinite(y_full(frames)'));
if numel(frames) > cfg.maxFrm, frames = frames(round(linspace(1,numel(frames),cfg.maxFrm))); end
nTr = floor(cfg.trainFrac*numel(frames));  itr = 1:nTr;  ite = nTr+1:numel(frames);

% --- (7) fixed z-scored contra design -------------------------------------------------
Uflat = reshape(U_cp, nY*nX, nSV);
Xg = double(Uflat(gridIdx,:)) * double(V_cp(:,frames));
mu_p = mean(Xg(:,itr),2);  sd_p = std(Xg(:,itr),0,2);  sd_p(sd_p==0) = 1;
Ztr = ((Xg(:,itr)-mu_p)./sd_p).';  Zte = ((Xg(:,ite)-mu_p)./sd_p).';
y_sp = double(y_full(frames));

% --- (10) per-amp peri-onset windows --------------------------------------------------
preN = round(cfg.bleed_preSec*Fs);  postN = round(cfg.bleed_postSec*Fs);  rel = (-preN:postN);  Wb = numel(rel);
nFall = size(V_cp,2);
amps = uAmp(uAmp>0);  nA = numel(amps);
onFcell = cell(nA,1);
for ai = 1:nA
    onFcell{ai} = local_onsets(imp_data.startTimes{find(uAmp==amps(ai),1)}(:), t_full, preN, postN, nFall);
end

% --- (10b) 0 V baseline onsets + evoked-excess arrays (mResp = amp - 0V), same as §10/§14 ---
% 0 V baseline onsets (or pseudo-catch from inter-trial gaps if no 0 V catch trials exist)
ia0 = find(uAmp==0,1);
if isempty(ia0)
    impF=zeros(numel(all_starts),1); for j=1:numel(all_starts), [~,impF(j)]=min(abs(t_full-all_starts(j))); end
    impF=sort(impF); mids=round((impF(1:end-1)+impF(2:end))/2);
    gapok=(impF(2:end)-impF(1:end-1))>(preN+postN+round(1.5*Fs));
    onF0=mids(gapok); onF0=onF0(onF0-preN>=1 & onF0+postN<=nFall);
else
    onF0=local_onsets(imp_data.startTimes{ia0}(:), t_full, preN, postN, nFall);
end
if numel(onF0)>500, onF0=onF0(round(linspace(1,numel(onF0),500))); end
nT0=numel(onF0);
mI_grid = double(mimg_cp(gridIdx));
Xpct = (double(Uflat(gridIdx,:)) * single(V_cp)) ./ single(mI_grid) * 100;   % %dF/F [nG x nFall]
[m0, blk0] = local_periavg(Xpct, onF0, rel, preN, nG, Wb);                    % 0 V baseline
mResp = nan(nG,Wb,nA);  nT_amp = zeros(nA,1);
for ai = 1:nA
    onF = onFcell{ai};  nT_amp(ai) = numel(onF);  if isempty(onF), continue; end
    mResp(:,:,ai) = local_periavg(Xpct, onF, rel, preN, nG, Wb) - m0;         % evoked excess re 0 V
end

% --- data-driven coupling window -> §14-style per-amp bled map bledA -------------------
ytrC = y_sp(itr);  yteC = y_sp(ite);  muYc = mean(ytrC);
Gc = Ztr.'*Ztr;  b_ols = Gc\(Ztr.'*(ytrC-muYc));
R2c = @(y,yh) 1 - sum((y-yh).^2)/max(sum((y-mean(y)).^2),eps);
r2_ols = R2c(yteC, muYc+Zte*b_ols);                          % full-grid spont ceiling (reference)
postCols=(preN+1):Wb;
idx0=onF0(:).'+rel(:); Z0=(double(Uflat(gridIdx,:))*double(V_cp(:,idx0(:)))-mu_p)./sd_p;
Z0=reshape(Z0,nG,Wb,nT0); Z0=Z0-mean(Z0(:,1:preN,:),2);
EVcell=cell(nA,1); cwEnd=zeros(nA,1);
for ai = 1:nA
    onF = onFcell{ai};  nT = numel(onF);  if nT==0, continue; end
    idx = onF(:).'+rel(:);
    Zp = (double(Uflat(gridIdx,:))*double(V_cp(:,idx(:)))-mu_p)./sd_p;
    ev = mean(reshape(Zp,nG,Wb,nT),3);  ev = ev - mean(ev(:,1:preN),2);  EVcell{ai}=ev;
    P=b_ols.'*ev; bd=nan(200,Wb);
    for b=1:200, ev0=mean(Z0(:,:,randi(nT0,nT,1)),3); bd(b,:)=abs(b_ols.'*ev0); end
    Pn=quantile(bd,0.95,1); sig=abs(P(postCols))>Pn(postCols); lk=find(sig,1,'last');
    if ~isempty(lk), cwEnd(ai)=rel(preN+lk)/Fs; end
end
couple_win_s=max([cwEnd;0]); if couple_win_s<=0, couple_win_s=cfg.dip_win_s; end
null_win_s=max(couple_win_s,cfg.dip_win_s);                 % floor to reporting dip window (see §14/§17b)
cplCols=(preN+1):min(Wb, preN+round(null_win_s*Fs));        % coupling window for the abs-energy bled test
bc_z_thr=1.28;                                              % match §14 (LOWER=more px dropped)
eDipA=squeeze(mean(abs(mResp(:,cplCols,:)),2));             % [nG x nA] abs coupling energy (|amp - 0V|)
bledA=false(nG,nA);
for ai=1:nA
    nT=nT_amp(ai); if nT==0, continue; end
    nd=nan(nG,300);
    for r=1:300, bb=blk0(:,:,randi(nT0,nT,1)); mb=mean(bb-mean(bb(:,1:preN,:),2),3)-m0; nd(:,r)=mean(abs(mb(:,cplCols)),2); end
    z=(eDipA(:,ai)-mean(nd,2))./max(std(nd,0,2),eps); bledA(:,ai)=z>bc_z_thr;
end

% --- (17d SELECT) per-amp SPARSE, DISTANCE-WEIGHTED stim-blind: FEW predictors, all FAR from ipsi --------
% Headless twin of §17d: for each amp keep the stim-UNAFFECTED pixels (~bledA) and fit the spont OLS with an
% L1 penalty that GROWS toward the ipsi site, so the surviving predictors are FEW and FAR from ipsi (least
% stim-contaminated). NO dip-blinding constraint -- the residual (Local) carries the dip only insofar as
% those distal predictors are genuinely stim-blind, so G_dip here is an HONEST LEAK, not ~0 by construction.
% (Replaces the retired NATIVE KKT twin, 2026-07-18 -- see §17a.)
% Distance is taken in ARRAY coords: the display orientation is an isometry, so the metric is unchanged.
dipCols=(preN+1):min(Wb, preN+round(cfg.dip_win_s*Fs));
ytr=y_sp(itr); yte=y_sp(ite); sstot=max(sum((yte-mean(yte)).^2),eps);
Gz=Gc; ytrc=ytr-muYc; cz=Ztr.'*ytrc;                                     % shared spont OLS operators (z-space)
selRidge_ = 0; if isfield(cfg,'select_ridge'), selRidge_ = cfg.select_ridge; end
lamSel = max(1e-6, selRidge_)*mean(diag(Gz));                            % SELECT's weighted-L2 (mirrors §17d)
selD  = hypot(grC(:)-py_prim, grR(:)-px_prim);                          % each contra px -> ipsi stim site
selDn = (selD-min(selD))/max(max(selD)-min(selD),eps);                  % normalize distance to [0,1]
gammaS = 1./(cfg.select_penNear*(1-selDn) + cfg.select_penFar*selDn);   % lasso column gains (LARGE far, small near)
A_dip=nan(nA,1); G_dip=nan(nA,1); L_dip=nan(nA,1); r2clean=nan(nA,1); nDrop=zeros(nA,1); nActA=zeros(nA,1);
trA=cell(nA,1); trG=cell(nA,1); trL=cell(nA,1); cleanMaskA=false(nG,nA); bCleanA=cell(nA,1);
for ai=1:nA
    onF=onFcell{ai}; nT=numel(onF); if nT==0 || isempty(EVcell{ai}), continue; end
    active=~bledA(:,ai); if nnz(active)<5, active=true(nG,1); end        % keep stim-UNAFFECTED px
    cleanMaskA(:,ai)=active; nDrop(ai)=nnz(~active);
    Sset=find(active);
    idx=onF(:).'+rel(:);
    ya=mean(reshape(double(y_full(idx(:))),Wb,nT),2); ya=ya-mean(ya(1:preN));
    bfull = select_wlasso(Gz, cz, Sset, gammaS, cfg.select_l1frac, lamSel); % far-from-ipsi weighted fit (DENSE by default)
    nActA(ai)=nnz(bfull);  bCleanA{ai}=bfull;
    yg=(bfull.'*EVcell{ai}).'; yg=yg-mean(yg(1:preN));                   % Global = sparse distal prediction
    rL=ya-yg;                                                            % Local  = residual (carries the dip)
    r2clean(ai)=1 - sum((yte-(muYc+Zte*bfull)).^2)/sstot;                % held-out spont R^2 of these weights
    trA{ai}=ya(:); trG{ai}=yg(:); trL{ai}=rL(:);
    A_dip(ai)=mean(ya(dipCols)); G_dip(ai)=mean(yg(dipCols)); L_dip(ai)=mean(rL(dipCols));
end
medLocalPct=median(100*L_dip./A_dip,'omitnan');
% orient the brain map + grid/site the same way the main script does (session-safe display)
Tor = pick_orient(logical(M.contra), logical(M.ipsi), px_prim, py_prim, nY, nX, ...
                  get_ant_rc(allExperiments(sel)));
[gdR,gdC] = orient_fwd(Tor, grR, grC);  [sdR,sdC] = orient_fwd(Tor, px_prim, py_prim);
oiB = Tor.imgOp(mimg_cp);  gimg = (oiB-min(oiB(:)))/max(max(oiB(:))-min(oiB(:)),eps);
BC = struct('mResp',mResp,'blk0',blk0,'m0',m0,'nT_amp',nT_amp,'nT0',nT0, ...
            'grR',grR,'grC',grC,'gdR',gdR,'gdC',gdC,'gridIdx',gridIdx, ...
            'site',[px_prim py_prim],'sdR',sdR,'sdC',sdC, ...
            'gimg',gimg,'amps',amps,'nA',nA,'nG',nG,'rel',rel,'Fs',Fs,'preN',preN,'Wb',Wb, ...
            'couple_win_s',couple_win_s,'null_win_s',null_win_s,'dip_win_s',cfg.dip_win_s);

% --- PER-TRIAL state-dependence payload (same engine as the interactive §17c) -------------------
% §18 previously returned only per-amp TRIAL AVERAGES, which is exactly the information the state
% test does NOT use -- the state statistic lives in the trial-to-trial spread AROUND the amp mean.
% Calling utils/imp_statedep_trials here (the identical function §17c calls) is what makes the
% 3-session state comparison possible without a human at the keyboard for each session.
motz_s = local_session_motion(sel, allExperiments, serverRoot, mn, td, en);
ST = imp_statedep_trials(struct('Uflat',Uflat,'gridIdx',gridIdx,'V',V_cp,'mu_p',mu_p,'sd_p',sd_p, ...
        'y_full',y_full,'nF',numel(y_full),'onFcell',{onFcell},'bUse',{bCleanA},'dipCols',dipCols, ...
        'rel',rel,'preN',preN,'Wb',Wb,'Fs',Fs,'amps',amps,'motz',motz_s,'wantTraces',false));
fprintf('   [ST] %-24s %d trials | motion %s\n', label, numel(ST.LD), ...
        ternstr(any(isfinite(ST.MOT)), sprintf('OK (%d finite)',nnz(isfinite(ST.MOT))), 'UNAVAILABLE -> NaN'));

S = struct('label',label,'sel',sel,'amps',amps,'Actual',A_dip,'Global',G_dip,'Local',L_dip,'BC',BC, ...
           'trA',{trA},'trG',{trG},'trL',{trL},'rel',rel,'Fs',Fs,'preN',preN, ...
           'r2_ols',r2_ols,'r2clean',r2clean,'nDrop',nDrop,'nActive',nActA,'medLocalPct',medLocalPct,'nG',nG, ...
           'bledA',bledA,'cleanMaskA',cleanMaskA,'bCleanA',{bCleanA}, ...
           'couple_win_s',couple_win_s,'null_win_s',null_win_s,'ST',ST);
end

function motz = local_session_motion(sel, allExperiments, serverRoot, mn, td, en)
% Session motion trace, z-scored at blue cadence. Prefers the trace the loader already attached
% (`mv_z`, e.g. load_bilateral_impulse for Signals sessions where loadData cannot open the folder);
% falls back to loadData's motion.motion_1 for the original controller-rig sessions. Returns []
% when neither is available -- imp_statedep_trials then leaves MOT as NaN rather than guessing.
motz = [];
if isfield(allExperiments,'mv_z') && ~isempty(allExperiments(sel).mv_z) && ...
        any(isfinite(allExperiments(sel).mv_z))
    motz = double(allExperiments(sel).mv_z(:));  return
end
try
    dM = loadData(serverRoot, mn, td, en);
    if isfield(dM,'motion') && isfield(dM.motion,'motion_1')
        m = double(dM.motion.motion_1(1:2:end));
        motz = (m - mean(m,'omitnan'))/max(std(m,'omitnan'), eps);
    end
catch
    % leave empty -> Motion column NaN, reported by the caller
end
end

function bleed_detail(DB, p, ai)
% VERIFIER: is the flagged response at this (possibly far) pixel actually PRESENT, or noise?
% Left-top : per-trial peri-stim traces for this amp (thin) + amp trial-avg + 0V trial-avg.
% Left-bot : excess = amp-avg - 0V-avg, with the 0V null(95%) band and the evoked peak.
% Right    : brain, this pixel (red), site (green+), all pixels flagged AT THIS AMP (black),
%            and the pixel's DISTANCE from the site (px) — so you can judge "far but real".
tt = DB.rel/DB.Fs;  preN = DB.preN;
trA = local_pixtrials(DB.Xpct, p, DB.onFcell{ai}, DB.rel, preN);   % [nT  x Wb] amp trials (pre-baselined)
tr0 = local_pixtrials(DB.Xpct, p, DB.onF0,        DB.rel, preN);   % [nT0 x Wb] 0V trials
mA = mean(trA,1);  m0 = mean(tr0,1);                               % trial averages
m  = squeeze(DB.mResp(p,:,ai));  thr = DB.nullThr(p,ai);           % excess (=mA-m0) + null
[pk,pj] = max(abs(m(DB.postCols)));  jj = DB.postCols(pj);
dist = hypot(DB.grR(p)-DB.site(1), DB.grC(p)-DB.site(2));
lab = {'not flagged','STIM-AFFECTED (black)'};
figure('Color','w','Name',sprintf('BLEED verify px #%d, amp %.2f V',p,DB.amps(ai)), ...
    'Units','pixels','Position',[300 150 1040 520]);

ax1 = subplot(2,2,1); hold(ax1,'on');                             % raw response vs 0V
plot(ax1, tt, trA.', '-', 'Color',[0.7 0.7 0.7 0.5], 'LineWidth',0.3, 'HandleVisibility','off');
plot(ax1, tt, mA, 'k-', 'LineWidth',1.8, 'DisplayName',sprintf('amp avg (n=%d)',size(trA,1)));
plot(ax1, tt, m0, '-', 'Color',[0.1 0.3 0.9], 'LineWidth',1.4, 'DisplayName',sprintf('0V avg (n=%d)',size(tr0,1)));
xline(ax1, 0, 'k:', 'HandleVisibility','off');
set(ax1,'Box','off','TickDir','out','FontSize',10);  xlim(ax1,[tt(1) tt(end)]);
ylabel(ax1,'\DeltaF/F (%)','FontWeight','bold');  title(ax1,'per-trial response vs 0V','FontSize',10,'FontWeight','bold');
legend(ax1,'Location','best','Box','off','FontSize',8);

ax2 = subplot(2,2,3); hold(ax2,'on');                             % excess + null band
fill(ax2, [tt fliplr(tt)], [thr+0*tt, -thr+0*tt], [1 0.85 0.85], 'EdgeColor','none', 'HandleVisibility','off');
plot(ax2, tt, m, 'k-', 'LineWidth',1.8, 'DisplayName','amp - 0V');
plot(ax2, tt(jj), m(jj), 'bo', 'MarkerFaceColor','b', 'DisplayName','evoked peak');
yline(ax2, thr, 'r--', 'DisplayName','0V null 95%');  yline(ax2, -thr, 'r--', 'HandleVisibility','off');
xline(ax2, 0, 'k:', 'HandleVisibility','off');
set(ax2,'Box','off','TickDir','out','FontSize',10);  xlim(ax2,[tt(1) tt(end)]);
xlabel(ax2,'time re onset (s)','FontWeight','bold');  ylabel(ax2,'excess re 0V (%)','FontWeight','bold');
title(ax2, sprintf('peak=%.3f  null95=%.3f  ->  %s', pk, thr, lab{DB.affected(p,ai)+1}), 'FontSize',10,'FontWeight','bold');
legend(ax2,'Location','best','Box','off','FontSize',8);

ax3 = subplot(2,2,[2 4]); hold(ax3,'on');                         % spatial context
image(ax3, repmat(DB.gimg,[1 1 3]));  axis(ax3,'image','off');  set(ax3,'YDir','reverse');
affA = DB.affected(:,ai);
scatter(ax3, DB.gdC(~affA), DB.gdR(~affA), 10, [0.7 0.7 0.7], 'filled', 'MarkerEdgeColor',[0.4 0.4 0.4], 'LineWidth',0.2);
scatter(ax3, DB.gdC(affA),  DB.gdR(affA),  16, 'k', 'filled');
plot(ax3, DB.sdC, DB.sdR, 'g+', 'MarkerSize',14, 'LineWidth',2);
plot(ax3, [DB.sdC DB.gdC(p)], [DB.sdR DB.gdR(p)], 'r-', 'LineWidth',0.8);
scatter(ax3, DB.gdC(p), DB.gdR(p), 70, 'r', 'filled', 'MarkerEdgeColor','k', 'LineWidth',1);
title(ax3, sprintf('px #%d  |  %.0f px from site  |  %.2f V (n=%d) vs 0V (n=%d)', ...
    p, dist, DB.amps(ai), DB.nT_amp(ai), DB.nT0), 'FontSize',10,'FontWeight','bold');
end

function tr = local_pixtrials(Xpct, p, onF, rel, preN)
% Single-pixel peri-onset traces [nTrials x Wb], each pre-window baseline-subtracted.
if isempty(onF), tr = zeros(0,numel(rel)); return; end
idx = onF(:) + rel(:).';                                          % [nT x Wb] frame indices
tr = double(reshape(Xpct(p, idx(:)), size(idx)));                 % [nT x Wb]
tr = tr - mean(tr(:,1:preN),2);                                   % baseline each trial
end

function bleedchar_click(figBC, ~)
% Click a pixel on the BLEEDCHAR map -> open its full per-amplitude bleed report.
BC = guidata(figBC);
cp = BC.axMap.CurrentPoint;  x = cp(1,1);  y = cp(1,2);          % x=display col, y=display row
xl = BC.axMap.XLim;  yl = BC.axMap.YLim;
if x<xl(1)||x>xl(2)||y<yl(1)||y>yl(2), return; end
[~,p] = min((BC.gdC - x).^2 + (BC.gdR - y).^2);
bleedchar_detail(BC, p);
end

function bleedchar_detail(BC, p)
% Full auditable report for ONE pixel: exactly why it is / isn't called bled at each amplitude.
tt = BC.rel/BC.Fs;  dc = BC.dipCols;  amps = BC.amps(:);  nA = BC.nA;
z = BC.zA(p,:).';  e = BC.eDipA(p,:).';  mu = BC.mu0A(p,:).';  sd = BC.sd0A(p,:).';
bled = z > BC.z_thr;  dist = hypot(BC.grR(p)-BC.site(1), BC.grC(p)-BC.site(2));
cmap = parula(nA);
figure('Color','w','Name',sprintf('BLEEDCHAR report — pixel #%d',p), ...
    'Units','pixels','Position',[280 130 1120 460]);

ax1 = subplot(1,3,1); hold(ax1,'on');                           % evoked excess traces, all amps
for ai = 1:nA
    plot(ax1, tt, squeeze(BC.mResp(p,:,ai)), '-', 'Color',cmap(ai,:), 'LineWidth',1.3, ...
        'DisplayName',sprintf('%.1fV%s',amps(ai),ternchar(bled(ai),' *','')));
end
yl = ylim(ax1);  patch(ax1, tt([dc(1) dc(end) dc(end) dc(1)]), [yl(1) yl(1) yl(2) yl(2)], ...
    [0.9 0.9 0.6], 'FaceAlpha',0.25, 'EdgeColor','none', 'HandleVisibility','off');
xline(ax1,0,'k:','HandleVisibility','off');  yline(ax1,0,'k:','HandleVisibility','off');
set(ax1,'Box','off','TickDir','out','FontSize',9);  xlim(ax1,[tt(1) tt(end)]);
xlabel(ax1,'time re onset (s)','FontWeight','bold');  ylabel(ax1,'excess re 0V (%)','FontWeight','bold');
title(ax1,'evoked traces (shaded = coupling window)','FontSize',9,'FontWeight','bold');
lg=legend(ax1,'Location','best','Box','off','FontSize',7); lg.ItemTokenSize=[10 10];

ax2 = subplot(1,3,2); hold(ax2,'on');                           % z vs amplitude + threshold
plot(ax2, amps, z, '-o', 'Color',[0.2 0.2 0.2], 'MarkerFaceColor',[0.2 0.2 0.2], 'LineWidth',1.5);
scatter(ax2, amps(bled), z(bled), 60, 'r', 'filled', 'DisplayName','bled');
yline(ax2,  BC.z_thr, 'r--');  yline(ax2,0,'k:');
set(ax2,'Box','off','TickDir','out','FontSize',9);
xlabel(ax2,'amplitude (V)','FontWeight','bold');  ylabel(ax2,'z (coupling energy vs 0V)','FontWeight','bold');
title(ax2, sprintf('z vs amp  (z>%.2f = bled)  slope=%.2f/V', BC.z_thr, BC.slopeA(p)), 'FontSize',9,'FontWeight','bold');

ax3 = subplot(1,3,3); hold(ax3,'on');                           % raw dip energy vs 0V null band
fill(ax3, [amps; flipud(amps)], [mu+2*sd; flipud(mu-2*sd)], [1 0.85 0.85], 'EdgeColor','none', 'DisplayName','0V null \pm2SD');
plot(ax3, amps, mu, 'r--', 'DisplayName','0V null mean');
plot(ax3, amps, e, '-o', 'Color',[0 0 0], 'MarkerFaceColor','k', 'LineWidth',1.5, 'DisplayName','coupling energy');
scatter(ax3, amps(bled), e(bled), 60, 'r', 'filled', 'HandleVisibility','off');
set(ax3,'Box','off','TickDir','out','FontSize',9);
xlabel(ax3,'amplitude (V)','FontWeight','bold');  ylabel(ax3,'|coupling| energy (%)','FontWeight','bold');
title(ax3,'evoked vs 0V null','FontSize',9,'FontWeight','bold');
lg3=legend(ax3,'Location','best','Box','off','FontSize',7); lg3.ItemTokenSize=[10 10];

sgtitle(sprintf('pixel #%d  |  %.0f px from site  |  bled at %d/%d amps: [%s]', ...
    p, dist, nnz(bled), nA, strtrim(sprintf('%.1f ',amps(bled)))), 'FontSize',11,'FontWeight','bold');
end

function s = ternchar(cond, a, b)
if cond, s = a; else, s = b; end
end

function local_bleedchar_session(BC, label, bc_z_thr, bc_nRand)
% HEADLESS §14 BLEEDCHAR for a non-main session (AL_0041 e1/e2): classify each grid pixel at each
% amplitude by ABSOLUTE evoked coupling energy over the session null window, exactly as the main
% §13/§14 (biphasic-safe, one-sided z). Produces (1) per-amp "definitely stim-affected" maps and
% (2) a z-matrix + #amps-bled clickable map (same bleedchar_click/bleedchar_detail report as §14).
mResp=BC.mResp; nG=BC.nG; nA=BC.nA; amps=BC.amps(:); preN=BC.preN; Wb=BC.Wb; Fs=BC.Fs;
cplCols=(preN+1):min(Wb, preN+round(BC.null_win_s*Fs));          % coupling/null window (>= dip_win_s)
eDipA=squeeze(mean(abs(mResp(:,cplCols,:)),2));                   % [nG x nA] ABS coupling energy
mu0A=zeros(nG,nA); sd0A=ones(nG,nA);
for ai=1:nA
    nT=BC.nT_amp(ai); if nT==0, continue; end
    nd=nan(nG,bc_nRand);
    for r=1:bc_nRand
        bb=BC.blk0(:,:, randi(BC.nT0, nT, 1));
        mb=mean(bb - mean(bb(:,1:preN,:),2), 3) - BC.m0;
        nd(:,r)=mean(abs(mb(:,cplCols)),2);
    end
    mu0A(:,ai)=mean(nd,2); sd0A(:,ai)=std(nd,0,2);
end
zA=(eDipA-mu0A)./max(sd0A,eps);  bledA=zA>bc_z_thr;              % one-sided (energy excess)
distBC=hypot(BC.grR-BC.site(1), BC.grC-BC.site(2));  nBledAmp=sum(bledA,2);
ampv=amps; Afit=[ones(nA,1) ampv]; slopeA=zeros(nG,1);
for p=1:nG, cc=Afit\abs(zA(p,:)).'; slopeA(p)=cc(2); end
fprintf('   [BLEEDCHAR %s] %.0f ms null window, per-amp bled (z>%.2f): ', label, 1000*BC.null_win_s, bc_z_thr);
for ai=1:nA, fprintf('%.1fV:%d ', amps(ai), nnz(bledA(:,ai))); end;  fprintf('\n');

% (1) per-amp black maps ---------------------------------------------------------------
nc=min(nA,3); nr=ceil(nA/nc);
figM=figure('Color','w','Name',sprintf('[ALLSESS BLEEDCHAR] per-amp affected — %s',label), ...
            'Position',[90 70 380*nc 300*nr]);
for ai=1:nA
    ax=subplot(nr,nc,ai,'Parent',figM); hold(ax,'on');
    image(ax, repmat(BC.gimg,[1 1 3])); axis(ax,'image','off'); set(ax,'YDir','reverse');
    aff=bledA(:,ai);
    scatter(ax, BC.gdC(~aff), BC.gdR(~aff), 12, [0.75 0.75 0.75],'filled','MarkerEdgeColor',[0.4 0.4 0.4],'LineWidth',0.2);
    scatter(ax, BC.gdC(aff),  BC.gdR(aff),  20, 'k','filled','MarkerEdgeColor','k');
    plot(ax, BC.sdC, BC.sdR, 'r+','MarkerSize',12,'LineWidth',1.6);
    title(ax, sprintf('%.2f V   %d/%d bled', amps(ai), nnz(aff), nG),'FontSize',11,'FontWeight','bold');
end
sgtitle(figM, sprintf('Bleed-affected contra px (black) — %s  (|coupling| energy over %.0f ms)', ...
        label, 1000*BC.null_win_s),'FontSize',12,'FontWeight','bold');

% (2) z-matrix + clickable #amps map ---------------------------------------------------
[~,sdi]=sort(distBC,'ascend');
figBC=figure('Color','w','Name',sprintf('[ALLSESS BLEEDCHAR] z-matrix — %s',label),'Position',[120 90 1180 620]);
axMat=subplot(1,2,1,'Parent',figBC);
imagesc(axMat,1:nA,1:nG,zA(sdi,:)); set(axMat,'YDir','normal');
zmx=max(abs(zA(:)))+eps; clim(axMat,[-zmx zmx]);
sM=linspace(0,1,128)'; colormap(axMat,[[sM sM ones(128,1)];[ones(128,1) 1-sM 1-sM]]);
cb1=colorbar(axMat,'eastoutside'); cb1.Label.String='z (coupling energy vs 0V)';
set(axMat,'XTick',1:nA,'XTickLabel',compose('%.1f',amps),'FontSize',9);
xlabel(axMat,'amplitude (V)','FontWeight','bold'); ylabel(axMat,'grid pixel (near\rightarrowfar)','FontWeight','bold');
title(axMat,'z-score matrix','FontSize',10,'FontWeight','bold');
axMap=subplot(1,2,2,'Parent',figBC); hold(axMap,'on');
image(axMap, repmat(BC.gimg,[1 1 3])); axis(axMap,'image','off'); set(axMap,'YDir','reverse');
scMap=scatter(axMap, BC.gdC, BC.gdR, 28, nBledAmp,'filled','MarkerEdgeColor',[0.25 0.25 0.25],'LineWidth',0.3);
colormap(axMap, parula(max(nA+1,2))); clim(axMap,[0 nA]);
cb2=colorbar(axMap,'eastoutside'); cb2.Label.String='# amplitudes bled';
plot(axMap, BC.sdC, BC.sdR,'g+','MarkerSize',14,'LineWidth',2);
title(axMap,'# amps each pixel is bled at  (click \rightarrow report)','FontSize',10,'FontWeight','bold');
sgtitle(figBC, sprintf('BLEEDCHAR — %s',label),'FontSize',11,'FontWeight','bold');
BCg=struct('axMap',axMap,'scMap',scMap,'grR',BC.grR,'grC',BC.grC,'gdR',BC.gdR,'gdC',BC.gdC,'nG',nG,'amps',amps,'nA',nA, ...
           'mResp',mResp,'rel',BC.rel,'Fs',Fs,'preN',preN,'dipCols',cplCols, ...
           'eDipA',eDipA,'mu0A',mu0A,'sd0A',sd0A,'zA',zA,'bledA',bledA,'slopeA',slopeA, ...
           'z_thr',bc_z_thr,'dist',distBC,'site',BC.site);
guidata(figBC, BCg); set(figBC,'WindowButtonDownFcn',@bleedchar_click);
end

% ---------------- §20 SESSION-VIEWER: loader + orientation-normalized interactive map --------
function [D, px_prim, py_prim, contra_mask, ipsi_mask] = local_load_session(sel, cfg, allExperiments)
% HEADLESS load of ONE session into a fit-ready struct D (same fields §7 packs), plus the site
% and the contra/ipsi masks. Mirrors §2-§7 exactly; requires cached site + ROI (no draw GUI).
mn=allExperiments(sel).mn; td=allExperiments(sel).td; en=allExperiments(sel).en;
y_full=allExperiments(sel).dF(:); t_full=allExperiments(sel).timeBlue(:);
serverRoot=expPath(mn,td,en);
[U_cp,V_cp,~,mimg_cp]=loadUVt(serverRoot,cfg.nSV_load);
[nY,nX]=size(mimg_cp); nSV=size(U_cp,3);
d_tmp=loadData(serverRoot,mn,td,en);
py_prim=double(d_tmp.params.pixel(1)); px_prim=double(d_tmp.params.pixel(2)); k_prim=double(d_tmp.params.kernel); clear d_tmp
if cfg.USE_DATA_SITE
    sf=fullfile(cfg.dataDir,sprintf('cp_stim_site_%s_%s%s_e%d.mat',mn,td(6:7),td(9:10),en));
    if exist(sf,'file'), SS=load(sf); stim_rc=double(SS.rowcol);
    else
        imp_v=allExperiments(sel).imp; uA_v=allExperiments(sel).uAmp; [~,iMx]=max(uA_v); sv=imp_v.startTimes{iMx}(:);
        onF=zeros(numel(sv),1); for jv=1:numel(sv), [~,onF(jv)]=min(abs(t_full-sv(jv))); end
        st=cp_find_stim_site(U_cp,double(V_cp),mimg_cp,onF,'fs',cfg.Fs); stim_rc=double(st.rowcol); save(sf,'-struct','st');
    end
    px_prim=stim_rc(1); py_prim=stim_rc(2);
    kr=max(1,px_prim-k_prim):min(nY,px_prim+k_prim); kc=max(1,py_prim-k_prim):min(nX,py_prim+k_prim);
    [KR,KC]=ndgrid(kr,kc); kidx=sub2ind([nY,nX],KR(:),KC(:));
    Ur=reshape(U_cp,nY*nX,nSV); mI_st=mean(mimg_cp(kr,kc),'all');
    y_full=((mean(Ur(kidx,:),1)*double(V_cp))/mI_st*100).'; clear Ur
end
nF_m=min(numel(y_full),size(V_cp,2));
rf=fullfile(cfg.dataDir,sprintf('cp_roi2_%s_%s%s_e%d.mat',mn,td(6:7),td(9:10),en));
if ~exist(rf,'file'), error('[VIEWER] missing ROI cache for %s %s e%d:\n  %s',mn,td,en,rf); end
M=cp_roi_masks(mimg_cp,rf,px_prim,py_prim,struct('redefine',false,'thr_pctile',20,'plot',false));
contra_mask=logical(M.contra); ipsi_mask=logical(M.ipsi);
imp_data=allExperiments(sel).imp; uAmp=allExperiments(sel).uAmp; all_starts=[];
for ia=1:numel(uAmp), if uAmp(ia)<=0, continue; end; all_starts=[all_starts; imp_data.startTimes{ia}(:)]; end
all_starts=sort(all_starts);
% grid
mask=contra_mask; [rC,cC]=find(mask); rmn=min(rC);rmx=max(rC);cmn=min(cC);cmx=max(cC);
dd=max(1,round(sqrt(nnz(mask)/cfg.nGrid))); gridIdx=[]; ln=[];
for it=1:12
    [GR,GC]=ndgrid(rmn:dd:rmx,cmn:dd:cmx); ln=sub2ind([nY,nX],GR(:),GC(:)); ln=ln(mask(ln));
    if numel(ln)>=cfg.nGrid||dd==1, gridIdx=ln; break; end
    dd=max(1,dd-1);
end
if isempty(gridIdx), gridIdx=ln; end
[grR,grC]=ind2sub([nY,nX],gridIdx); em=cfg.edgeMargin;
keep=(grR>em)&(grR<=nY-em)&(grC>em)&(grC<=nX-em);
for g=find(keep(:).'), blk=mask(grR(g)-em:grR(g)+em,grC(g)-em:grC(g)+em); if ~all(blk(:)), keep(g)=false; end; end
gridIdx=gridIdx(keep); grR=grR(keep); grC=grC(keep); nG=numel(gridIdx);
% spont frames + split
ons=zeros(numel(all_starts),1); for j=1:numel(all_starts), [~,ons(j)]=min(abs(t_full-all_starts(j))); end
settle=round(cfg.settle_s*cfg.Fs); frames=[];
for j=1:numel(ons)
    i0=ons(j)+settle; if j<numel(ons), i1=ons(j+1)-2; else, i1=nF_m; end
    i0=max(i0,1); i1=min(i1,nF_m); if i1>=i0, frames=[frames, i0:i1]; end
end
frames=unique(frames); frames=frames(isfinite(y_full(frames)'));
if numel(frames)>cfg.maxFrm, frames=frames(round(linspace(1,numel(frames),cfg.maxFrm))); end
nTr=floor(cfg.trainFrac*numel(frames)); itr=1:nTr; ite=nTr+1:numel(frames);
% design + fit operator
Uflat=reshape(U_cp,nY*nX,nSV);
Xg=double(Uflat(gridIdx,:))*double(V_cp(:,frames));
mu_p=mean(Xg(:,itr),2); sd_p=std(Xg(:,itr),0,2); sd_p(sd_p==0)=1;
Ztr=((Xg(:,itr)-mu_p)./sd_p).'; Zte=((Xg(:,ite)-mu_p)./sd_p).'; Ate=[ones(numel(ite),1) Zte];
D=struct(); D.fit_mode=lower(cfg.fit_mode);
switch D.fit_mode
    case 'lasso', D.Ztr=Ztr; D.G=Ztr.'*Ztr; D.Gdiag=diag(D.G); D.l1_frac=cfg.l1_frac; D.ridge=cfg.ridge;
    case 'ridge', Atr=[ones(numel(itr),1) Ztr]; Rg=cfg.ridge*eye(nG+1); Rg(1,1)=0; D.fitOp=(Atr.'*Atr+Rg)\Atr.';
    otherwise,    Atr=[ones(numel(itr),1) Ztr]; [Qa,Ra]=qr(Atr,0); D.fitOp=@(yv) Ra\(Qa.'*yv);
end
D.debias=cfg.debias; D.Uflat=Uflat; D.V=V_cp; D.frames=frames; D.itr=itr; D.ite=ite;
D.mu_p=mu_p; D.sd_p=sd_p; D.Ate=Ate; D.grR=grR; D.grC=grC; D.gridIdx=gridIdx;
D.nY=nY; D.nX=nX; D.mimg=mimg_cp; D.k=k_prim; D.Fs=cfg.Fs; D.ipsi=ipsi_mask;
end

function T = make_orient(imgOp, H, W)
% Build a dihedral display transform from an image op (rot90/flip combo). All maps are computed
% NUMERICALLY by transforming index images, so fwd/inv are exact for ANY imgOp (no hand algebra).
T.imgOp=imgOp; T.H=H; T.W=W;
T.invRow=imgOp(repmat((1:H)',1,W));           % display (rd,cd) -> original row
T.invCol=imgOp(repmat((1:W),H,1));            % display (rd,cd) -> original col
[T.Hd,T.Wd]=size(T.invRow);
lin=imgOp(reshape(1:H*W,[H W]));              % display pos -> original linear index
T.posOfOrig=zeros(H*W,1); T.posOfOrig(lin(:))=(1:numel(lin))';   % original linear -> display pos
end

function T = resolve_orient(knob, contra, ipsi, siteRow, siteCol, H, W, antRC)
% Turn the disp_orient knob into a display transform. 'auto' auto-normalizes via pick_orient;
% every other value is a FIXED dihedral view. make_orient builds fwd/inv numerically for any op,
% so overlay + click-inverse stay consistent regardless of the choice (display-only).
% antRC (optional): [dRow dCol] in NATIVE image coords pointing ANTERIOR (from the session's
% bregma registration). When given it replaces the site-below tiebreaker -- see pick_orient.
if nargin < 8, antRC = []; end
switch lower(knob)
    case 'auto',      T = pick_orient(contra, ipsi, siteRow, siteCol, H, W, antRC);
    case 'native',    T = make_orient(@(A)A, H, W);
    case 'transpose', T = make_orient(@(A)A.', H, W);
    case 'rot90',     T = make_orient(@(A)rot90(A,1), H, W);
    case 'rot180',    T = make_orient(@(A)rot90(A,2), H, W);
    case 'rot270',    T = make_orient(@(A)rot90(A,3), H, W);
    case 'fliplr',    T = make_orient(@(A)fliplr(A), H, W);
    case 'flipud',    T = make_orient(@(A)flipud(A), H, W);
    otherwise, error('resolve_orient: unknown disp_orient ''%s''', knob);
end
end

function T = pick_orient(contra, ipsi, siteRow, siteCol, H, W, antRC)
% Choose the dihedral view (of 8) that (1) puts IPSI rightmost with a VERTICAL midline
% (contra/ipsi separated horizontally), then (2) breaks the residual up/down flip so the view is
% the conventional dorsal one (ANTERIOR UP). Term (1) dominates (x1000); term (2) is the
% tiebreaker between the two views that both satisfy (1) (they differ only by flipud).
%
% Term (2) has two forms:
%   antRC given  -- [dRow dCol] pointing ANTERIOR in NATIVE coords, from the session's bregma
%                   registration. Score the view in which that vector points UP (display row
%                   DECREASING). This is the correct, anatomy-anchored rule.
%   antRC empty  -- legacy fallback: put the SITE in the LOWER half (site below the brain
%                   centroid). This was written for AL_0033, whose stim site is POSTERIOR, and it
%                   silently FLIPS any session whose site is anterior (AL_0048's inhibitory
%                   readout sits 2.6 mm anterior of the spot -> whole session displayed upside
%                   down). Kept only so the AL_0033/AL_0041 displays are bit-identical to before.
if nargin < 7, antRC = []; end
ops={@(A)A,@(A)rot90(A,1),@(A)rot90(A,2),@(A)rot90(A,3), ...
     @(A)fliplr(A),@(A)rot90(fliplr(A),1),@(A)rot90(fliplr(A),2),@(A)rot90(fliplr(A),3)};
brain=contra|ipsi; best=-inf; T=[];
% anterior probe: two native pixels, centroid and centroid + a step ANTERIOR
if ~isempty(antRC)
    [bR,bC]=find(brain);  c0=[mean(bR) mean(bC)];
    step=40*antRC(:).'/max(norm(antRC),eps);
    pA=min(max(round(c0+step),1),[H W]);  p0=min(max(round(c0),1),[H W]);
end
for o=1:numel(ops)
    Tt=make_orient(ops{o},H,W);
    cD=ops{o}(contra); iD=ops{o}(ipsi);
    [cr,cc]=find(cD); [ir,ic]=find(iD);  [br,~]=find(ops{o}(brain));
    if ~isempty(antRC)
        [rA,~]=orient_fwd(Tt,pA(1),pA(2));  [r0,~]=orient_fwd(Tt,p0(1),p0(2));
        tie = r0 - rA;                       % >0 when anterior points UP in the display
    else
        [sR,~]=orient_fwd(Tt,siteRow,siteCol);
        tie = sR - mean(br);                 % legacy: site below the centroid
    end
    score=1000*((mean(ic)-mean(cc)) - abs(mean(ir)-mean(cr))) + tie;
    if score>best, best=score; T=Tt; end
end
end

function a = get_ant_rc(ae)
% Session's ANTERIOR direction in native (row,col), if the loader registered one. Sessions
% without bregma registration return [] -> pick_orient keeps its legacy site-below tiebreaker.
a = [];
if isstruct(ae) && isfield(ae,'ant_rc') && numel(ae.ant_rc)==2 && all(isfinite(ae.ant_rc))
    a = double(ae.ant_rc(:)).';
end
end

function [rd,cd] = orient_fwd(T, r, c)
% original (row,col) -> display (row,col).
dl=T.posOfOrig(sub2ind([T.H T.W], r, c));  [rd,cd]=ind2sub([T.Hd T.Wd], dl);
end

function [r,c] = orient_inv(T, rd, cd)
% display (row,col) -> original (row,col).
r=T.invRow(rd,cd); c=T.invCol(rd,cd);
end

function local_session_viewer(cfg, allExperiments, selList, preload)
% Interactive map with a session dropdown. Selecting a session loads it and draws the
% orientation-normalized brain + sparse contra weights; clicking an ipsi pixel refits.
% preload (optional): struct('sel','D','px','py','T') from the main script's already-loaded
% session -> seeded into the cache and opened first, so its initial view is instant (no reload).
if nargin < 4, preload = []; end
labels=arrayfun(@(s) sprintf('%d: %s %s e%d',s,allExperiments(s).mn,allExperiments(s).td,allExperiments(s).en),selList,'uni',0);
fig=figure('Color','w','Name','[SESSION-VIEWER] pick session; click ipsi to refit contra weights','Position',[100 60 840 860]);
uicontrol(fig,'Style','text','Units','normalized','Position',[0.05 0.955 0.10 0.03],'String','session:', ...
          'FontSize',10,'HorizontalAlignment','left','BackgroundColor','w');
pop=uicontrol(fig,'Style','popupmenu','String',labels,'Units','normalized','Position',[0.16 0.95 0.5 0.04],'FontSize',10);
ax=axes(fig,'Units','normalized','Position',[0.05 0.03 0.9 0.89]);
% cache: a session's SVD load is ~17 s of disk I/O (loadUVt+loadData); memoize the loaded
% state per sel so switching BACK to an already-visited session is instant (no re-read).
cache=containers.Map('KeyType','double','ValueType','any');
if ~isempty(preload)
    cache(preload.sel)=struct('D',preload.D,'px',preload.px,'py',preload.py,'T',preload.T);
    iv=find(selList==preload.sel,1);  if ~isempty(iv), set(pop,'Value',iv); end   % open ON the seeded session
end
VS=struct('cfg',cfg,'allExp',{allExperiments},'selList',selList,'ax',ax,'pop',pop,'cache',cache);
guidata(fig,VS);
set(pop,'Callback',@(s,~) viewer_load(fig));
viewer_load(fig);
end

function viewer_load(fig)
VS=guidata(fig); ax=VS.ax; cla(ax,'reset');
sel=VS.selList(get(VS.pop,'Value'));
ae=VS.allExp(sel); lbl=sprintf('%s %s e%d',ae.mn,ae.td,ae.en);
if isKey(VS.cache,sel)                                   % already loaded once -> instant
    C=VS.cache(sel); D=C.D; px=C.px; py=C.py; T=C.T;
else                                                     % first visit: ~17 s SVD disk read
    title(ax,sprintf('loading %s  (first visit, ~15 s SVD read) ...',lbl)); axis(ax,'off'); drawnow;
    [D,px,py,contra,ipsi]=local_load_session(sel,VS.cfg,VS.allExp);
    knob=VS.cfg.disp_orient; if isempty(knob), knob='auto'; end
    T=resolve_orient(knob,contra,ipsi,px,py,D.nY,D.nX,get_ant_rc(ae));
    VS.cache(sel)=struct('D',D,'px',px,'py',py,'T',T);   % containers.Map is a handle -> persists
end
Idisp=T.imgOp(D.mimg); g=(Idisp-min(Idisp(:)))/max(max(Idisp(:))-min(Idisp(:)),eps);
him=image(ax,repmat(g,[1 1 3])); axis(ax,'image','off'); set(ax,'YDir','reverse'); hold(ax,'on');
s=linspace(0,1,128)'; colormap(ax,[[s s ones(128,1)];[ones(128,1) 1-s 1-s]]);
[gdR,gdC]=orient_fwd(T,D.grR,D.grC);
[sdR,sdC]=orient_fwd(T,px,py);
[bpix,cv,~,~,nAct]=ols_refit(D,px,py);
wsc=max(abs(bpix))+eps;
hSc=scatter(ax,gdC,gdR,26,bpix,'filled','MarkerEdgeColor',[.1 .1 .1],'LineWidth',0.4,'HitTest','off');
clim(ax,[-wsc wsc]); cb=colorbar(ax,'eastoutside'); cb.Label.String='weight (contra px \rightarrow ipsi target)';
hMk=plot(ax,sdC,sdR,'g+','MarkerSize',15,'LineWidth',2,'HitTest','off');
hTtl=title(ax,sprintf('%s   target[r%d c%d]  R^2=%.3f  %d/%d px  (click ipsi)',lbl,px,py,cv,nAct,numel(bpix)), ...
           'FontSize',11,'FontWeight','bold');
VS.D=D; VS.T=T; VS.hSc=hSc; VS.hMk=hMk; VS.hTtl=hTtl; VS.lbl=lbl;
guidata(fig,VS);
set(him,'ButtonDownFcn',@(o,~) viewer_click(fig));   % clicks land on the image (scatter/marker are HitTest off)
end

function viewer_click(fig)
VS=guidata(fig); ax=VS.ax; T=VS.T; D=VS.D;
cp=ax.CurrentPoint; xd=round(cp(1,1)); yd=round(cp(1,2));   % x=display col, y=display row
if yd<1||yd>T.Hd||xd<1||xd>T.Wd, return; end
[row,col]=orient_inv(T,yd,xd);
if ~D.ipsi(row,col)
    set(VS.hTtl,'String',sprintf('%s   [r%d c%d] NOT on ipsi (target) side — click the ipsi hemisphere',VS.lbl,row,col));
    return;
end
[bpix,cv,~,~,nAct]=ols_refit(D,row,col);
wsc=max(abs(bpix))+eps; set(VS.hSc,'CData',bpix); clim(ax,[-wsc wsc]);
[sdR,sdC]=orient_fwd(T,row,col); set(VS.hMk,'XData',sdC,'YData',sdR);
set(VS.hTtl,'String',sprintf('%s   target[r%d c%d]  R^2=%.3f  %d/%d px active',VS.lbl,row,col,cv,nAct,numel(bpix)));
guidata(fig,VS);
end
