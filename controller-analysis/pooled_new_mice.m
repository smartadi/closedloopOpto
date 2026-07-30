% controller-analysis/pooled_new_mice.m
% Memory-lean cross-session OL-vs-CL RMSE pool including the two new mice
% (AL_0048/AL_0051, 2026-07-29). Loads ONLY the small `data` struct from each
% controller cache (never the ~3 GB `d`/SVD), so all 15 sessions fit in memory.
% All caches verified on the RMSE scale (norm/sqrt(N), 2026-07-16 convention).
% Output: paper/images/figure3/pooled_ol_cl_rmse_15sess.pdf (+ PNG). New panel,
% does NOT overwrite the existing 3H violin.

PS = paperStyle(); setPaperDefaults();
dataDir = fullfile(fileparts(mfilename('fullpath')),'..','data');
D = dir(fullfile(dataDir,'*ctrl*.mat'));

nS = numel(D); medOL=nan(nS,1); medCL=nan(nS,1); lbl=cell(nS,1); isNew=false(nS,1);
for k=1:nS
    S = load(fullfile(dataDir,D(k).name),'data');
    medOL(k) = median(S.data.er_ncDfk(:));
    medCL(k) = median(S.data.er_wcDfk(:));
    lbl{k}   = erase(D(k).name,{'ctrl','.mat'});
    isNew(k) = contains(D(k).name,'0729') && (contains(D(k).name,'AL_0048') || contains(D(k).name,'AL_0051'));
    clear S
end
pWil = signrank(medOL, medCL);
fprintf('Pooled %d sessions: OL med(med)=%.2f  CL med(med)=%.2f  signrank p=%.4g\n', ...
    nS, median(medOL), median(medCL), pWil);
fprintf('CL < OL in %d/%d sessions\n', sum(medCL<medOL), nS);
for k=find(isNew)'; fprintf('  NEW %-18s OL=%.2f CL=%.2f\n', lbl{k}, medOL(k), medCL(k)); end

fig = paperFig(6,5);
ax = axes(fig,'Position',[0.16 0.12 0.80 0.82]); hold(ax,'on');
for k=1:nS
    lw = 0.5; cl = [0.6 0.6 0.6 0.6];
    if isNew(k); lw = 1.5; cl = [0 0 0 0.9]; end
    plot(ax,[1 2],[medOL(k) medCL(k)],'-','Color',cl,'LineWidth',lw,'HandleVisibility','off');
end
hOL=plot(ax,ones(nS,1),medOL,'o','MarkerFaceColor',PS.col_ol,'MarkerEdgeColor','none','MarkerSize',4);
hCL=plot(ax,2*ones(nS,1),medCL,'o','MarkerFaceColor',PS.col_cl,'MarkerEdgeColor','none','MarkerSize',4);
% emphasise the two new mice
plot(ax,ones(sum(isNew),1),medOL(isNew),'o','MarkerFaceColor',PS.col_ol,'MarkerEdgeColor','k','LineWidth',0.75,'MarkerSize',6);
plot(ax,2*ones(sum(isNew),1),medCL(isNew),'o','MarkerFaceColor',PS.col_cl,'MarkerEdgeColor','k','LineWidth',0.75,'MarkerSize',6);
% group medians
plot(ax,[0.8 1.2],median(medOL)*[1 1],'Color',PS.col_ol,'LineWidth',2.5,'HandleVisibility','off');
plot(ax,[1.8 2.2],median(medCL)*[1 1],'Color',PS.col_cl,'LineWidth',2.5,'HandleVisibility','off');
xlim(ax,[0.6 2.4]); ylim(ax,[0 max([medOL;medCL])*1.1]);
set(ax,'XTick',[1 2],'XTickLabel',{'OL','CL'},'Box','off','TickDir','out','FontSize',PS.fs,'FontWeight',PS.fw);
ylabel(ax,'Session median trial RMSE (% \DeltaF/F)','FontSize',PS.fs,'FontWeight',PS.fw);
title(ax,sprintf('%d sessions (2 new, black)   p=%.3g',nS,pWil),'FontSize',PS.fs,'FontWeight',PS.fw);
legend([hOL hCL],{'OL','CL'},'Box','off','Location','northeast');

outDir = fullfile(fileparts(mfilename('fullpath')),'..','paper','images','figure3');
if ~exist(outDir,'dir'); mkdir(outDir); end
paperExport(fig, fullfile(outDir,'pooled_ol_cl_rmse_15sess.pdf'));
paperExport(fig, fullfile(outDir,'pooled_ol_cl_rmse_15sess.png'));
fprintf('Saved pooled_ol_cl_rmse_15sess\n');
