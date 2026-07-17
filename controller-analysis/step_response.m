% controller-analysis -- extracted from plottingScript.m
% Run from brain_paper/ root directory.
% Requires: load_sessions.m has been run first (mouse, fields, tp, Mean_var_wc/nc, dur).

PS = paperStyle();
setPaperDefaults();

% Resolve paper/ root -- works whether run from brain_paper/ or controller-analysis/
if exist(fullfile('paper', 'images'), 'dir')
    paper_root = 'paper';
elseif exist(fullfile('..', 'paper', 'images'), 'dir')
    paper_root = fullfile('..', 'paper');
else
    paper_root = 'paper';
    warning('step_response: cannot locate paper/ directory -- paths may be incorrect.');
end

%% H: All-session trial average
fig_H = paperFig(3, 4);

lm_h = 0.18; rm_h = 0.05; bm_h = 0.12; tm_h = 0.08;
ax_H = axes(fig_H, 'Position', [lm_h, bm_h, 1-lm_h-rm_h, 1-bm_h-tm_h]);

t1_h = (-3*35 : 35*(dur+3)) / 35;
t_h  = 0 : 1/35 : dur;
colOL = PS.col_ol;
colCL = PS.col_cl;

Error_nc = [];
Error_wc = [];

hold(ax_H, 'on');
for k = 1:length(fields)
    error_NC = mean(mouse.(fields{k}).data.pncDfk_l - ...
        [mouse.(fields{k}).data.pncDfk_l(:,1:35*3), ...
         -5*ones(length(mouse.(fields{k}).data.nc), 35*3), ...
         mouse.(fields{k}).data.pncDfk_l(:,35*6+1:end)]);
    error_WC = mean(mouse.(fields{k}).data.pwcDfk_l - ...
        [mouse.(fields{k}).data.pwcDfk_l(:,1:35*3), ...
         -5*ones(length(mouse.(fields{k}).data.wc), 35*3), ...
         mouse.(fields{k}).data.pwcDfk_l(:,35*6+1:end)]);
    error_nc = mean(mouse.(fields{k}).data.error_nc);
    error_wc = mean(mouse.(fields{k}).data.error_wc);
    Error_nc = [Error_nc; abs(error_nc)];
    Error_wc = [Error_wc; abs(error_wc)];
    plot(ax_H, t1_h, abs(error_NC), 'Color', [colOL, PS.fa], 'LineWidth', PS.lw_trial, 'HandleVisibility','off');
    plot(ax_H, t1_h, abs(error_WC), 'Color', [colCL, PS.fa], 'LineWidth', PS.lw_trial, 'HandleVisibility','off');
end
plot(ax_H, t_h, mean(Error_nc), 'Color', colOL, 'LineWidth', PS.lw_mean);
plot(ax_H, t_h, mean(Error_wc), 'Color', colCL, 'LineWidth', PS.lw_mean);
addStimPatch(ax_H, 0, dur);
xlim(ax_H, [-0.5 dur+0.5]);
ylim(ax_H, [-0.25 6]);
hold(ax_H, 'off');

lgd_H = legend(ax_H, {'Open-Loop', 'Closed-Loop'}, 'Location','northeast');
paperLegend(lgd_H);
paperAxes(ax_H, 'XLength',0.5, 'YLength',1, 'XLabel','500 ms', 'YLabel','MAE dF/F');
paperExport(fig_H, fullfile(paper_root, 'images', 'figure3', 'all_average_sessions.pdf'));




%% Step response: two-row stack (mean response above across-trial variance), monochrome
close all;
fig = paperFig(6, 4);
set(gcf, 'Renderer', 'opengl');

t  = -3:1/35:(dur+3);

custom_idx = [4 9 11];   % sessions for the step-response panel

% Monochrome session encoding (matches Fig 2B/2F): session = LINESTYLE in one
% colour. Mean response (top) and across-trial variance (bottom) are now SEPARATE
% rows sharing the time axis, instead of overlaid via a +2 offset.
sessColor = [0.15 0.15 0.15];
sessLines = {'-', '--', ':'};

lm = 0.15; rm = 0.04;
ax_mean = axes(fig, 'Position', [lm 0.46 1-lm-rm 0.48]); hold(ax_mean, 'on');
ax_var  = axes(fig, 'Position', [lm 0.12 1-lm-rm 0.26]); hold(ax_var,  'on');

hLegend = gobjects(numel(custom_idx), 1);
legTxt  = strings(numel(custom_idx), 1);

for i = 1:numel(custom_idx)
    k    = custom_idx(i);
    e_nc = mouse.(fields{k}).data.pncDfk_l;   % trials x time
    mu   = mean(e_nc, 1);
    ls   = sessLines{min(i, numel(sessLines))};

    % top row: mean step response
    hLegend(i) = plot(ax_mean, t, mu, 'LineStyle', ls, 'Color', sessColor, 'LineWidth', 1.2);

    % bottom row: across-trial variance (no offset needed now)
    plot(ax_var, t, var(e_nc, 0, 1), 'LineStyle', ls, 'Color', sessColor, 'LineWidth', 1.2);

    legTxt{i} = sprintf('Session %d', i);
end

% stim window shading on both rows, sent behind the traces
for ax = [ax_mean, ax_var]
    xlim(ax, [-3 dur+3]);
    yl = ylim(ax);
    hStim = patch(ax, [0 dur dur 0], [yl(1) yl(1) yl(2) yl(2)], [0.9 0.9 0.9], ...
        'FaceAlpha', 0.3, 'EdgeColor', 'none', 'HandleVisibility', 'off');
    uistack(hStim, 'bottom');
    ylim(ax, yl);
    xticks(ax, []);
end

% corner scale bars: dF/F on top (y only), variance + time on bottom
paperAxes(ax_mean, 'YLength', 3, 'YLabel', '3% dF/F');
paperAxes(ax_var,  'XLength', 1, 'YLength', 5, 'XLabel', '1 s', 'YLabel', '5 %^2');

% rotated label for the variance row
text(ax_var, -0.13, 0.5, {'Variance', 'across trials'}, 'Units', 'normalized', ...
    'Color', 'k', 'FontSize', PS.fs, 'FontWeight', PS.fw, ...
    'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
    'Rotation', 90, 'Clipping', 'off');

lgd = legend(ax_mean, hLegend, legTxt, 'Color', 'none', 'Location', 'southeast');
paperLegend(lgd);
lgd.AutoUpdate = 'off';

paperExport(fig, fullfile(paper_root, 'images', 'figure2', sprintf('step_response%s.pdf', PS.cbtag)));



%%
close all;

n_sample   = 3;                          % number of fields to sample
custom_idx = randperm(13, n_sample);     % random sample of n ints from 1:13



batch_sizes = 10:10:100;
m_repeats   = 500;          % number of random draws per batch size

colors = lines(length(custom_idx));



all_data  = cell(length(custom_idx), length(batch_sizes));  % {field, batchsize} -> m values

for i = 1:length(custom_idx)
    spont_dFk = mouse.(fields{custom_idx(i)}).data.spont_dFk;   % trials x time
    n_trials  = size(spont_dFk, 1);

    for bi = 1:length(batch_sizes)
        n = batch_sizes(bi);
        vals = zeros(m_repeats, 1);
        for r = 1:m_repeats
            idx  = randperm(n_trials, min(n, n_trials));
            batch = spont_dFk(idx, :);          % n x time
            % vals(r) = sum(var(batch, 0, 1));    % sum of per-timepoint variance across trials

            vals(r) = sum(var(batch));    % sum of per-timepoint variance across trials
        end
        all_data{i, bi} = vals;
    end
end

% --- plot: mean +/- SEM per field, connected by line ---
x_positions = 1:length(batch_sizes);
capWidth     = 0.2;



fig = figure('Color','w', 'Units','centimeters', 'Position',[0 0 15 10]); hold on

hLegend = gobjects(length(custom_idx), 1);
legTxt  = cell(length(custom_idx), 1);

% --- first pass: collect raw means to compute per-field grand mean ---
rawMeans = zeros(length(custom_idx), 1);
allMeanVals = zeros(length(custom_idx), length(batch_sizes));
allSemVals  = zeros(length(custom_idx), length(batch_sizes));

for i = 1:length(custom_idx)
    for bi = 1:length(batch_sizes)
        vals = all_data{i, bi};
        allMeanVals(i, bi) = mean(vals);
        allSemVals(i, bi)  = std(vals) / sqrt(m_repeats);
    end
    rawMeans(i) = mean(allMeanVals(i, :));
end

% --- second pass: min-max normalize then scale by grand mean ---
% curves span [0, rawMean] so y-amplitude encodes mean variance
for i = 1:length(custom_idx)
    c = colors(i,:);

    mn = min(allMeanVals(i,:));
    mx = max(allMeanVals(i,:));
    scale = mx - mn + eps;
    meanVals = ((allMeanVals(i,:) - mn) / scale) * rawMeans(i);
    semVals  = (allSemVals(i,:) / scale) * rawMeans(i);

    xpos = x_positions;

    % SEM bars with caps
    for bi = 1:length(batch_sizes)
        plot([xpos(bi) xpos(bi)], [meanVals(bi)-semVals(bi), meanVals(bi)+semVals(bi)], ...
            '-', 'LineWidth', 2.5, 'Color', c, 'HandleVisibility','off');
        plot([xpos(bi)-capWidth xpos(bi)+capWidth], [meanVals(bi)-semVals(bi), meanVals(bi)-semVals(bi)], ...
            '-', 'LineWidth', 2.5, 'Color', c, 'HandleVisibility','off');
        plot([xpos(bi)-capWidth xpos(bi)+capWidth], [meanVals(bi)+semVals(bi), meanVals(bi)+semVals(bi)], ...
            '-', 'LineWidth', 2.5, 'Color', c, 'HandleVisibility','off');
        plot(xpos(bi), meanVals(bi), 'o', 'MarkerSize', 8, ...
            'MarkerFaceColor', c, 'MarkerEdgeColor', c, 'HandleVisibility','off');
    end

    % Connecting line through means
    hLegend(i) = plot(xpos, meanVals, '-', 'LineWidth', 2.0, 'Color', c);
    legTxt{i}  = sprintf('Session %d', i);
end

ax = gca;
ax.LineWidth  = 1.5;
ax.FontName   = 'Arial';
ax.XColor = 'k';              % keep ticks and labels visible
ax.YColor = 'none';           % hide y axis line and ticks
ax.XAxis.LineWidth = 0.001;    % make x axis spine invisible without hiding ticks

% ticks only at 20,40,60,80,100
tick_bs  = [20 40 60 80 100];
tick_pos = x_positions(ismember(batch_sizes, tick_bs));
xticks(tick_pos);
xticklabels(arrayfun(@num2str, tick_bs, 'UniformOutput', false));
ax.XAxis.TickLength = [0.02 0.02];

% y label only, no ticks or axis line
yticks([]);
yl = ylabel('Normalized variance', 'FontName','Arial', 'FontSize',6, 'FontWeight','bold');
yl.Color = 'k';
xl = xlabel('Batch size (trials)', 'FontName','Arial', 'FontSize',6, 'FontWeight','bold');
xl.Color = 'k';

lgd = legend(ax, hLegend, legTxt, 'Color','none');
paperLegend(lgd);
lgd.AutoUpdate = 'off';
supp_dir = fullfile(paper_root, 'images', 'supplementary');
if ~isfolder(supp_dir), mkdir(supp_dir); end
paperExport(fig, fullfile(supp_dir, 'spont_variance.pdf'));




