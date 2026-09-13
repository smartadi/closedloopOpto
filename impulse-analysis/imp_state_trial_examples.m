% impulse-analysis/imp_state_trial_examples.m
% ============================================================================
% SUPPLEMENTARY: single-trial examples of HIGH vs LOW pre-stim state (motion,
% rel-delta), to make the state-dependence panels (Fig 2 G/H) concrete -- "what
% does a high-delta / high-motion trial actually look like?".
%
% For one session x amplitude it picks representative trials at the 90th and 10th
% percentile of each state and shows:
%   col 1 (rel-delta):  the impulse-response dF/F trace, high-delta vs low-delta,
%                       + a 2-4 Hz band-passed view of the PRE-STIM window so the
%                       rhythm that defines "high delta" is visible.
%   col 2 (motion):     the impulse-response dF/F trace, high- vs low-motion,
%                       + the rectified motion trace for the same two trials.
%
% Reuses allExperiments (run load_experiments first). State windows + rel-delta
% are computed IDENTICALLY to imp_state_trialvar.m so the examples match the panel.
%
% Config (optional, set before running):
%   STE_SESS  session index into allExperiments (default: the one with most trials)
%   STE_AMP   amplitude index          (default: the amp with the most trials)
%   STE_HIQ / STE_LOQ   high/low percentiles (default 0.90 / 0.10)
% OUTPUT: paper/images/supplementary/imp_state_examples.pdf  (+ .png review copy)
% ============================================================================
clc;
assert(exist('allExperiments','var')==1 && ~isempty(allExperiments), ...
       '[STE] allExperiments absent -- run load_experiments first.');
here = fileparts(which('imp_state_trial_examples'));
if isempty(here), here = fullfile(pwd,'impulse-analysis'); end
PS = paperStyle(); setPaperDefaults();

fs    = 35;
tAxis = -3 : 1/fs : 3;                       % dfImp column timebase
iOn   = find(tAxis >= 0, 1);
Lresp = numel(iOn+2 : iOn + round(0.22*fs));
iSham = find(tAxis >= -1.0, 1) + (0:Lresp-1);
stLo  = tAxis(iSham(end)) + 1/fs;            % state window starts where sham ends
iState = tAxis >= stLo & tAxis <= -1/fs;     % strictly pre-onset (matches STV 'pre')

% ---- gather per-trial state across ALL sessions x NON-ZERO amps ---------------------------------
% The examples must have a real impulse response, so amp 0 (sham) is excluded; and each state's
% examples are drawn from wherever that state is actually large (AL_0033 has little motion), so
% the two columns may come from different session/amp -- each is labelled with its own.
if ~exist('STE_HIQ','var')||isempty(STE_HIQ), STE_HIQ = 0.97; end   % "high" = 97th pct target
if ~exist('STE_LOQ','var')||isempty(STE_LOQ), STE_LOQ = 0.10; end
nE = numel(allExperiments);
G = struct('e',{},'a',{},'tr',{},'mot',{},'dpr',{});   % pooled trial index
for e = 1:nE
    im = allExperiments(e).imp;
    for a = 1:numel(im.uAmp)
        av = im.uAmp(a);  if iscell(av), av = av{1}; end;  av = double(av);
        if av <= 0, continue; end                          % skip sham
        d0 = im.dfImp{a};  m0 = im.motTrace{a};
        if isempty(d0) || isempty(m0), continue; end
        nn = min(size(d0,1), size(m0,1));  if nn < 8, continue; end
        mv = mean(m0(1:nn, iState), 2, 'omitnan');
        [~, dv] = local_delta_ste(d0(1:nn, iState), fs);
        for tr = 1:nn
            G(end+1) = struct('e',e,'a',a,'tr',tr,'mot',mv(tr),'dpr',dv(tr));
        end
    end
end
allMot = [G.mot];  allDpr = [G.dpr];
% high pick = the trial nearest the 97th-pct target (avoids a single wild outlier); its low
% counterpart is drawn from the SAME session x amp so the impulse response is comparable.
gHiD = local_nearest(allDpr, quantile(allDpr, STE_HIQ));
gHiM = local_nearest(allMot, quantile(allMot, STE_HIQ));

[dfD, moD, iHiD, iLoD, lblD, ampD] = local_pack(allExperiments, G, gHiD, 'dpr', STE_LOQ, iState, fs);
[dfM, moM, iHiM, iLoM, lblM, ampM] = local_pack(allExperiments, G, gHiM, 'mot', STE_LOQ, iState, fs);
[~, dprD] = local_delta_ste(dfD(:, iState), fs);
motM = mean(moM(:, iState), 2, 'omitnan');
fprintf('[STE] delta ex: %s %.2fV trial %d (rel-d %.2f)\n', lblD, ampD, iHiD, dprD(iHiD));
fprintf('[STE] motion ex: %s %.2fV trial %d (motion %.2f z)\n', lblM, ampM, iHiM, motM(iHiM));

% ---- display windows ----------------------------------------------------------------------------
iShow = tAxis >= -1.0 & tAxis <= 1.5;   tS = tAxis(iShow);
ampMeanD = mean(dfD, 1, 'omitnan');   ampMeanM = mean(dfM, 1, 'omitnan');
cHi = PS.col_ol;  cLo = [0.62 0.62 0.62];   % high = red, low = grey

f = paperFig(13, 8.5);
tl = tiledlayout(f, 2, 2, 'TileSpacing','compact', 'Padding','compact');
title(tl, 'Single-trial examples: high vs low pre-stim state  (dashed = amplitude mean; shaded = state window)', ...
      'FontSize', PS.fs, 'FontWeight', PS.fw);

% ===== col 1: REL-DELTA =====
ax = nexttile(tl,1); hold(ax,'on');
patch(ax, [stLo -1/fs -1/fs stLo], [-1e3 -1e3 1e3 1e3], [0.90 0.90 0.98], 'EdgeColor','none');
plot(ax, tS, ampMeanD(iShow), '--', 'Color',[0.2 0.2 0.2], 'LineWidth', PS.lw_fit);
plot(ax, tS, dfD(iLoD,iShow), '-', 'Color', cLo, 'LineWidth', PS.lw_trial+0.3);
plot(ax, tS, dfD(iHiD,iShow), '-', 'Color', cHi, 'LineWidth', PS.lw_mean);
xline(ax, 0, 'k-', 'LineWidth', 0.6);
ylim(ax, local_pad([dfD(iHiD,iShow) dfD(iLoD,iShow)]));  xlim(ax,[-1 1.5]);
set(ax,'Box',PS.ax_box,'TickDir',PS.ax_tickdir,'FontSize',PS.fs,'FontWeight',PS.fw);
ylabel(ax,'\DeltaF/F (%)','FontSize',PS.fs,'FontWeight',PS.fw);
title(ax, sprintf('Rel \\delta:  high %.2f  vs  low %.2f', dprD(iHiD), dprD(iLoD)), ...
      'FontSize',PS.fs,'FontWeight',PS.fw);
text(ax, 0.02, 0.03, sprintf('%s  %.1fV', lblD, ampD), 'Units','normalized', ...
     'FontSize',PS.fs-1, 'Color',[0.45 0.45 0.45], 'VerticalAlignment','bottom');

% band-passed pre-stim (2-4 Hz) view = the rhythm that "high delta" measures
axb = nexttile(tl,3); hold(axb,'on');
bpHi = local_bp24(dfD(iHiD,:), fs);  bpLo = local_bp24(dfD(iLoD,:), fs);
patch(axb, [stLo -1/fs -1/fs stLo], [-1e3 -1e3 1e3 1e3], [0.90 0.90 0.98], 'EdgeColor','none');
plot(axb, tS, bpLo(iShow), '-', 'Color', cLo, 'LineWidth', PS.lw_trial+0.3);
plot(axb, tS, bpHi(iShow), '-', 'Color', cHi, 'LineWidth', PS.lw_mean);
xline(axb, 0, 'k-', 'LineWidth', 0.6);
ylim(axb, local_pad([bpHi(iShow) bpLo(iShow)]));  xlim(axb,[-1 1.5]);
set(axb,'Box',PS.ax_box,'TickDir',PS.ax_tickdir,'FontSize',PS.fs,'FontWeight',PS.fw);
xlabel(axb,'time from onset (s)','FontSize',PS.fs,'FontWeight',PS.fw);
ylabel(axb,'2-4 Hz (%)','FontSize',PS.fs,'FontWeight',PS.fw);

% ===== col 2: MOTION =====
ax2 = nexttile(tl,2); hold(ax2,'on');
patch(ax2, [stLo -1/fs -1/fs stLo], [-1e3 -1e3 1e3 1e3], [0.92 0.92 0.92], 'EdgeColor','none');
plot(ax2, tS, ampMeanM(iShow), '--', 'Color',[0.2 0.2 0.2], 'LineWidth', PS.lw_fit);
plot(ax2, tS, dfM(iLoM,iShow), '-', 'Color', cLo, 'LineWidth', PS.lw_trial+0.3);
plot(ax2, tS, dfM(iHiM,iShow), '-', 'Color', cHi, 'LineWidth', PS.lw_mean);
xline(ax2, 0, 'k-', 'LineWidth', 0.6);
ylim(ax2, local_pad([dfM(iHiM,iShow) dfM(iLoM,iShow)]));  xlim(ax2,[-1 1.5]);
set(ax2,'Box',PS.ax_box,'TickDir',PS.ax_tickdir,'FontSize',PS.fs,'FontWeight',PS.fw);
title(ax2, sprintf('Motion:  high %.2f  vs  low %.2f z', motM(iHiM), motM(iLoM)), ...
      'FontSize',PS.fs,'FontWeight',PS.fw);
text(ax2, 0.02, 0.03, sprintf('%s  %.1fV', lblM, ampM), 'Units','normalized', ...
     'FontSize',PS.fs-1, 'Color',[0.45 0.45 0.45], 'VerticalAlignment','bottom');

% the motion traces themselves = what "high motion" means
axm = nexttile(tl,4); hold(axm,'on');
patch(axm, [stLo -1/fs -1/fs stLo], [-1e3 -1e3 1e3 1e3], [0.92 0.92 0.92], 'EdgeColor','none');
plot(axm, tS, moM(iLoM,iShow), '-', 'Color', cLo, 'LineWidth', PS.lw_trial+0.3);
plot(axm, tS, moM(iHiM,iShow), '-', 'Color', cHi, 'LineWidth', PS.lw_mean);
xline(axm, 0, 'k-', 'LineWidth', 0.6);
ylim(axm, local_pad([moM(iHiM,iShow) moM(iLoM,iShow)]));  xlim(axm,[-1 1.5]);
set(axm,'Box',PS.ax_box,'TickDir',PS.ax_tickdir,'FontSize',PS.fs,'FontWeight',PS.fw);
xlabel(axm,'time from onset (s)','FontSize',PS.fs,'FontWeight',PS.fw);
ylabel(axm,'motion (z)','FontSize',PS.fs,'FontWeight',PS.fw);

outPng = fullfile(here,'figs','state_trialvar');
if ~exist(outPng,'dir'), mkdir(outPng); end
paperExport(f, fullfile(outPng, 'imp_state_examples.png'));
suppDir = fullfile(fileparts(here),'paper','images','supplementary');
if ~exist(suppDir,'dir'), mkdir(suppDir); end
paperExport(f, fullfile(suppDir, 'imp_state_examples.pdf'));
fprintf('[STE] done -> %s\n', suppDir);

% ------------------------------------------------------------------------------------------------
function [df, mo, iHi, iLo, lbl, ampV] = local_pack(AE, G, gHi, fld, loq, iState, fs)
% Given the pooled high pick gHi, return that session x amp's trace matrices, the high trial row,
% and a matched LOW trial row from the SAME session x amp (so the impulse response is comparable).
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

function [dpa, dpr] = local_delta_ste(seg, fs)   % identical to imp_state_trialvar local_delta
n = size(seg,2);  w = hann(n).';
x = seg - mean(seg, 2, 'omitnan');  x(~isfinite(x)) = 0;
X = abs(fft(x .* w, [], 2)).^2;
f = (0:n-1) * (fs/n);  half = 1:floor(n/2);  f = f(half);  X = X(:,half);
bD = f >= 2 & f <= 4;  bT = f >= 0.4 & f <= 10;
dpa = sum(X(:,bD), 2);  dpr = dpa ./ max(sum(X(:,bT), 2), eps);
end

function y = local_bp24(x, fs)   % 2-4 Hz band-pass by spectral masking (no toolbox filter design)
x = x(:).';  x(~isfinite(x)) = 0;  x = x - mean(x);
n = numel(x);  X = fft(x);  f = (0:n-1)*(fs/n);
keep = (f >= 2 & f <= 4) | (f >= fs-4 & f <= fs-2);   % symmetric band for a real signal
X(~keep) = 0;  y = real(ifft(X));
end

function i = local_nearest(v, target)
v = v(:);  [~, i] = min(abs(v - target));
end

function yl = local_pad(v)
v = v(isfinite(v));  if isempty(v), yl = [-1 1]; return; end
lo = min(v); hi = max(v); pad = 0.08*max(hi-lo, eps);  yl = [lo-pad hi+pad];
end
