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
%      (On m4 this is ~42%: most of the ipsi dip is network-shared, predictable from contra.
%       We report the split honestly rather than forcing it to 100% -- that would need the KKT
%       stim-blind constraint, deliberately NOT used here per the pure-pixel choice.)
%
% PREREQS
%   Run ctrl_ols_spont.m (Stage 1) first for THIS session -> data/ctrl_ols_spont_<sess>.mat.
%   Needs `mouse`,`fields` in the workspace (load_sessions.m) for the session's d/data.
%
% SECTIONS: [CFG] [LOAD] [AFFECTED] [FIT] [DEPLOY] [FIG] [SAVE]

%% [CTRL-OL-CFG] knobs ---------------------------------------------------------
selField    = 4;         % session index into `fields` (must match a Stage 1 run)
nSV_load    = 500;
Fs          = 35;
% STIM-AFFECTED contra px: MANUAL dip-score threshold, IDENTICAL definition to ctrl_affected_gui.m
% (trial-averaged %dF trace; score = (trough - onset_ref)/pre_SD; affected where score < -aff_dip_thr).
% Set aff_dip_thr to the slider value you converged on in the GUI. Adaptive/permutation was rejected.
aff_dip_thr = 1.5;       % affected if dip score < -aff_dip_thr  (downward dips only)  <-- GUI slider value
pre_sd_s    = 6.0;       % baseline-SD window for the score  [-6,0] s
ref_s       = 1.0;       % onset-reference window  [-1,0] s
trough_s    = 0.5;       % sliding-window length for the trough (s)
pre_s       = 1.0;       % pre-stim baseline window for the DECOMPOSITION (s)
dip_tran_s  = 0.5;       % transient dip window [0,dip_tran_s] s (capture report)
rng(7,'twister');

assert(exist('mouse','var') && exist('fields','var'), ...
    '[CTRL-OL] run controller-analysis/load_sessions.m first (need `mouse`,`fields`).');

here = fileparts(mfilename('fullpath'));
if isempty(here) || contains(here,tempdir,'IgnoreCase',true) || contains(here,'Editor_','IgnoreCase',true)
    here = fullfile(pwd,'controller-analysis');  if ~exist(here,'dir'); here = pwd; end
end
dataDir = fullfile(here,'data');
paper_root = fullfile(here,'..','paper');
fig_dir = fullfile(paper_root,'images','figure4'); if ~exist(fig_dir,'dir'); mkdir(fig_dir); end

%% [CTRL-OL-LOAD] Stage 1 cache + U/V + rebuild target ------------------------
fld = fields{selField};
d_s  = mouse.(fld).d;  data = mouse.(fld).data;
mn = mouse.(fld).mn; td = mouse.(fld).td; en = mouse.(fld).en;
sess_tag = sprintf('%s_%s%s_e%d', mn, td(6:7), td(9:10), en);

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
[U_cp, V_cp, t_svd, mimg_cp] = loadUVt(serverRoot, nSV_load);
V_cp = double(V_cp);
[nY_cp, nX_cp] = size(mimg_cp);  nSV_cp = size(U_cp,3);
Uflat = reshape(U_cp, nY_cp*nX_cp, nSV_cp);
t_full = t_svd(:);  nF_m = min(size(V_cp,2), numel(t_full));

% Actual = SVD raw-kernel + rolling baseline at the laser site (same as Stage 1)
[y_full, okY] = local_svd_rolling_dfk(Uflat, V_cp, mimg_cp, px_prim, py_prim, k_prim, horizon, nY_cp, nX_cp);
assert(okY, '[CTRL-OL] target rebuild failed at [row %d col %d].', px_prim, py_prim);

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
dipScore = local_dip_score(periAvg, iRef, iStim, iPre, wlen);   % negative = dip
affected = dipScore < -aff_dip_thr;             % DOWNWARD dips only (manual threshold)
unaff    = ~affected;
fprintf('[CTRL-OL] affected contra px: %d/%d (dip score < -%.2f) -> %d unaffected\n', ...
    nnz(affected), nG, aff_dip_thr, nnz(unaff));
if nnz(unaff) < 20
    warning('[CTRL-OL] only %d unaffected px -- dip threshold may be too strict.', nnz(unaff));
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
ys = y_full(frames);  ytr = ys(itr);  yte = ys(ite);  muY = mean(ytr);
b  = (Ztr.'*Ztr + 1e-6*mean(sum(Ztr.^2))*eye(numel(Su))) \ (Ztr.'*(ytr-muY));
r2f = @(y,yh) 1 - sum((y(:)-yh(:)).^2)/max(sum((y(:)-mean(y(:))).^2),eps);
R2_te = r2f(yte, muY+Zte*b);  R2_tr = r2f(ytr, muY+Ztr*b);
fprintf('[CTRL-OL] Global predictor (dense OLS, %d unaffected px): held-out spont R^2 = %.3f (train %.3f)\n', ...
    numel(Su), R2_te, R2_tr);

% Global over all frames = counterfactual ipsi from unaffected contra ongoing state
Gall = muY + (((Xg_full(Su,:)-mu)./sd).') * b;             % [T x 1]

%% [CTRL-OL-DEPLOY] OL Actual / Global / Local -------------------------------
A_tr = zeros(nTr,nRel);  G_tr = zeros(nTr,nRel);
for j = 1:nTr
    A_tr(j,:) = y_full(onF(j)+rel).';
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

nexttile(tl,2); hold on;                                  % affected map (native)
gg = mat2gray(mimg_cp); image(repmat(gg,1,1,3)); axis image ij off;
scatter(grC(unaff),  grR(unaff),  16, [0.2 0.6 0.9], 'filled', 'MarkerFaceAlpha',0.5);   % unaffected
scatter(grC(affected),grR(affected),34,[0.9 0.2 0.1], 'filled');                          % affected
plot(py_prim, px_prim, 'g+', 'MarkerSize',13, 'LineWidth',2.2);
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
OL.b=b; OL.mu=mu; OL.sd=sd; OL.muY=muY; OL.Su=Su;
OL.R2_te=R2_te; OL.R2_tr=R2_tr;
OL.onF=onF; OL.rel=rel; OL.pre=pre; OL.Fs=Fs;
OL.A_tr=A_tr; OL.G_tr=G_tr; OL.L_tr=L_tr; OL.Aa=Aa; OL.Gg=Gg; OL.Lo=Lo;
OL.capt_tran=capt(twin); OL.leak_tran=leak(twin); OL.capt_sus=capt(swin);
OL.px_prim=px_prim; OL.py_prim=py_prim; OL.gridIdx=gridIdx; OL.grR=grR; OL.grC=grC;
ol_file = fullfile(dataDir, sprintf('ctrl_ols_ol_stimblind_%s.mat', sess_tag));
save(ol_file, '-struct', 'OL', '-v7.3');
fprintf('[CTRL-OL-SAVE] -> %s\n\n', ol_file);

% ---- dip score (IDENTICAL to ctrl_affected_gui.m dip_score_; keep in sync) ---
function sc = local_dip_score(A, iRef, iStim, iPre, wlen)
% A [N x nRel] trial-averaged %dF traces -> [N x 1] dip score (negative = dip).
ref    = mean(A(:,iRef),2);
Wm     = movmean(A(:,iStim), wlen, 2);          % sliding-window mean over stim
trough = min(Wm,[],2);                          % deepest sub-window (catches transient dips)
sd     = std(A(:,iPre),0,2) + eps;
sc     = (trough - ref)./sd;
end

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
