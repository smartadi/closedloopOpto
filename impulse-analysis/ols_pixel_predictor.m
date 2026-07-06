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
% robustly locate impulse-analysis/ (the dir that actually contains data/), so the
% ROI + site caches are found regardless of pwd or how the script is launched.
cand = {here, fullfile(pwd,'impulse-analysis'), pwd, fullfile(pwd,'..','impulse-analysis')};
impulseDir = '';
for c = cand
    if ~isempty(c{1}) && exist(fullfile(c{1},'data'),'dir'), impulseDir = c{1}; break; end
end
if isempty(impulseDir)
    if ~isempty(here), impulseDir = here; else, impulseDir = fullfile(pwd,'impulse-analysis'); end
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
                      %   which cut inhibition off mid-recovery). Used by BLEED/CLEANFIT/STIMBLIND/
                      %   CLEANMAX/BLEEDCHAR so the window has ONE source of truth.
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
bwWinSec  = 1.5;      % window length (s) for the 5-best / 5-worst held-out panel
detrendSec= 1.0;      % running-mean window (s) for the best/worst DC detrend (< bwWinSec)
USE_DATA_SITE = true; % localise the site from data (recommended), not params.pixel
RUN_ALLSESS   = true;  % §19: also run the PRIMARY stim-blind decomposition HEADLESS on ALL
                      %   sessions in allSelExp and plot them together. Set false for fast
                      %   single-session iteration (skips the 3-session combined batch).
allSelExp     = [3 1 2];  % sessions for §19 combined run: AL_0033 e3, AL_0041 e1, AL_0041 e2
RUN_SESSION_VIEWER = true;  % §20: open the orientation-normalized interactive map with a session
                      %   picker (pick session -> brain + sparse contra weights; click ipsi to refit).

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

%% (8) Interactive map: weights ON the brain; click an IPSI pixel -> refit kernel
fig = figure('Color','w','Name','OLS kernel viewer — click an ipsi pixel to refit', ...
    'Units','pixels','Position',[120 80 720 760]);
ax_map = axes('Parent',fig,'Units','normalized','Position',[0.05 0.05 0.90 0.90]); hold(ax_map,'on');

% brain as an RGB grayscale underlay (ignores the axes colormap)
A2 = mimg_cp.';  g = (A2 - min(A2(:))) / max(max(A2(:))-min(A2(:)), eps);
image(ax_map, repmat(g,[1 1 3]));  axis(ax_map,'image','off');  set(ax_map,'YDir','reverse');
s = linspace(0,1,128)';  cmapBWR = [ [s s ones(128,1)] ; [ones(128,1) 1-s 1-s] ];  % blue->white->red
colormap(ax_map, cmapBWR);

% initial fit = the stim-site pixel
[bpix, cv, yte, yhat_te, nAct] = ols_refit(D, px_prim, py_prim);
wsc = max(abs(bpix))+eps;
hSc  = scatter(ax_map, grR, grC, 26, bpix, 'filled', 'MarkerEdgeColor',[0.1 0.1 0.1], 'LineWidth',0.4);
clim(ax_map,[-wsc wsc]);
cb = colorbar(ax_map,'eastoutside');  cb.Label.String = 'weight (contra px \rightarrow ipsi target)';
hMk  = plot(ax_map, px_prim, py_prim, 'g+', 'MarkerSize',14, 'LineWidth',2);   % clicked ipsi target
hTtl = title(ax_map, sprintf('[%s] target [row %d col %d]   R^2=%.3f   %d/%d px active   (click ipsi)', ...
    D.fit_mode, px_prim, py_prim, cv, nAct, nG), 'FontSize',13, 'FontWeight','bold');

% --- companion figure: 5 BEST (top) / 5 WORST (bottom) held-out windows ------------
figT = figure('Color','w','Name','OLS held-out: 5 best (top) / 5 worst (bottom) windows', ...
    'Units','pixels','Position',[860 120 980 620]);
D.bwWinSec = bwWinSec;  D.detrendSec = detrendSec;
D.axBW = gobjects(10,1);  D.hBWa = gobjects(10,1);  D.hBWp = gobjects(10,1);  D.hBWt = gobjects(10,1);
for m = 1:10
    axb = subplot(2,5,m,'Parent',figT); hold(axb,'on');
    D.hBWa(m) = plot(axb, nan, nan, 'k-', 'LineWidth',1.2, 'DisplayName','actual');
    D.hBWp(m) = plot(axb, nan, nan, 'Color',[0.85 0.15 0.15], 'LineWidth',1.0, 'DisplayName','pred (run-mean corr)');
    D.hBWt(m) = title(axb, '', 'FontSize',9, 'FontWeight','bold');
    set(axb,'Box','off','TickDir','out','FontSize',8);
    if m==6, xlabel(axb,'time (s)','FontSize',9,'FontWeight','bold'); ylabel(axb,'\DeltaF/F (%)','FontSize',9,'FontWeight','bold'); end
    D.axBW(m) = axb;
end
lgb = legend(D.axBW(1),'Location','best','Box','off','FontSize',7);  lgb.ItemTokenSize=[10 10];
sgtitle(figT, sprintf('5 best / 5 worst held-out %.1fs windows — FIXED site pixel [row %d col %d]', ...
    bwWinSec, px_prim, py_prim), 'FontSize',12, 'FontWeight','bold');

% store handles + state, wire callback. The best/worst panel is LOCKED to the site
% pixel (drawn once here); only the kernel map refits on click.
D.ax_map=ax_map; D.hSc=hSc; D.hMk=hMk; D.hTtl=hTtl;
guidata(fig, D);  set(fig,'WindowButtonDownFcn',@ols_click);
update_bestworst(D, yte, yhat_te);   % site-pixel best/worst — drawn once, not updated on click
fprintf('\n[OLS] interactive kernel viewer (%s): click any IPSI pixel -> contra-grid weights refit to predict it.\n', D.fit_mode);
fprintf('[OLS] companion figure = 5 best / 5 worst held-out %.1fs windows for the FIXED site pixel.\n', bwWinSec);
fprintf('[OLS] initial target = stim site [row %d col %d]: R^2 = %.3f, %d/%d px active (fit_mode=%s, l1_frac=%.2f)\n', ...
    px_prim, py_prim, cv, nAct, nG, D.fit_mode, l1_frac);

%% (9) Weights for the initial (stim-site) target — for record
% Per-pixel contra->ipsi OLS weights for the site pixel; click any ipsi pixel in the
% figure to refit for a different target (bpix/cv update live).
OLS = struct('gridIdx',gridIdx,'gridRC',[grR grC],'bpix',bpix,'cv',cv,'nG',nG, ...
             'fit_mode',fit_mode,'l1_frac',l1_frac,'ridge',ridge,'nActive',nAct, ...
             'mn',mn,'td',td,'en',en);

%% (10) [BLEED] Which contra grid pixels are DEFINITELY stim-affected (per amplitude)
% BASELINE = the 0 V (catch) trials, not random spont windows. Per pixel p, per amp a:
%   evoked = peak |trialavg(amp a) - trialavg(amp 0)| over [0, bleed_postSec] s
%            i.e. the stim-EXCESS over the 0 V command (removes any command artifact
%            common to all amps: shutter click, galvo move, etc.)  ["stim to stim+1s"]
%   null   = 95th pctile of the SAME peak from bootstrapped 0 V subsets (size = nTrials
%            of amp a) minus the full 0 V mean = sampling noise of a size-n average at 0 V.
% Pixel is "stim-affected" at amp a if evoked > threshFactor*null -> painted BLACK.
% NOTE the null threshold RISES as nTrials FALLS (a small-n average is noisier), so an amp
% with few trials needs a bigger real effect to flag. The diagnostic table below prints
% nTrials + median evoked/null per amp so a "low amp flags, high amp doesn't" result can be
% read as a trial-count/power effect vs a genuine amplitude reversal.
bleed_preSec  = 0.5;   bleed_postSec = 1.0;    % baseline / post window (s)
bleed_nRand   = 200;   threshFactor  = 1.0;    % 0V-bootstrap draws; evoked must exceed threshFactor*null(95%)
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
stimDev = nan(nG,nA);  nullThr = nan(nG,nA);  mResp = nan(nG,Wb,nA);  nT_amp = zeros(nA,1);
onFcell = cell(nA,1);                                                       % per-amp onset frames (for the verifier)
fprintf('\n[BLEED] baseline = amp-0 (%d catch trials, capped %d). per-amp diagnostics:\n', nT0, maxBaseTrl);
fprintf('   %-8s %6s | %10s %10s %8s\n','amp(V)','nTrl','medEvoked','medNull95','%%aff');
for ai = 1:nA
    onF = local_onsets(imp_data.startTimes{find(uAmp==amps(ai),1)}(:), t_full, preN, postN, nFall);
    nT = numel(onF);  nT_amp(ai) = nT;  onFcell{ai} = onF;
    if nT==0, continue; end
    m = local_periavg(Xpct, onF, rel, preN, nG, Wb);
    d = m - m0;                                                             % evoked EXCESS over 0 V baseline
    mResp(:,:,ai) = d;
    stimDev(:,ai) = max(abs(d(:,postCols)),[],2);                          % evoked peak dev (re 0 V)
    nd = nan(nG,bleed_nRand);                                               % 0 V bootstrap null, size-nT
    for r=1:bleed_nRand
        bb = blk0(:,:, randi(nT0, nT, 1));                                 % resample nT of the 0 V trials
        mb = mean(bb - mean(bb(:,1:preN,:),2), 3) - m0;                    % subset avg re full 0 V mean
        nd(:,r) = max(abs(mb(:,postCols)),[],2);
    end
    nullThr(:,ai) = quantile(nd, 0.95, 2);
    aff = stimDev(:,ai) > threshFactor.*nullThr(:,ai);
    fprintf('   %-8.2f %6d | %10.3f %10.3f %7.0f%%\n', amps(ai), nT, ...
        median(stimDev(:,ai),'omitnan'), median(nullThr(:,ai),'omitnan'), 100*nnz(aff)/max(nG,1));
end
affected = stimDev > threshFactor .* nullThr;                              % [nG x nA]

% --- per-amplitude map: affected pixels BLACK ------------------------------------
figB = figure('Color','w','Name','BLEED — definitely stim-affected contra pixels (per amp)', ...
    'Units','pixels','Position',[100 60 1200 780]);
A2b = mimg_cp.';  gB = (A2b-min(A2b(:)))/max(max(A2b(:))-min(A2b(:)),eps);
nCols = min(nA,3);  nRows = ceil(nA/nCols);  axB = gobjects(nA,1);
for ai=1:nA
    ax = subplot(nRows,nCols,ai,'Parent',figB);  hold(ax,'on');
    image(ax, repmat(gB,[1 1 3]));  axis(ax,'image','off');  set(ax,'YDir','reverse');
    aff = affected(:,ai);
    scatter(ax, grR(~aff), grC(~aff), 12, [0.75 0.75 0.75], 'filled', 'MarkerEdgeColor',[0.4 0.4 0.4], 'LineWidth',0.2);
    scatter(ax, grR(aff),  grC(aff),  20, 'k', 'filled', 'MarkerEdgeColor','k');
    plot(ax, px_prim, py_prim, 'r+', 'MarkerSize',12, 'LineWidth',1.6);
    title(ax, sprintf('%.2f V   %d/%d affected', amps(ai), nnz(aff), nG), 'FontSize',12,'FontWeight','bold');
    axB(ai) = ax;
end
sgtitle(figB, sprintf('Definitely stim-affected contra grid px (black)  %s %s e%d  — click a pixel to inspect', ...
    mn, td, en), 'FontSize',13,'FontWeight','bold');

DB = struct('axB',axB,'amps',amps,'grR',grR,'grC',grC,'mResp',mResp,'stimDev',stimDev, ...
            'nullThr',nullThr,'affected',affected,'rel',rel,'Fs',Fs,'postCols',postCols, ...
            'nT_amp',nT_amp,'nT0',nT0,'preN',preN, ...
            'Xpct',Xpct,'onFcell',{onFcell},'onF0',onF0, ...          % per-trial pull for the verifier
            'gimg',gB,'site',[px_prim py_prim]);                      % brain + site for spatial context
guidata(figB, DB);  set(figB,'WindowButtonDownFcn',@bleed_click);
fprintf('[BLEED] click any pixel -> VERIFIER: per-trial traces + 0V baseline + spatial location/distance.\n');

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
cw_nBoot = 300;  tt_c = rel/Fs;
P_obs = nan(nA,Wb);  P_nul = nan(nA,Wb);  cwEnd = zeros(nA,1);
for ai = 1:nA
    onF = onFcell{ai};  nT = numel(onF);  if nT==0, continue; end
    idx = onF(:).' + rel(:);
    Zp = (double(Uflat(gridIdx,:))*double(V_cp(:,idx(:))) - mu_p)./sd_p;
    ev = mean(reshape(Zp,nG,Wb,nT),3);  ev = ev - mean(ev(:,1:preN),2);
    P_obs(ai,:) = b_ols_cw.' * ev;                                        % predicted ipsi evoked trace
    bd = nan(cw_nBoot,Wb);
    for b = 1:cw_nBoot
        ev0 = mean(Z0(:,:, randi(nT0, nT, 1)),3);                         % size-nT 0 V predicted evoked
        bd(b,:) = abs(b_ols_cw.' * ev0);
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

%% (11) [CLEANFIT] Predictor with the BLACKED (stim-affected) pixels removed, deployed on STIM
% Drop every grid pixel flagged at ANY amplitude (union of the black maps), refit the
% contemporaneous contra->ipsi OLS on SPONTANEOUS data using only the surviving CLEAN pixels,
% then DEPLOY it on the peri-stim windows. Clean prediction = GLOBAL/network activity into the
% ipsi site NOT carried by direct stim bleed; residual (actual - clean prediction) = the LOCAL
% stim effect. If dropping the bleed pixels barely changes the spontaneous R^2 AND the peri-stim
% residual dip survives, the contra coupling is network, not bleed. (Standalone analogue of
% contra_prediction.m [CP-CLEAN]/[CP-CLEANRES].) Reuses section-7 Ztr/Zte/mu_p/sd_p (same split).
anyAff = any(affected,2);  clean = ~anyAff;  nClean = nnz(clean);
y_sp = double(y_full(frames));  ytr = y_sp(itr);  yte = y_sp(ite);
cf_full  = [ones(numel(itr),1) Ztr]          \ ytr;                % full-grid OLS (spont)
cf_clean = [ones(numel(itr),1) Ztr(:,clean)] \ ytr;               % clean-grid OLS (bleed px dropped)
yhat_full  = [ones(numel(ite),1) Zte]          * cf_full;
yhat_clean = [ones(numel(ite),1) Zte(:,clean)] * cf_clean;
R2_full  = 1 - sum((yte-yhat_full ).^2)/max(sum((yte-mean(yte)).^2),eps);
R2_clean = 1 - sum((yte-yhat_clean).^2)/max(sum((yte-mean(yte)).^2),eps);
bclean = cf_clean(2:end);  b0clean = cf_clean(1);
fprintf('\n[CLEANFIT] spont held-out R^2: full grid (%d px)=%.3f | clean grid (%d px, %d bleed dropped)=%.3f\n', ...
    nG, R2_full, nClean, nG-nClean, R2_clean);

% deploy the clean predictor on the peri-stim windows, per amplitude
dipCols = (preN+1):min(Wb, preN+round(dip_win_s*Fs));            % inhibition window (dip_win_s, default 300 ms)
ttc = rel/Fs;
figC = figure('Color','w','Name','CLEANFIT — clean-grid prediction on stim (actual / pred / residual)', ...
    'Units','pixels','Position',[120 90 1180 760]);
nColsC = min(nA,3);  nRowsC = ceil(nA/nColsC);
fprintf('   %-8s %6s | %9s %9s %9s   (0-200 ms dip re pre-onset)\n','amp(V)','nTrl','actual','cleanPred','residual');
for ai = 1:nA
    onF = onFcell{ai};  nT = numel(onF);
    ax = subplot(nRowsC,nColsC,ai,'Parent',figC);  hold(ax,'on');
    if nT==0, title(ax,sprintf('%.2f V: no trials',amps(ai))); continue; end
    idx = onF(:).' + rel(:);                                      % [Wb x nT] frame indices
    Xg_p = double(Uflat(gridIdx,:)) * double(V_cp(:,idx(:)));     % [nG x Wb*nT] raw grid activity
    Zp = (Xg_p - mu_p)./sd_p;                                     % z-score with TRAIN stats
    yhat_p = reshape(b0clean + bclean(:).'*Zp(clean,:), Wb, nT);  % [Wb x nT] clean prediction
    yact_p = reshape(double(y_full(idx(:))), Wb, nT);             % [Wb x nT] actual ipsi
    aA = mean(yact_p,2);  aA = aA - mean(aA(1:preN));             % trial-avg, pre-onset baselined
    pP = mean(yhat_p,2);  pP = pP - mean(pP(1:preN));
    rR = aA - pP;                                                 % residual = LOCAL
    plot(ax, ttc, aA, 'k-', 'LineWidth',1.8, 'DisplayName','actual');
    plot(ax, ttc, pP, '-', 'Color',[0.85 0.15 0.15], 'LineWidth',1.4, 'DisplayName','clean pred (Global)');
    plot(ax, ttc, rR, '-', 'Color',[0.1 0.3 0.9], 'LineWidth',1.4, 'DisplayName','residual (Local)');
    yline(ax,0,'k:','HandleVisibility','off');  xline(ax,0,'k:','HandleVisibility','off');
    set(ax,'Box','off','TickDir','out','FontSize',9);  xlim(ax,[ttc(1) ttc(end)]);
    title(ax, sprintf('%.2f V  (n=%d)',amps(ai),nT),'FontSize',10,'FontWeight','bold');
    if ai==1
        ylabel(ax,'\DeltaF/F (%)','FontWeight','bold');
        lg=legend(ax,'Location','best','Box','off','FontSize',7);  lg.ItemTokenSize=[10 10];
    end
    fprintf('   %-8.2f %6d | %9.3f %9.3f %9.3f\n', amps(ai), nT, mean(aA(dipCols)), mean(pP(dipCols)), mean(rR(dipCols)));
end
sgtitle(figC, sprintf('Clean-grid (bleed-free) predictor on stim  —  %s %s e%d  |  drop %d/%d bleed px, spont R^2 %.3f\\rightarrow%.3f', ...
    mn, td, en, nG-nClean, nG, R2_full, R2_clean), 'FontSize',12,'FontWeight','bold');

CLEANFIT = struct('clean',clean,'nClean',nClean,'nG',nG,'R2_full',R2_full,'R2_clean',R2_clean, ...
                  'bclean',bclean,'b0clean',b0clean,'amps',amps,'mn',mn,'td',td,'en',en);

%% (12) [STIMBLIND] What pixel COMBO predicts spont but shows NO stim effect (diagnostic @ 1.1 V)
% Question: is there a subset of contra grid pixels whose contemporaneous OLS prediction of the
% ipsi site (a) still predicts SPONTANEOUS activity, yet (b) shows NO stim-evoked dip in the
% PREDICTION at 1.1 V? Method: start from the full grid; repeatedly remove the pixel that
% contributes MOST to the predicted peri-stim dip, refit the OLS on spont, and record the
% predicted 1.1 V dip (0-200 ms) and the held-out spont R^2. This traces the tradeoff and the
% surviving "stim-blind" pixel set. Interpretation: if the prediction only goes flat once spont
% R^2 is destroyed, the contra network genuinely co-suppresses (the dip is NOT removable bleed);
% if a few pixels carry the whole predicted dip at little R^2 cost, THOSE are the stim-driven px.
blind_amp = 1.1;                                                 % <-- diagnostic amplitude
[dA,aB] = min(abs(amps - blind_amp));  ampB = amps(aB);
if dA > 1e-6, warning('[STIMBLIND] no exact %.2f V; using nearest amp %.2f V', blind_amp, ampB); end
onFb = onFcell{aB};  nTb = numel(onFb);
if nTb==0, error('[STIMBLIND] no trials at %.2f V', ampB); end

% spont design (reuse section 7 Ztr/Zte) + Gram for fast subset refits; target = ipsi site
ytr = double(y_full(frames(itr)));  yte = double(y_full(frames(ite)));
muY = mean(ytr);  ytrc = ytr - muY;
Gz = Ztr.'*Ztr;  cz = Ztr.'*ytrc;                               % [nG x nG], [nG x 1]
lamR = 1e-6*mean(diag(Gz));                                     % tiny ridge -> stable normal-eqn solves
sstot = max(sum((yte-mean(yte)).^2), eps);
solveB = @(S) (Gz(S,S) + lamR*eye(numel(S))) \ cz(S);

% 1.1 V peri-stim per-pixel evoked z-scored trial-avg (baselined) -> the predicted-dip pieces
idxb = onFb(:).' + rel(:);
Zpb = ((double(Uflat(gridIdx,:))*double(V_cp(:,idxb(:))) - mu_p)./sd_p);
Zpb = reshape(Zpb, nG, Wb, nTb);
evZ = mean(Zpb,3);  evZ = evZ - mean(evZ(:,1:preN),2);          % [nG x Wb] evoked z (baselined)
dipCols = (preN+1):min(Wb, preN+round(dip_win_s*Fs));          % inhibition window (dip_win_s)
evDip = mean(evZ(:,dipCols),2);                                 % [nG x 1] per-pixel dip per unit weight
yact = reshape(double(y_full(idxb(:))), Wb, nTb);
aA = mean(yact,2);  aA = aA - mean(aA(1:preN));                 % actual trial-avg dip (baselined)

% greedy strip: remove the pixel contributing most to the predicted dip, refit, repeat
active = true(nG,1);  maxRem = nG-2;
rem_n = (0:maxRem).';  predDipTraj = nan(maxRem+1,1);  r2Traj = nan(maxRem+1,1);
removedOrder = zeros(maxRem,1);
for step = 0:maxRem
    S = find(active);  bS = solveB(S);
    predDipTraj(step+1) = bS.'*evDip(S);                        % predicted 0-200 ms dip
    r2Traj(step+1)      = 1 - sum((yte-(muY+Zte(:,S)*bS)).^2)/sstot;
    if step==maxRem, break; end
    contrib = bS.*evDip(S);                                     % signed pixel contributions (sum=predDip)
    if predDipTraj(step+1) < 0, [~,k] = min(contrib); else, [~,k] = max(contrib); end
    removedOrder(step+1) = S(k);  active(S(k)) = false;         % drop the most dip-driving pixel
end
dipTol = 0.05*abs(predDipTraj(1));                              % "stim-blind" = <=5% of initial predicted dip
kSel = find(abs(predDipTraj) <= dipTol, 1);  if isempty(kSel), kSel = maxRem+1; end
kSel = kSel - 1;                                                % #pixels removed at the stim-blind point
blindMask = true(nG,1);  if kSel>0, blindMask(removedOrder(1:kSel)) = false; end
Sb = find(blindMask);  bBlind = solveB(Sb);  bFull = solveB((1:nG).');
predBlind = (bBlind.'*evZ(Sb,:)).';                            % [Wb x 1] stim-blind predicted trace
predFull  = (bFull.'*evZ).';
r2Blind = 1 - sum((yte-(muY+Zte(:,Sb)*bBlind)).^2)/sstot;
fprintf('\n[STIMBLIND] @ %.2f V (n=%d): to zero the predicted dip removed %d/%d px (%.0f%%).\n', ...
    ampB, nTb, kSel, nG, 100*kSel/nG);
fprintf('   predicted dip: full=%.3f -> blind=%.3f  |  spont R^2: full=%.3f -> blind=%.3f  |  actual dip=%.3f\n', ...
    predDipTraj(1), (bBlind.'*evDip(Sb)), r2Traj(1), r2Blind, mean(aA(dipCols)));

% --- Fig 1: tradeoff curve (predicted dip & spont R^2 vs #pixels removed) ------------
ttb = rel/Fs;
figS1 = figure('Color','w','Name',sprintf('STIMBLIND tradeoff @ %.2f V',ampB), ...
    'Units','pixels','Position',[140 120 720 480]);
axT = axes(figS1);  yyaxis(axT,'left');
plot(axT, rem_n, predDipTraj, '-', 'Color',[0.1 0.3 0.9], 'LineWidth',1.8);  hold(axT,'on');
yline(axT, 0, 'k:');  ylabel(axT,'predicted 0-200 ms dip (\DeltaF/F %)','FontWeight','bold');
yyaxis(axT,'right');
plot(axT, rem_n, r2Traj, '-', 'Color',[0.85 0.15 0.15], 'LineWidth',1.8);
ylabel(axT,'spont held-out R^2','FontWeight','bold');
xline(axT, kSel, 'k--', sprintf('stim-blind: %d px removed',kSel), 'LabelOrientation','horizontal','FontSize',9);
xlabel(axT,'# pixels removed (most dip-driving first)','FontWeight','bold');
set(axT,'Box','off','TickDir','out','FontSize',11);
title(axT, sprintf('%s %s e%d  —  driving the PREDICTED stim dip to 0 vs spont R^2 cost', mn,td,en), ...
    'FontSize',11,'FontWeight','bold');

% --- Fig 2: the stim-blind predictor on 1.1 V trials (actual / pred / residual) ------
figS2 = figure('Color','w','Name',sprintf('STIMBLIND predictor @ %.2f V',ampB), ...
    'Units','pixels','Position',[880 120 620 480]);
axP = axes(figS2); hold(axP,'on');
plot(axP, ttb, aA,        'k-',  'LineWidth',1.9, 'DisplayName','actual');
plot(axP, ttb, predFull,  '--', 'Color',[0.85 0.15 0.15], 'LineWidth',1.2, 'DisplayName',sprintf('full pred (dip=%.2f)',predDipTraj(1)));
plot(axP, ttb, predBlind, '-',  'Color',[0.85 0.15 0.15], 'LineWidth',1.7, 'DisplayName',sprintf('stim-blind pred (dip=%.2f)',bBlind.'*evDip(Sb)));
plot(axP, ttb, aA-predBlind, '-','Color',[0.1 0.3 0.9], 'LineWidth',1.5, 'DisplayName','residual (blind)');
yline(axP,0,'k:','HandleVisibility','off');  xline(axP,0,'k:','HandleVisibility','off');
set(axP,'Box','off','TickDir','out','FontSize',11);  xlim(axP,[ttb(1) ttb(end)]);
xlabel(axP,'time re onset (s)','FontWeight','bold');  ylabel(axP,'\DeltaF/F (%)','FontWeight','bold');
title(axP, sprintf('%.2f V: stim-blind pred flat (R^2 %.3f\\rightarrow%.3f)', ampB, r2Traj(1), r2Blind), ...
    'FontSize',11,'FontWeight','bold');
lgS = legend(axP,'Location','best','Box','off','FontSize',8);  lgS.ItemTokenSize=[12 12];

% --- Fig 3: the surviving pixel COMBO (removed=black, kept=weight-colored) -----------
figS3 = figure('Color','w','Name',sprintf('STIMBLIND pixel combo @ %.2f V',ampB), ...
    'Units','pixels','Position',[140 620 720 520]);
axM = axes(figS3); hold(axM,'on');
Ab = mimg_cp.';  gBs = (Ab-min(Ab(:)))/max(max(Ab(:))-min(Ab(:)),eps);
image(axM, repmat(gBs,[1 1 3]));  axis(axM,'image','off');  set(axM,'YDir','reverse');
s = linspace(0,1,128)';  colormap(axM, [ [s s ones(128,1)] ; [ones(128,1) 1-s 1-s] ]);
wB = zeros(nG,1);  wB(Sb) = bBlind;  wsc = max(abs(wB))+eps;
scatter(axM, grR(~blindMask), grC(~blindMask), 22, 'k', 'filled', 'MarkerEdgeColor','k', 'DisplayName','removed');
scatter(axM, grR(blindMask),  grC(blindMask),  26, wB(blindMask), 'filled', 'MarkerEdgeColor',[0.2 0.2 0.2], 'LineWidth',0.3);
clim(axM,[-wsc wsc]);  colorbar(axM,'eastoutside');
plot(axM, px_prim, py_prim, 'g+', 'MarkerSize',14, 'LineWidth',2);
title(axM, sprintf('stim-blind COMBO @ %.2f V: %d kept (colored) / %d removed (black)', ampB, numel(Sb), kSel), ...
    'FontSize',11,'FontWeight','bold');

STIMBLIND = struct('ampB',ampB,'kSel',kSel,'nG',nG,'blindMask',blindMask,'keptIdx',Sb, ...
                   'removedOrder',removedOrder(1:max(kSel,0)),'predDipTraj',predDipTraj,'r2Traj',r2Traj, ...
                   'r2Full',r2Traj(1),'r2Blind',r2Blind,'predDipFull',predDipTraj(1),'actualDip',mean(aA(dipCols)));

%% (13) [CLEANMAX-RADIAL] Discard 1.1 V bled pixels RADIALLY outward, fit OLS on leftovers
% Bleed physics: the stim artifact falls off RADIALLY from the laser point, so the closest
% contra pixels are the most contaminated. Two upgrades vs a flat threshold sweep:
%  (1) MORE SENSITIVE bleed test — integrated 0-200 ms evoked ENERGY (signed dip), z-scored
%      against a 0 V bootstrap null (SD-based, not a hard 95th-pctile peak) -> catches weak,
%      sustained bleed a peak test misses. Knob bleed_z_thr (LOWER = more sensitive).
%  (2) RADIAL cancellation — order the flagged bled pixels by DISTANCE from the primary
%      (laser) pixel and cancel them nearest-first, expanding the discard radius outward.
% Refit OLS on the leftovers at each radius, tracking held-out spont R^2 + predicted 1.1 V
% dip: how far out must we cancel to remove the bleed, and at what R^2 cost.
clean_amp    = 1.1;        % diagnostic amplitude
bleed_z_thr  = 1.28;       % |z| of integrated 0-200 ms dip energy vs 0V null to CALL a pixel bled
                           %   (1.28~90%, 1.64~95%, 2.33~99%; LOWER = more sensitive -> more px flagged)
bleed_nRandC = 300;        % 0V bootstrap draws for the sensitive null
[dC,aC] = min(abs(amps - clean_amp));  ampC = amps(aC);
if dC > 1e-6, warning('[CLEANMAX] no exact %.2f V; using nearest amp %.2f V', clean_amp, ampC); end
onFc = onFcell{aC};  nTc = numel(onFc);
if nTc==0, error('[CLEANMAX] no trials at %.2f V', ampC); end

% spont Gram (reuse section-12 Gz/cz/muY if present, else build) + held-out target
if ~exist('Gz','var') || ~exist('cz','var') || ~exist('muY','var')
    ytr = double(y_full(frames(itr)));  muY = mean(ytr);  Gz = Ztr.'*Ztr;  cz = Ztr.'*(ytr-muY);
end
yte = double(y_full(frames(ite)));  sstot = max(sum((yte-mean(yte)).^2), eps);
lamR = 1e-6*mean(diag(Gz));  solveB = @(S)(Gz(S,S)+lamR*eye(numel(S)))\cz(S);

% 1.1 V evoked pieces: z-scored (for the predicted dip) + raw excess dip (for the bleed test)
idxc = onFc(:).' + rel(:);
Zpc = reshape((double(Uflat(gridIdx,:))*double(V_cp(:,idxc(:))) - mu_p)./sd_p, nG, Wb, nTc);
evZ = mean(Zpc,3);  evZ = evZ - mean(evZ(:,1:preN),2);         % [nG x Wb] evoked z (baselined)
dipCols = (preN+1):min(Wb, preN+round(dip_win_s*Fs));         % inhibition window (dip_win_s)
evDip = mean(evZ(:,dipCols),2);                               % predicted-dip per unit weight
aA = mean(reshape(double(y_full(idxc(:))),Wb,nTc),2);  aA = aA - mean(aA(1:preN));
actualDip = mean(aA(dipCols));

% ---- SENSITIVE bleed test: ABSOLUTE coupling energy z-scored vs a 0V bootstrap null -----
% Classify bleed over the full (biphasic) coupling window with |evoked| so the dip and rebound
% lobes both count (a signed dip-mean cancels them). evDip above stays the signed dip we cancel.
cplCols = (preN+1):min(Wb, preN+round(max(couple_win_s,dip_win_s)*Fs)); % coupling window
eDip = mean(abs(mResp(:,cplCols,aC)),2);                      % ABS evoked coupling energy (|amp - 0V|), %dF/F
ndDip = nan(nG,bleed_nRandC);                                 % 0V bootstrap null of the same statistic
for r = 1:bleed_nRandC
    bb = blk0(:,:, randi(nT0, nTc, 1));                       % random nTc-subset of the 0V trials
    mb = mean(bb - mean(bb(:,1:preN,:),2), 3) - m0;           % subset avg re full 0V mean
    ndDip(:,r) = mean(abs(mb(:,cplCols)),2);                  % same ABS-energy statistic under 0V
end
mu0 = mean(ndDip,2);  sd0 = std(ndDip,0,2);
zBleed = (eDip - mu0) ./ max(sd0, eps);                       % one-sided z; large => bled
bled = zBleed > bleed_z_thr;
dist = hypot(grR - px_prim, grC - py_prim);                  % distance from laser/primary pixel
fprintf('\n[CLEANMAX-RADIAL] @ %.2f V (n=%d): sensitive test (z>%.2f on |coupling| energy, %.0f ms) flags %d/%d px bled.\n', ...
    ampC, nTc, bleed_z_thr, numel(cplCols)/Fs*1000, nnz(bled), nG);

% ---- RADIAL cancellation sweep: cancel bled pixels nearest-first, refit each step -------
[~,ordD] = sort(dist,'ascend');  bledOrd = ordD(bled(ordD));  % bled pixels, nearest -> farthest
nB = numel(bledOrd);
kvals = unique(round(linspace(0, nB, min(nB+1, 30))));  nK = numel(kvals);
swpDisc=zeros(nK,1); swpRad=zeros(nK,1); swpR2=nan(nK,1); swpDip=nan(nK,1);
for i = 1:nK
    kk = kvals(i);  keep = true(nG,1);  if kk>0, keep(bledOrd(1:kk)) = false; end
    S = find(keep);  swpDisc(i)=kk;  if kk>0, swpRad(i) = dist(bledOrd(kk)); end
    if numel(S) < 2, continue; end
    bS = solveB(S);
    swpR2(i)  = 1 - sum((yte-(muY+Zte(:,S)*bS)).^2)/sstot;
    swpDip(i) = bS.'*evDip(S);
end
ceilR2 = swpR2(1);                                           % k=0 => full grid ceiling
dipTol = 0.10*abs(swpDip(1));                                % "bleed removed" = predicted dip <=10% of full
knee = find(abs(swpDip) <= dipTol, 1);  if isempty(knee), knee = nK; end
kSel = swpDisc(knee);  radSel = swpRad(knee);
keep = true(nG,1);  if kSel>0, keep(bledOrd(1:kSel)) = false; end
Sk = find(keep);  bK = solveB(Sk);  predK = (bK.'*evZ(Sk,:)).';  r2K = swpR2(knee);  dipK = swpDip(knee);
fprintf('   radial cancel to R=%.0f px removes %d bled px -> predicted dip %.3f->%.3f, spont R^2 %.3f->%.3f (ceil %.3f).\n', ...
    radSel, kSel, swpDip(1), dipK, ceilR2, r2K, ceilR2);
fprintf('   sweep (#discard | radius px | R^2 | predDip):\n');
for i=1:nK, fprintf('     %6d | %8.0f | %6.3f | %7.3f\n', swpDisc(i), swpRad(i), swpR2(i), swpDip(i)); end

% --- Fig 0: RADIAL bleed profile — |z| dip energy vs distance from primary -----------
ttc = rel/Fs;
figR0 = figure('Color','w','Name',sprintf('CLEANMAX radial bleed profile @ %.2f V',ampC), ...
    'Units','pixels','Position',[140 120 640 460]);
axR = axes(figR0); hold(axR,'on');
scatter(axR, dist(~bled), abs(zBleed(~bled)), 18, [0.6 0.6 0.6], 'filled', 'DisplayName','not bled');
scatter(axR, dist(bled),  abs(zBleed(bled)),  24, 'k', 'filled', 'DisplayName','bled');
yline(axR, bleed_z_thr, 'r--', 'DisplayName','|z| threshold');
if radSel>0, xline(axR, radSel, 'k--', sprintf('cancel radius %.0f',radSel), 'FontSize',9, 'LabelOrientation','horizontal'); end
set(axR,'Box','off','TickDir','out','FontSize',11);
xlabel(axR,'distance from primary/laser pixel (px)','FontWeight','bold');
ylabel(axR,'|z|  (0-200 ms dip energy vs 0V)','FontWeight','bold');
title(axR, sprintf('%s %s e%d — bleed decays RADIALLY (%d/%d px bled)', mn,td,en, nnz(bled),nG), 'FontSize',11,'FontWeight','bold');
lgR = legend(axR,'Location','best','Box','off','FontSize',9);  lgR.ItemTokenSize=[12 12];

% --- Fig 1: radial cancellation sweep (held-out R^2 & predicted dip vs cancel radius) -
figC1 = figure('Color','w','Name',sprintf('CLEANMAX radial sweep @ %.2f V',ampC), ...
    'Units','pixels','Position',[800 120 740 480]);
axS = axes(figC1);  yyaxis(axS,'left');
plot(axS, swpRad, swpR2, '-o', 'Color',[0.85 0.15 0.15], 'LineWidth',1.8, 'MarkerFaceColor',[0.85 0.15 0.15]);
hold(axS,'on');  yline(axS, ceilR2, 'k:', 'ceiling (full grid)', 'FontSize',9);
ylabel(axS,'held-out spont R^2','FontWeight','bold');
yyaxis(axS,'right');
plot(axS, swpRad, swpDip, '-s', 'Color',[0.1 0.3 0.9], 'LineWidth',1.8, 'MarkerFaceColor',[0.1 0.3 0.9]);
yline(axS, 0, 'k:', 'HandleVisibility','off');  ylabel(axS,'predicted 1.1 V dip (\DeltaF/F %)','FontWeight','bold');
if radSel>0, xline(axS, radSel, 'k--', sprintf('knee R=%.0f (%d px)',radSel,kSel), 'FontSize',9, 'LabelOrientation','horizontal'); end
xlabel(axS,'radial cancel radius from primary (px)','FontWeight','bold');
set(axS,'Box','off','TickDir','out','FontSize',11);
title(axS, sprintf('%s %s e%d — cancel bled px outward: R^2 cost vs predicted-dip removal', mn,td,en), 'FontSize',11,'FontWeight','bold');

% --- Fig 2: bleed-free predictor on 1.1 V (actual / pred / residual) at the knee -----
figC2 = figure('Color','w','Name',sprintf('CLEANMAX predictor @ %.2f V',ampC), ...
    'Units','pixels','Position',[800 620 620 480]);
axQ = axes(figC2); hold(axQ,'on');
plot(axQ, ttc, aA,        'k-', 'LineWidth',1.9, 'DisplayName','actual');
plot(axQ, ttc, predK,     '-', 'Color',[0.85 0.15 0.15], 'LineWidth',1.7, 'DisplayName',sprintf('bleed-free pred (dip=%.2f)',dipK));
plot(axQ, ttc, aA-predK,  '-', 'Color',[0.1 0.3 0.9], 'LineWidth',1.5, 'DisplayName','residual (Local)');
yline(axQ,0,'k:','HandleVisibility','off');  xline(axQ,0,'k:','HandleVisibility','off');
set(axQ,'Box','off','TickDir','out','FontSize',11);  xlim(axQ,[ttc(1) ttc(end)]);
xlabel(axQ,'time re onset (s)','FontWeight','bold');  ylabel(axQ,'\DeltaF/F (%)','FontWeight','bold');
title(axQ, sprintf('%.2f V bleed-free: keep %d px, R^2=%.3f (ceil %.3f), captures %.0f%% of dip', ...
    ampC, numel(Sk), r2K, ceilR2, 100*dipK/max(abs(actualDip),eps)*sign(actualDip)), 'FontSize',10,'FontWeight','bold');
lgQ = legend(axQ,'Location','best','Box','off','FontSize',8);  lgQ.ItemTokenSize=[12 12];

% --- Fig 3: kept (weight-colored) vs discarded bled (black) + cancel-radius ring ------
figC3 = figure('Color','w','Name',sprintf('CLEANMAX combo @ %.2f V',ampC), ...
    'Units','pixels','Position',[140 620 620 520]);
axC = axes(figC3); hold(axC,'on');
Ac = mimg_cp.';  gBc = (Ac-min(Ac(:)))/max(max(Ac(:))-min(Ac(:)),eps);
image(axC, repmat(gBc,[1 1 3]));  axis(axC,'image','off');  set(axC,'YDir','reverse');
s = linspace(0,1,128)';  colormap(axC, [ [s s ones(128,1)] ; [ones(128,1) 1-s 1-s] ]);
keptMask = false(nG,1);  keptMask(Sk)=true;  wC = zeros(nG,1);  wC(Sk)=bK;  wsc = max(abs(wC))+eps;
scatter(axC, grR(~keptMask), grC(~keptMask), 22, 'k', 'filled', 'MarkerEdgeColor','k', 'DisplayName','discarded (bled)');
scatter(axC, grR(keptMask),  grC(keptMask),  26, wC(keptMask), 'filled', 'MarkerEdgeColor',[0.2 0.2 0.2], 'LineWidth',0.3);
clim(axC,[-wsc wsc]);  colorbar(axC,'eastoutside');
if radSel>0, th = linspace(0,2*pi,120); plot(axC, px_prim+radSel*cos(th), py_prim+radSel*sin(th), 'g--', 'LineWidth',1.2); end
plot(axC, px_prim, py_prim, 'g+', 'MarkerSize',14, 'LineWidth',2);
title(axC, sprintf('bleed-free COMBO @ %.2f V: keep %d / discard %d (radius %.0f px)', ampC, numel(Sk), nG-numel(Sk), radSel), ...
    'FontSize',11,'FontWeight','bold');

CLEANMAX = struct('ampC',ampC,'bleed_z_thr',bleed_z_thr,'zBleed',zBleed,'bled',bled,'dist',dist,'bledOrd',bledOrd, ...
                  'swpDisc',swpDisc,'swpRad',swpRad,'swpR2',swpR2,'swpDip',swpDip,'ceilR2',ceilR2, ...
                  'knee',knee,'kSel',kSel,'radSel',radSel,'keptIdx',Sk,'keptMask',keptMask,'bKept',bK, ...
                  'r2Knee',r2K,'predDipKnee',dipK,'actualDip',actualDip,'mn',mn,'td',td,'en',en);

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
bc_nRand  = 300;                                              % 0V bootstrap draws
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
Abc = mimg_cp.';  gBC = (Abc-min(Abc(:)))/max(max(Abc(:))-min(Abc(:)),eps);
image(axMap, repmat(gBC,[1 1 3]));  axis(axMap,'image','off');  set(axMap,'YDir','reverse');
scMap = scatter(axMap, grR, grC, 28, nBledAmp, 'filled', 'MarkerEdgeColor',[0.25 0.25 0.25], 'LineWidth',0.3);
colormap(axMap, parula(max(nA+1,2)));  clim(axMap,[0 nA]);
cb2 = colorbar(axMap,'eastoutside');  cb2.Label.String = '# amplitudes bled';
plot(axMap, px_prim, py_prim, 'g+', 'MarkerSize',14, 'LineWidth',2);
title(axMap,'map: # amps each pixel is bled at  (click a pixel \rightarrow full report)','FontSize',10,'FontWeight','bold');

BC = struct('axMap',axMap,'scMap',scMap,'grR',grR,'grC',grC,'nG',nG,'amps',amps,'nA',nA, ...
            'mResp',mResp,'rel',rel,'Fs',Fs,'preN',preN,'dipCols',cplColsBC, ...
            'eDipA',eDipA,'mu0A',mu0A,'sd0A',sd0A,'zA',zA,'bledA',bledA,'slopeA',slopeA, ...
            'z_thr',bc_z_thr,'dist',distBC,'site',[px_prim py_prim]);
guidata(figBC, BC);  set(figBC,'WindowButtonDownFcn',@bleedchar_click);
fprintf('[BLEEDCHAR] click any pixel on the map -> its z(amp) curve, evoked traces, and 0V null band.\n');

BLEEDCHAR = struct('zA',zA,'bledA',bledA,'eDipA',eDipA,'mu0A',mu0A,'sd0A',sd0A,'slopeA',slopeA, ...
                   'nBledAmp',nBledAmp,'dist',distBC,'amps',amps,'z_thr',bc_z_thr,'mn',mn,'td',td,'en',en);

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
fprintf('\n[SETTLETIME] primary-pixel impulse landmarks (0V-subtracted, per amp):\n');
fprintf('   amp(V)  nTrl | trough(ms)  depth | recover(ms) | reboundPk(ms)  height | settle(ms)\n');
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

    if rc < Wb                                          % rebound = max positive lobe after recovery
        [dRb, iRl] = max(m(rc:Wb));  iR = rc + iRl - 1;
        if dRb > tolR, Dreb(ai) = dRb;  Lreb(ai) = tms(iR); end
    end

    tolS = max(2*bslSD, st_setFac*abs(dTr));            % full-settle band (both lobes inside)
    lb = find(abs(seg) > tolS, 1, 'last');              % last excursion outside the band
    if isempty(lb), Lset(ai) = 0; else, Lset(ai) = tms(preN+lb); end

    fprintf('   %-6.2f %5d | %8.0f %7.3f | %9.0f | %11s %7s | %8.0f\n', ...
        amps(ai), nT, Ltr(ai), Dtr(ai), Lrec(ai), ...
        ternchar(isnan(Lreb(ai)),'   --',sprintf('%6.0f',Lreb(ai))), ...
        ternchar(isnan(Dreb(ai)),'  --',sprintf('%5.3f',Dreb(ai))), Lset(ai));
end

medRec = median(Lrec,'omitnan');
fprintf('   --> median recovery (end-of-inhibition) = %.0f ms   (current window = %.0f ms)\n', medRec, st_win*1000);
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
yline(axL, 0, 'Color',[.6 .6 .6], 'HandleVisibility','off');
xlabel(axL,'time from onset (ms)'); ylabel(axL,'evoked \DeltaF/F (amp - 0V, %)');
title(axL,'trial-avg impulse @ primary pixel  (\itv\rm=trough, \it\wedge\rm=rebound)','FontSize',10,'FontWeight','bold');
legend(axL,'Location','southeast','FontSize',7); xlim(axL,[tms(1) tms(end)]);

axR = subplot(1,2,2); hold(axR,'on');  box(axR,'on');
plot(axR, amps, Ltr,  '-o', 'Color',[0.85 0.2 0.2], 'MarkerFaceColor',[0.85 0.2 0.2], 'DisplayName','trough');
plot(axR, amps, Lrec, '-s', 'Color',[0.1 0.5 0.1], 'MarkerFaceColor',[0.1 0.5 0.1], 'DisplayName','recovery (end of inhib)');
plot(axR, amps, Lreb, '-^', 'Color',[0.2 0.3 0.9], 'MarkerFaceColor',[0.2 0.3 0.9], 'DisplayName','rebound peak');
plot(axR, amps, Lset, '-d', 'Color',[0.4 0.4 0.4], 'MarkerFaceColor',[0.4 0.4 0.4], 'DisplayName','full settle');
yline(axR, st_win*1000, 'r--', sprintf('%.0f ms',st_win*1000), 'LineWidth',1.2, 'LabelHorizontalAlignment','left', 'HandleVisibility','off');
xlabel(axR,'amplitude (V)'); ylabel(axR,'time from onset (ms)');
title(axR,'landmark timing vs amplitude','FontSize',10,'FontWeight','bold');
legend(axR,'Location','northwest','FontSize',7); grid(axR,'on');

SETTLE = struct('amps',amps,'tms',tms,'mAmp',mAmp,'tTrough',Ltr,'dTrough',Dtr, ...
                'tRecover',Lrec,'tRebound',Lreb,'dRebound',Dreb,'tSettle',Lset, ...
                'medRecover',medRec,'win_ms',st_win*1000);

%% (16) [FARPIX] Two populations of flagged contra px: near-site NEURAL dips vs far optical BLEED
% The contra pixels the z-metric flags -- neural co-suppression or optical bleed?  They split into
% TWO populations by the SIGN of the strong-amp response: NEGATIVE (a dip, like ipsi) vs POSITIVE
% (added light).  Optical bleed = INSTANTANEOUS (laser photons the same frame) + positive; neural
% co-suppression = DELAYED (conduction) + negative + dip-like.  For every STRONG pixel (|z|>fp_zstr)
% we take its strongest amplitude, extract onset latency + peak time in the early [0,fp_earlySec]
% window, and compare the two populations' DISTANCE from the laser -- bleed should sit closer.
fp_zstr     = 2.0;     % strong-response gate on max_amp |z| (clean kinetics only)
fp_earlySec = 0.400;   % early window (s): covers bleed + inhibition, excludes the ~550 ms rebound
tms_fp  = rel/Fs*1000;  earlyC = (preN+1):min(Wb, preN+round(fp_earlySec*Fs));
zbestF  = max(abs(zA),[],2);  [~,bestA] = max(abs(zA),[],2);   % per-px strongest amplitude
trBest  = nan(nG,Wb);  for p=1:nG, trBest(p,:)=mResp(p,:,bestA(p)); end
latF=nan(nG,1); texF=nan(nG,1); extF=nan(nG,1);
for p = 1:nG
    seg=trBest(p,earlyC); bsl=std(trBest(p,1:preN));
    [~,iA]=max(abs(seg)); e=seg(iA); extF(p)=e; tol=max(2*bsl,0.3*abs(e));
    if e<0, oi=find(seg<=-tol,1,'first'); else, oi=find(seg>=tol,1,'first'); end
    if ~isempty(oi), latF(p)=tms_fp(preN+oi); end
    texF(p)=tms_fp(preN+iA);
end
dR = hypot(grR(:)-px_prim, grC(:)-py_prim);
S = zbestF>fp_zstr;  posP = S & extF>0;  negP = S & extF<0;   % two populations
[pDist] = ranksum(dR(posP), dR(negP));
fprintf('\n[FARPIX] %d strong contra px (|z|>%.1f): %d POSITIVE, %d NEGATIVE\n', nnz(S), fp_zstr, nnz(posP), nnz(negP));
fprintf('   POSITIVE (bleed?): dist med %.0f px | onset med %.0f ms | peak med %.0f ms\n', median(dR(posP)),median(latF(posP),'omitnan'),median(texF(posP)));
fprintf('   NEGATIVE (dip?)  : dist med %.0f px | onset med %.0f ms | peak med %.0f ms\n', median(dR(negP)),median(latF(negP),'omitnan'),median(texF(negP)));
fprintf('   dist(pos) vs dist(neg): ranksum p=%.3g  => NEG sits nearer (neural), POS farther (bleed)\n', pDist);

figFP = figure('Color','w','Name','[FARPIX] two populations: near neural dip vs far bleed','Position',[60 60 1250 420]);
% (1) spatial map: red=positive(bleed), blue=negative(dip), on the brain
ax1=subplot(1,3,1); hold(ax1,'on');
Afp=mimg_cp.'; gFP=(Afp-min(Afp(:)))/max(max(Afp(:))-min(Afp(:)),eps);
image(ax1, repmat(gFP,[1 1 3])); axis(ax1,'image','off'); set(ax1,'YDir','reverse');
scatter(ax1, grR(negP), grC(negP), 34, [0.1 0.3 0.9], 'filled','MarkerEdgeColor','w','LineWidth',.3);
scatter(ax1, grR(posP), grC(posP), 34, [0.9 0.15 0.15],'filled','MarkerEdgeColor','w','LineWidth',.3);
plot(ax1, px_prim, py_prim, 'g+', 'MarkerSize',15,'LineWidth',2);
title(ax1,sprintf('blue=dip (n=%d, near)  red=bleed (n=%d, far)',nnz(negP),nnz(posP)),'FontSize',9,'FontWeight','bold');
% (2) population-mean evoked traces (each at its best amp)
ax2=subplot(1,3,2); hold(ax2,'on'); box(ax2,'on');
mp=mean(trBest(posP,:),1); mn=mean(trBest(negP,:),1);
plot(ax2, tms_fp, mn, '-','Color',[0.1 0.3 0.9],'LineWidth',1.8,'DisplayName','negative (dip)');
plot(ax2, tms_fp, mp, '-','Color',[0.9 0.15 0.15],'LineWidth',1.8,'DisplayName','positive (bleed)');
xline(ax2,0,'k:'); yline(ax2,0,'k:'); xlim(ax2,[-200 600]);
xlabel(ax2,'time from onset (ms)'); ylabel(ax2,'evoked \DeltaF/F (amp - 0V, %)');
title(ax2,'population-mean kinetics','FontSize',9,'FontWeight','bold'); legend(ax2,'Location','southeast','FontSize',7);
% (3) distance distributions
ax3=subplot(1,3,3); hold(ax3,'on'); box(ax3,'on');
eD=linspace(min(dR(S)),max(dR(S)),12);
histogram(ax3, dR(negP), eD, 'FaceColor',[0.1 0.3 0.9],'FaceAlpha',.5,'DisplayName','dip (neural)');
histogram(ax3, dR(posP), eD, 'FaceColor',[0.9 0.15 0.15],'FaceAlpha',.5,'DisplayName','bleed');
xlabel(ax3,'distance from laser site (px)'); ylabel(ax3,'# pixels');
title(ax3,sprintf('near=dip, far=bleed  (ranksum p=%.1g)',pDist),'FontSize',9,'FontWeight','bold'); legend(ax3,'Location','northwest','FontSize',7);
sgtitle('FARPIX: flagged contra px are TWO populations -- near-site delayed NEURAL dips + far INSTANTANEOUS bleed','FontWeight','bold');

FARPIX = struct('zbest',zbestF,'bestAmp',amps(bestA),'ext',extF,'lat',latF,'tex',texF,'dist',dR, ...
                'strong',S,'posP',posP,'negP',negP,'pDist',pDist, ...
                'nPos',nnz(posP),'nNeg',nnz(negP));

%% (17) [AGL-STIMBLIND] *** PRIMARY *** Actual / Global / Local decomposition (stim-blind contra pred)
% PRIMARY decomposition (locked 2026-07-04). This is the scientifically correct one for the paper's
% TASK: isolating the LOCAL-ONLY stim effect. The contra prediction (Global) is made blind to the
% stim so it carries ONLY the ongoing global brain state; the RESIDUAL (Local) then captures the
% FULL stim-evoked inhibition, which is the quantity of interest. (Best-pred §18 is SECONDARY: it
% asks the different question "how much CAN contra explain?" and is a ceiling/robustness check, not
% the local-effect estimator.)
%   Global (contra pred) = spont-trained OLS with the per-amp stim-dip direction PROJECTED OUT
%                          (closed-form equality constraint: predicted dip = 0 at every amplitude).
%   Local  (residual)    = Actual - Global  = the entire stim-evoked dip.
% This is a decomposition CHOICE, not a bleed property: contra genuinely co-suppresses (see §16),
% so "predict spont, predict no stim" must be IMPOSED. Cost is only ~0.05 spont R^2 because the
% stim-dip direction is a low-variance (though predictable) contra subspace. Everything stim-locked
% (incl. bilateral co-suppression) is thereby assigned to Local -- a spontaneous-vs-stim-evoked split.
con_ampRef = amps;                              % constrain the dip=0 at these amps (default: all)
ytrC=y_sp(itr); yteC=y_sp(ite); muYc=mean(ytrC);
Gc = Ztr.'*Ztr;  b_ols = Gc\(Ztr.'*(ytrC-muYc));
R2c = @(y,yh) 1 - sum((y-yh).^2)/max(sum((y-mean(y)).^2),eps);

% COUPLING-SUBSPACE null over the data-driven window (§10b couple_win_s). Instead of one dip-window
% MEAN direction per amp, project out the ENTIRE contra coupling subspace over [onset, couple_win_s]:
% the contra evoked patterns at EVERY bin through the coupling window, across all amps. Nulling their
% full column space forces the stim-blind prediction's evoked to ~0 across the WHOLE window (dip AND
% rebound), so the residual (Local) captures the COMPLETE stim effect (point 5: maximize residual
% stim-capture). Higher spont-R^2 cost than the old dip-mean null is expected and accepted by design.
% FLOOR the null span to at least dip_win_s: the dip is REPORTED over dip_win_s, so the null must cover
% it or the (couple..dip) tail leaks into Global sign-flipped (amplitude-limited sessions e.g. AL_0041
% e1, whose measured coupling ~171 ms < 300 ms dip window). max() makes this consistent with §13/§14.
null_win_s = max(couple_win_s, dip_win_s);                   % coupling span, floored to the reporting dip window
cwN = round(null_win_s*Fs);  cwCols = (preN+1):min(Wb, preN+max(cwN,1));
dipColsA = (preN+1):min(Wb, preN+round(dip_win_s*Fs));       % unipolar dip window (for reporting only)
EVcell=cell(numel(amps),1);  Apatt=[];
for ai=1:numel(amps)
    onF=onFcell{ai}; nT=numel(onF); if nT==0 || ~ismember(amps(ai),con_ampRef), continue; end
    idx=onF(:).'+rel(:);
    Zp=(double(Uflat(gridIdx,:))*double(V_cp(:,idx(:)))-mu_p)./sd_p;
    ev=mean(reshape(Zp,nG,Wb,nT),3); ev=ev-mean(ev(:,1:preN),2);
    EVcell{ai}=ev; Apatt=[Apatt, ev(:,cwCols)];              %#ok<AGROW> contra evoked over coupling window
end
Ae = orth(Apatt);                                            % orthonormal basis of the coupling subspace
GiA = Gc\Ae;
b_con = b_ols - GiA*(pinv(Ae.'*GiA)*(Ae.'*b_ols));           % STIM-BLIND: null coupling across whole window
r2_ols=R2c(yteC, muYc+Zte*b_ols);  r2_con=R2c(yteC, muYc+Zte*b_con);
fprintf('\n[AGL-STIMBLIND] coupling-subspace null over %.0f ms (measured coupling %.0f ms, floored to dip %.0f ms): %d directions projected out.\n', ...
    1000*null_win_s, 1000*couple_win_s, 1000*dip_win_s, size(Ae,2));
fprintf('[AGL-STIMBLIND] spont held-out R^2:  full-OLS=%.4f -> stim-blind=%.4f  (cost %.4f)\n', ...
    r2_ols, r2_con, r2_ols-r2_con);

% deploy: Actual / Global(=stim-blind pred, dip~0) / Local(=residual=full dip) per amp
A_dip=nan(numel(amps),1); G_dip=nan(numel(amps),1); L_dip=nan(numel(amps),1);
trA=cell(numel(amps),1); trG=cell(numel(amps),1); trL=cell(numel(amps),1);
fprintf('   amp(V) | Actual   Global(contra)  Local(residual) | %%Local\n');
for ai=1:numel(amps)
    if isempty(EVcell{ai}), continue; end
    ev=EVcell{ai};
    yg=b_con.'*ev; yg=yg-mean(yg(1:preN));                    % Global = stim-blind contra prediction
    onF=onFcell{ai}; idx=onF(:).'+rel(:);
    ya=mean(reshape(double(y_full(idx(:))),Wb,numel(onF)),2); ya=ya-mean(ya(1:preN));
    trA{ai}=ya(:); trG{ai}=yg(:); trL{ai}=ya(:)-yg(:);       % Local = residual
    A_dip(ai)=mean(ya(dipColsA)); G_dip(ai)=mean(yg(dipColsA)); L_dip(ai)=A_dip(ai)-G_dip(ai);
    fprintf('   %-6.2f | %7.3f %11.3f %14.3f | %4.0f%%\n', amps(ai), A_dip(ai), G_dip(ai), L_dip(ai), 100*L_dip(ai)/A_dip(ai));
end
gCWmax=0;                                                    % verify coupling nulled across WHOLE window (dip+rebound)
for ai=1:numel(amps), if isempty(EVcell{ai}), continue; end
    yg=b_con.'*EVcell{ai}; yg=yg-mean(yg(1:preN)); gCWmax=max(gCWmax,max(abs(yg(cwCols)))); end
fprintf('   [check] max |Global evoked| over the %.0f ms null window = %.4f  (\\approx 0 => residual carries full stim)\n', ...
    1000*null_win_s, gCWmax);

figAGL = figure('Color','w','Name','[AGL-STIMBLIND] residual = full stim effect','Position',[60 60 1250 420]);
axA=subplot(1,3,1); hold(axA,'on'); box(axA,'on');
plot(axA, amps, A_dip, '-o','Color','k','LineWidth',1.8,'MarkerFaceColor','k','DisplayName','Actual');
plot(axA, amps, G_dip, '-s','Color',[.85 .2 .2],'LineWidth',1.5,'MarkerFaceColor',[.85 .2 .2],'DisplayName','Global (contra pred = 0)');
plot(axA, amps, L_dip, '-^','Color',[.1 .4 .85],'LineWidth',1.5,'MarkerFaceColor',[.1 .4 .85],'DisplayName','Local (residual)');
yline(axA,0,'k:'); xlabel(axA,'amplitude (V)'); ylabel(axA,'0-300 ms dip (\DeltaF/F %)');
title(axA,sprintf('Global\\equiv0, Local\\equivActual  |  spont R^2 %.3f\\rightarrow%.3f',r2_ols,r2_con),'FontSize',9,'FontWeight','bold');
legend(axA,'Location','southwest','FontSize',7);
ttc=rel/Fs; [~,il]=min(abs(amps-1.1)); [~,ih]=max(amps);
for k=1:2
    ax=subplot(1,3,1+k); hold(ax,'on'); box(ax,'on'); ai=il*(k==1)+ih*(k==2);
    if isempty(trA{ai}), continue; end
    plot(ax, ttc, trA{ai}, 'k-','LineWidth',1.7,'DisplayName','Actual');
    plot(ax, ttc, trG{ai}, '-','Color',[.85 .2 .2],'LineWidth',1.4,'DisplayName','Global (contra)');
    plot(ax, ttc, trL{ai}, '-','Color',[.1 .4 .85],'LineWidth',1.4,'DisplayName','Local (residual)');
    xline(ax,0,'k:'); yline(ax,0,'k:'); xlim(ax,[-.5 1]);
    xlabel(ax,'time re onset (s)'); ylabel(ax,'\DeltaF/F %');
    title(ax,sprintf('%.1f V: Global flat, residual=dip',amps(ai)),'FontSize',9,'FontWeight','bold');
    legend(ax,'Location','southeast','FontSize',7);
end
sgtitle('STIM-BLIND decomposition: contra (Global) predicts ZERO dip -> residual (Local) = FULL stim effect','FontWeight','bold');

AGL = struct('b_ols',b_ols,'b_con',b_con,'r2_ols',r2_ols,'r2_con',r2_con,'cost',r2_ols-r2_con, ...
             'amps',amps,'Actual',A_dip,'Global',G_dip,'Local',L_dip,'trA',{trA},'trG',{trG},'trL',{trL}, ...
             'couple_win_s',couple_win_s,'null_win_s',null_win_s,'gCWmax',gCWmax,'nConstraints',size(Ae,2),'muY',muYc);

%% (18) [BESTPRED] --- SECONDARY --- per-amp BEST contra->ipsi stim prediction (ceiling/robustness)
% SECONDARY to §17. Different question: not "isolate the local effect" but "what is the MOST of the
% ipsi stim response contra CAN explain?". Per amplitude, fit the contra->ipsi predictor directly on
% that amp's stim trials with k-fold CV ACROSS TRIALS (ridge, per-amp lambda). Global here = the best
% cross-validated contra prediction (captures 77-95% of the dip); Local = the small ipsi-unique
% remainder contra genuinely cannot predict. Use as a ceiling on bilateral sharing + a robustness
% check on §17, NOT as the local-effect estimator (that is §17).
bp_kf      = 5;                       % CV folds (across trials)
bp_lamGrid = [1 10 100 1000];         % ridge lambda grid (per-amp pick by CV)
bp_dipC    = (preN+1):min(Wb, preN+round(dip_win_s*Fs));
R2f = @(y,yh) 1 - sum((y-yh).^2)/max(sum((y-mean(y)).^2),eps);
bp_cvR2=nan(nA,1); bp_dipCap=nan(nA,1); bp_lam=nan(nA,1);
bp_A=nan(nA,1); bp_G=nan(nA,1); bp_L=nan(nA,1);
bp_Ya=cell(nA,1); bp_Yh=cell(nA,1); bp_Res=cell(nA,1); bp_onF=cell(nA,1);
fprintf('\n[BESTPRED] per-amp trial-CV ridge contra->ipsi (SECONDARY):\n   amp | nTrl | CV R2  dipCap  Actual Global Local\n');
for ai = 1:nA
    onF=onFcell{ai}; nT=numel(onF); if nT<10, continue; end
    idx=onF(:).'+rel(:);
    Zp=(double(Uflat(gridIdx,:))*double(V_cp(:,idx(:)))-mu_p)./sd_p; Zp=reshape(Zp,nG,Wb,nT); Zp=Zp-mean(Zp(:,1:preN,:),2);
    Yp=reshape(double(y_full(idx(:))),Wb,nT); Yp=Yp-mean(Yp(1:preN,:),1);
    fold=mod((0:nT-1),bp_kf)+1; bestR=-inf; bestYh=[];
    for lam=bp_lamGrid
        Yhat=nan(Wb,nT);
        for f=1:bp_kf
            tr=fold~=f; te=fold==f; Xtr=reshape(Zp(:,:,tr),nG,[]); ytr=reshape(Yp(:,tr),1,[]);
            b=(Xtr*Xtr.'+lam*eye(nG))\(Xtr*ytr.'); Yhat(:,te)=reshape(b.'*reshape(Zp(:,:,te),nG,[]),Wb,nnz(te));
        end
        r=R2f(reshape(Yp,1,[]),reshape(Yhat,1,[]));
        if r>bestR, bestR=r; bp_lam(ai)=lam; bestYh=Yhat; end
    end
    bp_cvR2(ai)=bestR; bp_Ya{ai}=Yp; bp_Yh{ai}=bestYh; bp_Res{ai}=Yp-bestYh; bp_onF{ai}=onF(:);
    mA=mean(Yp,2); mG=mean(bestYh,2);
    bp_A(ai)=mean(mA(bp_dipC)); bp_G(ai)=mean(mG(bp_dipC)); bp_L(ai)=bp_A(ai)-bp_G(ai); bp_dipCap(ai)=bp_G(ai)/bp_A(ai);
    fprintf('   %.2f | %4d | %.3f %5.0f%% | %6.3f %6.3f %6.3f\n', amps(ai),nT,bestR,100*bp_dipCap(ai),bp_A(ai),bp_G(ai),bp_L(ai));
end

figBP = figure('Color','w','Name','[BESTPRED] per-amp Actual/Pred/Residual (trial-avg +/-SEM)','Position',[40 40 1300 820]);
ttc=rel/Fs;
for ai=1:nA
    ax=subplot(3,3,ai); hold(ax,'on'); box(ax,'on');
    if isempty(bp_Ya{ai}), title(ax,sprintf('%.2f V: n/a',amps(ai))); continue; end
    A=bp_Ya{ai}; H=bp_Yh{ai}; Rz=bp_Res{ai}; nT=size(A,2);
    mA=mean(A,2); mH=mean(H,2); mR=mean(Rz,2);
    sA=std(A,0,2)/sqrt(nT); sH=std(H,0,2)/sqrt(nT); sR=std(Rz,0,2)/sqrt(nT);
    fb=@(m,s,c) fill(ax,[ttc fliplr(ttc)],[(m+s).' fliplr((m-s).')],c,'EdgeColor','none','FaceAlpha',.22,'HandleVisibility','off');
    fb(mA,sA,[0 0 0]); fb(mH,sH,[.85 .2 .2]); fb(mR,sR,[.1 .4 .85]);
    plot(ax,ttc,mA,'k-','LineWidth',1.6,'DisplayName','Actual');
    plot(ax,ttc,mH,'-','Color',[.85 .2 .2],'LineWidth',1.4,'DisplayName','Prediction (best)');
    plot(ax,ttc,mR,'-','Color',[.1 .4 .85],'LineWidth',1.4,'DisplayName','Residual (local)');
    xline(ax,0,'k:'); yline(ax,0,'k:'); xlim(ax,[-.5 1]);
    title(ax,sprintf('%.2f V (n=%d): %.0f%% dip captured',amps(ai),nT,100*bp_dipCap(ai)),'FontSize',9,'FontWeight','bold');
    if ai==7, xlabel(ax,'time re onset (s)'); ylabel(ax,'\DeltaF/F %'); end
    if ai==1, legend(ax,'Location','southeast','FontSize',6); end
end
sgtitle('BESTPRED (SECONDARY): Actual = best contra Prediction (77-95% of dip) + Residual (small ipsi-unique)','FontWeight','bold');

BESTPRED = struct('amps',amps,'cvR2',bp_cvR2,'dipCap',bp_dipCap,'lam',bp_lam, ...
                  'Actual',bp_A,'Global',bp_G,'Local',bp_L,'Ya',{bp_Ya},'Yh',{bp_Yh}, ...
                  'Res',{bp_Res},'onF',{bp_onF},'dipCols',bp_dipC);

%% (19) [ALLSESS-STIMBLIND] combined PRIMARY stim-blind decomposition across ALL sessions
% Runs the §17 stim-blind model HEADLESS for every session in allSelExp (default the three
% impulse datasets), so the local-only effect can be compared across mice/sessions in one place.
% Each session is decomposed exactly as §17: Global (contra pred) = spont-trained OLS with the
% per-amp stim-dip direction PROJECTED OUT (predicted dip = 0 at every amp) -> Local (residual)
% = the FULL stim-evoked inhibition. Reuses the same cached site + ROI (cp_stim_site_*.mat,
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
        fprintf('   %-24s: spont R^2 %.4f->%.4f (cost %.4f) | %d amps, grid %d, couple %.0f ms (null %.0f ms), %d null-dirs\n', ...
                S.label, S.r2_ols, S.r2_con, S.cost, numel(S.amps), S.nG, 1000*S.couple_win_s, 1000*S.null_win_s, S.nConstraints);
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
                legend(ax,{'Actual','Global (contra pred\equiv0 dip)','Local (residual=stim)'}, ...
                       'FontSize',6,'Location','best');
                ylabel(ax,'\DeltaF/F %');
            end
            if ai>na-nc, xlabel(ax,'t re onset (s)'); end
        end
        sgtitle(sprintf('STIM-BLIND trial averages — %s   (spont R^2 %.3f\\rightarrow%.3f, cost %.3f)', ...
                S.label, S.r2_ols, S.r2_con, S.cost),'FontWeight','bold');
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

%% (20) [SESSION-VIEWER] orientation-normalized interactive map with a SESSION PICKER
% Standalone interactive tool (does NOT touch the §1-§19 analysis). Pick a session from the
% dropdown -> its brain loads in a COMMON orientation, auto-normalized so the IPSI (target)
% hemisphere is on the RIGHT and the midline is VERTICAL. This removes the apparent
% "transpose" of AL_0041 (its camera frame is stored ~90 deg rotated vs AL_0033; the fix is
% display-only and changes NOTHING numerical). The laser site is marked (green +) and the
% sparse contra-grid weights that predict the site pixel are shown. Click any IPSI pixel and
% the contra weights refit to predict it (same lasso model as §8). Orientation is chosen by
% pick_orient: among the 8 dihedral views, the one that puts the ipsi centroid rightmost with
% a vertical midline. Click->pixel mapping is inverted through the SAME transform, so selection
% is never transposed regardless of the raw camera frame.
if RUN_SESSION_VIEWER
    cfgV = struct('nSV_load',nSV_load,'Fs',Fs,'nGrid',nGrid,'edgeMargin',edgeMargin, ...
                  'settle_s',settle_s,'trainFrac',trainFrac,'maxFrm',maxFrm, ...
                  'USE_DATA_SITE',USE_DATA_SITE,'dataDir',dataDir,'fit_mode',fit_mode, ...
                  'l1_frac',l1_frac,'ridge',ridge,'debias',debias);
    local_session_viewer(cfgV, allExperiments, allSelExp);
end

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

function ols_click(fig, ~)
D = guidata(fig);
cp = D.ax_map.CurrentPoint;  row = round(cp(1,1));  col = round(cp(1,2));   % x=row, y=col (transposed view)
if row<1 || row>D.nY || col<1 || col>D.nX, return; end
if ~D.ipsi(row,col)
    set(D.hTtl,'String', sprintf('[row %d col %d] is NOT on the ipsi (target) side — click the ipsi hemisphere', row, col));
    return;
end
[bpix, cv, ~, ~, nAct] = ols_refit(D, row, col);   % only the kernel map updates on click
wsc = max(abs(bpix))+eps;
set(D.hSc,'CData',bpix);  clim(D.ax_map,[-wsc wsc]);
set(D.hMk,'XData',row,'YData',col);
set(D.hTtl,'String', sprintf('[%s] target [row %d col %d]   R^2=%.3f   %d/%d px active', ...
    D.fit_mode, row, col, cv, nAct, numel(bpix)));
% NB: best/worst companion is intentionally NOT updated — it stays fixed on the site pixel.
guidata(fig, D);
end

function update_bestworst(D, yte, yhat_te)
% Split the held-out block into bwWinSec windows, score each by R^2, and draw the 5
% best (top row) and 5 worst (bottom row). Windows that straddle a stim gap (their
% underlying frame indices are non-contiguous) are skipped so a gap-jump isn't scored.
if ~all(isgraphics(D.axBW)), return; end          % companion figure was closed
teFrames = D.frames(D.ite);  teFrames = teFrames(:);   % actual frame index of each held-out sample
stride = median(diff(teFrames));  if ~isfinite(stride) || stride < 1, stride = 1; end
Lw = max(4, round(D.bwWinSec*D.Fs/stride));        % samples covering ~bwWinSec of REAL time
W  = max(3, round(D.detrendSec*D.Fs/stride));       % running-mean window (samples)
jumpThr = max(round(0.3*D.Fs), 3*stride);          % a within-segment step is ~stride; a stim gap is huge
nW = floor(numel(yte)/Lw);
r2 = nan(nW,1);
for w = 1:nW
    idx = (w-1)*Lw + (1:Lw);
    fr  = teFrames(idx);
    if max(diff(fr)) > jumpThr, continue; end      % window crosses a stim gap -> skip
    a = yte(idx);  p = yhat_te(idx);
    p = p + movmean(a - p, W);                     % running-mean DC correction (removes slow drift)
    r2(w) = 1 - sum((a-p).^2) / max(sum((a-mean(a)).^2), eps);
end
[rs, ord] = sort(r2, 'descend', 'MissingPlacement','last');
ord = ord(isfinite(rs));  nWv = numel(ord);        % contiguous windows only
nb = min(5, nWv);
best  = ord(1:nb);
worst = ord(nWv:-1:max(1, nWv-nb+1));
sel = [best(:); worst(:)];  lab = {'best','worst'};  col2 = [0 0.5 0; 0.75 0 0];
tt = (0:Lw-1)*stride/D.Fs;                          % real elapsed seconds (accounts for subsampling)
for m = 1:10
    axb = D.axBW(m);  k = 1 + (m > 5);
    if m <= numel(sel)
        w = sel(m);  idx = (w-1)*Lw + (1:Lw);
        aw = yte(idx);  pw = yhat_te(idx);
        pw = pw + movmean(aw - pw, W);             % running-mean-corrected prediction (removes slow drift)
        set(D.hBWa(m),'XData',tt,'YData',aw);
        set(D.hBWp(m),'XData',tt,'YData',pw);
        set(D.hBWt(m),'String', sprintf('%s  R^2=%.2f', lab{k}, r2(w)), 'Color', col2(k,:));
        xlim(axb,[tt(1) tt(end)]);
    else
        set(D.hBWa(m),'XData',nan,'YData',nan);  set(D.hBWp(m),'XData',nan,'YData',nan);
        set(D.hBWt(m),'String','');
    end
end
end

function bleed_click(figB, ~)
% Click a pixel in any per-amp subplot -> inspect that pixel's peri-stim response.
DB = guidata(figB);
for ai = 1:numel(DB.axB)
    ax = DB.axB(ai);  cp = ax.CurrentPoint;  x = cp(1,1);  y = cp(1,2);
    xl = ax.XLim;  yl = ax.YLim;
    if x>=xl(1) && x<=xl(2) && y>=yl(1) && y<=yl(2)
        [~,p] = min((DB.grR - x).^2 + (DB.grC - y).^2);   % x=row, y=col (transposed view)
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
gridIdx = gridIdx(keep);  nG = numel(gridIdx);

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
dipCols = (preN+1):min(Wb, preN+round(cfg.dip_win_s*Fs));

% --- (10b+17) coupling-subspace stim-blind null over the data-driven coupling window ---
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
ytrC = y_sp(itr);  yteC = y_sp(ite);  muYc = mean(ytrC);
Gc = Ztr.'*Ztr;  b_ols = Gc\(Ztr.'*(ytrC-muYc));
R2c = @(y,yh) 1 - sum((y-yh).^2)/max(sum((y-mean(y)).^2),eps);
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
null_win_s=max(couple_win_s,cfg.dip_win_s);                 % floor null span to reporting dip window (see §17)
cwN=round(null_win_s*Fs); cwCols=(preN+1):min(Wb,preN+max(cwN,1));
Apatt=[]; for ai=1:nA, if isempty(EVcell{ai}), continue; end; Apatt=[Apatt, EVcell{ai}(:,cwCols)]; end %#ok<AGROW>
Ae=orth(Apatt); GiA=Gc\Ae; b_con=b_ols-GiA*(pinv(Ae.'*GiA)*(Ae.'*b_ols));
r2_ols = R2c(yteC, muYc+Zte*b_ols);  r2_con = R2c(yteC, muYc+Zte*b_con);

% --- deploy: Actual / Global(=stim-blind pred) / Local(=residual) per amp -------------
A_dip = nan(nA,1);  G_dip = nan(nA,1);  L_dip = nan(nA,1);
trA = cell(nA,1);  trG = cell(nA,1);  trL = cell(nA,1);
for ai = 1:nA
    if isempty(EVcell{ai}), continue; end
    ev = EVcell{ai};  yg = b_con.'*ev;  yg = yg - mean(yg(1:preN));
    onF = onFcell{ai};  idx = onF(:).'+rel(:);
    ya = mean(reshape(double(y_full(idx(:))),Wb,numel(onF)),2);  ya = ya - mean(ya(1:preN));
    trA{ai} = ya(:);  trG{ai} = yg(:);  trL{ai} = ya(:)-yg(:);
    A_dip(ai) = mean(ya(dipCols));  G_dip(ai) = mean(yg(dipCols));  L_dip(ai) = A_dip(ai)-G_dip(ai);
end

S = struct('label',label,'sel',sel,'amps',amps,'Actual',A_dip,'Global',G_dip,'Local',L_dip, ...
           'trA',{trA},'trG',{trG},'trL',{trL},'rel',rel,'Fs',Fs,'preN',preN, ...
           'r2_ols',r2_ols,'r2_con',r2_con,'cost',r2_ols-r2_con,'nG',nG, ...
           'couple_win_s',couple_win_s,'null_win_s',null_win_s,'nConstraints',size(Ae,2));
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
scatter(ax3, DB.grR(~affA), DB.grC(~affA), 10, [0.7 0.7 0.7], 'filled', 'MarkerEdgeColor',[0.4 0.4 0.4], 'LineWidth',0.2);
scatter(ax3, DB.grR(affA),  DB.grC(affA),  16, 'k', 'filled');
plot(ax3, DB.site(1), DB.site(2), 'g+', 'MarkerSize',14, 'LineWidth',2);
plot(ax3, [DB.site(1) DB.grR(p)], [DB.site(2) DB.grC(p)], 'r-', 'LineWidth',0.8);
scatter(ax3, DB.grR(p), DB.grC(p), 70, 'r', 'filled', 'MarkerEdgeColor','k', 'LineWidth',1);
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
cp = BC.axMap.CurrentPoint;  x = cp(1,1);  y = cp(1,2);          % x=row, y=col (transposed view)
xl = BC.axMap.XLim;  yl = BC.axMap.YLim;
if x<xl(1)||x>xl(2)||y<yl(1)||y>yl(2), return; end
[~,p] = min((BC.grR - x).^2 + (BC.grC - y).^2);
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

function local_session_viewer(cfg, allExperiments, selList)
% Interactive map with a session dropdown. Selecting a session loads it and draws the
% orientation-normalized brain + sparse contra weights; clicking an ipsi pixel refits.
labels=arrayfun(@(s) sprintf('%d: %s %s e%d',s,allExperiments(s).mn,allExperiments(s).td,allExperiments(s).en),selList,'uni',0);
fig=figure('Color','w','Name','[SESSION-VIEWER] pick session; click ipsi to refit contra weights','Position',[100 60 840 860]);
uicontrol(fig,'Style','text','Units','normalized','Position',[0.05 0.955 0.10 0.03],'String','session:', ...
          'FontSize',10,'HorizontalAlignment','left','BackgroundColor','w');
pop=uicontrol(fig,'Style','popupmenu','String',labels,'Units','normalized','Position',[0.16 0.95 0.5 0.04],'FontSize',10);
ax=axes(fig,'Units','normalized','Position',[0.05 0.03 0.9 0.89]);
VS=struct('cfg',cfg,'allExp',{allExperiments},'selList',selList,'ax',ax,'pop',pop);
guidata(fig,VS);
set(pop,'Callback',@(s,~) viewer_load(fig));
viewer_load(fig);
end

function viewer_load(fig)
VS=guidata(fig); ax=VS.ax; cla(ax,'reset');
sel=VS.selList(get(VS.pop,'Value'));
ae=VS.allExp(sel); lbl=sprintf('%s %s e%d',ae.mn,ae.td,ae.en);
title(ax,sprintf('loading %s ...',lbl)); axis(ax,'off'); drawnow;
[D,px,py,contra,ipsi]=local_load_session(sel,VS.cfg,VS.allExp);
T=pick_orient(contra,ipsi,px,py,D.nY,D.nX);
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
