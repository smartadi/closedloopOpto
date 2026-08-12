% ctrl_subspace_id.m -- STAGE 5a: latent state-space model of the controller session
% by SUBSPACE IDENTIFICATION, with MULTIPLE CONTRA REGIONS as the measurement vector.
%
% WHY (user 2026-07-28)
%   Every controller result so far rests on a SISO loop: one ipsi pixel is measured, one
%   laser drives it. That readout is (a) low-dimensional -- it sees one projection of a
%   high-dimensional ongoing network state -- and (b) contaminated, because the laser acts
%   on the very pixel that closes the loop. The contra hemisphere is the complement: it
%   carries the disturbance state (Stage 1: spontaneous contra->ipsi held-out R^2 = 0.87)
%   and, restricted to the Stage-2 UNAFFECTED nodes, it is stim-blind. So contra regions
%   are a clean, multi-dimensional measurement of the thing the controller must reject.
%
% MODEL (discrete, Ts = 1/Fs, innovations form)
%       x(t+1) = A x(t) + B u(t) + K e(t)
%       y(t)   = C x(t) + D u(t) + e(t)
%   u = laser command amplitude (one-sided, 0 <= u <= u_max)
%   y = [ r contra POD channels (stim-blind, DISTURBANCE-driven) ; ipsi readout (REGULATED) ]
%   The last output row is the regulated variable z: data.dFk, the frame in which ref = -5 lives.
%
% WHY PREDICTION FOCUS, NOT SIMULATION FOCUS
%   The unaffected contra channels are by construction NOT driven by u. A pure simulation
%   fit (x0 = 0, u only) therefore predicts ~0 for them and would score R^2 ~ 0 -- correctly,
%   but uselessly. Their dynamics are stochastic (process noise), so the model must be
%   identified in innovations form and validated as a PREDICTOR. Two validations are run:
%     V1  k-step-ahead prediction of the regulated ipsi channel, using the contra
%         measurements -- this is what a multimodal observer would actually deliver, at the
%         horizon the real loop delay imposes (Stage 4a: ~86 ms ~ 3 samples).
%     V2  deterministic u->ipsi simulation, cross-checked against the Stage-4a SISO plant
%         (order, DC gain, settling). If the actuator path disagrees, the latent model is
%         not a superset of the plant we already trust.
%
% CLOSED-LOOP IDENTIFICATION BIAS
%   Identification uses OPEN-LOOP trials only. The OL command is a designed persistently
%   exciting step + dither, so (u,y) is an honest open-loop record. CL trials are held back
%   entirely and used only as an out-of-regime validation set: under feedback, u is
%   correlated with the noise and direct subspace ID is biased.
%
% PREREQS  load_sessions.m (mouse, fields); Stage 1 + Stage 2 caches for this session.
% NEXT     ctrl_gramians.m (5b: controllability/observability), ctrl_mimo_control.m (5c).
% SECTIONS [CFG] [LOAD] [REGIONS] [IO] [FIT] [VALIDATE] [FIG] [SAVE]

%% [CTRL-SID-CFG] ---------------------------------------------------------------
selField   = 4;          % session index into `fields`; 4 = m4 (AL_0033 2025-02-26)
nSV_load   = 500;
Fs         = 35;
px_set     = 'all';      % CONTRA PIXELS entering the observation space:
                         %  'all'        = every contra grid pixel (DEFAULT). Correct for the
                         %                 SPATIAL/observation question -- censoring the
                         %                 stim-affected midline cluster would delete real
                         %                 structure and bias every map.
                         %  'unaffected' = the Stage-2 stim-blind subset. Required ONLY for the
                         %                 residual work, where Global must be laser-blind for
                         %                 Local = Actual - Global to mean anything. (user 2026-07-29)
nPOD       = 8;          % # contra measurement channels (POD modes over the pixel set)
region_mode= 'pod';      % 'pod' = data-driven orthogonal channels (default, stim-blind basis)
                         % 'parcel' = spatial k-means on unaffected node coords (interpretable)
NXMAX      = 12;         % latent state orders to sweep
pre_id_s   = 2.0;        % pre-onset padding of each identification window (s)
post_id_s  = 2.0;        % post-trial-end padding (s)
trainFrac  = 0.7;        % OL trials: first 70% (in time) identify, last 30% validate
kPred      = 3;          % prediction horizon for V1 (samples). 3 @ 35 Hz = 86 ms = Stage-4a delay
ref_level  = -5;         % d.ref, the setpoint (%dF/F) -- carried through for Stage 5c
rng(7,'twister');

assert(exist('mouse','var') && exist('fields','var'), ...
    '[CTRL-SID] run controller-analysis/load_sessions.m first (need `mouse`,`fields`).');

here = fileparts(mfilename('fullpath'));
if isempty(here) || contains(here,tempdir,'IgnoreCase',true) || contains(here,'Editor_','IgnoreCase',true)
    here = fullfile(pwd,'controller-analysis');  if ~exist(here,'dir'); here = pwd; end
end
dataDir = fullfile(here,'data');
fig_dir = fullfile(here,'..','paper','images','predictor_saga');
if ~exist(fig_dir,'dir'); mkdir(fig_dir); end

%% [CTRL-SID-LOAD] session + Stage 1/2 caches + SVD ------------------------------
fld  = fields{selField};
d_s  = mouse.(fld).d;   data = mouse.(fld).data;
mn = mouse.(fld).mn;  td = mouse.(fld).td;  en = mouse.(fld).en;
sess_tag = sprintf('%s_%s%s_e%d', mn, td(6:7), td(9:10), en);

s1_file = fullfile(dataDir, sprintf('ctrl_ols_spont_%s.mat', sess_tag));
s2_file = fullfile(dataDir, sprintf('ctrl_ols_ol_stimblind%s_%s.mat', ctrl_pred_tag(), sess_tag));
assert(exist(s1_file,'file')>0, '[CTRL-SID] Stage 1 cache missing: %s', s1_file);
assert(exist(s2_file,'file')>0, '[CTRL-SID] Stage 2 cache missing: %s', s2_file);
S1 = load(s1_file);  S2 = load(s2_file);

gridIdx = S1.gridIdx;  grR = S1.grR;  grC = S1.grC;  nG = S1.nG;
px_prim = S1.px_prim;  py_prim = S1.py_prim;
frames  = S1.frames;   itr = S1.itr;  w_warm = S1.w_warm;  dur = S1.trial_dur;
affected = logical(S2.affected(:));  unaff = logical(S2.unaff(:));
switch lower(px_set)
    case 'all',        Su = (1:nG).';        % every contra grid pixel
    case 'unaffected', Su = S2.Su(:);        % Stage-2 stim-blind subset
    otherwise, error('[CTRL-SID] unknown px_set ''%s''.', px_set);
end
aff_in = affected(Su);                       % which of the analysed pixels are stim-affected
fprintf('\n[CTRL-SID] %s | site [row %d col %d] | %d grid px | px_set=''%s'' -> %d px (%d stim-affected)\n', ...
    sess_tag, px_prim, py_prim, nG, px_set, numel(Su), nnz(aff_in));

serverRoot = expPath(mn, td, en);
[U_cp, V_cp, t_svd, mimg_cp] = loadUVt(serverRoot, nSV_load);
V_cp = double(V_cp);
[nY_cp, nX_cp] = size(mimg_cp);  nSV_cp = size(U_cp,3);
Uflat  = reshape(U_cp, nY_cp*nX_cp, nSV_cp);
t_full = t_svd(:);  nF_m = min(size(V_cp,2), numel(t_full));

Xg_full = double(Uflat(gridIdx,:)) * V_cp;            % [nG x T] contra grid, dF reconstruction
mIg     = max(mimg_cp(gridIdx), eps);
Xpct    = (Xg_full ./ mIg) * 100;                     % [nG x T] in %dF/F

ztrace = data.dFk(:);                                 % REGULATED output, canonical ref=-5 frame
assert(numel(ztrace) >= nF_m, '[CTRL-SID] data.dFk (%d) shorter than SVD frames (%d).', ...
    numel(ztrace), nF_m);

%% [CTRL-SID-REGIONS] contra measurement channels --------------------------------
% Basis is built on SPONTANEOUS TRAIN frames only, so the measurement definition never
% sees a stim trial -- the channels stay stim-blind by construction, not by assertion.
spTr = frames(itr);  spTr = spTr(spTr <= nF_m);
Xu   = Xpct(Su, :);                                   % [p x T] the analysed contra pixel set
mu_c = mean(Xu(:,spTr), 2);
sd_c = std(Xu(:,spTr), 0, 2);  sd_c(sd_c == 0) = 1;
Zu   = (Xu - mu_c) ./ sd_c;                           % z-scored per node (no bright-node dominance)

switch lower(region_mode)
    case 'pod'
        [~, Sv, Wv] = svd(Zu(:,spTr).', 'econ');      % [T x p] -> right singular vectors = spatial modes
        Wmix   = Wv(:, 1:nPOD);                       % [p x r] node -> channel mixing
        pod_ev = diag(Sv).^2;  pod_ev = pod_ev / sum(pod_ev);
        fprintf('[CTRL-SID] POD channels: %d modes capture %.1f%% of spontaneous contra variance\n', ...
            nPOD, 100*sum(pod_ev(1:nPOD)));
    case 'parcel'
        cc = [grR(Su(:)), grC(Su(:))];
        lab = kmeans(double(cc), nPOD, 'Replicates', 10);
        Wmix = zeros(numel(Su), nPOD);
        for q = 1:nPOD, Wmix(lab == q, q) = 1/nnz(lab == q); end   % parcel mean
        pod_ev = [];
        fprintf('[CTRL-SID] parcel channels: %d spatial k-means regions (sizes %s)\n', ...
            nPOD, mat2str(accumarray(lab,1).'));
    otherwise
        error('[CTRL-SID] unknown region_mode ''%s''.', region_mode);
end
Ychan = (Zu.' * Wmix);                                % [T x r] contra measurement channels

%% [CTRL-SID-IO] input, output matrix, trial windows -----------------------------
% TRUE input = sine-carrier AMPLITUDE at the NATIVE rate (at 35 Hz the 50 Hz carrier
% aliases into a fake dither) -- same extraction Stage 4a uses.
[uAmpFull, uinfo] = cp_laser_amplitude(d_s.inpVals, d_s.inpTime);
u_full = interp1(d_s.inpTime, uAmpFull, t_full, 'linear', 0);
fprintf('[CTRL-SID] laser mode = %s (carrier %.1f Hz) | u range [%.3f %.3f]\n', ...
    uinfo.mode, uinfo.carrier_hz, min(u_full), max(u_full));

Yall = [Ychan, ztrace(1:size(Ychan,1))];              % [T x (r+1)], last column = regulated ipsi
nOut = size(Yall,2);  iZ = nOut;                      % index of the regulated channel

% window bounds (identical grid for every trial)
preN  = round(pre_id_s*Fs);  postN = round(dur*Fs) + round(post_id_s*Fs);
relW  = -preN:postN;

onset_frames = @(tt) arrayfun(@(s) local_nearest(t_full, s), tt(:));
ol_on = onset_frames(sort(d_s.stimStarts(data.nc(:))));
cl_on = [];
if isfield(data,'wc'), cl_on = onset_frames(sort(d_s.stimStarts(data.wc(:)))); end
keep  = @(f) f(f > max(preN, w_warm) & f + postN <= nF_m);
ol_on = keep(ol_on);  cl_on = keep(cl_on);
nOL = numel(ol_on);  nCL = numel(cl_on);
assert(nOL >= 6, '[CTRL-SID] only %d usable OL trials -- too few to identify.', nOL);

% output scaling: identify in unit-variance outputs (mixed %dF and z-units otherwise
% mis-weights the cost). Scale/offset are stored so Stage 5b/5c can return to %dF/F.
segAll  = cell2mat(arrayfun(@(f) (f+relW).', [ol_on; cl_on].', 'UniformOutput', false));
yoffset = mean(Yall(segAll(:), :), 1);
yscale  = std(Yall(segAll(:), :), 0, 1);  yscale(yscale == 0) = 1;
fprintf('[CTRL-SID] regulated channel: mean %.2f %%dF/F, sd %.2f %%dF/F (ref = %.1f)\n', ...
    yoffset(iZ), yscale(iZ), ref_level);

mkexp = @(f) iddata((Yall(f+relW, :) - yoffset) ./ yscale, u_full(f+relW), 1/Fs);
nTrain = max(3, round(trainFrac*nOL));
zTrain = local_merge(arrayfun(mkexp, ol_on(1:nTrain),     'UniformOutput', false));
zTest  = local_merge(arrayfun(mkexp, ol_on(nTrain+1:end), 'UniformOutput', false));
zCL    = [];
if nCL > 0, zCL = local_merge(arrayfun(mkexp, cl_on, 'UniformOutput', false)); end
fprintf('[CTRL-SID] OL trials: %d identify / %d validate | CL held out: %d | %d samples/trial\n', ...
    nTrain, nOL-nTrain, nCL, numel(relW));

% input delay, estimated on the regulated channel alone (SISO, as in Stage 4a)
zSISO = local_merge(arrayfun(@(f) iddata((Yall(f+relW,iZ)-yoffset(iZ))/yscale(iZ), ...
    u_full(f+relW), 1/Fs), ol_on(1:nTrain), 'UniformOutput', false));
nk = delayest(zSISO, 2, 2, 0, 20);
fprintf('[CTRL-SID] estimated input delay = %d samples (%.3f s)\n', nk, nk/Fs);

%% [CTRL-SID-FIT] subspace identification, order sweep ---------------------------
% n4sid in innovations form (default prediction focus). Order chosen by held-out k-step
% prediction of the REGULATED channel -- the quantity Stage 5c actually needs -- with AICc
% printed alongside as a parsimony cross-check.
opt = n4sidOptions('N4Weight','auto','Focus','prediction','EnforceStability',true);
best = struct('score', -inf);  rows = cell(NXMAX,1);
for nx = 1:NXMAX
    try
        m = n4sid(zTrain, nx, 'Ts', 1/Fs, 'InputDelay', nk, 'DisturbanceModel','estimate', opt);
    catch ME
        rows{nx} = sprintf('  nx=%2d  FAILED (%s)', nx, ME.message);  continue;
    end
    r2te = local_predR2(m, zTest, kPred);              % per-channel held-out k-step R^2
    aicc = local_aicc(m);
    rows{nx} = sprintf('  nx=%2d  R^2_z(%d-step)=%6.3f  mean R^2_contra=%6.3f  AICc=%9.1f  max|pole|=%.3f', ...
        nx, kPred, r2te(iZ), mean(r2te(1:iZ-1)), aicc, max(abs(pole(m))));
    if r2te(iZ) > best.score
        best = struct('score', r2te(iZ), 'nx', nx, 'm', m, 'r2te', r2te, 'aicc', aicc);
    end
end
rows = rows(~cellfun(@isempty, rows));
fprintf('[CTRL-SID] order sweep (held-out OL, %d-step prediction of the regulated channel):\n%s\n', ...
    kPred, strjoin(rows, newline));
m = best.m;  nx = best.nx;
fprintf('[CTRL-SID] SELECTED nx=%d | held-out R^2_z=%.3f | AICc=%.1f\n', nx, best.score, best.aicc);

%% [CTRL-SID-VALIDATE] --------------------------------------------------------
[A,B,C,D,K] = idssdata(m);

% V0  STIM DRIVE ON THE CONTRA CHANNELS. Under px_set='unaffected' this is a LEAK CHECK
%     (contra gain should be << regulated, or the stim-blind selection leaked). Under
%     px_set='all' it is not a check but a MEASUREMENT: the affected midline pixels are in
%     the channels on purpose, so real stim drive here is expected and informative -- it is
%     the SNC distributed co-suppression showing up in the observation space.
dc = dcgain(ss(A,B,C,D,1/Fs));
if strcmpi(px_set,'unaffected'), tagV0 = 'want << regulated'; else, tagV0 = 'stim drive expected'; end
fprintf('[CTRL-SID-V0] |DC gain| regulated = %.3f | contra channels: max %.3f, median %.3f (%s)\n', ...
    abs(dc(iZ)), max(abs(dc(1:iZ-1))), median(abs(dc(1:iZ-1))), tagV0);

% V1  held-out k-step prediction, and the ablation that answers the user's question:
%     does seeing CONTRA improve prediction of the ipsi readout over an ipsi-only model?
r2_full = local_predR2(m, zTest, kPred);
mZ  = n4sid(zSISO, nx, 'Ts', 1/Fs, 'InputDelay', nk, 'DisturbanceModel','estimate', opt);
zTestZ = local_merge(arrayfun(@(f) iddata((Yall(f+relW,iZ)-yoffset(iZ))/yscale(iZ), ...
    u_full(f+relW), 1/Fs), ol_on(nTrain+1:end), 'UniformOutput', false));
r2_ipsi = local_predR2(mZ, zTestZ, kPred);
fprintf('[CTRL-SID-V1] %d-step prediction of ipsi, held-out OL:  contra-informed R^2 = %.3f  vs  ipsi-only R^2 = %.3f  (gain %+.3f)\n', ...
    kPred, r2_full(iZ), r2_ipsi(1), r2_full(iZ) - r2_ipsi(1));

% V1b same comparison on the CL trials (out-of-regime: never used for identification)
r2_cl = NaN;  r2_cl_ipsi = NaN;
if ~isempty(zCL)
    zCLz = local_merge(arrayfun(@(f) iddata((Yall(f+relW,iZ)-yoffset(iZ))/yscale(iZ), ...
        u_full(f+relW), 1/Fs), cl_on, 'UniformOutput', false));
    rc = local_predR2(m, zCL, kPred);  r2_cl = rc(iZ);
    rz = local_predR2(mZ, zCLz, kPred); r2_cl_ipsi = rz(1);
    fprintf('[CTRL-SID-V1b] same on CL trials (out of regime): contra-informed %.3f vs ipsi-only %.3f\n', ...
        r2_cl, r2_cl_ipsi);
end

% V2  deterministic actuator path vs the Stage-4a SISO plant
lti_file = fullfile(dataDir, sprintf('ctrl_lti_%s.mat', sess_tag));
sysZ = ss(A, B, C(iZ,:), D(iZ), 1/Fs);                 % u -> regulated channel (normalized units)
dcZ_pct = dcgain(sysZ) * yscale(iZ);                   % back to %dF/F per unit u
if exist(lti_file,'file')
    L4 = load(lti_file);
    fprintf('[CTRL-SID-V2] actuator path: latent DC gain %.3f %%dF/u (nx=%d) vs Stage-4a SISO %.3f (nx=%d)\n', ...
        dcZ_pct, nx, L4.dcgain, L4.nx);
else
    fprintf('[CTRL-SID-V2] actuator path: latent DC gain %.3f %%dF/u (no Stage-4a cache to compare)\n', dcZ_pct);
end

%% [CTRL-SID-BFIT] repair the input path: refit (B,D) by SIMULATION -------------
% n4sid ran in prediction focus, so the Kalman path K absorbed most of the step response
% and B came out 2.6x too weak vs the trusted Stage-4a plant (RESEARCH 2026-07-28). A and C
% (the DYNAMICS and the observation geometry) are what subspace ID is good at and are kept;
% only the input path is re-solved, by least squares, so the model REPRODUCES the measured
% OL trial-averaged response. With A,C fixed the map (B,D) -> simulated output is LINEAR:
%     x(t) = S(t) B,   S(t+1) = A S(t) + I*u_d(t),   y(t) = C S(t) B + D u_d(t)
% so this is an exact LS solve, not an iterative fit. u_d = u delayed by nk (the delay is
% kept OUT of the state so the modal table shows real dynamics, not nk poles at the origin).
Ybar = zeros(numel(relW), nOut);  ubar = zeros(numel(relW), 1);
for j = 1:numel(ol_on)
    Ybar = Ybar + (Yall(ol_on(j)+relW,:) - yoffset)./yscale;
    ubar = ubar + u_full(ol_on(j)+relW);
end
Ybar = Ybar/numel(ol_on);  ubar = ubar/numel(ol_on);
Ybar = Ybar - mean(Ybar(1:preN,:), 1);                 % start from rest
ubar = ubar - mean(ubar(1:preN));
u_d  = [zeros(nk,1); ubar(1:end-nk)];                  % input delay, applied explicitly

nT = numel(relW);  Sx = zeros(nx, nx);
Phi = zeros(nT*nOut, nx + nOut);  rhs = zeros(nT*nOut, 1);
for t = 1:nT
    ridx = (t-1)*nOut + (1:nOut);                      % NOT `rows` -- that is the sweep cell array
    Phi(ridx, 1:nx)     = C * Sx;                      % dY/dB
    Phi(ridx, nx+1:end) = eye(nOut) * u_d(t);          % dY/dD
    rhs(ridx)           = Ybar(t,:).';
    Sx = A*Sx + eye(nx)*u_d(t);                        % propagate AFTER using it
end
lamB  = 1e-6 * trace(Phi.'*Phi)/size(Phi,2);
theta = (Phi.'*Phi + lamB*eye(nx+nOut)) \ (Phi.'*rhs);
B_pred = B;  D_pred = D;                               % keep the prediction-focus versions
B = theta(1:nx);  D = theta(nx+1:end);
simFit = 1 - norm(rhs - Phi*theta)/max(norm(rhs - mean(rhs)), eps);
dcZ_new = dcgain(ss(A,B,C(iZ,:),D(iZ),1/Fs)) * yscale(iZ);
fprintf('[CTRL-SID-BFIT] input path re-solved: sim fit %.1f%% | ipsi DC gain %.3f -> %.3f %%dF/u\n', ...
    100*simFit, dcgain(ss(A,B_pred,C(iZ,:),D_pred(iZ),1/Fs))*yscale(iZ), dcZ_new);
if exist('L4','var')
    fprintf('[CTRL-SID-BFIT] Stage-4a SISO reference = %.3f %%dF/u  (ratio %.2f)\n', ...
        L4.dcgain, dcZ_new/L4.dcgain);
end
% contra stim drive, re-measured on the REPAIRED input path
dcB = dcgain(ss(A,B,C,D,1/Fs));
fprintf('[CTRL-SID-BFIT] contra stim drive (repaired B): |DC| regulated %.3f | contra max %.3f, median %.3f\n', ...
    abs(dcB(iZ)), max(abs(dcB(1:iZ-1))), median(abs(dcB(1:iZ-1))));

%% [CTRL-SID-PATTERN] forward pattern of the Stage-2 predictor -------------------
% The Stage-2 weights `b` are a FILTER over 249 correlated pixels; plotting them as a
% spatial map is the Haufe et al. 2014 error. Convert to the forward pattern here, and
% report how far apart the two are -- rho well below 1 means the filter was never safe
% to plot. (RESEARCH 2026-07-28 method-bug entry.)
% The FILTER exists only on the pixels the Stage-2 model was fit on (its stim-blind subset).
% The PATTERN is cov(x_j, yhat), which is defined for EVERY pixel -- so the pattern map
% covers the full analysed set even when the predictor did not.
[~, pinfo] = cp_weight_pattern(Xg_full(S2.Su,:), S2.b, S2.mu, S2.sd, S2.muY);
patt = cp_weight_pattern(Xg_full(Su,:), [], [], [], [], pinfo.yhat);
filt = S2.b(:);
[tf_, filt_loc] = ismember(S2.Su(:), Su);              % where the filter's pixels sit in Su
ok = tf_ & filt_loc > 0;
rho_ab = corr(filt(ok), patt(filt_loc(ok)));
nflip  = nnz(sign(filt(ok)) ~= sign(patt(filt_loc(ok))));
fprintf('[CTRL-SID-PATTERN] pattern over %d px | filter defined on %d px (Stage-2 stim-blind subset)\n', ...
    numel(Su), nnz(ok));
fprintf('[CTRL-SID-PATTERN] filter-vs-pattern corr = %+.3f (1.0 would mean the filter was safe to plot); sign disagreements %d/%d (%.0f%%)\n', ...
    rho_ab, nflip, nnz(ok), 100*nflip/max(nnz(ok),1));

%% [CTRL-SID-FIG] ---------------------------------------------------------------
figS = figure('Color','w','Position',[50 50 1400 780]);
tl = tiledlayout(figS, 2, 3, 'TileSpacing','compact','Padding','compact');
tt = relW/Fs;

nexttile(tl,1);                                        % order sweep
sw      = arrayfun(@(q) local_sweeppat(rows{q}, 'nx=\s*(\d+)'), 1:numel(rows));
sweepR2 = arrayfun(@(q) local_sweeppat(rows{q}, 'R\^2_z\(\d+-step\)=\s*(-?\d+\.\d+)'), 1:numel(rows));
plot(sw, sweepR2, 'o-', 'Color',[0.1 0.4 0.8], 'LineWidth',1.4, 'MarkerFaceColor','w'); hold on;
plot(nx, best.score, 'p', 'MarkerSize',13, 'MarkerFaceColor',[0.9 0.5 0.1], 'MarkerEdgeColor','k');
xlabel('latent order n_x'); ylabel(sprintf('held-out R^2 (%d-step, ipsi)',kPred)); grid on;
title(sprintf('order selection -> n_x = %d', nx));

nexttile(tl,2);                                        % contra-informed vs ipsi-only
bar([r2_full(iZ) r2_ipsi(1); r2_cl r2_cl_ipsi]);
set(gca,'XTickLabel',{'held-out OL','CL (out of regime)'});
ylabel(sprintf('R^2, %d-step ipsi prediction',kPred)); ylim([0 1]); grid on;
legend({'contra-informed (multimodal)','ipsi-only (SISO-equivalent)'},'Box','off','Location','southwest');
title('does seeing contra help?');

nexttile(tl,3);                                        % POD spectrum / channel map
if strcmpi(region_mode,'pod')
    plot(cumsum(pod_ev(1:min(30,numel(pod_ev))))*100, 'k.-','LineWidth',1.2); hold on;
    xline(nPOD,'r--','LineWidth',1.2);
    xlabel('POD mode'); ylabel('cumulative % variance'); grid on; ylim([0 100]);
    title(sprintf('contra POD: %d channels = %.0f%%', nPOD, 100*sum(pod_ev(1:nPOD))));
else
    scatter(grC(Su), grR(Su), 18, Wmix*(1:nPOD).', 'filled'); axis image ij;
    title('contra parcels');
end

nexttile(tl,4);                                        % pole map
th = linspace(0,2*pi,200);
plot(cos(th), sin(th), 'k:'); hold on; axis equal;
pl = pole(m);
scatter(real(pl), imag(pl), 46, [0.85 0.3 0.1], 'filled');
xlabel('Re'); ylabel('Im'); grid on;
title(sprintf('latent poles (n_x=%d), \\tau_{max}=%.2f s', nx, -1/(Fs*log(max(abs(pl))+eps))));

nexttile(tl, 5, [1 2]);                                % example held-out trial, measured vs predicted
yp = predict(m, zTest, kPred);
ex = 1;  ymeas = zTest.y{ex}(:,iZ)*yscale(iZ) + yoffset(iZ);
ypre = yp.y{ex}(:,iZ)*yscale(iZ) + yoffset(iZ);
plot(tt, ymeas, 'k-', 'LineWidth',1.6); hold on;
plot(tt, ypre, '-', 'Color',[0.85 0.3 0.1], 'LineWidth',1.4);
yyaxis right; plot(tt, zTest.u{ex}, '-', 'Color',[0.3 0.5 0.85], 'LineWidth',1.0);
set(gca,'YColor',[0.3 0.5 0.85]); ylabel('u (laser)');
yyaxis left; xline(0,'k:'); yline(ref_level,'k--');
xlabel('time from stim (s)'); ylabel('ipsi \DeltaF/F (%)'); xlim([tt(1) tt(end)]);
legend({'measured', sprintf('%d-step prediction (contra-informed)',kPred), 'u'}, ...
    'Box','off','Location','southeast','FontSize',8);
title('held-out OL trial 1: regulated channel');

sgtitle(figS, sprintf('[CTRL-SID] Stage 5a latent subspace ID  %s  |  %d contra channels + ipsi, n_x=%d', ...
    strrep(sess_tag,'_','\_'), nPOD, nx));
fig_png = fullfile(fig_dir, sprintf('ctrl_subspace_id_%s.png', sess_tag));
exportgraphics(figS, fig_png, 'Resolution', 300);
fprintf('[CTRL-SID-FIG] -> %s\n', fig_png);

%% [CTRL-SID-SAVE] --------------------------------------------------------------
SID = struct();
SID.sess_tag=sess_tag; SID.selField=selField; SID.Fs=Fs; SID.Ts=1/Fs; SID.ref_level=ref_level;
SID.A=A; SID.B=B; SID.C=C; SID.D=D; SID.K=K; SID.nx=nx; SID.nk=nk;
SID.nOut=nOut; SID.iZ=iZ; SID.nPOD=nPOD; SID.region_mode=region_mode;
SID.yscale=yscale; SID.yoffset=yoffset;         % y_physical = y_model .* yscale + yoffset
SID.Wmix=Wmix; SID.Su=Su; SID.mu_c=mu_c; SID.sd_c=sd_c; SID.gridIdx=gridIdx;
SID.grR=grR; SID.grC=grC; SID.px_prim=px_prim; SID.py_prim=py_prim;
SID.relW=relW; SID.preN=preN; SID.postN=postN; SID.dur=dur;
SID.ol_on=ol_on; SID.cl_on=cl_on; SID.nTrain=nTrain; SID.kPred=kPred;
SID.r2_full=r2_full; SID.r2_ipsi=r2_ipsi; SID.r2_cl=r2_cl; SID.r2_cl_ipsi=r2_cl_ipsi;
SID.dcZ_pct=dcZ_pct; SID.uinfo=uinfo; SID.uMaxHW=max(uAmpFull);
SID.sweep=rows;
% repaired input path (use B/D above; B_pred/D_pred kept for the record)
SID.B_pred=B_pred; SID.D_pred=D_pred; SID.simFit=simFit; SID.dcZ_new=dcZ_new;
SID.NoiseVariance=m.NoiseVariance;             % innovations covariance, for the modal H2 split
SID.Ybar=Ybar; SID.ubar=ubar; SID.u_d=u_d;     % OL trial-averaged response (all channels)
% Stage-2 predictor: filter vs forward pattern (Haufe), for the spatial maps
SID.patt=patt; SID.filt=filt; SID.rho_ab=rho_ab; SID.filt_loc=filt_loc; SID.filt_ok=ok;
SID.px_set=px_set; SID.affected=affected; SID.unaff=unaff; SID.aff_in=aff_in;
SID.mimg=mimg_cp;                              % brain background for spatial rendering
SID.mIg=mIg;
sid_file = fullfile(dataDir, sprintf('ctrl_subspace_id_%s.mat', sess_tag));
save(sid_file, '-struct', 'SID', '-v7.3');
fprintf('[CTRL-SID-SAVE] -> %s\n\n', sid_file);

%% ---- helpers -----------------------------------------------------------------
function f = local_nearest(t, s)
[~, f] = min(abs(t - s));
end

function z = local_merge(cells)
% merge a cell array of single-experiment iddata into one multi-experiment iddata
z = cells{1};
for q = 2:numel(cells), z = merge(z, cells{q}); end
end

function r2 = local_predR2(m, z, k)
% per-channel R^2 of the k-step-ahead predictor, pooled over experiments
yp = predict(m, z, k);
Y  = local_cat(z.y);  P = local_cat(yp.y);
r2 = 1 - sum((Y-P).^2, 1) ./ max(sum((Y - mean(Y,1)).^2, 1), eps);
end

function M = local_cat(y)
if iscell(y), M = cat(1, y{:}); else, M = y; end
end

function a = local_aicc(m)
try
    a = m.Report.Fit.AICc;
catch
    a = NaN;
end
end

function v = local_sweeppat(s, pat)
t = regexp(s, pat, 'tokens', 'once');
if isempty(t), v = NaN; else, v = str2double(t{1}); end
end
