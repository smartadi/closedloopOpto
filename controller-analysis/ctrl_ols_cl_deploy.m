% ctrl_ols_cl_deploy.m -- STAGE 3: deploy the stim-blind Global predictor on CLOSED-LOOP trials.
%
% GOAL (user Objective 1, 2026-07-19)
%   "Using this model find the activity of ipsi such that NO closed-loop control was applied."
%   The Global predictor (dense OLS on spontaneous, stim-BLIND unaffected contra px -- fit in
%   Stage 1, pixel set chosen in Stage 2) reconstructs the ipsi laser-site trace from ongoing
%   contralateral state ALONE. On CL trials it is therefore the counterfactual "ipsi with no laser":
%
%       Actual_CL = the controlled ipsi trace (what the closed loop achieved)
%       Global_CL = ipsi predicted from stim-blind contra   == "no controller input" counterfactual
%       Local_CL  = Actual_CL - Global_CL                    == the controller's own contribution
%
%   Because Global is built only from pixels that never respond to the laser, it is CONTROL-AGNOSTIC:
%   Global_CL should look like Global_OL (same underlying network state). We check that explicitly.
%
% DELIVERABLE
%   1. CL trial-avg decomposition (Actual / Global / Local), same frame as the OL Stage-2 figure.
%   2. OL-vs-CL overlay: Global_OL ~ Global_CL (validates control-agnostic); Actual_OL vs Actual_CL
%      (OL = fixed open-loop step, CL = adaptive hold at the reference).
%   3. ABSOLUTE-units panel with the reference line (d.ref = -5): Actual_CL holds near ref while
%      Global_CL (no control) sits near baseline -> the gap the controller closed.
%
% PREREQS  Stage 1 (ctrl_ols_spont.m) AND Stage 2 (ctrl_ols_ol_stimblind.m) caches for THIS session;
%          `mouse`,`fields` in the workspace (load_sessions.m).
%
% SECTIONS: [CFG] [LOAD] [GLOBAL] [DEPLOY-CL] [COMPARE] [FIG] [SAVE]

%% [CTRL-CL-CFG] -----------------------------------------------------------------
selField   = 4;          % session index into `fields` (must match the Stage 1/2 runs)
nSV_load   = 500;
Fs         = 35;
pre_s      = 1.0;        % per-trial baseline window [-1,0] s (matches Stage 2)
dip_tran_s = 0.5;        % transient window [0,dip_tran_s] s (metrics)
ref_level  = -5;         % d.ref, project-wide reference (%dF/F) -- absolute-units panel
rng(7,'twister');

assert(exist('mouse','var') && exist('fields','var'), ...
    '[CTRL-CL] run controller-analysis/load_sessions.m first (need `mouse`,`fields`).');
here = fileparts(mfilename('fullpath'));
if isempty(here) || contains(here,tempdir,'IgnoreCase',true) || contains(here,'Editor_','IgnoreCase',true)
    here = fullfile(pwd,'controller-analysis');  if ~exist(here,'dir'); here = pwd; end
end
dataDir = fullfile(here,'data');
fig_dir = fullfile(here,'..','paper','images','predictor_saga'); if ~exist(fig_dir,'dir'); mkdir(fig_dir); end

%% [CTRL-CL-LOAD] Stage 1 + Stage 2 caches, U/V, rebuild target ------------------
fld = fields{selField};
d_s  = mouse.(fld).d;  data = mouse.(fld).data;
mn = mouse.(fld).mn; td = mouse.(fld).td; en = mouse.(fld).en;
sess_tag = sprintf('%s_%s%s_e%d', mn, td(6:7), td(9:10), en);

s1_file = fullfile(dataDir, sprintf('ctrl_ols_spont_%s.mat', sess_tag));
s2_file = fullfile(dataDir, sprintf('ctrl_ols_ol_stimblind_%s.mat', sess_tag));
assert(exist(s1_file,'file')>0, '[CTRL-CL] Stage 1 cache missing: %s', s1_file);
assert(exist(s2_file,'file')>0, '[CTRL-CL] Stage 2 cache missing: %s -- run ctrl_ols_ol_stimblind.m first.', s2_file);
S1 = load(s1_file);  S2 = load(s2_file);

gridIdx = S1.gridIdx;  grR = S1.grR;  grC = S1.grC;
px_prim = S1.px_prim;  py_prim = S1.py_prim;  k_prim = S1.k_prim;  horizon = S1.horizon;
dur = S1.trial_dur;
% Stage-2 stim-blind predictor (IDENTICAL Global as OL) + OL decomposition for comparison
b = S2.b;  mu = S2.mu;  sd = S2.sd;  muY = S2.muY;  Su = S2.Su;
unaff = S2.unaff;  aff_dip_thr = S2.aff_dip_thr;
Aa_OL = S2.Aa;  Gg_OL = S2.Gg;  Lo_OL = S2.Lo;  rel_OL = S2.rel;
fprintf('[CTRL-CL] %s | Stage 2 predictor: %d unaffected px @ aff_dip_thr=%.2f (spont R^2=%.3f)\n', ...
    sess_tag, numel(Su), aff_dip_thr, S2.R2_te);

serverRoot = expPath(mn, td, en);
[U_cp, V_cp, t_svd, mimg_cp] = loadUVt(serverRoot, nSV_load);
V_cp = double(V_cp);  [nY_cp, nX_cp] = size(mimg_cp);  nSV_cp = size(U_cp,3);
Uflat = reshape(U_cp, nY_cp*nX_cp, nSV_cp);  t_full = t_svd(:);
nF_m = min(size(V_cp,2), numel(t_full));

% Actual = SVD raw-kernel + rolling baseline at the laser site (same target as Stage 1/2)
[y_full, okY] = local_svd_rolling_dfk(Uflat, V_cp, mimg_cp, px_prim, py_prim, k_prim, horizon, nY_cp, nX_cp);
assert(okY, '[CTRL-CL] target rebuild failed.');
Xg_full = double(Uflat(gridIdx,:)) * V_cp;                 % [nG x T] contra grid dF

%% [CTRL-CL-GLOBAL] counterfactual "no-control" ipsi over all frames -------------
Gall = muY + (((Xg_full(Su,:)-mu)./sd).') * b;             % [T x 1]  == ipsi if the laser were off

%% [CTRL-CL-DEPLOY] closed-loop trial decomposition ------------------------------
pre  = round(pre_s*Fs);  post = round(dur*Fs);
rel  = -pre:post;  nRel = numel(rel);
bwin = 1:pre;                                   % [-1,0]s baseline
twin = pre+1:pre+round(dip_tran_s*Fs);          % [0,dip_tran]s transient
swin = pre+1:pre+post;                          % [0,dur]s sustained

cl_starts = sort(d_s.stimStarts(data.wc(:)));   % CLOSED-LOOP onsets
assert(~isempty(cl_starts), '[CTRL-CL] no closed-loop (data.wc) trials in this session.');
onF = zeros(numel(cl_starts),1);
for j = 1:numel(cl_starts), [~,onF(j)] = min(abs(t_full - cl_starts(j))); end
onF = onF(onF>pre & onF+post<=nF_m);  nTr = numel(onF);
fprintf('[CTRL-CL] %d closed-loop trials\n', nTr);

Aabs = zeros(nTr,nRel);  Gabs = zeros(nTr,nRel);          % ABSOLUTE %dF (for the ref panel)
for j = 1:nTr
    Aabs(j,:) = y_full(onF(j)+rel).';
    Gabs(j,:) = Gall(onF(j)+rel).';
end
bl = @(M) M - mean(M(:,bwin),2);                          % per-trial baseline-subtract
A_tr = bl(Aabs);  G_tr = bl(Gabs);  L_tr = A_tr - G_tr;   % Local = Actual - Global
Aa = mean(A_tr,1);  Gg = mean(G_tr,1);  Lo = mean(L_tr,1);
AaAbs = mean(Aabs,1);  GgAbs = mean(Gabs,1);              % absolute trial averages

capt = @(w) 100*mean(Lo(w))/mean(Aa(w));
leak = @(w) 100*mean(Gg(w))/mean(Aa(w));
[~,imn] = min(Aa);  Ldip = mean(L_tr(:,twin),2);

%% [CTRL-CL-COMPARE] OL vs CL + controller correction ----------------------------
% Global control-agnostic check: OL and CL Global should agree over the common window.
nC = min(numel(rel), numel(rel_OL));
rG = corr(Gg(1:nC).', Gg_OL(1:nC).');
% controller correction in absolute units (sustained window)
act_abs = mean(AaAbs(swin));  glob_abs = mean(GgAbs(swin));
err_noctrl = abs(glob_abs - ref_level);  err_ctrl = abs(act_abs - ref_level);

fprintf('\n[CTRL-CL] CL trial-avg decomposition (n=%d), baseline-subtracted:\n', nTr);
fprintf('   window        Actual  Global  Local  | local%%  shared%%\n');
fprintf('   transient[0,%.1fs] %6.2f %6.2f %6.2f | %5.0f  %5.0f\n', dip_tran_s,mean(Aa(twin)),mean(Gg(twin)),mean(Lo(twin)),capt(twin),leak(twin));
fprintf('   sustained[0,%gs]  %6.2f %6.2f %6.2f | %5.0f  %5.0f\n', dur,mean(Aa(swin)),mean(Gg(swin)),mean(Lo(swin)),capt(swin),leak(swin));
fprintf('   trough @%.2fs     %6.2f %6.2f %6.2f\n', rel(imn)/Fs,Aa(imn),Gg(imn),Lo(imn));
fprintf('   per-trial Local dip (transient): median %.2f  IQR [%.2f %.2f]\n', median(Ldip),prctile(Ldip,25),prctile(Ldip,75));
fprintf('   Global control-agnostic check: corr(Global_OL, Global_CL) = %.3f\n', rG);
fprintf('   ABSOLUTE (sustained): Actual_CL=%.2f  Global_CL(no-ctrl)=%.2f  ref=%.1f\n', act_abs,glob_abs,ref_level);
fprintf('   -> error from ref: no-control %.2f%%  vs  controlled %.2f%%  (controller closed %.2f%%)\n', ...
    err_noctrl, err_ctrl, err_noctrl-err_ctrl);

%% [CTRL-CL-FIG] ----------------------------------------------------------------
tt = rel/Fs;  ttO = rel_OL/Fs;
figC = figure('Color','w','Position',[50 60 1550 470]);
tl = tiledlayout(figC,1,3,'TileSpacing','compact','Padding','compact');
cA=[0 0 0]; cG=[0.85 0.4 0.1]; cL=[0.1 0.5 0.85];

% (1) CL decomposition (baseline-subtracted)
nexttile(tl,1); hold on;
sdA = std(A_tr,0,1)/sqrt(nTr);
fill([tt fliplr(tt)],[Aa+sdA fliplr(Aa-sdA)],[0 0 0],'FaceAlpha',0.12,'EdgeColor','none');
plot(tt,Aa,'-','Color',cA,'LineWidth',1.8);
plot(tt,Gg,'-','Color',cG,'LineWidth',1.4);
plot(tt,Lo,'-','Color',cL,'LineWidth',1.4);
xline(0,'k:'); yline(0,'k:'); xlim([tt(1) tt(end)]);
xlabel('time from stim (s)'); ylabel('\DeltaF/F (%)  (baseline-sub)');
legend({'\pmSEM','Actual','Global (no-ctrl)','Local = residual'},'Box','off','Location','southwest','FontSize',8);
title(sprintf('CL decomposition: Local %.0f%% / shared %.0f%% (sustained)',capt(swin),leak(swin)));

% (2) OL vs CL overlay
nexttile(tl,2); hold on;
pA_OL=plot(ttO,Aa_OL,'--','Color',[.3 .3 .3],'LineWidth',1.4);
pA_CL=plot(tt, Aa,   '-','Color',cA,'LineWidth',1.8);
pG_OL=plot(ttO,Gg_OL,'--','Color',[0.95 0.6 0.35],'LineWidth',1.3);
pG_CL=plot(tt, Gg,   '-','Color',cG,'LineWidth',1.4);
xline(0,'k:'); yline(0,'k:'); xlim([tt(1) tt(end)]);
xlabel('time from stim (s)'); ylabel('\DeltaF/F (%)  (baseline-sub)');
legend([pA_OL pA_CL pG_OL pG_CL], ...
    {'Actual OL','Actual CL','Global OL','Global CL'},'Box','off','Location','southwest','FontSize',8);
title(sprintf('OL vs CL  |  corr(Global_{OL},Global_{CL}) = %.2f',rG));

% (3) ABSOLUTE units + reference line -> the controller's counterfactual
nexttile(tl,3); hold on;
sdAbs = std(Aabs,0,1)/sqrt(nTr);
fill([tt fliplr(tt)],[AaAbs+sdAbs fliplr(AaAbs-sdAbs)],[0 0 0],'FaceAlpha',0.12,'EdgeColor','none');
plot(tt,AaAbs,'-','Color',cA,'LineWidth',1.8);
plot(tt,GgAbs,'-','Color',cG,'LineWidth',1.4);
yline(ref_level,'--','Color',[0.1 0.5 0.2],'LineWidth',1.2,'Label','ref -5','LabelHorizontalAlignment','left','FontSize',8);
xline(0,'k:'); xlim([tt(1) tt(end)]);
xlabel('time from stim (s)'); ylabel('\DeltaF/F (%)  (absolute)');
legend({'\pmSEM','Actual CL (controlled)','Global CL (no control)'},'Box','off','Location','southwest','FontSize',8);
title(sprintf('no-control ipsi = %.1f%% vs ref %.1f%%  (controller closed %.1f%%)',glob_abs,ref_level,err_noctrl-err_ctrl));

sgtitle(figC, sprintf('[CTRL-CL] Stage 3 closed-loop deploy  %s  (%d CL trials, aff\\_dip\\_thr=%.2f)', ...
    strrep(sess_tag,'_','\_'), nTr, aff_dip_thr));
fig_png = fullfile(fig_dir, sprintf('ctrl_cl_deploy_%s.png', sess_tag));
exportgraphics(figC, fig_png, 'Resolution', 300);
fprintf('[CTRL-CL-FIG] -> %s\n', fig_png);

%% [CTRL-CL-SAVE] ---------------------------------------------------------------
CL = struct();
CL.sess_tag=sess_tag; CL.selField=selField; CL.aff_dip_thr=aff_dip_thr; CL.nUnaff=numel(Su);
CL.onF=onF; CL.rel=rel; CL.pre=pre; CL.Fs=Fs; CL.dur=dur; CL.ref_level=ref_level;
CL.A_tr=A_tr; CL.G_tr=G_tr; CL.L_tr=L_tr; CL.Aa=Aa; CL.Gg=Gg; CL.Lo=Lo;
CL.Aabs=Aabs; CL.Gabs=Gabs; CL.AaAbs=AaAbs; CL.GgAbs=GgAbs;
CL.capt_tran=capt(twin); CL.leak_tran=leak(twin); CL.capt_sus=capt(swin); CL.leak_sus=leak(swin);
CL.corr_globalOLvsCL=rG; CL.act_abs=act_abs; CL.glob_abs=glob_abs;
CL.err_noctrl=err_noctrl; CL.err_ctrl=err_ctrl;
CL.px_prim=px_prim; CL.py_prim=py_prim; CL.gridIdx=gridIdx; CL.grR=grR; CL.grC=grC;
cl_file = fullfile(dataDir, sprintf('ctrl_ols_cl_deploy_%s.mat', sess_tag));
save(cl_file, '-struct', 'CL', '-v7.3');
fprintf('[CTRL-CL-SAVE] -> %s\n\n', cl_file);

% ---- predictor target (IDENTICAL to Stage 1/2; keep in sync) -------------------
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
