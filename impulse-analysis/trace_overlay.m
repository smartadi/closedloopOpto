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

% Model-fit window drawn LATER (after ylim is known) so it can span the full
% height; tShade = exact xlim of tf_fit.m paper figure (preWin_A=0.2 s, tFit_s=0.5 s).
% Update these values if tFit_s or preWin_A change in tf_fit.m.
tShade = [-0.2, 0.5];

% Pass 1: +/-1 SD across trials, shown ONLY for the lowest and highest drawn
% amplitude (subset -> keeps all 5 mean traces legible). Faint fill only, no
% outline. Drawn first so the mean traces sit on top.
tw = t_win(:).';
drawIdx  = find(arrayfun(@(i) mod(i,2)==1 && ~isempty(imp3.dfImp{i}), 1:length(uAmp3)));
shadeIdx = unique([drawIdx(1) drawIdx(end)]);   % lowest + highest amplitude
sd_alpha = 0.08;                                 % faint fill
for i = shadeIdx
    mu_i = mean(imp3.dfImp{i}, 1);              % trials x time -> 1 x time
    sd_i = std(imp3.dfImp{i}, 0, 1);           % +/-1 SD across trials
    g_i = min(1-0.1*i, 0.78);                   % cap lightest (0 mW) so its swatch shows on white
    col_i = [g_i g_i g_i];
    fill([tw fliplr(tw)], [mu_i+sd_i fliplr(mu_i-sd_i)], col_i, ...
        'FaceAlpha', sd_alpha, 'EdgeColor', 'none', 'HandleVisibility', 'off');
end

% Pass 2: trial-mean traces
for i = 1:length(uAmp3)
    if mod(i,2)==1 && ~isempty(imp3.dfImp{i})
        g_i = min(1-0.1*i, 0.78);               % cap lightest (0 mW) so its swatch shows on white
        plot(t_win, mean(imp3.dfImp{i}, 1), ...
            'Color',[g_i g_i g_i],'LineWidth',2, ...
            'DisplayName', sprintf('%.2f mW', uAmp3(i)/3));
    end
end
xlim([-1,1]);
lgd = legend('Box','off','Location','southeast');
paperLegend(lgd);
paperAxes(gca,'XLength',0.25,'YLength',1,'XLabel','250 ms','YLabel','1% dF/F');

% Freeze the data-driven y-range, then draw the model-fit window spanning it
% full height and send it to the back (behind traces and SD fills).
yl_s = ylim(gca);  ylim(yl_s);
span = yl_s(2) - yl_s(1);
hModelWin = patch([tShade(1) tShade(2) tShade(2) tShade(1)], ...
    [yl_s(1) yl_s(1) yl_s(2) yl_s(2)], [0.8 0.8 0.8], ...
    'FaceAlpha', 0.5, 'EdgeColor', 'none', 'HandleVisibility', 'off');
uistack(hModelWin, 'bottom');

% Stimulation onset marker + labels, moved up near the top
stim_y = yl_s(1) + 0.82*span;
plot(0, stim_y, 'ro','MarkerSize',5,'MarkerFaceColor','red','HandleVisibility','off');
text(0.05, stim_y + 0.03*span, 'Stim', 'Color','r','FontSize',PS.fs,'FontWeight','bold', ...
    'HorizontalAlignment','left','VerticalAlignment','bottom','Clipping','off');
text(mean(tShade), yl_s(2), 'Model Fit Window', ...
    'FontSize', 3.5, 'Color', [0.45 0.45 0.45], 'FontWeight', 'bold', ...
    'HorizontalAlignment', 'center', 'VerticalAlignment', 'top', 'Clipping', 'off');

paperExport(figS, fullfile(paperRoot, 'images', 'figure2', sprintf('imp_single_%s_%s_en%d.pdf',mn3,td3,en3)));


%%