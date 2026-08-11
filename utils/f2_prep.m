function P = f2_prep(ae, cfg)
%F2_PREP  Fig-2 stream, STAGE 1: everything one impulse session needs, in ONE struct.
%
% WHY THIS EXISTS. ols_tf_pipeline.m communicates between its stages through bare script
% variables (Gz, cz, Sc, evZc, bUseS, affected, ...) guarded by exist('x','var') and injected
% by eval. That makes it impossible to prove a stage ran on THIS session's state rather than
% the previous session's leftovers -- which is exactly the doubt you cannot afford when the
% question is "is the OLS broken?". Here every stage takes a struct and returns a struct.
%
% This function is a faithful extraction of ols_tf_pipeline.m sections (2)-(7), (10) and
% (17)/(17a). It computes NOTHING new and makes NO modelling choice. It draws no figures.
%
% INPUT   ae   one element of `allExperiments` (from load_experiments / load_bilateral_impulse)
%         cfg  .dataDir (required) + optional overrides, see the defaults block below
%
% OUTPUT  P  session identity, geometry, spontaneous train/test operators, per-amp evoked, and
%            the honest pre/post-stim prediction designs. See the field map at the end.
%
% MEMORY. Only the GRID rows of U are retained (P.Ug, [nG x nSV]), never the full [nPix x nSV]
% Uflat -- one session's Uflat is ~0.5 GB and four of them will not coexist. Downstream code
% that wants the old interface passes P.Ug with gridIdx = 1:nG (see f2_decomp).
% -------------------------------------------------------------------------------------------
if nargin < 2, cfg = struct(); end
def = struct('nSV_load',500, 'Fs',35, 'nGrid',500, 'edgeMargin',12, 'dip_win_s',0.300, ...
             'settle_s',2.0, 'trainFrac',2/3, 'maxFrm',60000, 'bleed_preSec',0.5, ...
             'bleed_postSec',1.0, 'maxBaseTrl',500, 'recTolFac',0.05, 'setTolFac',0.10, ...
             'dataDir','', 'verbose',true);
fn = fieldnames(def);
for i = 1:numel(fn)
    if ~isfield(cfg,fn{i}) || isempty(cfg.(fn{i})), cfg.(fn{i}) = def.(fn{i}); end
end
assert(~isempty(cfg.dataDir) && exist(cfg.dataDir,'dir')==7, 'f2_prep: cfg.dataDir must be an existing folder.');
Fs = cfg.Fs;  vb = cfg.verbose;

%% ---- (a) session identity -----------------------------------------------------------------
P = struct();
P.mn = ae.mn;  P.td = ae.td;  P.en = ae.en;  P.Fs = Fs;
% Bilateral two-spot sessions (AL_0048) register one entry PER GALVO SITE under the same
% mn/td/en, so those entries carry a site-qualified sess_tag; without it two sites collide on
% one cache filename.
if isfield(ae,'sess_tag') && ~isempty(ae.sess_tag)
    P.sess_tag = ae.sess_tag;
else
    P.sess_tag = sprintf('%s_%s%s_e%d', ae.mn, ae.td(6:7), ae.td(9:10), ae.en);
end
% The TF-detector caches were written with an un-qualified name (see ols_tf_pipeline §10T), so
% the affected-mask lookup uses this SEPARATE tag. Do not merge the two.
P.tf_tag = sprintf('%s_%s%s_e%d', ae.mn, ae.td(6:7), ae.td(9:10), ae.en);
if isfield(ae,'site') && ~isempty(ae.site)
    P.label = sprintf('%s %s e%d [%s]', ae.mn, ae.td, ae.en, ae.site);
else
    P.label = sprintf('%s %s e%d', ae.mn, ae.td, ae.en);
end
% CAVEAT carried on the struct, not in a comment, so every table downstream can print it and it
% cannot be lost between here and the manuscript. RESEARCH 2026-08-02 / load_bilateral_impulse.m.
if strcmp(ae.mn,'AL_0048')
    P.caveat = ['readout sits ~2.6 mm from the ILLUMINATED spot -> this is the response of a ' ...
                'CONNECTED region, not of illuminated tissue. NOT a plain 4th replicate.'];
else
    P.caveat = '';
end
if vb, fprintf('\n[F2-PREP] %s\n', P.label); end

%% ---- (b) SVD + data-derived stim site + retargeted ipsi trace -------------------------------
% ae.dF is the loader's nominal kernel trace. It is deliberately NOT used: y_full is re-extracted
% below at the DATA-DERIVED site, because params.pixel (which ae.dF was built from) is flip-prone.
t_full = ae.timeBlue(:);
serverRoot = expPath(P.mn, P.td, P.en);
[U_cp, V_cp, ~, mimg] = loadUVt(serverRoot, cfg.nSV_load);
[nY, nX] = size(mimg);  nSV = size(U_cp,3);

% loadData needs the closed-loop controller rig's csv/mat files. The bilateral session is a
% Signals experiment with none of them, so k_prim falls back to the project default.
try
    dtmp = loadData(serverRoot, P.mn, P.td, P.en);
    k_prim = double(dtmp.params.kernel);  clear dtmp
catch
    k_prim = 10;
    if vb, fprintf('  [site] no controller-rig params (Signals session) -> k_prim=%d\n', k_prim); end
end

% params.pixel is FLIP-PRONE (load/save schemes swap x/y) and must never be trusted for the site.
% The site is data-derived: deepest focal inhibition in the trial-averaged peri-stim map.
site_file = fullfile(cfg.dataDir, sprintf('cp_stim_site_%s.mat', P.sess_tag));
if exist(site_file,'file')
    SS = load(site_file);  stim_rc = double(SS.rowcol);
else
    [~, iMx] = max(ae.uAmp);  sv = ae.imp.startTimes{iMx}(:);
    onF = zeros(numel(sv),1);
    for j = 1:numel(sv), [~,onF(j)] = min(abs(t_full - sv(j))); end
    st = cp_find_stim_site(U_cp, double(V_cp), mimg, onF, 'fs', Fs);
    stim_rc = double(st.rowcol);  save(site_file,'-struct','st');
end
px_prim = stim_rc(1);  py_prim = stim_rc(2);          % ARRAY (row,col) -- display-invariant
Uflat = reshape(U_cp, nY*nX, nSV);  clear U_cp
kr = max(1,px_prim-k_prim):min(nY,px_prim+k_prim);
kc = max(1,py_prim-k_prim):min(nX,py_prim+k_prim);
[KR,KC] = ndgrid(kr,kc);  kidx = sub2ind([nY nX], KR(:), KC(:));
mI_st = mean(mimg(kr,kc),'all');
y_full = ((mean(Uflat(kidx,:),1) * double(V_cp)) / mI_st * 100).';   % ipsi kernel at the TRUE site
clear KR KC kidx
if vb, fprintf('  [site] row %d col %d (k=%d) -> y_full retargeted\n', px_prim, py_prim, k_prim); end
nF = min(numel(y_full), size(V_cp,2));

%% ---- (c) contra / ipsi masks (cache only -- never draw here) --------------------------------
roi_file = fullfile(cfg.dataDir, sprintf('cp_roi2_%s.mat', P.sess_tag));
if ~exist(roi_file,'file')
    error(['f2_prep: no cached ROI for %s.\n  missing: %s\n' ...
           '  Draw it ONCE via contra_prediction.m section S04, then re-run. The draw GUI is ' ...
           'deliberately not opened from this stream.'], P.label, roi_file);
end
M = cp_roi_masks(mimg, roi_file, px_prim, py_prim, ...
                 struct('redefine',false,'thr_pctile',20,'plot',false));
contra_mask = logical(M.contra);  ipsi_mask = logical(M.ipsi);

%% ---- (d) tight regular grid over the contra mask --------------------------------------------
mask = contra_mask;  [rC,cC] = find(mask);
rmn=min(rC); rmx=max(rC); cmn=min(cC); cmx=max(cC);
d = max(1, round(sqrt(nnz(mask)/cfg.nGrid)));  gridIdx = [];  ln = [];
for it = 1:12
    [GR,GC] = ndgrid(rmn:d:rmx, cmn:d:cmx);
    ln = sub2ind([nY nX], GR(:), GC(:));  ln = ln(mask(ln));
    if numel(ln) >= cfg.nGrid || d==1, gridIdx = ln; break; end
    d = max(1, d-1);
end
if isempty(gridIdx), gridIdx = ln; end
[grR,grC] = ind2sub([nY nX], gridIdx);
% Erode the mask edge: keep a node only if its full (2*em+1)^2 neighbourhood is inside the mask.
% Boundary pixels are low-SNR and otherwise attract spurious weight.
em = cfg.edgeMargin;
keep = (grR>em) & (grR<=nY-em) & (grC>em) & (grC<=nX-em);
for g = find(keep(:).')
    if ~all(all(mask(grR(g)-em:grR(g)+em, grC(g)-em:grC(g)+em))), keep(g) = false; end
end
gridIdx = gridIdx(keep);  grR = grR(keep);  grC = grC(keep);  nG = numel(gridIdx);
if vb, fprintf('  [grid] %d interior contra px (lattice %d, edge margin %d)\n', nG, d, em); end

Ug = double(Uflat(gridIdx,:));                       % [nG x nSV] -- the ONLY part of U we keep
mI_grid = double(mimg(gridIdx));
Xpct = (Ug * single(V_cp)) ./ single(mI_grid) * 100; % [nG x nFrames] %dF/F on the grid
nFall = size(Xpct,2);
clear Uflat

%% ---- (e) onsets, per-amp peri-stim blocks, 0 V baseline --------------------------------------
uAmp = ae.uAmp;  imp = ae.imp;
preN = round(cfg.bleed_preSec*Fs);  postN = round(cfg.bleed_postSec*Fs);
rel = (-preN:postN);  Wb = numel(rel);

all_starts = [];
for ia = 1:numel(uAmp)
    if uAmp(ia) <= 0, continue; end
    all_starts = [all_starts; imp.startTimes{ia}(:)];  %#ok<AGROW>
end
all_starts = sort(all_starts);

% 0 V baseline. If the session has no catch trials (AL_0041 e2), sample a pseudo-catch from the
% midpoints of the inter-trial spontaneous gaps. That carries no shutter/galvo command artifact,
% but nothing downstream baselines against it (every model is per-trial pre-onset baselined), so
% it only ever serves as a null.
ia0 = find(uAmp==0, 1);
if isempty(ia0)
    impF = zeros(numel(all_starts),1);
    for j = 1:numel(all_starts), [~,impF(j)] = min(abs(t_full - all_starts(j))); end
    impF = sort(impF);
    mids  = round((impF(1:end-1)+impF(2:end))/2);
    gapok = (impF(2:end)-impF(1:end-1)) > (preN+postN+round(1.5*Fs));
    onF0  = mids(gapok);  onF0 = onF0(onF0-preN>=1 & onF0+postN<=nFall);
    P.catch_kind = 'pseudo';
else
    onF0 = f2_onsets(imp.startTimes{ia0}(:), t_full, preN, postN, nFall);
    P.catch_kind = 'true0V';
end
if numel(onF0) > cfg.maxBaseTrl, onF0 = onF0(round(linspace(1,numel(onF0),cfg.maxBaseTrl))); end
nT0 = numel(onF0);
assert(nT0 >= 2, 'f2_prep: only %d usable 0 V trials for %s -- need >=2.', nT0, P.label);
blk0 = reshape(Xpct(:,(onF0(:).'+rel(:))), nG, Wb, nT0);
m0   = mean(blk0 - mean(blk0(:,1:preN,:),2), 3);      % [nG x Wb] 0 V baseline

amps = uAmp(uAmp>0);  nA = numel(amps);
onFcell = cell(nA,1);  nT_amp = zeros(nA,1);  blkA = cell(nA,1);  mResp = nan(nG,Wb,nA);
for ai = 1:nA
    onF = f2_onsets(imp.startTimes{find(uAmp==amps(ai),1)}(:), t_full, preN, postN, nFall);
    onFcell{ai} = onF;  nT_amp(ai) = numel(onF);
    if isempty(onF), continue; end
    bA = reshape(Xpct(:,(onF(:).'+rel(:))), nG, Wb, numel(onF));
    mResp(:,:,ai) = mean(bA - mean(bA(:,1:preN,:),2), 3) - m0;
    blkA{ai} = bA - mean(bA(:,1:preN,:),2);
end

%% ---- (f) data-driven per-amp inhibition / rebound windows (from the IPSI impulse) -----------
% Landmarks come from the primary-pixel evoked, so no window constant is hard-coded. inhCols =
% onset -> recovery; rebCols = recovery -> settle. SINGLE SOURCE OF TRUTH for both.
y0tr = double(reshape(y_full(onF0(:).'+rel(:)), Wb, nT0));
y0tr = y0tr - mean(y0tr(1:preN,:),1);  y0p = mean(y0tr,2);
inhCols = cell(nA,1);  rebCols = cell(nA,1);  recMs = nan(nA,1);  setMs = nan(nA,1);
troughMs = nan(nA,1);  troughDf = nan(nA,1);  mAmpP = nan(Wb,nA);
for ai = 1:nA
    onF = onFcell{ai};  if isempty(onF), continue; end
    tra = double(reshape(y_full(onF(:).'+rel(:)), Wb, numel(onF)));
    tra = tra - mean(tra(1:preN,:),1);
    mp = mean(tra,2) - y0p;  mAmpP(:,ai) = mp;  bsd = std(mp(1:preN));  seg = mp((preN+1):Wb);
    [dTr,iLoc] = min(seg);  iT = preN + iLoc;
    tol = max(2*bsd, cfg.recTolFac*abs(dTr));
    rc = iT - 1 + find(mp(iT:Wb) >= -tol, 1, 'first');
    if isempty(rc) || rc <= preN, rc = min(Wb, preN+round(cfg.dip_win_s*Fs)); end
    tolS = max(2*bsd, cfg.setTolFac*abs(dTr));
    lb = find(abs(mp((preN+1):Wb)) > tolS, 1, 'last');
    se = preN + max(lb,1);  if isempty(lb), se = rc; end
    r1 = min(rc+1, Wb);
    inhCols{ai} = (preN+1):rc;  rebCols{ai} = r1:max(r1,se);
    recMs(ai) = rel(rc)/Fs*1000;  setMs(ai) = rel(min(se,Wb))/Fs*1000;
    troughMs(ai) = rel(iT)/Fs*1000;  troughDf(ai) = dTr;
end

%% ---- (g) spontaneous inter-stim frames + z-scored design ------------------------------------
ons = zeros(numel(all_starts),1);
for j = 1:numel(all_starts), [~,ons(j)] = min(abs(t_full - all_starts(j))); end
settle = round(cfg.settle_s*Fs);  frames = [];
for j = 1:numel(ons)
    i0 = ons(j) + settle;
    if j < numel(ons), i1 = ons(j+1)-2; else, i1 = nF; end
    i0 = max(i0,1);  i1 = min(i1,nF);
    if i1 >= i0, frames = [frames, i0:i1]; end   %#ok<AGROW>
end
frames = unique(frames);  frames = frames(isfinite(y_full(frames).'));
if numel(frames) > cfg.maxFrm, frames = frames(round(linspace(1,numel(frames),cfg.maxFrm))); end
nTrn = floor(cfg.trainFrac*numel(frames));
itr = 1:nTrn;  ite = nTrn+1:numel(frames);        % TEMPORAL split: first block trains

Xg = Ug * double(V_cp(:,frames));                  % [nG x nFrm] raw grid activity
mu_p = mean(Xg(:,itr),2);  sd_p = std(Xg(:,itr),0,2);  sd_p(sd_p==0) = 1;   % TRAIN z-score
Ztr = ((Xg(:,itr)-mu_p)./sd_p).';  Zte = ((Xg(:,ite)-mu_p)./sd_p).';
clear Xg
y_sp = double(y_full(frames));  ytr = y_sp(itr);  yte = y_sp(ite);
muY = mean(ytr);
Gz = Ztr.'*Ztr;  cz = Ztr.'*(ytr-muY);
sstot = max(sum((yte-mean(yte)).^2), eps);

%% ---- (h) motion trace, and the MOTION-AUGMENTED design ---------------------------------------
% Prefer the trace the loader already put on the entry (mv_z, z-scored at blue cadence). Sessions
% loaded outside the controller rig (the AL_0048 bilateral impulse) have no input_params.csv, so
% loadData throws and motion would silently be NaN even though the face video was processed.
motz = [];
if isfield(ae,'mv_z') && ~isempty(ae.mv_z) && any(isfinite(ae.mv_z))
    motz = double(ae.mv_z(:));
else
    try
        dM = loadData(serverRoot, P.mn, P.td, P.en);
        if isfield(dM,'motion') && isfield(dM.motion,'motion_1')
            mf = double(dM.motion.motion_1(1:2:end));
            motz = (mf - mean(mf,'omitnan'))/max(std(mf,'omitnan'),eps);
        end
        clear dM
    catch ME
        if vb, fprintf('  [motion] unavailable (%s) -> motion column NaN\n', ME.message); end
    end
end
% Motion as an EXTRA REGRESSOR (index nG+1 in the augmented design). Built here so f2_model can
% pick contra-only or contra+motion without rebuilding anything. NaN-safe: gaps -> 0 after
% z-scoring on the TRAIN frames, so a missing sample contributes nothing rather than poisoning
% the Gram matrix.
haveMot = ~isempty(motz) && numel(motz) >= nF && any(isfinite(motz));
if haveMot
    mv = motz(:);
    msp = mv(frames);  mtr = msp(itr);
    mmu = mean(mtr,'omitnan');  msd = max(std(mtr,'omitnan'),eps);
    zfill = @(v) local_fill((v-mmu)/msd);
    Ztr_a = [Ztr, zfill(msp(itr))];  Zte_a = [Zte, zfill(msp(ite))];
    Gz_a = Ztr_a.'*Ztr_a;  cz_a = Ztr_a.'*(ytr-muY);
    P.motNorm = struct('mu',mmu,'sd',msd);
else
    Zte_a = [];  Gz_a = [];  cz_a = [];  P.motNorm = [];
end
clear Ztr Ztr_a

%% ---- (i) per-amp evoked in z-space + split-half (for the greedy blindness control) ----------
% Seeded HERE, not just by the caller. Seeding only at the top of the driver makes the split depend
% on how much RNG every earlier stage happened to consume, so running with or without the motion
% variant silently produced different halves -- and therefore different greedy controls. A local
% seed makes this session's split a function of the session alone.
rng(7,'twister');
evZc = cell(nA,1);  aAc = cell(nA,1);  dcc = cell(nA,1);  rcc = cell(nA,1);  scc = cell(nA,1);
evZcA = cell(nA,1); aAcA = cell(nA,1); evZcB = cell(nA,1); aAcB = cell(nA,1);
evMot = nan(Wb,nA);                                        % trial-avg motion evoked (aug design)
dipColsShared = (preN+1):min(Wb, preN+round(cfg.dip_win_s*Fs));
for ai = 1:nA
    onF = onFcell{ai};  nT = numel(onF);  if nT==0, continue; end
    dc = inhCols{ai};  if isempty(dc), dc = dipColsShared; end
    rc = rebCols{ai};
    idx = onF(:).' + rel(:);
    Zp = (Ug*double(V_cp(:,idx(:))) - mu_p)./sd_p;  Zp = reshape(Zp, nG, Wb, nT);
    evZ = mean(Zp,3);  evZ = evZ - mean(evZ(:,1:preN),2);
    yTr = reshape(double(y_full(idx(:))), Wb, nT);
    aA  = mean(yTr,2);  aA = aA - mean(aA(1:preN));
    if nT >= 4
        pp = randperm(nT);  hA = pp(1:floor(nT/2));  hB = pp(floor(nT/2)+1:end);
        eA = mean(Zp(:,:,hA),3);  evZcA{ai} = eA - mean(eA(:,1:preN),2);
        eB = mean(Zp(:,:,hB),3);  evZcB{ai} = eB - mean(eB(:,1:preN),2);
        yA = mean(yTr(:,hA),2);   aAcA{ai} = yA - mean(yA(1:preN));
        yB = mean(yTr(:,hB),2);   aAcB{ai} = yB - mean(yB(1:preN));
    end
    if haveMot
        mb = reshape(local_fill((motz(min(max(idx(:),1),numel(motz)))-P.motNorm.mu)/P.motNorm.sd), Wb, nT);
        em = mean(mb,2);  evMot(:,ai) = em - mean(em(1:preN));
    end
    if ~isempty(rc), se = rc(end); else, se = dc(end); end
    evZc{ai}=evZ; aAc{ai}=aA; dcc{ai}=dc; rcc{ai}=rc; scc{ai}=(preN+1):max(se,dc(end));
end

%% ---- (j) HONEST pre/post-stim prediction designs ---------------------------------------------
% The old "non-stim R^2" was computed on the trial-AVERAGED evoked, which outside the stim window
% is ~0 signal + averaging noise -> it measured noise against noise and read 0.16-0.56 even for an
% excellent predictor. The right metric applies the weights to RAW per-trial pre-onset and
% post-settle frames (real ongoing activity) and asks how well the prediction tracks ipsi there.
Zpre = cell(nA,1);  ypre = cell(nA,1);  Zpost = cell(nA,1);  ypost = cell(nA,1);
mpre = cell(nA,1);  mpost = cell(nA,1);
for ai = 1:nA
    onF = onFcell{ai};  if isempty(onF) || isempty(evZc{ai}), continue; end
    frPre  = onF(:).' + rel(1:preN).';                 frPre  = frPre(:).';
    frPost = onF(:).' + rel(scc{ai}(end)+1:Wb).';      frPost = frPost(:).';
    frPre  = frPre( frPre >=1 & frPre <=size(V_cp,2));
    frPost = frPost(frPost>=1 & frPost<=size(V_cp,2));
    Zpre{ai}  = (Ug*double(V_cp(:,frPre ))-mu_p)./sd_p;   ypre{ai}  = double(y_full(frPre ));
    Zpost{ai} = (Ug*double(V_cp(:,frPost))-mu_p)./sd_p;   ypost{ai} = double(y_full(frPost));
    if haveMot
        mpre{ai}  = local_fill((motz(min(max(frPre ,1),numel(motz)))-P.motNorm.mu)/P.motNorm.sd).';
        mpost{ai} = local_fill((motz(min(max(frPost,1),numel(motz)))-P.motNorm.mu)/P.motNorm.sd).';
    end
end

%% ---- (k) distance from each contra px to the ipsi site ----------------------------------------
% Computed in NATIVE array coordinates. A dihedral display transform preserves distance exactly,
% so this is identical to the display-space version the old pipeline used -- and needs no view.
selDist = hypot(double(grR)-px_prim, double(grC)-py_prim);

%% ---- (l) display transform, for the STAGE-2 affected layout figure only -----------------------
T = cp_orient(mimg, px_prim, py_prim, struct('cache_file', ...
        fullfile(cfg.dataDir, sprintf('cp_orient_%s.mat', P.sess_tag)), 'verbose',false));
[dspGr, dspGc] = cp_orient_fwd(T, grR, grC);
[dspSr, dspSc] = cp_orient_fwd(T, px_prim, py_prim);
oI = cp_orient_img(T, mimg);
dspImg = (oI - min(oI(:)))/max(max(oI(:))-min(oI(:)), eps);

%% ---- pack -------------------------------------------------------------------------------------
P.amps=amps; P.nA=nA; P.nG=nG; P.nT_amp=nT_amp; P.onFcell=onFcell;
P.onF0=onF0; P.nT0=nT0; P.rel=rel; P.preN=preN; P.Wb=Wb; P.nF=nF;
P.inhCols=inhCols; P.rebCols=rebCols; P.dipCols=dipColsShared;
P.troughMs=troughMs; P.troughDf=troughDf; P.recMs=recMs; P.setMs=setMs; P.mAmpP=mAmpP;
P.Ug=Ug; P.V=V_cp; P.gridIdx=gridIdx; P.mu_p=mu_p; P.sd_p=sd_p; P.y_full=y_full;
P.frames=frames; P.itr=itr; P.ite=ite;
P.Gz=Gz; P.cz=cz; P.Zte=Zte; P.yte=yte; P.muY=muY; P.sstot=sstot;
P.Gz_a=Gz_a; P.cz_a=cz_a; P.Zte_a=Zte_a; P.haveMot=haveMot; P.motz=motz; P.evMot=evMot;
P.evZc=evZc; P.aAc=aAc; P.dcc=dcc; P.rcc=rcc; P.scc=scc;
P.evZcA=evZcA; P.aAcA=aAcA; P.evZcB=evZcB; P.aAcB=aAcB;
P.Zpre=Zpre; P.ypre=ypre; P.Zpost=Zpost; P.ypost=ypost; P.mpre=mpre; P.mpost=mpost;
P.blk0=blk0; P.m0=m0; P.mResp=mResp; P.blkA=blkA;
P.selDist=selDist; P.grR=grR; P.grC=grC; P.site=[px_prim py_prim]; P.k_prim=k_prim;
P.mimg=mimg; P.contra_mask=contra_mask; P.ipsi_mask=ipsi_mask;
P.dspImg=dspImg; P.dspGr=dspGr; P.dspGc=dspGc; P.dspSr=dspSr; P.dspSc=dspSc; P.Torient=T;
P.cfg=cfg;

if vb
    fprintf('  [prep] %d amps (%s V) | %d spont frames (%d train / %d test) | %s catch n=%d\n', ...
        nA, strjoin(compose('%.2g',amps(:).'),','), numel(frames), numel(itr), numel(ite), ...
        P.catch_kind, nT0);
    if ~isempty(P.caveat), fprintf(2,'  [CAVEAT] %s\n', P.caveat); end
end
end

% ------------------------------------------------------------------------------------------------
function v = local_fill(v)
% NaN -> 0 after z-scoring: a missing motion sample contributes nothing to the fit rather than
% propagating NaN through the Gram matrix and silently killing every weight.
v = v(:);  v(~isfinite(v)) = 0;
end
