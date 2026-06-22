function cp_motion_amp(R, imp, SIG, sigName, fname)
% cp_motion_amp — per-amplitude motion vs |dip dev| (motion_analysis figure-3 style,
% LARGE fonts) for the contra_residual workbench.
%
% One subplot per stim amplitude: x = per-trial motion (session-z), y = |dip - amp-mean|
% (deviation of the trial's inhibition energy from the amplitude-average = predictability;
% lower = closer to average). Dots coloured by motion tertile (Low/Mid/High at z = -0.5/0.5).
% The within-amplitude correlation r in each title shows the effect holds at fixed amplitude.
%
%   R       cp_residual_core output (uses iDip / nzMask / uAmp / mn,td,en / paper_root)
%   imp     allExperiments(R.selExp).imp  (for per-trial motion imp.mot{ia})
%   SIG     per-amp cell of [nT x nImp] traces: R.act_imp (Actual) / R.prr_imp (Global) / R.res_imp (Local)
%   sigName label for titles                | fname  output png name
iD = R.iDip;  nz = find(R.nzMask(:))';
motpool = [];                                   % session-pooled motion for a common z
for ia = nz, motpool = [motpool; imp.mot{ia}(:)]; end %#ok<AGROW>
mu = mean(motpool,'omitnan');  sd = max(std(motpool,'omitnan'), eps);
terCol = [0.20 0.40 0.80; 0.55 0.25 0.75; 0.85 0.20 0.20];  tLab = {'Low motion','Mid motion','High motion'};
nA = numel(nz);  nCols = min(nA,3);  nRows = ceil(nA/nCols);

xAll = []; yAll = [];                            % shared axis limits
for ia = nz
    m = (imp.mot{ia}(:)-mu)/sd;  dp = mean(SIG{ia}(:,iD),2,'omitnan');  d = abs(dp - mean(dp,'omitnan'));
    xAll = [xAll; m];  yAll = [yAll; d]; %#ok<AGROW>
end
xAll = xAll(isfinite(xAll));  yAll = yAll(isfinite(yAll));
xLim = [min(xAll)-0.05*range(xAll), max(xAll)+0.05*range(xAll)];  yLim = [0, max(yAll)*1.05];

fig = figure('Color','w','Units','inches','Position',[1 1 nCols*3.4 nRows*3.0]);
sgtitle(sprintf('%s %s e%d — %s |dip dev| vs motion, per amplitude', R.mn, R.td, R.en, sigName), ...
    'FontWeight','bold','FontSize',14,'Interpreter','none');
for k = 1:nA
    ia = nz(k);
    m = (imp.mot{ia}(:)-mu)/sd;  dp = mean(SIG{ia}(:,iD),2,'omitnan');  d = abs(dp - mean(dp,'omitnan'));
    nU = min(numel(m), numel(d));  m = m(1:nU);  d = d(1:nU);
    tert = 1 + (m >= -0.5) + (m > 0.5);
    ax = subplot(nRows,nCols,k); hold(ax,'on');
    for q = 1:3
        mk = tert==q;
        if any(mk), scatter(ax, m(mk), d(mk), 32, terCol(q,:), 'filled', 'MarkerFaceAlpha',0.6, 'DisplayName',tLab{q}); end
    end
    gd = isfinite(m)&isfinite(d);  r = corr(m(gd), d(gd));   % Pearson, matching motion_analysis fig 3
    title(ax, sprintf('%.2f V  (n=%d, r=%.2f)', R.uAmp(ia), nU, r), 'FontSize',12,'FontWeight','bold');
    xlabel(ax,'Motion z-score','FontSize',11,'FontWeight','bold');
    ylabel(ax,'|dip dev| (\DeltaF/F %)','FontSize',11,'FontWeight','bold');
    set(ax,'Box','off','TickDir','out','FontSize',10,'LineWidth',0.8);  xlim(ax,xLim);  ylim(ax,yLim);
    if k==1, lg = legend(ax,'Location','northeast','FontSize',10); lg.ItemTokenSize = [10 10]; end
end
exportgraphics(fig, fullfile(R.paper_root,'images','figure2',fname), 'Resolution',200);
fprintf('[CP-MOTION-AMP] Exported %s (%s)\n', fname, sigName);
end
