% ctrl_optimal_control.m -- STAGE 4b: best-possible (constrained-optimal) control vs the PI controller.
%
% GOAL (user Objective 2)
%   "What would happen if an OPTIMAL controller were applied instead of the PI-generated signal?"
%
% FRAMING (user, 2026-07-20)
%   The Stage-4a LTI plant G captures the actuator dynamics (drop, gain, settling) but NOT the slow
%   adaptation that makes y drift back under a constant step. We deliberately do NOT fold that into
%   the plant: the adaptation -- like the ongoing network state -- is a DISTURBANCE the controller is
%   there to fight. That is the honest framing and it makes the comparison fair:
%
%       y(t) = G*u(t) + d(t)          d = adaptation drift + ongoing state + model mismatch
%
%   d is MEASURED from the very trials the PI controller ran:  d = y_PI - G*u_PI.  The optimal
%   controller then faces the SAME plant, the SAME disturbance realization and the SAME actuator
%   ceiling as the PI controller did -- the only difference is the command.
%
% METHOD
%   1. Rebuild the discrete plant (absorbDelay so the 86 ms input delay lives in the states) and its
%      Markov/Toeplitz convolution matrix H, so  y = H*u  from rest. Verified against sim().
%   2. Recover the disturbance d over [0,dur] from the CL trial average: d = y_PI - H*u_PI.
%   3. NON-CAUSAL optimum (the true "best possible"): a clairvoyant controller that knows all of d,
%         min_u ||H*u + d - r||^2 + lam*||u||^2   s.t.  0 <= u <= u_max     (bound-constrained QP)
%   4. CAUSAL optimum (realistically achievable): receding-horizon MPC that only knows d up to the
%      current sample and predicts it as constant (standard output-disturbance model).
%   5. Compare y_PI vs y_opt(non-causal) vs y_opt(causal) against the reference, and the commands.
%
%   The one-sided actuator (0 <= u) matters: the laser can only INHIBIT, never excite, so the
%   controller cannot push y back up -- it can only stop pushing down. That constraint is why this
%   is a QP and not a plain least-squares solve.
%
% PREREQS  Stage 3 cache (CL decomposition) + Stage 4a cache (LTI plant) for this session.
% SECTIONS: [CFG] [LOAD] [PLANT] [DISTURBANCE] [OPT-NONCAUSAL] [OPT-CAUSAL] [METRICS] [FIG] [SAVE]

%% [CTRL-OPT-CFG] ---------------------------------------------------------------
selField  = 4;
Fs        = 35;
ref_level = -5;          % d.ref, the controller's setpoint (%dF/F)
lam       = 1e-4;        % tiny input regularization (conditioning only; ~0 tracking effect)
Hp        = 35;          % causal MPC prediction horizon (samples, 1 s)
uMaxMode  = 'CL';        % 'CL' = PI's own usage ceiling (fair same-budget) | 'HW' = hardware max
rng(7,'twister');

here = fileparts(mfilename('fullpath'));
if isempty(here) || contains(here,tempdir,'IgnoreCase',true) || contains(here,'Editor_','IgnoreCase',true)
    here = fullfile(pwd,'controller-analysis'); if ~exist(here,'dir'); here = pwd; end
end
dataDir = fullfile(here,'data');
fig_dir = fullfile(here,'..','paper','images','figure4'); if ~exist(fig_dir,'dir'); mkdir(fig_dir); end

%% [CTRL-OPT-LOAD] --------------------------------------------------------------
sess_tag = 'AL_0033_0226_e2';
if exist('mouse','var') && exist('fields','var') && numel(fields)>=selField
    fld=fields{selField};
    sess_tag=sprintf('%s_%s%s_e%d', mouse.(fld).mn, mouse.(fld).td(6:7), mouse.(fld).td(9:10), mouse.(fld).en);
end
S3 = load(fullfile(dataDir, sprintf('ctrl_ols_cl_deploy_%s.mat', sess_tag)));   % CL decomposition
L  = load(fullfile(dataDir, sprintf('ctrl_lti_%s.mat', sess_tag)));             % Stage 4a plant
pre = S3.pre;  dur = S3.dur;  N = round(dur*Fs);                                % horizon = [0,dur]
switch upper(uMaxMode)
    case 'CL', u_max = L.uMaxCL;   case 'HW', u_max = L.uMaxHW;
    otherwise, error('[CTRL-OPT] bad uMaxMode');
end
% post-onset slices. Use ABSOLUTE dF/F: the controller regulates the absolute signal to ref, so
% comparing a baseline-subtracted y against an absolute ref would bias the error by the pre-onset
% offset. d (measured below) absorbs that offset automatically.
y_PI = S3.AaAbs(pre+1:pre+N).';                    % PI-controlled ipsi (absolute trial avg)
u_PI = L.u_CL(pre+1:pre+N);                        % PI's own laser command (amplitude units)
r    = ref_level*ones(N,1);                        % setpoint
tt   = (1:N).'/Fs;
fprintf('[CTRL-OPT] %s | horizon %d samp (%.1fs) | u_max(%s)=%.3f | PI u: mean=%.3f max=%.3f\n', ...
    sess_tag, N, dur, uMaxMode, u_max, mean(u_PI), max(u_PI));

%% [CTRL-OPT-PLANT] discrete plant + convolution matrix -------------------------
md = ss(L.A, L.B, L.C, L.D, L.Ts);  md.InputDelay = L.nk;  md = absorbDelay(md);
[A,B,C,D] = ssdata(md);
h = zeros(N,1); h(1) = D;                          % Markov parameters h_0..h_{N-1}
Ak = eye(size(A));
for k = 2:N, h(k) = C*Ak*B;  Ak = Ak*A; end
H = tril(toeplitz(h));                             % y = H*u  (from rest)
% sanity: convolution matrix must reproduce sim() on the OL step
u_chk = L.u_OL(pre+1:pre+N);  y_chk = lsim(md, u_chk, tt-tt(1));
fprintf('[CTRL-OPT] plant check: max|H*u - lsim(u)| = %.3g (should be ~0)\n', max(abs(H*u_chk - y_chk(:))));

%% [CTRL-OPT-DISTURBANCE] what the PI controller was actually fighting ----------
d = y_PI - H*u_PI;                                 % adaptation + ongoing state + mismatch
fprintf('[CTRL-OPT] disturbance d: mean=%.2f%%  range [%.2f, %.2f]  (end-start drift %.2f%%)\n', ...
    mean(d), min(d), max(d), d(end)-d(1));

%% [CTRL-OPT-NONCAUSAL] clairvoyant best-possible ------------------------------
Qq = 2*(H.'*H + lam*eye(N));  Qq = (Qq+Qq.')/2;
fq = 2*H.'*(d - r);
qopt = optimoptions('quadprog','Display','off');
u_nc = quadprog(Qq, fq, [],[],[],[], zeros(N,1), u_max*ones(N,1), max(min(u_PI,u_max),0), qopt);
y_nc = H*u_nc + d;

%% [CTRL-OPT-CAUSAL] receding-horizon MPC (knows d only up to now) --------------
u_ca = zeros(N,1);  x = zeros(size(A,1),1);  y_ca = zeros(N,1);
for k = 1:N
    p = min(Hp, N-k+1);                            % shrinking horizon at the end
    % free response from current state + constant-disturbance prediction
    Psi = zeros(p,1); Ai = eye(size(A));
    for i = 1:p, Psi(i) = C*Ai*x; Ai = Ai*A; end   % Psi(1)=C*x (y_k), Psi(2)=C*A*x, ...
    dk = d(k);                                     % last measured disturbance, held constant
    Hp_mat = tril(toeplitz(h(1:p)));
    Qk = 2*(Hp_mat.'*Hp_mat + lam*eye(p)); Qk=(Qk+Qk.')/2;
    fk = 2*Hp_mat.'*(Psi + dk - r(k:k+p-1));
    uk = quadprog(Qk, fk, [],[],[],[], zeros(p,1), u_max*ones(p,1), [], qopt);
    u_ca(k) = uk(1);                               % apply first move only
    y_ca(k) = C*x + D*u_ca(k) + d(k);
    x = A*x + B*u_ca(k);                           % propagate true plant state
end

%% [CTRL-OPT-METRICS] -----------------------------------------------------------
w_ss = round(1*Fs)+1:N;                            % steady-state window [1,dur]s (project convention)
rmse   = @(y) sqrt(mean((y-r).^2));
rmse_s = @(y) sqrt(mean((y(w_ss)-r(w_ss)).^2));
fprintf('\n[CTRL-OPT] tracking RMSE to ref=%.1f%%  (lower is better)\n', ref_level);
fprintf('   controller        full[0,%gs]   steady[1,%gs]   u mean   u max\n', dur, dur);
fprintf('   PI (measured)     %8.3f     %8.3f    %7.3f %7.3f\n', rmse(y_PI), rmse_s(y_PI), mean(u_PI), max(u_PI));
fprintf('   optimal causal    %8.3f     %8.3f    %7.3f %7.3f\n', rmse(y_ca), rmse_s(y_ca), mean(u_ca), max(u_ca));
fprintf('   optimal non-caus. %8.3f     %8.3f    %7.3f %7.3f\n', rmse(y_nc), rmse_s(y_nc), mean(u_nc), max(u_nc));
fprintf('   -> causal optimal improves steady RMSE by %.1f%% vs PI\n', 100*(1-rmse_s(y_ca)/rmse_s(y_PI)));

%% [CTRL-OPT-FIG] ---------------------------------------------------------------
figO = figure('Color','w','Position',[50 70 1500 470]);
tl = tiledlayout(figO,1,3,'TileSpacing','compact','Padding','compact');
cPI=[0 0 0]; cCA=[0.1 0.5 0.85]; cNC=[0.85 0.3 0.1];

nexttile(tl,1); hold on;                            % output tracking
yline(ref_level,'--','Color',[0.1 0.5 0.2],'LineWidth',1.2,'Label','ref','FontSize',8);
plot(tt,y_PI,'-','Color',cPI,'LineWidth',1.8);
plot(tt,y_ca,'-','Color',cCA,'LineWidth',1.5);
plot(tt,y_nc,'-','Color',cNC,'LineWidth',1.3);
xlabel('time from stim (s)'); ylabel('ipsi \DeltaF/F (%)'); xlim([tt(1) tt(end)]);
legend({'ref','PI (measured)','optimal causal','optimal non-causal'},'Box','off','Location','southeast','FontSize',8);
title(sprintf('tracking: steady RMSE  PI %.2f -> opt %.2f', rmse_s(y_PI), rmse_s(y_ca)));

nexttile(tl,2); hold on;                            % commands
plot(tt,u_PI,'-','Color',cPI,'LineWidth',1.6);
plot(tt,u_ca,'-','Color',cCA,'LineWidth',1.4);
plot(tt,u_nc,'-','Color',cNC,'LineWidth',1.2);
yline(u_max,':','Color',[.4 .4 .4],'LineWidth',1,'Label','u_{max}','FontSize',8);
yline(0,'k-');
xlabel('time from stim (s)'); ylabel('laser command (amplitude)'); xlim([tt(1) tt(end)]);
legend({'PI','optimal causal','optimal non-causal'},'Box','off','Location','northeast','FontSize',8);
title('command: one-sided actuator 0 \leq u \leq u_{max}');

nexttile(tl,3); hold on;                            % the disturbance being fought
plot(tt,d,'-','Color',[0.5 0.2 0.6],'LineWidth',1.6); yline(0,'k:');
xlabel('time from stim (s)'); ylabel('disturbance d (%)');  xlim([tt(1) tt(end)]);
title(sprintf('measured disturbance  (drift %+.2f%% over trial)', d(end)-d(1)));

sgtitle(figO, sprintf('[CTRL-OPT] Stage 4b optimal vs PI  %s  (plant nx=%d, u_{max}=%.2f %s)', ...
    strrep(sess_tag,'_','\_'), L.nx, u_max, uMaxMode));
fig_png = fullfile(fig_dir, sprintf('ctrl_optimal_%s.png', sess_tag));
exportgraphics(figO, fig_png, 'Resolution', 300);
fprintf('[CTRL-OPT-FIG] -> %s\n', fig_png);

%% [CTRL-OPT-SAVE] --------------------------------------------------------------
OPT = struct('sess_tag',sess_tag,'Fs',Fs,'N',N,'dur',dur,'ref_level',ref_level, ...
    'u_max',u_max,'uMaxMode',uMaxMode,'lam',lam,'Hp',Hp,'tt',tt, ...
    'y_PI',y_PI,'u_PI',u_PI,'y_ca',y_ca,'u_ca',u_ca,'y_nc',y_nc,'u_nc',u_nc,'d',d, ...
    'rmse_PI',rmse(y_PI),'rmse_ca',rmse(y_ca),'rmse_nc',rmse(y_nc), ...
    'rmse_s_PI',rmse_s(y_PI),'rmse_s_ca',rmse_s(y_ca),'rmse_s_nc',rmse_s(y_nc));
opt_file = fullfile(dataDir, sprintf('ctrl_optimal_%s.mat', sess_tag));
save(opt_file, '-struct', 'OPT', '-v7.3');
fprintf('[CTRL-OPT-SAVE] -> %s\n\n', opt_file);
