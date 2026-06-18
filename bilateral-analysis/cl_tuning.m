% bilateral-analysis/cl_tuning.m
% Offline controller tuning: Kp x Ki grid sweep + gradient descent.
% Requires: load_bilateral.m has been run. Sessions must have exp_type 'cl_tune'.
%
% Approach:
%   1. For each (Kp, Ki) pair, simulate a PI controller on recorded OL traces
%      to estimate what CL MSE would have been (offline replay).
%   2. Gradient descent initialised at grid minimum using numerical gradient.

%% ---- Knobs -------------------------------------------------------------
SIDES     = {'left', 'right'};
dur       = 3.0;     % MSE window (s)
fs_img    = 35;
fs_ctrl   = 2000;    % controller / input sample rate (Hz) — verify from data

% Kp x Ki grid
Kp_range  = linspace(0, 5, 20);
Ki_range  = linspace(0, 2, 20);

% Gradient descent
GD_ALPHA  = 1e-3;    % step size
GD_ITERS  = 200;
GD_EPS    = 1e-4;    % finite-difference epsilon for numerical gradient

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

    for s = 1:length(SIDES)
        side = SIDES{s};
        if isempty(sess.(side).dFoF); continue; end

        dFoF = sess.(side).dFoF;
        ref  = sess.(side).ref;

        mask   = strcmp({sess.trial_meta.side}, side) & ...
                 strcmp({sess.trial_meta.stim_type}, 'cl_tune');
        trials = [sess.trial_meta(mask).trial_idx];
        if isempty(trials)
            fprintf('[%s] No cl_tune trials on %s side — skipping.\n', tag, side);
            continue;
        end

        %% Collect OL trial segments (imaging) + input traces (controller rate)
        ti = d.inpTime;
        ol_segs  = {};
        inp_segs = {};

        for j = 1:length(trials)
            [~, i0] = min(abs(t - d.stimStarts(trials(j))));
            if i0 + n_win > length(dFoF); continue; end
            ol_segs{end+1} = dFoF(i0 : i0 + n_win);

            [~, i0c] = min(abs(ti - d.stimStarts(trials(j))));
            n_ctrl   = round(dur * fs_ctrl);
            if i0c + n_ctrl <= length(d.inpVals)
                inp_segs{end+1} = d.inpVals(i0c : i0c + n_ctrl);
            else
                inp_segs{end+1} = [];
            end
        end

        nT = length(ol_segs);

        %% Helper: offline PI replay MSE
        %  Simulates a PI controller applied to each OL dF/F trace.
        %  Returns mean MSE across trials for given (Kp, Ki).
        function mse = offline_pi_mse(Kp, Ki, ol_segs, ref, fs)
            dt  = 1 / fs;
            N   = length(ol_segs);
            mse = 0;
            for jj = 1:N
                y   = ol_segs{jj}(:);
                ny  = length(y);
                e   = zeros(ny, 1);
                ei  = 0;
                u   = zeros(ny, 1);
                for ii = 1:ny
                    e(ii)  = ref - y(ii);
                    ei     = ei + e(ii) * dt;
                    u(ii)  = Kp * e(ii) + Ki * ei;
                end
                mse = mse + mean(e.^2);
            end
            mse = mse / N;
        end

        %% Grid sweep
        mse_grid = NaN(length(Kp_range), length(Ki_range));
        fprintf('[%s] %s: running %dx%d grid sweep...\n', tag, side, length(Kp_range), length(Ki_range));

        for pi = 1:length(Kp_range)
            for qi = 1:length(Ki_range)
                mse_grid(pi, qi) = offline_pi_mse(Kp_range(pi), Ki_range(qi), ol_segs, ref, fs_img);
            end
        end

        [~, idx] = min(mse_grid(:));
        [ri, ci] = ind2sub(size(mse_grid), idx);
        Kp0 = Kp_range(ri);
        Ki0 = Ki_range(ci);
        fprintf('[%s] %s: grid minimum Kp=%.3f Ki=%.3f MSE=%.4f\n', tag, side, Kp0, Ki0, mse_grid(ri,ci));

        sessions.(tag).(side).grid.mse  = mse_grid;
        sessions.(tag).(side).grid.Kp   = Kp_range;
        sessions.(tag).(side).grid.Ki   = Ki_range;
        sessions.(tag).(side).grid.Kp_opt = Kp0;
        sessions.(tag).(side).grid.Ki_opt = Ki0;

        %% Gradient descent from grid minimum
        Kp_gd = Kp0; Ki_gd = Ki0;
        gd_path = [Kp_gd Ki_gd];

        for iter = 1:GD_ITERS
            f0   = offline_pi_mse(Kp_gd, Ki_gd, ol_segs, ref, fs_img);
            dKp  = (offline_pi_mse(Kp_gd + GD_EPS, Ki_gd, ol_segs, ref, fs_img) - f0) / GD_EPS;
            dKi  = (offline_pi_mse(Kp_gd, Ki_gd + GD_EPS, ol_segs, ref, fs_img) - f0) / GD_EPS;
            Kp_gd = max(0, Kp_gd - GD_ALPHA * dKp);
            Ki_gd = max(0, Ki_gd - GD_ALPHA * dKi);
            gd_path = [gd_path; Kp_gd Ki_gd];
            if norm([dKp dKi]) < 1e-6; break; end
        end

        Kp_opt = Kp_gd; Ki_opt = Ki_gd;
        fprintf('[%s] %s: GD optimum Kp=%.3f Ki=%.3f MSE=%.4f\n', tag, side, Kp_opt, Ki_opt, ...
            offline_pi_mse(Kp_opt, Ki_opt, ol_segs, ref, fs_img));

        sessions.(tag).(side).gd.Kp_opt  = Kp_opt;
        sessions.(tag).(side).gd.Ki_opt  = Ki_opt;
        sessions.(tag).(side).gd.path    = gd_path;

        %% Figure: MSE heatmap + GD path
        figTag = sprintf('tuning_%s_%s', tag, side);
        figure('Name', figTag);
        paperFig(6, 4);
        sty = paperStyle();

        imagesc(Ki_range, Kp_range, mse_grid);
        axis xy; colorbar;
        hold on;
        plot(gd_path(:,2), gd_path(:,1), 'w-o', 'LineWidth', 1.2, 'MarkerSize', 3);
        plot(Ki_opt, Kp_opt, 'r*', 'MarkerSize', 6);
        xlabel('Ki', 'FontSize', sty.fs, 'FontWeight', 'bold');
        ylabel('Kp', 'FontSize', sty.fs, 'FontWeight', 'bold');
        title(sprintf('Tuning | %s | %s', tag, side), 'FontSize', sty.fs, 'FontWeight', 'bold');

        if EXPORT_FIG
            outDir = fullfile('paper', 'images', 'bilateral');
            if ~exist(outDir, 'dir'); mkdir(outDir); end
            exportgraphics(gcf, fullfile(outDir, [figTag '.png']), 'Resolution', 300);
        end
    end
end
