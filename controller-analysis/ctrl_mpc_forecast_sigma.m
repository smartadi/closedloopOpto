function F = ctrl_mpc_forecast_sigma(varargin)
%CTRL_MPC_FORECAST_SIGMA  Measured forecast error of the MPC disturbance -> operating point on the
%                         tube-MPC forecast-quality curve (stands in for Ziyu's model, Nick 2026-09-11.4).
%
% SIGNAL. The disturbance the tube-MPC rejects is the contra-model Global (contra-predicted no-laser
%   ipsi, stim-blind), per trial (S3.Gabs, trials x time). We forecast each trial's DEPARTURE from
%   the trial mean (the train-fold mean = climatology), exactly the part the MPC cannot know a priori.
%
% FORECASTERS (all fitted on training trials only, 5-fold CV across trials):
%   persistence  last observed value held over the lead (Naive-persistence)
%   AR(p)        pooled least-squares AR on departures, p by inner CV, iterated multi-step
%   direct       per-lead linear regression on the last p samples (best linear multi-step forecaster)
%
% METRIC. m(tau) = forecast RMSE at lead tau / std(departure), targets in the +1..+3 s window (the
%   tube-MPC scoring window). Climatology = 1 by construction. The tube-MPC error model is
%   e*rho(tau), so the operating point is x = argmin sum_tau (m(tau) - x*rho(tau))^2 (x = e/sigma_nat,
%   the curve's own x-axis). x1s = m(1 s) / m_persist(1 s) is also kept for the Lu et al. MWQL-style
%   placement.
%
% OUT  controller-analysis/data/ctrl_mpc_forecast_sigma_<sess>.mat  (read by ctrl_tube_mpc.m)

P.sess  = 'AL_0033_0226_e2';
P.Fs    = 35;
P.win   = [1 3];        % target window (s post-onset), = tube-MPC P.rmseWin
P.maxLd = 35;           % leads 1..35 samples (1 s)
P.pGrid = 1:20;
P.nFold = 5;
P.seed  = 7;
P.rho   = [0 0.10; 0.15 0.50; 0.20 0.60; 0.35 0.75; 0.50 0.83; 0.75 0.87; 1.0 0.90];  % = ctrl_tube_mpc
for a=1:2:numel(varargin); P.(varargin{a})=varargin{a+1}; end

here = fileparts(mfilename('fullpath'));
dataDir = fullfile(here,'data');
S3 = load(fullfile(dataDir, sprintf('ctrl_ols_cl_deploy_%s.mat', P.sess)));
G  = S3.Gabs; pre = S3.pre; [nT, nS] = size(G);
tgt = (pre + round(P.win(1)*P.Fs)) : min(nS, pre + round(P.win(2)*P.Fs));   % target sample indices
Ld  = 1:P.maxLd;  nL = numel(Ld);

rng(P.seed); fold = mod(randperm(nT), P.nFold) + 1;
[ePer, eAR, eDir] = deal(cell(1,nL)); eClim = cell(1,nL); pSel = nan(1,P.nFold);
for k = 1:P.nFold
    tr = fold~=k; te = fold==k;
    mu = mean(G(tr,:),1);
    Xtr = G(tr,:) - mu;  Xte = G(te,:) - mu;
    % --- AR order by inner CV on 1-s-lead-averaged error (train trials only)
    pSel(k) = pickP(Xtr, P.pGrid, tgt, Ld);
    p = pSel(k);
    a = fitAR(Xtr, p);
    for il = 1:nL
        L = Ld(il); org = tgt - L; ok = org >= p; o = org(ok); t = tgt(ok);
        yt = Xte(:, t);
        ePer{il}  = [ePer{il};  reshape(yt - Xte(:, o), [], 1)];
        eClim{il} = [eClim{il}; yt(:)];
        eAR{il}   = [eAR{il};   reshape(yt - arFcst(Xte, a, o, L), [], 1)];
        % direct per-lead regression: y(t) ~ last p samples at origin, fitted on train
        [Ztr, ytr] = lagMat(Xtr, p, o, t);  [Zte, ~] = lagMat(Xte, p, o, t);
        b = (Ztr.'*Ztr + 1e-6*eye(p)) \ (Ztr.'*ytr);
        eDir{il}  = [eDir{il}; reshape(yt, [], 1) - Zte*b];
    end
end
sdDep = sqrt(mean(cellfun(@(e) mean(e.^2), eClim)));          % climatology RMSE = std(departure)
rm = @(C) cellfun(@(e) sqrt(mean(e.^2)), C) / sdDep;
F.lead_s  = Ld / P.Fs;
F.mPer = rm(ePer); F.mAR = rm(eAR); F.mDir = rm(eDir); F.mClim = rm(eClim);
rhoL = min(max(interp1(P.rho(:,1), P.rho(:,2), F.lead_s, 'linear','extrap'),0),1);
fitx = @(m) (rhoL*m.') / (rhoL*rhoL.');                      % LS scale on the tube-MPC rho profile
F.xPer = fitx(F.mPer); F.xAR = fitx(F.mAR); F.xDir = fitx(F.mDir);
best = min([F.mAR; F.mDir],[],1);  F.mBest = best;  F.xBest = fitx(best);
F.x1s_vsPersist = best(end) / F.mPer(end);
F.x1s_vsClim    = best(end);
F.pSel = pSel; F.sdDep = sdDep; F.nTrials = nT; F.P = P; F.rhoL = rhoL;
fprintf(['[FSIG] %s | %d trials | AR p=%s | sd(dep)=%.3f\n' ...
         '       m(tau)/clim @ 0.1/0.3/1 s : persist %.2f/%.2f/%.2f  AR %.2f/%.2f/%.2f  direct %.2f/%.2f/%.2f\n' ...
         '       operating point x (fit to rho profile): persist %.2f  AR %.2f  direct %.2f  best %.2f\n' ...
         '       1-s skill: best/clim %.2f  best/persist %.2f\n'], ...
    P.sess, nT, mat2str(pSel), sdDep, F.mPer(lix(0.1)),F.mPer(lix(0.3)),F.mPer(end), ...
    F.mAR(lix(0.1)),F.mAR(lix(0.3)),F.mAR(end), F.mDir(lix(0.1)),F.mDir(lix(0.3)),F.mDir(end), ...
    F.xPer, F.xAR, F.xDir, F.xBest, F.x1s_vsClim, F.x1s_vsPersist);
save(fullfile(dataDir, sprintf('ctrl_mpc_forecast_sigma_%s.mat', P.sess)), '-struct', 'F');

    function i = lix(s), [~,i] = min(abs(F.lead_s - s)); end
end

% ---- helpers ------------------------------------------------------------------
function a = fitAR(X, p)
[Z, y] = deal([]);
for k = 1:size(X,1)
    x = X(k,:).'; n = numel(x);
    Zk = zeros(n-p, p); for j = 1:p, Zk(:,j) = x(p+1-j:n-j); end
    Z = [Z; Zk]; y = [y; x(p+1:n)]; %#ok<AGROW>
end
a = (Z.'*Z + 1e-6*eye(p)) \ (Z.'*y);
end

function Yh = arFcst(X, a, org, L)
% iterated L-step AR forecast from each origin (origin sample itself is the last observed)
p = numel(a); Yh = zeros(size(X,1), numel(org));
for j = 1:numel(org)
    h = X(:, org(j):-1:org(j)-p+1);          % most-recent first
    for s = 1:L
        nx = h*a; h = [nx h(:,1:end-1)];
    end
    Yh(:,j) = h(:,1);
end
end

function [Z, y] = lagMat(X, p, org, t)
Z = zeros(size(X,1)*numel(org), p); y = zeros(size(Z,1),1); r = 0;
for j = 1:numel(org)
    idx = r + (1:size(X,1));
    Z(idx,:) = X(:, org(j):-1:org(j)-p+1); y(idx) = X(:, t(j)); r = idx(end);
end
end

function p = pickP(X, pGrid, tgt, Ld)
% inner 2-fold CV over trials: mean squared iterated-forecast error across all leads
n = size(X,1); h = false(1,n); h(1:2:end) = true; err = inf(size(pGrid));
for ip = 1:numel(pGrid)
    q = pGrid(ip); a = fitAR(X(~h,:), q); e = 0;
    for L = Ld([1 round(end/2) end])
        o = tgt - L; o = o(o >= q); t = o + L;
        e = e + mean((X(h,t) - arFcst(X(h,:), a, o, L)).^2, 'all');
    end
    err(ip) = e;
end
[~, i] = min(err); p = pGrid(i);
end
