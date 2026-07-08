function out = cp_spont_predq(P)
% cp_spont_predq — spontaneous (non-stim) contra->ipsi predictability vs brain state,
% with a CLICKABLE inspector.
% ------------------------------------------------------------------------------
% Deploys the full contra readout on the SPONTANEOUS recording (all frames >=1.5 s
% pre / 2.5 s post any stim onset), windows it (~1.5 s, matching the peri state
% window), and per window computes local R^2 (contra->ipsi predictability) vs four
% brain-state measures, FLAGGING which are independent of signal power:
%   Motion energy  (mean|z|)         power-INDEP (behavioral)   -- the meaningful test
%   Variance var(y)                  power-CONFOUND (var is R^2's denominator)
%   abs delta power 1-4 Hz           power-CONFOUND (~ signal power)
%   Relative delta (delta/total)     power-INDEP (spectral ratio)
% Result (AL_0033 0129 e1): Motion rho~-0.01 (NULL), Variance +0.79 / abs-delta +0.67
% (both confounded), Relative-delta +0.29 (genuine). => predictability is motion-
% invariant and modestly higher in synchronized states. (RESEARCH 2026-07-02.)
% CLICK any scatter point -> a detail figure for that window: the actual trace
% (trial), the contra prediction, and the MEAN-CORRECTED prediction (DC re-aligned to
% the window), plus the residual. Exports cp_spont_r2_vs_state.png.
%
% INPUT P (struct): pixw[Npix x1] (h_pixw); U_K[Npix x K] (U_svd_raw(:,1:h_K));
%   V_c[K x nFrames] (V_c_full(1:h_K,:)); y[nFrames x1] (y_full); tr[.] train frames
%   for DC align (h_tr); mI_kern (h_mI_kern); onf[nT x1] stim onset frames (b_onf);
%   mot[nFrames x1] per-frame motion (mot_full); Fs; paper_root; (optional) mn/td/en,
%   winSec (1.5), interactive (true).
K = size(P.U_K,2);  sc = 100/P.mI_kern;  Fs = P.Fs;
winSec = 1.5;  if isfield(P,'winSec') && ~isempty(P.winSec), winSec = P.winSec; end
interactive = true;  if isfield(P,'interactive') && ~isempty(P.interactive), interactive = P.interactive; end
disc_thr = 3;  if isfield(P,'disc_thr') && ~isempty(P.disc_thr), disc_thr = P.disc_thr; end
targ_smooth = 1;  if isfield(P,'targ_smooth') && ~isempty(P.targ_smooth), targ_smooth = P.targ_smooth; end
nF = min([numel(P.y), size(P.V_c,2), numel(P.mot)]);

% --- full-frame contra->ipsi prediction (DC aligned on train frames) --------------
w    = P.U_K.' * P.pixw;
yhat = (P.V_c(:,1:nF).' * w) * sc;
yhat = yhat + mean(P.y(P.tr) - yhat(P.tr), 'omitnan');
y    = P.y(1:nF);  res = y - yhat;
mot  = P.mot(1:nF);  motz = (mot - mean(mot,'omitnan')) / max(std(mot,'omitnan'), eps);

% --- prediction-discontinuity guard -----------------------------------------------
% The redoSVD-reorthogonalized V_c mode 1 carries rare single-frame LEVEL SHIFTS that
% leak into the K-truncated readout but are ABSENT from the raw contra data and the
% (slow GCaMP) ipsi target (verified: raw contra-mean smooth at the flagged frames,
% no timestamp gap, no motion). A > disc_thr %dF/F single-frame jump in the prediction
% while the target is smooth (< targ_smooth) is non-physical for the slow indicator ->
% flag the frame; any window straddling one is dropped (its R^2 is a step artifact,
% not dynamics). ~46/193k frames on AL_0033 0129 e1 -> 4/534 windows; aggregate rho
% shifts <=0.005, but the flagged windows are the spurious very-negative-R^2 tail.
dYh = abs([0; diff(yhat)]);  dYt = abs([0; diff(y)]);
discFrame = dYh > disc_thr & dYt < targ_smooth;

% --- spontaneous mask: drop everything near a stim onset --------------------------
spont = true(nF,1);  gpre = round(1.5*Fs);  gpost = round(2.5*Fs);
for o = P.onf(:)'
    if o >= 1 && o <= nF, spont(max(1,o-gpre):min(nF,o+gpost)) = false; end
end

% --- window into contiguous non-stim segments; per-window metrics + state ---------
Lw = round(winSec*Fs);  win = hann(Lw);  Wn = sum(win.^2);  nfft = 2^nextpow2(Lw);
fr = (0:nfft-1)'/nfft*Fs;  nB = floor(nfft/2)+1;  dband = fr(1:nB)>=1 & fr(1:nB)<=4;
winIdx = {};  lr2=[]; rho=[]; motE=[]; pv=[]; dpow=[]; drel=[];  s = 1;  nDisc = 0;
while s+Lw-1 <= nF
    idx = s:s+Lw-1;
    if all(spont(idx)) && any(discFrame(idx))   % otherwise-clean window with a prediction step
        nDisc = nDisc + 1;  s = s + round(Lw/3);  continue;
    end
    if all(spont(idx))
        yv = y(idx);  yh = yhat(idx);  rv = res(idx);
        winIdx{end+1,1} = idx;                                  %#ok<AGROW>
        lr2(end+1,1)  = 1 - var(rv)/max(var(yv),eps);           %#ok<AGROW>
        rho(end+1,1)  = corr(yv, yh);                           %#ok<AGROW>
        motE(end+1,1) = mean(abs(motz(idx)),'omitnan');         %#ok<AGROW>
        pv(end+1,1)   = var(yv,'omitnan');                      %#ok<AGROW>
        Xf = fft(yv(:).*win, nfft);  pw = abs(Xf(1:nB)).^2 * 2/(Fs*Wn);
        dpow(end+1,1) = mean(pw(dband),'omitnan');              %#ok<AGROW>
        drel(end+1,1) = sum(pw(dband))/max(sum(pw),eps);        %#ok<AGROW>
        s = s + Lw;
    else
        s = s + round(Lw/3);
    end
end
states  = [motE pv dpow drel];
statesL = {'Motion energy (|z|)','Variance  var(y)','\delta power 1-4 Hz (abs)','Relative \delta  (\delta/total)'};
flags   = {'power-INDEP','power-CONFOUND','power-CONFOUND','power-INDEP'};

fprintf('\n[CP-PREDQ] spontaneous contra->ipsi predictability vs state (%s %s e%d): %d non-stim windows (%d dropped: prediction-discontinuity guard, %d flagged frames)\n', ...
    getf(P,'mn','?'), getf(P,'td','?'), getf(P,'en',0), numel(lr2), nDisc, nnz(discFrame & spont));
for k = 1:4
    [rr,pp] = corr(states(:,k), lr2, 'type','Spearman');
    fprintf('   R^2 vs %-26s rho=%+.2f (p=%.1g)  [%s]\n', statesL{k}, rr, pp, flags{k});
end

% --- figure: R^2 vs each state (clickable) ----------------------------------------
fig = figure('Name','CP-PREDQ  (click a point to inspect the window)','Color','w','Position',[40 40 1520 400]);
ax = gobjects(4,1);
for k = 1:4
    x = states(:,k);  ax(k) = subplot(1,4,k,'Parent',fig);  hold(ax(k),'on');
    scatter(ax(k), x, lr2, 11, [0.35 0.45 0.85], 'filled', 'MarkerFaceAlpha',0.30);
    e = quantile(x, linspace(0,1,9));  b = discretize(x,e);  b(isnan(b)) = 8;
    mx = accumarray(b, x, [8 1], @median, NaN);  my = accumarray(b, lr2, [8 1], @median, NaN);
    ey = accumarray(b, lr2, [8 1], @(v) std(v)/sqrt(numel(v)), NaN);
    errorbar(ax(k), mx, my, ey, 'k-o', 'LineWidth',2, 'MarkerFaceColor','k', 'MarkerSize',5, 'CapSize',3);
    [rr,pp] = corr(x, lr2, 'type','Spearman');
    ylim(ax(k), [-1.2 1.08]);  xlim(ax(k), [min(x) quantile(x,0.99)]);
    xlabel(ax(k), statesL{k}, 'FontWeight','bold');  if k==1, ylabel(ax(k),'local R^2  (contra\rightarrowipsi)','FontWeight','bold'); end
    tc = [0 0 0];  if abs(rr)<0.05, tc = [0 0.55 0]; end
    title(ax(k), {sprintf('\\rho=%+.2f  (p=%.1g)',rr,pp), flags{k}}, 'FontWeight','bold','FontSize',9,'Color',tc);
    yline(ax(k), median(lr2), ':', 'Color',[0.5 0.5 0.5]);  set(ax(k),'Box','off','TickDir','out');  grid(ax(k),'on');
end
sgtitle(fig, sprintf('Spontaneous contra\\rightarrowipsi predictability vs brain state  (%s %s e%d, %d non-stim windows)  —  click a point', ...
    getf(P,'mn','?'), getf(P,'td','?'), getf(P,'en',0), numel(lr2)), 'FontWeight','bold','FontSize',11);
exportgraphics(fig, fullfile(P.paper_root,'cp_spont_r2_vs_state.png'), 'Resolution',220);
fprintf('[CP-PREDQ] exported cp_spont_r2_vs_state.png\n');

% --- attach the clickable inspector ----------------------------------------------
if interactive
    D = struct('states',states,'lr2',lr2,'rho',rho,'winIdx',{winIdx},'y',y,'yhat',yhat, ...
               'Fs',Fs,'ax',ax,'statesL',{statesL},'motE',motE,'pv',pv,'dpow',dpow,'drel',drel, ...
               'motz',motz);
    guidata(fig, D);  set(fig,'WindowButtonDownFcn',@predq_click);
    fprintf('[CP-PREDQ] click any scatter point -> window detail (actual / prediction / mean-corrected).\n');
end

out = struct('lr2',lr2,'rho',rho,'states',states,'statesL',{statesL},'winIdx',{winIdx}, ...
             'n',numel(lr2),'nDisc',nDisc,'discFrame',find(discFrame));
end

% ── Callback: which axes, nearest window ─────────────────────────────────────────
function predq_click(fig, ~)
D = guidata(fig);
for k = 1:numel(D.ax)
    cp = D.ax(k).CurrentPoint;  xc = cp(1,1);  yc = cp(1,2);
    xl = D.ax(k).XLim;  yl = D.ax(k).YLim;
    if xc>=xl(1) && xc<=xl(2) && yc>=yl(1) && yc<=yl(2)
        dd = ((D.states(:,k)-xc)/max(diff(xl),eps)).^2 + ((D.lr2-yc)/max(diff(yl),eps)).^2;
        dd(~isfinite(dd)) = inf;  [~, j] = min(dd);
        predq_detail(D, j);  return;
    end
end
end

% ── Detail figure for window j ───────────────────────────────────────────────────
function predq_detail(D, j)
idx = D.winIdx{j};  tt = (0:numel(idx)-1)/D.Fs;
yv = D.y(idx);  yh = D.yhat(idx);
yh_mc = yh - mean(yh,'omitnan') + mean(yv,'omitnan');    % mean-corrected prediction (DC re-aligned to window)
r_mc  = yv - yh_mc;
mv    = D.motz(idx);                                     % z-scored motion over the window
figD = figure('Name',sprintf('CP-PREDQ  window %d  |  R^2=%.2f  corr=%.2f',j,D.lr2(j),D.rho(j)), ...
    'Color','w','Position',[220 90 620 640]);
ax1 = subplot(3,1,1,'Parent',figD); hold(ax1,'on');
plot(ax1, tt, yv,    'k-',  'LineWidth',1.6, 'DisplayName','trial (actual)');
plot(ax1, tt, yh,    'r-',  'LineWidth',1.2, 'DisplayName','prediction');
plot(ax1, tt, yh_mc, 'b--', 'LineWidth',1.2, 'DisplayName','mean-corrected prediction');
yline(ax1,0,'k:','HandleVisibility','off'); set(ax1,'Box','off','TickDir','out');
ylabel(ax1,'\DeltaF/F (%)','FontWeight','bold');
legend(ax1,'Location','best','Box','off','FontSize',8);
title(ax1, sprintf('window %d  |  R^2=%.2f  corr=%.2f  |  motion=%.2f  var=%.2f  \\delta=%.2f  rel\\delta=%.2f', ...
    j, D.lr2(j), D.rho(j), D.motE(j), D.pv(j), D.dpow(j), D.drel(j)), 'FontWeight','bold','FontSize',9);
ax2 = subplot(3,1,2,'Parent',figD); hold(ax2,'on');
plot(ax2, tt, r_mc, 'Color',[0.85 0.15 0.15], 'LineWidth',1.4, 'DisplayName','residual (actual - mean-corr pred)');
yline(ax2,0,'k:','HandleVisibility','off'); set(ax2,'Box','off','TickDir','out');
ylabel(ax2,'residual \DeltaF/F (%)','FontWeight','bold');
legend(ax2,'Location','best','Box','off','FontSize',8);
ax3 = subplot(3,1,3,'Parent',figD); hold(ax3,'on');
plot(ax3, tt, mv, 'Color',[0.20 0.55 0.25], 'LineWidth',1.4, 'DisplayName','motion (z)');
yline(ax3,0,'k:','HandleVisibility','off'); set(ax3,'Box','off','TickDir','out');
xlabel(ax3,'time in window (s)','FontWeight','bold');  ylabel(ax3,'motion (z)','FontWeight','bold');
legend(ax3,'Location','best','Box','off','FontSize',8);
linkaxes([ax1 ax2 ax3],'x');  xlim(ax3,[tt(1) tt(end)]);
end

% ── small helper ─────────────────────────────────────────────────────────────────
function v = getf(S,f,d)
if isfield(S,f) && ~isempty(S.(f)); v = S.(f); else; v = d; end
end
