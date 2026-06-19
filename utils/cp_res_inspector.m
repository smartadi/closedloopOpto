function cp_res_inspector(S)
% Clickable residual state-dependence inspector (CP-RESi).
%
% Scatter row: dev_stim vs each state (motion / pre-stim var / delta), colored
% by amplitude. Click any point -> 3-row detail figure for that trial:
%   Row 1 — actual trace (-2..+2 s) + amplitude-average actual + contra prediction
%   Row 2 — residual (= stim response) + amplitude-average residual
%   Row 3 — motion (z) locked to onset
%
% S fields:
%   stateX  {1xP} cell of [nT x 1] state vectors (scatter x)
%   stateL  {1xP} cell of x-axis labels
%   devS    [nT x 1]  dev_stim (scatter y)
%   amp     [nT x 1]  amplitude label per trial (color)
%   tW      [1 x Lw]  wide time axis (s), -2..+2 re onset
%   actW    [nT x Lw] actual trace
%   prdW    [nT x Lw] contra (decontam) prediction
%   resW    [nT x Lw] residual (actual - contra pred)
%   motW    [nT x Lw] motion (z) trace

P    = numel(S.stateX);
uAmp = unique(S.amp(~isnan(S.amp)));
nA   = numel(uAmp);
cmap = lines(nA);

fig = figure('Name','CP-RESi Inspector', ...
    'Color','w','Units','centimeters','Position',[2 3 7*P 8]);
axh = gobjects(P,1);
for p = 1:P
    axh(p) = subplot(1,P,p,'Parent',fig); hold(axh(p),'on');
    for k = 1:nA
        m = S.amp==uAmp(k) & isfinite(S.stateX{p}) & isfinite(S.devS);
        scatter(axh(p), S.stateX{p}(m), S.devS(m), 14, cmap(k,:), ...
            'filled','MarkerFaceAlpha',0.55);
    end
    set(axh(p),'Box','off','TickDir','out','FontSize',6,'FontWeight','bold');
    xlabel(axh(p), S.stateL{p},'FontSize',6,'FontWeight','bold');
    if p==1, ylabel(axh(p),'dev_{stim} (z)','FontSize',6,'FontWeight','bold'); end
end
title(axh(1),'click a trial to inspect','FontSize',6,'FontWeight','bold');

data.S = S; data.axh = axh;
guidata(fig, data);
set(fig,'WindowButtonDownFcn',@cri_click);
end

% ── Callback: find which axes was clicked + nearest trial ────────────────────
function cri_click(fig, ~)
data = guidata(fig); S = data.S; axh = data.axh;
for p = 1:numel(axh)
    cp = axh(p).CurrentPoint; xc = cp(1,1); yc = cp(1,2);
    xl = axh(p).XLim; yl = axh(p).YLim;
    if xc>=xl(1) && xc<=xl(2) && yc>=yl(1) && yc<=yl(2)
        xr = diff(xl); yr = diff(yl);
        dd = ((S.stateX{p}-xc)/max(xr,eps)).^2 + ((S.devS-yc)/max(yr,eps)).^2;
        dd(~isfinite(dd)) = inf;
        [~, iT] = min(dd);
        cri_detail(iT, S, p);
        return;
    end
end
end

% ── Detail figure: 3 rows ────────────────────────────────────────────────────
function cri_detail(iT, S, p)
tW  = S.tW(:)';
amp = S.amp(iT);
mA  = S.amp==amp;
muAct = mean(S.actW(mA,:),1,'omitnan');
muRes = mean(S.resW(mA,:),1,'omitnan');

figD = figure('Name',sprintf('CP-RESi  Trial %d  A=%.2f  dev_{stim}=%.2f', ...
    iT, amp, S.devS(iT)), 'Color','w','Units','centimeters','Position',[14 2 11 13]);

ax1 = subplot(3,1,1,'Parent',figD); hold(ax1,'on');
plot(ax1,tW,muAct,'Color',[0.72 0.72 0.72],'LineWidth',1.5, ...
    'DisplayName',sprintf('Amp avg (n=%d)',sum(mA)));
plot(ax1,tW,S.actW(iT,:),'k-','LineWidth',1.2,'DisplayName','Trial actual');
plot(ax1,tW,S.prdW(iT,:),'Color',[0.15 0.35 0.85],'LineWidth',1.0, ...
    'LineStyle','--','DisplayName','Contra pred');
xline(ax1,0,'k:','HandleVisibility','off'); yline(ax1,0,'k:','HandleVisibility','off');
set(ax1,'Box','off','TickDir','out','FontSize',6,'FontWeight','bold');
ylabel(ax1,'\DeltaF/F (%)','FontSize',6,'FontWeight','bold');
title(ax1,sprintf('Trial %d  A=%.2f  (%s=%.2f)', iT, amp, S.stateL{p}, S.stateX{p}(iT)), ...
    'FontSize',6,'FontWeight','bold');
lg1 = legend(ax1,'Location','best','Box','off','FontSize',5);
try; set(lg1,'ItemTokenSize',[6 6]); catch; end

ax2 = subplot(3,1,2,'Parent',figD); hold(ax2,'on');
plot(ax2,tW,muRes,'Color',[0.72 0.72 0.72],'LineWidth',1.5,'DisplayName','Avg residual');
plot(ax2,tW,S.resW(iT,:),'Color',[0.85 0.15 0.15],'LineWidth',1.2,'DisplayName','Trial residual');
xline(ax2,0,'k:','HandleVisibility','off'); yline(ax2,0,'k:','HandleVisibility','off');
set(ax2,'Box','off','TickDir','out','FontSize',6,'FontWeight','bold');
ylabel(ax2,'Residual \DeltaF/F (%)','FontSize',6,'FontWeight','bold');
lg2 = legend(ax2,'Location','best','Box','off','FontSize',5);
try; set(lg2,'ItemTokenSize',[6 6]); catch; end

ax3 = subplot(3,1,3,'Parent',figD); hold(ax3,'on');
plot(ax3,tW,S.motW(iT,:),'Color',[0.20 0.60 0.40],'LineWidth',1.0);
xline(ax3,0,'k:','HandleVisibility','off'); yline(ax3,0,'k:','HandleVisibility','off');
set(ax3,'Box','off','TickDir','out','FontSize',6,'FontWeight','bold');
xlabel(ax3,'Time re onset (s)','FontSize',6,'FontWeight','bold');
ylabel(ax3,'Motion (z)','FontSize',6,'FontWeight','bold');
end
