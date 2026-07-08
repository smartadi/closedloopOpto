% contra_prediction_controller.m  --  Zhiwen-faithful contra->ipsi predictor on
% CONTROLLER sessions: "predictability of trials from the contralateral hemisphere"
% (the state-dependence analysis planned with Nick).
%
% WHAT THIS IS
%   The impulse-analysis contra predictor (the Zhiwen/Ye whole-hemisphere RRR map,
%   utils/cp_hemi_predictor.m -> the [CP-HEMI] field->kernel readout) deployed on
%   closed-/open-loop controller data. The predictor is fit ONCE on spontaneous
%   (inter-stim) frames, collapsed to a pointwise affine map on the contra SVD
%   modes, then applied per trial:
%
%       yhat_dF(t) = V_c_full(1:K, t).' * H.bk + H.b0        (% dF/F, ~ dFk units)
%
%   so every trial gets a contra-only prediction of the controlled primary-pixel
%   trace (dFk). From that we measure, per trial, how PREDICTABLE the trajectory is
%   from the contralateral hemisphere, and ask whether the controller DECOUPLES that
%   predictable (global) drive from the trial outcome (OL vs CL) -- root CLAUDE.md
%   open Q2 (K2 OL vs CL slopes) and the impulse bridge (motion->lower MSE via the
%   low-variance desynchronized global state).
%
% FAITHFULNESS
%   Reuses the SAME shared helpers as impulse-analysis/contra_prediction.m:
%     utils/cp_roi_masks.m       -- midline-split contra(predictor)/ipsi(target) masks
%     utils/redoSVD.m            -- contra-hemisphere SVD timecourses (V_c_full)
%     utils/cp_hemi_predictor.m  -- whole-hemi CanonCor2 RRR -> affine field->kernel map
%   No reimplementation of the predictor; only the data plumbing differs (controller
%   session struct instead of allExperiments). When the impulse predictor changes,
%   this inherits it automatically.
%
% PREREQS
%   1. Run controller-analysis/load_sessions.m first (builds `mouse`,`fields`, the
%      per-session `.d` with `.svd`, and `.data` with `.dFk`,`.nc`,`.wc`).
%   2. First run draws the brain outline + midline ONCE per session (cp_roi_masks,
%      interactive) and caches the contra SVD. Controller `.d.svd` is already in the
%      session cache, so NO server reload is needed (unlike the impulse side).
%
% RUN ORDER  [CTRL-CP-SETUP] first, then [CTRL-CP-TRIAL], then [CTRL-CP-STATE].
% STATUS: SCAFFOLD -- not yet run end-to-end. Knobs/TODO marked inline. Build only.

%% [CTRL-CP-CFG]  knobs ---------------------------------------------------------
selField  = 10;      % session index into `fields` (load_sessions). 10 = AL_0039 (selField default elsewhere)
H_K       = 50;      % contra SVD modes fed to the RRR (cp_hemi_predictor default)
settle_s  = 1.0;     % drop this much after each onset before counting a gap as spontaneous
dur       = 3;       % trial response window (s) -- matches load_sessions er_*Dfk / pncDfk
Fs        = 35;      % widefield blue frame rate (project-wide controller Fs)
ref       = -5;      % d.ref project default; error = dFk - ref = dFk + 5
redefine_roi = false;% set true to re-draw the brain outline + midline for this session
nSV_contra   = 50;   % contra modes kept from redoSVD (>= H_K)

assert(exist('mouse','var') && exist('fields','var'), ...
    'Run controller-analysis/load_sessions.m first (need `mouse`,`fields`).');

dataDir = fullfile('controller-analysis','data');
if ~exist(dataDir,'dir'); dataDir = 'data'; end          % fallback to root data/
if exist(fullfile('paper','images'),'dir'); paper_root = 'paper';
elseif exist(fullfile('..','paper','images'),'dir'); paper_root = fullfile('..','paper');
else; paper_root = 'paper'; end
fig_dir = fullfile(paper_root,'images','figure4'); if ~exist(fig_dir,'dir'); mkdir(fig_dir); end
PS = paperStyle(); setPaperDefaults();

%% [CTRL-CP-SETUP]  fit the contra->primary predictor on spontaneous frames -- RUN FIRST
% Builds masks + contra SVD modes, fits cp_hemi_predictor (Hp), and deploys it over
% ALL frames -> yhat_full (contra-only prediction of dFk, aligned to d.timeBlue).
fld = fields{selField};
if isfield(mouse.(fld),'skip') && mouse.(fld).skip
    error('[CTRL-CP] session %s was skipped during load_sessions.', fld);
end
d    = mouse.(fld).d;
data = mouse.(fld).data;
sess_tag = sprintf('%s_%s_e%d', mouse.(fld).mn, mouse.(fld).td, mouse.(fld).en);

% --- session SVD (already cached in d; no server reload) ---
if ~isfield(d,'svd')
    fprintf('[CTRL-CP] %s has no .svd -- reloading via initialize_data...\n', fld);
    d = initialize_data(mouse.(fld).mn, mouse.(fld).en, mouse.(fld).td);
end
U_cp  = d.svd.U;  V_cp = double(d.svd.V);  mimg_cp = d.svd.mimg;
[nY_cp, nX_cp] = size(mimg_cp);  nSV_cp = size(U_cp,3);

py_prim = double(d.params.pixel(1));     % primary pixel "row" arg (cp_roi_masks prim_col)
px_prim = double(d.params.pixel(2));     % primary pixel "col" arg (cp_roi_masks prim_row)
if isfield(d.params,'kernel'); k_prim = double(d.params.kernel); else; k_prim = 2; end

y_full = data.dFk(:);                    % controlled primary-pixel trace (% dF/F) = target
t_full = d.timeBlue(:);                  % frame times
nF_m   = min(numel(y_full), numel(t_full));

% --- all stim onsets (both OL `nc` and CL `wc`) define the inter-stim gaps ---
all_starts = sort(d.stimStarts(:));
all_starts = all_starts(isfinite(all_starts) & all_starts > 0);

% --- midline-split masks (contra = predictor, ipsi = primary-pixel side = target) ---
roi_file = fullfile(dataDir, sprintf('cp_roi2_ctrl_%s.mat', sess_tag));
M_cp = cp_roi_masks(mimg_cp, roi_file, px_prim, py_prim, ...
                    struct('redefine', redefine_roi, 'thr_pctile', 20, 'plot', true));
contra_mask = M_cp.contra;  ipsi_mask = M_cp.ipsi;

% --- contra-hemisphere SVD modes V_c_full (cache alongside session) ---
path_cp      = fullfile(dataDir, sprintf('cp_ctrl_%s.mat', sess_tag));
path_svd_raw = strrep(path_cp, '.mat', '_svdraw_ml.mat');
if exist(path_svd_raw,'file')
    tmp = load(path_svd_raw,'U_svd_raw','V_c_full');
    U_svd_raw = tmp.U_svd_raw;  V_c_full = tmp.V_c_full;
    fprintf('[CTRL-CP] loaded contra SVD cache: %s\n', path_svd_raw);
else
    idx_contra = find(contra_mask(:));
    U_flat     = reshape(U_cp, nY_cp*nX_cp, nSV_cp);
    U_contra   = double(U_flat(idx_contra,:));
    fprintf('[CTRL-CP] redoSVD on contra mask (%d px)...\n', numel(idx_contra));
    [U_svd_raw, V_c_full] = redoSVD(U_contra, V_cp);
    U_svd_raw = double(U_svd_raw);  V_c_full = double(V_c_full);
    save(path_svd_raw,'U_svd_raw','V_c_full','-v7.3');
    fprintf('[CTRL-CP] saved contra SVD cache: %s (%d modes)\n', path_svd_raw, size(V_c_full,1));
end

% --- fit the Zhiwen-faithful predictor (shared helper) ---
Hp = cp_hemi_predictor(struct( ...
    'U_cp',U_cp,'V_cp',V_cp,'mimg_cp',mimg_cp,'nY_cp',nY_cp,'nX_cp',nX_cp, ...
    'nSV_cp',nSV_cp,'V_c_full',V_c_full,'ipsi_mask_cp',ipsi_mask, ...
    'py_prim',py_prim,'px_prim',px_prim,'k_prim',k_prim, ...
    'y_full',y_full,'t_full',t_full,'all_starts_cp',all_starts, ...
    'nF_m',nF_m,'Fs',Fs,'path_cp',path_cp,'K',H_K,'settle_s',settle_s));
Kh = Hp.K;
predFun  = @(g) V_c_full(1:Kh, g).' * Hp.bk + Hp.b0;     % contra-only prediction (% dF/F)
yhat_full = predFun(1:nF_m);                             % deploy over all frames
fprintf('[CTRL-CP-SETUP] %s | held-out primary-pixel R^2=%.3f @rank%d | pooled@10=%.3f\n', ...
    sess_tag, Hp.cv, Hp.rankSel, Hp.pool10);

%% [CTRL-CP-TRIAL]  per-trial contra-predictability (OL `nc` vs CL `wc`)
% For each trial, slice actual dFk and the contra prediction over the SAME window
% load_sessions uses (-3 s .. +(dur+3) s about onset) and quantify how well contra
% predicts THIS trial: trajectory R^2 over the 0..dur response window + residual
% energy (the part the controller/local circuit is NOT explained by contra).
if ~exist('predFun','var'); error('[CTRL-CP] run [CTRL-CP-SETUP] first.'); end
pre_n  = 3*Fs;  post_n = (dur+3)*Fs;             % matches pncDfk window in load_sessions
tp     = (-pre_n : post_n) / Fs;                 % trial time axis (s)
iResp  = find(tp >= 0 & tp <= dur);              % response window (= MSE window)
iPre   = find(tp >= -1 & tp <  0);               % 1 s pre-stim (contra "state" probe)

trial_sets = {'nc', data.nc; 'wc', data.wc};     % OL = nc, CL = wc
CP = struct();
for s = 1:2
    lab = trial_sets{s,1};  idxTr = trial_sets{s,2};
    nT  = numel(idxTr);
    r2   = nan(nT,1);   % trajectory R^2, contra vs actual, response window
    rho  = nan(nT,1);   % corr(actual,pred), response window
    resE = nan(nT,1);   % residual energy = norm(actual - pred) over MSE window
    preP = nan(nT,1);   % contra-predicted pre-stim level (state regressor)
    preV = nan(nT,1);   % contra-predicted pre-stim variance (state regressor)
    mse  = nan(nT,1);   % trial outcome = norm(dFk - ref) over response window
    act_all = nan(nT, numel(tp));   prd_all = nan(nT, numel(tp));
    for j = 1:nT
        [~, i0] = min(abs(t_full - d.stimStarts(idxTr(j))));
        g = i0-pre_n : i0+post_n;
        if g(1) < 1 || g(end) > nF_m; continue; end
        ya = y_full(g);   yp = yhat_full(g);
        act_all(j,:) = ya';  prd_all(j,:) = yp';
        a = ya(iResp);  p = yp(iResp);
        r2(j)   = sseExplainedCal(a(:).', p(:).');
        rho(j)  = corr(a(:), p(:));
        resE(j) = norm(a(:) - p(:));
        preP(j) = mean(yp(iPre),'omitnan');
        preV(j) = var(yp(iPre),'omitnan');
        mse(j)  = norm(ya(iResp) - ref);          % = norm(dFk+5), same as er_*Dfk
    end
    CP.(lab) = struct('idx',idxTr,'r2',r2,'rho',rho,'resE',resE, ...
                      'preP',preP,'preV',preV,'mse',mse, ...
                      'act',act_all,'prd',prd_all);
end
fprintf('[CTRL-CP-TRIAL] OL(nc) median traj R^2=%.3f (n=%d) | CL(wc) median traj R^2=%.3f (n=%d)\n', ...
    median(CP.nc.r2,'omitnan'), numel(CP.nc.idx), ...
    median(CP.wc.r2,'omitnan'), numel(CP.wc.idx));

%% [CTRL-CP-STATE]  does the controller DECOUPLE the contra-predictable drive?
% Two readouts of "predictability of trials from contra", OL vs CL:
%  (1) trajectory predictability distribution  -- is CL less contra-predictable?
%  (2) STATE->OUTCOME slope: regress trial MSE on the contra-predicted pre-stim
%      state (preP/preV). Flat CL slope vs steep OL slope = the controller has
%      decoupled the pre-stim global state from the outcome (CLAUDE.md open Q2).
if ~isfield(CP,'nc'); error('[CTRL-CP] run [CTRL-CP-TRIAL] first.'); end
col = struct('ol',[0.20 0.40 0.85],'cl',[0.85 0.30 0.10]);

fig = paperFig(18, 6);
% (1) predictability distributions
ax1 = subplot(1,3,1); hold(ax1,'on');
histogram(ax1, CP.nc.r2, 'Normalization','pdf','FaceColor',col.ol,'FaceAlpha',0.4,'EdgeColor','none');
histogram(ax1, CP.wc.r2, 'Normalization','pdf','FaceColor',col.cl,'FaceAlpha',0.4,'EdgeColor','none');
xlabel(ax1,'Trajectory R^2 (contra)','FontSize',PS.fs,'FontWeight',PS.fw);
ylabel(ax1,'pdf','FontSize',PS.fs,'FontWeight',PS.fw);
title(ax1,'Trial predictability: OL vs CL','FontSize',PS.fs,'FontWeight',PS.fw);
legend(ax1,{'OL (nc)','CL (wc)'},'Box','off','FontSize',PS.fs);

% (2) state->outcome slope, pre-stim contra-predicted LEVEL
ax2 = subplot(1,3,2); hold(ax2,'on');
[bOL,pOL] = scatfit(ax2, CP.nc.preP, CP.nc.mse, col.ol);
[bCL,pCL] = scatfit(ax2, CP.wc.preP, CP.wc.mse, col.cl);
xlabel(ax2,'Contra-predicted pre-stim level','FontSize',PS.fs,'FontWeight',PS.fw);
ylabel(ax2,'Trial MSE','FontSize',PS.fs,'FontWeight',PS.fw);
title(ax2,sprintf('slope OL=%.2f(p=%.2g) CL=%.2f(p=%.2g)',bOL,pOL,bCL,pCL), ...
    'FontSize',PS.fs,'FontWeight',PS.fw);

% (3) state->outcome slope, pre-stim contra-predicted VARIANCE
ax3 = subplot(1,3,3); hold(ax3,'on');
[bOLv,pOLv] = scatfit(ax3, CP.nc.preV, CP.nc.mse, col.ol);
[bCLv,pCLv] = scatfit(ax3, CP.wc.preV, CP.wc.mse, col.cl);
xlabel(ax3,'Contra-predicted pre-stim variance','FontSize',PS.fs,'FontWeight',PS.fw);
ylabel(ax3,'Trial MSE','FontSize',PS.fs,'FontWeight',PS.fw);
title(ax3,sprintf('slope OL=%.2f(p=%.2g) CL=%.2f(p=%.2g)',bOLv,pOLv,bCLv,pCLv), ...
    'FontSize',PS.fs,'FontWeight',PS.fw);
sgtitle(fig, sprintf('Contra predictability of trials  %s', sess_tag), ...
    'FontSize',PS.fs,'FontWeight',PS.fw,'Interpreter','none');
paperExport(fig, fullfile(fig_dir, sprintf('ctrl_contra_pred_%s.png', sess_tag)));
fprintf('[CTRL-CP-STATE] exported ctrl_contra_pred_%s.png\n', sess_tag);

% ---- local helpers ----------------------------------------------------------
function [b,p] = scatfit(ax, x, y, c)
% scatter + LS line; return slope and slope p-value (finite pairs only)
gd = isfinite(x) & isfinite(y);  x = x(gd); y = y(gd);
scatter(ax, x, y, 8, c, 'filled', 'MarkerFaceAlpha',0.35);
b = nan; p = nan;
if numel(x) > 2
    pc = polyfit(x, y, 1); b = pc(1);
    xl = [min(x) max(x)]; plot(ax, xl, polyval(pc,xl), '-', 'Color',c, 'LineWidth',1.2);
    [~,~,~,~,st] = regress(y, [ones(numel(x),1) x]);  % st(3) = p of model
    p = st(3);
end
end
