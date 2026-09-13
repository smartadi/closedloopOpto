% impulse-analysis/imp_state_trial_examples.m
% ============================================================================
% SUPPLEMENTARY: single-trial examples of HIGH vs LOW pre-stim state (motion,
% rel-delta), to make the state-dependence panels (Fig 2 G/H) concrete.
%
% 3 rows x 2 cols  (col 1 = rel-delta, col 2 = motion):
%   row 1  HIGH-amp stim trials   -- state modulates the impulse response
%   row 2  AMP-0 (no stim) trials -- the SAME state structure with NO stimulus,
%          i.e. the prediction error / variability is a property of the ongoing
%          signal, not of stimulus processing (single-trial twin of the grey
%          stim-free control line in 2G/2H).
%   row 3  state evidence for the row-1 trials -- 2-4 Hz band-passed pre-stim
%          (delta) and the rectified motion trace (motion).
% Each trace pair: HIGH state = red bold, LOW state = grey; amplitude mean dashed;
% pre-stim state window shaded.
%
% Reuses allExperiments (run load_experiments first). State windows + rel-delta
% computed IDENTICALLY to imp_state_trialvar.m.
%
% Config (optional): STE_HIQ/STE_LOQ high/low percentile targets (0.97/0.10);
%   STE_HIAMPQ amplitude cutoff for "high amp" as a per-session quantile (0.60).
% OUTPUT: paper/images/supplementary/imp_state_examples.pdf (+ .png)
% ============================================================================
clc;
assert(exist('allExperiments','var')==1 && ~isempty(allExperiments), ...
       '[STE] allExperiments absent -- run load_experiments first.');
here = fileparts(which('imp_state_trial_examples'));
if isempty(here), here = fullfile(pwd,'impulse-analysis'); end
PS = paperStyle(); setPaperDefaults();

fs    = 35;
tAxis = -3 : 1/fs : 3;
iOn   = find(tAxis >= 0, 1);
Lresp = numel(iOn+2 : iOn + round(0.22*fs));
iSham = find(tAxis >= -1.0, 1) + (0:Lresp-1);
stLo  = tAxis(iSham(end)) + 1/fs;
iState = tAxis >= stLo & tAxis <= -1/fs;

if ~exist('STE_HIQ','var')||isempty(STE_HIQ),     STE_HIQ = 0.97; end
if ~exist('STE_LOQ','var')||isempty(STE_LOQ),     STE_LOQ = 0.10; end
if ~exist('STE_HIAMPQ','var')||isempty(STE_HIAMPQ), STE_HIAMPQ = 0.60; end

% ---- gather every trial (all sessions x amps), tag amp tier -------------------------------------
nE = numel(allExperiments);
G = struct('e',{},'a',{},'tr',{},'mot',{},'dpr',{},'amp',{},'isZero',{},'isHi',{});
for e = 1:nE
    im = allExperiments(e).imp;
    av = zeros(numel(im.uAmp),1);
    for a = 1:numel(im.uAmp), v = im.uAmp(a); if iscell(v), v = v{1}; end; av(a) = double(v); end
    hiCut = quantile(av(av>0), STE_HIAMPQ);          % "high amp" = top tier of THIS session's amps
    for a = 1:numel(im.uAmp)
        d0 = im.dfImp{a};  m0 = im.motTrace{a};
        if isempty(d0) || isempty(m0), continue; end
        nn = min(size(d0,1), size(m0,1));  if nn < 8, continue; end
        mv = mean(m0(1:nn, iState), 2, 'omitnan');
        [~, dv] = local_delta_ste(d0(1:nn, iState), fs);
        for tr = 1:nn
            G(end+1) = struct('e',e,'a',a,'tr',tr,'mot',mv(tr),'dpr',dv(tr), ...
                              'amp',av(a),'isZero',av(a)<=0,'isHi',av(a)>=hiCut);
        end
    end
end
amp = [G.amp];  isZero = logical([G.isZero]);  isHi = logical([G.isHi]);
mot = [G.mot];  dpr = [G.dpr];

% ---- pick example sets --------------------------------------------------------------------------
% STIM = high-amp non-zero trials; SHAM = amp-0 trials. High state = nearest 97th-pct within the set.
selHiInSet = @(v, mask) local_setpick(v, mask, STE_HIQ);
[dfDs, moDs, iHiDs, iLoDs, lblDs, ampDs] = local_pack(allExperiments, G, selHiInSet(dpr, ~isZero & isHi), 'dpr', STE_LOQ, iState, fs);
[dfMs, moMs, iHiMs, iLoMs, lblMs, ampMs] = local_pack(allExperiments, G, selHiInSet(mot, ~isZero & isHi), 'mot', STE_LOQ, iState, fs);
[dfD0, moD0, iHiD0, iLoD0, lblD0, ampD0] = local_pack(allExperiments, G, selHiInSet(dpr, isZero), 'dpr', STE_LOQ, iState, fs);
[dfM0, moM0, iHiM0, iLoM0, lblM0, ampM0] = local_pack(allExperiments, G, selHiInSet(mot, isZero), 'mot', STE_LOQ, iState, fs);

[~, dDs] = local_delta_ste(dfDs(:,iState), fs);   [~, dD0] = local_delta_ste(dfD0(:,iState), fs);
mMs = mean(moMs(:,iState),2,'omitnan');            mM0 = mean(moM0(:,iState),2,'omitnan');
fprintf('[STE] delta  stim=%s %.1fV (%.2f vs %.2f) | sham=%s %.1fV (%.2f vs %.2f)\n', ...
        lblDs, ampDs, dDs(iHiDs), dDs(iLoDs), lblD0, ampD0, dD0(iHiD0), dD0(iLoD0));
fprintf('[STE] motion stim=%s %.1fV (%.2f vs %.2f z) | sham=%s %.1fV (%.2f vs %.2f z)\n', ...
        lblMs, ampMs, mMs(iHiMs), mMs(iLoMs), lblM0, ampM0, mM0(iHiM0), mM0(iLoM0));

% ---- draw -------------------------------------------------------------------------------------
iShow = tAxis >= -1.0 & tAxis <= 1.5;  tS = tAxis(iShow);
cHi = PS.col_ol;  cLo = [0.62 0.62 0.62];
cD  = [0.90 0.90 0.98];  cM = [0.92 0.92 0.92];       % state-window shade tints

f = paperFig(13, 12);
tl = tiledlayout(f, 3, 2, 'TileSpacing','compact', 'Padding','compact');
title(tl, 'Single-trial examples: high (red) vs low (grey) pre-stim state   (dashed = amp mean; shaded = state window)', ...
      'FontSize', PS.fs, 'FontWeight', PS.fw);

% row 1: HIGH-amp stim
local_trace(nexttile(tl,1), tS, dfDs, iHiDs, iLoDs, iShow, stLo, fs, cHi, cLo, cD, PS, ...
    '\DeltaF/F (%)', sprintf('Rel \\delta, high amp:  %.2f vs %.2f', dDs(iHiDs), dDs(iLoDs)), sprintf('%s %.1fV', lblDs, ampDs));
local_trace(nexttile(tl,2), tS, dfMs, iHiMs, iLoMs, iShow, stLo, fs, cHi, cLo, cM, PS, ...
    '', sprintf('Motion, high amp:  %.2f vs %.2f z', mMs(iHiMs), mMs(iLoMs)), sprintf('%s %.1fV', lblMs, ampMs));

% row 2: AMP-0 (no stim) -- the non-stim-dependent demonstration
local_trace(nexttile(tl,3), tS, dfD0, iHiD0, iLoD0, iShow, stLo, fs, cHi, cLo, cD, PS, ...
    '\DeltaF/F (%)', sprintf('Rel \\delta, NO stim (0V):  %.2f vs %.2f', dD0(iHiD0), dD0(iLoD0)), sprintf('%s', lblD0));
local_trace(nexttile(tl,4), tS, dfM0, iHiM0, iLoM0, iShow, stLo, fs, cHi, cLo, cM, PS, ...
    '', sprintf('Motion, NO stim (0V):  %.2f vs %.2f z', mM0(iHiM0), mM0(iLoM0)), sprintf('%s', lblM0));

% row 3: state evidence for the row-1 (high-amp) trials
axb = nexttile(tl,5); hold(axb,'on');
bpHi = local_bp24(dfDs(iHiDs,:), fs);  bpLo = local_bp24(dfDs(iLoDs,:), fs);
patch(axb, [stLo -1/fs -1/fs stLo], [-1e3 -1e3 1e3 1e3], cD, 'EdgeColor','none');
plot(axb, tS, bpLo(iShow), '-', 'Color', cLo, 'LineWidth', PS.lw_trial+0.3);
plot(axb, tS, bpHi(iShow), '-', 'Color', cHi, 'LineWidth', PS.lw_mean);
xline(axb,0,'k-','LineWidth',0.6);  xlim(axb,[-1 1.5]);  ylim(axb, local_pad([bpHi(iShow) bpLo(iShow)]));
set(axb,'Box',PS.ax_box,'TickDir',PS.ax_tickdir,'FontSize',PS.fs,'FontWeight',PS.fw);
xlabel(axb,'time from onset (s)','FontSize',PS.fs,'FontWeight',PS.fw);  ylabel(axb,'2-4 Hz (%)','FontSize',PS.fs,'FontWeight',PS.fw);

axm = nexttile(tl,6); hold(axm,'on');
patch(axm, [stLo -1/fs -1/fs stLo], [-1e3 -1e3 1e3 1e3], cM, 'EdgeColor','none');
plot(axm, tS, moMs(iLoMs,iShow), '-', 'Color', cLo, 'LineWidth', PS.lw_trial+0.3);
plot(axm, tS, moMs(iHiMs,iShow), '-', 'Color', cHi, 'LineWidth', PS.lw_mean);
xline(axm,0,'k-','LineWidth',0.6);  xlim(axm,[-1 1.5]);  ylim(axm, local_pad([moMs(iHiMs,iShow) moMs(iLoMs,iShow)]));
set(axm,'Box',PS.ax_box,'TickDir',PS.ax_tickdir,'FontSize',PS.fs,'FontWeight',PS.fw);
xlabel(axm,'time from onset (s)','FontSize',PS.fs,'FontWeight',PS.fw);  ylabel(axm,'motion (z)','FontSize',PS.fs,'FontWeight',PS.fw);

outPng = fullfile(here,'figs','state_trialvar');  if ~exist(outPng,'dir'), mkdir(outPng); end
paperExport(f, fullfile(outPng, 'imp_state_examples.png'));
suppDir = fullfile(fileparts(here),'paper','images','supplementary');  if ~exist(suppDir,'dir'), mkdir(suppDir); end
paperExport(f, fullfile(suppDir, 'imp_state_examples.pdf'));
fprintf('[STE] done -> %s\n', suppDir);

% ================================================================================================
function local_trace(ax, tS, D, iHi, iLo, iShow, stLo, fs, cHi, cLo, shade, PS, ylab, ttl, corner)
hold(ax,'on');
patch(ax, [stLo -1/fs -1/fs stLo], [-1e3 -1e3 1e3 1e3], shade, 'EdgeColor','none');
plot(ax, tS, mean(D(:,iShow),1,'omitnan'), '--', 'Color',[0.2 0.2 0.2], 'LineWidth', PS.lw_fit);
plot(ax, tS, D(iLo,iShow), '-', 'Color', cLo, 'LineWidth', PS.lw_trial+0.3);
plot(ax, tS, D(iHi,iShow), '-', 'Color', cHi, 'LineWidth', PS.lw_mean);
xline(ax, 0, 'k-', 'LineWidth', 0.6);
xlim(ax,[-1 1.5]);  ylim(ax, local_pad([D(iHi,iShow) D(iLo,iShow)]));
set(ax,'Box',PS.ax_box,'TickDir',PS.ax_tickdir,'FontSize',PS.fs,'FontWeight',PS.fw);
if ~isempty(ylab), ylabel(ax, ylab, 'FontSize',PS.fs,'FontWeight',PS.fw); end
title(ax, ttl, 'FontSize',PS.fs,'FontWeight',PS.fw);
if ~isempty(corner)
    text(ax, 0.02, 0.03, corner, 'Units','normalized', 'FontSize',PS.fs-1, ...
         'Color',[0.45 0.45 0.45], 'VerticalAlignment','bottom');
end
end

function idx = local_setpick(v, mask, q)
mask = mask(:).';  vv = v; vv(~mask) = NaN;
tgt = quantile(vv(isfinite(vv)), q);
d = abs(vv - tgt);  d(~isfinite(d)) = inf;
[~, idx] = min(d);
end

function [df, mo, iHi, iLo, lbl, ampV] = local_pack(AE, G, gHi, fld, loq, iState, fs)
e = G(gHi).e;  a = G(gHi).a;  iHi = G(gHi).tr;
im = AE(e).imp;
df = im.dfImp{a};  mo = im.motTrace{a};
nn = min(size(df,1), size(mo,1));  df = df(1:nn,:);  mo = mo(1:nn,:);
if strcmp(fld,'mot'), v = mean(mo(:, iState), 2, 'omitnan');
else,                 [~, v] = local_delta_ste(df(:, iState), fs); end
iLo = local_nearest(v, quantile(v(isfinite(v)), loq));
lbl = sprintf('%s %s e%d', AE(e).mn, AE(e).td, AE(e).en);
ampV = im.uAmp(a);  if iscell(ampV), ampV = ampV{1}; end;  ampV = double(ampV);
end

function [dpa, dpr] = local_delta_ste(seg, fs)
n = size(seg,2);  w = hann(n).';
x = seg - mean(seg, 2, 'omitnan');  x(~isfinite(x)) = 0;
X = abs(fft(x .* w, [], 2)).^2;
f = (0:n-1) * (fs/n);  half = 1:floor(n/2);  f = f(half);  X = X(:,half);
bD = f >= 2 & f <= 4;  bT = f >= 0.4 & f <= 10;
dpa = sum(X(:,bD), 2);  dpr = dpa ./ max(sum(X(:,bT), 2), eps);
end

function y = local_bp24(x, fs)
x = x(:).';  x(~isfinite(x)) = 0;  x = x - mean(x);
n = numel(x);  X = fft(x);  f = (0:n-1)*(fs/n);
keep = (f >= 2 & f <= 4) | (f >= fs-4 & f <= fs-2);
X(~keep) = 0;  y = real(ifft(X));
end

function i = local_nearest(v, target)
v = v(:);  [~, i] = min(abs(v - target));
end

function yl = local_pad(v)
v = v(isfinite(v));  if isempty(v), yl = [-1 1]; return; end
lo = min(v); hi = max(v); pad = 0.08*max(hi-lo, eps);  yl = [lo-pad hi+pad];
end
