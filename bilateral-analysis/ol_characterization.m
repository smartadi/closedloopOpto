% bilateral-analysis/ol_characterization.m
% OL impulse + step response characterization for both hemispheres.
% Requires: load_bilateral.m has been run (sessions struct in workspace).

%% ---- Knobs -------------------------------------------------------------
SIDES      = {'left', 'right'};
dur_imp    = 0.200;    % inhibition energy window (s), impulse — matches impulse-analysis
dur_step   = 3.0;     % step response window (s)
fs_img     = 35;      % imaging frame rate (Hz)
peak_mode  = 3;       % 3 = mean dF/F over 0–dur_imp (energy); matches impulse-analysis
EXPORT_FIG = false;   % set true to export PNGs to paper/images/bilateral/
% -------------------------------------------------------------------------

fields = fieldnames(sessions);

for k = 1:length(fields)
    tag  = fields{k};
    sess = sessions.(tag);
    if isfield(sess, 'skip') && sess.skip; continue; end

    d = sess.d;
    t = d.timeBlue;

    for s = 1:length(SIDES)
        side = SIDES{s};
        if isempty(sess.(side).dFoF)
            fprintf('[%s] No %s-side dFoF — skipping.\n', tag, side);
            continue;
        end

        dFoF = sess.(side).dFoF;
        ref  = sess.(side).ref;

        % Select trials for this side that are impulse or step
        mask   = strcmp({sess.trial_meta.side}, side) & ...
                 ismember({sess.trial_meta.stim_type}, {'impulse','step','unknown'});
        trials = [sess.trial_meta(mask).trial_idx];
        opsin  = sess.(side).opsin;

        %% Per-trial impulse energy / step trace
        n_pre  = round(3 * fs_img);
        n_imp  = round(dur_imp * fs_img);
        n_step = round(dur_step * fs_img);

        energy = NaN(length(trials), 1);
        traces_imp  = [];
        traces_step = [];

        for j = 1:length(trials)
            [~, i0] = min(abs(t - d.stimStarts(trials(j))));
            trial_type = sess.trial_meta(trials(j)).stim_type;

            if ismember(trial_type, {'impulse','unknown'}) && i0 + n_imp <= length(dFoF)
                seg         = dFoF(i0 : i0 + n_imp);
                energy(j)   = mean(seg - ref);           % signed deviation from ref
                if i0 - n_pre >= 1
                    traces_imp = [traces_imp; dFoF(i0 - n_pre : i0 + n_imp)];
                end
            end

            if ismember(trial_type, {'step','unknown'}) && i0 + n_step <= length(dFoF)
                if i0 - n_pre >= 1
                    traces_step = [traces_step; dFoF(i0 - n_pre : i0 + n_step)];
                end
            end
        end

        %% TF fit (impulse only) — sweeps poles/zeros/delay, AIC selection
        if ~isempty(traces_imp)
            mean_imp   = mean(traces_imp, 1);
            t_imp      = (0 : length(mean_imp) - 1) / fs_img - 3;

            maxPoles = 3; maxZeros = 2; maxDelay = 5;
            best_aic = Inf; best_tf = []; best_d = 0;

            for np = 1:maxPoles
                for nz = 0:maxZeros
                    for nd = 0:maxDelay
                        try
                            y_fit = mean_imp(n_pre + 1 + nd : end)';
                            u_fit = [zeros(nd, 1); ones(length(y_fit), 1)];
                            u_fit = u_fit(1:length(y_fit));
                            data_id = iddata(y_fit, u_fit, 1/fs_img);
                            tf_c    = tfest(data_id, np, nz);
                            yh      = lsim(tf_c, u_fit, (0:length(y_fit)-1)'/fs_img);
                            resid   = y_fit - yh;
                            k_par   = np + nz + 1 + nd;
                            aic_val = length(resid) * log(var(resid)) + 2 * k_par;
                            if aic_val < best_aic
                                best_aic = aic_val;
                                best_tf  = tf_c;
                                best_d   = nd;
                            end
                        catch
                        end
                    end
                end
            end

            sessions.(tag).(side).tf    = best_tf;
            sessions.(tag).(side).tf_d  = best_d;
            sessions.(tag).(side).tf_aic = best_aic;
            if ~isempty(best_tf)
                poles_c = pole(best_tf);
                tc      = -1 ./ real(poles_c(real(poles_c) < 0));
                sessions.(tag).(side).time_constants = sort(tc, 'descend');
                fprintf('[%s] %s TF: %d poles, delay=%d, τ = %s s\n', ...
                    tag, side, length(poles_c), best_d, mat2str(round(tc,3)));
            end
        end

        %% Figures
        stim_types_present = unique({sess.trial_meta(mask).stim_type});
        figTag = sprintf('OL_%s_%s_%s', tag, side, strjoin(stim_types_present,'_'));
        [fw, fh] = deal(6, 4);   % cm, paperFig standard
        figure('Name', figTag);
        paperFig(fw, fh);
        sty = paperStyle();

        t_pre = (-n_pre : 0) / fs_img;

        if ~isempty(traces_imp)
            t_ax = (-n_pre : n_imp) / fs_img;
            hold on;
            plot(t_ax, traces_imp', 'Color', [0.7 0.7 0.7], 'LineWidth', sty.lw_trial);
            plot(t_ax, mean(traces_imp,1), 'k', 'LineWidth', sty.lw_mean);
            yline(ref, '--', 'Color', [0.5 0.5 0.5], 'LineWidth', sty.lw_ref);
            xline(0, 'k:', 'LineWidth', 0.8);
            xlabel('Time (s)', 'FontSize', sty.fs, 'FontWeight', 'bold');
            ylabel('\DeltaF/F (%)', 'FontSize', sty.fs, 'FontWeight', 'bold');
            title(sprintf('%s | %s | %s', tag, upper(side(1)), opsin), ...
                  'FontSize', sty.fs, 'FontWeight', 'bold');

        elseif ~isempty(traces_step)
            t_ax = (-n_pre : n_step) / fs_img;
            hold on;
            plot(t_ax, traces_step', 'Color', [0.7 0.7 0.7], 'LineWidth', sty.lw_trial);
            plot(t_ax, mean(traces_step,1), 'k', 'LineWidth', sty.lw_mean);
            yline(ref, '--', 'Color', [0.5 0.5 0.5], 'LineWidth', sty.lw_ref);
            xline(0, 'k:', 'LineWidth', 0.8);
            xlabel('Time (s)', 'FontSize', sty.fs, 'FontWeight', 'bold');
            ylabel('\DeltaF/F (%)', 'FontSize', sty.fs, 'FontWeight', 'bold');
            title(sprintf('%s | %s | %s', tag, upper(side(1)), opsin), ...
                  'FontSize', sty.fs, 'FontWeight', 'bold');
        end

        if EXPORT_FIG
            outDir = fullfile('paper', 'images', 'bilateral');
            if ~exist(outDir, 'dir'); mkdir(outDir); end
            exportgraphics(gcf, fullfile(outDir, [figTag '.png']), 'Resolution', 300);
        end
    end
end
