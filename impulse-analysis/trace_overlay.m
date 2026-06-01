% impulse-analysis -- extracted from Impulse_mouseDataAnalysis_all.m
% Run from impulse-analysis/ directory.
% Requires: load_experiments.m has been run first (allExperiments, selExp, t_win).

%% Single-session trace overlay â€” session 3
close all;
imp3  = allExperiments(3).imp;
uAmp3 = allExperiments(3).uAmp;
mn3   = allExperiments(3).mn;
td3   = allExperiments(3).td;
en3   = allExperiments(3).en;

PS = paperStyle();
setPaperDefaults();
figS = paperFig(5, 4);
hold on;

% Shaded region = exact xlim of tf_fit.m paper figure (preWin_A=0.2 s, tFit_s=0.5 s)
% Update these values if tFit_s or preWin_A change in tf_fit.m.
tShade = [-0.2, 0.5];
patch([tShade(1) tShade(2) tShade(2) tShade(1)], [-5 -5 3 3], ...
    [0.8 0.8 0.8], 'FaceAlpha', 0.5, 'EdgeColor', 'none', 'HandleVisibility', 'off');

for i = 1:length(uAmp3)
    if mod(i,2)==1 && ~isempty(imp3.dfImp{i})
        plot(0, 0.75, 'ro','MarkerSize',5,'MarkerFaceColor','red','HandleVisibility','off');
        plot(t_win, mean(imp3.dfImp{i}), ...
            'Color',[1-(0.1*i),(1-0.1*i),(1-0.1*i)],'LineWidth',2, ...
            'DisplayName', sprintf('%.2f mW', uAmp3(i)/3));
    end
end
xlim([-1,1])
yl_s = ylim(gca);
text(gca, mean(tShade), yl_s(2)-0.5, 'Model Fit Window', ...
    'FontSize', 5, 'Color', [0.45 0.45 0.45], 'FontWeight', 'bold', ...
    'HorizontalAlignment', 'center', 'VerticalAlignment', 'top', 'Clipping', 'off');
lgd = legend('Box','off','Location','southeast');
paperLegend(lgd);
paperAxes(gca,'XLength',0.25,'YLength',1,'XLabel','250 ms','YLabel','1% dF/F');
text(0.1, 2, 'Stim','Color','r','FontSize',PS.fs,'FontWeight','bold', ...
    'HorizontalAlignment','right','VerticalAlignment','top','Clipping','off');
paperExport(figS, fullfile(paperRoot, 'images', 'figure2', sprintf('imp_single_%s_%s_en%d.pdf',mn3,td3,en3)));


%%