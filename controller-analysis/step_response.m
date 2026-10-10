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
fig_H = paperFig(3.4, 3.4);   % jn* resize: unify row height

lm_h = 0.18; rm_h = 0.05; bm_h = 0.12; tm_h = 0.20;   % top room for the title
ax_H = axes(fig_H, 'Position', [lm_h, bm_h, 1-lm_h-rm_h, 1-bm_h-tm_h]);

t1_h = (-3*35 : 35*(dur+3)) / 35;
t_h  = 0 : 1/35 : dur;
colOL = PS.col_ol;
colCL = PS.col_cl;

Error_nc = [];
Error_wc = [];
faintMax = 0;

% METRIC = RMSE, not MAE (user, 2026-08-24: "everything else has RMSE"). MAE here was
% abs(mean(e over trials)) -- opposite-sign errors on different trials CANCEL, so it measured
% BIAS only. RMSE = sqrt(mean(e^2 over trials)) cancels nothing (RMSE^2 = bias^2 + across-trial
% variance), matching every other Fig-3 error panel. Keep the deviation as a TRIALS x T matrix
% (no early mean) so the across-trial RMS can be taken. Supersedes the "3H is genuinely MAE"
% locked note. ⚠ RMSE folds in the across-trial spread, so this panel now shares information
% with the variance panel (3F) -- they are no longer independent evidence.
hold(ax_H, 'on');
for k = 1:length(fields)
    dev_NC = mouse.(fields{k}).data.pncDfk_l - ...
        [mouse.(fields{k}).data.pncDfk_l(:,1:35*3), ...
         -5*ones(length(mouse.(fields{k}).data.nc), 35*3), ...
         mouse.(fields{k}).data.pncDfk_l(:,35*6+1:end)];
    dev_WC = mouse.(fields{k}).data.pwcDfk_l - ...
        [mouse.(fields{k}).data.pwcDfk_l(:,1:35*3), ...
         -5*ones(length(mouse.(fields{k}).data.wc), 35*3), ...
         mouse.(fields{k}).data.pwcDfk_l(:,35*6+1:end)];
    rmse_NC = sqrt(mean(dev_NC.^2, 1));
    rmse_WC = sqrt(mean(dev_WC.^2, 1));
    Error_nc = [Error_nc; sqrt(mean(mouse.(fields{k}).data.error_nc.^2, 1))]; %#ok<AGROW>
    Error_wc = [Error_wc; sqrt(mean(mouse.(fields{k}).data.error_wc.^2, 1))]; %#ok<AGROW>
    faintMax = max([faintMax, rmse_NC, rmse_WC]);
    plot(ax_H, t1_h, rmse_NC, 'Color', [colOL, PS.fa], 'LineWidth', PS.lw_trial, 'HandleVisibility','off');
    plot(ax_H, t1_h, rmse_WC, 'Color', [colCL, PS.fa], 'LineWidth', PS.lw_trial, 'HandleVisibility','off');
end
plot(ax_H, t_h, mean(Error_nc), 'Color', colOL, 'LineWidth', PS.lw_mean);
plot(ax_H, t_h, mean(Error_wc), 'Color', colCL, 'LineWidth', PS.lw_mean);
addStimPatch(ax_H, 0, dur);
xlim(ax_H, [-0.5 dur+0.5]);
% RMSE runs above the old MAE range -- take the top from the data (floored at the old 6) so
% the faint traces do not clip.
ylim(ax_H, [-0.25, max([6, 1.08*faintMax, 1.08*max([Error_nc(:); Error_wc(:)])])]);
hold(ax_H, 'off');

% Legend removed (2026-09-30, user): OL/CL colour is established on panels A-C and
% stated in the caption, so the in-panel key only cost plot area at 3.4 cm.
paperAxes(ax_H, 'XLength',0.5, 'YLength',1, 'XLabel','500 ms', 'YLabel','RMSE dF/F');
title(ax_H, 'Trial-averaged tracking error', ...
    'FontSize', 6, 'FontWeight', 'bold', 'Color', 'k');    % user, 2026-10-10
% Line-weight key (user 2026-10-10): thin = one session, bold = mean of sessions. Drawn in
% neutral grey/black, NOT as a legend, because colour already codes OL/CL (panels A-C) and a
% coloured key would read as a third condition.
xk = dur - 1.05;  yl_k = ylim(ax_H);  yk = yl_k(2) - [0.10 0.20]*diff(yl_k);
line(ax_H, xk + [0 0.35], yk(1)*[1 1], 'Color', [0.55 0.55 0.55], 'LineWidth', PS.lw_trial, 'Clipping','off');
line(ax_H, xk + [0 0.35], yk(2)*[1 1], 'Color', [0 0 0], 'LineWidth', PS.lw_mean, 'Clipping','off');
text(ax_H, xk + 0.45, yk(1), 'session', 'FontSize', 6, 'VerticalAlignment','middle', 'Color', [0.4 0.4 0.4]);
text(ax_H, xk + 0.45, yk(2), 'mean',    'FontSize', 6, 'VerticalAlignment','middle', 'Color', [0 0 0]);
paperExport(fig_H, fullfile(paper_root, 'images', 'figure3', 'all_average_sessions.pdf'));




%% Step response: two-row stack (mean response above across-trial variance), monochrome
close all;
fig = paperFig(6, 4);
set(gcf, 'Renderer', 'opengl');

t  = -3:1/35:(dur+3);

custom_idx = [4 9 11];   % sessions for the step-response panel

% Session = sequential colour gradient (PS.sessGrad -> ordered, CB-safe). Mean
% response (top) and across-trial variance (bottom) are SEPARATE rows sharing
% the time axis, instead of overlaid via a +2 offset.
expColors = PS.sessGrad(numel(custom_idx));

lm = 0.15; rm = 0.04;
ax_mean = axes(fig, 'Position', [lm 0.46 1-lm-rm 0.48]); hold(ax_mean, 'on');
ax_var  = axes(fig, 'Position', [lm 0.12 1-lm-rm 0.26]); hold(ax_var,  'on');

hLegend = gobjects(numel(custom_idx), 1);
legTxt  = strings(numel(custom_idx), 1);

for i = 1:numel(custom_idx)
    k    = custom_idx(i);
    e_nc = mouse.(fields{k}).data.pncDfk_l;   % trials x time
    mu   = mean(e_nc, 1);
    c    = expColors(i,:);

    % top row: mean step response
    hLegend(i) = plot(ax_mean, t, mu, '-', 'Color', c, 'LineWidth', 1.2);

    % bottom row: across-trial variance (no offset needed now)
    plot(ax_var, t, var(e_nc, 0, 1), '-', 'Color', c, 'LineWidth', 1.2);

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
custom_idx = randperm(numel(fields), n_sample);  % random sample of n ints from all loaded sessions



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

% ============ SUPPLEMENTARY S1 PANEL: BATCH VARIANCE (2026-10-05) ============
% SELF-CONTAINED ON PURPOSE: this block re-runs its own bootstrap on a FIXED session
% set with a FIXED seed, instead of reusing the working view's arrays above.
%
% REPRODUCIBILITY DEFECT IN THE WORKING VIEW (found 2026-10-05). Line ~146 does
%     custom_idx = randperm(numel(fields), n_sample);
% which CLOBBERS the step-response set (custom_idx = [4 9 11]) with three RANDOM
% sessions, drawn fresh on every run, and the bootstrap itself is unseeded. So the
% published spont_variance.pdf plots three sessions nobody can identify, its
% "Session 1/2/3" legend names different animals each time the script is run, and
% the curves cannot be regenerated. That is fine for the exploratory check it was --
% "does convergence hold for arbitrary sessions" -- and not fine for a figure.
% This panel therefore pins the set to the step-response sessions, which is what the
% rest of the figure already shows, and seeds the draws.
%
% PRESENTATION ALSO CHANGED, because the working view hides the result:
% the measured finding is that mean total variance is FLAT in batch size (it moves
% ~1-2% of its own mean from 10 to 100 trials) while its SEM falls roughly as
% 1/sqrt(n) -- i.e. the estimate is unbiased and its uncertainty shrinks. That lives
% entirely in the error bars. The working view min-max normalises each curve, which
% maps its own min to 0 and max to 1 and so STRETCHES A 1% RIPPLE ACROSS THE FULL
% PANEL HEIGHT; what you then see is bootstrap noise at full amplitude, reading as
% "variance wanders with batch size" -- the opposite of the finding. Normalising by
% each session's own MEAN instead puts every session at 1.0 and leaves the error
% bars as the thing the reader watches shrink.
%
% DEGENERATE POINTS DROPPED. The draw is randperm(n_trials, min(n, n_trials)), so
% once the batch size reaches a session's trial count every repeat returns the SAME
% full set and the SEM is exactly 0 -- by construction, not because the estimate
% became perfect. Those points are excluded rather than plotted as perfect
% convergence.
if ~exist('SR_SUPP_PANEL','var') || isempty(SR_SUPP_PANEL), SR_SUPP_PANEL = true; end
if SR_SUPP_PANEL
    BV_SESS    = [4 9 11];            % step-response sessions -- fixed, not sampled
    BV_BATCH   = 10:10:100;
    BV_REPEATS = 500;
    bvRng = RandStream('mt19937ar', 'Seed', 20261005);   % local; does not disturb global RNG

    % 3.0 cm tall, not 2.6: the legend band below the data pushed the content to
    % 3.00 cm and the size guard correctly flagged the panel as overhanging its
    % canvas. Declare the size the panel actually is.
    fBV = paperFig(3.4, 3.0);
    axBV = axes(fBV); hold(axBV,'on'); grid(axBV,'off'); %#ok<LAXES>
    bvCol = lines(numel(BV_SESS));
    hBV = gobjects(numel(BV_SESS),1);
    fprintf('\n[step_response] S1 batch variance (fixed sessions, seeded):\n');
    for i = 1:numel(BV_SESS)
        sd  = mouse.(fields{BV_SESS(i)}).data.spont_dFk;
        nTr = size(sd, 1);
        keep = BV_BATCH < nTr;                 % drop the whole-set draws
        bs  = BV_BATCH(keep);
        mv = nan(1,numel(bs)); sv = nan(1,numel(bs));
        for bi = 1:numel(bs)
            v = zeros(BV_REPEATS,1);
            for r = 1:BV_REPEATS
                v(r) = sum(var(sd(randperm(bvRng, nTr, bs(bi)), :)));
            end
            mv(bi) = mean(v); sv(bi) = std(v)/sqrt(BV_REPEATS);
        end
        mu0 = mean(mv); yv = mv/mu0; ev = sv/mu0;
        errorbar(axBV, bs, yv, ev, '-o', 'Color', bvCol(i,:), ...
            'LineWidth', PS.lw_mean, 'MarkerSize', 2, 'MarkerFaceColor', bvCol(i,:), ...
            'MarkerEdgeColor', 'none', 'CapSize', 2, 'HandleVisibility','off');
        hBV(i) = plot(axBV, nan, nan, '-', 'Color', bvCol(i,:), 'LineWidth', PS.lw_mean);
        fprintf(['   sess %d (%s, %d trials): spread %.2f%% of mean | ' ...
                 'SEM %.2f%% -> %.2f%% of mean (x%.2f over n=%d->%d)\n'], ...
                 i, fields{BV_SESS(i)}, nTr, 100*(max(yv)-min(yv)), ...
                 100*ev(1), 100*ev(end), ev(end)/ev(1), bs(1), bs(end));
    end
    yline(axBV, 1, ':', 'Color', [.45 .45 .45], 'LineWidth', PS.lw_ref);
    xlim(axBV, [min(BV_BATCH)-6, max(BV_BATCH)+6]);
    % Clear band below the data for the legend. Every curve sits on 1.0 by
    % construction, so without this there is no empty corner anywhere in the panel
    % and the legend lands on a trace wherever it is placed.
    ybv = ylim(axBV);
    ylim(axBV, [ybv(1) - 0.45*diff(ybv), ybv(2)]);
    xticks(axBV, [20 60 100]);
    xlabel(axBV, 'batch size (trials)');
    ylabel(axBV, 'variance / session mean');
    % Legend at southeast: at northeast it printed across the curves, and with every
    % session pinned to 1.0 the top of the panel is never free.
    lgBV = legend(axBV, hBV, arrayfun(@(i) sprintf('session %d',i), ...
        1:numel(BV_SESS), 'uni', 0), 'Box','off', 'Location','southeast');
    lgBV.ItemTokenSize = PS.lgd_token;
    hold(axBV,'off');
    paperExport(fBV, fullfile(supp_dir, 'supp_s1_batch_variance.pdf'));
    fprintf('[step_response] S1 batch-variance panel -> %s\n', supp_dir);
end





