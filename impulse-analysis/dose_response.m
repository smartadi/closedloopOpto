% impulse-analysis -- extracted from Impulse_mouseDataAnalysis_all.m
% Run from brain_paper/ root directory.
% Requires: load_experiments.m has been run first (allExperiments, selExp, t_win).


%% Combined plot for all experiments
close all;

expColors = [0.2 0.4 0.8; 0.8 0.2 0.2; 0.2 0.8 0.4];

PW_c = 5; PH_c = 4;
fig = figure('Color','w'); hold on
fig.Units = 'centimeters';  fig.PaperUnits = 'centimeters';
fig.Position = [0 0 PW_c PH_c];
fig.PaperSize = [PW_c PH_c];  fig.PaperPosition = [0 0 PW_c PH_c];
h1 = yline(0,'--k');
ax_c = gca;

nExp = numel(allExperiments);
hLegend = gobjects(nExp,1);              % one legend entry per experiment
legTxt  = cell(nExp,1);

fprintf('\n--- Dose-response linear fits (mean Â± SEM) ---\n');
for expIdx = 1:nExp
    allVals = allExperiments(expIdx).allVals;
    groupLabels = allExperiments(expIdx).groupLabels;

    [ug,~,idx] = unique(groupLabels, 'stable');
    meanVals = accumarray(idx(:), allVals(:), [], @(v) mean(v,'omitnan'));
    semVals  = accumarray(idx(:), allVals(:), [], @(v) std(v,'omitnan')/sqrt(sum(~isnan(v))));

    xpos_raw = str2double(cellstr(ug))';
    nzMask   = xpos_raw > 0;          % exclude 0-amp gap-fill markers (not real laser trials)
    meanVals = meanVals(nzMask);
    semVals  = semVals(nzMask);
    xpos     = xpos_raw(nzMask) + (expIdx - 2) * 0.005;
    capWidth = 0.003;

    for j = 1:numel(xpos)
        plot([xpos(j) xpos(j)], [meanVals(j)-semVals(j), meanVals(j)+semVals(j)], ...
            '-', 'LineWidth', 1, 'Color', expColors(expIdx,:));
        plot([xpos(j)-capWidth xpos(j)+capWidth], [meanVals(j)-semVals(j), meanVals(j)-semVals(j)], ...
            '-', 'LineWidth', 1, 'Color', expColors(expIdx,:));
        plot([xpos(j)-capWidth xpos(j)+capWidth], [meanVals(j)+semVals(j), meanVals(j)+semVals(j)], ...
            '-', 'LineWidth', 1, 'Color', expColors(expIdx,:));
        plot(xpos(j), meanVals(j), 'o', 'MarkerSize', 1.5, ...
            'MarkerFaceColor', expColors(expIdx,:), ...
            'MarkerEdgeColor', expColors(expIdx,:), ...
            'LineWidth', 2);
    end

    % Fit line through means for this experiment
    p  = polyfit(xpos, meanVals, 1);
    xf = linspace(min(xpos)-0.02, max(xpos)+0.02, 100);

    hLegend(expIdx) = plot(xf, polyval(p,xf), '-', 'LineWidth', 2.0, ...
        'Color', expColors(expIdx,:));

    legTxt{expIdx} = sprintf('Session %d',expIdx);

    % RÂ² for this linear fit
    yfit   = polyval(p, xpos);
    SS_res = sum((meanVals(:) - yfit(:)).^2);
    SS_tot = sum((meanVals(:) - mean(meanVals)).^2);
    R2_e   = 1 - SS_res / max(SS_tot, eps);
    fprintf('  Session %d: slope=%.4f dF%%/V,  RÂ²=%.3f\n', expIdx, p(1), R2_e);
    text(ax_c, 0.5, 0.05 + 0.12*(expIdx-1), ...
        sprintf('S%d: m=%.3f, RÂ²=%.2f', expIdx, p(1), R2_e), ...
        'Units','normalized', 'FontSize',5, 'Color',expColors(expIdx,:), ...
        'FontWeight','bold', 'HorizontalAlignment','right', 'VerticalAlignment','bottom');
end

% Beautify
ax = gca;
ax.LineWidth = 1.5;
ax.FontName = 'Arial';
ax.FontSize = 12;
ax.FontWeight = 'bold';
ax.TickDir = 'out';
ax.Box = 'off';
xlabel('Amplitude(V)', 'FontWeight','bold');
ylabel('dF/F %', 'FontWeight','bold');
ylim([-5 3])
uistack(h1, 'bottom')
xticks([])

try
    % shortCornerAxes_plot(gca,'Frac',0.15,'XLabel','mW','YLabel',' ', ...
    %     'LineWidth',3,'LabelGap',0.05);
    shortCornerAxes_plot(gca,'XLength',2,'YLength',0.01,'XLabel','0.5 mW', ...
    'YLabel',' ','LineWidth',2,'LabelGap',0.05);
catch
    xlabel('Input(V)', 'FontWeight','bold');
    ylabel('dF/F %', 'FontWeight','bold');
end

% Legend (clean neuro style)
lgd = legend(ax, hLegend, legTxt, 'Box','off','Color','none','FontSize',6);
lgd.ItemTokenSize = [10 6];
lgd.AutoUpdate = 'off';
text(ax, -0.12, 0.5, 'Inhibition Energy', ...
    'Units','normalized', 'Rotation',90, ...
    'HorizontalAlignment','center', 'VerticalAlignment','middle', ...
    'FontSize',7, 'FontWeight','bold', 'Color','k', 'Clipping','off');
print(fig, 'paper/images/figure2/imp_response.pdf', '-dpdf', '-painters');

%% Combined plot â€” median Â± 95th-percentile bounds
figM = figure('Color','w'); hold on
figM.Units = 'centimeters';  figM.PaperUnits = 'centimeters';
figM.Position = [0 0 PW_c PH_c];
figM.PaperSize = [PW_c PH_c];  figM.PaperPosition = [0 0 PW_c PH_c];
h1m = yline(0,'--k');
ax_mc = gca;

hLegendM = gobjects(nExp,1);
legTxtM   = cell(nExp,1);

fprintf('\n--- Dose-response linear fits (median Â± 95th-pctile bounds) ---\n');
for expIdx = 1:nExp
    allVals_e     = allExperiments(expIdx).allVals;
    groupLabels_e = allExperiments(expIdx).groupLabels;

    [ug_m,~,idx_m] = unique(groupLabels_e, 'stable');
    medVals = accumarray(idx_m(:), allVals_e(:), [], @(v) median(v,'omitnan'));
    p2_5    = accumarray(idx_m(:), allVals_e(:), [], @(v) prctile(v, 2.5));
    p97_5   = accumarray(idx_m(:), allVals_e(:), [], @(v) prctile(v, 97.5));

    xpos_raw_m = str2double(cellstr(ug_m))';
    nzMask_m   = xpos_raw_m > 0;          % exclude 0-amp gap-fill markers
    medVals    = medVals(nzMask_m);
    p2_5       = p2_5(nzMask_m);
    p97_5      = p97_5(nzMask_m);
    xpos_m     = xpos_raw_m(nzMask_m) + (expIdx - 2) * 0.005;
    ug_m       = ug_m(nzMask_m);
    capWidth_m = 0.003;

    for j = 1:numel(ug_m)
        plot([xpos_m(j) xpos_m(j)], [p2_5(j), p97_5(j)], ...
            '-', 'LineWidth', 1, 'Color', expColors(expIdx,:));
        plot([xpos_m(j)-capWidth_m xpos_m(j)+capWidth_m], [p2_5(j) p2_5(j)], ...
            '-', 'LineWidth', 1, 'Color', expColors(expIdx,:));
        plot([xpos_m(j)-capWidth_m xpos_m(j)+capWidth_m], [p97_5(j) p97_5(j)], ...
            '-', 'LineWidth', 1, 'Color', expColors(expIdx,:));
        plot(xpos_m(j), medVals(j), 'o', 'MarkerSize', 1, ...
            'MarkerFaceColor', expColors(expIdx,:), ...
            'MarkerEdgeColor', expColors(expIdx,:), 'LineWidth', 2);
    end

    p_m  = polyfit(xpos_m, medVals, 1);
    xf_m = linspace(min(xpos_m)-0.02, max(xpos_m)+0.02, 100);
    hLegendM(expIdx) = plot(xf_m, polyval(p_m,xf_m), '-', 'LineWidth', 1.5, ...
        'Color', expColors(expIdx,:));
    legTxtM{expIdx} = sprintf('Session %d', expIdx);

    % RÂ² for this linear fit
    yfit_m   = polyval(p_m, xpos_m);
    SS_res_m = sum((medVals(:) - yfit_m(:)).^2);
    SS_tot_m = sum((medVals(:) - mean(medVals)).^2);
    R2_m     = 1 - SS_res_m / max(SS_tot_m, eps);
    fprintf('  Session %d: slope=%.4f dF%%/V,  RÂ²=%.3f\n', expIdx, p_m(1), R2_m);
    text(ax_mc, 0.5, 0.05 + 0.12*(expIdx-1), ...
        sprintf('S%d: m=%.3f, RÂ²=%.2f', expIdx, p_m(1), R2_m), ...
        'Units','normalized', 'FontSize',5, 'Color',expColors(expIdx,:), ...
        'FontWeight','bold', 'HorizontalAlignment','right', 'VerticalAlignment','bottom');
end

ax_m = gca;
ax_m.LineWidth = 1.5;  ax_m.FontName = 'Arial';  ax_m.FontSize = 7;
ax_m.FontWeight = 'bold';  ax_m.TickDir = 'out';  ax_m.Box = 'off';
ylim([-5 3]);  xticks([]);
uistack(h1m, 'bottom');
try
    shortCornerAxes_plot(ax_m,'XLength',1,'YLength',0.01,'XLabel','0.3 mW', ...
        'YLabel',' ','LineWidth',2,'LabelGap',0.05);
catch
    xlabel('Input(V)','FontWeight','bold');  ylabel('dF/F %','FontWeight','bold');
end
lgd_m = legend(ax_m, hLegendM, legTxtM, 'Box','off','Color','none','FontSize',6);
lgd_m.ItemTokenSize = [10 6];
lgd_m.AutoUpdate = 'off';
text(ax_m, -0.12, 0.5, 'Inhibition Energy', ...
    'Units','normalized', 'Rotation',90, ...
    'HorizontalAlignment','center', 'VerticalAlignment','middle', ...
    'FontSize',7, 'FontWeight','bold', 'Color','k', 'Clipping','off');
exportgraphics(figM, 'paper/imp_response_median.png', 'Resolution',300);
