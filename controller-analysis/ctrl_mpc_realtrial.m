function R = ctrl_mpc_realtrial(varargin)
%CTRL_MPC_REALTRIAL  MPC vs PI on the REAL single-trial disturbances (supersedes ctrl_tube_mpc.m).
%
% WHY A NEW SCRIPT (RESEARCH 2026-10-05). ctrl_tube_mpc.m drew synthetic disturbances scaled to the
%   std of the TRIAL-MEAN contra Global (0.15 %dF/F on m4). The single-trial departures the loop
%   actually faces have sd 2.7 %dF/F, with a different time structure. Here every rollout is driven
%   by one of the 108 recorded trials' contra Global, so the size and the predictability of the
%   disturbance are both measured, not assumed.
%
% PLANT. Stage-4a laser->ipsi LTI (ctrl_lti_<sess>.mat, delay absorbed). The REALIZED actuator gain
%   is g_k*B, g_k lognormal (mean 1, CV sigma_u measured from the open-loop trials, as before); every
%   controller plans with the nominal model. The same g_k and the same disturbance are used for
%   every controller on trial k (common realizations -> paired comparison).
%
% DISTURBANCE. d_k(t) = dbar(t) + dep_k(t): dbar = plant-consistent trial-mean disturbance (as in
%   ctrl_tube_mpc), dep_k = trial k's contra Global minus the trial mean. Pre-stim (1 s, laser off)
%   dep_k is observed exactly and seeds the forecasters.
%
% INFORMATION. At step k each controller has seen y up to k-1. The disturbance estimate is
%   dhat = y - C*xn (xn = nominal-model state), so actuator-gain error leaks into dhat exactly as it
%   would online (offset-free MPC).
%
% CONTROLLERS
%   PI      u = sat(uff + Kp*e + Ki/Fs*sum_{last M} e), e = y - ref, M = 105 (the rig's boxcar
%           "integral", ctrl_margins.m). Kp, Ki, uff grid-tuned on these same trials -> a best-case PI.
%   MPC     receding-horizon QP, Hp = 1 s, u in [0, u_max], with a disturbance forecast that is
%             hold   last estimate held over the horizon (standard offset-free MPC, no preview)
%             AR     causal AR(p) forecast of dep, trained on the OTHER folds (5-fold across trials)
%                    (= blend x=1; 'ari' = the same on first differences, an offset-keeping variant)
%             clair  the true future dep (+ the current gain-mismatch offset) = perfect forecast
%           and a blend  fc = clair + x*(AR - clair),  x = 0 (perfect) .. 1 (AR) .. 1.5 (worse).
%
% METRIC. Per-trial RMSE vs ref over +1..+3 s (project RMSE window for disturbance rejection);
%   reported as median [IQR] across trials, and paired ratio to PI.
%
% RUNS (2026-10-05, ~6 min each)
%   R  = ctrl_mpc_realtrial('lamGrid',[1e-2 0.1 1 10 100 1000]);                     % measured sigma_u
%   Rg = ctrl_mpc_realtrial('sigU',0,'tag','_g1','lamGrid',[0.1 1 10 100], ...      % perfect actuator,
%                           'KpGrid',R.Kp,'KiGrid',R.Ki);                             %   same PI gains
%   then ctrl_mpc_supp_fig.m
%
% OUT  controller-analysis/data/ctrl_mpc_realtrial_<sess><tag>.mat

P.sess   = 'AL_0033_0226_e2';   % m4 (best-transfer deploy session; holds -5 with an interior command)
P.Fs     = 35;
P.Hp     = 35;
P.ref    = -5;
P.lamGrid= [1e-3 1e-2 0.1 1 10];   % MPC penalty on input moves ||Delta u||^2, tuned per forecaster like the PI gains
P.qbGrid = [1e-3 1e-2 0.1 1];      % Kalman bias random-walk variance, in units of the AR innovation variance
P.rmseWin= [1 3];
P.M      = 105;                 % PI boxcar length (3 s), as on the rig
P.nFold  = 5;
P.p      = 19;                  % AR order (modal inner-CV choice in ctrl_mpc_forecast_sigma)
P.xGrid  = [0 0.25 0.5 0.75 1 1.25 1.5];
P.sigU   = 'auto';
P.seed   = 7;
P.nUse   = inf;                 % debug: limit the number of trials
P.tag    = '';                  % output-file suffix, e.g. '_g1' for the perfect-actuator run
P.KpGrid = 0:0.04:0.60;         % PI tuning grid, in plant input units per %dF/F
P.KiGrid = 0:0.25:3.0;
for a=1:2:numel(varargin); P.(varargin{a})=varargin{a+1}; end

here = fileparts(mfilename('fullpath'));
dataDir = fullfile(here,'data');
addpath(genpath(fullfile(here,'..','utils')));

%% [MRT-LOAD] -------------------------------------------------------------------
L  = load(fullfile(dataDir, sprintf('ctrl_lti_%s.mat', P.sess)));
S3 = load(fullfile(dataDir, sprintf('ctrl_ols_cl_deploy_%s.mat', P.sess)));
pre = S3.pre; N = round(S3.dur*P.Fs); u_max = L.uMaxCL;
[h, H, md] = ctrl_plant_markov(L, N); [A,B,C,D] = ssdata(md); nx = size(A,1);
u_PI  = L.u_CL(pre+1:pre+N); u_PI = u_PI(:);
dPI   = S3.AaAbs(pre+1:pre+N).' - H*u_PI;
Gc    = mean(S3.Gabs,1);                                   % trial mean, all samples
dbar  = (Gc(pre+1:pre+N).' - mean(Gc(pre+1:pre+N))) + mean(dPI);
DEP   = S3.Gabs - Gc;                                      % nT x (pre+N+..) single-trial departures
nT    = min(size(DEP,1), P.nUse); DEP = DEP(1:nT,:); S3.Aabs = S3.Aabs(1:nT,:);
tt    = (1:N).'/P.Fs; wmask = tt>=P.rmseWin(1) & tt<=P.rmseWin(2);
rmse  = @(y) sqrt(mean((y(wmask) - P.ref).^2));
realCL = sqrt(mean((S3.Aabs(:,pre+find(wmask)) - P.ref).^2, 2));   % recorded CL per-trial RMSE

% actuator-gain spread from the OL trials (same estimator as ctrl_tube_mpc)
if ischar(P.sigU)
    O = load(fullfile(dataDir, sprintf('ctrl_ols_ol_stimblind_%s.mat', P.sess)));
    Aol = O.A_tr(:, pre+1:end); mu = O.Aa(pre+1:end).'; s = (Aol*mu)/(mu.'*mu);
    P.sigU = std(s)/mean(s);
end
rng(P.seed); sl = sqrt(log(1+P.sigU^2)); g = exp(sl*randn(nT,1) - 0.5*sl^2);
rng(P.seed); fold = mod(randperm(nT), P.nFold) + 1;

% AR per fold (trained on the other folds only)
arA = cell(1,P.nFold); arS2 = nan(1,P.nFold);
for f = 1:P.nFold, [arA{f}, arS2(f)] = fitAR(DEP(fold~=f,:), P.p); end
Fcomp = @(a) [a.'; eye(numel(a)-1) zeros(numel(a)-1,1)];   % AR companion matrix

% constant QP pieces
Obs = zeros(P.Hp, nx); Ai = eye(nx); for i=1:P.Hp, Obs(i,:) = C*Ai; Ai = Ai*A; end
qopt = optimoptions('quadprog','Display','off');
fprintf('[MRT] %s | %d trials | sigma_u=%.2f | sd(dep, window)=%.2f | real CL RMSE median %.2f\n', ...
    P.sess, nT, P.sigU, std(reshape(DEP(:,pre+find(wmask)),[],1)), median(realCL));

%% [MRT-PI] tune a best-case PI on these trials, then run it ----------------------
uff0 = (P.ref - mean(dbar)) / sum(h);                      % steady command for the mean disturbance
best = inf;
for Kp = P.KpGrid
    for Ki = P.KiGrid
        r = arrayfun(@(k) rmse(runPI(k, Kp, Ki, uff0, g(k))), 1:nT);
        if median(r) < best, best = median(r); KpB = Kp; KiB = Ki; end
    end
end
yPI = zeros(N,nT); for k=1:nT, yPI(:,k) = runPI(k, KpB, KiB, uff0, g(k)); end
rPI = arrayfun(@(k) rmse(yPI(:,k)), 1:nT).';
fprintf('[MRT] PI tuned: Kp=%.2f Ki=%.2f | sim PI RMSE median %.2f (real CL %.2f)\n', KpB, KiB, median(rPI), median(realCL));

%% [MRT-MPC] -----------------------------------------------------------------------
% Every MPC variant is tuned like the PI: lam (Delta-u penalty) on a grid; the AR (x=1) variant also
% tunes qb, the bias random-walk variance of its Kalman disturbance model, which the blends reuse.
modes = [{'hold','x1.00'}, arrayfun(@(x) sprintf('x%.2f',x), setdiff(P.xGrid,1,'stable'), 'uni', 0)];
rM = nan(nT, numel(modes)); Y = cell(1,numel(modes)); lamB = nan(1,numel(modes)); qbB = P.qbGrid(1);
for im = 1:numel(modes)
    bestM = inf;
    if strcmp(modes{im},'x1.00'), qbs = P.qbGrid; else, qbs = qbB; end
    for qb = qbs
        for lam = P.lamGrid
            rr = nan(nT,1); yy = zeros(N,nT);
            for k = 1:nT, yy(:,k) = runMPC(k, modes{im}, g(k), lam, qb); rr(k) = rmse(yy(:,k)); end
            if median(rr) < bestM, bestM = median(rr); rM(:,im) = rr; lamB(im) = lam; Y{im} = yy; qbSel = qb; end
        end
    end
    if strcmp(modes{im},'x1.00'), qbB = qbSel; end
    fprintf('[MRT] MPC %-6s lam=%-6g qb=%-6g RMSE median %.2f [%.2f %.2f] | paired ratio to PI median %.2f | beats PI on %d/%d trials\n', ...
        modes{im}, lamB(im), qbSel, median(rM(:,im)), prctile(rM(:,im),25), prctile(rM(:,im),75), median(rM(:,im)./rPI), sum(rM(:,im)<rPI), nT);
end
% perfect actuator (g=1): how much of the clairvoyant / hold residual is the actuator-gain spread
iC = strcmp(modes,'x0.00'); rIdeal = nan(nT,2);
for k=1:nT
    rIdeal(k,1) = rmse(runMPC(k,'x0.00',1,lamB(iC),qbB)); rIdeal(k,2) = rmse(runMPC(k,'hold',1,lamB(1),qbB));
end
fprintf('[MRT] perfect actuator (g=1): clair %.2f | hold %.2f\n', median(rIdeal(:,1)), median(rIdeal(:,2)));

R = struct('P',P,'modes',{modes},'rM',rM,'rPI',rPI,'realCL',realCL,'rIdeal',rIdeal,'Kp',KpB,'Ki',KiB,'lamB',lamB,'qbB',qbB, ...
    'uff0',uff0,'g',g,'yPI',yPI,'Y',{Y},'dbar',dbar,'tt',tt,'wmask',wmask);
save(fullfile(dataDir, sprintf('ctrl_mpc_realtrial_%s%s.mat', P.sess, P.tag)), '-struct','R');

% ---- nested: PI on trial k ---------------------------------------------------------
    function y = runPI(k, Kp, Ki, uff, gk)
        d = dbar + DEP(k, pre+1:pre+N).';
        y = zeros(N,1); x = zeros(nx,1); e = zeros(N,1); ek = 0; s = 0;
        for t = 1:N
            if t > 1, ek = y(t-1) - P.ref; e(t-1) = ek; s = s + ek; if t-1 > P.M, s = s - e(t-1-P.M); end, end
            u = min(max(uff + Kp*ek + Ki/P.Fs*s, 0), u_max);
            y(t) = C*x + gk*D*u + d(t);
            x = A*x + gk*B*u;
        end
    end

% ---- nested: MPC on trial k ------------------------------------------------------
    function [y, u] = runMPC(k, mode, gk, lam, qb)
        dtrue = dbar + DEP(k, pre+1:pre+N).';
        depAll = DEP(k,:).'; aK = arA{fold(k)}; s2 = arS2(fold(k));
        % Kalman disturbance model: estimated departure = bias b (random walk, var qb*s2 per step;
        % absorbs the actuator-gain mismatch) + AR(p) fluctuation. Forecast = b held + AR forecast.
        np = numel(aK); Fz = blkdiag(1, Fcomp(aK)); Hz = [1 1 zeros(1,np-1)];
        Qz = zeros(np+1); Qz(1,1) = qb*s2; Qz(2,2) = s2; Rz = 1e-6*s2;
        z = zeros(np+1,1); Pz = blkdiag(0, var(depAll(1:pre))*eye(np));
        for j = 1:pre, [z,Pz] = kfStep(z,Pz,depAll(j)); end            % pre-stim: laser off, exact
        hist = depAll(1:pre);                 % estimated departure history (exact pre-stim)
        y = zeros(N,1); u = zeros(N,1); xt = zeros(nx,1); xn = zeros(nx,1);
        for t = 1:N
            p = min(P.Hp, N-t+1);
            % disturbance estimate up to t-1 (pre-stim value at t=1)
            if t > 1
                dh = y(t-1) - C*xnPrev - D*u(t-1); hist(end+1,1) = dh - dbar(t-1); %#ok<AGROW>
                [z,Pz] = kfStep(z,Pz,hist(end));
            end
            off = hist(end) - depAll(pre+t-1);                   % current estimate - truth (gain mismatch)
            if strcmp(mode,'hold')
                fc = hist(end)*ones(p,1);
            else
                x = sscanf(mode,'x%f');
                fClair = depAll(pre+t:pre+t+p-1) + off;
                if x == 0, fc = fClair;
                else
                    fKF = zeros(p,1); zz = z;
                    for j = 1:p, zz = Fz*zz; fKF(j) = Hz*zz; end   % bias held + AR forecast
                    fc  = fClair + x*(fKF - fClair);
                end
            end
            dfc = dbar(t:t+p-1) + fc;
            Hk = H(1:p,1:p); Psi = Obs(1:p,:)*xn;
            % penalty on input MOVES lam*||Delta u||^2 (does not anchor the steady state, so a gain
            % mismatch can be fully corrected, as the PI integral does)
            Dm = eye(p) - diag(ones(p-1,1),-1); if t == 1, uprev = uff0; else, uprev = u(t-1); end
            Qk = 2*(Hk.'*Hk + lam*(Dm.'*Dm)); Qk = (Qk+Qk.')/2;
            fk = 2*Hk.'*(Psi + dfc - P.ref) - 2*lam*Dm.'*[uprev; zeros(p-1,1)];
            uk = quadprog(Qk, fk, [],[],[],[], zeros(p,1), u_max*ones(p,1), [], qopt);
            u(t) = uk(1);
            y(t) = C*xt + gk*D*u(t) + dtrue(t);
            xt = A*xt + gk*B*u(t);
            xnPrev = xn; xn = A*xn + B*u(t);
        end
        function [z,Pz] = kfStep(z,Pz,obs)
            z = Fz*z; Pz = Fz*Pz*Fz.' + Qz;                         % predict
            S = Hz*Pz*Hz.' + Rz; K = Pz*Hz.'/S;
            z = z + K*(obs - Hz*z); Pz = (eye(np+1) - K*Hz)*Pz;     % update
        end
    end
end

% ---- helpers ------------------------------------------------------------------------
function [a, s2] = fitAR(X, p)
n = size(X,2); Z = zeros(size(X,1)*(n-p), p); y = zeros(size(Z,1),1); r = 0;
for k = 1:size(X,1)
    x = X(k,:).'; idx = r + (1:n-p);
    for j = 1:p, Z(idx,j) = x(p+1-j:n-j); end
    y(idx) = x(p+1:n); r = idx(end);
end
a = (Z.'*Z + 1e-6*eye(p)) \ (Z.'*y);
s2 = mean((y - Z*a).^2);                % one-step innovation variance
end

function f = arIter(hist, a, L)
% forecasts for the next L samples AFTER the last history sample
p = numel(a); hh = hist(end:-1:end-p+1).'; f = zeros(L,1);
for s = 1:L, nx = hh*a; f(s) = nx; hh = [nx hh(1:end-1)]; end
end
