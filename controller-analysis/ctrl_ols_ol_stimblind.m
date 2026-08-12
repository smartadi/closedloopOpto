% ctrl_ols_ol_stimblind.m -- STAGE 2: OL contra->ipsi stim-blind decomposition.
%
% GOAL (user, 2026-07-19)
%   Predict the ipsi laser-site trace during OPEN-LOOP stim trials from contra pixels that are
%   COMPLETELY UNAFFECTED by the stim. The residual (Actual - Global) then measures the LOCAL
%   stim effect that is NOT shared with the contralateral hemisphere.
%
% METHOD (pure unaffected-pixel selection -- user's chosen approach, no weight constraint)
%   1. Rebuild the spontaneous contra->ipsi setup from the Stage 1 cache (site, ROI, grid, frames).
%   2. Detect stim-AFFECTED contra grid pixels on the OL trials by the MANUAL dip-score threshold
%      (identical definition to ctrl_affected_gui.m: trial-avg %dF trace, score = (trough-onset_ref)/
%      pre_SD, affected where score < -aff_dip_thr). Drop them -> "completely unaffected" set.
%   3. Fit DENSE OLS on SPONTANEOUS (laser-off) frames using ONLY unaffected px  -> Global.
%   4. Deploy on OL trials: Actual = measured ipsi; Global = unaffected-contra prediction
%      (the network-shared, ongoing-state component); Local = Actual - Global (the local part).
%   5. Report how much of the ipsi dip the residual captures  ==  how LOCAL the effect is.
%      (On m4, aff_dip_thr=1.33 -> 151 genuinely-flat contra px: Global stays ~flat through stim,
%       so Local captures ~89% (transient) / ~94% (sustained) of the ipsi dip. I.e. with stim-BLIND
%       contra pixels the laser-site inhibition is almost entirely LOCAL, NOT network-shared.
%       The spont held-out R^2 drops 0.87->0.68 because the best predictors -- the homotopic midline
%       pixels -- are precisely the ones that dip and get dropped. That tradeoff is the pure-pixel
%       choice; the KKT stim-blind constraint (deliberately NOT used) would keep them and force 100%.)
%
% PREREQS
%   Run ctrl_ols_spont.m (Stage 1) first for THIS session -> data/ctrl_ols_spont_<sess>.mat.
%   Needs `mouse`,`fields` in the workspace (load_sessions.m) for the session's d/data.
%
% SECTIONS: [CFG] [LOAD] [AFFECTED] [FIT] [DEPLOY] [FIG] [SAVE]

%% [CTRL-OL-CFG] knobs ---------------------------------------------------------
selField    = 4;         % session index into `fields` (must match a Stage 1 run)
% BATCH override (see ctrl_ols_spont.m): set by imp_xsess_build for the cross-session sweep.
if exist('BATCH_selField','var') && ~isempty(BATCH_selField); selField = BATCH_selField; end
nSV_load    = 500;
Fs          = 35;
% STIM-AFFECTED contra px: decided by utils/ctrl_affected_detect.m -- the SINGLE detector shared
% with ctrl_affected_gui.m, so the rule you tune in the GUI is the rule that builds the predictor
% (before 2026-08-10 each script carried its own copy of the formula and they could drift).
% Default method 'dip': trial-averaged %dF trace, score = (trough - onset_ref)/pre_SD, affected
% where score < -aff_dip_thr. Adaptive/permutation selection was tried and rejected 2026-07-20.
aff_dip_thr = 1.33;      % 'dip' mode only. OVERRIDDEN by the GUI-saved threshold if present.
det_method  = 'least_affected';   % PRIMARY since 2026-08-10. 'dip' = the old absolute cut.
% WHY THE DEFAULT CHANGED. The absolute cut asks for contra pixels the laser does not reach. In
% controller sessions the MEDIAN contra pixel dips 1-4 pre-window SDs -- contralateral
% co-suppression is real and distributed -- so the cut deleted 70-99% of the grid, left 2-26
% predictor pixels, and only 1 of 13 sessions cleared ctrl_r2_floor(). Worse, the deployed R^2 then
% measured how strongly that session co-suppressed (Spearman(%flagged, R^2) = -0.819, p=0.0011)
% rather than anything about the model. RESEARCH 2026-08-10. The rank rule keeps the K LEAST
% affected pixels instead, with K chosen per session by ctrl_select_k as the smallest count that
% still clears the floor -- the most stim-blind predictor that is still usable. The bleed that
% remains is REPORTED (bleed_kept, and the Global `leak` below), not assumed away.
keep_n      = [];        % [] = choose K automatically via ctrl_select_k (recommended).
                         % Set a number to pin K by hand (e.g. to reproduce an old cache).
det_extra   = struct();  % extra detector knobs for non-'dip' methods (cos_thr, thr_lo, tmpl, ...)
% BATCH override: ctrl_residual_build.m sets BATCH_detect to sweep the detector without editing
% this file. Fields present in BATCH_detect win over everything above, including the saved thr.
if exist('BATCH_detect','var') && isstruct(BATCH_detect) && ~isempty(fieldnames(BATCH_detect))
    det_extra = BATCH_detect;
    if isfield(det_extra,'method'), det_method = det_extra.method; end
end
pre_sd_s    = 6.0;       % baseline-SD window for the score  [-6,0] s
ref_s       = 1.0;       % onset-reference window  [-1,0] s
trough_s    = 0.5;       % sliding-window length for the trough (s)
pre_s       = 1.0;       % pre-stim baseline window for the DECOMPOSITION (s)
dip_tran_s  = 0.5;       % transient dip window [0,dip_tran_s] s (capture report)
rng(7,'twister');

% TARGET for the contra->ipsi regression (the ipsi trace G is trained to predict):
%   'canonical' = the paper's referenced ipsi trace data.dFk (ref=-5 is defined in THIS scale) <-- USE
%   'yfull'     = SVD raw-kernel + rolling-baseline reconstruction (legacy; ~1.5x scale, overshoots ref)
% The legacy y_full is only ~0.9-correlated with data.dFk and ~1.5x its amplitude, so ||A-ref|| in
% y_full units is invalid (CL overshoots ref). Regress onto data.dFk so A and G share the ref frame.
target_mode = 'canonical';

assert(exist('mouse','var') && exist('fields','var'), ...
    '[CTRL-OL] run controller-analysis/load_sessions.m first (need `mouse`,`fields`).');

here = fileparts(mfilename('fullpath'));
if isempty(here) || contains(here,tempdir,'IgnoreCase',true) || contains(here,'Editor_','IgnoreCase',true)
    here = fullfile(pwd,'controller-analysis');  if ~exist(here,'dir'); here = pwd; end
end
dataDir = fullfile(here,'data');
paper_root = fullfile(here,'..','paper');
fig_dir = fullfile(paper_root,'images','predictor_saga'); if ~exist(fig_dir,'dir'); mkdir(fig_dir); end

%% [CTRL-OL-LOAD] Stage 1 cache + U/V + rebuild target ------------------------
fld = fields{selField};
d_s  = mouse.(fld).d;  data = mouse.(fld).data;
mn = mouse.(fld).mn; td = mouse.(fld).td; en = mouse.(fld).en;
sess_tag = sprintf('%s_%s%s_e%d', mn, td(6:7), td(9:10), en);

% Selection committed in ctrl_affected_gui.m ("Build predictor"), if any. Adopted ONLY when it was
% saved under the method now in force -- a pre-2026-08-10 file holds a dip-score threshold with no
% `det` field, and silently reading 1.13 as a K (or as a threshold under the rank rule) would build
% a completely different pixel set from the one that number ever meant.
thr_file = fullfile(dataDir, sprintf('ctrl_aff_thr_%s.mat', sess_tag));
if exist(thr_file,'file')
    Tt = load(thr_file);
    saved_method = 'dip';                                   % legacy files predate the field
    if isfield(Tt,'det') && isstruct(Tt.det) && isfield(Tt.det,'method')
        saved_method = Tt.det.method;
    end
    if strcmpi(saved_method, det_method)
        aff_dip_thr = Tt.aff_dip_thr;
        if isfield(Tt,'det') && isstruct(Tt.det)
            fn = setdiff(fieldnames(Tt.det), {'method','thr','wlen'});
            for q = 1:numel(fn)
                if ~isfield(det_extra, fn{q}); det_extra.(fn{q}) = Tt.det.(fn{q}); end
            end
        end
        fprintf('[CTRL-OL] adopting GUI-committed selection (method ''%s'') from %s\n', det_method, thr_file);
    else
        fprintf(['[CTRL-OL] IGNORING %s: it was committed under method ''%s'', this run uses ''%s''. ' ...
                 'Re-commit in the GUI if you want a hand-picked selection.\n'], ...
                thr_file, saved_method, det_method);
    end
else
    fprintf('[CTRL-OL] no committed selection for %s -- method ''%s'', selection chosen automatically.\n', ...
        sess_tag, det_method);
end
% BATCH_detect (ctrl_residual_build.m) wins over everything above.
if exist('BATCH_detect','var') && isstruct(BATCH_detect)
    if isfield(BATCH_detect,'thr') && ~isempty(BATCH_detect.thr)
        aff_dip_thr = BATCH_detect.thr;
        fprintf('[CTRL-OL] threshold overridden by BATCH_detect.thr = %.2f\n', aff_dip_thr);
    end
    if isfield(BATCH_detect,'keep_n') && ~isempty(BATCH_detect.keep_n)
        keep_n = BATCH_detect.keep_n;
        fprintf('[CTRL-OL] K pinned by BATCH_detect.keep_n = %d\n', keep_n);
    end
end

s1_file = fullfile(dataDir, sprintf('ctrl_ols_spont_%s.mat', sess_tag));
assert(exist(s1_file,'file')>0, '[CTRL-OL] Stage 1 cache missing: %s -- run ctrl_ols_spont.m first.', s1_file);
S1 = load(s1_file);
gridIdx = S1.gridIdx;  grR = S1.grR;  grC = S1.grC;  nG = S1.nG;
px_prim = S1.px_prim;  py_prim = S1.py_prim;  k_prim = S1.k_prim;  horizon = S1.horizon;
frames  = S1.frames;   itr = S1.itr;  ite = S1.ite;  w_warm = S1.w_warm;
contra_mask = S1.contra_mask;  ipsi_mask = S1.ipsi_mask;
fprintf('[CTRL-OL] %s | Stage 1: site [row %d col %d], %d contra grid px, %d spont frames\n', ...
    sess_tag, px_prim, py_prim, nG, numel(frames));

serverRoot = expPath(mn, td, en);
% timestamps-npy fallback for the uncorrected sessions -- see utils/cp_loadUVt.m
[U_cp, V_cp, t_svd, mimg_cp] = cp_loadUVt(serverRoot, nSV_load, d_s.timeBlue);
V_cp = double(V_cp);
[nY_cp, nX_cp] = size(mimg_cp);  nSV_cp = size(U_cp,3);
Uflat = reshape(U_cp, nY_cp*nX_cp, nSV_cp);
t_full = t_svd(:);  nF_m = min(size(V_cp,2), numel(t_full));

% Actual = SVD raw-kernel + rolling baseline at the laser site (same as Stage 1)
[y_full, okY] = local_svd_rolling_dfk(Uflat, V_cp, mimg_cp, px_prim, py_prim, k_prim, horizon, nY_cp, nX_cp);
assert(okY, '[CTRL-OL] target rebuild failed at [row %d col %d].', px_prim, py_prim);

% --- select regression TARGET: referenced canonical data.dFk (ref=-5) or legacy y_full ---
switch target_mode
    case 'canonical'
        ytrace = data.dFk(:);                              % paper getpixel_dFoF trace (ref=-5 frame)
        % data.dFk can be a frame or two short of the SVD (m8: 42614 vs 42615) -- the two
        % come from different readers of the same acquisition. Clamp for a small shortfall,
        % error only if the mismatch is big enough to mean a genuinely different recording.
        if numel(ytrace) < nF_m
            assert(nF_m - numel(ytrace) <= 10, ...
                '[CTRL-OL] data.dFk (%d) shorter than SVD frames (%d) by %d -- not a rounding difference.', ...
                numel(ytrace), nF_m, nF_m - numel(ytrace));
            fprintf('[CTRL-OL] data.dFk is %d frame(s) short of the SVD -- clamping to %d frames.\n', ...
                nF_m - numel(ytrace), numel(ytrace));
            nF_m = numel(ytrace);
            % Stage 1 chose its spontaneous `frames` against the longer SVD, so a trailing
            % frame can now be out of range. Drop those and remap the train/test index sets
            % (itr/ite index INTO frames, so they must be renumbered, not just filtered).
            keepF = frames <= nF_m;
            if ~all(keepF)
                map = cumsum(keepF);
                itr = map(itr(keepF(itr)));  ite = map(ite(keepF(ite)));
                frames = frames(keepF);
                fprintf('[CTRL-OL] dropped %d out-of-range spontaneous frame(s) after clamping.\n', nnz(~keepF));
            end
        end
        vvc = (w_warm+1):min(numel(ytrace),numel(y_full));
        fprintf('[CTRL-OL] TARGET = canonical data.dFk (ref-referenced).  corr(y_full,dFk)=%.3f  scale y_full/dFk=%.2f\n', ...
            corr(y_full(vvc),ytrace(vvc),'rows','complete'), std(y_full(vvc),'omitnan')/std(ytrace(vvc),'omitnan'));
    case 'yfull'
        ytrace = y_full;
        fprintf('[CTRL-OL] TARGET = legacy y_full (SVD rolling recon; NOT ref-referenced).\n');
    otherwise
        error('[CTRL-OL] unknown target_mode ''%s''.', target_mode);
end

% contra grid timecourses (dF reconstruction), full session
Xg_full = double(Uflat(gridIdx,:)) * V_cp;                 % [nG x T]

%% [CTRL-OL-AFFECTED] detect stim-affected contra px on OL trials (dip-score, matches GUI) ---
dur  = S1.trial_dur;  post = round(dur*Fs);
pre_sd = round(pre_sd_s*Fs);  ref_n = round(ref_s*Fs);  wlen = max(1,round(trough_s*Fs));

% onsets, filtered by the larger (SD) margin so both detection & decomposition windows fit
ol_starts = sort(d_s.stimStarts(data.nc(:)));
onF = zeros(numel(ol_starts),1);
for j = 1:numel(ol_starts), [~,onF(j)] = min(abs(t_full - ol_starts(j))); end
onF = onF(onF>pre_sd & onF+post<=nF_m);  nTr = numel(onF);

% dip-score windows (relative to onset) -- IDENTICAL to ctrl_affected_gui.m
relA  = -pre_sd:post;  nRelA = numel(relA);
iPre  = find(relA>=-pre_sd & relA<0);           % [-6,0)  baseline SD
iRef  = find(relA>=-ref_n  & relA<0);           % [-1,0)  onset reference
iStim = find(relA>=0 & relA<=post);             % [0,dur] stim
mIg   = max(mimg_cp(gridIdx),eps);
periAvg = zeros(nG,nRelA);
for j = 1:nTr, periAvg = periAvg + Xg_full(:,onF(j)+relA); end
periAvg = (periAvg/nTr)./mIg*100;               % trial-avg %dF (NOT baseline-sub) -- matches GUI
detW            = struct('iPre',iPre,'iRef',iRef,'iStim',iStim);
det_opts        = det_extra;
det_opts.method = det_method;
det_opts.thr    = aff_dip_thr;
det_opts.wlen   = wlen;
if ~isempty(keep_n); det_opts.keep_n = keep_n; end

% --- choose K, when the rank rule is in use and K was not pinned --------------------
% The Gram is built over the SAME spontaneous frames and train/test split as the fit below, so the
% R^2 the selector optimises is exactly the R^2 the fit will report (verified bit-identical).
KSEL = struct('used',false,'reachable',true,'K_star',NaN,'R2_star',NaN,'R2_ceiling',NaN);
[pred_suffix, pred_mode] = ctrl_pred_tag();     % 'rank' (default) | 'ridge' -- see utils/ctrl_pred_tag
useRidge = strcmpi(pred_mode,'ridge');
if useRidge
    % RIDGE MODEL: no pixel is dropped, so there is no K to choose. The detector still RUNS --
    % its score is the diagnostic that says how much bleed the kept set carries, and it is what
    % the two models are compared on. It just no longer decides membership.
    det_opts.method = 'least_affected';
    det_opts.keep_n = nG;
    fprintf('[CTRL-OL] predictor mode = RIDGE: whole grid kept, lambda chosen from catch windows.\n');
end
if ~useRidge && strcmpi(det_method,'least_affected') && ~isfield(det_opts,'keep_n')
    score_opts = det_opts;  score_opts.method = 'dip';        % the score is method-independent
    DET0  = ctrl_affected_detect(periAvg, detW, score_opts);
    FGRAM = ctrl_gram_build(Xg_full, frames, itr, ite, ytrace);
    sel_opts = struct();
    if isfield(det_opts,'max_bleed'); sel_opts.max_bleed = det_opts.max_bleed; end
    KSEL = ctrl_select_k(FGRAM, DET0.score, sel_opts);
    KSEL.used = true;
    det_opts.keep_n = KSEL.K_star;
    clear FGRAM DET0
end

DET = ctrl_affected_detect(periAvg, detW, det_opts);
dipScore = DET.score;                           % negative = dip
affected = DET.affected;                        % DROP these -- they see the laser
unaff    = DET.unaff;
fprintf('[CTRL-OL] affected contra px: %d/%d [%s: %s] -> %d kept | residual bleed: median %+.2f, worst %+.2f\n', ...
    nnz(affected), nG, DET.method, DET.note, nnz(unaff), DET.bleed_kept, DET.bleed_worst);
if nnz(unaff) < 20
    warning('[CTRL-OL] only %d predictor px kept -- selection is too strict to fit %d weights.', nnz(unaff), nnz(unaff));
end

% decomposition windows (baseline [-1,0]s), used by DEPLOY below
pre  = round(pre_s*Fs);  rel = -pre:post;  nRel = numel(rel);
bwin = 1:pre;                                   % baseline [-1,0]s
twin = pre+1:pre+round(dip_tran_s*Fs);          % transient [0,dip_tran]s
swin = pre+1:pre+post;                          % sustained [0,dur]s

%% [CTRL-OL-FIT] dense OLS on spontaneous, UNAFFECTED px only -----------------
Su = find(unaff);
Xs = Xg_full(Su, frames);
mu = mean(Xs(:,itr),2);  sd = std(Xs(:,itr),0,2);  sd(sd==0) = 1;   % TRAIN z-score
Ztr = ((Xs(:,itr)-mu)./sd).';  Zte = ((Xs(:,ite)-mu)./sd).';
ys = ytrace(frames);  ytr = ys(itr);  yte = ys(ite);  muY = mean(ytr);
r2f = @(y,yh) 1 - sum((y(:)-yh(:)).^2)/max(sum((y(:)-mean(y(:))).^2),eps);
RPATH = struct('used',false);
if useRidge
    % Whole grid, weights shrunk, lambda picked from LASER-OFF catch windows only. The Gram is
    % built over the same frames and split as the direct fit above, so R^2 is the same number by
    % the same definition -- only the estimator changed.
    FG    = ctrl_gram_build(Xg_full, frames, itr, ite, ytrace);
    % Catch windows need CONTIGUOUS laser-off stretches, and `frames` may be a decimated subsample
    % (ctrl_ols_spont caps at 60000 by even spacing), which has no contiguity at all. Rebuild the
    % un-decimated laser-off mask from the onsets, using the same rule ctrl_ols_spont used, and
    % hand it over. Only window admissibility uses it; the fit still uses `frames` via the Gram.
    rp_opts = struct();
    rp_opts.spontMask = local_spont_mask(S1.ons, S1.trial_dur, S1.settle_s, Fs, nF_m, w_warm);
    RPATH = ctrl_ridge_path(FG, Xg_full, frames, rel, bwin, swin, rp_opts);
    RPATH.used = true;
    b     = RPATH.b_star;
    R2_te = RPATH.R2te_star;  R2_tr = RPATH.R2tr_star;
    clear FG
    fprintf(['[CTRL-OL] Global predictor (RIDGE, %d px, lambda* %.3g): held-out spont R^2 = ' ...
             '%.3f (train %.3f), ||b|| %.1f\n'], numel(Su), RPATH.lambda_star, R2_te, R2_tr, RPATH.nrm_star);
else
    b  = (Ztr.'*Ztr + 1e-6*mean(sum(Ztr.^2))*eye(numel(Su))) \ (Ztr.'*(ytr-muY));
    R2_te = r2f(yte, muY+Zte*b);  R2_tr = r2f(ytr, muY+Ztr*b);
    fprintf('[CTRL-OL] Global predictor (dense OLS, %d unaffected px): held-out spont R^2 = %.3f (train %.3f)\n', ...
        numel(Su), R2_te, R2_tr);
end
% ADMISSION GATE (ctrl_r2_floor, single source of truth). Not an error: the cache is still written
% so the session can be inspected, but gate_pass travels with it and the cross-session batch
% excludes failures. A Global this weak hands its own prediction error to Local.
r2_floor = ctrl_r2_floor();
gate_pass = R2_te >= r2_floor;
if gate_pass
    fprintf('[CTRL-OL] gate: R^2 %.3f >= floor %.2f -> PASS\n', R2_te, r2_floor);
elseif KSEL.used && ~KSEL.reachable
    % Not a tuning failure: the FULL grid on this session already falls short, so no pixel count
    % can pass. Report it as a session property rather than sending the user back to a slider.
    warning(['[CTRL-OL] gate FAIL: held-out R^2 %.3f < floor %.2f, and the full-grid CEILING is ' ...
             'only %.3f -- no pixel set on %s can clear the floor. This is a property of the ' ...
             'session (predictor capacity), not of the selection.'], ...
            R2_te, r2_floor, KSEL.R2_ceiling, sess_tag);
else
    warning(['[CTRL-OL] gate FAIL: held-out R^2 %.3f < floor %.2f. Inspect the K sweep in ' ...
             'ctrl_affected_gui.m, or pin a larger keep_n.'], R2_te, r2_floor);
end

%% [CTRL-OL-VAL] held-out fit snippet, cached so the fit figure needs no session reload -------
% The held-out prediction had never been stored -- only the R^2 it produces -- so "is this fit
% any good" could not be answered without re-opening a 1-3.5 GB session. Store the test-block
% actual/predicted (a contiguous stretch for the trace panel, subsampled for the scatter) and
% ctrl_fit_figs.m draws every session from the caches alone.
VAL = struct();
VAL.yte = yte(:);  VAL.yhat = muY + Zte*b;  VAL.te_frames = reshape(frames(ite),[],1);
VAL.R2_te = R2_te;
nSnip = min(numel(VAL.yte), round(60*Fs));                 % first ~60 s of the test block
VAL.snip = 1:nSnip;
nSub = min(numel(VAL.yte), 5000);                          % scatter subsample, deterministic
VAL.sub = unique(round(linspace(1, numel(VAL.yte), nSub)));

% Global over all frames = counterfactual ipsi from unaffected contra ongoing state
Gall = muY + (((Xg_full(Su,:)-mu)./sd).') * b;             % [T x 1]

%% [CTRL-OL-DEPLOY] OL Actual / Global / Local -------------------------------
A_tr = zeros(nTr,nRel);  G_tr = zeros(nTr,nRel);
for j = 1:nTr
    A_tr(j,:) = ytrace(onF(j)+rel).';
    G_tr(j,:) = Gall(onF(j)+rel).';
end
bl = @(M) M - mean(M(:,bwin),2);                          % per-trial baseline-subtract
A_tr = bl(A_tr);  G_tr = bl(G_tr);  L_tr = A_tr - G_tr;   % Local = Actual - Global, per trial
Aa = mean(A_tr,1);  Gg = mean(G_tr,1);  Lo = mean(L_tr,1);% trial averages

% capture over transient + sustained windows
capt = @(win) 100*mean(Lo(win))/mean(Aa(win));
leak = @(win) 100*mean(Gg(win))/mean(Aa(win));
[trough,imn] = min(Aa);
fprintf('\n[CTRL-OL] OL trial-avg decomposition (n=%d), baseline-subtracted:\n', nTr);
fprintf('   window        Actual   Global   Local   | Local capture / Global (network) share\n');
fprintf('   transient[0,%.1fs]  %6.3f  %6.3f  %6.3f |  %3.0f%% local  /  %3.0f%% shared\n', ...
    dip_tran_s, mean(Aa(twin)),mean(Gg(twin)),mean(Lo(twin)), capt(twin), leak(twin));
fprintf('   sustained[0,%ds]   %6.3f  %6.3f  %6.3f |  %3.0f%% local  /  %3.0f%% shared\n', ...
    dur, mean(Aa(swin)),mean(Gg(swin)),mean(Lo(swin)), capt(swin), leak(swin));
fprintf('   trough @%.2fs      %6.3f  %6.3f  %6.3f\n', rel(imn)/Fs, Aa(imn),Gg(imn),Lo(imn));
% per-trial Local dip distribution (transient)
Ldip = mean(L_tr(:,twin),2);
fprintf('   per-trial Local dip (transient): median %.3f, IQR [%.3f %.3f]\n', ...
    median(Ldip), prctile(Ldip,25), prctile(Ldip,75));

%% [CTRL-OL-FIG] decomposition + affected map --------------------------------
tt = rel/Fs;
figD = figure('Color','w','Position',[70 70 1250 480]);
tl = tiledlayout(figD,1,2,'TileSpacing','compact','Padding','compact');

nexttile(tl,1); hold on;                                  % decomposition
sdA = std(A_tr,0,1)/sqrt(nTr);
fill([tt fliplr(tt)],[Aa+sdA fliplr(Aa-sdA)],[0 0 0],'FaceAlpha',0.12,'EdgeColor','none');
plot(tt,Aa,'k-','LineWidth',1.8);
plot(tt,Gg,'-','Color',[0.85 0.4 0.1],'LineWidth',1.4);
plot(tt,Lo,'-','Color',[0.1 0.5 0.85],'LineWidth',1.4);
xline(0,'k:'); yline(0,'k:'); xlim([-pre_s dur]);
xlabel('time from stim (s)'); ylabel('\DeltaF/F (%)');
legend({'\pmSEM','Actual','Global (unaffected contra)','Local = residual'},'Box','off','Location','southwest');
title(sprintf('OL contra\\rightarrowipsi: Local %.0f%% local / Global %.0f%% shared (transient)', capt(twin), leak(twin)));

nexttile(tl,2); hold on;                                  % affected map (SESSION VIEW, see cp_orient)
if isfield(S1,'Torient'), Tor = S1.Torient; else, Tor = []; end   % [] = native, pre-orientation caches
gg = mat2gray(cp_orient_img(Tor, mimg_cp)); image(repmat(gg,1,1,3)); axis image ij off;
[uR,uC] = cp_orient_fwd(Tor, grR(unaff),   grC(unaff));
[aR,aC] = cp_orient_fwd(Tor, grR(affected),grC(affected));
[sR,sC] = cp_orient_fwd(Tor, px_prim, py_prim);
scatter(uC, uR, 16, [0.2 0.6 0.9], 'filled', 'MarkerFaceAlpha',0.5);   % unaffected
scatter(aC, aR, 34, [0.9 0.2 0.1], 'filled');                          % affected
plot(sC, sR, 'g+', 'MarkerSize',13, 'LineWidth',2.2);
title(sprintf('contra grid: %d unaffected (blue) / %d affected (red) + site', nnz(unaff), nnz(affected)));

sgtitle(figD, sprintf('[CTRL-OL] stim-blind (pure unaffected-pixel)  %s  (%d OL trials)', ...
    strrep(sess_tag,'_','\_'), nTr));
fig_png = fullfile(fig_dir, sprintf('ctrl_ol_stimblind_%s.png', sess_tag));
exportgraphics(figD, fig_png, 'Resolution', 300);
fprintf('[CTRL-OL-FIG] -> %s\n', fig_png);

%% [CTRL-OL-SAVE] --------------------------------------------------------------
OL = struct();
OL.sess_tag=sess_tag; OL.selField=selField;
OL.affected=affected; OL.unaff=unaff; OL.dipScore=dipScore; OL.aff_dip_thr=aff_dip_thr;
% the exact detector that produced `affected` -- without this the pixel set is not reproducible
OL.det=DET.opts; OL.det_method=DET.method; OL.det_note=DET.note; OL.det_cosSim=DET.cosSim;
OL.rank=DET.rank; OL.nKept=DET.nKept;
% RESIDUAL BLEED -- must be quoted with any Local share built on this cache. `bleed_kept` is how
% affected the predictor pixels still are; `leak_*` is the consequence, i.e. how much the Global
% trace itself dips through the stim. Global dipping means Local UNDER-reports the local effect.
OL.bleed_kept=DET.bleed_kept; OL.bleed_worst=DET.bleed_worst;
OL.leak_sus=leak(swin); OL.leak_tran_w=leak(twin);
% how K was chosen (empty-ish struct when K was pinned or the 'dip' rule was used)
OL.KSEL=KSEL; OL.K_star=KSEL.K_star; OL.R2_ceiling=KSEL.R2_ceiling; OL.K_reachable=KSEL.reachable;
OL.b=b; OL.mu=mu; OL.sd=sd; OL.muY=muY; OL.Su=Su; OL.target_mode=target_mode;
OL.R2_te=R2_te; OL.R2_tr=R2_tr; OL.r2_floor=r2_floor; OL.gate_pass=gate_pass;
OL.onF=onF; OL.rel=rel; OL.pre=pre; OL.Fs=Fs;
OL.A_tr=A_tr; OL.G_tr=G_tr; OL.L_tr=L_tr; OL.Aa=Aa; OL.Gg=Gg; OL.Lo=Lo;
OL.capt_tran=capt(twin); OL.leak_tran=leak(twin); OL.capt_sus=capt(swin);
OL.px_prim=px_prim; OL.py_prim=py_prim; OL.gridIdx=gridIdx; OL.grR=grR; OL.grC=grC;
OL.pred_mode=pred_mode; OL.RPATH=RPATH; OL.VAL=VAL;
if RPATH.used
    OL.lambda=RPATH.lambda_star; OL.lambda_abs=RPATH.lambda_abs;
    OL.bnorm=RPATH.nrm_star; OL.catch_def=RPATH.catch_star; OL.catch_falls=RPATH.catch_falls;
    OL.lambda_at_edge=RPATH.at_edge; OL.r2_cost=RPATH.r2_cost;
end
% Suffixed per predictor mode so 'rank' and 'ridge' caches coexist and reverting is one variable
% (utils/ctrl_pred_tag.m). Nothing the rank model built is ever overwritten by the ridge model.
ol_file = fullfile(dataDir, sprintf('ctrl_ols_ol_stimblind%s_%s.mat', pred_suffix, sess_tag));
save(ol_file, '-struct', 'OL', '-v7.3');
fprintf('[CTRL-OL-SAVE] -> %s\n\n', ol_file);

% (the dip score used to live here as local_dip_score; it is now utils/ctrl_affected_detect.m,
%  shared with ctrl_affected_gui.m so the tuned rule and the built rule cannot diverge)

% ---- local helper (copied from ctrl_ols_spont.m; keep in sync) --------------
function [y, ok] = local_svd_rolling_dfk(Uflat, V, mimg, prow, pcol, k, horizon, nY, nX)
% SVD-reconstructed RAW kernel fluorescence -> rolling-baseline dF/F (getpixel mode-0 match).
y = nan(size(V,2),1);  ok = false;
if prow<1||prow>nY||pcol<1||pcol>nX; return; end
kr = max(1,prow-k):min(nY,prow+k);  kc = max(1,pcol-k):min(nX,pcol+k);
[KR,KC] = ndgrid(kr,kc);  kidx = sub2ind([nY,nX], KR(:), KC(:));
mI = mean(mimg(kr,kc),'all');
if ~isfinite(mI) || abs(mI) < eps; return; end
Fsvd = mean(double(Uflat(kidx,:)),1) * V;
Fraw = mI + Fsvd(:);
w = max(1, round(horizon)-1);  T = numel(Fraw);  ii = (1:T).';
cs = [0; cumsum(Fraw)];  lo = max(ii-w,1);
base = (cs(ii+1)-cs(lo))./(ii-lo+1);
y = (Fraw - base)./base*100;  y(1:w) = NaN;
ok = true;
end

function m = local_spont_mask(ons, trial_dur, settle_s, Fs, nF_m, w_warm)
% Un-decimated laser-off mask over 1..nF_m, replicating ctrl_ols_spont's own rule: a frame is
% spontaneous from (onset + trial_dur + settle_s) until 2 frames before the next onset, plus the
% stretch before the first onset, minus the rolling-baseline warm-up.
% Deliberately NOT the isfinite(y_full) filter ctrl_ols_spont also applies -- that one only ever
% removes warm-up NaNs, which w_warm already covers, and applying it here would need the target
% trace threaded in for no gain.
m = false(1, nF_m);
ons = ons(:).';
ons = ons(ons >= 1 & ons <= nF_m);
off0 = round((trial_dur + settle_s)*Fs);
for j = 1:numel(ons)
    i0 = max(ons(j) + off0, 1);
    if j < numel(ons); i1 = ons(j+1) - 2; else; i1 = nF_m; end
    i1 = min(i1, nF_m);
    if i1 >= i0; m(i0:i1) = true; end
end
if ~isempty(ons) && ons(1) > 2; m(1:(ons(1)-2)) = true; end
m(1:min(w_warm, nF_m)) = false;
end
