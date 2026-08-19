% ctrl_ols_spont.m -- STAGE 1 of the controller-side stim-blind decomposition:
% fit the direct-pixel contra->ipsi OLS predictor on SPONTANEOUS (laser-off) frames.
%
% WHAT THIS IS
%   The controller-session counterpart of ols_tf_pipeline.m sec17 [SPONT-OLS]. Builds a
%   regular grid of CONTRA-hemisphere pixels and regresses the controller's regulated
%   ipsi readout (dFk) on them, using ONLY laser-off inter-trial frames. The resulting
%   map is the "ongoing network state" predictor that later stages deploy on stim
%   trials to produce GLOBAL (the counterfactual no-input ipsi) and
%   LOCAL = ACTUAL - GLOBAL (what the laser/controller actually did).
%
%   This is the DIRECT-PIXEL OLS lineage (ols_tf_pipeline / ols_pixel_predictor), NOT
%   the RRR/CanonCor2 lineage (cp_hemi_predictor, used by contra_prediction_controller.m).
%   Chosen 2026-07-18: the TF pipeline is the primary ipsi-prediction method going forward.
%
% RUN ORDER
%   Stage 1 (this file)  -> spontaneous predictor + held-out validation
%   Stage 2 (next)       -> OL-trial TF affected-pixel detection + per-pixel plant h_j(t)
%   Stage 3 (next)       -> deploy on CL: Global / Local, best-possible-control benchmark
%
% PREREQS
%   controller-analysis/load_sessions.m  (builds `mouse`, `fields`, per-session .d/.data)
%
% SECTIONS
%   [CTRL-OLS-CFG]    knobs
%   [CTRL-OLS-LOAD]   session + SVD + target readout (with convention guard)
%   [CTRL-OLS-MASK]   contra/ipsi midline masks
%   [CTRL-OLS-GRID]   contra pixel lattice
%   [CTRL-OLS-SPONT]  laser-OFF frame selection  <-- the part that differs most from impulse
%   [CTRL-OLS-FIT]    z-score, train/test split, fit
%   [CTRL-OLS-VAL]    held-out validation + diagnostic figure
%   [CTRL-OLS-SAVE]   cache the fitted predictor for Stage 2/3

%% [CTRL-OLS-CFG] knobs --------------------------------------------------------
selField   = 4;        % session index into `fields`. 4 = m4 (AL_0033 2025-02-26), a step-response
                       % session (custom_idx = [4 9 11]) -> has OL steps for Stage 2 detection.
                       % NOTE: m1 (AL_0033 2025-01-20 e3) has NO widefield SVD on the server
                       % (raw 101 GB widefield.tar, never decomposed) -- excluded. See RESEARCH 2026-07-18.
% BATCH override: the cross-session builder (imp_xsess_build) sets BATCH_selField so
% this script can be run in a loop without editing the knob. Interactive use ignores it.
if exist('BATCH_selField','var') && ~isempty(BATCH_selField); selField = BATCH_selField; end
nSV_load   = 500;      % SVD components to load (matches ols_tf_pipeline)
Fs         = 35;       % widefield blue frame rate
nGrid      = 500;      % target contra grid size
edgeMargin = 12;       % erode mask edge by this many px (drop low-SNR boundary nodes)
settle_s   = 2.0;      % laser-OFF settle AFTER TRIAL END before a frame counts as spontaneous
trainFrac  = 2/3;      % temporal train fraction (first block = train, later block = test)
maxFrm     = 60000;    % cap on spontaneous frames used
fit_mode   = 'ols';    % 'ols' | 'ridge' | 'lasso'. DENSE OLS is the default -- we care about R^2
                       % here (dense 0.87 vs sparse-lasso plateau ~0.68; the extra R^2 is many small
                       % DISTRIBUTED contra contributions). Lasso stays available for an interpretable
                       % Zhiwen-style map; ridge never zeros px.
ridge_lam  = 0.2;      % L2 (ridge mode) / elastic-net L2 fraction (lasso mode: >0 groups neighbours)
l1_frac    = 0.1;      % L1 penalty fraction (lasso mode only): HIGHER = sparser (fewer active px)
debias     = true;     % lasso: refit plain OLS on selected pixels (removes L1 shrinkage)
redefine_roi = false;  % true = redraw the brain outline + midline for this session
% BATCH override: ctrl_roi_build_all.m sets BATCH_redefine_roi to force a fresh draw for THIS
% session without editing the knob (and without leaving it edited for the next interactive run).
if exist('BATCH_redefine_roi','var') && ~isempty(BATCH_redefine_roi)
    redefine_roi = BATCH_redefine_roi;
end
rng(7,'twister');      % reproducibility (matches ols_tf_pipeline)

assert(exist('mouse','var') && exist('fields','var'), ...
    '[CTRL-OLS] run controller-analysis/load_sessions.m first (need `mouse`,`fields`).');

here = fileparts(mfilename('fullpath'));
if isempty(here) || contains(here, tempdir, 'IgnoreCase', true) || contains(here, 'Editor_', 'IgnoreCase', true)
    here = fullfile(pwd, 'controller-analysis');            % section-run puts mfilename in %TEMP%
    if ~exist(here, 'dir'); here = pwd; end
end
dataDir = fullfile(here, 'data');  if ~exist(dataDir,'dir'); mkdir(dataDir); end
% Anchor the export path to THIS script's directory, not pwd -- the CWD-dependent
% exist('paper/images') resolver silently writes to projects\paper (see TASKS BUG 2026-07-17).
paper_root = fullfile(here, '..', 'paper');
fig_dir = fullfile(paper_root, 'images', 'predictor_saga');
if ~exist(fig_dir,'dir'); mkdir(fig_dir); end

%% [CTRL-OLS-LOAD] session + SVD + target readout ------------------------------
fld = fields{selField};
if isfield(mouse.(fld),'skip') && mouse.(fld).skip
    error('[CTRL-OLS] session %s was skipped during load_sessions.', fld);
end
d_s  = mouse.(fld).d;                                   % session struct (NOT `d` -- avoid collisions)
data = mouse.(fld).data;
mn   = mouse.(fld).mn;  td = mouse.(fld).td;  en = mouse.(fld).en;
sess_tag = sprintf('%s_%s%s_e%d', mn, td(6:7), td(9:10), en);
fprintf('\n[CTRL-OLS] session %s (%s)\n', fld, sess_tag);

% --- SVD: load via loadUVt for PARITY WITH THE IMPULSE PIPELINE -------------------
% Deliberate choice (2026-07-18): do NOT use the cached d_s.svd. initialize_data reads the
% RAW blue/svdTemporalComponents.npy with no hemodynamic correction and no detrend, whereas
% loadUVt prefers corr/svdTemporalComponents_corr.npy and otherwise applies detrendAndFilt.
% Using d_s.svd would preprocess the controller data DIFFERENTLY from the impulse data the
% method was developed on, which would make any Global/Local comparison across the two
% non-comparable. loadUVt also REPORTS which branch it took -> we record it below.
serverRoot = expPath(mn, td, en);
% cp_loadUVt = loadUVt + a d.timeBlue fallback for the 5 sessions that ship no
% svdTemporalComponents.timestamps.npy (m6 m7 m8 m11 m12). Identical behaviour when the
% timestamps exist. See utils/cp_loadUVt.m + RESEARCH 2026-08-02.
[U_cp, V_cp, t_svd, mimg_cp] = cp_loadUVt(serverRoot, nSV_load, d_s.timeBlue);
V_cp = double(V_cp);
[nY_cp, nX_cp] = size(mimg_cp);  nSV_cp = size(U_cp,3);
used_corr = exist(fullfile(serverRoot,'corr','svdTemporalComponents_corr.npy'),'file') > 0;
fprintf('[CTRL-OLS] SVD %dx%d, %d SV | hemo-corrected V: %s\n', ...
    nY_cp, nX_cp, nSV_cp, ternstr_ols(used_corr,'YES (corr/)','NO (blue/ + detrendAndFilt)'));
if ~used_corr
    warning(['[CTRL-OLS] %s has NO corrected V. 7 of 12 usable controller sessions do; 5 do not ' ...
             '(m6 m7 m8 m11 m12). Carry this as a covariate -- do not pool blind across the split. ' ...
             'It bears directly on the T1 hemodynamic reviewer objection.'], sess_tag);
end

t_full = t_svd(:);
if numel(t_full) ~= size(V_cp,2)
    t_full = t_full(1:min(numel(t_full), size(V_cp,2)));
end
Uflat = reshape(U_cp, nY_cp*nX_cp, nSV_cp);
if isfield(d_s.params,'kernel');  k_prim  = double(d_s.params.kernel);  else; k_prim  = 10;    end
if isfield(d_s.params,'horizon'); horizon = double(d_s.params.horizon); else; horizon = 40*Fs; end

% --- recording site = DATA-DERIVED laser spot (deepest focal OL inhibition) --------
% params.pixel is unreliable (flip-prone AND, on m4, sits on the inhibition RIM ~45 px from the
% true laser center -- verified 2026-07-19, ctrl_dipmap_m4.png). We localise the laser spot the
% same way the impulse pipeline does: trial-average the peri-stim widefield response on the
% OPEN-LOOP trials (fixed-ish laser) and take the most-inhibited pixel (cp_find_stim_site,
% native frame, row=pixel(2)/col=pixel(1) convention). Cached like the impulse side so every
% stage inherits ONE site. This also confirms the hemisphere: the dip is focal on the RIGHT
% (ipsi); contra (predictor) = LEFT.
site_file = fullfile(dataDir, sprintf('cp_stim_site_ctrl_%s.mat', sess_tag));
if exist(site_file,'file') && ~redefine_roi
    st = load(site_file);  stim_rc = double(st.rowcol);
    fprintf('[CTRL-OLS] loaded cached laser site [row %d col %d]\n', stim_rc);
else
    ol_starts = sort(d_s.stimStarts(data.nc(:)));
    onF_ol = zeros(numel(ol_starts),1);
    for j = 1:numel(ol_starts), [~,onF_ol(j)] = min(abs(t_full - ol_starts(j))); end
    onF_ol = onF_ol(onF_ol > 0.5*Fs & onF_ol < size(V_cp,2)-Fs);
    st = cp_find_stim_site(U_cp, double(V_cp), mimg_cp, onF_ol, 'fs', Fs);
    stim_rc = double(st.rowcol);  save(site_file,'-struct','st');
    fprintf('[CTRL-OLS] computed laser site [row %d col %d] (depth %.3f) from %d OL trials -> cached\n', ...
        stim_rc, st.depth, numel(onF_ol));
end
laser_rc = stim_rc;     % keep the LASER spot -- it is what the effect-map overlay marks

% --- READOUT site: which pixel did the controller actually regulate? --------------
% The laser spot and the readout are different questions and were conflated until 2026-08-10.
% `data.dFk` is computed online at `d.params.pixel`, except the load/save path flips x<->y, so the
% transpose may be the right reading (user). Rather than guess, ctrl_readout_site scores every
% candidate against data.dFk on correlation AND amplitude and takes the best plausible one --
% per session, because the answer differs by session: on AL_0039 the readout sits ~50-72 px from
% the laser spot (params wins), on AL_0033/AL_0051 the two essentially coincide. RESEARCH 2026-08-10.
% Cached so Stage 2/3 and every downstream script inherit ONE readout site.
ro_file = fullfile(dataDir, sprintf('ctrl_readout_site_%s.mat', sess_tag));
if exist(ro_file,'file') && ~redefine_roi
    RO = load(ro_file);
    fprintf('[CTRL-OLS] loaded cached readout site [row %d col %d] (%s, r=%.3f)\n', ...
        RO.rc, RO.name, RO.r);
else
    ro_cand = struct('name',{},'rc',{});
    if isfield(d_s.params,'pixel') && numel(d_s.params.pixel) >= 2
        pp = double(d_s.params.pixel);
        ro_cand(end+1) = struct('name','params',   'rc',[pp(2) pp(1)]); %#ok<SAGROW>
        ro_cand(end+1) = struct('name','params_T', 'rc',[pp(1) pp(2)]); %#ok<SAGROW>
    end
    ro_cand(end+1) = struct('name','laser', 'rc', laser_rc);
    RO = ctrl_readout_site(Uflat, V_cp, mimg_cp, data.dFk(:), ro_cand, ...
                           k_prim, horizon, nY_cp, nX_cp, max(1,round(horizon)-1));
    save(ro_file,'-struct','RO');
    fprintf('[CTRL-OLS] readout site = %s [row %d col %d] -> cached\n', RO.name, RO.rc);
end
px_prim = RO.rc(1);   % ROW of the READOUT pixel
py_prim = RO.rc(2);   % COL of the READOUT pixel
d_readout_laser = hypot(px_prim-laser_rc(1), py_prim-laser_rc(2));
if d_readout_laser > 30
    fprintf(['[CTRL-OLS] NOTE: readout is %.0f px from the laser spot [row %d col %d]. Not an ' ...
             'error -- on this session the photostimulated spot and the controlled readout are ' ...
             'genuinely different places. Carry it into Methods.\n'], d_readout_laser, laser_rc);
end

% --- Actual = SVD raw-kernel fluorescence + rolling baseline at the laser spot -----
% CRITICAL PIPELINE FACT (RESEARCH 2026-07-18): the paper's `data.dFk` is getpixel_dFoF
% **mode=0** = RAW binary frames + a `horizon`-sample ROLLING baseline, NOT the SVD mean-image
% dF/F. Reconstructing the SVD kernel with the mean-image baseline (F/mI*100) gives corr~0.06
% with data.dFk (different baseline method). FIX (per user): rebuild raw fluorescence from the
% SVD (F_raw = mI + kernel.U*V) and pass it through the SAME rolling baseline. That trace both
% (a) reconstructs from the SVD -> is contra-predictable, and (b) tracks data.dFk (corr ~0.90 at
% the laser spot on m4). First `w` warm-up samples are baseline garbage -> NaN, excluded everywhere.
[y_full, okY] = local_svd_rolling_dfk(Uflat, V_cp, mimg_cp, px_prim, py_prim, k_prim, horizon, nY_cp, nX_cp);
assert(okY, '[CTRL-OLS] laser-spot box [row %d col %d] is out of frame or degenerate.', px_prim, py_prim);
w_warm = max(1, round(horizon)-1);
nF_m   = min(numel(y_full), size(V_cp,2));

% Validate against the paper's data.dFk (regulated at params.pixel rim; ~0.9 at the spot).
dfk_rec = data.dFk(:);
vv = (w_warm+1):min(numel(y_full), numel(dfk_rec));
r_match = corr(y_full(vv), dfk_rec(vv), 'rows','complete');
fprintf('[CTRL-OLS] Actual = SVD raw-kernel + %.0f s rolling baseline @ readout [row %d col %d]\n', ...
    horizon/Fs, px_prim, py_prim);
fprintf('[CTRL-OLS] corr(Actual, paper data.dFk) = %.3f  (warm-up %d frames NaN)\n', r_match, w_warm);
if r_match < 0.7
    % NB this is a quality flag on the SVD RECONSTRUCTION, not on the decomposition: Stage 2
    % regresses onto data.dFk itself, and the candidates all sit in the same hemisphere, so the
    % masks and grid are unaffected. It bites only the scripts that use y_full. RESEARCH 2026-08-10.
    warning(['[CTRL-OLS] corr(Actual, data.dFk)=%.3f is low (expected ~0.9) even at the best ' ...
             'readout candidate -- this session reconstructs poorly from the SVD. Stage 2 is ' ...
             'unaffected (it targets data.dFk); y_full-based analyses are.'], r_match);
end

%% [CTRL-OLS-MASK] contra (predictor) / ipsi (target) midline masks -------------
% Same shared helper + same cache naming scheme as the impulse side, so a session's ROI is
% drawn ONCE and inherited by every stage.
roi_file = fullfile(dataDir, sprintf('cp_roi2_ctrl_%s.mat', sess_tag));
if ~exist(roi_file,'file') && ~redefine_roi
    fprintf('[CTRL-OLS] no cached ROI for %s -- the draw GUI will open ONCE.\n', sess_tag);
end
% ONE display view for the whole session (cp_orient): the draw GUI, the VAL kernel map, the
% Stage-2 affected map and the detector GUI all render through it, and clicks invert through it,
% so the frame you draw in is the frame you check in. Resolved from the image itself (mirror
% symmetry decides transpose; the site is put on the right); the anterior-up flip is confirmed by
% eye once, only when the ROI is being (re)drawn, and cached.
orient_file = fullfile(dataDir, sprintf('cp_orient_ctrl_%s.mat', sess_tag));
Torient = cp_orient(mimg_cp, px_prim, py_prim, struct('cache_file',orient_file, ...
                    'redefine',redefine_roi, 'confirm',redefine_roi));
% SANITY LAYER WHILE DRAWING (2026-08-10): the draw window now carries the data-derived laser
% effect (cp_find_stim_site's trial-averaged inhibition map) plus the site and params.pixel
% markers. The midline you click is what assigns contra vs ipsi, so the spot has to be visible
% at click time -- drawing on a bare mean image is how a midline ends up on the wrong side of
% the laser and the "contra predictor" quietly contains the stimulated hemisphere.
% Green + = the LASER spot (what the effect contours are of); magenta x = the READOUT pixel the
% controller regulated. On most sessions they coincide; on AL_0039 they are ~60 px apart, and
% seeing both while drawing is the point.
roi_overlay = [];
if isfield(st,'map')
    roi_overlay = @(ax) cp_site_overlay(ax, Torient, st.map, laser_rc, [px_prim py_prim], ...
        struct('site_label','laser spot','extra_label','readout (dFk)'));
end
% plot=false: cp_roi_masks' built-in verification still draws the legacy transposed frame; we
% render our own overlay through Torient in the VAL figure below instead.
M_cp = cp_roi_masks(mimg_cp, roi_file, px_prim, py_prim, ...
                    struct('redefine', redefine_roi, 'thr_pctile', 20, 'plot', false, ...
                           'T', Torient, 'draw_overlay', roi_overlay, ...
                           'name_extra', sess_tag, 'fig_pos', [40 60 760 720]));
contra_mask = logical(M_cp.contra);  ipsi_mask = logical(M_cp.ipsi);
% midline endpoints back in NATIVE (row,col) for drawing (cp_roi_masks stores them transposed:
% mx=x=col-of-A=native row, my=y=row-of-A=native col). So native (row,col) = (mx, my).
mid_row = M_cp.mx(:);  mid_col = M_cp.my(:);
fprintf('[CTRL-OLS] masks: contra(left/predictor) %d px | ipsi(right/target) %d px\n', ...
    nnz(contra_mask), nnz(ipsi_mask));

%% [CTRL-OLS-GRID] regular contra pixel lattice --------------------------------
% Uniform lattice at spacing gstep (NOT linspace-trimmed to exactly nGrid -- that drops nodes
% in a periodic stripe pattern). Then erode: keep a node only if its full (2*em+1)^2
% neighborhood is inside the mask, so no low-SNR boundary pixel gets weight.
[rC,cC] = find(contra_mask);
rmn=min(rC); rmx=max(rC); cmn=min(cC); cmx=max(cC);
gstep = max(1, round(sqrt(nnz(contra_mask)/nGrid)));
gridIdx = [];  ln = [];
for it = 1:12
    [GR,GC] = ndgrid(rmn:gstep:rmx, cmn:gstep:cmx);
    ln = sub2ind([nY_cp,nX_cp], GR(:), GC(:));  ln = ln(contra_mask(ln));
    if numel(ln) >= nGrid || gstep==1, gridIdx = ln; break; end
    gstep = max(1, gstep-1);
end
if isempty(gridIdx); gridIdx = ln; end
[grR,grC] = ind2sub([nY_cp,nX_cp], gridIdx);
em = edgeMargin;
keep = (grR>em) & (grR<=nY_cp-em) & (grC>em) & (grC<=nX_cp-em);
for g = find(keep(:).')
    blk = contra_mask(grR(g)-em:grR(g)+em, grC(g)-em:grC(g)+em);
    if ~all(blk(:)); keep(g) = false; end
end
gridIdx = gridIdx(keep);  grR = grR(keep);  grC = grC(keep);
nG = numel(gridIdx);
fprintf('[CTRL-OLS] grid: %d interior contra px (%d-px lattice, %d-px edge margin; target %d)\n', ...
    nG, gstep, em, nGrid);

%% [CTRL-OLS-SPONT] laser-OFF spontaneous frames -------------------------------
% *** THE KEY DIFFERENCE FROM THE IMPULSE PIPELINE ***
% ols_tf_pipeline sec6 starts each spontaneous gap at onset + settle_s (2 s). That is safe for
% IMPULSE data, where the stim is instantaneous. It is WRONG here: a controller trial drives
% the laser for the ENTIRE trial duration (controllerData slices d_s.inpVals over
% i2 : i2 + dur*2000, i.e. dur seconds at 2 kHz), so frames from onset to onset+dur are
% LASER-ON. Starting the gap at onset+2 s would pull ~1 s of laser-on frames per trial into
% the "spontaneous" training set and teach the predictor exactly the stim-driven coupling we
% need it to be blind to. (contra_prediction_controller.m's settle_s = 1.0 has this bug.)
% Correct gap: onset + trial_dur + settle_s  ->  next onset - 2 frames.
if isfield(d_s.params,'dur'); trial_dur = double(d_s.params.dur); else; trial_dur = 3; end
all_starts = sort(d_s.stimStarts(:));
all_starts = all_starts(isfinite(all_starts) & all_starts > 0);
ons = zeros(numel(all_starts),1);
for j = 1:numel(all_starts), [~,ons(j)] = min(abs(t_full - all_starts(j))); end
ons = ons(ons >= 1 & ons <= nF_m);

laser_off_start = round((trial_dur + settle_s)*Fs);      % frames after onset before we trust "off"
frames = [];
for j = 1:numel(ons)
    i0 = ons(j) + laser_off_start;
    if j < numel(ons); i1 = ons(j+1) - 2; else; i1 = nF_m; end
    i0 = max(i0,1);  i1 = min(i1,nF_m);
    if i1 >= i0; frames = [frames, i0:i1]; end   %#ok<AGROW>
end
% also take the pre-first-trial baseline period (pure spontaneous, no stim history).
% NB most of this falls inside the rolling-baseline warm-up (first w_warm frames) and is
% dropped by the isfinite filter below -- Actual is NaN there. Kept for the rare case where
% the first trial starts after the warm-up ends.
if ~isempty(ons) && ons(1) > 2
    frames = [1:(ons(1)-2), frames];
end
frames = unique(frames);
frames = frames(frames>=1 & frames<=nF_m);
n_pre_warm = numel(frames);
frames = frames(frames > w_warm);                        % drop rolling-baseline warm-up explicitly
frames = frames(isfinite(y_full(frames)'));              % and any remaining NaN Actual
n_dropped_warm = n_pre_warm - numel(frames);
nSpontRaw = numel(frames);
fprintf('[CTRL-OLS] dropped %d warm-up/NaN frames (first %.1f s rolling-baseline garbage)\n', ...
    n_dropped_warm, w_warm/Fs);
if numel(frames) > maxFrm
    frames = frames(round(linspace(1,numel(frames),maxFrm)));
end
frac_off = nSpontRaw / max(nF_m,1);
fprintf(['[CTRL-OLS] spontaneous: %d laser-off frames (%.1f%% of session, %.1f s) ' ...
         'from %d trials | gap = onset + %.1f s (dur %.1f + settle %.1f)\n'], ...
    nSpontRaw, 100*frac_off, nSpontRaw/Fs, numel(ons), trial_dur+settle_s, trial_dur, settle_s);
if nSpontRaw < 20*Fs
    warning(['[CTRL-OLS] only %.1f s of laser-off data -- too little to fit %d regressors. ' ...
             'Check trial spacing; consider a shorter settle or a pooled-session fit.'], ...
             nSpontRaw/Fs, nG);
end

% temporal (not random) split: first block trains, later block tests. Random splits leak
% across the ~s-scale autocorrelation of widefield activity and inflate held-out R^2.
nTr = floor(trainFrac*numel(frames));
itr = 1:nTr;  ite = nTr+1:numel(frames);
fprintf('[CTRL-OLS] split: %d train / %d test frames (temporal, trainFrac=%.2f)\n', ...
    numel(itr), numel(ite), trainFrac);

%% [CTRL-OLS-FIT] z-score + fit the spontaneous contra->ipsi map ---------------
Xg   = double(Uflat(gridIdx,:)) * V_cp(:,frames);            % [nG x nFrm] raw grid activity
mu_p = mean(Xg(:,itr),2);  sd_p = std(Xg(:,itr),0,2);  sd_p(sd_p==0) = 1;   % TRAIN-ONLY z-score
Ztr  = ((Xg(:,itr) - mu_p)./sd_p).';
Zte  = ((Xg(:,ite) - mu_p)./sd_p).';

y_sp = double(y_full(frames));
ytr  = y_sp(itr);  yte = y_sp(ite);
muY  = mean(ytr);  ytrc = ytr - muY;

switch lower(fit_mode)
    case 'ridge'
        Gz = Ztr.'*Ztr;  lam = ridge_lam*mean(diag(Gz));
        b  = (Gz + lam*eye(nG)) \ (Ztr.'*ytrc);
        nActive = nG;
    case 'lasso'
        Gz = Ztr.'*Ztr;  cz = Ztr.'*ytrc;
        b  = cd_lasso_ols(Gz, cz, diag(Gz), l1_frac, ridge_lam);
        nActive = nnz(b);
        if debias && nActive > 0                              % refit OLS on selected px
            S = find(b);  Gs = Gz(S,S) + 1e-6*mean(diag(Gz))*eye(numel(S));
            b = zeros(nG,1);  b(S) = Gs \ cz(S);
        end
    otherwise                                                 % ols
        Gz = Ztr.'*Ztr;  lamR = 1e-6*mean(diag(Gz));          % tiny jitter for conditioning
        b  = (Gz + lamR*eye(nG)) \ (Ztr.'*ytrc);
        nActive = nG;
end

predict_spont = @(Zrows) muY + Zrows*b;   % Zrows = [nFrames x nG] z-scored contra design

%% [CTRL-OLS-VAL] held-out validation ------------------------------------------
% Reported on the HELD-OUT temporal block, per-frame (never on a trial average -- a
% trial-averaged R^2 outside the stim window is noise-vs-noise and reads high regardless;
% ols_tf_pipeline sec17b documents that trap explicitly).
yhat_te = predict_spont(Zte);
yhat_tr = predict_spont(Ztr);
r2f = @(y,yh) 1 - sum((y(:)-yh(:)).^2)/max(sum((y(:)-mean(y(:))).^2),eps);
R2_tr = r2f(ytr, yhat_tr);
R2_te = r2f(yte, yhat_te);
rho_te = corr(yte(:), yhat_te(:), 'rows','complete');
fprintf(['\n[CTRL-OLS-VAL] %s | mode=%s nActive=%d/%d\n' ...
         '   train R^2 = %.3f | HELD-OUT R^2 = %.3f | held-out rho = %.3f\n'], ...
    sess_tag, lower(fit_mode), nActive, nG, R2_tr, R2_te, rho_te);
if R2_te < 0.3
    warning(['[CTRL-OLS] held-out R^2 = %.3f is low. The impulse side reaches ~0.85-0.95. ' ...
             'Suspect: Actual-vs-data.dFk corr was %.3f (target build), laser-on ' ...
             'contamination, or too few spontaneous frames.'], R2_te, r_match);
end
gap = R2_tr - R2_te;
if gap > 0.15
    warning(['[CTRL-OLS] train-test gap %.3f (%d active px). NB with lasso+debias the train R^2 is ' ...
             'optimistic (OLS refit on train-selected px); the held-out is the honest number -- lower ' ...
             'l1_frac to densify, or set debias=false.'], gap, nActive);
end

% --- orientation check: sparse contra weights should cluster at the HOMOTOPIC mirror of the
% laser site (a focal homotopic contra hot-spot = no transpose; cp_find_stim_site / Ye et al.).
mid_c_val = mean(mid_col);
homo_row  = px_prim;  homo_col = 2*mid_c_val - py_prim;          % mirror the site across the midline
actw = find(abs(b) > 0);  [~,si] = sort(abs(b(actw)),'descend');
topK = actw(si(1:min(10,numel(si))));
wcen_row = sum(grR(topK).*abs(b(topK)))/sum(abs(b(topK)));
wcen_col = sum(grC(topK).*abs(b(topK)))/sum(abs(b(topK)));
d_homo = hypot(wcen_row-homo_row, wcen_col-homo_col);
fprintf(['[CTRL-OLS] orientation check: top-10 contra-weight centroid (row %.0f, col %.0f) vs ' ...
         'homotopic mirror (row %.0f, col %.0f) = %.0f px %s\n'], ...
    wcen_row, wcen_col, homo_row, homo_col, d_homo, ...
    ternstr_ols(d_homo < 80, '-> homotopic, orientation OK', '-> FAR: possible transpose/orientation issue'));

% --- diagnostic figure (PNG; not a paper panel -> per CLAUDE.md export rule) ---
figV = figure('Color','w','Position',[80 80 1200 700]);
tl = tiledlayout(figV, 2, 3, 'TileSpacing','compact','Padding','compact');

nexttile(tl,1,[1 2]); hold on;                                   % held-out trace
nShow = min(numel(yte), round(60*Fs));
plot((1:nShow)/Fs, yte(1:nShow), 'k-', 'LineWidth',1.0);
plot((1:nShow)/Fs, yhat_te(1:nShow), '-', 'Color',[0.85 0.33 0.10], 'LineWidth',1.0);
xlabel('Time (s, held-out block)'); ylabel('\DeltaF/F (%)');
title(sprintf('Held-out spontaneous prediction — R^2 = %.3f', R2_te));
legend({'actual (dFk)','contra prediction'}, 'Box','off','Location','best');

nexttile(tl,3); hold on;                                          % scatter
scatter(yhat_te, yte, 4, [0.2 0.4 0.85], 'filled', 'MarkerFaceAlpha',0.15);
lims = [min([yte;yhat_te]) max([yte;yhat_te])];
plot(lims, lims, 'k--', 'LineWidth',0.8);
axis tight; xlabel('predicted'); ylabel('actual'); title(sprintf('\\rho = %.3f', rho_te));

nexttile(tl,4); hold on;                                          % kernel map in the SESSION VIEW
% Everything here goes through Torient -- image, hemisphere tints, midline, grid, site, mirror --
% so a marker cannot drift off the feature it marks. Brain as an RGB image (NOT colormapped) so
% the weights own the axes colormap (diverging).
gg = mat2gray(cp_orient_img(Torient, mimg_cp));  rgb = repmat(gg,1,1,3);
ipsiD = cp_orient_img(Torient, ipsi_mask);  contraD = cp_orient_img(Torient, contra_mask);
aT = 0.16;                                                        % faint hemisphere tints, clean read
rgb(:,:,3) = rgb(:,:,3) + aT*double(ipsiD)  .*(1-rgb(:,:,3));     % ipsi   (target)    -> bluish
rgb(:,:,1) = rgb(:,:,1) + aT*double(contraD).*(1-rgb(:,:,1));     % contra (predictor) -> reddish
image(rgb); axis image ij off;
[midR_d, midC_d] = cp_orient_fwd(Torient, mid_row, mid_col);
plot(midC_d, midR_d, 'w--', 'LineWidth',1.1);                     % hand-drawn midline
act = find(abs(b) > 0);                                           % SPARSE: active contra px only
wn  = b(act)/max(abs(b(act))+eps);
[~,ord] = sort(abs(wn));                                          % strong weights drawn on top
[gR_d, gC_d] = cp_orient_fwd(Torient, grR(act(ord)), grC(act(ord)));
scatter(gC_d, gR_d, 40*abs(wn(ord))+8, wn(ord), 'filled', 'MarkerEdgeColor',[.25 .25 .25]);
clim([-1 1]); colormap(gca, local_bwr()); cb = colorbar; cb.Label.String = 'weight';
[sR_d, sC_d] = cp_orient_fwd(Torient, px_prim, py_prim);
plot(sC_d, sR_d, 'g+', 'MarkerSize',13, 'LineWidth',2.2);         % laser site (ipsi)
mid_c = mean(mid_col);  mir_col = round(2*mid_c - py_prim);       % homotopic mirror across midline
[hR_d, hC_d] = cp_orient_fwd(Torient, px_prim, mir_col);
plot(hC_d, hR_d, 'o', 'Color',[0 0.7 0], 'MarkerSize',11, 'LineWidth',1.6);  % expected contra hot-spot
title(sprintf('Sparse contra weights (%d/%d active) + ipsi;  o = homotopic', numel(act), nG));

nexttile(tl,5); hold on;                                          % laser-off coverage
onsT = ons/Fs;
plot([0 nF_m/Fs], [0 0], 'k-');
inSp = false(nF_m,1); inSp(frames) = true;
area((1:nF_m)/Fs, double(inSp), 'FaceColor',[0.2 0.6 0.3], 'EdgeColor','none', 'FaceAlpha',0.5);
for j = 1:numel(onsT)
    xline(onsT(j), '-', 'Color',[0.85 0.2 0.2 0.35], 'LineWidth',0.5);
end
ylim([0 1.2]); xlabel('Session time (s)'); ylabel('spont');
title(sprintf('Laser-off frames: %.1f%% (red = onsets)', 100*frac_off));

nexttile(tl,6); hold on;                                          % residual distribution
res_te = yte - yhat_te;
histogram(res_te, 60, 'Normalization','pdf', 'FaceColor',[0.4 0.4 0.4], 'EdgeColor','none');
xlabel('held-out residual (\DeltaF/F %)'); ylabel('pdf');
title(sprintf('resid SD = %.3f', std(res_te,'omitnan')));

sgtitle(figV, sprintf('[CTRL-OLS] spontaneous contra\\rightarrowipsi  %s  (%s, corrV=%s)', ...
    strrep(sess_tag,'_','\_'), lower(fit_mode), ternstr_ols(used_corr,'yes','no')));
fig_png = fullfile(fig_dir, sprintf('ctrl_ols_spont_%s.png', sess_tag));
exportgraphics(figV, fig_png, 'Resolution', 300);
fprintf('[CTRL-OLS-VAL] figure -> %s\n', fig_png);

%% [CTRL-OLS-SAVE] cache the fitted predictor for Stage 2/3 --------------------
OLS = struct();
OLS.sess_tag   = sess_tag;   OLS.selField = selField;
OLS.mn = mn;  OLS.td = td;  OLS.en = en;
OLS.b          = b;          OLS.muY = muY;
OLS.mu_p       = mu_p;       OLS.sd_p = sd_p;
OLS.gridIdx    = gridIdx;    OLS.grR = grR;  OLS.grC = grC;  OLS.nG = nG;
OLS.px_prim    = px_prim;    OLS.py_prim = py_prim;  OLS.k_prim = k_prim;
% readout vs laser -- two different pixels on some sessions; both travel with the cache so a
% downstream script can never silently assume they are the same place
OLS.readout_rc = [px_prim py_prim];  OLS.laser_rc = laser_rc;
OLS.readout_name = RO.name;  OLS.readout_r = RO.r;  OLS.readout_scale = RO.scale;
OLS.readout_cands = RO.cands;  OLS.d_readout_laser = d_readout_laser;
OLS.horizon    = horizon;    OLS.w_warm = w_warm;    OLS.r_match = r_match;   % Actual = SVD raw-kernel + rolling baseline
OLS.baseline   = 'svd_raw_kernel_rolling(mode0-match)';
OLS.frames     = frames;     OLS.itr = itr;  OLS.ite = ite;
OLS.ons        = ons;        OLS.trial_dur = trial_dur;  OLS.settle_s = settle_s;
OLS.fit_mode   = lower(fit_mode);  OLS.nActive = nActive;
OLS.R2_tr      = R2_tr;      OLS.R2_te = R2_te;  OLS.rho_te = rho_te;
OLS.used_corr  = used_corr;  OLS.nSV_load = nSV_load;  OLS.Fs = Fs;
OLS.contra_mask = contra_mask;  OLS.ipsi_mask = ipsi_mask;
OLS.Torient = Torient;          % the session display view -- Stage 2/3 and the GUIs render through it
OLS.nF_m       = nF_m;
ols_file = fullfile(dataDir, sprintf('ctrl_ols_spont_%s.mat', sess_tag));
save(ols_file, '-struct', 'OLS', '-v7.3');
fprintf('[CTRL-OLS-SAVE] -> %s\n\n', ols_file);

% ---- local helpers ----------------------------------------------------------
function [y, ok] = local_svd_rolling_dfk(Uflat, V, mimg, prow, pcol, k, horizon, nY, nX)
% Actual readout = SVD-reconstructed RAW kernel fluorescence put through the SAME
% rolling-baseline dF/F as getpixel_dFoF mode=0 (the pipeline data.dFk uses).
%   F_raw(t) = mI + mean(U_box)*V(:,t)      (U*V is the zero-mean dF; mI = mean image = F0)
%   base(t)  = trailing mean of F_raw over the last (w+1) samples, w = horizon-1
%   dFk(t)   = (F_raw - base)/base * 100 ;   first w (warm-up) samples -> NaN
% Box = row prow, col pcol (getpixel convention: prow=pixel(2), pcol=pixel(1)).
% ok=false if the box is out of frame or the mean image there is degenerate.
y = nan(size(V,2),1);  ok = false;
if prow < 1 || prow > nY || pcol < 1 || pcol > nX; return; end
kr = max(1,prow-k):min(nY,prow+k);
kc = max(1,pcol-k):min(nX,pcol+k);
[KR,KC] = ndgrid(kr,kc);
kidx = sub2ind([nY,nX], KR(:), KC(:));
mI = mean(mimg(kr,kc),'all');
if ~isfinite(mI) || abs(mI) < eps; return; end
Fsvd = mean(double(Uflat(kidx,:)),1) * V;      % [1 x T] kernel dF reconstruction (zero-mean)
Fraw = mI + Fsvd(:);                            % [T x 1] raw fluorescence
w = max(1, round(horizon)-1);
T = numel(Fraw);  ii = (1:T).';
cs = [0; cumsum(Fraw)];  lo = max(ii-w, 1);
base = (cs(ii+1) - cs(lo)) ./ (ii - lo + 1);    % trailing causal mean over <= w+1 samples
y = (Fraw - base) ./ base * 100;
y(1:w) = NaN;                                   % ignore warm-up (garbage baseline)
ok = true;
end

function s = ternstr_ols(cond, a, b)
if cond; s = a; else; s = b; end
end

function cmap = local_bwr()
% blue-white-red diverging map for signed weights
n = 128;
cmap = [[linspace(0.20,1,n)' linspace(0.35,1,n)' linspace(0.85,1,n)']; ...
        [linspace(1,0.85,n)' linspace(1,0.20,n)' linspace(1,0.15,n)']];
end

function b = cd_lasso_ols(G, c, dg, l1frac, l2frac)
% Coordinate-descent elastic net on the Gram system (mirrors ols_tf_pipeline's cd_lasso).
%   minimise 0.5*b'Gb - c'b + lam1*|b|_1 + 0.5*lam2*|b|^2
nP = numel(c);
lam_max = max(abs(c));
lam1 = l1frac*lam_max;
lam2 = l2frac*mean(dg);
b = zeros(nP,1);  r = c;                      % r = c - G*b  (b=0 -> r=c)
for sweep = 1:200
    b_old = b;
    for j = 1:nP
        if dg(j) <= 0; continue; end
        rj = r(j) + dg(j)*b(j);               % partial residual for coord j
        bj = sign(rj)*max(abs(rj)-lam1, 0) / (dg(j) + lam2);
        db = bj - b(j);
        if db ~= 0
            r = r - G(:,j)*db;
            b(j) = bj;
        end
    end
    if max(abs(b-b_old)) < 1e-8*max(1,max(abs(b))); break; end
end
end
