% impulse-analysis -- extracted from Impulse_mouseDataAnalysis_all.m
% Run from brain_paper/ root directory.
% Requires: load_experiments.m has been run first (allExperiments, selExp, t_win).

%% Single-session trace overlay â€” session 3
close all;
imp3  = allExperiments(3).imp;
uAmp3 = allExperiments(3).uAmp;
mn3   = allExperiments(3).mn;
td3   = allExperiments(3).td;
en3   = allExperiments(3).en;

PW_s = 5; PH_s = 4;
figS = figure('Color','w');
figS.Units = 'centimeters';  figS.PaperUnits = 'centimeters';
figS.Position = [0 0 PW_s PH_s];
figS.PaperSize = [PW_s PH_s];  figS.PaperPosition = [0 0 PW_s PH_s];
hold on;
for i = 1:length(uAmp3)
    if mod(i,2)==1 && ~isempty(imp3.dfImp{i})
        plot(0, 0.75, 'ro','MarkerSize',5,'MarkerFaceColor','red','HandleVisibility','off');
        plot(t_win, mean(imp3.dfImp{i}), ...
            'Color',[1-(0.1*i),(1-0.1*i),(1-0.1*i)],'LineWidth',2, ...
            'DisplayName', sprintf('%.2f mW', uAmp3(i)/3));
    end
end
xlim([-1,1])
lgd = legend('Box','off','FontSize',6,'FontWeight','bold','Location','southeast');
lgd.ItemTokenSize = [6 6];
shortCornerAxes_plot(gca,'XLength',0.5,'YLength',1,'XLabel','500 ms', ...
    'YLabel','1% dF/F','LineWidth',2,'LabelGap',0.05);
text(0.1, 1.5, 'Stim','Color','r','FontSize',7,'FontWeight','bold', ...
    'HorizontalAlignment','right','VerticalAlignment','top','Clipping','off');
print(figS, sprintf('paper/images/figure2/imp_single_%s_%s_en%d.pdf',mn3,td3,en3), '-dpdf','-painters');


%%