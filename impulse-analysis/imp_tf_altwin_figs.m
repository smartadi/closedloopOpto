%% imp_tf_altwin_figs.m -- EXPLORATORY: old (0-0.5 s) vs alternative (-0.5..+1.0 s) impulse TF fits.
%
% Reads the two caches side by side and writes CANDIDATE panels as PNG to
% paper/images/figure2/alt_window/. Never writes PDFs, finals or the Fig-2 cache.
%   alt_fit_overlay.png   2 x nS: row 1 current fit (onset-referenced data, model extrapolated
%                         past 0.5 s dashed); row 2 alternative fit (pre-mean-referenced data,
%                         -0.5..+1.0 s). The rebound is judged here.
%   alt_tau_forest.png    dip (fastest mode) and rebound (slowest mode) tau per session, current
%                         vs alternative, with bootstrap 95% CIs; tau beyond 1.0 s off-scale.
%   alt_model_swap.png    cross-session model-swap R^2 (free gain) for the alternative fits,
%                         same computation as tf_model_swap (imp_tf_robust_fig panel D).
% Also prints the old-vs-new table (order, taus + CI, discard rate, pooled R^2, rebound capture).
%
% Needs allExperiments (or ALT_DATA = mat with variable A) for the measured traces beyond 0.5 s.

here = fileparts(mfilename('fullpath'));  root = fileparts(here);
addpath(fullfile(root,'utils'));
if ~exist('allExperiments','var') || isempty(allExperiments)
    assert(exist('ALT_DATA','var') && ~isempty(ALT_DATA), '[ALTFIG] run load_experiments.m or set ALT_DATA.');
    L = load(ALT_DATA);  allExperiments = L.A;  clear L
end
outDir = fullfile(root,'paper','images','figure2','alt_window');
if ~exist(outDir,'dir'), mkdir(outDir); end
O = load(fullfile(here,'data','imp_tf_fits.mat'));                 Sold = O.Sprim;
N = load(fullfile(here,'data','imp_tf_fits_win_m0p5_1p0.mat'));    Snew = N.Sprim;
nS = numel(Snew);  fs = 35;  Ts = 1/fs;  t = -3:Ts:3;
PS = paperStyle();  lblS = string(imp_mouse_label(Snew, 'short'));
tShow = [-0.5 1.0];  iShow = find(t >= tShow(1)-1e-9 & t <= tShow(2)+1e-9);  tt = t(iShow);

% ---- per-session numbers -----------------------------------------------------------------
R = struct();
for k = 1:nS
    A  = allExperiments(k);  uA = A.uAmp(:);  v = uA > 0;
    w  = uA(v).^2;  w = w/sum(w);
    DFon = A.DF_imp;                                                % onset-referenced (as loaded)
    DFpm = DFon - mean(DFon(:, t >= -0.5 & t < 0), 2, 'omitnan');   % pre-mean-referenced
    hOn  = sum(DFon(v, iShow)./uA(v).*w, 1, 'omitnan');
    hPm  = sum(DFpm(v, iShow)./uA(v).*w, 1, 'omitnan');
    so = Sold{k};  sn = Snew{k};
    mOld = i_sim(so.sys, tt, Ts);  mNew = i_sim(sn.sys, tt, Ts);
    R(k).hOn = hOn;  R(k).hPm = hPm;  R(k).mOld = mOld;  R(k).mNew = mNew;
    seg = @(a,b) tt >= a-1e-9 & tt <= b+1e-9;
    R(k).old_r2_05   = i_r2(hOn(seg(0,0.5)),   mOld(seg(0,0.5)));
    R(k).old_r2_reb  = i_r2(hOn(seg(0.25,1)),  mOld(seg(0.25,1)));     % extrapolated past 0.5 s
    R(k).new_r2_05   = i_r2(hPm(seg(0,0.5)),   mNew(seg(0,0.5)));
    R(k).new_r2_reb  = i_r2(hPm(seg(0.25,1)),  mNew(seg(0.25,1)));
    R(k).new_r2_pre  = i_r2(hPm(seg(-0.5,-1e-6)), mNew(seg(-0.5,-1e-6)));
    % rebound = max of the measured trace over 0.15-1.0 s (after the trough), vs the model's
    r = seg(0.15,1);  tr = tt(r);
    [R(k).rebMeas, i1] = max(hPm(r));  R(k).rebMeasT = tr(i1);
    [R(k).rebNew,  i2] = max(mNew(r)); R(k).rebNewT  = tr(i2);
    [R(k).rebOldMeas, i3] = max(hOn(r));  R(k).rebOldMeasT = tr(i3);
    [R(k).rebOld,  i4] = max(mOld(r));    R(k).rebOldT  = tr(i4);
    % pooled LTI R^2 of the NEW model restricted to 0-0.5 s (like-for-like with the old R2_pool)
    iP = find(t >= 0 & t <= 0.5);  hN = i_sim(sn.sys, t(iP), Ts);  yP = []; pP = [];
    for a = find(v).'
        y = DFpm(a, iP).';  yP = [yP; y]; pP = [pP; uA(a)*hN(:)];          %#ok<AGROW>
    end
    R(k).new_pool05 = i_r2(yP, pP);
    [R(k).oD, R(k).oDci, R(k).oR, R(k).oRci] = i_dipreb(so);
    [R(k).nD, R(k).nDci, R(k).nR, R(k).nRci] = i_dipreb(sn);
end

% ---- table -------------------------------------------------------------------------------
fprintf('\n================= OLD (0-0.5 s, onset ref, synthetic lead-in) vs NEW (-0.5..+1.0 s, pre-mean ref) =================\n');
for k = 1:nS
    so = Sold{k};  sn = Snew{k};
    fprintf('%-4s order  old %dp%dz%dd (%s)  | new %dp%dz%dd (%s)\n', lblS(k), so.np,so.nz,so.nd, so.selRule, sn.np,sn.nz,sn.nd, sn.selRule);
    fprintf('     dip tau     old %s | new %s\n', i_ci(R(k).oD, R(k).oDci), i_ci(R(k).nD, R(k).nDci));
    fprintf('     rebound tau old %s | new %s\n', i_ci(R(k).oR, R(k).oRci), i_ci(R(k).nR, R(k).nRci));
    fprintf('     boot discard old %.0f%% (beyond %.2f s %.0f%%, failed %.0f%%) | new %.0f%% (beyond %.2f s %.0f%%, failed %.0f%%)\n', ...
        100*i_fld(so,'tauBootReject'), i_fld(so,'tauMax'), 100*i_fld(so,'tauBootBeyond'), 100*i_fld(so,'tauBootFail'), ...
        100*i_fld(sn,'tauBootReject'), i_fld(sn,'tauMax'), 100*i_fld(sn,'tauBootBeyond'), 100*i_fld(sn,'tauBootFail'));
    fprintf('     pooled R2   old %.3f (0-0.5) | new %.3f (0-1.0), %.3f (0-0.5)\n', so.R2_pool, sn.R2_pool, R(k).new_pool05);
    fprintf('     R2 h 0-0.5  old %.3f | new %.3f ;  R2 0.25-1.0 s: old (extrapolated) %.3f | new %.3f ; new pre-window R2 %.3f\n', ...
        R(k).old_r2_05, R(k).new_r2_05, R(k).old_r2_reb, R(k).new_r2_reb, R(k).new_r2_pre);
    fprintf('     rebound peak  meas(pm) %+.3f @ %.2f s, new model %+.3f @ %.2f s | meas(onset) %+.3f @ %.2f s, old model %+.3f @ %.2f s\n', ...
        R(k).rebMeas, R(k).rebMeasT, R(k).rebNew, R(k).rebNewT, R(k).rebOldMeas, R(k).rebOldMeasT, R(k).rebOld, R(k).rebOldT);
end
ALTCMP = R;

% ---- panel 1: fit overlay ----------------------------------------------------------------
f1 = paperFig(4*nS, 7);
for k = 1:nS
    c = PS.sessColor(k);
    for row = 1:2
        ax = subplot(2, nS, (row-1)*nS + k);  hold(ax,'on');
        if row == 1, y = R(k).hOn; m = R(k).mOld; ttl = 'current'; else, y = R(k).hPm; m = R(k).mNew; ttl = 'alt'; end
        xline(ax, 0, ':', 'Color',[.5 .5 .5], 'LineWidth',PS.lw_zero);
        yline(ax, 0, '-', 'Color',[.75 .75 .75], 'LineWidth',PS.lw_zero);
        if row == 1, patch(ax, [0 0.5 0.5 0], [-10 -10 10 10], [.93 .93 .93], 'EdgeColor','none');
        else,        patch(ax, [-0.5 1 1 -0.5], [-10 -10 10 10], [.93 .93 .93], 'EdgeColor','none'); end
        plot(ax, tt, y, '-', 'Color', c, 'LineWidth', PS.lw_mean);
        if row == 1
            in = tt >= 0 & tt <= 0.5;  ex = tt >= 0.5;
            plot(ax, tt(tt<0), zeros(1,nnz(tt<0)), 'k--', 'LineWidth', PS.lw_fit);
            plot(ax, tt(in), m(in), 'k--', 'LineWidth', PS.lw_fit);
            plot(ax, tt(ex), m(ex), ':', 'Color',[.3 .3 .3], 'LineWidth', PS.lw_fit);
            txt = sprintf('R^2 %.2f | %.2f', R(k).old_r2_05, R(k).old_r2_reb);
        else
            plot(ax, tt, m, 'k--', 'LineWidth', PS.lw_fit);
            txt = sprintf('R^2 %.2f | %.2f', R(k).new_r2_05, R(k).new_r2_reb);
        end
        yl = [min([y m])-0.1, max([y m])+0.15];  ylim(ax, yl);  xlim(ax, tShow);
        title(ax, sprintf('%s %s', lblS(k), ttl), 'FontSize',PS.fs,'FontWeight',PS.fw);
        text(ax, 0.98, 0.06, txt, 'Units','normalized','HorizontalAlignment','right', ...
             'FontSize',PS.fs-1,'FontWeight',PS.fw);
        set(ax,'FontSize',PS.fs,'FontWeight',PS.fw,'TickDir','out','Box','off','Layer','top');
        if k == 1, ylabel(ax, '\DeltaF/F per V'); end
        if row == 2, xlabel(ax, 'time (s)'); end
    end
end
annotation(f1,'textbox',[0 0.955 1 0.045],'String', ...
    'shaded = fitted window | dashed = model | dotted = old model extrapolated | R^2: 0-0.5 s | 0.25-1.0 s (rebound)', ...
    'EdgeColor','none','HorizontalAlignment','center','FontSize',PS.fs,'FontWeight',PS.fw);
exportgraphics(f1, fullfile(outDir,'alt_fit_overlay.png'), 'Resolution', 300);

% ---- panel 2: tau forest old vs new --------------------------------------------------------
clipT = 1.0;
f2 = paperFig(7, 5);  ax = axes(f2);  hold(ax,'on');
for k = 1:nS
    c = PS.sessColor(k);
    rows = {k+0.17, R(k).oD, R(k).oDci, R(k).oR, R(k).oRci, [.55 .55 .55]; ...
            k-0.17, R(k).nD, R(k).nDci, R(k).nR, R(k).nRci, c};
    for r = 1:2
        [y, d, dci, rb, rbci, cc] = rows{r,:};
        if all(isfinite(dci)),  plot(ax, min(dci,clipT),  [y y]-0.05, '-', 'Color', cc, 'LineWidth', 0.6); end
        if all(isfinite(rbci)), plot(ax, min(rbci,clipT), [y y]+0.05, '-', 'Color', cc, 'LineWidth', 0.6); end
        if isfinite(d), plot(ax, min(d,clipT), y-0.05, 's', 'MarkerSize',3.2, 'MarkerEdgeColor',cc, 'MarkerFaceColor','none','LineWidth',0.6); end
        if isfinite(rb)
            if rb > clipT, plot(ax, clipT, y+0.05, '>', 'MarkerSize',3.5,'MarkerFaceColor',cc,'MarkerEdgeColor',cc);
            else,          plot(ax, rb,    y+0.05, 'o', 'MarkerSize',3.5,'MarkerFaceColor',cc,'MarkerEdgeColor',cc); end
        end
    end
end
xline(ax, 0.5, ':', 'Color',[.5 .5 .5]);
set(ax,'YTick',1:nS,'YTickLabel',cellstr(lblS),'YDir','reverse','FontSize',PS.fs,'FontWeight',PS.fw,'TickDir','out','Box','off');
xlim(ax,[0 clipT*1.05]);  ylim(ax,[0.4 nS+0.6]);  xlabel(ax,'\tau (s)');
title(ax,'grey = current 0-0.5 s | colour = alt -0.5..1.0 s ; square = dip, circle = rebound', ...
    'FontSize',PS.fs-1,'FontWeight',PS.fw);
exportgraphics(f2, fullfile(outDir,'alt_tau_forest.png'), 'Resolution', 300);

% ---- panel 3: model swap (alternative fits) -----------------------------------------------
RBn = imp_tf_robust_fig(Snew, outDir, struct('export',false,'panels',{{'D'}}));
figD = RBn.figs(end);
exportgraphics(figD, fullfile(outDir,'alt_model_swap.png'), 'Resolution', 300);
RBo = imp_tf_robust_fig(Sold, outDir, struct('export',false,'panels',{{}}));
fprintf('\nmodel swap: self R2 old %.3f new %.3f | off-diagonal mean old %.3f new %.3f, median old %.3f new %.3f\n', ...
    RBo.selfR2, RBn.selfR2, RBo.swapR2, RBn.swapR2, median(RBo.X(~eye(nS))), median(RBn.X(~eye(nS))));
ALTCMP(1).Xold = RBo.X;  ALTCMP(1).Xnew = RBn.X;
fprintf('[ALTFIG] panels -> %s\n', outDir);

% =========================================================================================
function y = i_sim(sys, tt, Ts)
% Model impulse response on the time grid tt (zero before onset, zero initial conditions).
n0 = nnz(tt < -1e-9);  n1 = numel(tt) - n0;
u  = [zeros(n0,1); 1; zeros(n1-1,1)];
o  = sim(sys, iddata([], u, Ts));
y  = o.OutputData(:).';
end
function r = i_r2(y, m)
y = y(:); m = m(:); v = isfinite(y) & isfinite(m);
r = 1 - sum((y(v)-m(v)).^2)/max(sum((y(v)-mean(y(v))).^2), eps);
end
function v = i_fld(s, f)
if isfield(s,f) && ~isempty(s.(f)), v = s.(f); else, v = NaN; end
end
function [d, dci, rb, rbci] = i_dipreb(s)
% rebound = slowest mode (imp_tf_robust_fig convention). dip = the FASTEST COMPLEX (oscillatory)
% pair, as the Fig-2F text defines it; falls back to the fastest mode when no pair exists. Taking
% the plain fastest mode would pick a 15 ms real pole in the new M1a fit. CI by the same pole.
d = NaN; dci = [NaN NaN]; rb = NaN; rbci = [NaN NaN];
tf = s.tau(:);  if isempty(tf), return; end
[rb, isl] = max(tf);
p  = s.poles(real(s.poles) < 0);  [~, o] = sort(-1./real(p), 'descend');  p = p(o);
isC = abs(imag(p)) > 1e-9;
if any(isC), ifa = find(isC, 1, 'last'); else, [~, ifa] = min(tf); end
tfa = tf(ifa);
if tfa < rb - 1e-9, d = tfa; end
if isfield(s,'tauCI') && ~isempty(s.tauCI)
    if isl <= size(s.tauCI,1), rbci = s.tauCI(isl,:); end
    if isfinite(d) && ifa <= size(s.tauCI,1), dci = s.tauCI(ifa,:); end
end
end
function s = i_ci(x, ci)
if ~isfinite(x), s = '      --          '; return; end
if all(isfinite(ci)), s = sprintf('%6.3f [%5.3f %5.3f]', x, ci(1), ci(2));
else,                 s = sprintf('%6.3f [  no CI    ]', x); end
end
