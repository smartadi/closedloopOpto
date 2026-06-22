% impulse-analysis/contra_lds.m
%
% Input-driven LDS (linear dynamical system) of the contra->ipsi impulse response.
%
% Model:
%   x(t+1) = A x(t)  +  B u(t)  +  w(t)          w ~ N(0,Q)
%   z_c(t) = C_c x(t) + D_c u(t) + v_c(t)         [contra SVD modes, OBSERVED]
%   y(t)   = c_y' x(t) + d u(t)  + v_y(t)         [ipsi primary pixel, HELD OUT]
%
%   u(t)   = laser amplitude at stim-onset frames, 0 elsewhere
%
% Universal Kalman filter: predictor runs over the FULL session (no per-trial
% resets). State at each trial onset reflects accumulated contra history.
% Ipsi is never fed back into the filter — it is held out for evaluation.
%
% Sections (run section-by-section in MATLAB):
%   LDS-SETUP   -- load SVD/ROI caches, build Z_obs and u_full
%   LDS-SPONT   -- n4sid on pre-trial windows (no input) -> A_spont
%   LDS-DRIVEN  -- n4sid on trial windows with u -> A_evoked, B, C, D, K
%   LDS-OL      -- open-loop impulse response vs trial average
%   LDS-KF      -- universal Kalman predictor over full session
%
% Prereq: load_experiments.m must have been run (allExperiments in workspace).
%         contra_residual.m must have been run once to create the SVD/ROI cache.
%
% Presettable knobs (set in workspace before running):
%   selExp    (3)   -- experiment index
%   nSV_lds   (10)  -- contra SVD modes used as observation channels
%   n_states  (15)  -- latent state dimension; sweep [5 10 15 20] manually
close all;

%% [LDS-SETUP] -----------------------------------------------------------------
lds_path = mfilename('fullpath');
if isempty(lds_path), lds_path = fullfile(pwd,'contra_lds.m'); end
impulseDir = fileparts(lds_path);
utilsDir   = fullfile(impulseDir,'..','utils');
dataDir    = fullfile(impulseDir,'data');
paperRoot  = fullfile(impulseDir,'..','paper');
addpath(utilsDir); addpath(genpath(utilsDir));
if ~exist(dataDir,'dir'), mkdir(dataDir); end

PS = paperStyle(); setPaperDefaults();

if ~exist('allExperiments','var') || isempty(allExperiments)
    error('contra_lds: run load_experiments.m first.');
end
if ~exist('selExp','var')   || isempty(selExp),   selExp   = 3;  end
if ~exist('nSV_lds','var')  || isempty(nSV_lds),  nSV_lds  = 10; end
if ~exist('n_states','var') || isempty(n_states), n_states = 15; end

nSV_load   = 500;
nSV_use    = 200;
spont_pre  = 6;     % s -- pre-trial spontaneous window for LDS-SPONT
pre_trial  = 1.0;   % s -- window before onset in driven iddata
post_trial = 2.5;   % s -- window after onset in driven iddata
Fs         = 35;

mn = allExperiments(selExp).mn;
td = allExperiments(selExp).td;
en = allExperiments(selExp).en;
fprintf('[LDS-SETUP] %s %s e%d | nSV_lds=%d n_states=%d\n', mn, td, en, nSV_lds, n_states);

y_full  = allExperiments(selExp).dF(:);
t_full  = allExperiments(selExp).timeBlue(:);
nFrames = numel(y_full);

% ---- Load SVD ----------------------------------------------------------------
serverRoot = expPath(mn, td, en);
[U_cp, V_cp, ~, mimg_cp] = loadUVt(serverRoot, nSV_load);
[nY_cp, nX_cp] = size(mimg_cp);
nSV_cp         = size(U_cp, 3);
brain_mask_cp  = mimg_cp > prctile(mimg_cp(:), 20);

d_tmp    = loadData(serverRoot, mn, td, en);
mot_full = d_tmp.motion.motion_1(1:2:end);
clear d_tmp

% ---- Load contra ROI (shared cache with contra_residual / cp_residual_core) -
roi_name = sprintf('cp_roi_%s_%s%s_e%d.mat', mn, td(6:7), td(9:10), en);
roi_file = fullfile(dataDir, roi_name);
if ~exist(roi_file,'file')
    error('contra_lds: ROI cache not found at\n  %s\nRun contra_residual.m first to define the contra ROI.', roi_file);
end
tmp      = load(roi_file);
ml_cp    = tmp.ml_cp; poly_col = tmp.poly_col; poly_row = tmp.poly_row;

[xg_s, yg_s]  = meshgrid(1:nY_cp, 1:nX_cp);
in_poly_s      = inpolygon(xg_s(:), yg_s(:), poly_row, poly_col);
valid_cp_svd   = reshape(in_poly_s, nX_cp, nY_cp)' & brain_mask_cp;

% ---- Load contra SVD temporal cache (created by cp_residual_core) ------------
path_cp      = fullfile(dataDir, sprintf('%scp%s%s%d.mat', mn, td(6:7), td(9:10), en));
path_svd_raw = strrep(path_cp, '.mat', '_svdraw.mat');   % matches cp_residual_core naming
if ~exist(path_svd_raw,'file')
    % Regenerate if missing (usually exists after contra_residual.m has run)
    idx_contra = find(valid_cp_svd(:));
    U_flat_cp  = reshape(U_cp, nY_cp*nX_cp, nSV_cp);
    U_contra   = double(U_flat_cp(idx_contra,:));
    fprintf('[LDS-SETUP] Running redoSVD (first run)...\n');
    [U_svd_raw, V_c_full] = redoSVD(U_contra, double(V_cp));
    U_svd_raw = double(U_svd_raw);  V_c_full = double(V_c_full);
    save(path_svd_raw, 'U_svd_raw', 'V_c_full', '-v7.3');
    fprintf('[LDS-SETUP] SVD cache saved: %s\n', path_svd_raw);
else
    tmp      = load(path_svd_raw, 'V_c_full');
    V_c_full = tmp.V_c_full;
    fprintf('[LDS-SETUP] SVD cache loaded: %s  (%d modes)\n', path_svd_raw, size(V_c_full,1));
end

nSV_actual = min(nSV_use, size(V_c_full,1));
X_cp_raw   = V_c_full(1:nSV_actual,:)';          % [nFrames x nSV_actual]
nF_m       = min(nFrames, size(X_cp_raw,1));
X_cp_z     = zscore(X_cp_raw(1:nF_m,:));          % global z-score (session-wide)
Z_obs      = X_cp_z(:, 1:nSV_lds);                % [nF_m x nSV_lds]
y_dm       = y_full(1:nF_m) - mean(y_full(1:nF_m),'omitnan');   % demeaned ipsi
mot_z      = zscore(mot_full(1:nF_m));

% Free the large SVD arrays before any n4sid call. V_c_full is [2000 x ~193k]
% (~3 GB); U_cp/V_cp another ~1.5 GB. Keeping them resident while n4sid builds
% Hankel/QR intermediates causes an OOM crash. Only Z_obs/y_dm/mot_z are needed
% downstream. (U_cp/V_cp are used only in the SVD-regenerate branch above.)
clear V_c_full X_cp_raw X_cp_z U_cp V_cp

fprintf('[LDS-SETUP] nF_m=%d  nSV_actual=%d  nSV_lds=%d\n', nF_m, nSV_actual, nSV_lds);

% ---- Trial info (all non-zero amplitude trials) ------------------------------
imp_data = allExperiments(selExp).imp;
uAmp     = allExperiments(selExp).uAmp;
nzMask   = uAmp > 0;

all_starts = []; all_amps = [];
for ia = 1:numel(uAmp)
    if ~nzMask(ia); continue; end
    st = imp_data.startTimes{ia}(:);
    all_starts = [all_starts; st];
    all_amps   = [all_amps;   repmat(uAmp(ia), numel(st), 1)];
end
[all_starts, sidx] = sort(all_starts);
all_amps   = all_amps(sidx);
nTrials    = numel(all_starts);
fprintf('[LDS-SETUP] %d non-zero trials across %d amp levels\n', nTrials, sum(nzMask));

% ---- Build full-session laser input vector -----------------------------------
u_full = zeros(nF_m, 1);
for j = 1:nTrials
    [~, ion] = min(abs(t_full - all_starts(j)));
    if ion >= 1 && ion <= nF_m
        u_full(ion) = all_amps(j);
    end
end
fprintf('[LDS-SETUP] u_full: %d stim events, amp range [%.2f %.2f]\n', ...
    sum(u_full>0), min(all_amps), max(all_amps));

% ---- Window geometry ---------------------------------------------------------
pre_fr   = round(pre_trial  * Fs);
post_fr  = round(post_trial * Fs);
spont_fr = round(spont_pre  * Fs);
t_driv   = (-pre_fr:post_fr) / Fs;
Ldriv    = numel(t_driv);
iDip     = find(t_driv >= 0   & t_driv <= 0.2);   % 0-200 ms dip window
iPre     = find(t_driv >= -0.2 & t_driv <  0);    % 200 ms pre-onset control

%% [LDS-SPONT] Spontaneous SS fit (autonomous, no input) ----------------------
% One iddata experiment per pre-trial window. No input channel.
% Identifies A_spont: the recurrence / timescales of spontaneous fluctuations.
fprintf('\n[LDS-SPONT] Building spontaneous iddata from pre-trial windows...\n');

y_sp_cell = cell(nTrials,1);
ok_sp     = false(nTrials,1);
for j = 1:nTrials
    [~, ion] = min(abs(t_full - all_starts(j)));
    i0 = ion - spont_fr;  i1 = ion - 1;
    if i0 < 1 || i1 > nF_m; continue; end
    blk = [Z_obs(i0:i1,:), y_dm(i0:i1)];      % [spont_fr x (nSV_lds+1)]
    blk = blk - mean(blk, 1, 'omitnan');        % per-window demean
    y_sp_cell{j} = blk;
    ok_sp(j)     = true;
end
good_sp = find(ok_sp);
fprintf('[LDS-SPONT] %d/%d windows usable\n', numel(good_sp), nTrials);

% Concatenate windows into ONE experiment. n4sid estimates a separate x0 per
% experiment, so 748 windows -> 748*n_states x0 unknowns -> linreg hangs.
% One record => one x0. Per-window demean (above) keeps join discontinuities small.
data_spont = iddata(cell2mat(y_sp_cell(good_sp)), [], 1/Fs);

fprintf('[LDS-SPONT] Fitting n4sid autonomous (n_states=%d)...\n', n_states);
% Bound the subspace horizon: default 'Auto' can pick a large horizon and
% allocate huge Hankel/QR intermediates on this long record -> OOM crash.
r_h    = max(20, 2*n_states);
opt_n4 = n4sidOptions('N4Horizon', [r_h r_h r_h]);
sys_spont = n4sid(data_spont, n_states, opt_n4);
A_spont   = sys_spont.A;

eig_sp  = eig(A_spont);
stab_sp = all(abs(eig_sp) < 1);
tau_sp  = sort(-1 ./ (Fs * real(log(eig_sp(abs(eig_sp)<1-1e-6)))), 'descend');
fprintf('[LDS-SPONT] Stable: %d | |eig| range [%.3f %.3f]\n', stab_sp, min(abs(eig_sp)), max(abs(eig_sp)));
fprintf('[LDS-SPONT] Dominant time constants (s): %s\n', sprintf('%.3f ', tau_sp(1:min(5,end))'));

%% [LDS-DRIVEN] Driven trial SS fit (with laser input) ------------------------
% One iddata experiment per trial window [-pre_trial, +post_trial] s.
% Input u = amplitude at the onset frame (pre_fr+1), 0 elsewhere.
% Output channels: [z_c_1..z_c_K, y_ipsi]  (K = nSV_lds, last = ipsi)
fprintf('\n[LDS-DRIVEN] Building driven trial iddata...\n');

y_dr_cell = cell(nTrials,1);
u_dr_cell = cell(nTrials,1);
ok_dr     = false(nTrials,1);
for j = 1:nTrials
    [~, ion] = min(abs(t_full - all_starts(j)));
    g = (ion - pre_fr) : (ion + post_fr);
    if g(1) < 1 || g(end) > nF_m; continue; end

    blk = [Z_obs(g,:), y_dm(g)];              % [Ldriv x (nSV_lds+1)]
    bl  = mean(blk(1:pre_fr,:), 1, 'omitnan');
    blk = blk - bl;                            % per-trial pre-stim baseline subtract

    u_tr = zeros(Ldriv, 1);
    u_tr(pre_fr+1) = all_amps(j);             % impulse at onset frame

    y_dr_cell{j} = blk;
    u_dr_cell{j} = u_tr;
    ok_dr(j)     = true;
end
good_dr = find(ok_dr);
nGd     = numel(good_dr);
fprintf('[LDS-DRIVEN] %d/%d trials usable\n', nGd, nTrials);

data_driv = iddata(y_dr_cell(good_dr), u_dr_cell(good_dr), 1/Fs);

% 80/20 train/test split (reproducible)
rng(42);
test_mask  = false(nGd,1);
test_mask(randperm(nGd, round(0.2*nGd))) = true;
train_idx  = find(~test_mask);
test_idx   = find( test_mask);
% Concatenate train windows into ONE experiment (same x0-blowup fix as spont).
% getexp(data_driv,...) would keep ~598 experiments -> linreg hangs.
data_train = iddata(cell2mat(y_dr_cell(good_dr(train_idx))), ...
                    cell2mat(u_dr_cell(good_dr(train_idx))), 1/Fs);
fprintf('[LDS-DRIVEN] Fitting n4sid driven (n_states=%d | train=%d test=%d)...\n', ...
    n_states, numel(train_idx), numel(test_idx));

if ~exist('opt_n4','var')   % allow running this section without LDS-SPONT first
    r_h = max(20, 2*n_states);
    opt_n4 = n4sidOptions('N4Horizon', [r_h r_h r_h]);
end
sys_evoked = n4sid(data_train, n_states, opt_n4);
A_evoked   = sys_evoked.A;     % [n_states x n_states]
B_evoked   = sys_evoked.B;     % [n_states x 1]
C_evoked   = sys_evoked.C;     % [(nSV_lds+1) x n_states]
D_evoked   = sys_evoked.D;     % [(nSV_lds+1) x 1]
K_evoked   = sys_evoked.K;     % [n_states x (nSV_lds+1)]

eig_ev  = eig(A_evoked);
stab_ev = all(abs(eig_ev) < 1);
tau_ev  = sort(-1 ./ (Fs * real(log(eig_ev(abs(eig_ev)<1-1e-6)))), 'descend');
fprintf('[LDS-DRIVEN] Stable: %d | |eig| range [%.3f %.3f]\n', stab_ev, min(abs(eig_ev)), max(abs(eig_ev)));
fprintf('[LDS-DRIVEN] Dominant time constants (s): %s\n', sprintf('%.3f ', tau_ev(1:min(5,end))'));
if ~stab_ev
    warning('[LDS-DRIVEN] A_evoked has unstable eigenvalues. Consider reducing n_states or using ssest with EnforceStability.');
end

% ---- Test-set open-loop dip R² (no Kalman; baseline for comparison) ---------
ypred_ol = []; yact_ol = [];
for k = test_idx'
    jj = good_dr(k);
    [~, ion] = min(abs(t_full - all_starts(jj)));
    g = (ion - pre_fr) : (ion + post_fr);
    if g(1) < 1 || g(end) > nF_m; continue; end
    blk  = [Z_obs(g,:), y_dm(g)];
    bl   = mean(blk(1:pre_fr,:),1,'omitnan');
    blk  = blk - bl;
    u_tr = zeros(Ldriv,1); u_tr(pre_fr+1) = all_amps(jj);
    x = zeros(n_states,1);
    y_ol = zeros(Ldriv,1);
    for t = 1:Ldriv
        y_ol(t) = C_evoked(end,:)*x + D_evoked(end)*u_tr(t);
        x = A_evoked*x + B_evoked*u_tr(t);    % no Kalman correction
    end
    ypred_ol = [ypred_ol; y_ol(iDip)'];
    yact_ol  = [yact_ol;  blk(iDip,end)'];
end
r2_ol = 1 - sum((yact_ol(:)-ypred_ol(:)).^2,'omitnan') / ...
              sum((yact_ol(:)-mean(yact_ol(:),'omitnan')).^2,'omitnan');
fprintf('[LDS-DRIVEN] Open-loop dip R² (test set, 0-200 ms): %.3f\n', r2_ol);

%% [LDS-OL] Open-loop impulse response vs trial average -----------------------
fprintf('\n[LDS-OL] Simulating open-loop impulse response...\n');
nOL  = round(3.5 * Fs);
u_ol = zeros(nOL,1); u_ol(pre_fr+1) = 1;   % unit amplitude
x = zeros(n_states,1);
y_ol_sim = zeros(nOL,1);
for t = 1:nOL
    y_ol_sim(t) = C_evoked(end,:)*x + D_evoked(end)*u_ol(t);
    x = A_evoked*x + B_evoked*u_ol(t);
end
t_ol = ((1:nOL) - (pre_fr+1)) / Fs;

% Empirical per-amplitude mean traces for overlay
mean_amp = mean(all_amps,'omitnan');
amp_list = uAmp(nzMask);
colors_ol = lines(numel(amp_list));
fig_ol = paperFig(10, 5);
ax_ol  = axes(fig_ol,'Position',[0.10 0.14 0.86 0.76]); hold(ax_ol,'on');
for ka = 1:numel(amp_list)
    aa   = amp_list(ka);
    mask_a = abs(all_amps - aa) < 1e-6;
    act_a  = nan(sum(mask_a), Ldriv);
    idx_a  = find(mask_a);
    for jx = 1:numel(idx_a)
        jj = idx_a(jx);
        [~, ion] = min(abs(t_full - all_starts(jj)));
        g = (ion-pre_fr):(ion+post_fr);
        if g(1)<1 || g(end)>nF_m; continue; end
        bl = mean(y_dm(ion-Fs:ion-1),'omitnan');
        act_a(jx,:) = (y_dm(g) - bl)';
    end
    mu_a = mean(act_a,1,'omitnan');
    plot(ax_ol, t_driv, mu_a, '-', 'Color', colors_ol(ka,:), 'LineWidth',1.0, ...
        'DisplayName', sprintf('Actual A=%.2f', aa));
end
plot(ax_ol, t_ol, y_ol_sim*mean_amp, 'k--', 'LineWidth',1.5, ...
    'DisplayName', sprintf('LDS OL (unit B, scaled \\times%.1f)', mean_amp));
xline(ax_ol,0,'k:','LineWidth',0.5,'HandleVisibility','off');
yline(ax_ol,0,'k--','LineWidth',0.4,'HandleVisibility','off');
hold(ax_ol,'off');
xlabel(ax_ol,'Time re onset (s)','FontSize',6,'FontWeight','bold');
ylabel(ax_ol,'\DeltaF/F (%)','FontSize',6,'FontWeight','bold');
legend(ax_ol,'Location','southeast','Box','off','FontSize',5,'NumColumns',2);
title(ax_ol, sprintf('LDS open-loop impulse response  |  %s %s e%d  |  n=%d states', ...
    mn, td, en, n_states), 'FontSize',6,'FontWeight','bold','Interpreter','none');
set(ax_ol,'Box','off','TickDir','out','FontSize',6,'FontWeight','bold');
paperExport(fig_ol, fullfile(paperRoot,'images','figure2','lds_ol_impulse.png'));
fprintf('[LDS-OL] Exported lds_ol_impulse.png\n');

%% [LDS-KF] Universal Kalman filter over full session (contra-only update) ----
% Predictor-form filter running over EVERY frame in the session.
% Contra channels feed the Kalman update; ipsi is never observed by the filter.
%
% K_c = K_evoked(:, 1:nSV_lds) is a partial Kalman gain — K was identified
% using all (nSV_lds+1) output channels but we drop the ipsi column at runtime
% so the filter never sees ipsi. This is slightly suboptimal vs re-solving the
% Riccati equation with ipsi removed, but avoids re-fitting and is adequate for
% the state-dependence test (the gain error is small when ipsi noise >> contra noise).
fprintf('\n[LDS-KF] Running universal Kalman predictor over full session (n=%d frames)...\n', nF_m);

C_c   = C_evoked(1:nSV_lds, :);    % [nSV_lds x n_states]   contra emission
c_y   = C_evoked(end, :)';          % [n_states x 1]          ipsi emission
D_c   = D_evoked(1:nSV_lds);        % [nSV_lds x 1]           contra feedthrough
d_y   = D_evoked(end);              % scalar                   ipsi feedthrough
K_c   = K_evoked(:, 1:nSV_lds);    % [n_states x nSV_lds]    partial Kalman gain

x_hat      = zeros(n_states, 1);    % state initialised at 0 (session start)
y_hat_full = zeros(nF_m, 1);

for t = 1:nF_m
    % One-step-ahead ipsi prediction (y_hat(t|t-1))
    y_hat_full(t) = c_y' * x_hat + d_y * u_full(t);

    % Contra innovation and state advance (ipsi never observed)
    innov_c = Z_obs(t,:)' - C_c*x_hat - D_c*u_full(t);
    x_hat   = A_evoked*x_hat + B_evoked*u_full(t) + K_c*innov_c;
end
fprintf('[LDS-KF] Filter complete.\n');

% ---- Extract per-trial predictions and evaluate ------------------------------
kf_act  = nan(nGd, Ldriv);
kf_pred = nan(nGd, Ldriv);
amp_gd  = nan(nGd, 1);

for k = 1:nGd
    jj = good_dr(k);
    [~, ion] = min(abs(t_full - all_starts(jj)));
    g = (ion - pre_fr) : (ion + post_fr);
    if g(1) < 1 || g(end) > nF_m; continue; end

    bl_idx = max(1, ion-Fs) : ion-1;          % 1 s pre-stim baseline (guard edge)
    if isempty(bl_idx); continue; end
    bl_a = mean(y_dm(bl_idx),       'omitnan');
    bl_p = mean(y_hat_full(bl_idx), 'omitnan');

    kf_act(k,:)  = (y_dm(g)       - bl_a)';
    kf_pred(k,:) = (y_hat_full(g) - bl_p)';
    amp_gd(k)    = all_amps(jj);
end

kf_res    = kf_act(:,iDip) - kf_pred(:,iDip);
r2_kf_dip = 1 - sum(kf_res(:).^2,'omitnan') / ...
                 sum((kf_act(:,iDip) - mean(kf_act(:,iDip),'omitnan')).^2,'omitnan');
fprintf('[LDS-KF] Universal-KF dip R² (0-200 ms, all trials): %.3f\n', r2_kf_dip);
fprintf('[LDS-KF] Open-loop baseline dip R²: %.3f  (KF gain: %+.3f)\n', r2_ol, r2_kf_dip-r2_ol);

% ---- Figure: KF mean prediction vs actual per amplitude ---------------------
ia_list = find(nzMask(:))';
nA = numel(ia_list);
fig_kf = paperFig(max(6, 5*nA), 8);
lm=0.07; rm=0.02; bm=0.12; tm=0.10; gx=0.03; gy=0.07;
pw = (1-lm-rm-(nA-1)*gx)/nA;
ph = (1-bm-tm-gy)/2;

for kk = 1:nA
    ia   = ia_list(kk);
    amp  = uAmp(ia);
    m_a  = abs(amp_gd - amp) < 1e-6;
    act_a = kf_act(m_a,:);  prd_a = kf_pred(m_a,:);  res_a = act_a - prd_a;
    nT_a  = sum(m_a);
    mu_a = mean(act_a,1,'omitnan'); se_a = std(act_a,0,1,'omitnan')/sqrt(max(nT_a,1));
    mu_p = mean(prd_a,1,'omitnan');
    mu_r = mean(res_a,1,'omitnan'); se_r = std(res_a,0,1,'omitnan')/sqrt(max(nT_a,1));
    xL   = lm + (kk-1)*(pw+gx);

    axT = axes(fig_kf,'Position',[xL, bm+ph+gy, pw, ph]); hold(axT,'on');
    patch(axT,[t_driv,fliplr(t_driv)],[mu_a+se_a,fliplr(mu_a-se_a)], ...
        [0.1 0.1 0.1],'FaceAlpha',0.15,'EdgeColor','none','HandleVisibility','off');
    plot(axT, t_driv, mu_a, 'k-',  'LineWidth',1.5, 'DisplayName','Actual');
    plot(axT, t_driv, mu_p, 'b--', 'LineWidth',1.2, 'DisplayName','KF pred (contra)');
    xline(axT,0,'k:','LineWidth',0.5,'HandleVisibility','off');
    yline(axT,0,'k--','LineWidth',0.4,'HandleVisibility','off');
    hold(axT,'off');
    title(axT, sprintf('A=%.2f  n=%d', amp, nT_a), 'FontSize',6,'FontWeight','bold');
    set(axT,'Box','off','TickDir','out','FontSize',6,'FontWeight','bold','XTickLabel',{});
    if kk==1
        ylabel(axT,'\DeltaF/F (%)','FontSize',6,'FontWeight','bold');
        legend(axT,'Location','southwest','Box','off','FontSize',5);
    end

    axB = axes(fig_kf,'Position',[xL, bm, pw, ph]); hold(axB,'on');
    patch(axB,[t_driv,fliplr(t_driv)],[mu_r+se_r,fliplr(mu_r-se_r)], ...
        [0.85 0.2 0.1],'FaceAlpha',0.15,'EdgeColor','none','HandleVisibility','off');
    plot(axB, t_driv, mu_r, 'Color',[0.85 0.2 0.1], 'LineWidth',1.5);
    xline(axB,0,'k:','LineWidth',0.5,'HandleVisibility','off');
    yline(axB,0,'k--','LineWidth',0.4,'HandleVisibility','off');
    hold(axB,'off');
    xlabel(axB,'Time re onset (s)','FontSize',6,'FontWeight','bold');
    if kk==1, ylabel(axB,'LDS-KF residual \DeltaF/F (%)','FontSize',6,'FontWeight','bold'); end
    set(axB,'Box','off','TickDir','out','FontSize',6,'FontWeight','bold');
end
sgtitle(fig_kf, sprintf('%s %s e%d  |  LDS universal KF  (n=%d states, contra-only, ipsi held-out)  KF dip R^2=%.3f', ...
    mn, td, en, n_states, r2_kf_dip), 'FontSize',6,'FontWeight','bold','Interpreter','none');
paperExport(fig_kf, fullfile(paperRoot,'images','figure2','lds_kf_pred.png'));
fprintf('[LDS-KF] Exported lds_kf_pred.png\n');

% ---- Save key outputs for LDS-STATE / LDS-EIG (next sections) ---------------
lds_cache = fullfile(dataDir, sprintf('lds_%s_%s%s_e%d_n%d.mat', ...
    mn, td(6:7), td(9:10), en, n_states));
save(lds_cache, 'A_spont','A_evoked','B_evoked','C_evoked','D_evoked','K_evoked', ...
    'tau_sp','tau_ev','eig_sp','eig_ev', ...
    'kf_act','kf_pred','amp_gd','t_driv','iDip','iPre', ...
    'y_hat_full','u_full','r2_kf_dip','r2_ol','n_states','nSV_lds','selExp');
fprintf('[LDS-KF] Outputs saved to %s\n', lds_cache);

fprintf('\n[contra_lds] Done.  %s %s e%d | n_states=%d | nSV_lds=%d\n', mn, td, en, n_states, nSV_lds);
fprintf('  A_spont tau1=%.3f s (stable=%d)  |  A_evoked tau1=%.3f s (stable=%d)\n', ...
    tau_sp(1), stab_sp, tau_ev(1), stab_ev);
fprintf('  OL dip R²=%.3f  |  Universal-KF dip R²=%.3f\n', r2_ol, r2_kf_dip);
fprintf('  --> Next: add LDS-STATE section (state-dep of KF residual)\n');
fprintf('  --> Then: LDS-EIG (eig comparison figure)\n');
