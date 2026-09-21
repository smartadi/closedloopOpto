function ctrl_tube_mpc(varargin)
%CTRL_TUBE_MPC  STAGE 4c: disturbance-preview tube-MPC vs the PI controller --
%               swept over forecast uncertainty and preview horizon, with the actuator-gain
%               uncertainty MEASURED from open-loop trials, and a real forecaster (Lu et al.
%               2025 benchmark) placed on the curve.
%
% METRIC (2026-09-15, user): residual disturbance-rejection RMSE as a RATIO to the PI controller,
%   rho_r = RMSE_MPC / RMSE_PI   (PI = 1; lower is better; 0.30 means "70% less error than PI").
%   Reported on the +1..+3 s window (skips the irreducible onset transient). The ratio is clearer
%   than a "% improvement" that saturates at a misleading 100%.
%
% WHY PERFECT PREVIEW IS NOT PERFECT. Two limits survive even with a flawless disturbance forecast:
%   (i) the actuator dynamics/delay must be respected (in H); over the slow settled window they do
%   not bite, but (ii) the laser->activity GAIN is state dependent and varies trial to trial. We
%   MEASURE that variability from the open-loop trials (per-trial gain scatter, CV ~ 0.35) and carry
%   it as a multiplicative gain error g~N(0,sigma_u^2) on the REALIZED plant, the controller planning
%   with the nominal plant. So every "realistic" curve sits above 0 no matter how good the forecast.
%
% FORECAST-ERROR MODEL. Preview error std at lead tau = f_skill * sigma_nat * rho(tau), where rho is
%   Lu et al. Fig 1e Std(pred)/Std(train) vs lead time on the same widefield modality (rho~0.1 @0s,
%   0.6 @0.2s, 0.83 @0.5s, 0.90 @1s). Near term nearly known, far term climatological.
%
%     Lu, Li, Ladd, Matveev, Deole, Shea-Brown, Kutz, Steinmetz. "Benchmarking Probabilistic Time
%     Series Forecasting Models on Neural Activity." NeurIPS 2025 Workshop: Data on the Brain & Mind.
%
% OUT  paper/images/figure4/tubempc_improvement.png  (residual ratio vs forecast sigma)
%      paper/images/figure4/tubempc_horizon.png      (residual ratio vs preview horizon, capped 1 s)
%      paper/images/figure4/tubempc_example.png      (rollout with TUBES around the response)
%      controller-analysis/data/ctrl_tube_mpc_<sess>.mat

%% [TMPC-CFG] -------------------------------------------------------------------
P.sess   = 'AL_0033_0226_e2';   % m4
P.Fs     = 35;
P.Hp     = 35;                  % nominal preview / MPC horizon = 1 s
P.ref    = -5;
P.lam    = 1e-4;
P.uMode  = 'CL';
P.rmseWin= [1 3];
P.nMC    = 150;                 % high enough for a stable median under the large measured sigma_u
P.nSig   = 7;
P.sigMul = 1.2;
P.kTube  = 2.0;
P.corrMs = 86;
P.sigU   = 'auto';              % INPUT gain uncertainty: 'auto' = measure from OL trials, else a number
P.HpGridS= [0.15 0.20 0.30 0.50 0.75 1.0];        % preview horizons (s) -- CAPPED at 1 s
P.rho    = [0 0.10; 0.15 0.50; 0.20 0.60; 0.35 0.75; 0.50 0.83; 0.75 0.87; 1.0 0.90];
P.bench  = struct('name',{'AR / PatchTST','Naive'}, 'ratio',{0.90, 1.00});
P.seed   = 7;
P.exSig  = 0.30;
P.exNMC  = 60;                  % rollouts for the response-tube example
for a=1:2:numel(varargin); P.(varargin{a})=varargin{a+1}; end
rng(P.seed);

here = fileparts(mfilename('fullpath'));
if isempty(here) || contains(here,tempdir,'IgnoreCase',true)
    here = fullfile(pwd,'controller-analysis'); if ~exist(here,'dir'); here = pwd; end
end
dataDir = fullfile(here,'data');
figDir  = fullfile(here,'..','paper','images','figure4'); if ~exist(figDir,'dir'); mkdir(figDir); end
addpath(genpath(fullfile(here,'..','utils')));

%% [TMPC-LOAD] plant + PI trial + disturbance -----------------------------------
L  = load(fullfile(dataDir, sprintf('ctrl_lti_%s.mat', P.sess)));
S3 = load(fullfile(dataDir, sprintf('ctrl_ols_cl_deploy_%s.mat', P.sess)));
dur = S3.dur; pre = S3.pre; N = round(dur*P.Fs);
switch upper(P.uMode)
    case 'CL', u_max = L.uMaxCL;   case 'HW', u_max = L.uMaxHW;
    otherwise, error('bad uMode');
end
[h, H, md] = ctrl_plant_markov(L, N);
[A,B,C,D]  = ssdata(md);
y_PI = S3.AaAbs(pre+1:pre+N).';
u_PI = L.u_CL(pre+1:pre+N); u_PI = u_PI(:);
dbar = y_PI - H*u_PI;
r    = P.ref*ones(N,1);
tt   = (1:N).'/P.Fs;   Ts = 1/P.Fs;
dcg  = abs(L.dcgain);

wmask = tt>=P.rmseWin(1) & tt<=P.rmseWin(2);
rmse  = @(y) sqrt(mean((y(wmask) - r(wmask)).^2));
sig_nat = std(dbar(wmask));
RMSE_PI = rmse(y_PI);
ratiofun = @(y) rmse(y)/RMSE_PI;                 % residual RMSE relative to PI (lower is better)

%% [TMPC-SIGU] actuator-gain uncertainty MEASURED from open-loop trials ----------
src = 'set by caller';
if ischar(P.sigU) && strcmpi(P.sigU,'auto')
    sig_u = 0.35; src = 'default (OL cache missing)';
    try
        O = load(fullfile(dataDir, sprintf('ctrl_ols_ol_stimblind_%s.mat', P.sess)));
        Aol = O.A_tr(:, pre+1:end);  mu = O.Aa(pre+1:end).';        % per-trial OL responses & mean
        s   = (Aol*mu)/(mu.'*mu);                                    % per-trial best-fit gain scale
        sig_u = std(s)/mean(s); src = sprintf('measured, OL n=%d trials', size(O.A_tr,1));
    catch, end
    P.sigU = sig_u;
end
fprintf('[TMPC] %s | Hp=%d | win [%.1f,%.1f]s | sigma_nat=%.3f | RMSE_PI=%.3f | sigma_u=%.2f (%s)\n', ...
    P.sess, P.Hp, P.rmseWin(1), P.rmseWin(2), sig_nat, RMSE_PI, P.sigU, src);

% lognormal actuator-gain draw (mean 1, CV = sigma_u, always positive -> no sign flips)
sigU_ln = sqrt(log(1+P.sigU^2));
gdraw = @() exp(sigU_ln*randn - 0.5*sigU_ln^2);

% forecast-error smoothing kernel + per-lead skill ratio rho(lead)
ksig = max(1, round(P.corrMs/1000*P.Fs));
kern = exp(-0.5*((-3*ksig:3*ksig)/ksig).^2); kern = kern/norm(kern);
maxHp = max([P.Hp, round(P.HpGridS*P.Fs)]);
rhoLead  = min(max(interp1(P.rho(:,1), P.rho(:,2), (0:maxHp-1)*Ts, 'linear','extrap'),0),1.0).';
onesLead = ones(maxHp,1);

%% [TMPC-SWEEP-SIGMA] residual ratio vs forecast uncertainty ---------------------
% idealized = perfect actuator (sigma_u=0); realistic = measured sigma_u ALWAYS on.
sigGrid = linspace(0, P.sigMul*sig_nat, P.nSig);
[rIdeal,rReal,rRealLo,rRealHi] = deal(nan(1,P.nSig));
for is = 1:P.nSig
    sig = sigGrid(is);
    a0 = nan(1,P.nMC); aU = nan(1,P.nMC);
    for m = 1:P.nMC       % common random numbers across sigma (variance reduction -> smooth curve)
        rng(P.seed+m);           a0(m) = ratiofun( roll(dbar, sig, onesLead, P.Hp, 1) );
        rng(P.seed+10000+m); gf=gdraw(); aU(m) = ratiofun( roll(dbar, sig, onesLead, P.Hp, gf) );
    end
    rIdeal(is)=median(a0);
    rReal(is)=median(aU); rRealLo(is)=prctile(aU,5); rRealHi(is)=prctile(aU,95);
end
fprintf('[TMPC] residual ratio @sigma=0: ideal %.2f  realistic(+sigma_u) %.2f | @sigma_nat realistic %.2f\n', ...
    rIdeal(1), rReal(1), interp1(sigGrid,rReal,sig_nat));

% benchmark operating points on the realistic curve
nb = numel(P.bench);
for b = 1:nb
    P.bench(b).sigma = P.bench(b).ratio * sig_nat;
    P.bench(b).ratio_r = interp1(sigGrid, rReal, P.bench(b).sigma, 'linear','extrap');
    fprintf('   %-13s sigma=%.3f -> residual %.2f x PI  (%.0f%% less error)\n', ...
        P.bench(b).name, P.bench(b).sigma, P.bench(b).ratio_r, 100*(1-P.bench(b).ratio_r));
end

%% [TMPC-SWEEP-HORIZON] residual ratio vs preview horizon (capped 1 s) -----------
HpG = round(P.HpGridS*P.Fs); nH = numel(HpG);
[hIdeal,hReal,hRealLo,hRealHi] = deal(nan(1,nH));
for iH = 1:nH
    Hp_i = HpG(iH);
    hIdeal(iH) = ratiofun( roll(dbar, 0, onesLead, Hp_i, 1) );      % perfect preview, perfect actuator
    aU = nan(1,P.nMC);
    for m = 1:P.nMC       % common random numbers across horizons
        rng(P.seed+20000+m); gf=gdraw(); aU(m) = ratiofun( roll(dbar, sig_nat, rhoLead, Hp_i, gf) );
    end
    hReal(iH)=median(aU); hRealLo(iH)=prctile(aU,5); hRealHi(iH)=prctile(aU,95);
end
fprintf('[TMPC] horizon: realistic residual @100ms %.2f | @200ms %.2f | @1s %.2f  (ideal @1s %.2f)\n', ...
    hReal(1), hReal(P.HpGridS==0.2), hReal(end), hIdeal(end));

%% [TMPC-FIG1] residual ratio vs forecast uncertainty ---------------------------
f1 = figure('Color','w','Position',[80 80 780 560]); ax=axes(f1); hold(ax,'on');
fill([sigGrid fliplr(sigGrid)],[rRealLo fliplr(rRealHi)],[.86 .90 .84],'EdgeColor','none','FaceAlpha',.6,'DisplayName','5-95% band');
yline(1,'-','Color',[.30 .30 .34],'LineWidth',1.6,'Label','PI controller','LabelHorizontalAlignment','left','FontSize',10,'HandleVisibility','off');
plot(sigGrid,rIdeal,'--','Color',[.90 .55 .20],'LineWidth',1.8,'DisplayName','perfect actuator (idealized)');
plot(sigGrid,rReal,'-o','Color',[.15 .45 .72],'LineWidth',2.4,'MarkerFaceColor',[.15 .45 .72],'MarkerSize',6, ...
     'DisplayName',sprintf('realistic (measured \\sigma_u=%.0f%%)',100*P.sigU));
xline(sig_nat,':','Color',[.5 .5 .5],'LineWidth',1,'Label','\sigma_{nat}','LabelVerticalAlignment','bottom','FontSize',9,'HandleVisibility','off');
bcol=[0.85 0.20 0.45;0.45 0.45 0.45]; halign={'right','left'}; dx=[-.006 .006];
for b=1:nb
    plot(P.bench(b).sigma,P.bench(b).ratio_r,'p','MarkerSize',15,'MarkerFaceColor',bcol(b,:),'MarkerEdgeColor','k','LineWidth',.8, ...
        'DisplayName',sprintf('%s (Lu et al.)',P.bench(b).name));
    text(P.bench(b).sigma+dx(b),P.bench(b).ratio_r+0.03,sprintf('%s',P.bench(b).name),'HorizontalAlignment',halign{b},'FontSize',9,'Color',bcol(b,:),'FontWeight','bold');
end
hold(ax,'off'); grid on; box on;
xlabel('forecast uncertainty  \sigma  (%\DeltaF/F)','FontSize',11);
ylabel('residual RMSE  (\div PI,  lower = better)','FontSize',11);
title({'Disturbance-rejection residual vs forecast quality  (m4)', sprintf('RMSE ratio to PI, +%.0f..+%.0f s window',P.rmseWin(1),P.rmseWin(2))},'FontSize',12);
ylim([0 1.12]); xlim([0 max(sigGrid)]);
legend('Location','northwest','FontSize',8.5,'Box','off');
exportgraphics(f1, fullfile(figDir,'tubempc_improvement.png'),'Resolution',300);

%% [TMPC-FIG3] residual ratio vs preview horizon (capped 1 s) --------------------
f3 = figure('Color','w','Position',[100 100 780 560]); ax3=axes(f3); hold(ax3,'on');
xs=P.HpGridS;
fill([xs fliplr(xs)],[hRealLo fliplr(hRealHi)],[.86 .90 .84],'EdgeColor','none','FaceAlpha',.6,'DisplayName','5-95% band');
yline(1,'-','Color',[.30 .30 .34],'LineWidth',1.6,'Label','PI controller','LabelHorizontalAlignment','left','FontSize',10,'HandleVisibility','off');
plot(xs,hIdeal,'--','Color',[.90 .55 .20],'LineWidth',1.8,'DisplayName','perfect preview & actuator (idealized)');
plot(xs,hReal,'-o','Color',[.15 .45 .72],'LineWidth',2.4,'MarkerFaceColor',[.15 .45 .72],'MarkerSize',6,'DisplayName',sprintf('realistic (Lu et al. \\rho + \\sigma_u=%.0f%%)',100*P.sigU));
xline(0.086,':','Color',[.6 .3 .3],'LineWidth',1,'Label','loop delay','FontSize',8,'HandleVisibility','off');
xline(0.2,':','Color',[.4 .4 .4],'LineWidth',1,'Label','200 ms','FontSize',9,'HandleVisibility','off');
hold(ax3,'off'); grid on; box on;
xlabel('preview horizon  H_p  (s)','FontSize',11);
ylabel('residual RMSE  (\div PI,  lower = better)','FontSize',11);
title({'Residual vs how far ahead the controller previews  (m4)','forecast error grows with lead time (Lu et al. \rho); horizon capped at 1 s'},'FontSize',12);
ylim([0 1.12]); xlim([0 1.0]);
legend('Location','northeast','FontSize',8.5,'Box','off');
exportgraphics(f3, fullfile(figDir,'tubempc_horizon.png'),'Resolution',300);

%% [TMPC-FIG2] example rollout with TUBES around the response --------------------
Yr = nan(P.exNMC,N); Ur = nan(P.exNMC,N); resid_i = nan(P.exNMC,1);
for m=1:P.exNMC
    [ym,um] = roll(dbar, sig_nat, rhoLead, P.Hp, gdraw());        % realistic ensemble
    Yr(m,:)=ym.'; Ur(m,:)=um.'; resid_i(m)=ratiofun(ym);
end
yTube = prctile(Yr,[5 50 95]); uTube = prctile(Ur,[5 50 95]);
y_cl = roll(dbar, 0, onesLead, P.Hp, 1);                          % idealized clairvoyant
band = sig_nat*rhoLead(P.Hp);                                     % 1-s-ahead forecast band width
resid_med = median(resid_i);                                     % typical PER-TRIAL residual (not of the median trace)
f2 = figure('Color','w','Position',[60 60 1500 430]);
t=tiledlayout(f2,1,3,'Padding','compact','TileSpacing','compact');
title(t,sprintf('Tube-MPC rollout  m4  (1-s preview, Lu et al. forecast + measured \\sigma_u=%.0f%%, %d trials)',100*P.sigU,P.exNMC),'FontSize',12);
nexttile; hold on;
  fill([tt;flipud(tt)],[dbar+band;flipud(dbar-band)],[.85 .80 .90],'EdgeColor','none','FaceAlpha',.55,'DisplayName','1-s forecast band');
  plot(tt,dbar,'-','Color',[.35 .15 .45],'LineWidth',2,'DisplayName','disturbance');
  hold off; grid on; box on; xlabel('time (s)'); ylabel('disturbance (%\DeltaF/F)');
  title('disturbance & forecast band','FontSize',10); legend('Location','southeast','FontSize',8,'Box','off');
nexttile; hold on;
  fill([tt;flipud(tt)],[yTube(3,:).';flipud(yTube(1,:).')],[.80 .88 .96],'EdgeColor','none','FaceAlpha',.75,'DisplayName','MPC response tube (5-95%)');
  plot(tt,y_PI,'-k','LineWidth',2,'DisplayName','PI');
  plot(tt,yTube(2,:),'-','Color',[.15 .45 .72],'LineWidth',2,'DisplayName','tube MPC (median)');
  plot(tt,y_cl,'-','Color',[.90 .45 .10],'LineWidth',1.2,'DisplayName','clairvoyant (idealized)');
  yline(P.ref,'--','Color',[.1 .6 .1],'LineWidth',1.2,'Label','ref','FontSize',9,'HandleVisibility','off');
  hold off; grid on; box on; xlabel('time (s)'); ylabel('ipsi \DeltaF/F (%)');
  title(sprintf('response: residual %.2f\\times PI  (+%.0f..+%.0fs)',resid_med,P.rmseWin(1),P.rmseWin(2)),'FontSize',10);
  legend('Location','southeast','FontSize',8,'Box','off');
nexttile; hold on;
  fill([tt;flipud(tt)],[uTube(3,:).';flipud(uTube(1,:).')],[.80 .88 .96],'EdgeColor','none','FaceAlpha',.75,'DisplayName','MPC command tube');
  plot(tt,u_PI,'-k','LineWidth',2,'DisplayName','PI');
  plot(tt,uTube(2,:),'-','Color',[.15 .45 .72],'LineWidth',2,'DisplayName','tube MPC (median)');
  yline(u_max,':','Color',[.4 .4 .4],'LineWidth',1,'Label','u_{max}','FontSize',9,'HandleVisibility','off');
  hold off; grid on; box on; xlabel('time (s)'); ylabel('laser command');
  title('command (one-sided 0 \leq u \leq u_{max})','FontSize',10); legend('Location','northeast','FontSize',8,'Box','off');
exportgraphics(f2, fullfile(figDir,'tubempc_example.png'),'Resolution',300);

%% [TMPC-SAVE] ------------------------------------------------------------------
R = struct('P',P,'sess',P.sess,'sigGrid',sigGrid,'rIdeal',rIdeal,'rReal',rReal,'rRealLo',rRealLo,'rRealHi',rRealHi, ...
    'HpGridS',P.HpGridS,'hIdeal',hIdeal,'hReal',hReal,'sig_nat',sig_nat,'sig_u',P.sigU,'RMSE_PI',RMSE_PI, ...
    'bench',P.bench,'dbar',dbar,'y_PI',y_PI,'u_PI',u_PI,'u_max',u_max);
save(fullfile(dataDir, sprintf('ctrl_tube_mpc_%s.mat',P.sess)), '-struct','R');
fprintf('[TMPC] saved figs -> %s\n', figDir);

% ---- nested: one tube-MPC rollout --------------------------------------------
    function [y,u] = roll(dtrue, sigLevel, rhoVec, Hp_use, gfac)
        w   = P.kTube*sigLevel/dcg;
        umx = max(u_max - w, 0.05*u_max);
        Be = gfac*B;  De = gfac*D;             % realized actuator gain (gfac=1 nominal, lognormal>0)
        u = zeros(N,1); y = zeros(N,1); x = zeros(size(A,1),1);
        qopt = optimoptions('quadprog','Display','off');
        for k = 1:N
            p = min(Hp_use, N-k+1);
            Psi = zeros(p,1); Ai = eye(size(A));
            for ii=1:p, Psi(ii)=C*Ai*x; Ai=Ai*A; end
            e = feStep(p, sigLevel, rhoVec(1:p), kern);
            dprev = dtrue(k:k+p-1) + e;
            Hk = tril(toeplitz(h(1:p)));
            Qk = 2*(Hk.'*Hk + P.lam*eye(p)); Qk=(Qk+Qk.')/2;
            fk = 2*Hk.'*(Psi + dprev - r(k:k+p-1));
            uk = quadprog(Qk, fk, [],[],[],[], zeros(p,1), umx*ones(p,1), [], qopt);
            u(k) = uk(1);
            y(k) = C*x + De*u(k) + dtrue(k);
            x = A*x + Be*u(k);
        end
    end
end

% ---- per-step forecast error: std at lead i = sigLevel*rhoVec(i) ----------------
function e = feStep(p, sigLevel, rhoVec, kern)
    if sigLevel<=0, e=zeros(p,1); return; end
    m = numel(kern);
    z = conv(randn(p+2*m,1), kern, 'same');
    z = z(m+1:m+p);
    e = sigLevel * rhoVec(:) .* z(:);
end
