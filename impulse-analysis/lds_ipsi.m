% impulse-analysis/lds_ipsi.m
%
% Version 1 (SISO) LDS of the laser -> ipsi impulse response, via ERA.
%   y(k) = D u(k) + sum_{m>=1} C A^(m-1) B u(k-m) + noise        (y = ipsi)
%
% Identification: NO System Identification Toolbox (n4sid's sssim MEX repeatedly
% segfaulted on this real dF; reproduced clean only on synthetic data). Instead
% we realize a state space from the EMPIRICAL impulse response with the
% Eigensystem Realization Algorithm (Ho-Kalman): build a Hankel matrix of the
% Markov parameters, SVD it, read off [A,B,C,D]. Uses only svd/eig/\, which are
% stable on this machine. Open-loop sim of this model is the state-space twin of
% the tfest transfer function (Nick: SISO -> SS == TF).
%
% Minimal: no SVD/contra/ROI/server load. Uses allExperiments.{dF,timeBlue,imp,uAmp}.
%
% Sections (run section-by-section):
%   LDS-SETUP   -- trials, ipsi trace, window geometry
%   LDS-IR      -- empirical impulse response (train) + ERA realization -> A,B,C,D
%   LDS-SPONT   -- AR(p) on pre-trial ipsi -> spontaneous timescales (A_spont)
%   LDS-OL      -- open-loop impulse response vs per-amplitude averages + test R^2
%
% Prereq: load_experiments.m has been run (allExperiments in workspace).
% Knobs: selExp (3), n_states (5), pre_trial (1.0 s), post_trial (2.5 s), spont_pre (6 s)
close all;
selExp = 3; n_states = 5;
%% [LDS-SETUP] -----------------------------------------------------------------
% mfilename points to a temp Editor_* copy when a section is run with unsaved
% changes; reject tempdir and fall back to which()/pwd so caches land in data\.
lds_path = mfilename('fullpath');
if isempty(lds_path) || startsWith(lds_path, tempdir)
    w = which('lds_ipsi');
    if ~isempty(w) && ~startsWith(w, tempdir), lds_path = w;
    else,                                      lds_path = fullfile(pwd,'lds_ipsi.m'); end
end
impulseDir = fileparts(lds_path);
utilsDir   = fullfile(impulseDir,'..','utils');
dataDir    = fullfile(impulseDir,'data');
paperRoot  = fullfile(impulseDir,'..','paper');
addpath(utilsDir); addpath(genpath(utilsDir));
if ~exist(dataDir,'dir'), mkdir(dataDir); end
PS = paperStyle(); setPaperDefaults();

if ~exist('allExperiments','var') || isempty(allExperiments)
    error('lds_ipsi: run load_experiments.m first.');
end
if ~exist('selExp','var')   || isempty(selExp),   selExp   = 3; end
if ~exist('n_states','var') || isempty(n_states), n_states = 5; end

pre_trial = 1.0;  post_trial = 2.5;  spont_pre = 6;  Fs = 35;

mn = allExperiments(selExp).mn; td = allExperiments(selExp).td; en = allExperiments(selExp).en;
fprintf('[LDS-SETUP] %s %s e%d | SISO ipsi-only (ERA) | n_states=%d\n', mn, td, en, n_states);

y_full = allExperiments(selExp).dF(:);            % ipsi primary pixel
t_full = allExperiments(selExp).timeBlue(:);
nF     = numel(y_full);
y_dm   = y_full - mean(y_full,'omitnan');          % demeaned ipsi
nbad   = sum(~isfinite(y_full));
if nbad>0, fprintf('[LDS-SETUP] NOTE: dF has %d non-finite samples (%.2f%%).\n', nbad, 100*nbad/nF); end

imp_data = allExperiments(selExp).imp;
uAmp     = allExperiments(selExp).uAmp;
nzMask   = uAmp > 0;

all_starts = []; all_amps = [];
for ia = 1:numel(uAmp)
    if ~nzMask(ia); continue; end
    st = imp_data.startTimes{ia}(:);
    all_starts = [all_starts; st]; all_amps = [all_amps; repmat(uAmp(ia),numel(st),1)]; %#ok<AGROW>
end
[all_starts, sidx] = sort(all_starts); all_amps = all_amps(sidx);
nTrials = numel(all_starts);
fprintf('[LDS-SETUP] nF=%d  %d trials  %d amp levels  amp[%.2f %.2f]\n', ...
    nF, nTrials, sum(nzMask), min(all_amps), max(all_amps));

pre_fr   = round(pre_trial*Fs);  post_fr = round(post_trial*Fs);  spont_fr = round(spont_pre*Fs);
t_driv   = (-pre_fr:post_fr)/Fs; Ldriv   = numel(t_driv);
t_ir     = (0:post_fr)/Fs;                       % impulse-response time axis (from onset)
iDip_ir  = find(t_ir>=0 & t_ir<=0.2);            % 0-200 ms dip (peak_mode=3)

% reproducible 80/20 trial split
rng(42); tmask = false(nTrials,1); tmask(randperm(nTrials, round(0.2*nTrials))) = true;
tr = find(~tmask); te = find(tmask);

%% [LDS-IR] empirical impulse response (train) + ERA realization --------------
% Per trial: post-onset window, pre-stim baseline-subtracted. Average over TRAIN
% trials, divide by mean amplitude (linearity) -> unit impulse response g[0..post_fr].
acc = zeros(post_fr+1,1); amp_tr = []; n_ir = 0;
for k = tr'
    [~,ion] = min(abs(t_full - all_starts(k)));
    if ion-pre_fr<1 || ion+post_fr>nF, continue; end
    seg = y_dm(ion:ion+post_fr); bl = mean(y_dm(ion-pre_fr:ion-1),'omitnan');
    if any(~isfinite(seg)) || ~isfinite(bl) || std(seg)<1e-9, continue; end   % drop NaN/flat
    acc = acc + (seg - bl); amp_tr = [amp_tr; all_amps(k)]; n_ir = n_ir + 1; %#ok<AGROW>
end
assert(n_ir>0, 'lds_ipsi: no usable train trials (all NaN/flat).');
g = acc / n_ir / mean(amp_tr);                    % unit-amplitude impulse response
fprintf('[LDS-IR] empirical impulse response from %d train trials (mean amp %.2f).\n', n_ir, mean(amp_tr));

[A,B,C,D,poles] = era_fit(g, n_states);           % Ho-Kalman realization (local fn below)
eig_ev = poles;
tau_ev = sort(-1./(Fs*real(log(eig_ev(abs(eig_ev)<1-1e-6)))),'descend');
if isempty(tau_ev), tau_ev = NaN; end
fprintf('[LDS-IR] ERA: stable=%d  |eig|max=%.3f  tau(s): %s\n', ...
    all(abs(eig_ev)<1), max(abs(eig_ev)), sprintf('%.3f ', tau_ev(1:min(3,end))));

%% [LDS-SPONT] AR(p) on pre-trial ipsi -> spontaneous timescales --------------
p_ar = 10;
y_sp = cell(nTrials,1); ok_sp = false(nTrials,1);
for j = 1:nTrials
    [~,ion] = min(abs(t_full - all_starts(j)));
    i0 = ion-spont_fr; i1 = ion-1;
    if i0<1 || i1>nF, continue; end
    seg = y_dm(i0:i1);
    if any(~isfinite(seg)) || std(seg)<1e-9, continue; end
    y_sp{j} = seg - mean(seg); ok_sp(j) = true;
end
Yc = cell2mat(y_sp(ok_sp));
Phi = zeros(numel(Yc)-p_ar, p_ar);
for i = 1:p_ar, Phi(:,i) = Yc(p_ar-i+1:end-i); end
a_ar   = Phi \ Yc(p_ar+1:end);                    % y[t] = sum a_i y[t-i]  (LS, no MEX)
comp   = [a_ar.'; [eye(p_ar-1), zeros(p_ar-1,1)]];
eig_sp = eig(comp);
tau_sp = sort(-1./(Fs*real(log(eig_sp(abs(eig_sp)<1-1e-6)))),'descend');
if isempty(tau_sp), tau_sp = NaN; end
fprintf('[LDS-SPONT] AR(%d) on %d windows: |pole|max=%.3f  tau(s): %s\n', ...
    p_ar, sum(ok_sp), max(abs(eig_sp)), sprintf('%.3f ', tau_sp(1:min(3,end))));

%% [LDS-OL] open-loop impulse response vs per-amplitude averages + test R^2 ----
% ERA model open-loop unit-impulse response (manual sim, no MEX)
nOL = post_fr+1; x = zeros(n_states,1); yol = zeros(nOL,1); uimp = [1; zeros(nOL-1,1)];
for t = 1:nOL, yol(t) = C*x + D*uimp(t); x = A*x + B*uimp(t); end

% held-out test dip R^2: predict each test trial = yol * amp, compare in dip
yp = []; ya = [];
for k = te'
    [~,ion] = min(abs(t_full - all_starts(k)));
    if ion-pre_fr<1 || ion+post_fr>nF, continue; end
    seg = y_dm(ion:ion+post_fr); bl = mean(y_dm(ion-pre_fr:ion-1),'omitnan');
    if any(~isfinite(seg)) || ~isfinite(bl), continue; end
    ya = [ya; (seg(iDip_ir)-bl)']; yp = [yp; (yol(iDip_ir)*all_amps(k))']; %#ok<AGROW>
end
r2_ol = 1 - sum((ya(:)-yp(:)).^2,'omitnan') / sum((ya(:)-mean(ya(:),'omitnan')).^2,'omitnan');
fprintf('[LDS-OL] held-out test dip R^2 (0-200 ms): %.3f\n', r2_ol);

amp_list = uAmp(nzMask); mean_amp = mean(all_amps,'omitnan'); cols = lines(numel(amp_list));
fig = paperFig(10,5); ax = axes(fig,'Position',[0.10 0.14 0.86 0.76]); hold(ax,'on');
for ka = 1:numel(amp_list)
    aa = amp_list(ka); idx = find(abs(all_amps-aa)<1e-6); accp = nan(numel(idx),post_fr+1);
    for jx = 1:numel(idx)
        [~,ion] = min(abs(t_full-all_starts(idx(jx))));
        if ion-pre_fr<1 || ion+post_fr>nF, continue; end
        bl = mean(y_dm(ion-pre_fr:ion-1),'omitnan'); accp(jx,:) = (y_dm(ion:ion+post_fr)-bl)';
    end
    plot(ax, t_ir, mean(accp,1,'omitnan'), '-', 'Color',cols(ka,:), 'LineWidth',1.0, ...
        'DisplayName',sprintf('A=%.2f',aa));
end
plot(ax, t_ir, yol*mean_amp, 'k--', 'LineWidth',1.5, 'DisplayName',sprintf('ERA OL \\times%.1f',mean_amp));
xline(ax,0,'k:','LineWidth',0.5,'HandleVisibility','off');
yline(ax,0,'k--','LineWidth',0.4,'HandleVisibility','off'); hold(ax,'off');
xlabel(ax,'Time re onset (s)','FontSize',6,'FontWeight','bold');
ylabel(ax,'\DeltaF/F (%)','FontSize',6,'FontWeight','bold');
legend(ax,'Location','southeast','Box','off','FontSize',5,'NumColumns',2);
title(ax, sprintf('SISO ERA impulse response  %s %s e%d  n=%d  testR^2=%.2f', ...
    mn,td,en,n_states,r2_ol), 'FontSize',6,'FontWeight','bold','Interpreter','none');
set(ax,'Box','off','TickDir','out','FontSize',6,'FontWeight','bold');
paperExport(fig, fullfile(paperRoot,'images','figure2','lds_ipsi_ol.png'));
fprintf('[LDS-OL] exported lds_ipsi_ol.png\n');

%% ---- save outputs -----------------------------------------------------------
lds_cache = fullfile(dataDir, sprintf('ldsipsi_%s_%s%s_e%d_n%d.mat', mn, td(6:7), td(9:10), en, n_states));
save(lds_cache, 'A','B','C','D','g','poles','eig_sp','eig_ev','tau_sp','tau_ev', ...
    'r2_ol','t_ir','iDip_ir','n_states','selExp');
fprintf('\n[lds_ipsi] Done.  %s %s e%d | n_states=%d\n', mn, td, en, n_states);
fprintf('  A_spont tau1=%.3f s  |  A_evoked tau1=%.3f s\n', tau_sp(1), tau_ev(1));
fprintf('  Held-out test dip R^2=%.3f   Saved: %s\n', r2_ol, lds_cache);

%% ===== local functions =======================================================
function [A,B,C,D,poles] = era_fit(g, n)
% Eigensystem Realization Algorithm (Ho-Kalman) for a SISO system from its
% impulse response g = [g0; g1; g2; ...].  g0 = D; gk = C A^(k-1) B for k>=1.
    g = g(:); D = g(1); m = g(2:end); N = numel(m);
    r = floor(N/2); c = N - r;                       % Hankel block sizes (r+c = N)
    H0 = hankel(m(1:r),   m(r:r+c-1));               % H0(i,j) = m(i+j-1)
    H1 = hankel(m(2:r+1), m(r+1:r+c));               % H1(i,j) = m(i+j)  (shifted)
    [U,S,V] = svd(H0,'econ'); sv = diag(S);
    n = max(1, min(n, sum(sv > sv(1)*1e-8)));         % cap order at numerical rank
    Un = U(:,1:n); Sn = S(1:n,1:n); Vn = V(:,1:n);
    s12  = diag(sqrt(diag(Sn)));  s12i = diag(1./sqrt(diag(Sn)));
    A = s12i * Un' * H1 * Vn * s12i;
    Obsv = Un * s12;  Ctrb = s12 * Vn';
    C = Obsv(1,:);                                    % first output row  [1 x n]
    B = Ctrb(:,1);                                    % first input col   [n x 1]
    poles = eig(A);
end
