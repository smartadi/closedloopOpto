% impulse-analysis -- extracted from Impulse_mouseDataAnalysis_all.m
% Run from brain_paper/ root directory (or impulse-analysis/ -- path auto-detected).
% Requires: load_experiments.m has been run first (allExperiments, selExp, t_win).


%% Combined plot for all experiments
close all;

PS = paperStyle();
PW_c = PS.f2w; PH_c = PS.f2h;      % 2B -- Fig-2 grid (see paperStyle f2w/f2h)
% Grant overrides (same opt-in style as DR_LABEL / DR_OUTDIR below). The R01
% prints this panel at 0.46 x 0.41 x 0.62 x 7.5in = 2.23 cm, so the paper's
% 4.0 cm canvas is shown at 0.52x and its 6pt type lands on the page at ~3pt.
% DR_SIZE sets the canvas to the printed size and DR_FS sets the type in FINAL
% points, so the LaTeX scale factor is 1.0 and DR_FS is what the reader sees.
if exist('DR_SIZE','var') && ~isempty(DR_SIZE), PW_c = DR_SIZE(1); PH_c = DR_SIZE(2); end
if exist('DR_FS','var')   && ~isempty(DR_FS),   PS.fs = DR_FS;   end
% Session colour indexed by SESSION NUMBER (see paperStyle.m): PS.sessGrad(n) resampled the
% ramp to however many sessions this run had, so session 1 changed shade between a 3-session
% and a 4-session run and 2B stopped matching 2C-i and the TF panels.
expColors = PS.sess;
setPaperDefaults();
fig = paperFig(PW_c, PH_c); hold on
h1 = yline(0,'--k');
ax_c = gca;

nExp = numel(allExperiments);
% DR_LABEL controls how verbose the direct labels are: 'slope' = "s1  -0.34",
% 'id' = "s1" only, with the slopes left to the caption, 'none' = no labels at all.
% 'none' added 2026-08-19 for the talk deck (user: "i want the inhibition energy plot to not
% have legends") -- on a slide the per-session slopes are read out loud, not squinted at.
% DEFAULT = 'mouse' (per-ANIMAL labels) since 2026-08-24: the paper panel now adopts the
% NeuroAI-talk treatment (user: "update the main panel like we did for the neuroai conference").
if ~exist('DR_LABEL','var') || isempty(DR_LABEL), DR_LABEL = 'mouse'; end
if ~exist('DR_OUTDIR','var'), DR_OUTDIR = ''; end   % non-empty = export here, not figure2/
% DR_YAXIS = true -> draw a REAL y axis with ticks and units instead of the corner-axes look
% (user, 2026-08-19: "put axis on y and put units"). DEFAULT = true since 2026-08-24 so the
% committed paper panel 2B carries the real y axis, matching the talk version.
if ~exist('DR_YAXIS','var') || isempty(DR_YAXIS), DR_YAXIS = true; end

% ---- mouse labels, for DR_LABEL='mouse' -----------------------------------------------------
% NOTE sessions are NOT mice: the impulse set is AL_0041 e1, AL_0041 e2, AL_0033 e1, AL_0048 e1,
% so a bare "Mouse 1..4" would claim four animals where there are three. Number the UNIQUE mouse
% names and suffix a/b when one animal contributes more than one session.
mnAll    = arrayfun(@(e) allExperiments(e).mn, 1:nExp, 'UniformOutput', false);
mouseTxt = imp_mouse_label(mnAll);           % shared cross-figure convention (utils/imp_mouse_label.m)
uMn      = unique(string(mnAll), 'stable');
fprintf('[DR] %d sessions from %d mice: %s\n', nExp, numel(uMn), strjoin(mouseTxt', ', '));

labX = nan(nExp,1); labY = nan(nExp,1); labT = cell(nExp,1);
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
    % Label position + text are collected, not drawn, so they can be placed AFTER the loop
    % once every line's end point is known (see the direct-labelling block below).
    labX(expIdx) = xf(end);          %#ok<SAGROW>
    labY(expIdx) = polyval(p, xf(end));  %#ok<SAGROW>
    labT{expIdx} = sprintf('s%d', expIdx);  %#ok<SAGROW>
    if strcmpi(DR_LABEL,'slope')
        labT{expIdx} = sprintf('s%d  %.2f', expIdx, p(1));
    elseif strcmpi(DR_LABEL,'mouse')
        labT{expIdx} = mouseTxt{expIdx};
    end
end

% Beautify
ax = gca;
ax.LineWidth = 1.5;
xlabel('Amplitude(V)', 'FontWeight','bold');
ylabel('dF/F %', 'FontWeight','bold');
ylim([-5 3])
uistack(h1, 'bottom')
xticks([])

if DR_YAXIS
    % Real y axis: the quantity is an energy in %dF/F averaged over 0-200 ms, and a corner
    % scale bar of 0.01 was effectively no axis at all -- the reader could not tell whether
    % the deepest point was -1% or -10%. x keeps its scale bar (amplitude is shown in mW by
    % the bar label, and per-session x offsets make tick values misleading).
    %
    % paperAxes = cleanAxes + shortCornerAxes_plot, and BOTH strip the real axes, so the
    % y axis has to be rebuilt AFTER the call, not configured before it (the first attempt
    % set the ticks first and they were silently wiped).
    % ORDER MATTERS TWICE HERE.
    % (1) ylim must be set BEFORE paperAxes: shortCornerAxes_plot positions the x scale bar
    %     from the ylim it sees, so tightening the limits afterwards strands the bar far
    %     below the data with a band of white between them.
    % (2) the y axis must be restored AFTER paperAxes: it is cleanAxes +
    %     shortCornerAxes_plot and both strip the real axes.
    % Tighten to the data -- the paper panel's fixed ylim([-5 3]) keeps several exports on
    % one scale, but with a real axis drawn it left ~60% of the height empty and squashed a
    % 2.5 %dF/F effect into a third of the panel.
    yb = [-3 1];
    ylim(ax, yb);
    paperAxes(gca,'XLength',1,'YLength',0.01,'XLabel','0.25 mW','YLabel',' ');
    ax.YAxis.Visible   = 'on';
    ax.YAxis.Color     = 'k';
    ax.YAxis.LineWidth = 1.0;
    ylim(ax, yb);
    ax.YTick      = yb(1):1:yb(2);
    ax.YTickLabel = compose('%d', (yb(1):1:yb(2))');
    ax.TickDir = 'out';  ax.Box = 'off';
    ax.FontSize = PS.fs; ax.FontWeight = PS.fw;
else
    try
        % x scale bar halved 0.5 -> 0.25 mW (user, 2026-08-17). XLength is in DATA units (V);
        % the label is the mW equivalent, so both must move together or the bar lies.
        paperAxes(gca,'XLength',1,'YLength',0.01,'XLabel','0.25 mW','YLabel',' ');
    catch
        xlabel('Input(V)', 'FontWeight','bold');
        ylabel('dF/F %', 'FontWeight','bold');
    end
end

% ---- DIRECT LABELS replace the legend AND the stacked text block ---------------------------
% (user, 2026-08-17: "has colored text and legend i dont think we need both ... a lot of
% spacing in betwen and is overlapping the traces ... suggest way to merge".)
% The two carried the same information twice: the legend mapped colour -> "Session k" in one
% corner, the text block mapped colour -> slope/R2 in another, and the reader had to join them
% through the colour. Putting "s1  -0.34" at the END OF ITS OWN LINE merges them into one
% mark: identity and slope arrive together, at the object they describe, with no colour
% look-up and no legend box competing with the traces. R2 is dropped from the panel (it is a
% goodness-of-fit number, not the result) and still prints to the console for the caption.
% Vertical nudging only if two lines end within a hair of each other.
% SEQUENTIAL legend (user 2026-09-22: "just put them sequentially with no gaps"): stack the
% labels as an evenly-spaced list in the right margin, in session order, DECOUPLED from each
% line's end y-position. Uniform spacing => no ragged gaps; the colour still ties each entry
% to its trace, so it reads as a clean legend column top-to-bottom.
if ~strcmpi(DR_LABEL, 'none')
    % Place the sequential legend INSIDE the axes at the top-right (the dose-response lines
    % descend, so that corner is empty) and right-align it, so it does NOT extend the panel
    % width. Keeps the panel within the <=4 cm Fig-2 canvas (user 2026-09-22).
    xl    = xlim(ax);   yl = ylim(ax);   xr = diff(xl);
    labXc = xl(1) + 0.97*xr;                    % right edge, text grows leftward
    ytop  = yl(2) - 0.06*diff(yl);
    ystep = 0.115*diff(yl);                     % fixed row pitch -- sequential, no gaps
    for expIdx = 1:nExp
        yy = ytop - (expIdx-1)*ystep;
        text(ax, labXc, yy, labT{expIdx}, ...
            'Color', expColors(expIdx,:), 'FontSize', PS.fs, 'FontWeight', PS.fw, ...
            'HorizontalAlignment','right', 'VerticalAlignment','middle', 'Clipping','off');
    end
end
ylabTxt = 'Inhibition Energy';
if DR_YAXIS
    % name the units on the axis label, since there is now an axis to put them on
    % Two lines (2026-09-30): at the rule-book 7 pt this label is longer than a 3.3 cm
    % panel is tall, so as one line it overflowed the plot box and sat on the ticks.
    ylabTxt = {'Inhibition energy', '(% \DeltaF/F, 0-200 ms)'};
end
% Drop the built-in ylabel set further up ('dF/F %'): the rotated text below IS the y label.
% Leaving both drew a stray 'dF/F %' ~0.75 cm to the LEFT of the real one (MATLAB pushes the
% built-in label outward to clear the manual text), which was invisible on screen but present
% in the vector export -- and, being the leftmost object, it set the crop. That is what made
% imp_response.pdf land 3.85 cm wide against a 3.40 cm canvas. Found 2026-10-02 by the
% paper_final_mirror size guard.
ylabel(ax, '');
text(ax, -0.32, 0.5, ylabTxt, ...
    'Units','normalized', 'Rotation',90, ...
    'HorizontalAlignment','center', 'VerticalAlignment','middle', ...
    'FontSize',jnStyle().fs_label, 'FontWeight',PS.fw, 'Color','k', 'Clipping','off');
outDirC = fullfile(paperRoot, 'figures_v2', 'figure2');
if ~isempty(DR_OUTDIR), outDirC = DR_OUTDIR; end
% ---- DR_EXACTW: grant export at the EXACT printed width (opt-in, 2026-09-30) ---------------
% Set DR_EXACTW = {targetCm, 'full\path\out.png'} to ALSO write a grant copy before the normal
% export. On-page type = source pt x (displayed width / natural width); paperExport tight-crops
% to the content, so the saved width never equals the printed width and a LaTeX scale factor
% creeps back in. print() with an exact paper size writes the whole canvas => scale 1.0, so
% DR_FS is literally the point size the reader sees. Only safe with an explicit axes Position.
if exist('DR_EXACTW','var') && ~isempty(DR_EXACTW)
    tgtCm = DR_EXACTW{1}; outPng = DR_EXACTW{2};
    if ~exist(fileparts(outPng),'dir'), mkdir(fileparts(outPng)); end
    % The rotated 'Inhibition energy (% dF/F, 0-200 ms)' above is bounded by the PLOT-BOX
    % HEIGHT (~40 pt at 2.2 cm), not the width: at 11 pt it is ~140 pt and can only clip.
    % One glyph instead; the LaTeX panel title and caption name the quantity. Match on the
    % NORMALIZED-units text only -- paperAxes leaves a second rotated text (its blank y
    % scale-bar label, in data units at the corner), and retargeting that one too printed a
    % stray second '%' under the axis.
    tRot = findobj(fig,'Type','text','Rotation',90);
    for tt = tRot(:)'
        if strcmp(tt.Units,'normalized'), tt.String = '%'; tt.FontSize = PS.fs;
        else,                             delete(tt);
        end
    end
    axE = ax_c;
    % Ticks 6 pt, not 8 (user 2026-09-30: "ticks are too big you can make them small").
    % They set the left/bottom margin, so the plot box grows back as they shrink.
    fsTickE = 6;
    % Left margin has to hold the 6 pt y ticks AND the 11 pt rotated '%', which sits at
    % normalized x = -0.155 (i.e. OUTSIDE the axes). At 0.22 the '%' fell off the exact
    % page and printed as '/o'.
    set(axE,'Position',[0.30 0.20 0.67 0.76],'FontSize',fsTickE,'FontWeight','bold');
    % Two y ticks, not five, and both INSET from the limits: at 8 pt bold five integer labels
    % fill the 40 pt plot height, and a label centred on the bottom limit half-hangs into the
    % x scale bar at the corner.
    set(axE,'YTick',[-2 0],'YTickLabel',{'-2','0'});
    tOth = findobj(fig,'Type','text','-not','Rotation',90);
    set(tOth,'FontSize',max(8,PS.fs-3),'FontWeight','bold');
    % paperAxes hangs the x scale-bar label just under the bar, which at this canvas lands on
    % the bottom y tick; drop it clear.
    for tt = tOth(:)'
        if contains(tt.String,'mW'), tt.Position(2) = tt.Position(2) - 0.35; end
    end
    pE = get(fig,'Position');
    set(fig,'PaperUnits','centimeters','PaperSize',[tgtCm pE(4)], ...
            'PaperPosition',[0 0 tgtCm pE(4)],'PaperPositionMode','manual', ...
            'Units','centimeters','Position',[pE(1) pE(2) tgtCm pE(4)]);
    % Driver follows the extension: the draft calls this panel in as .pdf, and an exact-page
    % PDF is vector -- "high-res for zoomability" with no raster ceiling at all.
    if endsWith(lower(outPng),'.pdf')
        print(fig,'-dpdf','-vector',outPng);
        fprintf('[DR grant] %s -> %.3f cm page (vector)\n', outPng, tgtCm);
    else
        print(fig,'-dpng','-r1200',outPng);
        iE = imfinfo(outPng);
        fprintf('[DR grant] %s -> %.3f cm (target %.3f, scale %.3f)\n', ...
                outPng, iE.Width/1200*2.54, tgtCm, tgtCm/(iE.Width/1200*2.54));
    end
else
    jnAxesAll(fig);   % rule-book font/axis pass (see utils/jnAxesAll.m)
    paperExport(fig, fullfile(outDirC, sprintf('imp_response%s.pdf', PS.cbtag)));
end

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
