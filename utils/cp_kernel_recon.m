function cp_kernel_recon(P)
% cp_kernel_recon — sparse "kernel" reconstruction of the ipsi primary pixel.
% ------------------------------------------------------------------------------
% The [CP-HEMI] predictor maps contra activity -> ipsi through K canonical
% components ("kernels"), each a (contra spatial map x temporal latent) pair.
% This asks: how few of the MOST IMPORTANT kernels reconstruct the ipsi trace?
%
%   readout:  yhat(t) = sum_n  scoresTe(:,n) * aKern(n)   (/mI*100 -> %dF/F)
%
% Importance of component n = its STANDALONE held-out primary-pixel R^2. We rank
% components by that, accumulate them in importance order, and report the number M
% needed for 90/95/99% of the peak (rank-kbest) R^2. Two reconstruction curves are
% shown: canonical (prefix) order = kernR2, and importance-sorted order.
%
% INPUT P (struct): scoresTe[nTe x K], aKern[K x1], mI_kern, yact_te[nTe x1] (%dF/F),
%   segL, nSeg, kernR2[K x1] (canonical-prefix cumulative R^2), kbest, b[K x K],
%   sdtr[K x1], U_svd_raw_K[nContra x K], idx_c, nY, nX, mimg, px_prim, py_prim, Fs,
%   paper_root.
K = size(P.scoresTe,2);
pred = @(cols) (P.scoresTe(:,cols) * P.aKern(cols)) / P.mI_kern * 100;   % [nTe x1] %dF/F
r2   = @(yh) sseExplainedCal(P.yact_te(:).', yh(:).');
peakR2 = P.kernR2(P.kbest);

% ---- per-component standalone R^2 -> importance ranking ----------------------
r2solo = nan(K,1);
for n = 1:K, r2solo(n) = r2(pred(n)); end
[~, ord] = sort(r2solo, 'descend');        % importance order (most predictive kernel first)

% ---- cumulative reconstruction in importance order --------------------------
cumImp = nan(K,1);
for m = 1:K, cumImp(m) = r2(pred(ord(1:m))); end

frac = @(f) find(cumImp >= f*peakR2, 1, 'first');
M90 = frac(0.90);  M95 = frac(0.95);  M99 = frac(0.99);
if isempty(M90), M90 = K; end;  if isempty(M95), M95 = K; end;  if isempty(M99), M99 = K; end
% canonical-prefix equivalents (from kernR2 directly)
fracP = @(f) find(P.kernR2 >= f*peakR2, 1, 'first');
P90 = fracP(0.90);  if isempty(P90), P90 = K; end

fprintf('\n[CP-KRECON] peak primary-pixel R^2=%.3f @rank %d (K=%d components)\n', peakR2, P.kbest, K);
fprintf('  importance-sorted kernels for 90/95/99%% of peak: M=%d / %d / %d\n', M90, M95, M99);
fprintf('  (canonical-prefix order needs %d for 90%%; top kernel alone R^2=%.3f)\n', P90, max(r2solo));

% ---- FIGURE A: reconstruction curve + importance bars + example segments -----
figA = paperFig(22, 12);
axc = subplot(2,3,1); hold(axc,'on');                       % cumulative R^2 vs M
plot(axc, 1:K, P.kernR2, '-o','Color',[0.3 0.55 0.85],'MarkerSize',2,'DisplayName','canonical order');
plot(axc, 1:K, cumImp,   '-s','Color',[0.85 0.3 0.1],'MarkerSize',2,'DisplayName','importance order');
yline(axc, peakR2, 'k:', 'HandleVisibility','off');
plot(axc, M90, cumImp(M90), 'kv','MarkerFaceColor','k','MarkerSize',5,'HandleVisibility','off');
text(axc, M90, cumImp(M90)-0.06, sprintf('M_{90}=%d',M90),'FontSize',5,'FontWeight','bold');
xline(axc, P.kbest, ':','Color',[0.5 0.5 0.5],'HandleVisibility','off');
xlabel(axc,'# kernels (M)','FontSize',6,'FontWeight','bold'); ylabel(axc,'primary-pixel R^2','FontSize',6,'FontWeight','bold');
set(axc,'Box','off','TickDir','out','FontSize',6,'FontWeight','bold'); xlim(axc,[1 min(K,40)]);
lg = legend(axc,'Location','southeast','FontSize',5); lg.ItemTokenSize=[8 8];
title(axc,'Reconstruction vs # kernels','FontSize',6,'FontWeight','bold');

axb = subplot(2,3,2); hold(axb,'on');                       % per-component solo R^2 (importance order)
nBar = min(15,K);
bar(axb, 1:nBar, r2solo(ord(1:nBar)), 0.7, 'FaceColor',[0.85 0.3 0.1],'EdgeColor','none');
xlabel(axb,'kernel (importance rank)','FontSize',6,'FontWeight','bold'); ylabel(axb,'standalone R^2','FontSize',6,'FontWeight','bold');
set(axb,'Box','off','TickDir','out','FontSize',6,'FontWeight','bold');
title(axb,sprintf('per-kernel importance (top %d)',nBar),'FontSize',6,'FontWeight','bold');

% example held-out segments: actual vs recon at M=1, M90, kbest
segpick = unique(round(linspace(1, P.nSeg, min(4,P.nSeg))));
yhat1 = pred(ord(1));  yhat90 = pred(ord(1:M90));  yhatK = pred(1:P.kbest);
tseg = (0:P.segL-1)/P.Fs;
for kk = 1:numel(segpick)
    ax = subplot(2,3,2+kk); hold(ax,'on');
    s = segpick(kk); idx = (s-1)*P.segL + (1:P.segL);
    plot(ax, tseg, P.yact_te(idx), 'Color',[0.1 0.1 0.1],'LineWidth',1.2,'DisplayName','actual');
    plot(ax, tseg, yhat1(idx),  'Color',[0.7 0.7 0.2],'LineWidth',0.8,'DisplayName','M=1');
    plot(ax, tseg, yhat90(idx), 'Color',[0.85 0.4 0.1],'LineWidth',1.0,'DisplayName',sprintf('M=%d',M90));
    plot(ax, tseg, yhatK(idx),  'Color',[0.1 0.35 0.9],'LineWidth',1.2,'DisplayName',sprintf('M=%d (kbest)',P.kbest));
    set(ax,'Box','off','TickDir','out','FontSize',6,'FontWeight','bold');
    title(ax, sprintf('held-out seg %d', s),'FontSize',6,'FontWeight','bold');
    if kk>numel(segpick)-2, xlabel(ax,'time (s)','FontSize',6,'FontWeight','bold'); end
    if mod(kk,3)==1 || kk==1, ylabel(ax,'\DeltaF/F (%)','FontSize',6,'FontWeight','bold'); end
    if kk==1, lg=legend(ax,'Location','best','FontSize',4.5); lg.ItemTokenSize=[6 6]; end
end
sgtitle(figA, sprintf('CP-KRECON  sparse kernel reconstruction of ipsi primary pixel  (M_{90}=%d of %d kernels -> 90%% of R^2=%.3f)', ...
    M90, K, peakR2), 'FontSize',7,'FontWeight','bold','Interpreter','tex');
paperExport(figA, fullfile(P.paper_root,'cp_krecon_curve.png'));

% ---- FIGURE B: the top individual kernel spatial maps ------------------------
nK = min(6, K);                        % always show a top-6 gallery (M90 may be 1)
allw = zeros(numel(P.idx_c), nK);
for j = 1:nK
    n = ord(j);
    wraw = (P.b(:,n) * P.aKern(n)) ./ P.sdtr;              % this component's weight on RAW contra modes
    allw(:,j) = P.U_svd_raw_K * wraw;                      % [nContra x 1] signed pixel kernel
end
klim = prctile(abs(allw(:)), 99);  if klim < eps, klim = 1; end
nC = 256; nH = ceil(nC/2);
cmapK = [ linspace(0.23,1,nH)', linspace(0.30,1,nH)', linspace(0.75,1,nH)'; ...
          linspace(1,0.80,nC-nH)', linspace(1,0.10,nC-nH)', linspace(1,0.10,nC-nH)' ];
figB = paperFig(22, 8);  nCol = min(nK,3);  nRow = ceil(nK/nCol);
for j = 1:nK
    km = nan(P.nY, P.nX);  km(P.idx_c) = allw(:,j);
    rgb = cp_weight_composite(P.mimg', km', cmapK, [-klim klim]);
    ax = subplot(nRow, nCol, j);
    image(ax, rgb); axis(ax,'image','off'); hold(ax,'on');
    plot(ax, P.px_prim, P.py_prim, 'k+','MarkerSize',7,'LineWidth',1.2);   % transposed: plot(row,col)
    title(ax, sprintf('kernel #%d (rank %d, R^2_{solo}=%.3f)', j, ord(j), r2solo(ord(j))), 'FontSize',6,'FontWeight','bold');
end
sgtitle(figB, sprintf('CP-KRECON  top-%d importance-ranked contra kernels (signed predictive weight; transposed view)', nK), ...
    'FontSize',7,'FontWeight','bold','Interpreter','tex');
paperExport(figB, fullfile(P.paper_root,'cp_krecon_kernels.png'));
fprintf('[CP-KRECON] exported cp_krecon_curve.png + cp_krecon_kernels.png\n');
end
