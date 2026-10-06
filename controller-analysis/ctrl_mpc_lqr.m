function R = ctrl_mpc_lqr(varargin)
%CTRL_MPC_LQR  Preview finite-horizon LQR (receding horizon, input-constrained) vs PI, on a scalar
%              plant identified from the open-loop step (user spec 2026-10-05).
%
% PLANT (user 2026-10-05: 2-state + measured 47 ms latency). x(t+1) = A x(t) + B u(t-d), y = C x + dist,
%   d = P.delay = 2 samples, 2 poles constrained real in (0,1), output-error fit on the fixed OL step
%   command u_OL vs the trial-averaged OL response y_OL. m4: the data support ONE time constant
%   (~190 ms); the 2nd pole goes to ~0 (a one-sample input memory = fast zero), fit 88.7%.
%   (First version 2026-10-05 was scalar, no delay: a=0.879, b=-0.549, fit 88.4%.)
%   Realized plant on trial k uses g_k*b, g_k lognormal with the CV measured from the OL trials;
%   both controllers plan/act with the nominal b. Same g_k and same d_k for both (paired).
%
% DISTURBANCE. d_k = dbar + dep_k: dep_k = trial k's contra-predicted Global minus the trial
%   mean (108 recorded CL trials), dbar = plant-consistent mean (recorded mean CL output minus
%   the model's response to the recorded mean CL command, fluctuations from the contra Global).
%
% CONTROLLERS (both measure y(t), then set u(t), which acts on x(t+1))
%   PI    u = sat(uff + Kp*e + Ki/Fs*sum_{last M} e), e = y - ref, rig boxcar M = 105; Kp,Ki grid-tuned.
%   LQR   min sum_{j=1..Hp} (y(t+j)-ref)^2 + r*(u(t+j-1)-uss)^2, 0 <= u <= u_max, over the next
%         Hp = 35 samples (1 s), given the state estimate xn(t) (nominal-model state) and a
%         disturbance preview dfc(t+1..t+Hp); apply u(t), repeat. r small = aggressive.
%         dhat(t) = y(t) - xn(t) carries any gain-mismatch offset; every preview keeps that offset.
%   Previews:  hold   dhat(t) held (no preview; offset-free feedback only)
%              AR     Kalman (bias random walk + AR(p)) on the dhat history, AR trained on other folds
%              clair  true future d + current offset (perfect preview)
%              blend  clair + x*(AR - clair)
%
% OUT  controller-analysis/data/ctrl_mpc_lqr_<sess><tag>.mat

P.sess   = 'AL_0033_0226_e2';
P.Fs     = 35;  P.Hp = 35;  P.ref = -5;  P.rmseWin = [1 3];  P.M = 105;
P.delay  = 2;                    % input delay (samples): measured 47 ms loop latency -> 2 samples (57 ms)
P.r      = 1e-3;
P.rd     = 1;                    % penalty on input moves (Delta u)^2. User choice 2026-10-05: 1 (command
                                 % ~2x rougher than PI's; Fig-3 replay perfect preview 0.14x vs 0.38x at 10).
                                 % 10 = PI-matched smoothness; 0 chatters. See ctrl_mpc_smooth_tradeoff.m                 % input weight (aggressive), in (%dF/F)^2 per (cmd unit)^2
P.nFold  = 5;   P.p = 19;   P.qb = 1;   % AR order; Kalman bias variance (x AR innovation var)
P.fcst   = 'ar';                 % forecaster: 'ar' | 'shrink' | 'lp' (see [LQR] forecaster variants)
P.lpHz   = 3;                    % 'lp' cutoff (Hz)
P.xGrid  = [0 0.25 0.5 0.75 1 1.25 1.5];
P.sigU   = 'auto';  P.seed = 7;  P.nUse = inf;  P.tag = '';
P.frame  = 'svd';                % 'svd' = contra-Global disturbance (Aabs frame); 'fig3' = replay each
                                 %   recorded CL trial in the rig's online dF/F (Fig-3 frame)
P.rawFile = 'AL_0033ctrl02262.mat';   % fig3 frame: session cache under brain_paper/data
P.unbounded = false;            % diagnostic: drop the MPC laser bounds (two-sided, unlimited)
P.Lp     = inf;                 % preview window (samples) inside the fixed Hp horizon; inf = full 1 s
P.KpGrid = 0:0.04:0.60;  P.KiGrid = 0:0.25:3.0;
for i=1:2:numel(varargin); P.(varargin{i})=varargin{i+1}; end

here = fileparts(mfilename('fullpath')); dataDir = fullfile(here,'data');
addpath(genpath(fullfile(here,'..','utils')));
if strcmp(P.frame,'fig3')
    % [LQR-FIG3] Fig-3 frame: the rig's online dF/F (data.dFk, = Fig-3 ncDfk/wcDfk exactly) and each
    % trial's recorded laser command (cp_laser_amplitude at 2 kHz, sampled at the frame times).
    Z = load(fullfile(here,'..','data',P.rawFile)); dz = Z.d; Dz = Z.data;
    [uAmp, ~] = cp_laser_amplitude(dz.inpVals, dz.inpTime);
    tb = dz.timeBlue(:); yfull = Dz.dFk(:); pre = 35; N = 105; rel = -pre:N;
    on = arrayfun(@(t) find(tb >= t, 1), dz.stimStarts(:));
    grab = @(idx) deal(cell2mat(arrayfun(@(i) yfull(on(i)+rel).', idx(:), 'uni', 0)), ...
                       cell2mat(arrayfun(@(i) interp1(dz.inpTime, uAmp, tb(on(i)+rel), 'linear', 0).', idx(:), 'uni', 0)));
    [Yol, Uol] = grab(Dz.nc);  [Ycl, Ucl] = grab(Dz.wc);
    L = struct('u_OL', mean(Uol,1).' - mean(mean(Uol(:,1:pre))), 'y_OL', mean(Yol,1).' - mean(mean(Yol(:,1:pre))));
    u_max = max(Ucl(:));
    if ischar(P.sigU), P.sigU = 0; end            % the trial's own gain error is inside its replayed d
else
    L  = load(fullfile(dataDir, sprintf('ctrl_lti_%s.mat', P.sess)));
    S3 = load(fullfile(dataDir, sprintf('ctrl_ols_cl_deploy_%s.mat', P.sess)));
    pre = S3.pre; N = round(S3.dur*P.Fs); u_max = L.uMaxCL;
end
uLo = 0; uHi = u_max; if P.unbounded, uLo = -inf; uHi = inf; end   % MPC bounds (diagnostic switch)

%% [LQR-SYSID] 2-state plant + input delay from the OL step --------------------------
% y(t) = a1 y(t-1) + a2 y(t-2) + b1 u(t-1-d) + b2 u(t-2-d): output-error fit (free-run sim error)
% on the fixed OL command u_OL vs the trial-averaged OL response y_OL, with both poles constrained
% real in (0,1) (an unconstrained fit puts one pole on the negative axis = sample-to-sample ringing).
uo = L.u_OL(:); yo = L.y_OL(:);
sg = @(v) 1./(1+exp(-v)); d = P.delay;
simp = @(q) filter([zeros(1,1+d) q(3:4)], conv([1 -sg(q(1))],[1 -sg(q(2))]), uo);
best = inf; fopt = optimset('MaxFunEvals',4e4,'MaxIter',4e4,'TolX',1e-10,'TolFun',1e-10);
for s0 = [0.5 0.95; 0.3 0.9; 0.7 0.9; 0.1 0.88].'
    q = fminsearch(@(q) norm(yo - simp(q)), [log(s0.'./(1-s0.')) -0.3 -0.2], fopt);
    if norm(yo - simp(q)) < best, best = norm(yo - simp(q)); qB = q; end
end
pol = sort(sg(qB(1:2)),'descend'); bnum = qB(3:4);
fitOL = 100*(1 - norm(yo-simp(qB))/norm(yo-mean(yo)));
md = ss(tf([0 bnum], poly(pol), 1/P.Fs, 'InputDelay', d));     % 2 states, then
md = absorbDelay(md); [A,B,C,Dd] = ssdata(md); nx = size(A,1);  % delay folded in -> 2+d states
assert(Dd == 0);
dcg = sum(bnum)/prod(1-pol);

%% [LQR-DIST] -----------------------------------------------------------------------
tt = (1:N).'/P.Fs; wmask = tt>=P.rmseWin(1) & tt<=P.rmseWin(2);
rmse = @(y) sqrt(mean((y(wmask) - P.ref).^2));
if strcmp(P.frame,'fig3')
    % replay: d_k = recorded CL output - model response to that trial's recorded command (from -1 s)
    nT = min(size(Ycl,1), P.nUse); Ycl = Ycl(1:nT,:); Ucl = Ucl(1:nT,:);
    Dk = zeros(nT, numel(rel)); for k = 1:nT, Dk(k,:) = Ycl(k,:) - lsim(md, Ucl(k,:).').'; end
    dmean = mean(Dk,1); dbar = dmean(pre+1:pre+N).'; DEP = Dk - dmean;
    realCL = sqrt(mean((Ycl(:,pre+find(wmask)) - P.ref).^2, 2));
else
    uCL = L.u_CL(:); yCLm = S3.AaAbs(:);
    xm  = lsim(md, uCL);
    dPI  = yCLm(pre+1:pre+N) - xm(pre+1:pre+N);
    Gc   = mean(S3.Gabs,1);
    dbar = (Gc(pre+1:pre+N).' - mean(Gc(pre+1:pre+N))) + mean(dPI);
    DEP  = S3.Gabs - Gc; nT = min(size(DEP,1), P.nUse); DEP = DEP(1:nT,:);
    realCL = sqrt(mean((S3.Aabs(1:nT,pre+find(wmask)) - P.ref).^2, 2));
end
x0 = zeros(nx,1);                                 % pre-stim command ~0 -> state ~0 at onset
uss = (P.ref - mean(dbar)) / dcg;                 % steady command for the mean disturbance

if ischar(P.sigU)
    O = load(fullfile(dataDir, sprintf('ctrl_ols_ol_stimblind_%s.mat', P.sess)));
    Aol = O.A_tr(:, pre+1:end); mu = O.Aa(pre+1:end).'; s = (Aol*mu)/(mu.'*mu);
    P.sigU = std(s)/mean(s);
end
rng(P.seed); sl = sqrt(log(1+P.sigU^2)); g = exp(sl*randn(nT,1) - 0.5*sl^2);
rng(P.seed); fold = mod(randperm(nT), P.nFold) + 1;
% forecaster variants (P.fcst): 'ar' plain iterated AR; 'shrink' AR fluctuation forecast x alpha(lead),
% alpha = cov(f,d)/var(f) on training trials (never worse than "no change"); 'lp' AR fitted/run on the
% causally low-passed (P.lpHz) departure, so only the slow component is forecast.
[blp, alp] = butter(2, P.lpHz/(P.Fs/2));
arA = cell(1,P.nFold); arS2 = nan(1,P.nFold); alph = ones(P.Hp, P.nFold);
for f = 1:P.nFold
    Xtr = DEP(fold~=f,:); if strcmp(P.fcst,'lp'), Xtr = filter(blp, alp, Xtr, [], 2); end
    [arA{f}, arS2(f)] = fitAR(Xtr, P.p);
    if strcmp(P.fcst,'shrink'), alph(:,f) = fitShrink(Xtr, arA{f}, P.Hp); end
end

% prediction matrices: Y(t+1..t+Hp) = Phi*x(t) + Gam*U(t..t+Hp-1)  (delay states carry the latency)
Phi = zeros(P.Hp,nx); Gam = zeros(P.Hp); Ak = eye(nx); CA = zeros(P.Hp+1,nx);
for j = 0:P.Hp, CA(j+1,:) = C*Ak; Ak = Ak*A; end
for j = 1:P.Hp, Phi(j,:) = CA(j+1,:); for i = 1:j, Gam(j,i) = CA(j-i+1,:)*B; end, end
qopt = optimoptions('quadprog','Display','off');
fprintf(['[LQR] %s | 2-state + %d-sample delay (%.0f ms): poles %s (tau %s ms), b %s, DC %.2f, OL fit %.1f%%\n' ...
         '      %d trials | sigma_u=%.2f | sd(dep)=%.2f | real CL RMSE median %.2f | r=%g\n'], P.sess, d, 1000*d/P.Fs, ...
         mat2str(pol,3), mat2str(round(-1000/P.Fs./log(max(pol,eps)))), mat2str(bnum,3), dcg, fitOL, ...
         nT, P.sigU, std(reshape(DEP(:,pre+find(wmask)),[],1)), median(realCL), P.r);

%% [LQR-PI] --------------------------------------------------------------------------
best = inf;
for Kp = P.KpGrid, for Ki = P.KiGrid
    rr = arrayfun(@(k) rmse(runPI(k,Kp,Ki,g(k))), 1:nT);
    if median(rr) < best, best = median(rr); KpB = Kp; KiB = Ki; end
end, end
yPI = zeros(N,nT); uPI = yPI; yOL = yPI; uOL = yPI;
for k=1:nT, [yPI(:,k), uPI(:,k)] = runPI(k,KpB,KiB,g(k)); [yOL(:,k), uOL(:,k)] = runPI(k,0,0,g(k)); end
rPI = arrayfun(@(k) rmse(yPI(:,k)), 1:nT).';
fprintf('[LQR] PI tuned Kp=%.2f Ki=%.2f | RMSE median %.2f\n', KpB, KiB, median(rPI));

%% [LQR-RUN] -------------------------------------------------------------------------
modes = [{'hold'}, arrayfun(@(x) sprintf('x%.2f',x), P.xGrid, 'uni', 0)];
rM = nan(nT,numel(modes)); Y = cell(1,numel(modes)); U = Y;
for im = 1:numel(modes)
    Y{im} = zeros(N,nT); U{im} = zeros(N,nT);
    for k = 1:nT, [Y{im}(:,k), U{im}(:,k)] = runLQR(k, modes{im}, g(k)); rM(k,im) = rmse(Y{im}(:,k)); end
    fprintf('[LQR] %-6s RMSE median %.2f [%.2f %.2f] | paired ratio to PI %.2f | beats PI %d/%d\n', modes{im}, ...
        median(rM(:,im)), prctile(rM(:,im),25), prctile(rM(:,im),75), median(rM(:,im)./rPI), sum(rM(:,im)<rPI), nT);
end
R = struct('P',P,'poles',pol,'bnum',bnum,'A',A,'B',B,'C',C,'dcg',dcg,'fitOL',fitOL,'modes',{modes},'rM',rM,'rPI',rPI,'realCL',realCL,'Kp',KpB,'Ki',KiB, ...
    'g',g,'yPI',yPI,'uPI',uPI,'yOL',yOL,'uOL',uOL,'Y',{Y},'U',{U},'dbar',dbar,'tt',tt,'wmask',wmask,'uss',uss);
if strcmp(P.frame,'fig3')   % recorded Fig-3 trials (stim window), for the CL-trial comparison figure
    R.recOL = Yol(:,pre+1:pre+N).'; R.recCL = Ycl(:,pre+1:pre+N).';
    R.recUOL = Uol(:,pre+1:pre+N).'; R.recUCL = Ucl(:,pre+1:pre+N).';
end
save(fullfile(dataDir, sprintf('ctrl_mpc_lqr_%s%s.mat', P.sess, P.tag)), '-struct','R');

% ---- nested ------------------------------------------------------------------------
    function [y, u] = runPI(k, Kp, Ki, gk)          % Kp = Ki = 0 -> OL (feedforward uss only)
        dk = dbar + DEP(k,pre+1:pre+N).'; y = zeros(N,1); u = zeros(N,1); e = zeros(N,1); x = x0; s = 0;
        for t = 1:N
            y(t) = C*x + dk(t); e(t) = y(t) - P.ref; s = s + e(t); if t > P.M, s = s - e(t-P.M); end
            u(t) = min(max(uss + Kp*e(t) + Ki/P.Fs*s, 0), u_max);
            x = A*x + gk*B*u(t);
        end
    end

    function [y, u] = runLQR(k, mode, gk)
        dep = DEP(k,:).'; dk = dbar + dep(pre+1:pre+N); aK = arA{fold(k)}; s2 = arS2(fold(k));
        np = numel(aK); Fz = blkdiag(1, [aK.'; eye(np-1) zeros(np-1,1)]); Hz = [1 1 zeros(1,np-1)];
        Qz = zeros(np+1); Qz(1,1) = P.qb*s2; Qz(2,2) = s2; Rz = 1e-6*s2;
        z = zeros(np+1,1); Pz = blkdiag(0, var(dep(1:pre))*eye(np));
        isLP = strcmp(P.fcst,'lp'); al_k = alph(:,fold(k));
        if isLP, [dpre, zf] = filter(blp, alp, dep(1:pre)); else, dpre = dep(1:pre); end
        for j = 1:pre, [z,Pz] = kf(z,Pz,dpre(j)); end             % laser off: dep observed exactly
        y = zeros(N,1); u = zeros(N,1); x = x0; xn = x0;
        for t = 1:N
            y(t) = C*x + dk(t);
            dh = y(t) - C*xn - dbar(t);                          % departure estimate (incl. gain offset)
            if t > 1
                if isLP, [dhf, zf] = filter(blp, alp, dh, zf); else, dhf = dh; end
                [z,Pz] = kf(z,Pz,dhf);
            end
            p = min(P.Hp, N-t);
            if p < 1, u(t) = u(t-1); break; end
            off = dh - dep(pre+t);
            switch mode
                case 'hold', fc = dh*ones(p,1);
                otherwise
                    xb = sscanf(mode,'x%f'); fCl = dep(pre+t+1:pre+t+p) + off;
                    if xb == 0, fc = fCl;
                    else, fK = zeros(p,1); zz = z; for j=1:p, zz = Fz*zz; fK(j) = zz(1) + al_k(j)*zz(2); end
                          fc = fCl + xb*(fK - fCl); end
            end
            % preview window: only the first Lp forecast samples are used; beyond, the last previewed
            % value is held (Lp = 0 -> the current estimate dh is held = 'hold')
            Lp = min(P.Lp, p);
            if Lp == 0, fc(:) = dh; elseif Lp < p, fc(Lp+1:end) = fc(Lp); end
            dfc = dbar(t+1:t+p) + fc;
            G = Gam(1:p,1:p); free = Phi(1:p,:)*xn + dfc - P.ref;
            % + rd*||Delta u||^2: suppresses sample-to-sample chatter that exploits the model's fast
            %   zero, a path the ramped OL step cannot validate
            Dm = eye(p) - diag(ones(p-1,1),-1); if t == 1, up = uss; else, up = u(t-1); end
            Hq = 2*(G.'*G + P.r*eye(p) + P.rd*(Dm.'*Dm));
            fq = 2*(G.'*free - P.r*uss*ones(p,1) - P.rd*Dm.'*[up; zeros(p-1,1)]);
            uo = -Hq\fq;
            if any(uo < uLo | uo > uHi), uo = quadprog((Hq+Hq.')/2, fq, [],[],[],[], uLo*ones(p,1), uHi*ones(p,1), [], qopt); end
            u(t) = uo(1);
            x  = A*x  + gk*B*u(t);                              % true plant
            xn = A*xn + B*u(t);                                  % controller's nominal model
        end
        function [z,Pz] = kf(z,Pz,obs)
            z = Fz*z; Pz = Fz*Pz*Fz.' + Qz; K = Pz*Hz.'/(Hz*Pz*Hz.' + Rz);
            z = z + K*(obs - Hz*z); Pz = (eye(np+1) - K*Hz)*Pz;
        end
    end
end

function [a, s2] = fitAR(X, p)
n = size(X,2); Z = zeros(size(X,1)*(n-p), p); y = zeros(size(Z,1),1); r = 0;
for k = 1:size(X,1)
    x = X(k,:).'; idx = r + (1:n-p);
    for j = 1:p, Z(idx,j) = x(p+1-j:n-j); end
    y(idx) = x(p+1:n); r = idx(end);
end
a = (Z.'*Z + 1e-6*eye(p)) \ (Z.'*y); s2 = mean((y - Z*a).^2);
end


function al = fitShrink(X, a, Hp)
% per-lead shrinkage alpha_L = <f,d>/<f,f> of the iterated AR forecast, over all origins of all trials
p = numel(a); [nTr, n] = size(X); Fs_ = []; Ts_ = [];
for k = 1:nTr
    x = X(k,:).'; org = p:n-1; Hm = zeros(numel(org), p);
    for j = 1:p, Hm(:,j) = x(org-j+1); end
    Fk = nan(numel(org), Hp); Tk = nan(numel(org), Hp);
    for L = 1:Hp
        nx = Hm*a; Fk(:,L) = nx; Hm = [nx Hm(:,1:end-1)];
        ok = org+L <= n; Tk(ok,L) = x(org(ok)+L);
    end
    Fs_ = [Fs_; Fk]; Ts_ = [Ts_; Tk]; %#ok<AGROW>
end
m = ~isnan(Ts_); Fs_(~m) = 0; Ts_(~m) = 0;
al = min(max(sum(Fs_.*Ts_,1) ./ max(sum(Fs_.^2,1), eps), 0), 1).';
end