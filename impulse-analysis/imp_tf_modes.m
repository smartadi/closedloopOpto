%% imp_tf_modes.m -- EXPLORATORY: how much does each LTI mode matter? Both impulse TF fit sets.
%
% Read-only on the Fig-2 pipeline. Loads the current fits (data/imp_tf_fits.mat, 0-0.5 s,
% onset reference) and the alternative fits (data/imp_tf_fits_win_m0p5_1p0.mat, -0.5..+1.0 s,
% pre-mean reference; see ALT_WINDOW_DECISION.md) and, per session and fit set:
%   1. partial-fraction decomposition of the selected TF into modes (residue/pole, complex pairs
%      grouped). DIP = fastest complex pair; OFFSET = any mode with tau > OFFSET_TAU (near-DC
%      pole, e.g. the seeded fit's 1768 s pole) -- reported separately, never the rebound;
%      REBOUND = slowest remaining mode other than the dip; anything else = OTHER.
%   2. each mode's share of response energy (integral of its squared modal impulse response) over
%      the fit window and over 0-inf, as a share of the summed modal energies (cross terms
%      excluded, so shares add to 100 %), and its signed share of the DC gain. OFFSET excluded
%      from both denominators.
%   3. from the trial-averaged h(t): peak rebound (max over 0.15-1.0 s) as % of the dip trough
%      (|min| over 0-0.3 s), on each fit set's own reference.
%   4. a 3 s step through each model (offset mode removed): relaxation of the suppression during
%      the step (y(3 s) vs the peak, % of peak), overshoot after offset (% of peak); and the same
%      with the rebound mode removed too, to attribute the relaxation.
%   5. dip / rebound tau with bootstrap CI and the beyond-window discard rate, both sets.
% Outputs (PNG only): paper/images/figure2/alt_window/modes_overlay.png, modes_step.png.
%
% Modal responses are the CONTINUOUS impulse responses g_i(t) = r e^{pt} (+ conj), scaled by Ts so
% they sit on the per-sample h(t) scale; the shares are scale-free. Energies over 0-inf are
% analytic. Needs allExperiments, or ALT_DATA = mat with variable A, for the measured traces.

here = fileparts(mfilename('fullpath'));  root = fileparts(here);
addpath(fullfile(root,'utils'));
if ~exist('allExperiments','var') || isempty(allExperiments)
    assert(exist('ALT_DATA','var') && ~isempty(ALT_DATA), '[MODES] run load_experiments.m or set ALT_DATA.');
    L = load(ALT_DATA);  allExperiments = L.A;  clear L
end
outDir = fullfile(root,'paper','images','figure2','alt_window');
if ~exist(outDir,'dir'), mkdir(outDir); end
OFFSET_TAU = 10;                                         % s; slower than this = near-DC offset
SETS = {'current 0-0.5 s', fullfile(here,'data','imp_tf_fits.mat'),               0.5, 'onset';
        'alt -0.5..1.0 s', fullfile(here,'data','imp_tf_fits_win_m0p5_1p0.mat'),  1.0, 'premean'};
fs = 35;  Ts = 1/fs;  t = -3:Ts:3;  PS = paperStyle();
colReb = [0.85 0.45 0.05];

M = struct();
for si = 1:size(SETS,1)
    C = load(SETS{si,2});  S = C.Sprim;  win = SETS{si,3};
    lbl = string(imp_mouse_label(S, 'short'));
    for k = 1:numel(S)
        s = S{k};  A = allExperiments(k);
        [num, den] = tfdata(s.sys, 'v');
        assert(s.sys.Ts == 0, '[MODES] expected a continuous-time model');
        [r, p] = residue(num, den);
        md = i_group(r, p);                                    % one entry per mode
        tau = -1 ./ real([md.p]);
        isC = [md.cplx];  isOff = tau > OFFSET_TAU | real([md.p]) >= 0;
        iDip = find(isC & ~isOff);  [~, j] = min(tau(iDip));  iDip = iDip(j);
        rest = setdiff(find(~isOff), iDip);  [~, j] = max(tau(rest));  iReb = rest(j);
        role = repmat("other", 1, numel(md));  role(isOff) = "offset";
        role(iDip) = "dip";  if ~isempty(iReb), role(iReb) = "rebound"; end
        % ---- energies + DC gain -------------------------------------------------------------
        tw = (0:0.001:win).';                                   % fine grid for the window integral
        Ew = zeros(1,numel(md));  Ei = zeros(1,numel(md));  dc = zeros(1,numel(md));
        for m = 1:numel(md)
            g = i_modal(md(m), tw);  Ew(m) = trapz(tw, g.^2);
            Ei(m) = i_einf(md(m));   dc(m) = i_dc(md(m));
        end
        use = ~isOff;
        shW = 100 * Ew ./ sum(Ew(use));  shI = 100 * Ei ./ sum(Ei(use));  shD = 100 * dc ./ sum(dc(use));
        shW(isOff) = NaN;  shI(isOff) = NaN;  shD(isOff) = NaN;
        % cancellation index: summed modal energy / energy of the summed model, over the window.
        % ~1 = modes separate cleanly; >> 1 = large modes cancel, so per-mode shares are fragile.
        gTot = zeros(size(tw));  for m = find(use), gTot = gTot + i_modal(md(m), tw); end
        cancel = sum(Ew(use)) / trapz(tw, gTot.^2);
        % same 0-0.25 vs 0-1 s split on the model (old fits extrapolated past their 0.5 s window)
        t1 = (0:0.001:1.0).';  g1 = zeros(size(t1));  for m = find(use), g1 = g1 + i_modal(md(m), t1); end
        mSplit = 100 * trapz(t1(t1<=0.25), g1(t1<=0.25).^2) / trapz(t1, g1.^2);
        % ---- measured rebound / dip from h(t) on this set's own reference --------------------
        uA = A.uAmp(:);  v = uA > 0;  w = uA(v).^2;  w = w/sum(w);
        DF = A.DF_imp;
        if strcmp(SETS{si,4}, 'premean'), DF = DF - mean(DF(:, t >= -0.5 & t < 0), 2, 'omitnan'); end
        h = sum(DF(v,:)./uA(v).*w, 1, 'omitnan');
        trough = min(h(t >= 0 & t <= 0.3));  [rebPk, ir] = max(h(t >= 0.15 & t <= 1.0));
        tr = t(t >= 0.15 & t <= 1.0);
        % MODEL-FREE: time-domain energy split of the measured h(t) (0-0.25 s dip window vs 0-1 s),
        % and the LTI step response predicted straight from the data = running sum of h(t), to 1 s
        % only (past ~1 s the trial average is dominated by ongoing activity; RESEARCH 2026-10-03).
        i01 = t >= 0 & t <= 1.0;  h01 = h(i01);  t01 = t(i01);
        dSplit = 100 * sum(h01(t01 <= 0.25).^2) / sum(h01.^2);
        sData = cumsum(h01);  [sPk, isp] = min(sData);
        dRelax1 = 100 * (sData(end) - sPk) / abs(sPk);  dPkT = t01(isp);
        % ---- 3 s step through the model (offset removed), +/- rebound mode --------------------
        ts = (0:Ts:6).';  u = double(ts < 3);
        yFull = i_step(md(use), ts, u, Ts);
        yNoReb = i_step(md(use & role ~= "rebound"), ts, u, Ts);
        [ad, ov, pk] = i_adapt(yFull, ts);  [adN, ovN] = i_adapt(yNoReb, ts);
        i1 = ts <= 1.0 + 1e-9;  [pk1, ~] = min(yFull(i1));  y1 = yFull(find(i1,1,'last'));
        mRelax1 = 100 * (y1 - pk1) / abs(pk1);
        % ---- store -------------------------------------------------------------------------
        R = struct('set',SETS{si,1},'lbl',lbl(k),'order',sprintf('%dp%dz%dd',s.np,s.nz,s.nd), ...
            'md',md,'role',role,'tau',tau,'shW',shW,'shI',shI,'shD',shD, ...
            'trough',trough,'rebPk',rebPk,'rebT',tr(ir),'rebPct',100*rebPk/abs(trough), ...
            'adapt',ad,'over',ov,'stepPk',pk,'adaptNoReb',adN,'overNoReb',ovN, ...
            'yFull',yFull,'yNoReb',yNoReb,'ts',ts,'h',h,'win',win, ...
            'cancel',cancel,'mSplit',mSplit,'dSplit',dSplit,'sData',sData,'t01',t01, ...
            'dRelax1',dRelax1,'dPkT',dPkT,'mRelax1',NaN, ...
            'tauCI',[],'discard',i_fld(s,'tauBootReject'),'beyond',i_fld(s,'tauBootBeyond'),'tauMax',i_fld(s,'tauMax'));
        % bootstrap CI by pole (tauCI rows follow s.tau sorted descending, repeats included)
        if isfield(s,'tauCI') && ~isempty(s.tauCI)
            tSorted = s.tau(:);
            R.dipCI = i_ciFor(tau(iDip), tSorted, s.tauCI, 'last');
            if ~isempty(iReb), R.rebCI = i_ciFor(tau(iReb), tSorted, s.tauCI, 'first'); else, R.rebCI = [NaN NaN]; end
        else
            R.dipCI = [NaN NaN];  R.rebCI = [NaN NaN];
        end
        R.offTau = tau(isOff);  R.mRelax1 = mRelax1;
        M(si,k).R = R;                                                      %#ok<SAGROW>
    end
end

% ---- table -------------------------------------------------------------------------------------
fprintf('\n=================== MODAL DECOMPOSITION (shares exclude near-DC offset modes) ===================\n');
fprintf('%-5s %-16s %-8s | %-31s | %-31s | %-14s | %6s | %13s | %13s | %s\n', 'mouse','fit set','order', ...
    'DIP tau [CI] / freq', 'REBOUND tau [CI]', 'offset tau', 'reb/dip', 'E win dip/reb', 'E inf dip/reb', ...
    'DC dip/reb | step: relax / overshoot (no-reb: relax / over) | boot discard');
for k = 1:size(M,2)
    for si = 1:size(M,1)
        R = M(si,k).R;  iD = find(R.role=="dip");  iR = find(R.role=="rebound");
        fD = abs(imag(R.md(iD).p))/(2*pi);
        sR = '      --                       ';  eW = NaN; eI = NaN; dR = NaN;
        if ~isempty(iR)
            ty = 'real';  if R.md(iR).cplx, ty = sprintf('%.1f Hz', abs(imag(R.md(iR).p))/(2*pi)); end
            sR = sprintf('%6.3f [%5.3f %5.3f] %-8s', R.tau(iR), R.rebCI, ty);
            eW = R.shW(iR); eI = R.shI(iR); dR = R.shD(iR);
        end
        sO = '--';  if ~isempty(R.offTau), sO = sprintf('%.3g s', max(R.offTau)); end
        fprintf('%-5s %-16s %-8s | %6.3f [%5.3f %5.3f] %4.1f Hz | %s | %-14s | %5.0f%% | %5.0f%% /%4.0f%% | %5.0f%% /%4.0f%% | %5.0f%% /%5.0f%% | %5.1f%% / %5.1f%% (%5.1f%% / %5.1f%%) | %.0f%% (beyond %.0f%%)\n', ...
            R.lbl, R.set, R.order, R.tau(iD), R.dipCI, fD, sR, sO, R.rebPct, ...
            R.shW(iD), eW, R.shI(iD), eI, R.shD(iD), dR, R.adapt, R.over, R.adaptNoReb, R.overNoReb, ...
            100*R.discard, 100*R.beyond);
    end
end
fprintf(['Shares: modal energy / summed modal energy (cross terms excluded); DC: signed share of the summed\n' ...
         'modal DC gain. Offset modes (tau > %g s) excluded from shares and from the step simulation.\n' ...
         'Step: unit 3 s step; relax = (peak - y(3 s))/peak; overshoot = max opposite-sign excursion after\n' ...
         'offset, %% of peak. reb/dip = measured rebound peak (0.15-1.0 s) / |dip trough| (0-0.3 s).\n'], OFFSET_TAU);
fprintf('\n=================== ROBUSTNESS: modal cancellation vs model-free numbers ===================\n');
fprintf('%-5s %-16s | cancel idx | dip-window energy share (0-0.25 of 0-1 s): data / model | data step to 1 s: peak @ t, relax by 1 s | model relax by 1 s\n','mouse','fit set');
for k = 1:size(M,2)
    for si = 1:size(M,1)
        R = M(si,k).R;
        fprintf('%-5s %-16s | %9.2f  | %5.0f%% / %5.0f%%                                    | %.2f s, %5.0f%%                            | %5.0f%%\n', ...
            R.lbl, R.set, R.cancel, R.dSplit, R.mSplit, R.dPkT, R.dRelax1, R.mRelax1);
    end
end
MODES = M;

% ---- figure 1: modal decomposition over h(t), row per fit set ----------------------------------
nS = size(M,2);  f1 = paperFig(4*nS, 7);
for si = 1:size(M,1)
    for k = 1:nS
        R = M(si,k).R;  ax = subplot(size(M,1), nS, (si-1)*nS + k);  hold(ax,'on');
        tt = (0:0.001:1.0).';  ts0 = t(t >= -0.15 & t <= 1.0);
        patch(ax, [0 R.win R.win 0], [-10 -10 10 10], [.94 .94 .94], 'EdgeColor','none');
        yline(ax, 0, '-', 'Color',[.75 .75 .75], 'LineWidth',PS.lw_zero);
        plot(ax, ts0, R.h(t >= -0.15 & t <= 1.0), '-', 'Color',[.55 .55 .55], 'LineWidth',PS.lw_mean);
        tot = zeros(size(tt));  hD = gobjects(0); hR = gobjects(0); hO = gobjects(0); hX = gobjects(0);
        for m = 1:numel(R.md)
            g = Ts * i_modal(R.md(m), tt);
            if R.role(m) ~= "offset", tot = tot + g; end
            switch R.role(m)
                case "dip",     hD = plot(ax, tt, g, '-',  'Color', PS.sessColor(k), 'LineWidth', PS.lw_fit);
                case "rebound", hR = plot(ax, tt, g, '-',  'Color', colReb, 'LineWidth', PS.lw_fit);
                case "offset",  hX = plot(ax, tt, g, ':',  'Color', [.4 .4 .4], 'LineWidth', PS.lw_fit);
                otherwise,      hO = plot(ax, tt, g, '-',  'Color', [.6 .6 .6], 'LineWidth', 0.5);
            end
        end
        hT = plot(ax, tt, tot, 'k--', 'LineWidth', PS.lw_fit);
        xlim(ax, [-0.15 1.0]);  yl = [min(R.h(t>=0&t<=1))-0.1, max([R.h(t>=0&t<=1) tot.'])+0.15];  ylim(ax, yl);
        iD = find(R.role=="dip");  iR = find(R.role=="rebound");
        txt = sprintf('dip %.0f%%', R.shW(iD));  if ~isempty(iR), txt = sprintf('%s | reb %.0f%%', txt, R.shW(iR)); end
        text(ax, 0.98, 0.06, txt, 'Units','normalized','HorizontalAlignment','right','FontSize',PS.fs-1,'FontWeight',PS.fw);
        title(ax, sprintf('%s  %s  %s', R.lbl, R.set, R.order), 'FontSize',PS.fs,'FontWeight',PS.fw);
        set(ax,'FontSize',PS.fs,'FontWeight',PS.fw,'TickDir','out','Box','off','Layer','top');
        if k == 1, ylabel(ax,'\DeltaF/F per V'); end
        if si == size(M,1), xlabel(ax,'time (s)'); end
        if si == 1 && k == nS
            hc = {hT hD hR hO hX};  nm = {'model','dip','rebound','other','offset'};
            keep = cellfun(@(x) ~isempty(x) && all(isgraphics(x)), hc);
            hh = gobjects(1, nnz(keep));  kk = find(keep);
            for q = 1:numel(kk), hh(q) = hc{kk(q)}(1); end
            lg = legend(ax, hh, nm(keep), 'Location','southeast','Box','off');
            lg.String = nm(keep);                 % pin names (auto 'dataN' otherwise)
            lg.ItemTokenSize = PS.lgd_token;  lg.FontSize = PS.fs-1;
        end
    end
end
annotation(f1,'textbox',[0 0.955 1 0.045],'String', ...
    'grey = measured h(t) | dashed = model (offset mode excluded) | shaded = fit window | % = share of modal energy in the window', ...
    'EdgeColor','none','HorizontalAlignment','center','FontSize',PS.fs,'FontWeight',PS.fw);
exportgraphics(f1, fullfile(outDir,'modes_overlay.png'), 'Resolution', 300);

% ---- figure 2: 3 s step, full model vs rebound mode removed -----------------------------------
f2 = paperFig(4*nS, 7);
for si = 1:size(M,1)
    for k = 1:nS
        R = M(si,k).R;  ax = subplot(size(M,1), nS, (si-1)*nS + k);  hold(ax,'on');
        patch(ax, [0 3 3 0], [-1e3 -1e3 1e3 1e3], [.94 .94 .94], 'EdgeColor','none');
        yline(ax, 0, '-', 'Color',[.75 .75 .75], 'LineWidth',PS.lw_zero);
        pkN = abs(R.stepPk);
        h1 = plot(ax, R.ts, R.yFull/pkN, '-', 'Color', PS.sessColor(k), 'LineWidth', PS.lw_mean);
        h2 = plot(ax, R.ts, R.yNoReb/pkN, '--', 'Color', colReb, 'LineWidth', PS.lw_fit);
        ylim(ax, [-1.25 0.6]);  xlim(ax, [0 6]);
        text(ax, 0.98, 0.94, sprintf('relax %.0f%% | over %.0f%%', R.adapt, R.over), 'Units','normalized', ...
            'HorizontalAlignment','right','FontSize',PS.fs-1,'FontWeight',PS.fw);
        title(ax, sprintf('%s  %s', R.lbl, R.set), 'FontSize',PS.fs,'FontWeight',PS.fw);
        set(ax,'FontSize',PS.fs,'FontWeight',PS.fw,'TickDir','out','Box','off','Layer','top');
        if k == 1, ylabel(ax,'response / |peak|'); end
        if si == size(M,1), xlabel(ax,'time (s)'); end
        if si == 1 && k == nS
            lg = legend(ax, [h1 h2], {'full model','rebound mode removed'}, 'Location','southeast','Box','off');
            lg.ItemTokenSize = PS.lgd_token;  lg.FontSize = PS.fs-1;
        end
    end
end
annotation(f2,'textbox',[0 0.955 1 0.045],'String', ...
    'unit 3 s step (shaded) through each model, near-DC offset mode removed; normalised to the peak suppression', ...
    'EdgeColor','none','HorizontalAlignment','center','FontSize',PS.fs,'FontWeight',PS.fw);
exportgraphics(f2, fullfile(outDir,'modes_step.png'), 'Resolution', 300);
fprintf('[MODES] panels -> %s\n', outDir);

% =================================================================================================
function md = i_group(r, p)
% One struct per mode: real pole, or one representative of a conjugate pair (Im > 0).
md = struct('r',{},'p',{},'cplx',{});  used = false(size(p));
for i = 1:numel(p)
    if used(i), continue; end
    if abs(imag(p(i))) < 1e-9 * max(1, abs(p(i)))
        md(end+1) = struct('r', real(r(i)), 'p', real(p(i)), 'cplx', false);     %#ok<AGROW>
        used(i) = true;
    else
        j = find(~used & abs(p - conj(p(i))) < 1e-6 * max(1, abs(p(i))), 1);
        if isempty(j), j = i; end
        used([i j]) = true;
        if imag(p(i)) > 0, ii = i; else, ii = j; end
        md(end+1) = struct('r', r(ii), 'p', p(ii), 'cplx', true);                %#ok<AGROW>
    end
end
end
function g = i_modal(m, tt)
if m.cplx, g = 2*real(m.r * exp(m.p * tt)); else, g = m.r * exp(m.p * tt); end
end
function E = i_einf(m)
% integral over 0-inf of the squared modal impulse response (analytic; Re p < 0)
if real(m.p) >= 0, E = Inf; return; end
if m.cplx
    E = 2*real(m.r^2 / (-2*m.p)) + 2*abs(m.r)^2 / (-2*real(m.p));
else
    E = m.r^2 / (-2*m.p);
end
end
function d = i_dc(m)
if m.cplx, d = 2*real(-m.r / m.p); else, d = -m.r / m.p; end
end
function y = i_step(md, ts, u, Ts)
% Response of the sum of modes to input u (ZOH, sampled at Ts), per-sample scaling as h(t).
y = zeros(size(ts));
for m = 1:numel(md)
    if md(m).cplx
        sysm = tf([2*real(md(m).r), -2*real(md(m).r*conj(md(m).p))], [1, -2*real(md(m).p), abs(md(m).p)^2]);
    else
        sysm = tf(md(m).r, [1, -md(m).p]);
    end
    y = y + lsim(sysm, u, ts, 'zoh');
end
% A held unit input integrates g(t), which equals summing the per-sample h(t) = Ts*g over frames,
% so y is already on the same scale as h. (Ts kept in the signature for that reason.)
end
function [ad, ov, pk] = i_adapt(y, ts)
on = ts < 3;  [pk, ip] = min(y(on));           % suppression = negative peak
if pk >= 0, ad = NaN; ov = NaN; return; end    % no suppression at all (e.g. a mode removed)
yEnd = y(find(on, 1, 'last'));
ad = 100 * (yEnd - pk) / abs(pk);              % relaxation back toward 0 during the step
ov = 100 * max(0, max(y(~on))) / abs(pk);      % opposite-sign excursion after offset
if ts(ip) > 2.9, ad = 0; end                   % still deepening at the end: no relaxation
end
function ci = i_ciFor(tauX, tSorted, tauCI, which)
% Bootstrap columns are per-draw sorted taus, so a conjugate pair occupies two rows. The dip
% takes the LAST matching row and the rebound the FIRST, as imp_tf_altwin_figs/imp_tf_robust_fig do.
i = find(abs(tSorted - tauX) < 1e-6 * max(1, tauX), 1, which);
if isempty(i), [~, i] = min(abs(tSorted - tauX)); end
if i <= size(tauCI,1), ci = tauCI(i,:); else, ci = [NaN NaN]; end
end
function v = i_fld(s, f)
if isfield(s,f) && ~isempty(s.(f)), v = s.(f); else, v = NaN; end
end
