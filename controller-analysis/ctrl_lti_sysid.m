% ctrl_lti_sysid.m -- STAGE 4a: identify an LTI actuator model  u (laser) -> y (ipsi dF/F).
%
% GOAL (user Objective 2 groundwork, 2026-07-20)
%   Learn the input->output response of the ipsi laser site from the OPEN-LOOP trial-averaged
%   data, as a low-order LTI system. The OL input is a designed persistently-exciting command
%   (step ~0.6 + ~15 Hz dither), so the trial-averaged (u_OL, y_OL) pair is a clean SISO record
%   for identification. This LTI is the plant model that Stage 4b uses to compute the BEST-POSSIBLE
%   (constrained-optimal) control and compare it to the PI controller the animal actually ran.
%
% METHOD
%   1. y_OL = OL trial-averaged ipsi response (baseline-sub), from the Stage-2 cache.
%   2. u_OL = OL trial-averaged laser command on the same peri-stim grid (from d.inpVals).
%   3. Fit discrete state-space models (ssest, Ts=1/Fs) for nx = 1..NXMAX with an estimated input
%      delay; pick the order with the best simulation NRMSE fit (guard against overfit via AICc).
%   4. Validate: overlay measured vs simulated y_OL; report fit%, R^2, DC gain, poles.
%   5. Save the chosen discrete LTI (A,B,C,D,Ts) + u budget for Stage 4b (optimal control).
%
% PREREQS  Stage 2 cache for this session; `mouse`,`fields` in the workspace.
% SECTIONS: [CFG] [LOAD] [FIT] [VALIDATE] [FIG] [SAVE]

%% [CTRL-LTI-CFG] ---------------------------------------------------------------
selField = 4;
Fs       = 35;
NXMAX    = 5;             % try state orders 1..NXMAX
rng(7,'twister');

assert(exist('mouse','var') && exist('fields','var'), '[CTRL-LTI] run load_sessions.m first.');
here = fileparts(mfilename('fullpath'));
if isempty(here) || contains(here,tempdir,'IgnoreCase',true) || contains(here,'Editor_','IgnoreCase',true)
    here = fullfile(pwd,'controller-analysis'); if ~exist(here,'dir'); here = pwd; end
end
dataDir = fullfile(here,'data');
fig_dir = fullfile(here,'..','paper','images','predictor_saga'); if ~exist(fig_dir,'dir'); mkdir(fig_dir); end

%% [CTRL-LTI-LOAD] OL input/output pair ----------------------------------------
fld = fields{selField};
d_s = mouse.(fld).d;  data = mouse.(fld).data;
mn = mouse.(fld).mn; td = mouse.(fld).td; en = mouse.(fld).en;
sess_tag = sprintf('%s_%s%s_e%d', mn, td(6:7), td(9:10), en);

S2 = load(fullfile(dataDir, sprintf('ctrl_ols_ol_stimblind_%s.mat', sess_tag)));
rel = S2.rel(:).';  pre = S2.pre;  trel = rel/Fs;  y_OL = S2.Aa(:);     % OL Actual (baseline-sub)

% TRUE input = the sine-carrier AMPLITUDE (early sessions) or the raw value (later sessions).
% Must be done at the NATIVE rate: at 35 Hz the 50 Hz carrier aliases into a fake "dither".
[uAmpFull, uinfo] = cp_laser_amplitude(d_s.inpVals, d_s.inpTime);
fprintf('[CTRL-LTI] laser command mode = %s (carrier %.1f Hz, %.0f%% of AC power, period %d samp)\n', ...
    uinfo.mode, uinfo.carrier_hz, 100*uinfo.power_frac, uinfo.period_samples);

nc = data.nc(:);  ol_starts = sort(d_s.stimStarts(nc));
U = zeros(numel(ol_starts), numel(trel));
for j = 1:numel(ol_starts)
    U(j,:) = interp1(d_s.inpTime, uAmpFull, ol_starts(j)+trel, 'linear', 0);
end
u_OL = mean(U,1).';  u_OL = u_OL - mean(u_OL(1:pre));                   % baseline-sub input (pre ~ 0)
uAbs = mean(U,1).';                                                     % absolute trial-avg amplitude
fprintf('[CTRL-LTI] %s | %d OL trials | u step amplitude=%.3f, y trough=%.2f%%\n', ...
    sess_tag, numel(ol_starts), mean(u_OL(pre+1:end)), min(y_OL));

%% [CTRL-LTI-FIT] identify LTI  u -> y ------------------------------------------
% u is now the true amplitude (a clean step), so no prefilter is needed -- the earlier 6 Hz LP was
% only compensating for the aliased carrier. Select by AICc (parsimony) so we don't pick up
% lightly-damped resonant poles that a controller would spuriously exploit.
uf = u_OL;  yf = y_OL;
z = iddata(yf, uf, 1/Fs);                            % SISO io data
nk = delayest(z, 2, 2, 0, 20);                       % input delay (samples), search 0..20
fprintf('[CTRL-LTI] estimated input delay = %d samples (%.3f s)\n', nk, nk/Fs);

opt = ssestOptions('Focus','simulation','EnforceStability',true);
best = struct('aicc',inf);  rows = cell(NXMAX,1);
for nx = 1:NXMAX
    try
        m = ssest(z, nx, 'Ts', 1/Fs, 'InputDelay', nk, opt);
    catch ME
        rows{nx} = sprintf('  nx=%d  FAILED (%s)', nx, ME.message);
        continue;
    end
    yh = sim(m, uf);  yh = yh(:);
    fitpct = 100*(1 - norm(y_OL-yh)/norm(y_OL-mean(y_OL)));       % fit vs the REAL (unfiltered) y
    N=numel(yf); k=nx^2+2*nx+1; sse=sum((yf-yh).^2);
    aicc = N*log(sse/N) + 2*k + 2*k*(k+1)/max(N-k-1,1);
    pl = pole(m);  damp_min = min(-log(abs(pl))./abs(angle(pl)+eps));  % smallest damping (osc flag)
    rows{nx} = sprintf('  nx=%d  fit=%5.1f%%  AICc=%8.1f  |poles|=%s', ...
        nx, fitpct, aicc, mat2str(round(sort(abs(pl),'descend').',3)));
    if aicc < best.aicc
        best = struct('aicc',aicc,'fit',fitpct,'nx',nx,'m',m,'yh',yh,'damp',damp_min);
    end
end
rows = rows(~cellfun(@isempty,rows));
fprintf('[CTRL-LTI] model sweep (simulation fit):\n%s\n', strjoin(rows, newline));
m = best.m;  yh = best.yh;
fprintf('[CTRL-LTI] SELECTED nx=%d | fit=%.1f%% | R^2=%.3f\n', ...
    best.nx, best.fit, 1-sum((y_OL-yh).^2)/sum((y_OL-mean(y_OL)).^2));

%% [CTRL-LTI-VALIDATE] gain / poles / step --------------------------------------
md = c2d_if_needed(m, 1/Fs);                          % ensure discrete at Ts=1/Fs
[A,B,C,D] = ssdata(md);
dcg = dcgain(md);
fprintf('[CTRL-LTI] DC gain=%.3f %%dF per unit u | |poles|=%s | settling ~%.2fs\n', ...
    dcg, mat2str(round(abs(pole(md)).',3)), find_settle_s(md));

%% [CTRL-LTI-FIG] ---------------------------------------------------------------
figL = figure('Color','w','Position',[60 80 1250 460]);
tl = tiledlayout(figL,1,2,'TileSpacing','compact','Padding','compact');
nexttile(tl,1); hold on;                              % measured vs simulated
plot(trel, y_OL, 'k-', 'LineWidth', 1.8);
plot(trel, yh,  '-', 'Color',[0.85 0.3 0.1], 'LineWidth', 1.5);
yyaxis right; plot(trel, u_OL, '-', 'Color',[0.3 0.5 0.85], 'LineWidth', 1.0);
set(gca,'YColor',[0.3 0.5 0.85]); ylabel('u (laser cmd)');
yyaxis left; xline(0,'k:'); xlabel('time from stim (s)'); ylabel('ipsi \DeltaF/F (%)');
xlim([trel(1) trel(end)]);
legend({'y measured (OL)',sprintf('y LTI (nx=%d, fit %.0f%%)',best.nx,best.fit),'u input'}, ...
    'Box','off','Location','southeast','FontSize',8);
title('OL identification: measured vs LTI simulation');

nexttile(tl,2);                                       % unit-step response of the plant
[ys,ts] = step(md, 3);  plot(ts, ys, 'k-','LineWidth',1.6);
xlabel('time (s)'); ylabel('\DeltaF/F (%) per unit u'); grid on;
title(sprintf('plant step response  (DC gain %.2f)', dcg));

sgtitle(figL, sprintf('[CTRL-LTI] Stage 4a plant ID  %s  (nx=%d)', strrep(sess_tag,'_','\_'), best.nx));
fig_png = fullfile(fig_dir, sprintf('ctrl_lti_sysid_%s.png', sess_tag));
exportgraphics(figL, fig_png, 'Resolution', 300);
fprintf('[CTRL-LTI-FIG] -> %s\n', fig_png);

%% [CTRL-LTI-SAVE] --------------------------------------------------------------
% actuator budget (for Stage 4b constraint 0<=u<=u_max): the controller's own usage ceiling
uMaxCL = 0;  u_CL = [];
if isfield(data,'wc')
    wc = data.wc(:);  cl_starts = sort(d_s.stimStarts(wc));
    Uc = zeros(numel(cl_starts), numel(trel));
    for j=1:numel(cl_starts), Uc(j,:) = interp1(d_s.inpTime,uAmpFull,cl_starts(j)+trel,'linear',0); end
    u_CL   = mean(Uc,1).';                             % PI controller's own command (amplitude)
    uMaxCL = max(u_CL);                                % its usage ceiling
end
LTI = struct();
LTI.sess_tag=sess_tag; LTI.selField=selField; LTI.Fs=Fs; LTI.Ts=1/Fs;
LTI.A=A; LTI.B=B; LTI.C=C; LTI.D=D; LTI.nx=best.nx; LTI.nk=nk;
LTI.fit=best.fit; LTI.dcgain=dcg;
LTI.trel=trel; LTI.pre=pre; LTI.u_OL=u_OL; LTI.y_OL=y_OL; LTI.yh=yh; LTI.uAbs=uAbs;
LTI.u_CL=u_CL; LTI.uMaxCL=uMaxCL; LTI.uMaxHW=max(uAmpFull); LTI.uinfo=uinfo;
lti_file = fullfile(dataDir, sprintf('ctrl_lti_%s.mat', sess_tag));
save(lti_file, '-struct', 'LTI', '-v7.3');
fprintf('[CTRL-LTI-SAVE] -> %s | u_max(CL usage)=%.3f  u_max(HW)=%.3f\n\n', lti_file, uMaxCL, LTI.uMaxHW);

%% ---- helpers -----------------------------------------------------------------
function md = c2d_if_needed(m, Ts)
if m.Ts == 0, md = c2d(m, Ts, 'zoh'); else, md = m; end
end
function ts_settle = find_settle_s(md)
[ys,ts] = step(md, 5); yf = ys(end);
idx = find(abs(ys-yf) > 0.05*abs(yf), 1, 'last');
if isempty(idx), ts_settle = 0; else, ts_settle = ts(idx); end
end
