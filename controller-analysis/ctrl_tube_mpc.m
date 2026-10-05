function ctrl_tube_mpc(varargin)
% ⚠ SUPERSEDED 2026-10-05 by ctrl_mpc_realtrial.m. sig_nat below is the std of the TRIAL-MEAN
%   disturbance (0.15 %dF/F on m4); real single-trial departures have sd 2.7, so every number this
%   script produces is on a ~17x-too-small disturbance. Kept for history only. See RESEARCH 2026-10-05.
%CTRL_TUBE_MPC  STAGE 4c: disturbance-preview tube-MPC vs the PI controller --
%               swept over forecast uncertainty and disturbance-preview length, with the actuator-gain
%               uncertainty MEASURED from open-loop trials, and a real forecaster (Lu et al.
%               2025 benchmark) placed on the curve.
%
% DISTURBANCE. The signal the MPC rejects is the CONTRA-MODEL-generated Global (contra-predicted
%   no-laser ipsi) from the best-transfer deploy session. Its fluctuations sit on the plant-consistent
%   DC level; the PI baseline is reconstructed on the SAME disturbance (its recorded command).
%
% TWO-SIDED AUTHORITY. Holding y at ref=-5 needs a steady u_ref interior of [0,u_max], so the laser
%   can push activity UP (less inhibition) or DOWN (more) about that bias -> not one-sided. A fully
%   clairvoyant controller therefore rejects the (slow) disturbance nearly perfectly.
%
% PREVIEW vs HORIZON. Control/prediction horizon is FIXED at P.Hp (1 s). The disturbance-preview
%   length L_p is swept 0..1 s: within L_p the forecast is known (with lead-dependent error), beyond
%   it the disturbance is held constant. This isolates the value of preview from the horizon length.
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
%      paper/images/figure4/tubempc_horizon.png      (residual ratio vs disturbance-preview length, 0-1 s)
%      paper/images/figure4/tubempc_example.png      (rollout with TUBES around the response)
%      controller-analysis/data/ctrl_tube_mpc_<sess>.mat

%% [TMPC-CFG] -------------------------------------------------------------------
P.sess   = 'AL_0033_0226_e2';   % m4
P.Fs     = 35;
P.Hp     = 35;                  % MPC control/prediction horizon = 1 s (FIXED; preview varies separately)
P.ref    = -5;                  % holds at -5 => steady u_ref interior of [0,u_max] => laser acts BOTH ways
P.lam    = 1e-4;
P.uMode  = 'CL';
P.rmseWin= [1 3];
P.nMC    = 150;                 % high enough for a stable median under the large measured sigma_u
P.nSig   = 7;
P.sigMul = 1.2;
P.kTube  = 2.0;
P.corrMs = 86;
P.sigU   = 'auto';              % INPUT gain uncertainty: 'auto' = measure from OL trials, else a number
P.HpGridS= 0:0.1:1.0;           % DISTURBANCE PREVIEW length (s): 0 .. 1 s in 100 ms steps (control horizon fixed at P.Hp)
P.rho    = [0 0.10; 0.15 0.50; 0.20 0.60; 0.35 0.75; 0.50 0.83; 0.75 0.87; 1.0 0.90];
% FULL Lu et al. field: 12 models + 2 baselines placed by their 1.0 s MWQL relative to Naive
% (Fig 1c middle panel; Naive=1.0=climatology, lower=better forecast). cat: 1 baseline, 2 classical,
% 3 deep-learning, 4 foundation. Values are reads off Fig 1c (paper gives no numeric table); exact
% per-model numbers would come from Ziyu. The realistic curve is flat here, so placement is illustrative.
P.bench  = struct( ...
  'name', {'Naive','Average','Theta','AR','ARIMA','AR-HMM','DeepAR','DLinear','TFT','PatchTST','TiDE','WaveNet','Chronos-ft','Chronos-zs','Moirai-ft','Moirai-zs'}, ...
  'ratio',{ 1.00,   0.90,     0.94,   0.83, 0.84,   0.85,    0.87,    0.86,     0.88, 0.80,      0.81,  0.85,     0.82,        0.98,        0.84,       0.99 }, ...
  'cat',  { 1,      1,        2,      2,    2,      2,       3,       3,        3,    3,         3,     3,        4,           4,           4,          4  } );
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
% Disturbance = CONTRA-MODEL-generated (Global = contra-predicted no-laser ipsi), from the
% best-transfer deploy session. The contra Global is ~zero-mean; the plant model carries a small
% DC mismatch that the plant-inversion term absorbs, so we put the contra FLUCTUATIONS on the
% plant-consistent DC level. PI baseline is reconstructed on the SAME disturbance (its recorded
% command) so PI and MPC face identical d -> honest RMSE ratio.
u_PI  = L.u_CL(pre+1:pre+N); u_PI = u_PI(:);
y_emp = S3.AaAbs(pre+1:pre+N).';               % empirical CL output (reference only)
dPI   = y_emp - H*u_PI;                         % plant-inversion disturbance (plant-consistent, incl DC)
Gc    = mean(S3.Gabs(:,pre+1:pre+N),1).';       % contra-model Global, trial mean
dbar  = (Gc - mean(Gc)) + mean(dPI);            % contra fluctuations on the plant-consistent DC level
y_PI  = H*u_PI + dbar;                           % PI baseline on the contra disturbance (same d as MPC)
r    = P.ref*ones(N,1);
tt   = (1:N).'/P.Fs;   Ts = 1/P.Fs;
dcg  = abs(L.dcgain);

wmask = tt>=P.rmseWin(1) & tt<=P.rmseWin(2);
rmse  = @(y) sqrt(mean((y(wmask) - r(wmask)).^2));
sig_nat = std(dbar(wmask));
RMSE_PI = rmse(y_PI);

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

sigD = sig_nat;                                    % FIXED disturbance realization scale (real contra magnitude)

%% [TMPC-SWEEP-QUALITY] forecast quality vs ABSOLUTE MPC residual -----------------
% Disturbance scale is FIXED at sigma_nat. We sweep the FORECAST ERROR level e (0 = perfect
% forecast .. sigma_nat = Naive/climatology): each trial samples a realization d_real=dbar+sigma_nat*w
% and the controller observes it with per-lead error e*rho(lead). Metric = ABSOLUTE residual RMSE
% (%dF/F) vs the -5 setpoint. Reference lines: PI (deployed) and the clairvoyant floor.
eGrid = linspace(0, sig_nat, P.nSig);              % forecast error level: perfect -> Naive
[qIdeal,qReal,qLo,qHi] = deal(nan(1,P.nSig)); piAbsV = nan(1,P.nMC);
for is = 1:P.nSig
    e = eGrid(is); aI = nan(1,P.nMC); aR = nan(1,P.nMC);
    for m = 1:P.nMC
        rng(P.seed+m); w = drawW(); g = gdraw();               % realization + gain, CRN across e
        if is==1, piAbsV(m) = rmse(y_PI + sigD*w); end          % PI on the same realization
        rng(P.seed+50000+m); aI(m) = rmse(rollR(e, rhoLead, P.Hp, 1, w));  % perfect actuator
        rng(P.seed+50000+m); aR(m) = rmse(rollR(e, rhoLead, P.Hp, g, w));  % + actuator uncertainty
    end
    qIdeal(is)=median(aI); qReal(is)=median(aR); qLo(is)=prctile(aR,5); qHi(is)=prctile(aR,95);
end
PI_abs = median(piAbsV); clair_abs = qIdeal(1);
fprintf('[TMPC] quality: MPC RMSE  perfect %.3f .. Naive %.3f | PI %.3f | clairvoyant %.3f  (%%dF/F)\n', ...
    qReal(1), qReal(end), PI_abs, clair_abs);

% place the Lu et al. models by forecast error e = (MWQL/Naive)*sigma_nat
nb = numel(P.bench);
for b = 1:nb
    P.bench(b).ferr = P.bench(b).ratio * sig_nat;
    P.bench(b).rmse = interp1(eGrid, qReal, P.bench(b).ferr, 'linear','extrap');
end

%% [TMPC-SWEEP-WINDOW] forecast window vs ABSOLUTE MPC residual -------------------
% Fix forecast quality at a good model (PatchTST-level, e=winErr) and disturbance scale sigma_nat;
% sweep the forecast window L_p (0..1 s, 100 ms). idealized = perfect forecast + perfect actuator.
winErr = 0.80 * sig_nat;                            % PatchTST-level forecast for the window sweep
HpG = round(P.HpGridS*P.Fs); nH = numel(HpG);
[wIdeal,wReal,wLo,wHi] = deal(nan(1,nH));
for iH = 1:nH
    Lp = HpG(iH); aI = nan(1,P.nMC); aR = nan(1,P.nMC);
    for m = 1:P.nMC       % SAME CRN base as the quality sweep -> the two figures agree at shared configs
        rng(P.seed+m); w = drawW(); g = gdraw();
        rng(P.seed+50000+m); aI(m) = rmse(rollR(0,      rhoLead, Lp, 1, w));  % perfect forecast+actuator
        rng(P.seed+50000+m); aR(m) = rmse(rollR(winErr, rhoLead, Lp, g, w));  % model forecast + sigma_u
    end
    wIdeal(iH)=median(aI); wReal(iH)=median(aR); wLo(iH)=prctile(aR,5); wHi(iH)=prctile(aR,95);
end
nrst = @(v) interp1(P.HpGridS, 1:numel(P.HpGridS), v, 'nearest');   % robust index (avoids float ==)
fprintf('[TMPC] window: MPC RMSE @0 %.3f | @200ms %.3f | @1s %.3f  (ideal @1s %.3f) | PI %.3f\n', ...
    wReal(nrst(0)), wReal(nrst(0.2)), wReal(end), wIdeal(end), PI_abs);

ymax = 1.18*PI_abs;                                % common y-scale (PI is the top reference)
catcol=[.45 .45 .45; .20 .45 .75; .15 .60 .30; .80 .40 .10];   % baseline / classical / DL / foundation
catname={'baseline','classical','deep learning','foundation (Lu et al.)'};

%% [TMPC-FIG1] forecast quality vs ABSOLUTE MPC residual -------------------------
xq = eGrid/sig_nat;                                % forecast error relative to Naive: 0=perfect .. 1=Naive
f1 = figure('Color','w','Position',[80 80 800 560]); ax=axes(f1); hold(ax,'on');
fill([xq fliplr(xq)],[qLo fliplr(qHi)],[.86 .90 .84],'EdgeColor','none','FaceAlpha',.55,'DisplayName','realization spread (5-95%)');
yline(PI_abs,'-','Color',[.30 .30 .34],'LineWidth',1.6,'Label','PI controller','LabelHorizontalAlignment','right','FontSize',10,'HandleVisibility','off');
yline(clair_abs,':','Color',[.1 .6 .1],'LineWidth',1.3,'Label','clairvoyant floor','LabelHorizontalAlignment','left','FontSize',9,'HandleVisibility','off');
plot(xq,qIdeal,'--','Color',[.90 .55 .20],'LineWidth',1.8,'DisplayName','perfect actuator (idealized)');
plot(xq,qReal,'-o','Color',[.15 .45 .72],'LineWidth',2.4,'MarkerFaceColor',[.15 .45 .72],'MarkerSize',6, ...
     'DisplayName',sprintf('realistic (measured \\sigma_u=%.0f%%)',100*P.sigU));
xb=[P.bench.ratio]; yb=[P.bench.rmse]; cc=[P.bench.cat];
for c=1:4
    idx = cc==c;
    plot(xb(idx),yb(idx),'o','MarkerSize',8,'MarkerFaceColor',catcol(c,:),'MarkerEdgeColor','k','LineWidth',.6,'DisplayName',catname{c});
end
for nm = {'PatchTST','Naive'}
    b = strcmp({P.bench.name},nm{1});
    text(xb(b), yb(b)+0.05*ymax, nm{1},'HorizontalAlignment','center','FontSize',8.5,'FontWeight','bold','Color',[.1 .1 .1]);
end
hold(ax,'off'); grid on; box on;
xlabel('forecast error   (\times Naive:  0 = perfect,  1 = Naive)','FontSize',11);
ylabel('MPC residual RMSE  (%\DeltaF/F)','FontSize',11);
title({'Forecast quality vs MPC residual  (m4, realization-based)', sprintf('disturbance fixed at \\sigma_{nat}; absolute RMSE vs -5, +%.0f..+%.0f s',P.rmseWin(1),P.rmseWin(2))},'FontSize',12);
ylim([0 ymax]); xlim([0 1]);
legend('Location','northwest','FontSize',8.5,'Box','off');
exportgraphics(f1, fullfile(figDir,'tubempc_improvement.png'),'Resolution',300);

%% [TMPC-FIG2] forecast window vs ABSOLUTE MPC residual --------------------------
xs=P.HpGridS;
f3 = figure('Color','w','Position',[100 100 800 560]); ax3=axes(f3); hold(ax3,'on');
fill([xs fliplr(xs)],[wLo fliplr(wHi)],[.86 .90 .84],'EdgeColor','none','FaceAlpha',.55,'DisplayName','realization spread (5-95%)');
yline(PI_abs,'-','Color',[.30 .30 .34],'LineWidth',1.6,'Label','PI controller','LabelHorizontalAlignment','center','FontSize',10,'HandleVisibility','off');
yline(clair_abs,':','Color',[.1 .6 .1],'LineWidth',1.3,'Label','clairvoyant floor','LabelHorizontalAlignment','left','FontSize',9,'HandleVisibility','off');
plot(xs,wIdeal,'--','Color',[.90 .55 .20],'LineWidth',1.8,'DisplayName','perfect forecast + actuator (idealized)');
plot(xs,wReal,'-o','Color',[.15 .45 .72],'LineWidth',2.4,'MarkerFaceColor',[.15 .45 .72],'MarkerSize',6,'DisplayName',sprintf('realistic (PatchTST-level forecast + \\sigma_u=%.0f%%)',100*P.sigU));
xline(0.086,':','Color',[.6 .3 .3],'LineWidth',1,'Label','loop delay','FontSize',8,'HandleVisibility','off');
hold(ax3,'off'); grid on; box on;
xlabel('forecast window  L_p  (s)','FontSize',11);
ylabel('MPC residual RMSE  (%\DeltaF/F)','FontSize',11);
title({'Forecast window vs MPC residual  (m4, realization-based)','1 s control horizon fixed; how far ahead the sampled disturbance is seen'},'FontSize',12);
ylim([0 ymax]); xlim([0 1.0]);
legend('Location','northeast','FontSize',8.5,'Box','off');
exportgraphics(f3, fullfile(figDir,'tubempc_horizon.png'),'Resolution',300);

%% [TMPC-SAVE] ------------------------------------------------------------------
R = struct('P',P,'sess',P.sess,'eGrid',eGrid,'qIdeal',qIdeal,'qReal',qReal,'qLo',qLo,'qHi',qHi, ...
    'HpGridS',P.HpGridS,'wIdeal',wIdeal,'wReal',wReal,'wLo',wLo,'wHi',wHi,'PI_abs',PI_abs,'clair_abs',clair_abs, ...
    'sig_nat',sig_nat,'sig_u',P.sigU,'RMSE_PI',RMSE_PI,'bench',P.bench,'dbar',dbar,'y_PI',y_PI,'u_PI',u_PI,'u_max',u_max);
save(fullfile(dataDir, sprintf('ctrl_tube_mpc_%s.mat',P.sess)), '-struct','R');
fprintf('[TMPC] saved 2 figs -> %s\n', figDir);

% ---- nested: smoothed unit-variance disturbance departure realization ----------
    function wout = drawW()
        mk = numel(kern);
        zz = conv(randn(N+2*mk,1), kern, 'same'); zz = zz(mk+1:mk+N);
        wout = zz / std(zz);                     % unit-variance smooth realization (length N)
    end

% ---- nested: forecast observation error (std at lead i = errLevel*rhoVec(i)) ----
    function fe = feError(np, errLevel, rhoVec)
        if errLevel<=0, fe = zeros(np,1); return; end
        mk = numel(kern);
        zz = conv(randn(np+2*mk,1), kern, 'same'); zz = zz(mk+1:mk+np);
        fe = errLevel * rhoVec(:) .* zz(:);
    end

% ---- nested: one REALIZATION-BASED tube-MPC rollout ----------------------------
    function y = rollR(errLevel, rhoVec, Lp, gfac, w)
        % Disturbance realization d_real = dbar + sigD*w (sigD fixed = sigma_nat). Within the forecast
        % window Lp the controller OBSERVES the true realization plus forecast error (std errLevel*rho);
        % beyond Lp it uses the mean forecast dbar. Control horizon fixed at P.Hp. Plant feels d_real.
        dreal = dbar + sigD * w;
        tubeW = P.kTube*errLevel/dcg;  umx = max(u_max - tubeW, 0.05*u_max);
        Be = gfac*B;  De = gfac*D;               % realized actuator gain (gfac=1 nominal, lognormal>0)
        y = zeros(N,1); x = zeros(size(A,1),1); uk1 = 0;
        qopt = optimoptions('quadprog','Display','off');
        for k = 1:N
            p  = min(P.Hp, N-k+1);
            np = min(Lp,  p);
            dprev = dbar(k:k+p-1);               % mean forecast (used beyond the window)
            if np >= 1
                dprev(1:np) = dreal(k:k+np-1) + feError(np, errLevel, rhoVec(1:np));  % observe truth + error
            end
            Psi = zeros(p,1); Ai = eye(size(A));
            for ii=1:p, Psi(ii)=C*Ai*x; Ai=Ai*A; end
            Hk = tril(toeplitz(h(1:p)));
            Qk = 2*(Hk.'*Hk + P.lam*eye(p)); Qk=(Qk+Qk.')/2;
            fk = 2*Hk.'*(Psi + dprev - r(k:k+p-1));
            uk = quadprog(Qk, fk, [],[],[],[], zeros(p,1), umx*ones(p,1), [], qopt);
            uk1 = uk(1);
            y(k) = C*x + De*uk1 + dreal(k);
            x = A*x + Be*uk1;
        end
    end
end
