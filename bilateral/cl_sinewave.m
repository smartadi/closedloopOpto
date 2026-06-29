% bilateral/cl_sinewave.m
% Feedforward / preview sine-wave controller analysis, both sides.
% Requires: load_bilateral.m has been run. exp_type = 'sinewave'.

%% ---- Knobs -------------------------------------------------------------
SIDES      = {'left', 'right'};
dur        = 3.0;      % analysis window (s)
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
                 strcmp({sess.trial_meta.stim_type}, 'sinewave');
        trials = [sess.trial_meta(mask).trial_idx];
        if isempty(trials)
            fprintf('[%s] No sinewave trials on %s side — skipping.\n', tag, side);
            continue;
        end

        %% Collect trial traces
        traces_nc = [];   % no controller (OL)
        traces_wc = [];   % with feedforward controller

        % Split nc / wc trials — uses same controllerData convention:
        %   d.nc = OL trial indices, d.wc = CL/FF trial indices
        % These are expected in sess.d; if not present, treat all as wc.
        if isfield(d, 'nc') && isfield(d, 'wc')
            nc_trials = intersect(trials, d.nc);
            wc_trials = intersect(trials, d.wc);
        else
            nc_trials = [];
            wc_trials = trials;
        end

        for j = 1:length(nc_trials)
            [~, i0] = min(abs(t - d.stimStarts(nc_trials(j))));
            if i0 - n_pre < 1 || i0 + n_win > length(dFoF); continue; end
            traces_nc = [traces_nc; dFoF(i0 - n_pre : i0 + n_win)];
        end
        for j = 1:length(wc_trials)
            [~, i0] = min(abs(t - d.stimStarts(wc_trials(j))));
            if i0 - n_pre < 1 || i0 + n_win > length(dFoF); continue; end
            traces_wc = [traces_wc; dFoF(i0 - n_pre : i0 + n_win)];
        end

        %% Tracking error (RMS)
        t_ax = (-n_pre : n_win) / fs_img;
        t_post = t_ax >= 0;

        rms_nc = NaN; rms_wc = NaN;
        if ~isempty(traces_nc)
            err_nc = mean(traces_nc(:, t_post), 1) - ref;
            rms_nc = rms(err_nc);
        end
        if ~isempty(traces_wc)
            err_wc = mean(traces_wc(:, t_post), 1) - ref;
            rms_wc = rms(err_wc);
        end

        sessions.(tag).(side).sine.rms_nc = rms_nc;
        sessions.(tag).(side).sine.rms_wc = rms_wc;
        sessions.(tag).(side).sine.ff_benefit = rms_nc - rms_wc;  % positive = FF helps

        fprintf('[%s] %s sinewave | OL RMS=%.4f | FF RMS=%.4f | benefit=%.4f\n', ...
            tag, side, rms_nc, rms_wc, rms_nc - rms_wc);

        %% Figure
        figTag = sprintf('sinewave_%s_%s', tag, side);
        figure('Name', figTag);
        paperFig(6, 4);
        sty = paperStyle();

        hold on;
        if ~isempty(traces_nc)
            plot(t_ax, mean(traces_nc,1), 'Color', [0.6 0.6 0.6], 'LineWidth', sty.lw_mean);
        end
        if ~isempty(traces_wc)
            plot(t_ax, mean(traces_wc,1), 'k', 'LineWidth', sty.lw_mean);
        end
        yline(ref, '--', 'Color', [0.5 0.5 0.5], 'LineWidth', sty.lw_ref);
        xline(0, 'k:', 'LineWidth', 0.8);
        legend({'OL','FF-CL'}, 'FontSize', sty.fs, 'ItemTokenSize', [6 6]);
        xlabel('Time (s)', 'FontSize', sty.fs, 'FontWeight', 'bold');
        ylabel('\DeltaF/F (%)', 'FontSize', sty.fs, 'FontWeight', 'bold');
        title(sprintf('Sinewave FF | %s | %s', tag, side), 'FontSize', sty.fs, 'FontWeight', 'bold');

        if EXPORT_FIG
            outDir = fullfile('paper', 'images', 'bilateral');
            if ~exist(outDir, 'dir'); mkdir(outDir); end
            exportgraphics(gcf, fullfile(outDir, [figTag '.png']), 'Resolution', 300);
        end
    end
end
