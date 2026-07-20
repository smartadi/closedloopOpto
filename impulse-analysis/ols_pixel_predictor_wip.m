%% ols_pixel_predictor_wip.m — WIP REPAIR COPY (from 2026-07-06 per-amp version)
% =============================================================================================
% Working copy to REPAIR the stim-blind analysis FROM SCRATCH. The canonical ols_pixel_predictor.m
% has been reverted to its 2026-07-04 (projection) state — do experimental work HERE, not there.
%
% USER DIAGNOSIS / REPAIR TARGETS (2026-07-06):
%  (1) [STIM-BLIND is WRONG — top priority] The per-amp clean-pixel predictor (§17) does the
%      OPPOSITE of the goal: the "clean" contra pixels still predict EVERY detail of the ipsi dip,
%      so Global captures the stim effect and the residual (Local) is near-empty. DESIRED: find the
%      contra pixel set whose prediction is BLIND to the stim, so the residual (Actual - prediction)
%      captures ~100% of the ipsi stim effect. Selecting "least-bled" pixels by energy is NOT
%      enough — network-correlated clean pixels still reconstruct the dip. Need a selection/
%      constraint that removes the stim-PREDICTIVE direction, not just the directly-bled pixels.
%  (2) [FARPIX] The POSITIVE-response population is likely a NON-effect (noise), not a real second
%      population — treat only the negative (dip) population as real coupling.
%  (3) [SETTLETIME] Also capture the REBOUND, not just recovery: rebound has mostly died down by
%      ~770 ms — report/threshold that as the settle landmark.
% =============================================================================================
%
%% ols_pixel_predictor.m — direct-pixel, no-lag OLS contra->ipsi predictor (STANDALONE)
% ==============================================================================
% A fresh, self-contained implementation, INDEPENDENT of the contra_prediction
% RRR pipeline (no redoSVD, no CanonCor2, no reduced rank, no SVD-mode readout).
%
% Predict the ipsi primary pixel from the RAW, CONTEMPORANEOUS (no-lag) activity
% of a tight ~200-pixel regular grid over the contra hemisphere, by ordinary least
% squares:
%       yhat_dF(t) = x_grid(t).' * bpix + b0          (contemporaneous, no lag)
% x_grid(t) = raw activity of the grid pixels at frame t, reconstructed on the fly
% as U(grid,:)*V (never loads the movie). Same interstim spontaneous train/test
% split as [CP-HEMI], so the held-out R^2 is directly comparable to the RRR map.
%
% Reuses only shared DATA utilities (loadUVt / cp_find_stim_site / cp_roi_masks) so
% the data is identical to the pipeline; the PREDICTOR is implemented here inline.
%
% PREREQ: run load_experiments.m first (builds `allExperiments`).
% Run top-to-bottom, or section by section.
% ==============================================================================


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
                      %   STIMBLIND-GREEDY so the dip window has ONE source of truth.
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
RUN_ALLSESS   = false; % §19: OFF by default in this WIP — §19's engine local_stimblind_session still
                      %   uses the OLD per-amp drop-bled method (NOT the new §17 greedy). Leave off
                      %   until §19 is repointed to the greedy selection, or it will mislead.
allSelExp     = [3 1 2];  % sessions for §19 combined run: AL_0033 e3, AL_0041 e1, AL_0041 e2
RUN_SESSION_VIEWER = true;  % §20: open the orientation-normalized interactive map with a session
                      %   picker (pick session -> brain + sparse contra weights; click ipsi to refit).
disp_orient = 'auto'; % DISPLAY orientation of ALL brain-map overlays (§8,§10,§14,§16,§17,§20).
                      %   'auto'      = pick_orient auto-normalizes (ipsi right, midline vertical)
                      %   'transpose' = canonical imagesc(mimg') anatomical view (brain vertical)
                      %   'native'|'rot90'|'rot180'|'rot270'|'fliplr'|'flipud' = fixed dihedral view
                      % DISPLAY-ONLY: overlay + grid + click-to-refit follow the SAME transform, so
                      % pixel selection is unaffected by this choice (proven consistent for any op).

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

%% (2) Load SVD + session params
y_full  = allExperiments(selExp).dF(:);
t_full  = allExperiments(selExp).timeBlue(:);
serverRoot = expPath(mn, td, en);
[U_cp, V_cp, ~, mimg_cp] = loadUVt(serverRoot, nSV_load);
[nY_cp, nX_cp] = size(mimg_cp);
nSV_cp = size(U_cp, 3);

d_tmp   = loadData(serverRoot, mn, td, en);
py_prim = double(d_tmp.params.pixel(1));
px_prim = double(d_tmp.params.pixel(2));
k_prim  = double(d_tmp.params.kernel);
clear d_tmp

%% (3) Data-derived photostim site + retarget y_full (same as [CP-SITE])
if USE_DATA_SITE
    site_file = fullfile(dataDir, sprintf('cp_stim_site_%s_%s%s_e%d.mat', mn, td(6:7), td(9:10), en));
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

%% (4) Contra (predictor) hemisphere mask + stim-onset list
% REUSE the existing mask — never redraw here. Priority: (a) a contra mask already in
% the workspace (valid_cp_svd, from contra_prediction.m); (b) the cached ROI geometry
% (cp_roi2_*.mat, loaded — no draw); (c) error with instructions. The draw GUI only
% ever opens from contra_prediction.m S04, which is the single source of truth.
roi_file = fullfile(dataDir, sprintf('cp_roi2_%s_%s%s_e%d.mat', mn, td(6:7), td(9:10), en));
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

%% (5) Tight ~nGrid pixel regular grid over the contra mask
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

%% (6) Spontaneous interstim frames (post-settle) — same split as [CP-HEMI]
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

%% (7) Precompute the FIXED contra-grid design + fast fit operator
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

% ---- ONE display-orientation transform shared by ALL brain-map overlays (§8,§10,§14,§16,§17) ----
% resolve_orient turns the disp_orient knob into a Torient: 'auto' = pick_orient auto-normalizes
% (ipsi right, midline vertical); any other value forces a fixed dihedral view (e.g. 'transpose' =
% canonical imagesc(mimg')). Every overlay draws Torient.imgOp(mimg) and places grid/site via
% orient_fwd, and clicks invert through the SAME Torient, so the choice is display-only and pixel
% selection is unaffected on any session.
Torient = resolve_orient(disp_orient, contra_mask, ipsi_mask, px_prim, py_prim, nY_cp, nX_cp);
[dspGr, dspGc] = orient_fwd(Torient, grR, grC);            % grid pixels -> display (row,col)
[dspSr, dspSc] = orient_fwd(Torient, px_prim, py_prim);    % laser site  -> display (row,col)
oI_ = Torient.imgOp(mimg_cp);  dspImg = (oI_-min(oI_(:)))/max(max(oI_(:))-min(oI_(:)),eps);  % oriented brain [Hd x Wd]

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
    local_session_viewer(cfgV, allExperiments, allSelExp, preload);
    fprintf('\n[VIEWER] session-picker map (%s): pick a session; click any IPSI pixel -> contra weights refit.\n', fit_mode);
else
    % viewer disabled -> record the site-pixel weights headlessly for the current session
    [bpix, cv, ~, ~, nAct] = ols_refit(D, px_prim, py_prim);
    OLS = struct('gridIdx',gridIdx,'gridRC',[grR grC],'bpix',bpix,'cv',cv,'nG',nG, ...
                 'fit_mode',fit_mode,'l1_frac',l1_frac,'ridge',ridge,'nActive',nAct, ...
                 'mn',mn,'td',td,'en',en);
    fprintf('\n[OLS] viewer off; site-pixel weights recorded: R^2=%.3f, %d/%d px active (%s).\n', cv, nAct, nG, fit_mode);
end

%% (8b) [KERNELMAP] Zhiwen-style static panel: a few ipsi regions -> their prominent CONTRA weights
% Ye/Zhiwen 2023 figure style: pick a handful of ipsi-side target regions and, for EACH, show the
% sparse contra-grid weights that predict it (spont-trained %s OLS = the SAME first model as the §8
% viewer, just static + multi-region instead of interactive single-pixel). Reveals what distributed
% contra structure predicts each ipsi region: active (non-zero, debiased Lasso) px are drawn big &
% color-coded by signed weight; the ~zero px are faint grey so the sparse kernel pops. The green
% pentagram marks the ipsi target of each panel; the first panel is always the laser site.
ipM = logical(D.ipsi);  [ir, ic] = find(ipM);                     % ipsi-mask pixel coords
% spatially-spread ipsi targets: laser site first, then a 3x3 lattice over the ipsi mask snapped in
rq = round(prctile(ir,[22 50 78]));  cq = round(prctile(ic,[25 50 75]));
cand = zeros(numel(rq)*numel(cq),2);  q = 0;
for a = 1:numel(rq)
    for bcol = 1:numel(cq)
        [~,mi] = min((ir-rq(a)).^2 + (ic-cq(bcol)).^2);
        q = q+1;  cand(q,:) = [ir(mi) ic(mi)];
    end
end
targ = unique([px_prim py_prim; cand], 'rows', 'stable');         % site first, then spread (deduped)
nTk = min(6, size(targ,1));  targ = targ(1:nTk,:);
ncK = 3;  nrK = ceil(nTk/ncK);  sMk = linspace(0,1,128)';
figK = figure('Color','w','Name','[KERNELMAP] ipsi regions -> prominent contra weights','Position',[55 55 1320 780]);
for t = 1:nTk
    [bpx, cvk, ~, ~, nAk] = ols_refit(D, targ(t,1), targ(t,2));   % sparse contra weights for this ipsi px
    ax = subplot(nrK,ncK,t); hold(ax,'on');
    image(ax, repmat(dspImg,[1 1 3]));  axis(ax,'image','off');  set(ax,'YDir','reverse');
    colormap(ax, [[sMk sMk ones(128,1)];[ones(128,1) 1-sMk 1-sMk]]);   % blue -> white -> red
    act = bpx~=0;  wsc = max(abs(bpx)) + eps;
    scatter(ax, dspGc(~act), dspGr(~act), 5, [.62 .62 .62],'filled','MarkerFaceAlpha',0.30);  % ~zero px
    sz = 24 + 130*(abs(bpx)/wsc);
    scatter(ax, dspGc(act), dspGr(act), sz(act), bpx(act),'filled','MarkerEdgeColor',[.15 .15 .15],'LineWidth',0.3);
    clim(ax, [-wsc wsc]);
    [tr,tc] = orient_fwd(Torient, targ(t,1), targ(t,2));          % this panel's ipsi target -> display
    plot(ax, tc, tr, 'p','MarkerSize',15,'MarkerFaceColor',[0 1 0],'MarkerEdgeColor','k','LineWidth',0.8);
    ttl = 'ipsi region';  if t==1, ttl = 'laser SITE'; end
    title(ax, sprintf('%s [r%d c%d]  R^2=%.2f, %d px', ttl, targ(t,1), targ(t,2), cvk, nAk), 'FontSize',8,'FontWeight','bold');
end
sgtitle(figK, sprintf('KERNELMAP  %s %s e%d  —  sparse CONTRA weight map predicting each ipsi region (%s, l1=%.2f)   [green pentagram = ipsi target; marker size = |weight|]', ...
    mn,td,en,D.fit_mode,l1_frac), 'FontWeight','bold','FontSize',9);
fprintf('\n[KERNELMAP] %d ipsi regions -> per-region sparse contra weight maps (site + %d spread targets).\n', nTk, nTk-1);

%% (10) [AFFECT] TASK 2 — per-amp IMPULSE-RESPONSE detection (matched filter to the stim impulse)
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
% shutter/galvo command artifact, but the PRIMARY §17 stim-blind model baselines per-trial
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
mResp = nan(nG,Wb,nA);  nT_amp = zeros(nA,1);  onFcell = cell(nA,1);
for ai = 1:nA
    onF = local_onsets(imp_data.startTimes{find(uAmp==amps(ai),1)}(:), t_full, preN, postN, nFall);
    nT = numel(onF);  nT_amp(ai) = nT;  onFcell{ai} = onF;
    if nT==0, continue; end
    mResp(:,:,ai) = local_periavg(Xpct, onF, rel, preN, nG, Wb) - m0;      % evoked EXCESS over 0 V [nG x Wb]
end

% --- data-driven per-amp INHIBITION [onset->recovery] + REBOUND [recovery->settle] windows ---------
% landmarks from the PRIMARY-pixel evoked impulse (cleanest signal), so no hardcoded window is used.
y0tr = double(reshape(y_full(onF0(:).'+rel(:)),Wb,nT0)); y0tr = y0tr - mean(y0tr(1:preN,:),1); y0p = mean(y0tr,2);
inhCols = cell(nA,1);  rebCols = cell(nA,1);  recMs = nan(nA,1);  setMs = nan(nA,1);  mAmpP = nan(Wb,nA);
for ai = 1:nA
    onF = onFcell{ai};  if isempty(onF), continue; end
    tra = double(reshape(y_full(onF(:).'+rel(:)),Wb,numel(onF)));  tra = tra - mean(tra(1:preN,:),1);
    mp  = mean(tra,2) - y0p;  mAmpP(:,ai) = mp;  bsd = std(mp(1:preN));  seg = mp((preN+1):Wb);
    [dTr,iLoc] = min(seg);  iT = preN + iLoc;  tol = max(2*bsd, 0.05*abs(dTr));   % trough + recovery band
    rc = iT - 1 + find(mp(iT:Wb) >= -tol, 1, 'first');                            % recovery = 1st return to baseline
    if isempty(rc) || rc<=preN, rc = min(Wb, preN+round(dip_win_s*Fs)); end
    tolS = max(2*bsd, 0.10*abs(dTr));  lb = find(abs(mp((preN+1):Wb)) > tolS, 1, 'last');  % settle = last excursion
    se = preN + max(lb,1);  if isempty(lb), se = rc; end
    r1 = min(rc+1, Wb);
    inhCols{ai} = (preN+1):rc;  rebCols{ai} = r1:max(r1, se);
    recMs(ai) = rel(rc)/Fs*1000;  setMs(ai) = rel(min(se,Wb))/Fs*1000;
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

% --- per-amplitude map: affected pixels BLACK ------------------------------------
figB = figure('Color','w','Name','BLEED — definitely stim-affected contra pixels (per amp)', ...
    'Units','pixels','Position',[100 60 1200 780]);
gB = dspImg;                                                               % oriented brain (Torient)
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

%% =====================================================================
% §10T [AFFECT-TF-PROTO] -- TF fit to each contra pixel's own impulse response (Framing A)
%   Alternative to §10's matched filter. Fit a low-order continuous-time TF
%   H(s) to a pixel's evoked response (mResp = measured impulse response of a
%   brief stim pulse). A pixel is "dynamically affected by ipsi" iff:
%     (a) fit VAF exceeds the 0V-null (there ARE dynamics to fit), AND
%     (b) the fitted dynamics MATCH the ipsi-site reference TF
%         (onset delay / trough / settle / rebound within tolerance).
%   Bleed  -> good VAF but delay~0, monophasic, no rebound (mismatch => reject).
%   Couple -> delay>0, biphasic dip+rebound tracking the ipsi reference (accept).
%   PROTOTYPE ONLY: runs on a few known-affected + clean pixels at the strong
%   amp to lock the parameterisation + thresholds before any per-pixel rollout.
% =====================================================================
tf_maxPoles = 3;   tf_maxZeros = 2;   tf_maxDelay = 4;   % sweep bounds (delay in samples)
tf_refAmpIdx = nA;                                       % strongest amp = reference dynamics
tf_win  = (preN+1):Wb;                                   % post-onset fit window (dip+rebound)
tf_nBoot = 15;                                           % 0V-null VAF draws (serial, coarse floor sweep)
tf_vafFloor = 40;   tf_matchTol = 0.7;                   % detection: VAF>floor AND delay+trough match<tol
Ts  = 1/Fs;   nPreZ = tf_maxPoles + tf_maxZeros + 2;
tfOptP = tfestOptions('EnforceStability', false, 'Display', 'off');
tfWarnPrev = warning('off','all');                       % suppress tfest goodness warnings ONCE (restored at end of §10T2)
tms = rel/Fs*1000;                                       % peri-onset time axis (ms) — §10T runs before §10b defines it
tms_w  = tms(tf_win);                                    % window time axis (ms), t=0 at onset+1

fprintf('\n[AFFECT-TF] framing-A prototype  (amp %.1f V, win %d..%d ms, sweep %dp/%dz/%dd)\n', ...
        amps(tf_refAmpIdx), round(tms_w(1)), round(tms_w(end)), tf_maxPoles, tf_maxZeros, tf_maxDelay);

% --- reference dynamics: fit TF to the ipsi-site evoked at the strong amp ---
rRef = mAmpP(tf_win, tf_refAmpIdx);   rRef = rRef - rRef(1);
[sysRef, vafRef, chRef, ordRef] = proto_fitTF(rRef, Ts, tf_maxPoles, tf_maxZeros, tf_maxDelay, nPreZ, tfOptP);
fprintf('  REF (ipsi site): VAF=%.1f%%  order=%dp/%dz/%dd  delay=%.0fms trough=%.0fms settle=%.0fms rebRatio=%.2f\n', ...
        vafRef, ordRef(1),ordRef(2),ordRef(3), chRef.delayMs, chRef.troughMs, chRef.settleMs, chRef.reboundRatio);

% --- 0V null VAF floor: fit TF to no-signal 0V segments (parfor; narrowed sweep, sets a floor only) ---
rng(0);  gN = randi(nG, tf_nBoot, 1);  kN = randi(nT0, tf_nBoot, 1);
vafNull = nan(tf_nBoot,1);
for b = 1:tf_nBoot          % serial (parfor routes worker output through the crashing structuredoutput layer)
    rn = squeeze(blk0(gN(b),tf_win,kN(b))).' - m0(gN(b),tf_win).';   rn = rn - rn(1);
    [~, vafNull(b)] = proto_fitTF(rn, Ts, 2,0,2, nPreZ, tfOptP);   % coarse floor sweep
end
vaf95 = prctile(vafNull(~isnan(vafNull)), 95);
fprintf('  0V-null VAF: median=%.1f%%  95th=%.1f%%  (fit must beat this)\n', ...
        median(vafNull,'omitnan'), vaf95);

% --- pick prototype pixels: deepest known-affected + spread of clean ---
aiR   = tf_refAmpIdx;
affPx = find(affected(:,aiR));
[~,ord] = sort(min(mResp(affPx,tf_win,aiR),[],2),'ascend');    % deepest dip first
affPick = affPx(ord(1:min(4,numel(affPx))));
cleanPx = find(~any(affected,2));                              % never affected at any amp
if numel(cleanPx) >= 4, cleanPick = cleanPx(round(linspace(1,numel(cleanPx),4)));
else,                   cleanPick = cleanPx; end
protoPx  = [affPick(:); cleanPick(:)];
protoLbl = [repmat({'aff'},numel(affPick),1); repmat({'clean'},numel(cleanPick),1)];

% dynamic-match distance = delay + trough only (the discriminative pair; VAF & the
% noisy settle/rebound do NOT separate aff from clean -- they are reported, not gated).
mScale  = [40, 80];    % ms tolerances for [delay, trough]
matchOf = @(c) sqrt(mean( ([c.delayMs c.troughMs] - ...
                          [chRef.delayMs chRef.troughMs]).^2 ./ mScale.^2 ));

% --- fit each prototype pixel + tabulate ---
nPx = numel(protoPx);
Tvaf=nan(nPx,1); Tdel=nan(nPx,1); Ttr=nan(nPx,1); Tset=nan(nPx,1); Treb=nan(nPx,1); Tmd=nan(nPx,1);
protoFit = cell(nPx,1);  Tord = nan(nPx,3);
fprintf('  %-4s %-5s %6s %7s %6s %7s %7s %7s %7s\n','g','cls','VAF','order','delay','trough','settle','rebR','matchD');
for i = 1:nPx          % serial
    ri = squeeze(mResp(protoPx(i),tf_win,aiR));  ri = ri(:) - ri(1);
    [sysi, vafi, chi, ordi] = proto_fitTF(ri, Ts, tf_maxPoles, tf_maxZeros, tf_maxDelay, nPreZ, tfOptP);
    protoFit{i} = struct('sys',sysi,'r',ri);  Tord(i,:) = ordi;
    Tvaf(i)=vafi; Tdel(i)=chi.delayMs; Ttr(i)=chi.troughMs; Tset(i)=chi.settleMs; Treb(i)=chi.reboundRatio;
    Tmd(i)=matchOf(chi);
    fprintf('  %-4d %-5s %5.1f%% %2dp%dz%dd %5.0f %6.0f %6.0f %6.2f %6.2f\n', ...
            protoPx(i), protoLbl{i}, Tvaf(i), ordi(1),ordi(2),ordi(3), Tdel(i), Ttr(i), Tset(i), Treb(i), Tmd(i));
end
% --- LOCK canonical order from the affected prototypes (+ ref): fix #poles/#zeros, minimal delay ---
affRows = 1:numel(affPick);
ordPool = [ordRef; Tord(affRows,:)];  ordPool = ordPool(all(~isnan(ordPool),2),:);
if isempty(ordPool), tf_np=2; tf_nz=1; tf_nd=1;                     % fallback
else, tf_np = mode(ordPool(:,1));  tf_nz = mode(ordPool(:,2));  tf_nd = min(ordPool(:,3)); end
fprintf('  >> CANONICAL order locked: %dp/%dz/%dd  (fixed for per-pixel fits in §10T2; delay=min of affected)\n', tf_np,tf_nz,tf_nd);
vafGate = max(tf_vafFloor, vaf95);
tfPass  = (Tvaf > vafGate) & (Tmd < tf_matchTol);          % VAF certifies a real fit; match = ipsi dynamics
fprintf('  detect rule: VAF>%.1f%% AND (delay+trough)match<%.2f  ->  aff pass %d/%d,  clean pass %d/%d\n', ...
        vafGate, tf_matchTol, nnz(tfPass(1:numel(affPick))), numel(affPick), ...
        nnz(tfPass(numel(affPick)+1:end)), numel(cleanPick));

% --- figure: evoked + TF fit overlays (ref, affected, clean) ---
figure('Name','§10T AFFECT-TF prototype','Color','w','Position',[80 80 1180 620]);
tl = tiledlayout(3, max(4,ceil(nPx/2)+1), 'TileSpacing','compact','Padding','compact');
nexttile([1 max(4,ceil(nPx/2)+1)]);
plot(tms_w, rRef,'k','LineWidth',1.6); hold on;
[ypR] = proto_sim(sysRef, numel(tf_win), Ts, nPreZ);
plot(tms_w, ypR,'r--','LineWidth',1.2); yline(0,':','Color',[.6 .6 .6]);
title(sprintf('REF ipsi site  VAF=%.0f%%  delay=%.0f trough=%.0f settle=%.0f rebR=%.2f', ...
      vafRef, chRef.delayMs, chRef.troughMs, chRef.settleMs, chRef.reboundRatio),'FontSize',9);
xlabel('ms'); ylabel('\DeltaF/F'); legend({'evoked','TF fit'},'Location','best','FontSize',7);
for i = 1:nPx
    nexttile;
    plot(tms_w, protoFit{i}.r,'Color',[.2 .2 .2],'LineWidth',1.2); hold on;
    plot(tms_w, proto_sim(protoFit{i}.sys, numel(tf_win), Ts, nPreZ),'--','LineWidth',1.1, ...
         'Color', tern_col(strcmp(protoLbl{i},'aff')));
    yline(0,':','Color',[.7 .7 .7]);
    ttl = sprintf('g%d %s  VAF=%.0f%%\ndel=%.0f md=%.2f %s', protoPx(i), protoLbl{i}, ...
                  Tvaf(i), Tdel(i), Tmd(i), ternstr(tfPass(i),'PASS','--'));
    title(ttl,'FontSize',8); xlabel('ms');
end
sgtitle(sprintf('§10T framing-A: TF per-pixel impulse fit  (amp %.1f V)', amps(aiR)),'FontWeight','bold');

AFFECT_TF_PROTO = struct('amp',amps(aiR),'sysRef',sysRef,'chRef',chRef,'vafRef',vafRef, ...
    'vaf95null',vaf95,'protoPx',protoPx,'protoLbl',{protoLbl},'VAF',Tvaf,'delayMs',Tdel, ...
    'troughMs',Ttr,'settleMs',Tset,'reboundRatio',Treb,'matchD',Tmd,'pass',tfPass, ...
    'win',tf_win,'sweep',[tf_maxPoles tf_maxZeros tf_maxDelay]);
fprintf('[AFFECT-TF] -> AFFECT_TF_PROTO  (review overlays + table before per-pixel rollout)\n');

%% =====================================================================
% §10T2 [AFFECT-TF-FULL] per-pixel x amp TF detection -> affected_tf[nG x nA]  (sibling to §10)
%   Rolls the framing-A TF fit (validated in §10T) across every screened pixel x amp.
%   A pixel is TF-affected iff  VAF>floor  AND  its (delay,trough) match the ipsi
%   reference TF (i.e. it obeys the same LTI dynamics => "dynamically affected by ipsi").
%   Cheap dip pre-screen keeps the tfest count tractable; parfor over candidates.
%   affect_mode toggles which map (§10 matched | §10T2 TF) feeds §17/§17b downstream.
% =====================================================================
affect_mode = 'tf';           % 'matched' (=§10)  |  'tf' (=this cell)
tf_run      = 'full';            % 'full' (real nG x nA map) | 'subset' (~60-cell validation) | 'off'
tf_screenK  = 2.0;                 % candidate if dip < -K * pre-onset sd (cheap gate)
tf_useParfor = false;              % SERIAL by default (parfor worker-output crashes the MCP structuredoutput layer); set true only outside MCP
dipWinT = (preN+1):min(Wb, preN+round(0.35*Fs));

% FIXED canonical order from §10T (tf_np/tf_nz/tf_nd) — every pixel gets the SAME model class,
% one tfest each (no per-pixel sweep): uniform dynamics across contra + ~1 fit/cell.
if ~exist('tf_np','var'), error('run §10T first (it locks the canonical order tf_np/tf_nz/tf_nd).'); end
[sysRef2,vafRef2,chRef2] = proto_fitTF_fix(rRef, Ts, tf_np,tf_nz,tf_nd, nPreZ, tfOptP);
dR = chRef2.delayMs;  tR = chRef2.troughMs;  mScaleR = [40 80];
fprintf('\n[AFFECT-TF-FULL] fixed order %dp/%dz/%dd | ref: VAF=%.1f%% delay=%.0fms trough=%.0fms\n', ...
        tf_np,tf_nz,tf_nd, vafRef2, dR, tR);

sd0g = squeeze(std(mResp(:,1:preN,:),0,2));                 % [nG x nA] pre-onset noise
dipD = squeeze(min(mResp(:,dipWinT,:),[],2));               % [nG x nA] dip depth
cand = dipD < -tf_screenK*max(sd0g,eps);
[cg,ca] = find(cand);  nCall = numel(cg);
switch lower(tf_run)
    case 'off',    sel = [];
    case 'subset', sel = unique(round(linspace(1, nCall, min(60,nCall))));    % evenly-spaced validation subset
    otherwise,     sel = (1:nCall).';   tf_run = 'full';
end
cg = cg(sel);  ca = ca(sel);  nC = numel(cg);
fprintf('  mode=%s: fitting %d/%d screened candidates (K=%.1f, fixed %dp/%dz/%dd)\n', ...
        tf_run, nC, nCall, tf_screenK, tf_np,tf_nz,tf_nd);

tV=nan(nC,1); tMD=nan(nC,1); tDE=nan(nC,1); tTR=nan(nC,1); tSE=nan(nC,1); tRB=nan(nC,1);
mR=mResp; win=tf_win; fnp=tf_np; fnz=tf_nz; fnd=tf_nd; nPz=nPreZ; TsL=Ts; optL=tfOptP;  % parfor locals
tstart=tic;
if tf_useParfor
    parfor c=1:nC
        ri=squeeze(mR(cg(c),win,ca(c))); ri=ri(:)-ri(1);
        [~,v,ch]=proto_fitTF_fix(ri, TsL, fnp,fnz,fnd, nPz, optL);
        tV(c)=v; tDE(c)=ch.delayMs; tTR(c)=ch.troughMs; tSE(c)=ch.settleMs; tRB(c)=ch.reboundRatio;
        tMD(c)=sqrt(mean(([ch.delayMs ch.troughMs]-[dR tR]).^2./mScaleR.^2));
    end
else
    for c=1:nC
        ri=squeeze(mR(cg(c),win,ca(c))); ri=ri(:)-ri(1);
        [~,v,ch]=proto_fitTF_fix(ri, TsL, fnp,fnz,fnd, nPz, optL);
        tV(c)=v; tDE(c)=ch.delayMs; tTR(c)=ch.troughMs; tSE(c)=ch.settleMs; tRB(c)=ch.reboundRatio;
        tMD(c)=sqrt(mean(([ch.delayMs ch.troughMs]-[dR tR]).^2./mScaleR.^2));
    end
end
fprintf('  fit %d candidates in %.0f s (1 tfest/cell, fixed order)\n', nC, toc(tstart));

affected_tf=false(nG,nA);
VAFtf=nan(nG,nA); MDtf=nan(nG,nA); DELtf=nan(nG,nA); TRtf=nan(nG,nA); SETtf=nan(nG,nA); REBtf=nan(nG,nA);
vg=max(tf_vafFloor,vaf95);
for c=1:nC
    g=cg(c); a=ca(c);
    VAFtf(g,a)=tV(c); MDtf(g,a)=tMD(c); DELtf(g,a)=tDE(c); TRtf(g,a)=tTR(c); SETtf(g,a)=tSE(c); REBtf(g,a)=tRB(c);
    affected_tf(g,a)= tV(c)>vg && tMD(c)<tf_matchTol;
end
fitIdx = sub2ind([nG nA], cg, ca);              % linear idx of the cells actually fitted
aM = affected(fitIdx);  aT = affected_tf(fitIdx);
if strcmpi(tf_run,'full')
    fprintf('  per-amp TF-affected: '); fprintf('%d ', sum(affected_tf,1));
    fprintf('(vs §10: '); fprintf('%d ',sum(affected,1)); fprintf(')\n');
end
fprintf('  over %d fitted cells vs §10: both=%d  §10-only=%d  TF-only=%d  neither=%d  (gate VAF>%.0f match<%.2f)\n', ...
        nC, nnz(aM&aT), nnz(aM&~aT), nnz(~aM&aT), nnz(~aM&~aT), vg, tf_matchTol);

if strcmpi(affect_mode,'tf') && strcmpi(tf_run,'full')
    affected = affected_tf;
    fprintf('  affect_mode=tf  ->  affected := affected_tf  (feeds §17/§17b)\n');
elseif strcmpi(affect_mode,'tf')
    fprintf('  affect_mode=tf but tf_run=%s (partial map) -> NOT switching; set tf_run=''full'' first\n', tf_run);
else
    fprintf('  affect_mode=matched  ->  §10 map unchanged  (set affect_mode=''tf'' + tf_run=''full'' to switch)\n');
end

AFFECT_TF = struct('mode',affect_mode,'affected_tf',affected_tf,'VAF',VAFtf,'matchD',MDtf, ...
    'delayMs',DELtf,'troughMs',TRtf,'settleMs',SETtf,'reboundRatio',REBtf, ...
    'chRef',chRef2,'vafRef',vafRef2,'vafGate',vg,'matchTol',tf_matchTol,'screenK',tf_screenK, ...
    'order',[tf_np tf_nz tf_nd],'nCand',nC);
fprintf('[AFFECT-TF-FULL] -> AFFECT_TF (affected_tf[nG x nA] + per-cell VAF/delay/trough/settle/rebound maps)\n');
warning(tfWarnPrev);               % restore warning state suppressed at top of §10T (single top-level call)

%% =====================================================================
%% §10T3 [AFFECT-TF-MAP] interactive TF-affected pixel map (DEBUG the TF detection)
%%   Per-amp grid with TF-affected pixels (affected_tf) in BLACK. Click any pixel ->
%%   refit its fixed-order TF and show evoked + fit overlay + ipsi reference, with
%%   VAF/trough/matchD/pass, so you can see WHY the TF flagged / missed it.
%%   Placed AFTER §10T2 and driven by affected_tf (works in subset or full mode).
%% =====================================================================
figT = figure('Color','w','Position',[60 60 1500 820], ...
    'Name','TF-AFFECT — TF-detected stim-affected contra pixels (per amp) — click to debug');
nColT = ceil(sqrt(nA));  nRowT = ceil(nA/nColT);
axT = gobjects(nA,1);
for ai = 1:nA
    axT(ai) = subplot(nRowT, nColT, ai);
    imagesc(axT(ai), gB);  colormap(axT(ai), gray);  axis(axT(ai),'image','off');  hold(axT(ai),'on');
    aff = affected_tf(:,ai);
    scatter(axT(ai), dspGc(~aff), dspGr(~aff), 12, [0.75 0.75 0.75],'filled','MarkerEdgeColor',[0.4 0.4 0.4],'LineWidth',0.2);
    scatter(axT(ai), dspGc(aff),  dspGr(aff),  20, 'k','filled','MarkerEdgeColor','k');
    plot(axT(ai), dspSc, dspSr, 'r+','MarkerSize',12,'LineWidth',1.6);
    title(axT(ai), sprintf('%.1f V   %d aff', amps(ai), nnz(aff)), 'FontSize',10,'FontWeight','bold');
end
sgtitle(sprintf('§10T3 TF-affected map (%s, fixed %dp/%dz/%dd) — click a pixel to see its TF fit', ...
        tf_run, tf_np,tf_nz,tf_nd), 'FontWeight','bold');

DBT = struct('axT',axT,'amps',amps,'grR',grR,'grC',grC,'gdR',dspGr,'gdC',dspGc, ...
    'mResp',mResp,'tf_win',tf_win,'tms_w',tms_w,'rRef',rRef, ...
    'np',tf_np,'nz',tf_nz,'nd',tf_nd,'nPreZ',nPreZ,'Ts',Ts,'opt',tfOptP, ...
    'affected_tf',affected_tf,'VAF',VAFtf,'MD',MDtf,'TR',TRtf,'vg',vg,'tol',tf_matchTol, ...
    'dR',chRef2.delayMs,'tR',chRef2.troughMs);
guidata(figT, DBT);  set(figT,'WindowButtonDownFcn',@tfmap_click);
fprintf('[AFFECT-TF-MAP] click any pixel -> refit its fixed-order TF + show evoked/fit/VAF/trough/matchD/pass.\n');

%% (10b) [COUPLING-WINDOW] data-driven window capturing ALL ipsi<->contra coupling (BEFORE bleed labeling)
% Runs BEFORE the bleed-affected labeling (§13/§14) so the coupling extent is known first — cutting
% coupling short with a guessed 200-300 ms window is what corrupted the earlier bleed/neural split.
% COUPLING is measured as the stim-locked structure in the FULL contra->ipsi OLS PREDICTION of the
% ipsi site — i.e. the exact signal the stim-blind (§17) must null. This is far more sensitive than
% a raw contra-population average, because the predictor concentrates on the coupled subspace.
%   per amp a, bin t:  P_obs(a,t) = b_ols' * (contra evoked z-pattern at t)   [predicted ipsi evoked]
%   null: apply b_ols to size-matched 0 V windows -> 95th pctile of |predicted evoked| per bin.
% Coupling window end = last post-onset bin with |P_obs|>null; session window = MAX over amps.
% NOTE the coupling trace is BIPHASIC (dip then rebound): this window is the coupling SPAN and must
% NOT replace the unipolar dip_win_s used by the signed-dip metrics (§11-§14,§17). It is reported
% here and used to drive an ABSOLUTE-energy bleed window + (next) a per-bin stim-blind null.
y_sp_cw = double(y_full(frames));  muY_cw = mean(y_sp_cw(itr));
Gc_cw   = Ztr.'*Ztr;  b_ols_cw = Gc_cw \ (Ztr.'*(y_sp_cw(itr)-muY_cw));   % spont-trained full OLS (z-space)
idx0 = onF0(:).' + rel(:);                                                % z-scored 0 V evoked block (for null)
Z0 = (double(Uflat(gridIdx,:))*double(V_cp(:,idx0(:))) - mu_p)./sd_p;
Z0 = reshape(Z0,nG,Wb,nT0);  Z0 = Z0 - mean(Z0(:,1:preN,:),2);
% [0V CLAMP] reference the predicted-evoked trace to the 0 V (no-stim) condition, not just its own
% pre-onset baseline: a trial-AVERAGE need not be zero-mean (a few high-variability trials leave a
% common baseline drift). Subtract the grand 0 V predicted trace so every amp AND the null are clamped
% to 0 V -> the coupling test measures departure from 0 V, not from a possibly-biased self-baseline.
ev0_all = mean(Z0,3);  P_0V = b_ols_cw.' * ev0_all;
cw_nBoot = 300;  tt_c = rel/Fs;
P_obs = nan(nA,Wb);  P_nul = nan(nA,Wb);  cwEnd = zeros(nA,1);
for ai = 1:nA
    onF = onFcell{ai};  nT = numel(onF);  if nT==0, continue; end
    idx = onF(:).' + rel(:);
    Zp = (double(Uflat(gridIdx,:))*double(V_cp(:,idx(:))) - mu_p)./sd_p;
    ev = mean(reshape(Zp,nG,Wb,nT),3);  ev = ev - mean(ev(:,1:preN),2);
    P_obs(ai,:) = b_ols_cw.' * ev - P_0V;                                 % predicted ipsi evoked trace (clamped to 0V)
    bd = nan(cw_nBoot,Wb);
    for b = 1:cw_nBoot
        ev0 = mean(Z0(:,:, randi(nT0, nT, 1)),3);                         % size-nT 0 V predicted evoked
        bd(b,:) = abs(b_ols_cw.' * ev0 - P_0V);                           % null clamped to 0V identically
    end
    P_nul(ai,:) = quantile(bd,0.95,1);
    sig = abs(P_obs(ai,postCols)) > P_nul(ai,postCols);
    lastk = find(sig,1,'last');  if ~isempty(lastk), cwEnd(ai) = tt_c(preN+lastk); end
end
couple_win_s = max([cwEnd; 0]);                                           % full coupling extent (all amps)
if couple_win_s<=0, couple_win_s = dip_win_s; end
fprintf('\n[COUPLING-WINDOW] per-amp contra->ipsi coupling extent (last bin |pred evoked| > 0V null):\n');
for ai = 1:nA, fprintf('   %5.2f V | coupled to %4.0f ms\n', amps(ai), 1000*cwEnd(ai)); end
fprintf('   --> session coupling window = %.0f ms (max across amps)  |  config dip_win_s = %.0f ms\n', ...
        1000*couple_win_s, 1000*dip_win_s);

figCW = figure('Color','w','Name','[COUPLING-WINDOW] contra->ipsi predicted-evoked coupling vs time','Position',[60 60 1150 720]);
ncw = min(nA,3);  nrw = ceil(nA/ncw);
for ai = 1:nA
    ax = subplot(nrw,ncw,ai); hold(ax,'on'); box(ax,'on');
    if nT_amp(ai)==0, title(ax,sprintf('%.2f V n/a',amps(ai))); continue; end
    plot(ax, 1000*tt_c(postCols),  P_obs(ai,postCols), 'k-','LineWidth',1.5,'DisplayName','pred evoked');
    plot(ax, 1000*tt_c(postCols),  P_nul(ai,postCols), 'r--','LineWidth',1.0,'DisplayName','0V null 95%');
    plot(ax, 1000*tt_c(postCols), -P_nul(ai,postCols), 'r--','LineWidth',1.0,'HandleVisibility','off');
    if cwEnd(ai)>0, xline(ax,1000*cwEnd(ai),'b-','LineWidth',1.3,'DisplayName','coupling end'); end
    xline(ax,1000*dip_win_s,'m:','LineWidth',1.2,'DisplayName','dip\_win\_s'); yline(ax,0,'k:','HandleVisibility','off');
    title(ax,sprintf('%.2f V  couple\\rightarrow%.0f ms',amps(ai),1000*cwEnd(ai)),'FontSize',9,'FontWeight','bold');
    if ai==1, legend(ax,'Location','best','FontSize',6); ylabel(ax,'pred ipsi evoked (%\DeltaF/F)'); xlabel(ax,'ms re onset'); end
end
sgtitle(sprintf('COUPLING-WINDOW  %s %s e%d  — session coupling %.0f ms (blue) vs dip\\_win\\_s %.0f ms (magenta)', ...
        mn,td,en,1000*couple_win_s,1000*dip_win_s),'FontWeight','bold');
COUPLING = struct('amps',amps,'P_obs',P_obs,'P_nul',P_nul,'cwEnd',cwEnd,'couple_win_s',couple_win_s, ...
                  'rel',rel,'Fs',Fs,'postCols',postCols);

%% (14) [BLEEDCHAR] Fully auditable per-pixel, per-amplitude bleed characterization
% "Show me EXACTLY how each pixel is called bled, at every amplitude." For every grid pixel p
% and amplitude a we compute one statistic — ABSOLUTE evoked energy integrated over the SESSION
% COUPLING WINDOW (mean_t |amp - 0V| over 0..couple_win_s) — and its 0 V bootstrap null (matched
% to that amp's trial count), giving a one-sided z-score zA(p,a). A pixel is bled at amp a iff
% zA(p,a) > bc_z_thr. We use ABSOLUTE energy over the FULL coupling window (not the signed 0-200 ms
% dip mean) precisely because the ipsi->contra coupling is BIPHASIC (dip then rebound): a signed
% mean cancels the two lobes and under-counts bleed at high amps — exactly what hurt the previous
% analysis. Identifying all coupling BEFORE labeling bleed is the point (user pipeline step 4).
% Nothing is hidden: click any pixel to see, across ALL amps, (1) its evoked excess traces,
% (2) z vs amplitude with the threshold, (3) the raw coupling energy vs the 0V null band. Real
% bleed is AMPLITUDE-GRADED (grows with power) and RADIAL (near the site).
bc_z_thr  = 1.28;                                              % z to call a pixel bled at an amp (LOWER=more sensitive)
bc_nRand  = 600;                                              % 0V bootstrap draws (raised for a stabler map)
cplColsBC = (preN+1):min(Wb, preN+round(max(couple_win_s,dip_win_s)*Fs)); % coupling window (>= dip_win_s floor)

eDipA = squeeze(mean(abs(mResp(:,cplColsBC,:)),2));         % [nG x nA] ABS evoked coupling energy (|excess re 0V|)
mu0A = zeros(nG,nA);  sd0A = ones(nG,nA);
fprintf('\n[BLEEDCHAR] building per-pixel x per-amp z-scores over %.0f ms coupling window (%d amps, %d bootstrap)...\n', ...
        numel(cplColsBC)/Fs*1000, nA, bc_nRand);
for ai = 1:nA
    nT = nT_amp(ai);  if nT==0, continue; end
    nd = nan(nG,bc_nRand);
    for r = 1:bc_nRand
        bb = blk0(:,:, randi(nT0, nT, 1));                   % random nT-subset of the 0V trials
        mb = mean(bb - mean(bb(:,1:preN,:),2), 3) - m0;      % subset avg re full 0V mean
        nd(:,r) = mean(abs(mb(:,cplColsBC)),2);              % same ABS-energy statistic under 0V
    end
    mu0A(:,ai) = mean(nd,2);  sd0A(:,ai) = std(nd,0,2);
end
zA = (eDipA - mu0A) ./ max(sd0A, eps);                       % [nG x nA] one-sided z (coupling energy above 0V floor)
bledA = zA > bc_z_thr;                                       % [nG x nA] per-amp bled flag (one-sided: energy excess)
ampv = amps(:);  Afit = [ones(nA,1) ampv];                   % amp-graded slope of |z| (bleed grows w/ power)
slopeA = zeros(nG,1);
for p = 1:nG, cc = Afit \ abs(zA(p,:)).';  slopeA(p) = cc(2); end
distBC = hypot(grR - px_prim, grC - py_prim);
nBledAmp = sum(bledA,2);                                     % [nG x 1] # amps each pixel is bled at
% SEVERITY (map metric): reward pixels bled at MORE *and* HIGHER amps, not just the raw count.
% For each pixel sum the voltage of every amp it is bled at -> a pixel bled only at 4.9 V scores
% higher than one bled at 0.5+1.1+1.6 V; a pixel bled at many high amps scores highest of all.
% Units = summed volts over the amps where it exceeds the null. (bledA is the same bleed call as
% before, so the map still reflects exactly the pixels the z-matrix flags — only the color weight
% changes from count -> amplitude-weighted.)
sevBleed = bledA * amps(:);                                  % [nG x 1] Sigma of bled-amp voltages (V)
fprintf('[BLEEDCHAR] per-amp bled counts (|z|>%.2f):\n', bc_z_thr);
for ai=1:nA, fprintf('   %.2f V (n=%d): %d/%d px bled\n', amps(ai), nT_amp(ai), nnz(bledA(:,ai)), nG); end

% --- overview: z-score matrix (pixels sorted by distance) + clickable map ------------
[~,sdi] = sort(distBC,'ascend');
figBC = figure('Color','w','Name','BLEEDCHAR — per-pixel x per-amp bleed classification', ...
    'Units','pixels','Position',[110 90 1180 720]);
axMat = subplot(1,2,1,'Parent',figBC);
imagesc(axMat, 1:nA, 1:nG, zA(sdi,:));  set(axMat,'YDir','normal');
zmx = max(abs(zA(:)))+eps;  clim(axMat,[-zmx zmx]);
sM = linspace(0,1,128)';  colormap(axMat,[ [sM sM ones(128,1)] ; [ones(128,1) 1-sM 1-sM] ]);
cb1 = colorbar(axMat,'eastoutside');  cb1.Label.String = 'z (coupling energy vs 0V)';
set(axMat,'XTick',1:nA,'XTickLabel',compose('%.1f',amps(:)),'FontSize',9);
xlabel(axMat,'amplitude (V)','FontWeight','bold');  ylabel(axMat,'grid pixel (sorted near\rightarrowfar from site)','FontWeight','bold');
title(axMat,'z-score matrix: how every pixel scores at every amp','FontSize',10,'FontWeight','bold');

axMap = subplot(1,2,2,'Parent',figBC);  hold(axMap,'on');
image(axMap, repmat(dspImg,[1 1 3]));  axis(axMap,'image','off');  set(axMap,'YDir','reverse');
% size AND color encode severity: bigger+hotter = bled at more and higher amps. Unbled px (sev=0)
% drawn small/dark so the amplitude-graded, radial structure of real bleed stands out.
sevMx = max(sevBleed);  if sevMx<=0, sevMx = 1; end
mkSz  = 14 + 44*(sevBleed./sevMx);                          % 14..58 px marker area by severity
scMap = scatter(axMap, dspGc, dspGr, mkSz, sevBleed, 'filled', 'MarkerEdgeColor',[0.25 0.25 0.25], 'LineWidth',0.3);
colormap(axMap, hot(256));  clim(axMap,[0 sevMx]);
cb2 = colorbar(axMap,'eastoutside');  cb2.Label.String = 'amplitude-weighted bleed (\Sigma bled-amp V)';
plot(axMap, dspSc, dspSr, 'g+', 'MarkerSize',14, 'LineWidth',2);
title(axMap,{'map: amplitude-weighted bleed severity  (\Sigma of bled-amp voltages)', ...
             'bigger+hotter = bled at more AND higher amps   (click \rightarrow full report)'}, ...
      'FontSize',10,'FontWeight','bold');

BC = struct('axMap',axMap,'scMap',scMap,'grR',grR,'grC',grC,'gdR',dspGr,'gdC',dspGc,'nG',nG,'amps',amps,'nA',nA, ...
            'mResp',mResp,'rel',rel,'Fs',Fs,'preN',preN,'dipCols',cplColsBC, ...
            'eDipA',eDipA,'mu0A',mu0A,'sd0A',sd0A,'zA',zA,'bledA',bledA,'slopeA',slopeA, ...
            'z_thr',bc_z_thr,'dist',distBC,'site',[px_prim py_prim]);
guidata(figBC, BC);  set(figBC,'WindowButtonDownFcn',@bleedchar_click);
fprintf('[BLEEDCHAR] click any pixel on the map -> its z(amp) curve, evoked traces, and 0V null band.\n');

BLEEDCHAR = struct('zA',zA,'bledA',bledA,'eDipA',eDipA,'mu0A',mu0A,'sd0A',sd0A,'slopeA',slopeA, ...
                   'nBledAmp',nBledAmp,'sevBleed',sevBleed,'dist',distBC,'amps',amps,'z_thr',bc_z_thr,'mn',mn,'td',td,'en',en);

%% (15) [SETTLETIME] Data-driven inhibition window: per-amp trial-avg impulse landmarks
% Is the 0-200 ms dip window correct?  Measure it, don't eyeball it.  For each amplitude
% take the trial-averaged impulse response at the PRIMARY (ipsi) pixel (0V-catch subtracted),
% and extract the landmarks that define the window: trough (peak inhibition), RECOVERY
% (return to baseline = honest END of inhibition, BEFORE the rebound), REBOUND peak (signal
% diving up above baseline), and full SETTLE.  The recovery time -- not 200 ms -- is the
% principled upper edge of the inhibition-energy window; the rebound is a SEPARATE positive
% lobe that must not contaminate it.
st_tolFac  = 0.05;      % recovery band = st_tolFac * |trough| (or 2*baseline SD, whichever larger)
st_setFac  = 0.10;      % full-settle band = st_setFac  * |trough| (or 2*baseline SD)
st_win     = dip_win_s; % the window currently in use, for reference (s) — tracks the global knob

postC = (preN+1):Wb;                                   % post-onset columns
tms   = rel/Fs*1000;                                   % peri-onset time axis (ms)

% 0V baseline trace at the primary pixel (pre-onset baselined, trial-averaged)
tr0p = double(reshape(y_full(onF0(:).'+rel(:)), Wb, numel(onF0)));
tr0p = tr0p - mean(tr0p(1:preN,:),1);   y0p = mean(tr0p,2);   % [Wb x 1]

nA_s = numel(amps);
mAmp   = nan(Wb, nA_s);                                 % per-amp evoked impulse (amp - 0V)
Ltr    = nan(nA_s,1);  Dtr = nan(nA_s,1);               % trough time (ms) / depth (%dF/F)
Lrec   = nan(nA_s,1);                                   % recovery (end-of-inhibition) time (ms)
Lreb   = nan(nA_s,1);  Dreb = nan(nA_s,1);              % rebound peak time (ms) / height (%dF/F)
Lset   = nan(nA_s,1);                                   % full settle time (ms)
Lrbs   = nan(nA_s,1);                                   % REBOUND-settle time (ms): rebound has died down (target #3)
fprintf('\n[SETTLETIME] primary-pixel impulse landmarks (0V-subtracted, per amp):\n');
fprintf('   amp(V)  nTrl | trough(ms)  depth | recover(ms) | reboundPk(ms)  height | rebSettle(ms) | settle(ms)\n');
for ai = 1:nA_s
    onF = onFcell{ai};  nT = numel(onF);
    if nT==0, continue; end
    tra = double(reshape(y_full(onF(:).'+rel(:)), Wb, nT));
    tra = tra - mean(tra(1:preN,:),1);                 % baseline each trial
    m   = mean(tra,2) - y0p;                            % evoked excess over 0V  [Wb x 1]
    mAmp(:,ai) = m;

    bslSD = std(m(1:preN));                             % residual baseline noise of the trial-avg
    seg   = m(postC);
    [dTr, iLoc] = min(seg);   iT = preN + iLoc;         % trough (most negative) over post-onset
    Dtr(ai) = dTr;  Ltr(ai) = tms(iT);

    tolR = max(2*bslSD, st_tolFac*abs(dTr));            % recovery band around baseline
    rc = iT - 1 + find(m(iT:Wb) >= -tolR, 1, 'first');  % first return to baseline after trough
    if ~isempty(rc), Lrec(ai) = tms(rc); else, rc = Wb; end

    iRb = NaN;                                          % rebound-peak column (set below if a rebound exists)
    if rc < Wb                                          % rebound = max positive lobe after recovery
        [dRb, iRl] = max(m(rc:Wb));  iR = rc + iRl - 1;
        if dRb > tolR, Dreb(ai) = dRb;  Lreb(ai) = tms(iR);  iRb = iR; end
    end

    tolS = max(2*bslSD, st_setFac*abs(dTr));            % full-settle band (both lobes inside)
    lb = find(abs(seg) > tolS, 1, 'last');              % last excursion outside the band
    if isempty(lb), Lset(ai) = 0; else, Lset(ai) = tms(preN+lb); end

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
% is ever classified as stim-affected. FARPIX fed nothing downstream (the greedy uses §10 `affected`),
% so removing it changes no result -- it just removes a confusing, unused diagnostic.

%% (16) [PIXVIEW] FEASIBILITY — click a contra pixel -> its per-amp response vs 0V null + windows
% BEFORE fitting the stim-blind (§17): is the effect even there, and where are the critical windows?
% Click any contra grid pixel on the brain (left). The right panel updates IN PLACE with that pixel's
% per-amp TRIAL-AVERAGED evoked response (mResp, re 0 V), overlaid on the 0 V NULL ENVELOPE (95% band
% from a size-matched 0 V bootstrap) with the data-driven RECOVERY (end-of-inhibition) and SETTLE
% (end-of-rebound) marks. A pixel whose amp traces leave the grey null band inside those windows is a
% real stim-coupled pixel; one that stays inside the band is stim-blind -> a good predictor candidate.
figPV = figure('Color','w','Name','[PIXVIEW] click a contra pixel -> per-amp response vs 0V null', ...
    'Units','pixels','Position',[80 80 1280 620]);
axMapPV = subplot(1,2,1,'Parent',figPV);  hold(axMapPV,'on');
image(axMapPV, repmat(dspImg,[1 1 3]));  axis(axMapPV,'image','off');  set(axMapPV,'YDir','reverse');
scatter(axMapPV, dspGc, dspGr, 16, [0.6 0.6 0.6], 'filled', 'MarkerEdgeColor',[0.3 0.3 0.3], 'LineWidth',0.2);
plot(axMapPV, dspSc, dspSr, 'g+', 'MarkerSize',14, 'LineWidth',2);
hMkPV = plot(axMapPV, nan, nan, 'o', 'MarkerSize',11, 'MarkerEdgeColor',[0.9 0.1 0.1], 'LineWidth',2);
title(axMapPV,'click a contra grid pixel','FontWeight','bold');
axTrPV = subplot(1,2,2,'Parent',figPV);  hold(axTrPV,'on');  box(axTrPV,'on');
pvYL = [min(mResp(:)) max(mResp(:))];  pvYL = pvYL + [-1 1]*0.08*max(diff(pvYL),eps);  % CONSTANT y-limits (full range)
PV = struct('mResp',mResp,'blk0',blk0,'m0',m0,'nT0',nT0,'nRep',max(round(median(nT_amp(nT_amp>0))),2), ...
            'nBoot',500,'preN',preN,'rel',rel,'Fs',Fs,'amps',amps,'nA',nA,'tms',rel/Fs*1000, ...
            'gdR',dspGr,'gdC',dspGc,'grR',grR,'grC',grC,'site',[px_prim py_prim],'ylimPV',pvYL, ...
            'recMs',recMs,'setMs',setMs,'axMap',axMapPV,'axTr',axTrPV,'hMk',hMkPV);
guidata(figPV, PV);  set(figPV,'WindowButtonDownFcn',@pixview_click);
[~,p0] = min(hypot(grR-px_prim, grC-py_prim));   % start on the pixel nearest the site
pixview_show(PV, p0);  set(hMkPV,'XData',dspGc(p0),'YData',dspGr(p0));
fprintf('\n[PIXVIEW] feasibility viewer: click a contra pixel -> per-amp trial-avg vs 0V null envelope (windows marked).\n');

%% (17) [STIMBLIND-GREEDY] *** PRIMARY *** TASK 3 — per-amp greedy pixel selection: predict spont, NOT the dip
% GOAL: a contra pixel set whose SPONT-trained prediction of the ipsi site is BLIND to the stim, so
% the residual (Actual - prediction) carries ~100% of the stim dip. Merely dropping stim-affected
% pixels (task-2 `affected`) is INSUFFICIENT — the surviving network-correlated pixels still linearly
% reconstruct the dip (that was the prior failure). So we target the PREDICTED DIP directly:
%   1) start from the stim-UNAFFECTED pixels for this amp (~affected(:,ai));
%   2) GREEDILY remove the pixel contributing most to the predicted per-amp dip, REFIT the spont OLS,
%      repeat until predicted dip <= greedy_tol * |start dip| (~0);
%   3) track held-out spont R^2 at every step so the cost of blinding is explicit.
% Global = the greedy stim-blind prediction (predicted dip ~ 0 BY CONSTRUCTION); Local = Actual - Global
% => residual carries the dip. %captured -> ~100% confirms it; spont R^2 full->blind shows the price.
% Trained SPONT only (§6 split), deployed on that amp's stim windows. Needs §10 (onFcell, `affected`).
greedy_tol = 0.05;                                          % stop when |predicted dip| <= this * |start dip|
dipCols = (preN+1):min(Wb, preN+round(dip_win_s*Fs));       % reporting/greedy dip window (data-driven default)
ttc = rel/Fs;
% NOTE: no explicit ipsi-mirror / homotopic prior. The sparse spont OLS already concentrates weight on
% the contra region most predictive of the ipsi site (the homotopic mirror), so no hand-coded spatial
% prior is imposed -- the pixel set is chosen purely by (a) spont predictive value and (b) dip-blindness.
y_sp = double(y_full(frames));  ytr = y_sp(itr);  yte = y_sp(ite);  muY = mean(ytr);  ytrc = ytr - muY;
Gz = Ztr.'*Ztr;  cz = Ztr.'*ytrc;  lamR = 1e-6*mean(diag(Gz));  sstot = max(sum((yte-mean(yte)).^2),eps);
solveB = @(S) (Gz(S,S) + lamR*eye(numel(S))) \ cz(S);       % spont OLS on a pixel subset S (tiny ridge for stability)

A_dip=nan(nA,1); G_dip=nan(nA,1); L_dip=nan(nA,1); r2full=nan(nA,1); r2sb=nan(nA,1); r2nd=nan(nA,1);
nStart=zeros(nA,1); nKeep=zeros(nA,1); pd0=nan(nA,1); pdEnd=nan(nA,1);
trA=cell(nA,1); trG=cell(nA,1); trL=cell(nA,1); keepMaskA=false(nG,nA); bKeepA=cell(nA,1);
fprintf('\n[STIMBLIND-GREEDY] per-amp: drop the biggest dip-driver until predicted dip <= %.0f%% of start,\n', 100*greedy_tol);
fprintf('                    then re-add the most dip-safe clean px that keep it dip-blind (SPONT-trained):\n');
fprintf('   %-6s %4s | %11s | %13s | %8s | %13s | %6s %8s\n','amp','nTr','start->keep','spontR2 f->b','nonDipR2','predDip s->e','Local','%%capt');
for ai = 1:nA
    onF = onFcell{ai};  nT = numel(onF);  if nT==0, continue; end
    dc = inhCols{ai};  if isempty(dc), dc = dipCols; end                   % per-amp DATA-DRIVEN inhibition window (task 2)
    idx = onF(:).'+rel(:);
    Zp = (double(Uflat(gridIdx,:))*double(V_cp(:,idx(:))) - mu_p)./sd_p;  Zp = reshape(Zp,nG,Wb,nT);
    evZ = mean(Zp,3);  evZ = evZ - mean(evZ(:,1:preN),2);                  % [nG x Wb] evoked z (baselined)
    evDip = mean(evZ(:,dc),2);                                             % per-px predicted-dip per unit weight
    aA = mean(reshape(double(y_full(idx(:))),Wb,nT),2);  aA = aA - mean(aA(1:preN));
    actualDip = mean(aA(dc));
    active = ~affected(:,ai);  if nnz(active) < 5, active = true(nG,1); end % start from stim-UNAFFECTED pixels
    activeStart = active;                                                  % remember the clean start set (for add-back)
    nStart(ai) = nnz(active);
    S = find(active);  bS = solveB(S);  predDip0 = bS.'*evDip(S);  pd0(ai) = predDip0;
    r2full(ai) = 1 - sum((yte-(muY+Zte(:,S)*bS)).^2)/sstot;
    for step = 1:(numel(S)-2)                                              % greedy: refit each removal
        S = find(active);  bS = solveB(S);  predDip = bS.'*evDip(S);
        if abs(predDip) <= greedy_tol*max(abs(predDip0),eps), break; end
        contrib = bS.*evDip(S);                                            % signed per-px contribution to the dip
        if predDip < 0, [~,k] = min(contrib); else, [~,k] = max(contrib); end  % drop the biggest dip-driver
        active(S(k)) = false;
    end
    % forward refinement: re-add the most DIP-SAFE clean px (smallest predicted-dip contribution) that do
    % NOT reintroduce the dip. Adding the least dip-carrying pixels first lets many back in -> lifts the
    % OVERALL (non-dip) prediction WITHOUT breaking dip-blindness (residual stays clean outside the stim
    % window). Ordered by |predicted dip per px| ascending -- dip-safety, no spatial/mirror prior.
    cand = find(activeStart & ~active);  [~,oa] = sort(abs(evDip(cand)),'ascend');  cand = cand(oa);
    for q = cand(:).'
        trial = active;  trial(q) = true;  St = find(trial);  bt = solveB(St);
        if abs(bt.'*evDip(St)) <= greedy_tol*max(abs(predDip0),eps), active = trial; end
    end
    S = find(active);  bS = solveB(S);  predDip = bS.'*evDip(S);  pdEnd(ai) = predDip;
    r2sb(ai) = 1 - sum((yte-(muY+Zte(:,S)*bS)).^2)/sstot;
    nKeep(ai) = numel(S);  keepMaskA(:,ai) = active;  bf = zeros(nG,1);  bf(S) = bS;  bKeepA{ai} = bf;
    yg = (bS.'*evZ(S,:)).';  yg = yg - mean(yg(1:preN));                   % stim-blind prediction trace (Global)
    rL = aA - yg;                                                         % residual (Local)
    nd = [1:preN, (dc(end)+1):Wb];                                        % NON-dip window (pre-onset + post-recovery)
    r2nd(ai) = 1 - sum((aA(nd)-yg(nd)).^2)/max(sum((aA(nd)-mean(aA(nd))).^2),eps);  % overall fit OUTSIDE the stim dip
    trA{ai}=aA(:); trG{ai}=yg(:); trL{ai}=rL(:);
    A_dip(ai)=actualDip; G_dip(ai)=mean(yg(dc)); L_dip(ai)=mean(rL(dc));
    fprintf('   %-6.2f %4d | %4d->%4d  | %.3f->%.3f | %8.3f | %6.3f->%6.3f | %6.3f %6.0f%%\n', ...
        amps(ai), nT, nStart(ai), nKeep(ai), r2full(ai), r2sb(ai), r2nd(ai), predDip0, predDip, L_dip(ai), 100*L_dip(ai)/A_dip(ai));
end
medCap = median(100*L_dip./A_dip,'omitnan');
fprintf('   --> median residual-captured dip = %.0f%% (target ~100%%) | median spont R^2 %.3f -> %.3f (cost of blinding)\n', ...
        medCap, median(r2full,'omitnan'), median(r2sb,'omitnan'));
fprintf('       median NON-dip fit R^2 = %.3f (Global tracks Actual OUTSIDE the stim window)\n', median(r2nd,'omitnan'));

% --- Fig 1: dose curve (Actual / Global(stim-blind pred) / Local(residual) dip vs amp) -----
figSB1 = figure('Color','w','Name','[STIMBLIND-GREEDY] Local dose curve','Position',[60 80 560 460]);
axA=axes(figSB1); hold(axA,'on'); box(axA,'on');
plot(axA, amps, A_dip, '-o','Color','k','LineWidth',1.8,'MarkerFaceColor','k','DisplayName','Actual');
plot(axA, amps, G_dip, '-s','Color',[.85 .2 .2],'LineWidth',1.5,'MarkerFaceColor',[.85 .2 .2],'DisplayName','Global (stim-blind pred \approx 0)');
plot(axA, amps, L_dip, '-^','Color',[.1 .4 .85],'LineWidth',1.5,'MarkerFaceColor',[.1 .4 .85],'DisplayName','Local (residual)');
yline(axA,0,'k:'); xlabel(axA,'amplitude (V)'); ylabel(axA,sprintf('0-%.0f ms dip (\\DeltaF/F %%)',1000*dip_win_s));
title(axA,sprintf('greedy stim-blind  |  median %.0f%% dip in residual',medCap),'FontSize',9,'FontWeight','bold');
legend(axA,'Location','southwest','FontSize',7);

% --- Fig 2: per-amp Actual / Global / Local trial averages ----------------------------------
figSB2 = figure('Color','w','Name','[STIMBLIND-GREEDY] per-amp Actual/Global/Local','Position',[40 40 1300 780]);
ncS = min(nA,3);  nrS = ceil(nA/ncS);
for ai=1:nA
    ax=subplot(nrS,ncS,ai); hold(ax,'on'); box(ax,'on');
    if isempty(trA{ai}), title(ax,sprintf('%.2f V: n/a',amps(ai))); continue; end
    plot(ax, ttc, trA{ai}, 'k-','LineWidth',1.7,'DisplayName','Actual');
    plot(ax, ttc, trG{ai}, '-','Color',[.85 .2 .2],'LineWidth',1.4,'DisplayName','Global (stim-blind pred)');
    plot(ax, ttc, trL{ai}, '-','Color',[.1 .4 .85],'LineWidth',1.4,'DisplayName','Local (residual)');
    xline(ax,0,'k:'); yline(ax,0,'k:'); xlim(ax,[-.5 1]);
    title(ax,sprintf('%.2f V (keep %d px, %.0f%% dip in residual)',amps(ai),nKeep(ai),100*L_dip(ai)/A_dip(ai)),'FontSize',9,'FontWeight','bold');
    if ai==1, legend(ax,'Location','southeast','FontSize',6); ylabel(ax,'\DeltaF/F %'); end
    if ai>nA-ncS, xlabel(ax,'t re onset (s)'); end
end
sgtitle('GREEDY STIM-BLIND: prediction blind to the dip (Global\approx0) -> residual (Local) = stim effect','FontWeight','bold');

% --- Fig 3: per-amp kept (weight-colored) vs removed (black) contra pixels -------------------
figSB3 = figure('Color','w','Name','[STIMBLIND-GREEDY] per-amp stim-blind pixel maps','Position',[80 60 1300 780]);
for ai=1:nA
    ax=subplot(nrS,ncS,ai); hold(ax,'on');
    image(ax, repmat(dspImg,[1 1 3])); axis(ax,'image','off'); set(ax,'YDir','reverse');
    sM=linspace(0,1,128)'; colormap(ax,[[sM sM ones(128,1)];[ones(128,1) 1-sM 1-sM]]);
    if isempty(bKeepA{ai}), title(ax,sprintf('%.2f V: n/a',amps(ai))); continue; end
    w=bKeepA{ai}; km=keepMaskA(:,ai); wsc=max(abs(w))+eps;
    scatter(ax, dspGc(~km), dspGr(~km), 20, 'k','filled','MarkerEdgeColor','k');
    scatter(ax, dspGc(km),  dspGr(km),  24, w(km),'filled','MarkerEdgeColor',[.2 .2 .2],'LineWidth',0.3);
    clim(ax,[-wsc wsc]); plot(ax, dspSc, dspSr, 'g+','MarkerSize',12,'LineWidth',1.8);
    title(ax,sprintf('%.2f V: keep %d (stim-blind) / remove %d',amps(ai),nnz(km),nG-nnz(km)),'FontSize',9,'FontWeight','bold');
end
sgtitle('per-amp GREEDY stim-blind sets: kept=spont-predictive clean px (weights), removed=dip-driving (black)','FontWeight','bold');

STIMBLIND = struct('amps',amps,'Actual',A_dip,'Global',G_dip,'Local',L_dip, ...
                   'trA',{trA},'trG',{trG},'trL',{trL},'bKeepA',{bKeepA},'keepMaskA',keepMaskA, ...
                   'r2full',r2full,'r2sb',r2sb,'r2nonDip',r2nd,'nStart',nStart,'nKeep',nKeep,'predDip0',pd0,'predDipEnd',pdEnd, ...
                   'greedy_tol',greedy_tol,'dipCols',dipCols,'rel',rel,'Fs',Fs,'preN',preN, ...
                   'medCapturedPct',medCap,'mn',mn,'td',td,'en',en);

%% (17b) [STIMBLIND-NATIVE] alternate: KEEP ALL unaffected px, enforce dip-blindness by CONSTRAINT
% Same goal as §17 (a spont-trained contra->ipsi prediction BLIND to the stim, so the residual carries
% the dip), OPPOSITE selection philosophy. §17 greedily REMOVES px until the reconstructed dip vanishes
% -> a sparse set (and at low amps it drops many px that were never stim-affected). Here we KEEP EVERY
% available (stim-UNAFFECTED) px for maximum accuracy, and instead impose dip-blindness as a linear
% EQUALITY CONSTRAINT on the spont fit -- no px are thrown away:
%     minimize || y_spont - Z b ||^2   subject to   b . evDip == 0     (predicted dip is EXACTLY 0)
% Closed form = project the unconstrained spont OLS off the dip direction (KKT / Lagrange):
%     b0 = G\c;   b = b0 - (G\d) * (d.'*b0) / (d.'*(G\d)),    G=Gz(S,S)+ridge, c=cz(S), d=evDip(S)
% Sparsity is NOT enforced (all unaffected px retained; sparsity is only "valued", not required), so the
% spont / non-dip accuracy should BEAT the sparse greedy (many more predictors) while the dip is zeroed
% EXACTLY by construction -> ~100% of the dip in the residual. Trained SPONT only; deployed per amp.
% [BIPHASIC UPGRADE 2026-07-07] The stim response is BIPHASIC: a fast inhibitory DIP (~0-300 ms) then a
% slow positive REBOUND (~300-700 ms, grows with amp per §15). Blinding to the dip ALONE lets the rebound
% leak into the prediction (Global), so the residual misses it. FIX (NATIVE only; greedy untouched): blind
% the prediction to the FULL stim-effect window by projecting the spont OLS off a K-column subspace D --
% K equal sub-windows spanning onset->settle, each column = that sub-window's mean evoked direction:
%     minimize ||y_spont - Z b||^2  s.t.  D' b = 0   ->   b = b0 - G^{-1}D (D'G^{-1}D)^+ D' b0   (KKT)
% The residual (Local) then carries BOTH lobes. We ALSO fit a SHARED parametric biphasic model (fast + slow
% gamma, SAME shape across amps) to the residual -> per-amp dip-gain & rebound-gain = a uniform dose model.
% [NBLIND TUNING 2026-07-07, pick reworked 2026-07-13] native_nblind (# blinded sub-windows) trades
% biphasic capture vs how many prediction DoF are removed: MORE windows -> fuller dip+rebound capture in
% the residual, but fewer DoF left for the ongoing (pre/post-stim) prediction. We SWEEP candidates, cache
% each amp's evoked ONCE (the expensive SVD reconstruction), and pick the smallest nblind that captures the
% dip at EVERY amp (see the auto-pick below) -- NOT the old "max nonStimR2" which was chasing a lying metric.
nblind_grid = [2 3 4 5 6 8];                                          % # blind sub-windows swept (native_nblind pick)
ncN = min(nA,3);  nrN = ceil(nA/ncN);
% shared parametric biphasic basis (fixed shapes from §15 landmarks: dip peak ~143 ms, rebound peak ~571 ms)
tms_on = (rel(:)-rel(preN+1))/Fs*1000;  posT = tms_on>=0;
gDip = zeros(Wb,1);  gReb = zeros(Wb,1);
gDip(posT) = (tms_on(posT).^2).*exp(-tms_on(posT)/71.5);  if any(gDip>0), gDip=gDip/max(gDip); end   % peak 143 ms
gReb(posT) = (tms_on(posT).^2).*exp(-tms_on(posT)/285);   if any(gReb>0), gReb=gReb/max(gReb); end    % peak 571 ms
% ---- cache per-amp evoked + fit operators ONCE (all independent of nblind) ----
evZc=cell(nA,1); aAc=cell(nA,1); dcc=cell(nA,1); rcc=cell(nA,1); scc=cell(nA,1); Sc=cell(nA,1); dGc=cell(nA,1); b0c=cell(nA,1);
for ai = 1:nA
    onF=onFcell{ai}; nT=numel(onF); if nT==0, continue; end
    dc=inhCols{ai}; if isempty(dc), dc=dipCols; end;  rc=rebCols{ai};
    idx=onF(:).'+rel(:);
    Zp=(double(Uflat(gridIdx,:))*double(V_cp(:,idx(:)))-mu_p)./sd_p; Zp=reshape(Zp,nG,Wb,nT);
    evZ=mean(Zp,3); evZ=evZ-mean(evZ(:,1:preN),2);
    aA=mean(reshape(double(y_full(idx(:))),Wb,nT),2); aA=aA-mean(aA(1:preN));
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
% ---- sweep native_nblind: report dip/rebound capture + the HONEST per-frame pre/post prediction R^2 ----
% [2026-07-13] Pick the SMALLEST nblind whose WORST-amp dip capture >= cap_dip_min_amp, so EVERY amp
% (incl. the low ones) reaches ~full capture while removing as few prediction DoF as possible (smaller
% nblind -> higher pred R^2). The OLD objective ("max median nonStimR2 s.t. median dip>=90%") picked
% nblind=2 by chasing the lying trial-avg metric, which under-captured the dip at low/mid amps (52% at
% 3.2 V). native_nblind='auto' runs this pick (-> 4 on AL_0033); set an integer to force it.
native_nblind   = 'auto';   % 'auto' = data-driven pick below; or a fixed integer to force the # blind windows
cap_dip_min_amp = 92;       % 'auto': smallest nblind whose MIN per-amp dip capture >= this (%). ("100% at ALL amps")
fprintf('\n[STIMBLIND-NATIVE] tuning native_nblind — dip/rebound capture + HONEST per-frame pre/post pred R^2:\n');
fprintf('   %-6s | %9s %9s | %9s | %14s | %8s\n','nblind','medDipCap','minDipCap','medRebCap','predR2 pre/post','spontR2b');
sw_dip=nan(numel(nblind_grid),1); sw_dipmin=sw_dip; sw_reb=sw_dip; sw_pre=sw_dip; sw_post=sw_dip; sw_sb=sw_dip; sw_ns=sw_dip;
for gi = 1:numel(nblind_grid)
    nb=nblind_grid(gi); dcv=nan(nA,1); rcv=nan(nA,1); nsv=nan(nA,1); sbv=nan(nA,1); prv=nan(nA,1); pov=nan(nA,1);
    for ai = 1:nA
        if isempty(evZc{ai}), continue; end
        [bN,~,~,r2ns,dCap,rCap,r2sb] = native_project(nb, evZc{ai},aAc{ai},dcc{ai},rcc{ai},scc{ai},Sc{ai},dGc{ai},b0c{ai}, preN,Wb,yte,muY,Zte,sstot);
        S=Sc{ai}; nsv(ai)=r2ns; dcv(ai)=dCap; rcv(ai)=rCap; sbv(ai)=r2sb;
        prv(ai)=r2f(ypre{ai},  muY+(Zpre{ai}(S,:).'*bN));
        pov(ai)=r2f(ypost{ai}, muY+(Zpost{ai}(S,:).'*bN));
    end
    sw_dip(gi)=median(dcv,'omitnan'); sw_dipmin(gi)=min(dcv,[],'omitnan'); sw_reb(gi)=median(rcv,'omitnan');
    sw_pre(gi)=median(prv,'omitnan'); sw_post(gi)=median(pov,'omitnan'); sw_sb(gi)=median(sbv,'omitnan'); sw_ns(gi)=median(nsv,'omitnan');
    fprintf('   %-6d | %8.0f%% %8.0f%% | %8.0f%% | %6.3f / %6.3f | %8.3f\n', nb, sw_dip(gi), sw_dipmin(gi), sw_reb(gi), sw_pre(gi), sw_post(gi), sw_sb(gi));
end
if ischar(native_nblind) && strcmpi(native_nblind,'auto')
    good = find(sw_dipmin>=cap_dip_min_amp);
    if ~isempty(good), native_nblind=nblind_grid(good(1));            % smallest nblind reaching full per-amp capture
    else, [~,bi]=max(sw_dipmin); native_nblind=nblind_grid(bi); end
    fprintf('   --> AUTO picked native_nblind = %d (smallest nblind with MIN per-amp dip capture >= %d%%)\n', native_nblind, cap_dip_min_amp);
else
    fprintf('   --> using forced native_nblind = %d\n', native_nblind);
end

An_dip=nan(nA,1); Gn_dip=nan(nA,1); Ln_dip=nan(nA,1);              % DIP lobe (Actual/Global/Local)
An_reb=nan(nA,1); Gn_reb=nan(nA,1); Ln_reb=nan(nA,1);             % REBOUND lobe
r2n_full=nan(nA,1); r2n_sb=nan(nA,1); r2n_ns=nan(nA,1);          % spont ceiling / blinded / NON-stim R2 (trial-avg; deprecated)
r2n_pre=nan(nA,1); r2n_post=nan(nA,1);                            % HONEST per-frame pre/post-stim prediction R2
nUse_n=zeros(nA,1); pdn=nan(nA,1); prn=nan(nA,1); nCon=zeros(nA,1);
kDipA=nan(nA,1); kRebA=nan(nA,1);                                 % shared parametric biphasic gains per amp
trAn=cell(nA,1); trGn=cell(nA,1); trLn=cell(nA,1); trMn=cell(nA,1); useMaskN=false(nG,nA); bUseN=cell(nA,1);
fprintf('\n[STIMBLIND-NATIVE] KEEP all unaffected px; blind prediction to DIP+REBOUND (%d-window subspace); SPONT-trained:\n', native_nblind);
fprintf('   %-6s %4s | %5s %4s | %13s | %14s | %8s %8s | %8s %8s\n','amp','nTr','nUse','nCon','spontR2 c->b','predR2 pre/post','dipAct','dipLoc','rebAct','rebLoc');
for ai = 1:nA
    if isempty(evZc{ai}), continue; end
    S=Sc{ai};  nUse_n(ai)=numel(S);  useMaskN(S,ai)=true;
    aA=aAc{ai};  dc=dcc{ai};  rc=rcc{ai};  stimCols=scc{ai};
    [bN,yg,rL,r2ns,~,~,r2sb,nc] = native_project(native_nblind, evZc{ai},aA,dc,rc,stimCols,S,dGc{ai},b0c{ai}, preN,Wb,yte,muY,Zte,sstot);
    nCon(ai)=nc;  bf=zeros(nG,1);  bf(S)=bN;  bUseN{ai}=bf;
    r2n_full(ai) = 1 - sum((yte-(muY+Zte(:,S)*b0c{ai})).^2)/sstot;         % spont ceiling (unconstrained)
    r2n_sb(ai) = r2sb;  r2n_ns(ai) = r2ns;                                 % spont blinded / NON-stim R2 (deprecated)
    r2n_pre(ai)  = r2f(ypre{ai},  muY+(Zpre{ai}(S,:).'*bN));               % HONEST per-frame pre-stim prediction R2
    r2n_post(ai) = r2f(ypost{ai}, muY+(Zpost{ai}(S,:).'*bN));             % HONEST per-frame post-stim prediction R2
    An_dip(ai)=mean(aA(dc)); Gn_dip(ai)=mean(yg(dc)); Ln_dip(ai)=mean(rL(dc));  pdn(ai)=Gn_dip(ai);
    if ~isempty(rc), An_reb(ai)=mean(aA(rc)); Gn_reb(ai)=mean(yg(rc)); Ln_reb(ai)=mean(rL(rc));  prn(ai)=Gn_reb(ai); end
    B = [gDip(stimCols) gReb(stimCols)];  kk = B \ rL(stimCols);          % shared biphasic fit to the residual
    kDipA(ai)=kk(1); kRebA(ai)=kk(2);  trMn{ai} = (gDip*kk(1) + gReb*kk(2));
    trAn{ai}=aA(:); trGn{ai}=yg(:); trLn{ai}=rL(:);
    fprintf('   %-6.2f %4d | %5d %4d | %.3f->%.3f | %6.3f / %6.3f | %8.3f %8.3f | %8.3f %8.3f\n', ...
        amps(ai), nT_amp(ai), nUse_n(ai), nCon(ai), r2n_full(ai), r2n_sb(ai), r2n_pre(ai), r2n_post(ai), An_dip(ai), Ln_dip(ai), An_reb(ai), Ln_reb(ai));
end
capDip = median(100*Ln_dip./An_dip,'omitnan');  capReb = median(100*Ln_reb./An_reb,'omitnan');
fprintf('   --> median DIP in residual = %.0f%% | median REBOUND in residual = %.0f%% | spont R^2 %.3f->%.3f | HONEST pred R^2 pre %.3f / post %.3f\n', ...
    capDip, capReb, median(r2n_full,'omitnan'), median(r2n_sb,'omitnan'), median(r2n_pre,'omitnan'), median(r2n_post,'omitnan'));

% --- Fig 1: DIP + REBOUND dose curves (Actual / Global(pred~0) / Local(residual)) ------------
figNB1 = figure('Color','w','Name','[STIMBLIND-NATIVE] dip+rebound dose curves','Position',[80 80 1000 430]);
axD=subplot(1,2,1,'Parent',figNB1); hold(axD,'on'); box(axD,'on');
plot(axD,amps,An_dip,'-o','Color','k','LineWidth',1.8,'MarkerFaceColor','k','DisplayName','Actual');
plot(axD,amps,Gn_dip,'-s','Color',[.85 .2 .2],'LineWidth',1.4,'MarkerFaceColor',[.85 .2 .2],'DisplayName','Global (\approx0)');
plot(axD,amps,Ln_dip,'-^','Color',[.1 .4 .85],'LineWidth',1.4,'MarkerFaceColor',[.1 .4 .85],'DisplayName','Local (residual)');
yline(axD,0,'k:'); xlabel(axD,'amplitude (V)'); ylabel(axD,'dip \DeltaF/F %'); legend(axD,'Location','southwest','FontSize',7);
title(axD,sprintf('DIP lobe  (median %.0f%% in residual)',capDip),'FontSize',9,'FontWeight','bold');
axR=subplot(1,2,2,'Parent',figNB1); hold(axR,'on'); box(axR,'on');
plot(axR,amps,An_reb,'-o','Color','k','LineWidth',1.8,'MarkerFaceColor','k','DisplayName','Actual');
plot(axR,amps,Gn_reb,'-s','Color',[.85 .2 .2],'LineWidth',1.4,'MarkerFaceColor',[.85 .2 .2],'DisplayName','Global (\approx0)');
plot(axR,amps,Ln_reb,'-^','Color',[.1 .4 .85],'LineWidth',1.4,'MarkerFaceColor',[.1 .4 .85],'DisplayName','Local (residual)');
yline(axR,0,'k:'); xlabel(axR,'amplitude (V)'); ylabel(axR,'rebound \DeltaF/F %'); legend(axR,'Location','northwest','FontSize',7);
title(axR,sprintf('REBOUND lobe  (median %.0f%% in residual)',capReb),'FontSize',9,'FontWeight','bold');
sgtitle(figNB1,'NATIVE stim-blind: BIPHASIC effect (dip + rebound) captured in the residual','FontWeight','bold');

% --- Fig 2: per-amp Actual / Global / Local + shared biphasic model overlay -----------------
figNB2 = figure('Color','w','Name','[STIMBLIND-NATIVE] per-amp Actual/Global/Local + biphasic model','Position',[60 40 1300 780]);
for ai=1:nA
    ax=subplot(nrN,ncN,ai); hold(ax,'on'); box(ax,'on');
    if isempty(trAn{ai}), title(ax,sprintf('%.2f V: n/a',amps(ai))); continue; end
    plot(ax, ttc, trAn{ai}, 'k-','LineWidth',1.6,'DisplayName','Actual');
    plot(ax, ttc, trGn{ai}, '-','Color',[.85 .2 .2],'LineWidth',1.3,'DisplayName','Global (stim-blind pred)');
    plot(ax, ttc, trLn{ai}, '-','Color',[.1 .4 .85],'LineWidth',1.3,'DisplayName','Local (residual)');
    plot(ax, ttc, trMn{ai}, '--','Color',[0 .6 .2],'LineWidth',1.2,'DisplayName','biphasic model');
    xline(ax,0,'k:'); yline(ax,0,'k:'); xlim(ax,[-.5 1]);
    title(ax,sprintf('%.2f V (%d px | dip %.0f%%, reb %.0f%%)',amps(ai),nUse_n(ai), ...
        100*Ln_dip(ai)/An_dip(ai), 100*Ln_reb(ai)/max(abs(An_reb(ai)),eps)*sign(An_reb(ai))),'FontSize',8,'FontWeight','bold');
    if ai==1, legend(ax,'Location','southeast','FontSize',5); ylabel(ax,'\DeltaF/F %'); end
    if ai>nA-ncN, xlabel(ax,'t re onset (s)'); end
end
sgtitle('NATIVE STIM-BLIND: prediction blind to DIP+REBOUND -> residual (blue) carries full biphasic effect; green dash = shared parametric model','FontWeight','bold');

% --- Fig 3: per-amp used (weight-colored) vs excluded/affected (black) contra pixels ---------
figNB3 = figure('Color','w','Name','[STIMBLIND-NATIVE] per-amp used pixel maps','Position',[100 60 1300 780]);
for ai=1:nA
    ax=subplot(nrN,ncN,ai); hold(ax,'on');
    image(ax, repmat(dspImg,[1 1 3])); axis(ax,'image','off'); set(ax,'YDir','reverse');
    sM=linspace(0,1,128)'; colormap(ax,[[sM sM ones(128,1)];[ones(128,1) 1-sM 1-sM]]);
    if isempty(bUseN{ai}), title(ax,sprintf('%.2f V: n/a',amps(ai))); continue; end
    w=bUseN{ai}; um=useMaskN(:,ai); wsc=max(abs(w))+eps;
    scatter(ax, dspGc(~um), dspGr(~um), 20, 'k','filled','MarkerEdgeColor','k');
    scatter(ax, dspGc(um),  dspGr(um),  24, w(um),'filled','MarkerEdgeColor',[.2 .2 .2],'LineWidth',0.3);
    clim(ax,[-wsc wsc]); plot(ax, dspSc, dspSr, 'g+','MarkerSize',12,'LineWidth',1.8);
    title(ax,sprintf('%.2f V: use %d (all unaffected) / excl %d (affected)',amps(ai),nnz(um),nG-nnz(um)),'FontSize',9,'FontWeight','bold');
end
sgtitle('per-amp NATIVE stim-blind sets: used=ALL unaffected px (constrained weights), excluded=affected (black)','FontWeight','bold');

STIMBLIND_NATIVE = struct('amps',amps,'ActualDip',An_dip,'GlobalDip',Gn_dip,'LocalDip',Ln_dip, ...
                   'ActualReb',An_reb,'GlobalReb',Gn_reb,'LocalReb',Ln_reb, ...
                   'trA',{trAn},'trG',{trGn},'trL',{trLn},'trModel',{trMn},'bUseN',{bUseN},'useMaskN',useMaskN, ...
                   'r2full',r2n_full,'r2sb',r2n_sb,'r2nonStim',r2n_ns,'r2pre',r2n_pre,'r2post',r2n_post,'nUse',nUse_n,'nCon',nCon,'predDip',pdn,'predReb',prn, ...
                   'kDip',kDipA,'kReb',kRebA,'native_nblind',native_nblind, ...
                   'dipCols',dipCols,'rel',rel,'Fs',Fs,'preN',preN, ...
                   'medDipCapPct',capDip,'medRebCapPct',capReb,'mn',mn,'td',td,'en',en);

%% (17bV) [NATIVE-VALIDATION] overfitting + performance metrics for the NATIVE stim-blind model
% Statistical validation (NATIVE only; greedy untouched). Four independent checks:
%   (M1) BLOCKED k-fold CV of the spont fit -- CONTIGUOUS folds (random-frame CV leaks because widefield
%        frames are temporally autocorrelated) -> held-out R^2 mean+-SD and the train-test gap (optimism =
%        the direct overfitting readout).
%   (M2) PERMUTATION null: circularly shift the ipsi target vs the contra design to break the instantaneous
%        coupling, refit -> null R^2 distribution -> p = P(null >= real). Confirms the fit isn't chance.
%   (M3) NATIVE held-out DIP+REBOUND capture: estimate the blinding subspace on TRAIN trials (odd), deploy
%        on HELD-OUT trials (even) -> does dip/rebound-blindness GENERALIZE (held-out predicted dip ~0)?
%   (M4) WEIGHT stability: bootstrap the spont fit -> mean pairwise weight-map correlation (stable weights
%        across resamples = signal, not overfit noise).
RUN_NATIVE_VAL = true;
if RUN_NATIVE_VAL
    fprintf('\n[NATIVE-VAL] statistical validation of the NATIVE stim-blind model:\n');
    Zall = [Ztr; Zte];  yall = y_sp(:);  nAll = size(Zall,1);
    % (M1) blocked k-fold CV of the spont predictor
    kF = 5;  ed = round(linspace(1,nAll+1,kF+1));  r2te=nan(kF,1); r2tr=nan(kF,1);
    for f = 1:kF
        te = ed(f):ed(f+1)-1;  tr = setdiff(1:nAll, te);
        muf = mean(yall(tr));  Gf = Zall(tr,:).'*Zall(tr,:) + lamR*eye(nG);  cf = Zall(tr,:).'*(yall(tr)-muf);
        bf = Gf\cf;
        r2te(f) = 1 - sum((yall(te)-(muf+Zall(te,:)*bf)).^2)/max(sum((yall(te)-mean(yall(te))).^2),eps);
        r2tr(f) = 1 - sum((yall(tr)-(muf+Zall(tr,:)*bf)).^2)/max(sum((yall(tr)-muf).^2),eps);
    end
    fprintf('   M1 blocked %d-fold CV: held-out R^2 %.3f +- %.3f  | train R^2 %.3f  | optimism(train-test) %.3f\n', ...
        kF, mean(r2te), std(r2te), mean(r2tr), mean(r2tr)-mean(r2te));
    % (M2) circular-shift permutation null
    nPerm = 200;  shifts = round(linspace(0.1,0.9,nPerm)*nAll);  r2null=nan(nPerm,1);
    GA = Zall.'*Zall + lamR*eye(nG);  muA = mean(yall);
    breal = GA\(Zall.'*(yall-muA));  r2real = 1 - sum((yall-(muA+Zall*breal)).^2)/max(sum((yall-muA).^2),eps);
    for p = 1:nPerm
        ysh = circshift(yall, shifts(p));  msh = mean(ysh);
        bp = GA\(Zall.'*(ysh-msh));
        r2null(p) = 1 - sum((ysh-(msh+Zall*bp)).^2)/max(sum((ysh-msh).^2),eps);
    end
    pPerm = (1+sum(r2null>=r2real))/(nPerm+1);
    fprintf('   M2 permutation null: real R^2 %.3f vs null %.3f +- %.3f  -> p=%.4f (n=%d shifts)\n', ...
        r2real, mean(r2null), std(r2null), pPerm, nPerm);
    % (M3) NATIVE held-out dip/rebound capture (odd trials -> subspace, even trials -> test)
    hoDip=nan(nA,1); hoReb=nan(nA,1); hoPredDip=nan(nA,1);
    for ai = 1:nA
        onF=onFcell{ai}; nT=numel(onF); if nT<6, continue; end
        dc=inhCols{ai}; if isempty(dc), dc=dipCols; end;  rc=rebCols{ai};
        idx=onF(:).'+rel(:);
        Zp=(double(Uflat(gridIdx,:))*double(V_cp(:,idx(:)))-mu_p)./sd_p; Zp=reshape(Zp,nG,Wb,nT);
        trn=1:2:nT; tst=2:2:nT;
        evTr=mean(Zp(:,:,trn),3); evTr=evTr-mean(evTr(:,1:preN),2);
        evTe=mean(Zp(:,:,tst),3); evTe=evTe-mean(evTe(:,1:preN),2);
        Amat=reshape(double(y_full(idx(:))),Wb,nT);  aTe=mean(Amat(:,tst),2); aTe=aTe-mean(aTe(1:preN));
        if ~isempty(rc), se=rc(end); else, se=dc(end); end
        scph=(preN+1):max(se,dc(end)); eg=round(linspace(1,numel(scph)+1,native_nblind+1));
        Dtr=zeros(nG,native_nblind);
        for q=1:native_nblind, cc=scph(eg(q):eg(q+1)-1); if ~isempty(cc), Dtr(:,q)=mean(evTr(:,cc),2); end; end
        act=~affected(:,ai); if nnz(act)<5, act=true(nG,1); end;  S=find(act);
        G=Gz(S,S)+lamR*eye(numel(S)); b0=G\cz(S);
        Dc=Dtr(S,:); Dc=Dc(:,any(abs(Dc)>0,1));
        if ~isempty(Dc), GD=G\Dc; bN=b0-GD*(pinv(Dc.'*GD)*(Dc.'*b0)); else, bN=b0; end
        ygte=(bN.'*evTe(S,:)).'; ygte=ygte-mean(ygte(1:preN));  rLte=aTe-ygte;
        hoPredDip(ai)=mean(ygte(dc));
        if abs(mean(aTe(dc)))>eps, hoDip(ai)=100*mean(rLte(dc))/mean(aTe(dc)); end
        if ~isempty(rc) && abs(mean(aTe(rc)))>eps, hoReb(ai)=100*mean(rLte(rc))/mean(aTe(rc)); end
    end
    fprintf('   M3 held-out (even trials): median dip captured %.0f%% | rebound %.0f%% | median |pred dip| %.4f (want ~0)\n', ...
        median(hoDip,'omitnan'), median(hoReb,'omitnan'), median(abs(hoPredDip),'omitnan'));
    % (M4) weight-map bootstrap stability
    Bn=30; Wm=nan(nG,Bn);
    for b=1:Bn
        ii=randi(nTr,nTr,1); Zb=Ztr(ii,:); yb=ytrc(ii);
        Wm(:,b)=(Zb.'*Zb+lamR*eye(nG))\(Zb.'*yb);
    end
    Rw=corr(Wm); ut=triu(true(Bn),1); meanWr=mean(Rw(ut));
    fprintf('   M4 weight stability: mean pairwise weight-map r = %.3f across %d bootstraps (1=perfectly stable)\n', meanWr, Bn);

    figVAL = figure('Color','w','Name','[NATIVE-VALIDATION]','Position',[70 70 1280 360]);
    axv1=subplot(1,3,1,'Parent',figVAL); bar(axv1,1:kF,r2te,'FaceColor',[.3 .5 .85]); hold(axv1,'on');
    yline(axv1,mean(r2tr),'r--','LineWidth',1.2); box(axv1,'on');
    xlabel(axv1,'fold'); ylabel(axv1,'held-out R^2'); title(axv1,sprintf('M1 blocked %d-fold CV (red=train)',kF),'FontSize',9,'FontWeight','bold');
    axv2=subplot(1,3,2,'Parent',figVAL); histogram(axv2,r2null,20,'FaceColor',[.6 .6 .6]); hold(axv2,'on');
    xline(axv2,r2real,'r-','LineWidth',1.8); box(axv2,'on');
    xlabel(axv2,'spont R^2'); ylabel(axv2,'count'); title(axv2,sprintf('M2 perm null (real=red, p=%.3f)',pPerm),'FontSize',9,'FontWeight','bold');
    axv3=subplot(1,3,3,'Parent',figVAL); hold(axv3,'on'); box(axv3,'on');
    plot(axv3,amps,hoDip,'-o','Color',[.1 .4 .85],'LineWidth',1.4,'MarkerFaceColor',[.1 .4 .85],'DisplayName','dip');
    plot(axv3,amps,hoReb,'-^','Color',[0 .6 .2],'LineWidth',1.4,'MarkerFaceColor',[0 .6 .2],'DisplayName','rebound');
    yline(axv3,100,'k:'); xlabel(axv3,'amplitude (V)'); ylabel(axv3,'held-out % captured'); legend(axv3,'Location','best','FontSize',7);
    title(axv3,'M3 held-out biphasic capture','FontSize',9,'FontWeight','bold');
    sgtitle(figVAL, sprintf('NATIVE-VALIDATION  %s %s e%d',mn,td,en),'FontWeight','bold','FontSize',10);

    NATIVE_VAL = struct('kFold',kF,'r2test',r2te,'r2train',r2tr,'r2real',r2real,'r2null',r2null,'pPerm',pPerm, ...
                        'hoDipCap',hoDip,'hoRebCap',hoReb,'hoPredDip',hoPredDip,'weightStability',meanWr,'mn',mn,'td',td,'en',en);
end

%% (17b2) [STIMBLIND-NAIVE] third model: FIXED predictor config = the reference-amp NATIVE set, reused across amps
% Motivation (user obs on Fig 11 + "too much stim predicted by contra at high amps"): the ~3.7 V NATIVE
% decomposition is the cleanest (dip+rebound fully in the residual, Global~0, healthy non-stim R^2). At
% LOW/MID amps NATIVE keeps ALL unaffected px (up to the full grid) -- so many predictors that the contra
% prediction has the freedom to reconstruct part of the stim itself (stim LEAKS into Global; residual
% under-captures). Fixing the predictor set to the smaller, cleaner reference-amp config across amps
% CONSTRAINS that freedom -> less leak, one uniform predictor basis for every amp. For amps ABOVE the
% reference some of those px become stim-affected, so we intersect with each amp's own unaffected set
% (never reintroduce a bled pixel). Blinding + metrics identical to NATIVE (same native_nblind, same KKT);
% only the predictor SET changes. Same validation (blocked CV + held-out capture) is run below.
% [REF-SWEEP 2026-07-10] The reference amp used to be hardcoded 3.7 V. That is arbitrary and drives the
% whole capture<->non-stim-R^2 tradeoff (a HIGHER ref amp -> fewer, cleaner px -> tighter blinding = more
% dip/rebound in the residual, but a SMALLER, spatially-biased far-from-site set = a WORSE spont predictor
% -> lower non-stim R^2; a LOWER ref amp -> the opposite, approaching NATIVE). So we now SWEEP every usable
% candidate reference amp (unaffected set >= naive_refMinPx), deploy the fixed-config naive from each across
% ALL amps, and TABULATE the tradeoff (median dip cap / rebound cap / non-stim R^2 / #px). The operating
% point is set by the naive_refAmp knob (default 3.7 preserves the prior result); the sweep just makes the
% choice data-driven and auditable instead of hardcoded.
naive_refAmp   = 3.7;   % reference amp (V) for the fixed predictor config. Numeric = force that amp
                        %   (default 3.7 = prior behavior); 'auto' = pick the sweep row that MAXIMIZES
                        %   median dip+rebound capture subject to non-stim R^2 >= naive_refNsFloor.
naive_refMinPx = 20;    % a candidate ref amp is usable only if its unaffected set has >= this many px
naive_refNsFloor = 0.35;% 'auto' guard: keep non-stim R^2 >= this while maximizing capture (naive's goal)
refCands = find(arrayfun(@(a) ~isempty(evZc{a}) && numel(Sc{a})>=naive_refMinPx, 1:nA));
swRefD=nan(numel(refCands),1); swRefR=swRefD; swRefN=swRefD; swRefNpx=swRefD;
fprintf('\n[STIMBLIND-NAIVE] reference-amp sweep (deploy fixed config from each ref across all amps):\n');
fprintf('   %-8s %6s | %10s %10s | %13s\n','refAmp(V)','nPx','medDipCap','medRebCap','med nonStimR2');
for ci = 1:numel(refCands)
    aiR = refCands(ci);  Sr = Sc{aiR};
    dGr = decomposition(Gz(Sr,Sr)+lamR*eye(numel(Sr)));  b0r = dGr\cz(Sr);
    dC=nan(nA,1); rC=nan(nA,1); nsC=nan(nA,1);
    for ai = 1:nA
        if isempty(evZc{ai}), continue; end
        aff=affected(:,ai);  Su=Sr(~aff(Sr));  if numel(Su)<5, continue; end
        if numel(Su)==numel(Sr), dGu=dGr; b0u=b0r;
        else, dGu=decomposition(Gz(Su,Su)+lamR*eye(numel(Su))); b0u=dGu\cz(Su); end
        [~,~,~,r2ns,dc_,rc_] = native_project(native_nblind, evZc{ai},aAc{ai},dcc{ai},rcc{ai},scc{ai},Su,dGu,b0u, preN,Wb,yte,muY,Zte,sstot);
        dC(ai)=dc_; rC(ai)=rc_; nsC(ai)=r2ns;
    end
    swRefD(ci)=median(dC,'omitnan'); swRefR(ci)=median(rC,'omitnan'); swRefN(ci)=median(nsC,'omitnan'); swRefNpx(ci)=numel(Sr);
    fprintf('   %-8.2f %6d | %9.0f%% %9.0f%% | %13.3f\n', amps(aiR), numel(Sr), swRefD(ci), swRefR(ci), swRefN(ci));
end
REFSWEEP = struct('refAmps',amps(refCands),'nPx',swRefNpx,'medDipCap',swRefD,'medRebCap',swRefR,'medNonStimR2',swRefN);
if ischar(naive_refAmp) && strcmpi(naive_refAmp,'auto')      % pick max capture s.t. non-stim R^2 floor
    capScore = swRefD + swRefR;  ok = swRefN>=naive_refNsFloor;
    if any(ok), cc=find(ok); [~,bi]=max(capScore(cc)); aiRef=refCands(cc(bi));
    else, [~,bi]=max(swRefN); aiRef=refCands(bi); end
    fprintf('   --> AUTO picked reference amp = %.2f V (max dip+reb capture with non-stim R^2 >= %.2f)\n', amps(aiRef), naive_refNsFloor);
else                                                         % forced numeric ref amp (default 3.7)
    [~,aiRef] = min(abs(amps-naive_refAmp));
    if isempty(Sc{aiRef}) || numel(Sc{aiRef})<naive_refMinPx % forced ref unusable -> most-constrained usable set
        [~,mi]=min(swRefNpx);  aiRef=refCands(mi);
    end
end
S_naive = Sc{aiRef};  ampRef = amps(aiRef);
dGnvR = decomposition(Gz(S_naive,S_naive)+lamR*eye(numel(S_naive)));  b0nvR = dGnvR\cz(S_naive);
An2d=nan(nA,1); Gn2d=nan(nA,1); Ln2d=nan(nA,1);  An2r=nan(nA,1); Gn2r=nan(nA,1); Ln2r=nan(nA,1);
r2_2full=nan(nA,1); r2_2sb=nan(nA,1); r2_2ns=nan(nA,1);  nUse2=zeros(nA,1); nCon2=zeros(nA,1);
kDip2=nan(nA,1); kReb2=nan(nA,1);  trA2=cell(nA,1); trG2=cell(nA,1); trL2=cell(nA,1); trM2=cell(nA,1);
useMask2=false(nG,nA); bUse2=cell(nA,1);
fprintf('\n[STIMBLIND-NAIVE] FIXED predictor config = %.2f V NATIVE set (%d px), reused across amps (intersect-guarded above ref):\n', ampRef, numel(S_naive));
fprintf('   %-6s %4s | %5s %4s | %13s | %9s | %8s %8s | %8s %8s\n','amp','nTr','nUse','nCon','spontR2 c->b','nonStimR2','dipAct','dipLoc','rebAct','rebLoc');
for ai = 1:nA
    if isempty(evZc{ai}), continue; end
    aff = affected(:,ai);  S_use = S_naive(~aff(S_naive));    % drop ref px that are stim-affected at THIS amp
    if numel(S_use) < 5, continue; end
    if numel(S_use)==numel(S_naive), dGu=dGnvR; b0u=b0nvR;
    else, dGu=decomposition(Gz(S_use,S_use)+lamR*eye(numel(S_use))); b0u=dGu\cz(S_use); end
    aA=aAc{ai}; dc=dcc{ai}; rc=rcc{ai}; stimCols=scc{ai};
    [bN,yg,rL,r2ns,~,~,r2sb,nc] = native_project(native_nblind, evZc{ai},aA,dc,rc,stimCols,S_use,dGu,b0u, preN,Wb,yte,muY,Zte,sstot);
    nUse2(ai)=numel(S_use); nCon2(ai)=nc; useMask2(S_use,ai)=true;
    bf=zeros(nG,1); bf(S_use)=bN; bUse2{ai}=bf;
    r2_2full(ai)=1 - sum((yte-(muY+Zte(:,S_use)*b0u)).^2)/sstot; r2_2sb(ai)=r2sb; r2_2ns(ai)=r2ns;
    An2d(ai)=mean(aA(dc)); Gn2d(ai)=mean(yg(dc)); Ln2d(ai)=mean(rL(dc));
    if ~isempty(rc), An2r(ai)=mean(aA(rc)); Gn2r(ai)=mean(yg(rc)); Ln2r(ai)=mean(rL(rc)); end
    B=[gDip(stimCols) gReb(stimCols)]; kk=B\rL(stimCols); kDip2(ai)=kk(1); kReb2(ai)=kk(2); trM2{ai}=gDip*kk(1)+gReb*kk(2);
    trA2{ai}=aA(:); trG2{ai}=yg(:); trL2{ai}=rL(:);
    fprintf('   %-6.2f %4d | %5d %4d | %.3f->%.3f | %9.3f | %8.3f %8.3f | %8.3f %8.3f\n', ...
        amps(ai),nT_amp(ai),nUse2(ai),nCon2(ai),r2_2full(ai),r2_2sb(ai),r2_2ns(ai),An2d(ai),Ln2d(ai),An2r(ai),Ln2r(ai));
end
capDip2=median(100*Ln2d./An2d,'omitnan'); capReb2=median(100*Ln2r./An2r,'omitnan');
fprintf('   --> NAIVE median DIP %.0f%% | REBOUND %.0f%% in residual | spont R^2 %.3f->%.3f | non-stim R^2 %.3f\n', ...
    capDip2,capReb2,median(r2_2full,'omitnan'),median(r2_2sb,'omitnan'),median(r2_2ns,'omitnan'));

% --- Fig NV1: DIP + REBOUND dose curves ------------------------------------------------------
figNV1 = figure('Color','w','Name','[STIMBLIND-NAIVE] dip+rebound dose curves','Position',[90 90 1000 430]);
axD=subplot(1,2,1,'Parent',figNV1); hold(axD,'on'); box(axD,'on');
plot(axD,amps,An2d,'-o','Color','k','LineWidth',1.8,'MarkerFaceColor','k','DisplayName','Actual');
plot(axD,amps,Gn2d,'-s','Color',[.85 .2 .2],'LineWidth',1.4,'MarkerFaceColor',[.85 .2 .2],'DisplayName','Global (\approx0)');
plot(axD,amps,Ln2d,'-^','Color',[.1 .4 .85],'LineWidth',1.4,'MarkerFaceColor',[.1 .4 .85],'DisplayName','Local (residual)');
yline(axD,0,'k:'); xlabel(axD,'amplitude (V)'); ylabel(axD,'dip \DeltaF/F %'); legend(axD,'Location','southwest','FontSize',7);
title(axD,sprintf('DIP lobe  (median %.0f%% in residual)',capDip2),'FontSize',9,'FontWeight','bold');
axR=subplot(1,2,2,'Parent',figNV1); hold(axR,'on'); box(axR,'on');
plot(axR,amps,An2r,'-o','Color','k','LineWidth',1.8,'MarkerFaceColor','k','DisplayName','Actual');
plot(axR,amps,Gn2r,'-s','Color',[.85 .2 .2],'LineWidth',1.4,'MarkerFaceColor',[.85 .2 .2],'DisplayName','Global (\approx0)');
plot(axR,amps,Ln2r,'-^','Color',[.1 .4 .85],'LineWidth',1.4,'MarkerFaceColor',[.1 .4 .85],'DisplayName','Local (residual)');
yline(axR,0,'k:'); xlabel(axR,'amplitude (V)'); ylabel(axR,'rebound \DeltaF/F %'); legend(axR,'Location','northwest','FontSize',7);
title(axR,sprintf('REBOUND lobe  (median %.0f%% in residual)',capReb2),'FontSize',9,'FontWeight','bold');
sgtitle(figNV1,sprintf('STIMBLIND-NAIVE (fixed %.2f V config): biphasic effect captured in the residual',ampRef),'FontWeight','bold');

% --- Fig NV2: per-amp Actual / Global / Local + shared biphasic model -------------------------
figNV2 = figure('Color','w','Name','[STIMBLIND-NAIVE] per-amp Actual/Global/Local + biphasic model','Position',[70 50 1300 780]);
for ai=1:nA
    ax=subplot(nrN,ncN,ai); hold(ax,'on'); box(ax,'on');
    if isempty(trA2{ai}), title(ax,sprintf('%.2f V: n/a',amps(ai))); continue; end
    plot(ax, ttc, trA2{ai}, 'k-','LineWidth',1.6,'DisplayName','Actual');
    plot(ax, ttc, trG2{ai}, '-','Color',[.85 .2 .2],'LineWidth',1.3,'DisplayName','Global (stim-blind pred)');
    plot(ax, ttc, trL2{ai}, '-','Color',[.1 .4 .85],'LineWidth',1.3,'DisplayName','Local (residual)');
    xline(ax,0,'k:'); yline(ax,0,'k:'); xlim(ax,[-.5 1]);
    title(ax,sprintf('%.2f V (%d px | dip %.0f%%, reb %.0f%%)',amps(ai),nUse2(ai), ...
        100*Ln2d(ai)/An2d(ai), 100*Ln2r(ai)/max(abs(An2r(ai)),eps)*sign(An2r(ai))),'FontSize',8,'FontWeight','bold');
    if ai==1, legend(ax,'Location','southeast','FontSize',5); ylabel(ax,'\DeltaF/F %'); end
    if ai>nA-ncN, xlabel(ax,'t re onset (s)'); end
end
sgtitle(sprintf('STIMBLIND-NAIVE: same %.2f V predictor set at every amp -> residual (blue) carries the biphasic stim effect',ampRef),'FontWeight','bold');

% --- Fig NV3: per-amp used pixel maps (fixed config; high amps drop bled px) ------------------
figNV3 = figure('Color','w','Name','[STIMBLIND-NAIVE] per-amp used pixel maps (fixed config)','Position',[110 70 1300 780]);
for ai=1:nA
    ax=subplot(nrN,ncN,ai); hold(ax,'on');
    image(ax, repmat(dspImg,[1 1 3])); axis(ax,'image','off'); set(ax,'YDir','reverse');
    sM=linspace(0,1,128)'; colormap(ax,[[sM sM ones(128,1)];[ones(128,1) 1-sM 1-sM]]);
    if isempty(bUse2{ai}), title(ax,sprintf('%.2f V: n/a',amps(ai))); continue; end
    w=bUse2{ai}; um=useMask2(:,ai); wsc=max(abs(w))+eps;
    scatter(ax, dspGc(~um), dspGr(~um), 20, 'k','filled','MarkerEdgeColor','k');
    scatter(ax, dspGc(um),  dspGr(um),  24, w(um),'filled','MarkerEdgeColor',[.2 .2 .2],'LineWidth',0.3);
    clim(ax,[-wsc wsc]); plot(ax, dspSc, dspSr, 'g+','MarkerSize',12,'LineWidth',1.8);
    title(ax,sprintf('%.2f V: use %d (fixed %.1fV set) / drop %d',amps(ai),nnz(um),ampRef,numel(S_naive)-nnz(um)),'FontSize',9,'FontWeight','bold');
end
sgtitle(sprintf('per-amp NAIVE stim-blind sets: fixed %.2f V config (drops only px that bleed at higher amps)',ampRef),'FontWeight','bold');

% --- NAIVE validation: blocked CV of the naive-set spont fit + held-out biphasic capture ------
if RUN_NATIVE_VAL
    fprintf('\n[NAIVE-VAL] validation of the NAIVE (fixed-config) stim-blind model:\n');
    kF=5; ed=round(linspace(1,nAll+1,kF+1)); r2teN=nan(kF,1); r2trN=nan(kF,1); Zs=Zall(:,S_naive);
    for f=1:kF
        te=ed(f):ed(f+1)-1; tr=setdiff(1:nAll,te); muf=mean(yall(tr));
        Gf=Zs(tr,:).'*Zs(tr,:)+lamR*eye(numel(S_naive)); cf=Zs(tr,:).'*(yall(tr)-muf); bf=Gf\cf;
        r2teN(f)=1 - sum((yall(te)-(muf+Zs(te,:)*bf)).^2)/max(sum((yall(te)-mean(yall(te))).^2),eps);
        r2trN(f)=1 - sum((yall(tr)-(muf+Zs(tr,:)*bf)).^2)/max(sum((yall(tr)-muf).^2),eps);
    end
    fprintf('   M1 blocked %d-fold CV (naive set): held-out R^2 %.3f +- %.3f | train %.3f | optimism %.3f\n', ...
        kF,mean(r2teN),std(r2teN),mean(r2trN),mean(r2trN)-mean(r2teN));
    hoDip2=nan(nA,1); hoReb2=nan(nA,1); hoPD2=nan(nA,1);
    for ai=1:nA
        onF=onFcell{ai}; nT=numel(onF); if nT<6, continue; end
        dc=inhCols{ai}; if isempty(dc), dc=dipCols; end; rc=rebCols{ai};
        idx=onF(:).'+rel(:);
        Zp=(double(Uflat(gridIdx,:))*double(V_cp(:,idx(:)))-mu_p)./sd_p; Zp=reshape(Zp,nG,Wb,nT);
        trn=1:2:nT; tst=2:2:nT;
        evTr=mean(Zp(:,:,trn),3); evTr=evTr-mean(evTr(:,1:preN),2);
        evTe=mean(Zp(:,:,tst),3); evTe=evTe-mean(evTe(:,1:preN),2);
        Amat=reshape(double(y_full(idx(:))),Wb,nT); aTe=mean(Amat(:,tst),2); aTe=aTe-mean(aTe(1:preN));
        if ~isempty(rc), se=rc(end); else, se=dc(end); end
        scph=(preN+1):max(se,dc(end)); eg=round(linspace(1,numel(scph)+1,native_nblind+1));
        aff=affected(:,ai); S_use=S_naive(~aff(S_naive)); if numel(S_use)<5, continue; end
        Dtr=zeros(numel(S_use),native_nblind);
        for q=1:native_nblind, cc=scph(eg(q):eg(q+1)-1); if ~isempty(cc), Dtr(:,q)=mean(evTr(S_use,cc),2); end; end
        Dtr=Dtr(:,any(abs(Dtr)>0,1));
        G=Gz(S_use,S_use)+lamR*eye(numel(S_use)); b0=G\cz(S_use);
        if ~isempty(Dtr), GD=G\Dtr; bN=b0-GD*(pinv(Dtr.'*GD)*(Dtr.'*b0)); else, bN=b0; end
        ygte=(bN.'*evTe(S_use,:)).'; ygte=ygte-mean(ygte(1:preN)); rLte=aTe-ygte;
        hoPD2(ai)=mean(ygte(dc));
        if abs(mean(aTe(dc)))>eps, hoDip2(ai)=100*mean(rLte(dc))/mean(aTe(dc)); end
        if ~isempty(rc) && abs(mean(aTe(rc)))>eps, hoReb2(ai)=100*mean(rLte(rc))/mean(aTe(rc)); end
    end
    fprintf('   M3 held-out (even trials, naive set): median dip %.0f%% | rebound %.0f%% | median |pred dip| %.4f\n', ...
        median(hoDip2,'omitnan'),median(hoReb2,'omitnan'),median(abs(hoPD2),'omitnan'));
    figNVV=figure('Color','w','Name','[NAIVE-VALIDATION]','Position',[80 80 900 360]);
    axa=subplot(1,2,1,'Parent',figNVV); bar(axa,1:kF,r2teN,'FaceColor',[.3 .5 .85]); hold(axa,'on');
    yline(axa,mean(r2trN),'r--','LineWidth',1.2); box(axa,'on');
    xlabel(axa,'fold'); ylabel(axa,'held-out R^2'); title(axa,sprintf('M1 blocked %d-fold CV, naive set (red=train)',kF),'FontSize',9,'FontWeight','bold');
    axb=subplot(1,2,2,'Parent',figNVV); hold(axb,'on'); box(axb,'on');
    plot(axb,amps,hoDip2,'-o','Color',[.1 .4 .85],'LineWidth',1.4,'MarkerFaceColor',[.1 .4 .85],'DisplayName','dip');
    plot(axb,amps,hoReb2,'-^','Color',[0 .6 .2],'LineWidth',1.4,'MarkerFaceColor',[0 .6 .2],'DisplayName','rebound');
    yline(axb,100,'k:'); xlabel(axb,'amplitude (V)'); ylabel(axb,'held-out % captured'); legend(axb,'Location','best','FontSize',7);
    title(axb,'M3 held-out biphasic capture (naive set)','FontSize',9,'FontWeight','bold');
    sgtitle(figNVV,sprintf('NAIVE-VALIDATION  %s %s e%d  (fixed %.2f V config)',mn,td,en,ampRef),'FontWeight','bold','FontSize',10);
    NAIVE_VAL=struct('kFold',kF,'r2test',r2teN,'r2train',r2trN,'hoDipCap',hoDip2,'hoRebCap',hoReb2,'hoPredDip',hoPD2, ...
                     'refAmp',ampRef,'nRefPx',numel(S_naive),'mn',mn,'td',td,'en',en);
end
STIMBLIND_NAIVE = struct('amps',amps,'refAmp',ampRef,'S_naive',S_naive,'refSweep',REFSWEEP, ...
                   'ActualDip',An2d,'GlobalDip',Gn2d,'LocalDip',Ln2d,'ActualReb',An2r,'GlobalReb',Gn2r,'LocalReb',Ln2r, ...
                   'trA',{trA2},'trG',{trG2},'trL',{trL2},'trModel',{trM2},'bUseN',{bUse2},'useMaskN',useMask2, ...
                   'r2full',r2_2full,'r2sb',r2_2sb,'r2nonStim',r2_2ns,'nUse',nUse2,'nCon',nCon2, ...
                   'kDip',kDip2,'kReb',kReb2,'native_nblind',native_nblind,'medDipCapPct',capDip2,'medRebCapPct',capReb2, ...
                   'dipCols',dipCols,'rel',rel,'Fs',Fs,'preN',preN,'mn',mn,'td',td,'en',en);

%% (17c) [STATEDEP] Trial-by-trial state-dependence of the LOCAL (stim-blind residual) dip
% The per-amp TRIAL-AVERAGED Local dip (§17) is the MEAN stim effect. Question (journal 2026-06-16):
% does the SINGLE-TRIAL Local dip vary with brain state at stim onset -- i.e. is the local stim
% response itself state-dependent, beyond baseline prediction noise? For each trial we build the
% stim-blind (greedy §17) prediction from THAT trial's own contra pixels (b.Kepp*Z_trial), subtract
% from the trial's actual ipsi -> single-trial Local residual; its 0-200 ms dip is the per-trial
% stim effect (DV). We z-score the DV WITHIN amplitude (removes the dose-response mean = the
% trial-averaged Local dip) so only the trial-to-trial spread AROUND that mean is tested.
%     DECISIVE TEST:  partialcorr( localDip_zWithinAmp , state | dev_pre )     [Spearman]
% dev_pre = pre-onset (-0.2..0 s) residual energy = per-trial prediction quality, partialled out so
% a state effect means the STIM response is state-dependent, not just a noisier baseline fit.
% State defs are IDENTICAL to CP-RES / cp_residual_core (2026-06-26 windows): MOTION = total |z| of
% the session motion trace over [-2,+0.5]s; PRE-VAR = var(y) over [-1,+0.5]s; PRE-DELTA = 1-4 Hz
% power over the same window. CRITICAL (RESEARCH 2026-07-01/02, CP-PREDQ): raw var and ABSOLUTE
% delta are SIGNAL-POWER CONFOUNDS (both ~ signal power, entangled with the DV magnitude); the
% admissible POWER-INDEPENDENT states are MOTION and RELATIVE delta (delta/total). All four are
% reported; the two confounded ones are flagged, not interpreted as genuine state-dependence.
tsec    = rel(:)/Fs;  preCols = find(tsec>=-0.2 & tsec<0);     % matched pre-onset control window (cols into peri-onset)
vd_preN = round(1*Fs);  vd_postN = round(0.5*Fs);             % var/delta window [-1,+0.5]s (peri-stim, CP-RES)
motPreN = round(2*Fs);  motPostN = round(0.5*Fs);            % motion window  [-2,+0.5]s
nWvd = vd_preN+vd_postN+1;  win_r = hann(nWvd);  W_r = sum(win_r.^2);
nfft_r = 2^nextpow2(nWvd);  fr = (0:nfft_r-1)'/nfft_r*Fs;  nB_r = floor(nfft_r/2)+1;
delta_r = fr(1:nB_r)>=1 & fr(1:nB_r)<=4;                       % 1-4 Hz delta band
tot_r   = fr(1:nB_r)>=0.5 & fr(1:nB_r)<=30;                    % broadband for the RELATIVE-delta ratio

% session motion trace (same source as cp_residual_core: 2x-sampled -> decimate to blue rate)
motz_full = [];
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

DVz=[]; LD=[]; PRE=[]; MOT=[]; PVv=[]; DPa=[]; DPr=[]; AMPv=[]; AMPi=[]; TRi=[]; ldMean=nan(nA,1); ldStd=nan(nA,1);
trAll=cell(nA,1); ygAll=cell(nA,1); rlAll=cell(nA,1);      % per-trial traces for TRIALPRED fig + clickable scatter
for ai = 1:nA
    onF = onFcell{ai};  nT = numel(onF);
    if nT==0 || isempty(bKeepA{ai}), continue; end
    b  = bKeepA{ai};  dc = inhCols{ai};  if isempty(dc), dc = dipCols; end
    idx = onF(:).'+rel(:);
    Zp  = (double(Uflat(gridIdx,:))*double(V_cp(:,idx(:))) - mu_p)./sd_p;  Zp = reshape(Zp,nG,Wb,nT);
    A   = reshape(double(y_full(idx(:))),Wb,nT);  A = A - mean(A(1:preN,:),1);   % single-trial actual (baselined)
    ld=nan(nT,1); dpre=nan(nT,1); mt=nan(nT,1); pvv=nan(nT,1); dpa=nan(nT,1); dpr=nan(nT,1);
    YG=nan(Wb,nT); RL=nan(Wb,nT);                          % per-trial predicted + residual traces
    for j = 1:nT
        yg = (b.'*Zp(:,:,j)).';  yg = yg - mean(yg(1:preN));   % single-trial stim-blind (Global) prediction
        rL = A(:,j) - yg;                                      % single-trial Local residual (stim effect)
        YG(:,j)=yg;  RL(:,j)=rL;                               % keep traces for plotting + click inspector
        ld(j)   = mean(rL(dc));                                % 0-200 ms Local dip = per-trial stim effect (DV)
        dpre(j) = mean(rL(preCols).^2);                        % pre-onset residual energy = prediction quality (control)
        ion = onF(j);
        mw = ion-motPreN:ion+motPostN;
        if ~isempty(motz_full) && mw(1)>=1 && mw(end)<=numel(motz_full), mt(j)=sum(abs(motz_full(mw))); end
        gp = ion-vd_preN:ion+vd_postN;
        if gp(1)>=1 && gp(end)<=nF_m
            sp = double(y_full(gp));  pvv(j) = var(sp,'omitnan');
            Xf = fft(sp(:).*win_r, nfft_r);  pw = abs(Xf(1:nB_r)).^2 * 2/(Fs*W_r);
            dpa(j) = mean(pw(delta_r),'omitnan');
            dpr(j) = dpa(j)/max(mean(pw(tot_r),'omitnan'),eps);  % RELATIVE delta (power-independent)
        end
    end
    trAll{ai}=A;  ygAll{ai}=YG;  rlAll{ai}=RL;
    ldMean(ai) = mean(ld,'omitnan');  ldStd(ai) = std(ld,'omitnan');
    % DV = SIGNED deviation from the amp-mean dip (dip - <dip>_amp), z-scored WITHIN amp. Signed (not
    % |dev|) so the metric carries DIRECTION: DV<0 = deeper dip than the amp template, DV>0 = shallower.
    % Within-amp centering removes the dose-response mean (the trial-averaged Local dip) so only the
    % trial-to-trial spread AROUND that mean is tested against state.
    sdf = @(x) (x-mean(x,'omitnan'))./max(std(x,'omitnan'),eps);
    DVz  = [DVz;  sdf(ld)];   LD = [LD; ld];   PRE = [PRE; dpre];     %#ok<AGROW>  signed dev + raw dip (for split re-centering)
    MOT  = [MOT;  mt];  PVv = [PVv; pvv];  DPa = [DPa; dpa];  DPr = [DPr; dpr];  %#ok<AGROW>
    AMPv = [AMPv; amps(ai)*ones(nT,1)];  AMPi = [AMPi; ai*ones(nT,1)];  TRi = [TRi; (1:nT).'];  %#ok<AGROW>
end

% --- Fig (TRIALPRED): 5 example trials/amp — row1 ipsi actual+pred(+amp-avg), row2 residual(+avg) ---
% Requested "before state-dep": shows the per-trial decomposition the state test operates on. Top row
% = actual ipsi (thin grey) & stim-blind prediction (thin red) for 5 trials, with the amp-average
% actual (thick black) and predicted (thick red) overlaid. Bottom row = each trial's residual (thin
% blue) and the amp-average residual (thick blue). Prediction is the greedy §17 stim-blind model.
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
fprintf('\n[STATEDEP] single-trial SIGNED Local dip deviation vs brain state  (DV=(dip-ampMean) z-within-amp; PARTIAL controls dev_pre; Spearman):\n');
fprintf('   [trust] Spearman(|DV|, pre-stim error) = %+.3f  (>0 => noisier baseline fits inflate the deviation)\n', trust_r);
fprintf('   %-16s %8s %8s | %11s   %-14s\n','state','partial','raw','trust-only','class');
rhoP=nan(4,1); pvP=nan(4,1); rhoR=nan(4,1); rhoT=nan(4,1); pvT=nan(4,1);
for s=1:4
    st = STc{s,2};  m = isfinite(DVz)&isfinite(st)&isfinite(PRE);
    if nnz(m) > 10
        [rhoP(s),pvP(s)] = partialcorr(DVz(m), st(m), PRE(m), 'type','Spearman');
        rhoR(s)          = corr(DVz(m), st(m), 'type','Spearman','rows','complete');
    end
    mt = m & trust_ok;                                    % trustworthy half only (well-predicted baseline)
    if nnz(mt) > 10, [rhoT(s),pvT(s)] = partialcorr(DVz(mt), st(mt), PRE(mt), 'type','Spearman'); end
    mark  = '';  if pvP(s) < 0.05, mark = ' *'; end
    markT = ' ';  if pvT(s) < 0.05, markT = '*'; end
    fprintf('   %-16s %+8.3f %+8.3f | %+10.3f%s  %-14s%s\n', regexprep(STc{s,1},'\\',''), rhoP(s), rhoR(s), rhoT(s), markT, STc{s,4}, mark);
end
fprintf('   NOTE: DV = SIGNED (per-trial 0-%.0f ms Local dip - amp mean), z-within amp. rho<0 => the trial dip is\n', 1000*dip_win_s);
fprintf('         DEEPER (more negative) than the amp template in that state; rho>0 => shallower. "trust-only" repeats\n');
fprintf('         the partial on the well-predicted half (pre-error below median). Interpret Motion + Rel-\\delta only.\n');

% --- Fig A: trial-averaged Local dip (the §17 mean) with single-trial spread -------------------
figST1 = figure('Color','w','Name','[STATEDEP] trial-avg Local dip + single-trial spread','Position',[70 90 560 460]);
axS=axes(figST1); hold(axS,'on'); box(axS,'on');
errorbar(axS, amps, ldMean, ldStd, '-o','Color','k','LineWidth',1.6,'MarkerFaceColor','k','CapSize',4,'DisplayName','trial-avg Local dip \pm SD');
plot(axS, amps, STIMBLIND.Local, 's','Color',[.1 .4 .85],'MarkerFaceColor',[.1 .4 .85],'DisplayName','§17 Local (check)');
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
    ttl = sprintf('%s  \\rho_{part}=%+.2f (trust %+.2f)', STc{s,1}, rhoP(s), rhoT(s));
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
             'tt',rel(:)/Fs, 'dipCols',dipCols, 'amps',amps);
guidata(figST2, SDc);  set(figST2,'WindowButtonDownFcn',@statedep_click);
fprintf('[STATEDEP] scatter is clickable -> click a point to see that trial''s actual/pred/residual traces.\n');

STATEDEP = struct('DVz',DVz,'dev_pre',PRE,'amp',AMPv, ...
                  'Motion',MOT,'PreVar',PVv,'PreDeltaAbs',DPa,'RelDelta',DPr, ...
                  'stateLabel',{{'Motion','PreVar','PreDeltaAbs','RelDelta'}}, ...
                  'rho_partial',rhoP,'p_partial',pvP,'rho_raw',rhoR,'admissible',[true false false true], ...
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

%% (18) [ALLSESS-STIMBLIND] combined PRIMARY stim-blind decomposition across ALL sessions
% Runs the §17 stim-blind model HEADLESS for every session in allSelExp (default the three
% impulse datasets), so the local-only effect can be compared across mice/sessions in one place.
% Each session is decomposed exactly as §17: per amp, DROP the stim-affected contra pixels (per-amp
% bledA), fit the contra->ipsi OLS on SPONT using only clean pixels -> Global (clean pred); Local
% (residual) = Actual - Global = the stim effect the clean contra cannot see. Reuses the same
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
                 'maxBaseTrl',maxBaseTrl,'dip_win_s',dip_win_s);
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

function c = tern_col(isAff)
% colour for §10T fit overlay: red-ish for affected, grey-blue for clean.
if isAff, c = [0.85 0.15 0.15]; else, c = [0.25 0.45 0.75]; end
end

function tfmap_click(fig, ~)
% §10T3: locate the clicked amp-subplot + nearest grid pixel, open the TF inspector.
DB = guidata(fig);
for ai = 1:numel(DB.axT)
    ax = DB.axT(ai);  cp = ax.CurrentPoint;  x = cp(1,1);  y = cp(1,2);
    xl = ax.XLim;  yl = ax.YLim;
    if x>=xl(1) && x<=xl(2) && y>=yl(1) && y<=yl(2)
        [~,p] = min((DB.gdC - x).^2 + (DB.gdR - y).^2);
        tfmap_detail(DB, p, ai);  return;
    end
end
end

function tfmap_detail(DB, p, ai)
% §10T3: refit the clicked pixel's fixed-order TF and overlay evoked / fit / ipsi reference.
ri = squeeze(DB.mResp(p, DB.tf_win, ai));  ri = ri(:) - ri(1);
wp = warning('off','all');                                   % single toggle (no onCleanup/loop -> safe)
[sys, vaf, ch] = proto_fitTF_fix(ri, DB.Ts, DB.np, DB.nz, DB.nd, DB.nPreZ, DB.opt);
warning(wp);
yhat = proto_sim(sys, numel(DB.tf_win), DB.Ts, DB.nPreZ);
md   = sqrt(mean(([ch.delayMs ch.troughMs]-[DB.dR DB.tR]).^2 ./ [40 80].^2));
pass = (vaf > DB.vg) && (md < DB.tol);
f = findobj('Type','figure','Name','TF pixel inspector');
if isempty(f), f = figure('Name','TF pixel inspector','Color','w','Position',[720 220 640 460]); else, clf(f); figure(f); end
ax = axes(f);  hold(ax,'on');
plot(ax, DB.tms_w, ri,   'k',   'LineWidth',1.4);
plot(ax, DB.tms_w, yhat, 'r--', 'LineWidth',1.3);
plot(ax, DB.tms_w, DB.rRef, 'Color',[.3 .5 .8], 'LineWidth',1.0);
yline(ax, 0, ':', 'Color',[.6 .6 .6]);
legend(ax, {'evoked','TF fit (fixed order)','ipsi reference'}, 'Location','best','FontSize',8);
xlabel(ax,'ms');  ylabel(ax,'\DeltaF/F');
title(ax, sprintf('g%d @ %.1fV   VAF=%.0f%% (gate %.0f)   trough=%.0f (ref %.0f)   matchD=%.2f (tol %.2f)   ->  %s', ...
    p, DB.amps(ai), vaf, DB.vg, ch.troughMs, DB.tR, md, DB.tol, ternstr(pass,'AFFECTED','not')), 'FontSize',9);
end

function [sys, vaf, ch, ord] = proto_fitTF(r, Ts, maxP, maxZ, maxD, nPreZ, opt)
% §10T framing-A: SWEEP (np,nz,nd) and keep the AIC-best low-order continuous TF for an
% impulse-response vector r (evoked, t=0 at first sample). Returns sys, in-window VAF (%),
% characteristics via proto_chars, and the selected order ord=[np nz nd].
r  = r(:);  nT = numel(r);
u  = [zeros(nPreZ,1); 1; zeros(nT-1,1)];
y  = [zeros(nPreZ,1); r];
dat = iddata(y, u, Ts);  dat.Tstart = -nPreZ*Ts;
bestA = inf;  sys = [];  ord = [NaN NaN NaN];   % NOTE: warnings suppressed once by caller (no onCleanup here — its destructor crashes the MCP output layer)
for nd = 0:maxD
    for np = 1:maxP
        for nz = 0:min(np-1, maxZ)
            try
                s = tfest(dat, np, nz, opt, 'InputDelay', nd*Ts);
                a = aic(s);
                if isfinite(a) && a < bestA, bestA = a; sys = s; ord = [np nz nd]; end
            catch
            end
        end
    end
end
[vaf, ch] = proto_vafch(sys, r, nT, Ts, nPreZ);
end

function [sys, vaf, ch] = proto_fitTF_fix(r, Ts, np, nz, nd, nPreZ, opt)
% §10T2: fit ONE continuous TF at a FIXED order (np,nz,nd) — no sweep. Same model class
% for every pixel (uniform dynamics across contra); one tfest call each.
r  = r(:);  nT = numel(r);
u  = [zeros(nPreZ,1); 1; zeros(nT-1,1)];
y  = [zeros(nPreZ,1); r];
dat = iddata(y, u, Ts);  dat.Tstart = -nPreZ*Ts;
sys = [];
try
    s = tfest(dat, np, nz, opt, 'InputDelay', nd*Ts);
    if isfinite(aic(s)), sys = s; end
catch
end
[vaf, ch] = proto_vafch(sys, r, nT, Ts, nPreZ);
end

function [vaf, ch] = proto_vafch(sys, r, nT, Ts, nPreZ)
% shared: in-window VAF (%) + characteristics for a fitted sys ([] -> reject cleanly).
if isempty(sys), vaf = -100; ch = proto_chars([], Ts, nT); return; end
try
    yhat = proto_sim(sys, nT, Ts, nPreZ);
    if any(~isfinite(yhat)), vaf = -100; ch = proto_chars(sys, Ts, nT); return; end   % unstable fit -> reject
    vaf  = max(-100, 100*(1 - sum((r-yhat).^2)/max(sum((r-mean(r)).^2), eps)));        % floor so nulls stay finite
    ch   = proto_chars(sys, Ts, nT);
catch
    vaf = -100;  ch = proto_chars([], Ts, nT);   % pathological sim/chars -> reject cleanly
end
end

function yhat = proto_sim(sys, nT, Ts, nPreZ)
% simulate the fitted TF's unit-impulse response over nT samples (post-onset window).
if isempty(sys), yhat = zeros(nT,1); return; end
u  = [zeros(nPreZ,1); 1; zeros(nT-1,1)];
yo = sim(sys, iddata([], u, Ts));
yhat = yo.OutputData(nPreZ+1:end);
end

function ch = proto_chars(sys, Ts, nT)
% Extract tunable characteristics from a fitted TF's impulse response:
% onset delay, trough time/depth, rebound peak/ratio, 5%-settle time, slow tau.
ch = struct('delayMs',NaN,'troughMs',NaN,'dip',NaN,'reboundMs',NaN, ...
            'reboundRatio',NaN,'settleMs',NaN,'slowTauMs',NaN);
if isempty(sys), return; end
try
    [yi, ti] = impulse(sys, (0:nT-1)*Ts);   yi = yi(:);   tiMs = ti(:)*1000;
    ch.delayMs = sys.InputDelay*1000;
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
    p  = pole(sys);  ps = p(real(p) < 0);
    if ~isempty(ps), ch.slowTauMs = -1000/max(real(ps)); end
catch
    % leave the NaN-initialised struct (pathological sys) — caller treats as reject
end
end

function [bN,yg,rL,r2ns,dipCap,rebCap,r2sb,nCon] = native_project(nb, evZ,aA,dc,rc,stimCols,S,dG,b0, preN,Wb,yte,muY,Zte,sstot)
% NATIVE stim-blind KKT projection for a given #blind-windows nb, on cached per-amp evoked. Splits the
% onset->settle window into nb equal sub-windows, blinds the prediction to each sub-window's mean evoked
% direction (D), and returns the constrained weights + Global/residual traces + capture/R^2 metrics.
edg = round(linspace(1, numel(stimCols)+1, nb+1));
D = zeros(numel(S), nb);
for q = 1:nb
    cc = stimCols(edg(q):edg(q+1)-1);
    if ~isempty(cc), D(:,q) = mean(evZ(S,cc),2); end
end
D = D(:, any(abs(D)>0,1));  nCon = size(D,2);
if ~isempty(D), GD = dG\D;  bN = b0 - GD*(pinv(D.'*GD)*(D.'*b0));  else, bN = b0; end   % project off stim subspace
yg = (bN.'*evZ(S,:)).';  yg = yg - mean(yg(1:preN));
rL = aA - yg;
nsc = [1:preN, (stimCols(end)+1):Wb];                                                   % NON-stim window
r2ns = 1 - sum((aA(nsc)-yg(nsc)).^2)/max(sum((aA(nsc)-mean(aA(nsc))).^2),eps);
dipCap = 100*mean(rL(dc))/mean(aA(dc));
if ~isempty(rc) && abs(mean(aA(rc)))>eps, rebCap = 100*mean(rL(rc))/mean(aA(rc)); else, rebCap = NaN; end
r2sb = 1 - sum((yte-(muY+Zte(:,S)*bN)).^2)/sstot;
end

function pixview_click(fig, ~)
% [PIXVIEW] click on the brain map -> nearest contra grid pixel -> update the per-amp trace panel.
PV = guidata(fig);  ax = PV.axMap;  cp = ax.CurrentPoint;  x = cp(1,1);  y = cp(1,2);
xl = ax.XLim;  yl = ax.YLim;  if x<xl(1)||x>xl(2)||y<yl(1)||y>yl(2), return; end
[~, p] = min((PV.gdC - x).^2 + (PV.gdR - y).^2);          % nearest grid pixel (display coords)
pixview_show(PV, p);
set(PV.hMk, 'XData', PV.gdC(p), 'YData', PV.gdR(p));      % mark the clicked pixel on the map
end

function statedep_click(fig, ~)
% [STATEDEP] click a scatter point in any of the 4 state panels -> that trial's actual/predicted ipsi
% (vs the amp-average) on top, and its residual (vs amp-average residual) below, with the dip window.
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
figure('Color','w','Name',sprintf('STATEDEP trial — %.2f V, trial %d',SD.amps(ai),tj),'Position',[220 180 660 540]);
axa = subplot(2,1,1);  hold(axa,'on');  box(axa,'on');
plot(axa,tt,mean(A,2), '-','Color',[.6 .6 .6],'LineWidth',1.2,'DisplayName','amp-avg actual');
plot(axa,tt,mean(YG,2),'-','Color',[.95 .62 .62],'LineWidth',1.2,'DisplayName','amp-avg pred');
plot(axa,tt,A(:,tj),  'k-','LineWidth',1.9,'DisplayName','actual (this trial)');
plot(axa,tt,YG(:,tj), '-','Color',[.85 .2 .2],'LineWidth',1.5,'DisplayName','stim-blind pred');
xline(axa,0,'k:'); yline(axa,0,'k:'); xlim(axa,[-.5 1]);  legend(axa,'Location','best','FontSize',7);
ylabel(axa,'ipsi \DeltaF/F %');
title(axa,sprintf('%s = %+.2f (z)   |   %.2f V, trial %d',regexprep(SD.stateName{pidx},'\\',''),SD.stateZ{pidx}(k),SD.amps(ai),tj),'FontWeight','bold');
axb = subplot(2,1,2);  hold(axb,'on');  box(axb,'on');
plot(axb,tt,mean(RL,2),'-','Color',[.6 .75 1],'LineWidth',1.2,'DisplayName','amp-avg residual');
plot(axb,tt,RL(:,tj), '-','Color',[.1 .4 .85],'LineWidth',1.9,'DisplayName','residual (this trial)');
xline(axb,tt(dc(1)),'m:'); xline(axb,tt(dc(end)),'m:');
xline(axb,0,'k:'); yline(axb,0,'k:'); xlim(axb,[-.5 1]);  legend(axb,'Location','best','FontSize',7);
xlabel(axb,'t re onset (s)');  ylabel(axb,'residual \DeltaF/F %');
end

function pixview_show(PV, p)
% Redraw (IN PLACE) the per-amp trial-averaged evoked response of contra pixel p vs the 0V null
% envelope, with the data-driven recovery + settle windows marked.
ax = PV.axTr;  cla(ax);  hold(ax,'on');  box(ax,'on');
Wb = numel(PV.rel);
% 0V null envelope for THIS pixel: 95% band of a size-nRep 0V bootstrap trial-average (re 0V mean)
nd = nan(PV.nBoot, Wb);
for r = 1:PV.nBoot
    bb = PV.blk0(p, :, randi(PV.nT0, PV.nRep, 1));
    nd(r,:) = mean(bb - mean(bb(:,1:PV.preN,:),2), 3) - PV.m0(p,:);
end
lo = prctile(nd,2.5,1);  hi = prctile(nd,97.5,1);
fill(ax, [PV.tms fliplr(PV.tms)], [hi fliplr(lo)], [0.82 0.82 0.82], 'EdgeColor','none', ...
     'FaceAlpha',0.6, 'DisplayName','0V null 95%');
cmap = parula(PV.nA);
for ai = 1:PV.nA
    plot(ax, PV.tms, squeeze(PV.mResp(p,:,ai)), '-', 'Color',cmap(ai,:), 'LineWidth',1.3, ...
         'DisplayName',sprintf('%.2f V',PV.amps(ai)));
end
yline(ax,0,'k:','HandleVisibility','off');  xline(ax,0,'k:','HandleVisibility','off');
mr = median(PV.recMs,'omitnan');  ms = median(PV.setMs,'omitnan');
if isfinite(mr), xline(ax, mr, '--', 'Color',[0.1 0.5 0.1], 'LineWidth',1.2, 'DisplayName','recovery (end inhib)'); end
if isfinite(ms), xline(ax, ms, '--', 'Color',[0.2 0.3 0.9], 'LineWidth',1.2, 'DisplayName','settle (end rebound)'); end
xlim(ax, [PV.tms(1) PV.tms(end)]);
if isfield(PV,'ylimPV') && all(isfinite(PV.ylimPV)), ylim(ax, PV.ylimPV); end   % CONSTANT across clicks
xlabel(ax,'time from onset (ms)','FontWeight','bold');  ylabel(ax,'evoked \DeltaF/F (amp - 0V, %)','FontWeight','bold');
d = hypot(PV.grR(p)-PV.site(1), PV.grC(p)-PV.site(2));
title(ax, sprintf('pixel [r%d c%d]  %.0f px from site  —  per-amp trial avg re 0V', PV.grR(p), PV.grC(p), d), ...
      'FontSize',9,'FontWeight','bold');
lg = legend(ax,'Location','southeast','FontSize',6);  lg.ItemTokenSize=[10 10];
end

function S = local_stimblind_session(sel, cfg, allExperiments)
% HEADLESS reproduction of the minimal §2-§7,§10,§17 pipeline for ONE session, returning the
% PRIMARY stim-blind (Actual/Global/Local) decomposition. Mirrors the main-script math exactly
% (site retarget, cached ROI, uniform eroded grid, spont train/test split, dip=0 equality
% constraint) but skips every interactive/diagnostic figure. Used by §19 to compare the local
% effect across sessions. Requires cached cp_stim_site_*.mat + cp_roi2_*.mat (no draw GUI).
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
null_win_s=max(couple_win_s,cfg.dip_win_s);                 % floor to reporting dip window (see §14/§17)
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

% --- (17) per-amp clean-pixel stim-blind: drop bledA(:,ai), fit SPONT, deploy STIM -----
dipCols=(preN+1):min(Wb, preN+round(cfg.dip_win_s*Fs));
ytr=y_sp(itr); yte=y_sp(ite); sstot=max(sum((yte-mean(yte)).^2),eps);
A_dip=nan(nA,1); G_dip=nan(nA,1); L_dip=nan(nA,1); r2clean=nan(nA,1); nDrop=zeros(nA,1);
trA=cell(nA,1); trG=cell(nA,1); trL=cell(nA,1); cleanMaskA=false(nG,nA); bCleanA=cell(nA,1);
for ai=1:nA
    onF=onFcell{ai}; nT=numel(onF); if nT==0 || isempty(EVcell{ai}), continue; end
    clean=~bledA(:,ai); cleanMaskA(:,ai)=clean; nDrop(ai)=nnz(~clean);
    if nnz(clean)<2, continue; end
    b=[ones(numel(itr),1) Ztr(:,clean)]\ytr; b0=b(1); bcf=b(2:end);
    r2clean(ai)=1-sum((yte-(b0+Zte(:,clean)*bcf)).^2)/sstot;
    bfull=zeros(nG,1); bfull(clean)=bcf; bCleanA{ai}=bfull;
    yg=bcf.'*EVcell{ai}(clean,:); yg=yg-mean(yg(1:preN));    % clean pred evoked (b0 cancels on baseline)
    onF=onFcell{ai}; idx=onF(:).'+rel(:);
    ya=mean(reshape(double(y_full(idx(:))),Wb,nT),2); ya=ya-mean(ya(1:preN));
    trA{ai}=ya(:); trG{ai}=yg(:); trL{ai}=ya(:)-yg(:);
    A_dip(ai)=mean(ya(dipCols)); G_dip(ai)=mean(yg(dipCols)); L_dip(ai)=A_dip(ai)-G_dip(ai);
end
medLocalPct=median(100*L_dip./A_dip,'omitnan');
% orient the brain map + grid/site the same way the main script does (session-safe display)
Tor = pick_orient(logical(M.contra), logical(M.ipsi), px_prim, py_prim, nY, nX);
[gdR,gdC] = orient_fwd(Tor, grR, grC);  [sdR,sdC] = orient_fwd(Tor, px_prim, py_prim);
oiB = Tor.imgOp(mimg_cp);  gimg = (oiB-min(oiB(:)))/max(max(oiB(:))-min(oiB(:)),eps);
BC = struct('mResp',mResp,'blk0',blk0,'m0',m0,'nT_amp',nT_amp,'nT0',nT0, ...
            'grR',grR,'grC',grC,'gdR',gdR,'gdC',gdC,'gridIdx',gridIdx, ...
            'site',[px_prim py_prim],'sdR',sdR,'sdC',sdC, ...
            'gimg',gimg,'amps',amps,'nA',nA,'nG',nG,'rel',rel,'Fs',Fs,'preN',preN,'Wb',Wb, ...
            'couple_win_s',couple_win_s,'null_win_s',null_win_s,'dip_win_s',cfg.dip_win_s);

S = struct('label',label,'sel',sel,'amps',amps,'Actual',A_dip,'Global',G_dip,'Local',L_dip,'BC',BC, ...
           'trA',{trA},'trG',{trG},'trL',{trL},'rel',rel,'Fs',Fs,'preN',preN, ...
           'r2_ols',r2_ols,'r2clean',r2clean,'nDrop',nDrop,'medLocalPct',medLocalPct,'nG',nG, ...
           'bledA',bledA,'cleanMaskA',cleanMaskA,'bCleanA',{bCleanA}, ...
           'couple_win_s',couple_win_s,'null_win_s',null_win_s);
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

function T = resolve_orient(knob, contra, ipsi, siteRow, siteCol, H, W)
% Turn the disp_orient knob into a display transform. 'auto' auto-normalizes via pick_orient;
% every other value is a FIXED dihedral view. make_orient builds fwd/inv numerically for any op,
% so overlay + click-inverse stay consistent regardless of the choice (display-only).
switch lower(knob)
    case 'auto',      T = pick_orient(contra, ipsi, siteRow, siteCol, H, W);
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

function T = pick_orient(contra, ipsi, siteRow, siteCol, H, W)
% Choose the dihedral view (of 8) that (1) puts IPSI rightmost with a VERTICAL midline
% (contra/ipsi separated horizontally), then (2) breaks the residual up/down flip so the SITE
% lands in the LOWER half (site below the brain centroid) — matching the conventional dorsal
% view (anterior up) the original AL_0033 display used. Term (1) dominates (x1000); term (2)
% is the tiebreaker between the two views that both satisfy (1) (they differ only by flipud).
ops={@(A)A,@(A)rot90(A,1),@(A)rot90(A,2),@(A)rot90(A,3), ...
     @(A)fliplr(A),@(A)rot90(fliplr(A),1),@(A)rot90(fliplr(A),2),@(A)rot90(fliplr(A),3)};
brain=contra|ipsi; best=-inf; T=[];
for o=1:numel(ops)
    Tt=make_orient(ops{o},H,W);
    cD=ops{o}(contra); iD=ops{o}(ipsi);
    [cr,cc]=find(cD); [ir,ic]=find(iD);  [br,~]=find(ops{o}(brain));
    [sR,~]=orient_fwd(Tt,siteRow,siteCol);
    score=1000*((mean(ic)-mean(cc)) - abs(mean(ir)-mean(cr))) + (sR-mean(br));  % ipsi-right (dom) + site-below
    if score>best, best=score; T=Tt; end
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
    T=resolve_orient(knob,contra,ipsi,px,py,D.nY,D.nX);
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
