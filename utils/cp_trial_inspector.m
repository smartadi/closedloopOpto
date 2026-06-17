function cp_trial_inspector(S)
% Interactive motion-vs-error scatter for CP-6i trial inspection.
%
% S fields:
%   mot_all4   [nT x 1]  per-trial motion z-score
%   err_all4   [nT x 1]  per-trial prediction MSE
%   amp_all4   [nT x 1]  stimulus amplitude label per trial
%   act_all4   [nT x L]  actual trace (eval window, onset-baselined)
%   red_all4   [nT x L]  ARX+TF prediction (same window)
%   tEval      [1 x L]   time axis for act/red columns (s)
%   onset_all4 [nT x 1]  onset sample index into mot_z
%   mot_z      [nF x 1]  full-session motion z-score
%   Fs                   sample rate (Hz)
%
% Click any scatter point to open a 2-panel detail figure:
%   Top    — amplitude-average actual  +  trial actual  +  prediction
%   Bottom — z-scored motion locked to that trial's onset

uAmp = unique(S.amp_all4);
nA   = numel(uAmp);
cmap = lines(nA);

fig = figure('Name','CP-6i Trial Inspector', ...
    'Color','w','Units','centimeters','Position',[3 3 12 8]);
ax  = axes(fig, 'Units','normalized','Position',[0.10 0.14 0.85 0.78]);

hold(ax,'on');
hs = gobjects(nA,1);
for k = 1:nA
    m      = S.amp_all4 == uAmp(k);
    hs(k)  = scatter(ax, S.mot_all4(m), S.err_all4(m), 18, ...
        'MarkerFaceColor', cmap(k,:), 'MarkerEdgeColor','none', ...
        'MarkerFaceAlpha', 0.65, ...
        'DisplayName', sprintf('A=%.2f  (n=%d)', uAmp(k), sum(m)));
end
hold(ax,'off');

set(ax,'Box','off','TickDir','out','FontSize',6,'FontWeight','bold');
xlabel(ax,'Motion z-score','FontSize',6,'FontWeight','bold');
ylabel(ax,'Pred error (MSE 0–500 ms)','FontSize',6,'FontWeight','bold');
title(ax,'CP-6i  — click a trial to inspect','FontSize',6,'FontWeight','bold');
lg = legend(ax, hs,'Location','best','Box','off','FontSize',5);
try; set(lg,'ItemTokenSize',[6 6]); catch; end

% Store state — callbacks read via guidata(gcbf)
data.S    = S;
data.ax   = ax;
data.uAmp = uAmp;
data.cmap = cmap;
guidata(fig, data);

set(fig,'WindowButtonDownFcn', @cpi_click);
end

% ── Callback: find nearest trial and open detail window ──────────────────────
function cpi_click(fig, ~)
data = guidata(fig);
ax   = data.ax;
S    = data.S;

cp = ax.CurrentPoint;
xc = cp(1,1);  yc = cp(1,2);

xl = ax.XLim;  yl = ax.YLim;
if xc < xl(1) || xc > xl(2) || yc < yl(1) || yc > yl(2); return; end

xr = diff(xl);  yr = diff(yl);
dx = (S.mot_all4 - xc) / max(xr, eps);
dy = (S.err_all4 - yc) / max(yr, eps);
[~, iTrial] = min(dx.^2 + dy.^2);

cpi_detail(iTrial, S);
end

% ── Detail figure: trace + motion ────────────────────────────────────────────
function cpi_detail(iTrial, S)
tE    = S.tEval(:)';
actT  = S.act_all4(iTrial, :);
redT  = S.red_all4(iTrial, :);
ampT  = S.amp_all4(iTrial);
ionT  = S.onset_all4(iTrial);
L     = numel(tE);

mAmp  = S.amp_all4 == ampT;
muAmp = mean(S.act_all4(mAmp, :), 1, 'omitnan');

nMot  = numel(S.mot_z);
i0m   = max(1, ionT);
i1m   = min(ionT + L - 1, nMot);
nSeg  = i1m - i0m + 1;
tMot  = (0 : nSeg-1) / S.Fs;
motSeg = S.mot_z(i0m:i1m);

figD = figure('Name', sprintf('CP-6i  Trial %d  |  A=%.2f  mot=%.2f  err=%.4f', ...
    iTrial, ampT, S.mot_all4(iTrial), S.err_all4(iTrial)), ...
    'Color','w','Units','centimeters','Position',[16 3 10 10]);

axT = subplot(2,1,1,'Parent',figD);
hold(axT,'on');
plot(axT, tE, muAmp, 'Color',[0.72 0.72 0.72],'LineWidth',1.5, ...
    'DisplayName', sprintf('Amp avg (n=%d)', sum(mAmp)));
plot(axT, tE, actT,  'k-','LineWidth',1.2, 'DisplayName','Trial actual');
plot(axT, tE, redT,  'Color',[0.85 0.15 0.15],'LineWidth',1.0,'LineStyle','--', ...
    'DisplayName','Prediction (ARX+TF)');
xline(axT, 0, 'k:','LineWidth',0.5,'HandleVisibility','off');
yline(axT, 0, 'k:','LineWidth',0.3,'HandleVisibility','off');
hold(axT,'off');
set(axT,'Box','off','TickDir','out','FontSize',6,'FontWeight','bold');
ylabel(axT,'\DeltaF/F (%)','FontSize',6,'FontWeight','bold');
title(axT, sprintf('Trial %d  |  A=%.2f', iTrial, ampT),'FontSize',6,'FontWeight','bold');
lhD = legend(axT,'Location','best','Box','off','FontSize',5);
try; set(lhD,'ItemTokenSize',[6 6]); catch; end

axM = subplot(2,1,2,'Parent',figD);
plot(axM, tMot, motSeg, 'Color',[0.20 0.60 0.40],'LineWidth',1.0);
xline(axM, 0, 'k:','LineWidth',0.5,'HandleVisibility','off');
yline(axM, 0, 'k:','LineWidth',0.3,'HandleVisibility','off');
set(axM,'Box','off','TickDir','out','FontSize',6,'FontWeight','bold');
xlabel(axM,'Time re onset (s)','FontSize',6,'FontWeight','bold');
ylabel(axM,'Motion (z)','FontSize',6,'FontWeight','bold');
title(axM,'Motion energy (z-scored)','FontSize',6,'FontWeight','bold');
end
