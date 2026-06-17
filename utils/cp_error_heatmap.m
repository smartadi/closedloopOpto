function cp_error_heatmap(S)
% Per-amplitude error-sorted heatmap for CP-7.
%
% S fields:
%   actual4   {nAmp x 1}  per-amplitude actual traces [nT x outlen]
%   pink4     {nAmp x 1}  contra-SVD prediction
%   red4      {nAmp x 1}  ARX+TF prediction (finalized)
%   err4      {nAmp x 1}  per-trial pred error [nT x 1]
%   tEval     [1 x L]     time axis (s) for iEval columns
%   uAmp_cp   [nAmp x 1]  amplitude values
%   ia_list4  [k x 1]     non-zero amplitude indices into uAmp_cp / *4 cells
%   iEval     [1 x L]     column indices into each *4{ia} matrix
%   err_end_s             pred-error window end (s)
%   mn, td, en            session metadata strings/numbers
%   paper_root            root path for figure export
%
% Click any heatmap row to open a detail figure:
%   actual trace + amplitude average + contra SVD + ARX+TF prediction.

nAmps = numel(S.ia_list4);
tMs   = S.tEval(:)' * 1000;   % s → ms

% Blue-white-red diverging colormap
cmap7 = interp1([0;0.5;1],[0 0.2 0.8; 1 1 1; 0.8 0.1 0.1], ...
    linspace(0,1,256)','linear');

w_cm = max(10, 4.5 * nAmps);
fig  = figure('Name', sprintf('CP-7  %s %s e%d  error-sorted heatmap', S.mn, S.td, S.en), ...
    'Color','w','Units','centimeters','Position',[2 2 w_cm 14]);

lm=0.07;  rm=0.06;  bm=0.09;  tm=0.08;
gx = min(0.04, 0.02 * nAmps);
pw = (1-lm-rm-(nAmps-1)*gx) / max(nAmps,1);
ph = 1-bm-tm;

data.S        = S;
data.nAmps    = nAmps;
data.axList   = gobjects(nAmps, 1);
data.sortIdx  = cell(nAmps, 1);
data.tMs      = tMs;
data.cmap7    = cmap7;

for k = 1:nAmps
    ia     = S.ia_list4(k);
    act_k  = S.actual4{ia}(:, S.iEval);   % [nT x L]
    err_k  = S.err4{ia}(:);

    validK = find(~all(isnan(act_k),2) & isfinite(err_k));
    if isempty(validK)
        data.sortIdx{k} = int32([]);
        continue
    end
    [~, si]         = sort(err_k(validK), 'ascend');
    sortedRows      = validK(si);
    data.sortIdx{k} = sortedRows;

    mat_k = act_k(sortedRows, :);   % [nSorted x L], best-predicted at row 1

    clim7 = max(abs(mat_k(:)),[],'omitnan');
    if clim7 < 1e-6; clim7 = 1; end

    xL = lm + (k-1)*(pw+gx);
    ax = axes(fig, 'Position',[xL, bm, pw, ph]);

    imagesc(ax, tMs, 1:numel(sortedRows), mat_k, [-clim7 clim7]);
    colormap(ax, cmap7);
    set(ax,'YDir','normal','Box','off','TickDir','out', ...
        'FontSize',6,'FontWeight','bold');
    xlabel(ax,'Time (ms)','FontSize',6,'FontWeight','bold');
    if k == 1
        ylabel(ax,'Trial rank  (1=best prediction)','FontSize',6,'FontWeight','bold');
    else
        set(ax,'YTickLabel',{});
    end
    title(ax, sprintf('A=%.2f  n=%d', S.uAmp_cp(ia), numel(sortedRows)), ...
        'FontSize',6,'FontWeight','bold');

    hold(ax,'on');
    xline(ax, 0, 'w-','LineWidth',1.0,'HandleVisibility','off');
    xline(ax, S.err_end_s*1000,'Color',[1 0.85 0.3],'LineWidth',0.8,'HandleVisibility','off');
    hold(ax,'off');

    if k == nAmps
        cb = colorbar(ax,'Location','eastoutside');
        cb.FontSize    = 5;
        cb.Label.String = '\DeltaF/F (%)';
        cb.Label.FontSize = 6;
        cb.Label.FontWeight = 'bold';
    end

    data.axList(k) = ax;
end

guidata(fig, data);
set(fig,'WindowButtonDownFcn', @ceh_click);

sgtitle(fig, sprintf('CP-7  error-sorted trials  |  %s %s e%d  (click row to inspect)', ...
    S.mn, S.td, S.en), 'FontSize',6,'FontWeight','bold');

paperExport(fig, fullfile(S.paper_root,'images','figure2','cp7_error_heatmap.png'));
fprintf('[CP-7] Heatmap exported. Click any trial row to inspect.\n');
end

% ── Click callback ────────────────────────────────────────────────────────────
function ceh_click(fig, ~)
data = guidata(fig);
for k = 1:data.nAmps
    ax = data.axList(k);
    if ~isvalid(ax); continue; end
    cp = ax.CurrentPoint;
    xc = cp(1,1);  yc = cp(1,2);
    xl = ax.XLim;  yl = ax.YLim;
    if xc >= xl(1) && xc <= xl(2) && yc >= yl(1) && yc <= yl(2)
        rank       = round(yc);
        sortedRows = data.sortIdx{k};
        if isempty(sortedRows) || rank < 1 || rank > numel(sortedRows); return; end
        ceh_detail(k, sortedRows(rank), rank, data);
        return
    end
end
end

% ── Detail figure ─────────────────────────────────────────────────────────────
function ceh_detail(k, iTrial, rank, data)
S      = data.S;
tMs    = data.tMs;
ia     = S.ia_list4(k);

actT   = S.actual4{ia}(iTrial, S.iEval);
redT   = S.red4{ia}(iTrial, S.iEval);
pinkT  = S.pink4{ia}(iTrial, S.iEval);
errT   = S.err4{ia}(iTrial);

actAll = S.actual4{ia}(:, S.iEval);
valAll = find(~all(isnan(actAll),2));
muAmp  = mean(actAll(valAll,:), 1, 'omitnan');
semAmp = std(actAll(valAll,:), 0, 1, 'omitnan') / sqrt(max(numel(valAll),1));

figD = figure('Name', sprintf('CP-7  A=%.2f  rank=%d  trial=%d  err=%.4f', ...
    S.uAmp_cp(ia), rank, iTrial, errT), ...
    'Color','w','Units','centimeters','Position',[17 3 11 8]);

ax1 = axes(figD,'Position',[0.11 0.13 0.83 0.76]);
hold(ax1,'on');
fill(ax1,[tMs fliplr(tMs)],[muAmp+semAmp fliplr(muAmp-semAmp)], ...
    [0.72 0.72 0.72],'FaceAlpha',0.25,'EdgeColor','none','HandleVisibility','off');
plot(ax1, tMs, muAmp,  'Color',[0.55 0.55 0.55],'LineWidth',1.5, ...
    'DisplayName', sprintf('Amp avg (n=%d)', numel(valAll)));
plot(ax1, tMs, pinkT,  'Color',[0.2 0.5 0.9],'LineWidth',1.0,'LineStyle','--', ...
    'DisplayName','Contra SVD');
plot(ax1, tMs, redT,   'Color',[0.85 0.15 0.15],'LineWidth',1.0,'LineStyle','--', ...
    'DisplayName','ARX+TF pred');
plot(ax1, tMs, actT,   'k-','LineWidth',1.5, ...
    'DisplayName', sprintf('Trial %d  (rank %d, err=%.4f)', iTrial, rank, errT));
xline(ax1, 0,                   'k:','LineWidth',0.5,'HandleVisibility','off');
xline(ax1, S.err_end_s*1000, 'Color',[0.7 0.5 0],'LineStyle',':','LineWidth',0.8,'HandleVisibility','off');
yline(ax1, 0, 'k:','LineWidth',0.3,'HandleVisibility','off');
hold(ax1,'off');
set(ax1,'Box','off','TickDir','out','FontSize',6,'FontWeight','bold');
xlabel(ax1,'Time (ms)','FontSize',6,'FontWeight','bold');
ylabel(ax1,'\DeltaF/F (%)','FontSize',6,'FontWeight','bold');
title(ax1, sprintf('A=%.2f  |  trial %d  rank %d  err=%.4f  |  %s %s e%d', ...
    S.uAmp_cp(ia), iTrial, rank, errT, S.mn, S.td, S.en), ...
    'FontSize',6,'FontWeight','bold');
lhD = legend(ax1,'Location','best','Box','off','FontSize',5);
try; set(lhD,'ItemTokenSize',[6 6]); catch; end
end
