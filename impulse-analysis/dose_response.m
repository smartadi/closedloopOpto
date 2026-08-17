% impulse-analysis -- extracted from Impulse_mouseDataAnalysis_all.m
% Run from brain_paper/ root directory (or impulse-analysis/ -- path auto-detected).
% Requires: load_experiments.m has been run first (allExperiments, selExp, t_win).


%% Combined plot for all experiments
close all;

PW_c = 5; PH_c = 4;
PS = paperStyle();
% Session colour indexed by SESSION NUMBER (see paperStyle.m): PS.sessGrad(n) resampled the
% ramp to however many sessions this run had, so session 1 changed shade between a 3-session
% and a 4-session run and 2B stopped matching 2C-i and the TF panels.
expColors = PS.sess;
setPaperDefaults();
fig = paperFig(PW_c, PH_c); hold on
h1 = yline(0,'--k');
ax_c = gca;

nExp = numel(allExperiments);
hLegend = gobjects(nExp,1);              % one legend entry per experiment
legTxt  = cell(nExp,1);

fprintf('\n--- Dose-response linear fits (mean +/- SEM) ---\n');
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

    c = expColors(expIdx,:);
    for j = 1:numel(xpos)
        plot([xpos(j) xpos(j)], [meanVals(j)-semVals(j), meanVals(j)+semVals(j)], ...
            '-', 'LineWidth', 1, 'Color', c);
        plot([xpos(j)-capWidth xpos(j)+capWidth], [meanVals(j)-semVals(j), meanVals(j)-semVals(j)], ...
            '-', 'LineWidth', 1, 'Color', c);
        plot([xpos(j)-capWidth xpos(j)+capWidth], [meanVals(j)+semVals(j), meanVals(j)+semVals(j)], ...
            '-', 'LineWidth', 1, 'Color', c);
        plot(xpos(j), meanVals(j), 'o', 'MarkerSize', 3, ...
            'MarkerFaceColor', c, 'MarkerEdgeColor', c, 'LineWidth', 0.5);
    end

    % Fit line through means for this experiment (session = gradient colour)
    p  = polyfit(xpos, meanVals, 1);
    xf = linspace(min(xpos)-0.02, max(xpos)+0.02, 100);
    hLegend(expIdx) = plot(xf, polyval(p,xf), '-', 'LineWidth', 1.5, 'Color', c);

    legTxt{expIdx} = sprintf('Session %d',expIdx);

    % R2 for this linear fit
    yfit   = polyval(p, xpos);
    SS_res = sum((meanVals(:) - yfit(:)).^2);
    SS_tot = sum((meanVals(:) - mean(meanVals)).^2);
    R2_e   = 1 - SS_res / max(SS_tot, eps);
    fprintf('  Session %d: slope=%.4f dF%%/V,  R2=%.3f\n', expIdx, p(1), R2_e);
    text(ax_c, 0.5, 0.05 + 0.12*(expIdx-1), ...
        sprintf('S%d: m=%.3f, R2=%.2f', expIdx, p(1), R2_e), ...
        'Units','normalized', 'FontSize',PS.fs, 'Color',c, ...
        'FontWeight','bold', 'HorizontalAlignment','right', 'VerticalAlignment','bottom');
end

% Beautify
ax = gca;
ax.LineWidth = 1.5;
xlabel('Amplitude(V)', 'FontWeight','bold');
ylabel('dF/F %', 'FontWeight','bold');
ylim([-5 3])
uistack(h1, 'bottom')
xticks([])

try
    paperAxes(gca,'XLength',2,'YLength',0.01,'XLabel','0.5 mW','YLabel',' ');
catch
    xlabel('Input(V)', 'FontWeight','bold');
    ylabel('dF/F %', 'FontWeight','bold');
end

% Legend (clean neuro style)
lgd = legend(ax, hLegend, legTxt, 'Color','none');
paperLegend(lgd);
lgd.AutoUpdate = 'off';
text(ax, -0.12, 0.5, 'Inhibition Energy', ...
    'Units','normalized', 'Rotation',90, ...
    'HorizontalAlignment','center', 'VerticalAlignment','middle', ...
    'FontSize',PS.fs, 'FontWeight',PS.fw, 'Color','k', 'Clipping','off');
paperExport(fig, fullfile(paperRoot, 'images', 'figure2', sprintf('imp_response%s.pdf', PS.cbtag)));

%% Combined plot - median +/- IQR (supplementary)
figM = paperFig(PW_c, PH_c); hold on
h1m = yline(0,'--k');
ax_mc = gca;

hLegendM = gobjects(nExp,1);
legTxtM   = cell(nExp,1);

fprintf('\n--- Impulse-response linear fits (median +/- IQR) ---\n');
for expIdx = 1:nExp
    allVals_e     = allExperiments(expIdx).allVals;
    groupLabels_e = allExperiments(expIdx).groupLabels;

    [ug_m,~,idx_m] = unique(groupLabels_e, 'stable');
    medVals = accumarray(idx_m(:), allVals_e(:), [], @(v) median(v,'omitnan'));
    p25     = accumarray(idx_m(:), allVals_e(:), [], @(v) prctile(v, 25));   % Q1
    p75     = accumarray(idx_m(:), allVals_e(:), [], @(v) prctile(v, 75));   % Q3

    xpos_raw_m = str2double(cellstr(ug_m))';
    nzMask_m   = xpos_raw_m > 0;          % exclude 0-amp gap-fill markers
    medVals    = medVals(nzMask_m);
    p25        = p25(nzMask_m);
    p75        = p75(nzMask_m);
    xpos_m     = xpos_raw_m(nzMask_m) + (expIdx - 2) * 0.005;
    ug_m       = ug_m(nzMask_m);
    capWidth_m = 0.003;

    c_m = expColors(expIdx,:);
    for j = 1:numel(ug_m)
        plot([xpos_m(j) xpos_m(j)], [p25(j), p75(j)], ...
            '-', 'LineWidth', 1, 'Color', c_m);
        plot([xpos_m(j)-capWidth_m xpos_m(j)+capWidth_m], [p25(j) p25(j)], ...
            '-', 'LineWidth', 1, 'Color', c_m);
        plot([xpos_m(j)-capWidth_m xpos_m(j)+capWidth_m], [p75(j) p75(j)], ...
            '-', 'LineWidth', 1, 'Color', c_m);
        plot(xpos_m(j), medVals(j), 'o', 'MarkerSize', 3, ...
            'MarkerFaceColor', c_m, 'MarkerEdgeColor', c_m, 'LineWidth', 0.5);
    end

    p_m  = polyfit(xpos_m, medVals, 1);
    xf_m = linspace(min(xpos_m)-0.02, max(xpos_m)+0.02, 100);
    hLegendM(expIdx) = plot(xf_m, polyval(p_m,xf_m), '-', 'LineWidth', 1.5, 'Color', c_m);
    legTxtM{expIdx} = sprintf('Session %d', expIdx);

    % R2 for this linear fit
    yfit_m   = polyval(p_m, xpos_m);
    SS_res_m = sum((medVals(:) - yfit_m(:)).^2);
    SS_tot_m = sum((medVals(:) - mean(medVals)).^2);
    R2_m     = 1 - SS_res_m / max(SS_tot_m, eps);
    fprintf('  Session %d: slope=%.4f dF%%/V,  R2=%.3f\n', expIdx, p_m(1), R2_m);
    text(ax_mc, 0.5, 0.05 + 0.12*(expIdx-1), ...
        sprintf('S%d: m=%.3f, R2=%.2f', expIdx, p_m(1), R2_m), ...
        'Units','normalized', 'FontSize',PS.fs, 'Color',c_m, ...
        'FontWeight','bold', 'HorizontalAlignment','right', 'VerticalAlignment','bottom');
end

ax_m = gca;
ax_m.LineWidth = 1.5;
ylim auto;  xticks([]);
title(ax_m, 'Dose-response: median +/- IQR per amplitude (all sessions)', ...
    'FontSize', 6, 'FontWeight', 'bold', 'Color', 'k');
uistack(h1m, 'bottom');
try
    paperAxes(ax_m,'XLength',1,'YLength',0.01,'XLabel','0.3 mW','YLabel',' ');
catch
    xlabel('Input(V)','FontWeight','bold');  ylabel('dF/F %','FontWeight','bold');
end
lgd_m = legend(ax_m, hLegendM, legTxtM, 'Color','none');
paperLegend(lgd_m);
lgd_m.AutoUpdate = 'off';
text(ax_m, -0.12, 0.5, 'Inhibition Energy', ...
    'Units','normalized', 'Rotation',90, ...
    'HorizontalAlignment','center', 'VerticalAlignment','middle', ...
    'FontSize',PS.fs, 'FontWeight',PS.fw, 'Color','k', 'Clipping','off');
paperExport(figM, fullfile(paperRoot, 'images', 'supplementary', 'imp_response_median_IQR.pdf'));
