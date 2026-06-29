% bilateral/compare_sides.m
% Cross-side summary: OL time constants, CL MSE, tuning optima.
% Requires: all upstream scripts have been run in this workspace.

%% ---- Knobs -------------------------------------------------------------
SIDES      = {'left', 'right'};
EXPORT_FIG = false;
% -------------------------------------------------------------------------

fields = fieldnames(sessions);

%% Collect summary across sessions
summary = struct();
summary.left.tc  = {};  summary.right.tc  = {};
summary.left.mse = [];  summary.right.mse = [];
summary.left.Kp  = [];  summary.right.Kp  = [];
summary.left.Ki  = [];  summary.right.Ki  = [];

for k = 1:length(fields)
    tag  = fields{k};
    sess = sessions.(tag);
    if isfield(sess, 'skip') && sess.skip; continue; end

    for s = 1:length(SIDES)
        side = SIDES{s};
        if ~isfield(sess, side); continue; end

        if isfield(sess.(side), 'time_constants') && ~isempty(sess.(side).time_constants)
            summary.(side).tc{end+1} = sess.(side).time_constants;
        end
        if isfield(sess.(side), 'mse_cl')
            summary.(side).mse = [summary.(side).mse; nanmean(sess.(side).mse_cl)];
        end
        if isfield(sess.(side), 'gd')
            summary.(side).Kp = [summary.(side).Kp; sess.(side).gd.Kp_opt];
            summary.(side).Ki = [summary.(side).Ki; sess.(side).gd.Ki_opt];
        end
    end
end

%% Print summary
fprintf('\n===== Bilateral Summary =====\n');
for s = 1:length(SIDES)
    side = SIDES{s};
    fprintf('\n--- %s hemisphere ---\n', upper(side));
    if ~isempty(summary.(side).tc)
        all_tc = cell2mat(cellfun(@(x) x(:)', summary.(side).tc, 'UniformOutput', false));
        fprintf('  OL time constants: mean=%.3f s, range=[%.3f %.3f] s\n', ...
            mean(all_tc), min(all_tc), max(all_tc));
    end
    if ~isempty(summary.(side).mse)
        fprintf('  CL MSE: mean=%.4f (n=%d sessions)\n', mean(summary.(side).mse), length(summary.(side).mse));
    end
    if ~isempty(summary.(side).Kp)
        fprintf('  Optimal gains: Kp=%.3f±%.3f  Ki=%.3f±%.3f\n', ...
            mean(summary.(side).Kp), std(summary.(side).Kp), ...
            mean(summary.(side).Ki), std(summary.(side).Ki));
    end
end

%% Side-by-side comparison figure (time constants)
if ~isempty(summary.left.tc) || ~isempty(summary.right.tc)
    figure('Name', 'compare_tc');
    paperFig(6, 4);
    sty = paperStyle();

    tc_L = cell2mat(cellfun(@(x) x(:)', summary.left.tc,  'UniformOutput', false));
    tc_R = cell2mat(cellfun(@(x) x(:)', summary.right.tc, 'UniformOutput', false));
    data_cmp = {tc_L(:), tc_R(:)};
    labels   = {'Left (exc.)', 'Right (inh.)'};

    hold on;
    for s = 1:2
        x = s * ones(size(data_cmp{s}));
        scatter(x + 0.05*randn(size(x)), data_cmp{s}, 12, 'filled', 'MarkerFaceAlpha', 0.6);
        errorbar(s, mean(data_cmp{s}), std(data_cmp{s}), 'k', 'LineWidth', sty.lw_mean, 'CapSize', 4);
    end
    set(gca, 'XTick', [1 2], 'XTickLabel', labels, 'FontSize', sty.fs, 'FontWeight', 'bold');
    ylabel('Time constant (s)', 'FontSize', sty.fs, 'FontWeight', 'bold');
    title('OL time constants: L vs R', 'FontSize', sty.fs, 'FontWeight', 'bold');

    if EXPORT_FIG
        outDir = fullfile('paper', 'images', 'bilateral');
        if ~exist(outDir, 'dir'); mkdir(outDir); end
        exportgraphics(gcf, fullfile(outDir, 'compare_tc.png'), 'Resolution', 300);
    end
end
