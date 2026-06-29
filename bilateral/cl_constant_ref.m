% bilateral-analysis/cl_constant_ref.m
% CL constant-reference controller analysis, both sides.
% Requires: load_bilateral.m has been run.

%% ---- Knobs -------------------------------------------------------------
SIDES      = {'left', 'right'};
dur        = 3.0;     % MSE window (s) — t = 0 to +3 s post stim onset
fs_img     = 35;
EXPORT_FIG = false;
% -------------------------------------------------------------------------

fields = fieldnames(sessions);

for k = 1:length(fields)
    tag  = fields{k};
    sess = sessions.(tag);
    if isfield(sess, 'skip') && sess.skip; continue; end
    d = sess.d;
    t = d.timeBlue;
    n_win = round(dur * fs_img);
    n_pre = round(3 * fs_img);

    for s = 1:length(SIDES)
        side = SIDES{s};
        if isempty(sess.(side).dFoF); continue; end

        dFoF = sess.(side).dFoF;
        ref  = sess.(side).ref;

        mask   = strcmp({sess.trial_meta.side}, side) & ...
                 strcmp({sess.trial_meta.stim_type}, 'cl_const');
        trials = [sess.trial_meta(mask).trial_idx];
        if isempty(trials)
            fprintf('[%s] No cl_const trials on %s side — skipping.\n', tag, side);
            continue;
        end

        %% Per-trial MSE and trace
        mse_cl = NaN(length(trials), 1);
        traces = [];

        for j = 1:length(trials)
            [~, i0] = min(abs(t - d.stimStarts(trials(j))));
            if i0 + n_win > length(dFoF) || i0 - n_pre < 1; continue; end
            seg        = dFoF(i0 : i0 + n_win);
            mse_cl(j)  = mean((seg - ref).^2);
            traces     = [traces; dFoF(i0 - n_pre : i0 + n_win)];
        end

        sessions.(tag).(side).mse_cl = mse_cl;

        %% Figure: trial traces + mean
        figTag = sprintf('CL_const_%s_%s', tag, side);
        figure('Name', figTag);
        paperFig(6, 4);
        sty = paperStyle();

        t_ax = (-n_pre : n_win) / fs_img;
        hold on;
        plot(t_ax, traces', 'Color', [0.7 0.7 0.7], 'LineWidth', sty.lw_trial);
        plot(t_ax, mean(traces,1), 'k', 'LineWidth', sty.lw_mean);
        yline(ref, '--', 'Color', [0.5 0.5 0.5], 'LineWidth', sty.lw_ref);
        xline(0, 'k:', 'LineWidth', 0.8);
        xlabel('Time (s)', 'FontSize', sty.fs, 'FontWeight', 'bold');
        ylabel('\DeltaF/F (%)', 'FontSize', sty.fs, 'FontWeight', 'bold');
        title(sprintf('CL const | %s | %s | ref=%.1f', tag, side, ref), ...
              'FontSize', sty.fs, 'FontWeight', 'bold');

        if EXPORT_FIG
            outDir = fullfile('paper', 'images', 'bilateral');
            if ~exist(outDir, 'dir'); mkdir(outDir); end
            exportgraphics(gcf, fullfile(outDir, [figTag '.png']), 'Resolution', 300);
        end

        fprintf('[%s] %s MSE: mean=%.4f, median=%.4f (%d trials)\n', ...
            tag, side, mean(mse_cl,'omitnan'), median(mse_cl,'omitnan'), length(trials));
    end
end
