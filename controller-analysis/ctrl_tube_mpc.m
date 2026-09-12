function ctrl_tube_mpc(varargin)
%CTRL_TUBE_MPC  STAGE 4c: what a 1-s disturbance PREVIEW buys over the PI controller,
%               and where a REAL forecaster (Lu et al. 2025 benchmark) lands on that curve.
%
% STORY (user, 2026-09-11 rebuild)
%   Stage-4b (ctrl_optimal_control.m) showed the best-possible CAUSAL controller is a
%   receding-horizon MPC that predicts the disturbance as CONSTANT (hold-last). This script
%   asks the next question: if instead the controller PREVIEWS the disturbance ~1 s ahead --
%   but the preview is UNCERTAIN (a tube of width sigma around the mean disturbance) -- how
%   much RMSE does that preview buy over PI, and how does the benefit decay with sigma?
%
%   Then it ANCHORS sigma to reality using the same lab's forecasting benchmark:
%     Lu, Li, Ladd, Matveev, Deole, Shea-Brown, Kutz, Steinmetz.
%     "Benchmarking Probabilistic Time Series Forecasting Models on Neural Activity."
%     NeurIPS 2025 Workshop: Data on the Brain & Mind.   (same widefield rig, 35 Hz, CCF/SVD)
%   Their Fig 1e reports Std(pred dist)/Std(training data) ~ 0.90 at a 1-s horizon for the
%   best models (PatchTST, AR); ~0.83 at 0.5 s. For a calibrated probabilistic forecaster the
%   predictive-std ratio ~ normalized forecast-error std, and our disturbance's climatology
%   std IS sigma_nat -- so a forecaster's operating point on our axis is
%       sigma_model = ratio_at_1s * sigma_nat.
%   Naive (repeat-last) carries no skill vs climatology -> sigma ~ sigma_nat (right edge).
%
% FRAMING NOTES (honest, carried from the change log)
%   * Plant = Stage-4a LTI (delay absorbed). Disturbance d = y_PI - H*u_PI is the SAME
%     plant-inversion disturbance the Stage-4b optimal solve fights; sigma_nat = std(d).
%   * Only the DISTURBANCE preview is uncertain here (full-state feedback assumed) -- the tube
%     is a first-order (DC-gain) constraint-tightening, not a full rigid-tube invariant set.
%   * The sigma axis is a swept knob; the benchmark markers translate a published, same-modality
%     forecastability number onto it. The forecaster is NOT re-fit on our (short, stim-locked)
%     disturbance -- that is a different, data-starved regime and would understate skill.
%
% USAGE
%   ctrl_tube_mpc                      % default session AL_0033_0226_e2 (=m4)
%   ctrl_tube_mpc('sess','AL_0033_0226_e2','nMC',30,'seed',7)
%
% OUT  paper/images/figure4/tubempc_improvement.png  (money plot + benchmark markers)
%      paper/images/figure4/tubempc_example.png      (one rollout: disturbance/tube, tracking, command)
%      controller-analysis/data/ctrl_tube_mpc_<sess>.mat

%% [TMPC-CFG] -------------------------------------------------------------------
P.sess   = 'AL_0033_0226_e2';   % m4
P.Fs     = 35;
P.Hp     = 35;                  % preview / MPC horizon = 1 s
P.ref    = -5;                  % setpoint (%dF/F), project default
P.lam    = 1e-4;                % input regularization (conditioning)
P.uMode  = 'CL';                % actuator ceiling = PI's own usage (fair same-budget)
P.nMC    = 30;                  % Monte-Carlo forecast-error draws per sigma
P.nSig   = 7;                   % sigma grid points 0 .. sigMax
P.sigMul = 1.2;                 % sigMax = sigMul * sigma_nat
P.kTube  = 2.0;                 % tube tightening = kTube-sigma DC-gain margin
P.corrMs = 86;                  % forecast-error temporal smoothing (ms) ~ loop delay
% Lu et al. Fig 1e Std(pred dist)/Std(train) @ 1-s horizon. AR & PatchTST ~0.90 (the paper:
% "PatchTST and AR perform similarly") -> collapsed to one best-model point; Naive = no skill.
P.bench  = struct('name',{'AR / PatchTST','Naive'}, 'ratio',{0.90, 1.00});
P.seed   = 7;
P.exSig  = 0.30;                % sigma for the example rollout figure
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
[h, H, md] = ctrl_plant_markov(L, N);        % y = H*u from rest (delay in states)
[A,B,C,D]  = ssdata(md);
y_PI = S3.AaAbs(pre+1:pre+N).';              % measured PI-controlled ipsi (absolute avg)
u_PI = L.u_CL(pre+1:pre+N); u_PI = u_PI(:);  % PI's own laser command
dbar = y_PI - H*u_PI;                        % plant-inversion disturbance (the sim ground truth)
r    = P.ref*ones(N,1);
tt   = (1:N).'/P.Fs;
sig_nat = std(dbar);
dcg = abs(L.dcgain);

rmse = @(y) sqrt(mean((y - r).^2));          % full-window RMSE (0..dur), %dF/F
RMSE_PI = rmse(y_PI);

fprintf('[TMPC] %s | N=%d (%.1fs) Hp=%d u_max=%.3f | sigma_nat=std(dbar)=%.3f | RMSE_PI=%.3f\n', ...
    P.sess, N, dur, P.Hp, u_max, sig_nat, RMSE_PI);

% correlated-forecast-error kernel (Gaussian smoother, unit-output-std normalized)
ksig = max(1, round(P.corrMs/1000*P.Fs));
kern = exp(-0.5*((-3*ksig:3*ksig)/ksig).^2); kern = kern/norm(kern); % unit-energy -> preserves std

%% [TMPC-SWEEP] improvement vs preview uncertainty sigma -------------------------
sigGrid = linspace(0, P.sigMul*sig_nat, P.nSig);
impMed = nan(1,P.nSig); impLo = nan(1,P.nSig); impHi = nan(1,P.nSig);
for is = 1:P.nSig
    sig = sigGrid(is);
    imp = nan(1,P.nMC);
    for m = 1:P.nMC
        fe = feDraw(N, sig, kern);                 % correlated forecast error, std=sig
        y  = roll(dbar, fe, sig);                  % tube-MPC realized output
        imp(m) = 100*(RMSE_PI - rmse(y))/RMSE_PI;
    end
    impMed(is)=median(imp); impLo(is)=prctile(imp,5); impHi(is)=prctile(imp,95);
end
% clairvoyant ceiling (sigma=0, perfect preview, no tube)
y_cl = roll(dbar, zeros(N,1), 0); imp_cl = 100*(RMSE_PI - rmse(y_cl))/RMSE_PI;
fprintf('[TMPC] clairvoyant improvement = %.1f%% (RMSE %.3f) | @sigma_nat = %.1f%%\n', ...
    imp_cl, rmse(y_cl), interp1(sigGrid,impMed,sig_nat));

%% [TMPC-BENCH] benchmarked-forecaster operating points -------------------------
nb = numel(P.bench);
for b = 1:nb
    P.bench(b).sigma = P.bench(b).ratio * sig_nat;                 % onto our axis
    P.bench(b).imp   = interp1(sigGrid, impMed, P.bench(b).sigma, 'linear','extrap');
    fprintf('   %-9s: ratio=%.2f -> sigma=%.3f %%dF/F -> improvement %.1f%% over PI\n', ...
        P.bench(b).name, P.bench(b).ratio, P.bench(b).sigma, P.bench(b).imp);
end

%% [TMPC-FIG1] money plot -------------------------------------------------------
f1 = figure('Color','w','Position',[80 80 760 560]);
ax=axes(f1); hold(ax,'on');
fill([sigGrid fliplr(sigGrid)],[impLo fliplr(impHi)],[.80 .88 .98], ...
     'EdgeColor','none','FaceAlpha',.7,'DisplayName','5-95% band');
plot(sigGrid, impMed, '-o','Color',[.10 .34 .70],'LineWidth',2.4, ...
     'MarkerFaceColor',[.10 .34 .70],'MarkerSize',6,'DisplayName','tube MPC (median)');
yline(imp_cl,'--','Color',[.90 .45 .10],'LineWidth',1.8,'Label','clairvoyant ceiling', ...
     'LabelHorizontalAlignment','left','FontSize',10,'DisplayName','clairvoyant ceiling');
yline(0,'-','Color',[.4 .4 .4],'LineWidth',1,'Label','PI baseline', ...
     'LabelHorizontalAlignment','left','FontSize',9,'HandleVisibility','off');
xline(sig_nat,':','Color',[.5 .5 .5],'LineWidth',1,'Label','\sigma_{nat}', ...
     'LabelVerticalAlignment','bottom','FontSize',9,'HandleVisibility','off');
% benchmark markers (Lu et al. forecasters translated onto our sigma axis)
bcol = [0.85 0.20 0.45; 0.45 0.45 0.45];        % AR/PatchTST (magenta) / Naive (grey)
blab = [+2.0 -1; -2.4 +1];                       % [dy, halign(-1 left/+1 right)] per marker
halign = {'right','left'};
for b=1:nb
    plot(P.bench(b).sigma, P.bench(b).imp,'p','MarkerSize',15, ...
        'MarkerFaceColor',bcol(b,:),'MarkerEdgeColor','k','LineWidth',.8, ...
        'DisplayName',sprintf('%s (Lu et al.)',P.bench(b).name));
    text(P.bench(b).sigma-0.008*(blab(b,2)<0)+0.008*(blab(b,2)>0), P.bench(b).imp+blab(b,1), ...
        sprintf('%s  %.0f%%',P.bench(b).name,P.bench(b).imp), ...
        'HorizontalAlignment',halign{b},'FontSize',9,'Color',bcol(b,:),'FontWeight','bold');
end
hold(ax,'off'); grid(ax,'on'); box(ax,'on');
xlabel('preview uncertainty  \sigma  (%\DeltaF/F forecast-error std)','FontSize',11);
ylabel('RMSE improvement over PI (%)','FontSize',11);
title(sprintf('What a 1-s disturbance preview buys  (m4, %d trials/\\sigma)',P.nMC),'FontSize',12);
ylim([0 max(impHi)+3]); xlim([0 max(sigGrid)]);
legend('Location','southwest','FontSize',9,'Box','off');
exportgraphics(f1, fullfile(figDir,'tubempc_improvement.png'),'Resolution',300);

%% [TMPC-FIG2] example rollout at exSig -----------------------------------------
fe_ex = feDraw(N, P.exSig, kern);
[y_ex,u_ex] = roll(dbar, fe_ex, P.exSig);
[y_c0,~   ] = roll(dbar, zeros(N,1), 0);
wtube = P.kTube*P.exSig/dcg;
f2 = figure('Color','w','Position',[60 60 1500 420]);
t=tiledlayout(f2,1,3,'Padding','compact','TileSpacing','compact');
title(t,sprintf('Tube-MPC example rollout  m4  (1-s preview, \\sigma=%.2f, tighten=%.2f)', ...
    P.exSig, wtube),'FontSize',12);
nexttile; hold on;
  fill([tt;flipud(tt)],[dbar+P.exSig;flipud(dbar-P.exSig)],[.85 .80 .90], ...
       'EdgeColor','none','FaceAlpha',.6,'DisplayName','tube \pm\sigma');
  plot(tt,dbar,'-','Color',[.35 .15 .45],'LineWidth',2,'DisplayName','mean disturbance');
  plot(tt,dbar+fe_ex,'-','Color',[.65 .45 .75],'LineWidth',1,'DisplayName','previewed (realized)');
  hold off; grid on; box on; xlabel('time (s)'); ylabel('disturbance (%\DeltaF/F)');
  title(sprintf('disturbance & preview tube (\\sigma=%.2f)',P.exSig),'FontSize',10);
  legend('Location','southeast','FontSize',8,'Box','off');
nexttile; hold on;
  plot(tt,y_PI,'-k','LineWidth',2,'DisplayName','PI');
  plot(tt,y_ex,'-','Color',[.10 .34 .70],'LineWidth',2,'DisplayName','tube MPC');
  plot(tt,y_c0,'-','Color',[.90 .35 .10],'LineWidth',1.2,'DisplayName','clairvoyant');
  yline(P.ref,'--','Color',[.1 .6 .1],'LineWidth',1.2,'Label','ref','FontSize',9,'HandleVisibility','off');
  hold off; grid on; box on; xlabel('time (s)'); ylabel('ipsi \DeltaF/F (%)');
  title(sprintf('tracking: PI RMSE %.2f \\rightarrow MPC %.2f',RMSE_PI,rmse(y_ex)),'FontSize',10);
  legend('Location','southeast','FontSize',8,'Box','off');
nexttile; hold on;
  plot(tt,u_PI,'-k','LineWidth',2,'DisplayName','PI');
  plot(tt,u_ex,'-','Color',[.10 .34 .70],'LineWidth',2,'DisplayName','tube MPC');
  yline(u_max,':','Color',[.4 .4 .4],'LineWidth',1,'Label','u_{max}','FontSize',9,'HandleVisibility','off');
  hold off; grid on; box on; xlabel('time (s)'); ylabel('laser command');
  title('command (one-sided 0 \leq u \leq u_{max})','FontSize',10);
  legend('Location','northeast','FontSize',8,'Box','off');
exportgraphics(f2, fullfile(figDir,'tubempc_example.png'),'Resolution',300);

%% [TMPC-SAVE] ------------------------------------------------------------------
R = struct('P',P,'sess',P.sess,'sigGrid',sigGrid,'impMed',impMed,'impLo',impLo, ...
    'impHi',impHi,'imp_cl',imp_cl,'sig_nat',sig_nat,'RMSE_PI',RMSE_PI, ...
    'bench',P.bench,'dbar',dbar,'y_PI',y_PI,'u_PI',u_PI,'u_max',u_max);
save(fullfile(dataDir, sprintf('ctrl_tube_mpc_%s.mat',P.sess)), '-struct','R');
fprintf('[TMPC] saved figs -> %s  (improvement + example)\n', figDir);

% ---- nested: one tube-MPC rollout against realized disturbance dbar -----------
    function [y,u] = roll(dtrue, fe, sig)
        w  = P.kTube*sig/dcg;                      % DC-gain constraint tightening (command units)
        umx = max(u_max - w, 0.05*u_max);          % keep a positive feasible ceiling
        u = zeros(N,1); y = zeros(N,1); x = zeros(size(A,1),1);
        qopt = optimoptions('quadprog','Display','off');
        for k = 1:N
            p = min(P.Hp, N-k+1);
            % free response of the plant from current state over the horizon
            Psi = zeros(p,1); Ai = eye(size(A));
            for ii=1:p, Psi(ii)=C*Ai*x; Ai=Ai*A; end
            dprev = dtrue(k:k+p-1) + fe(k:k+p-1);  % PREVIEWED disturbance over horizon (uncertain)
            Hk = tril(toeplitz(h(1:p)));
            Qk = 2*(Hk.'*Hk + P.lam*eye(p)); Qk=(Qk+Qk.')/2;
            fk = 2*Hk.'*(Psi + dprev - r(k:k+p-1));
            uk = quadprog(Qk, fk, [],[],[],[], zeros(p,1), umx*ones(p,1), [], qopt);
            u(k) = uk(1);                          % apply first move
            y(k) = C*x + D*u(k) + dtrue(k);        % realized output (TRUE disturbance)
            x = A*x + B*u(k);
        end
    end
end

% ---- correlated Gaussian forecast-error draw, std = sig --------------------------
function fe = feDraw(N, sig, kern)
    if sig<=0, fe=zeros(N,1); return; end
    e = randn(N+numel(kern),1);
    e = conv(e, kern, 'same');
    e = e(1:N);
    fe = sig * (e/std(e));
    fe = fe(:);
end
