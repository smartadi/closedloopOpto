% controller-analysis -- extracted from plottingScript.m
% Run from brain_paper/ root directory.
% Requires: load_sessions.m has been run first (mouse, fields, tp, Mean_var_wc/nc, dur).


% Fits a fixed 2-pole 1-zero TF to the OL trial average for sessions [4 9 11].
% Main figure (nSess x 2): col 1 = OL traces + TF fit, col 2 = CL mean vs OL-TF pred.
% Separate interactive figure: trial R^2 vs trial MSE (OL + CL), click -> plotSingleTrial.

% SESSION SET. Historically [4 9 11] -- the three sessions the raw OL step-response panel (2D)
% used. 2D is retired (user, 2026-08-12: the impulse and step responses are different
% measurements, so a raw step panel beside the impulse panels invites a comparison the data
% does not support). What replaces it is THIS panel run over EVERY controller session: the
% claim becomes "a low-order LTI model fits the OL trial average in all N sessions", which is
% what licenses an LTI design later. Set OL_TF_SESS to override.
if ~exist('OL_TF_SESS','var') || isempty(OL_TF_SESS)
    ol_sess_idx = 1:numel(fields);
else
    ol_sess_idx = OL_TF_SESS;
end
Fs_ol  = 35;   Ts_ol = 1/Fs_ol;
Fs_in  = 2000;
nPre_ol  = 5;             % zero-prepend length (> model order for clean initialisation)
tfOpt_ol = tfestOptions('EnforceStability', false, 'Display', 'off');

nSess_ol  = numel(ol_sess_idx);
PS_tf     = paperStyle();
% One row PER SESSION. This was a hardcoded 3x3 (blue/red/green) from when the panel was
% locked to sessions [4 9 11]; with the set opened to all controller sessions, `col_s =
% ol_colors(si,:)` threw an index error on session 4 and the loop died there -- silently, as
% far as the paper panel was concerned, because sessions 1-3 had already been drawn.
ol_colors = PS_tf.sessGrad(nSess_ol);

% Accumulation arrays for interactive validation figure
ud_nc_tf   = struct('field',{}, 'stim_idx',{}, 'lbl',{}, 'mse',{});
ud_wc_tf   = struct('field',{}, 'stim_idx',{}, 'lbl',{}, 'mse',{});
r2_nc_all  = [];  mse_nc_all = [];
r2_wc_all  = [];  mse_wc_all = [];

fig_ol = figure;
tlo_ol = tiledlayout(nSess_ol, 3, 'TileSpacing', 'compact', 'Padding', 'compact');

rng('shuffle');   % ensure different random trial pick on every run

% Paper-level figure: OL trial average + TF fit, -1 to +1 s, one column per session
PS = paperStyle();
setPaperDefaults();
colOL = PS.col_ol;
colCL = PS.col_cl;
fig_tf_paper = paperFig(6, 4);
ax_p = axes(fig_tf_paper); hold(ax_p, 'on');
% Controller sessions are a DIFFERENT session set from the impulse ones, so they get their own
% ramp sampled to this set's size -- PS.sessColor is reserved for impulse session identity and
% reusing it here would imply s1 in 2C-i is s1 here, which it is not (Fig-2 colour policy).
gradC_tf = PS.sessGrad(nSess_ol);
hLegTF   = gobjects(nSess_ol, 1);      % one legend handle per session
R2_all_ol = nan(1,nSess_ol);  ordNP_ol = nan(1,nSess_ol);  ordNZ_ol = nan(1,nSess_ol);
hFitTF    = gobjects(nSess_ol,1);
% OL_TF_SHOWN: how many sessions the PAPER panel draws, picked by R2 (user, 2026-08-17: the
% 15-session overlay "looks absurd", "just keep three best fit sessions"). This is selection
% on the outcome, so the panel is an EXAMPLE, not a population estimate -- every session is
% still fitted and the all-15 distribution is still printed. The on-panel "best N of 15" line
% was REMOVED on user instruction (too verbose) and is now printed to the console as
% "[OL-TF] CAPTION MUST STATE: ..." -- so the selection now depends on the caption carrying it.
% Set to Inf to draw all of them.
if ~exist('OL_TF_SHOWN','var') || isempty(OL_TF_SHOWN), OL_TF_SHOWN = 3; end
% Stim-window shading drawn ONCE (all sessions share the locked dur=3 s window)
patch(ax_p, [0 dur dur 0], [-8 -8 5 5], [0.85 0.85 0.85], ...
    'FaceAlpha',0.4, 'EdgeColor','none', 'HandleVisibility','off');

for si = 1:nSess_ol
    fld       = fields{ol_sess_idx(si)};
    d_ol      = mouse.(fld).d;
    data_ol_s = mouse.(fld).data;
    dur_ol    = d_ol.params.dur;
    col_s     = ol_colors(si, :);

    ncDfk_ol = data_ol_s.ncDfk;
    ncInp_ol = data_ol_s.ncInp;
    nNc_ol   = size(ncDfk_ol, 1);

    fprintf('\n-- Session %d: %s  %s  en%d  (%d OL trials  dur=%d s)\n', ...
        si, mouse.(fld).mn, mouse.(fld).td, mouse.(fld).en, nNc_ol, dur_ol);

    if nNc_ol == 0
        warning('No OL trials in %s -- skipping.', fld);
        nexttile(tlo_ol); nexttile(tlo_ol); nexttile(tlo_ol);
        continue
    end

    % Downsample input 2 kHz -> 35 Hz
    ncInp_ds = resample(ncInp_ol', Fs_ol, Fs_in)';
    nSamp_ol = min(dur_ol*Fs_ol + 1, size(ncInp_ds, 2));
    ncInp_ds = ncInp_ds(:, 1:nSamp_ol);

    % Baseline correct: pre-onset window = first Fs_ol columns (t = -1 to 0 s)
    iOn_ol      = Fs_ol + 1;
    baseline_ol = mean(ncDfk_ol(:, 1:iOn_ol-1), 2);
    ncDfk_bc    = ncDfk_ol - baseline_ol;
    u_pre       = zeros(iOn_ol-1, 1);   % laser off before stim onset

    % Post-onset OL window (t = 0 to dur s)
    y_trials_ol = ncDfk_bc(:, iOn_ol : iOn_ol + nSamp_ol - 1);
    t_ol        = (0 : nSamp_ol-1) / Fs_ol;

    % Trial average
    y_mean_ol = mean(y_trials_ol, 1)';
    y_sem_ol  = std(y_trials_ol, 0, 1)' / sqrt(nNc_ol);
    u_mean_ol = mean(ncInp_ds, 1)';

    % Fit fixed 2p1z TF on OL trial average
    u_fit_ol   = [zeros(nPre_ol,1); u_mean_ol];
    y_fit_ol   = [zeros(nPre_ol,1); y_mean_ol];
    data_id_ol = iddata(y_fit_ol, u_fit_ol, Ts_ol);
    data_id_ol.Tstart = -nPre_ol * Ts_ol;
    % AIC sweep over LOW orders (np capped at 2: candidates 1p0z / 2p0z / 2p1z),
    % nz 0..min(np-1,3), nd=0, strictly proper. Same search idea as impulse
    % tf_fit.m but pole-capped -- high-order AIC picks free-simulate poorly on the
    % long step response (e.g. 4p0z gave R2=-8 on S1); 2 poles stay robust.
    bestAIC_ol = inf; best_ol = []; bestNP_ol = NaN; bestNZ_ol = NaN;
    for np_ol = 1:2
        for nz_ol = 0:min(np_ol-1, 3)
            try
                sys_ol = tfest(data_id_ol, np_ol, nz_ol, tfOpt_ol, 'InputDelay', 0);
                aic_ol = aic(sys_ol);
                if aic_ol < bestAIC_ol
                    bestAIC_ol = aic_ol;  best_ol = sys_ol;
                    bestNP_ol = np_ol;    bestNZ_ol = nz_ol;
                end
            catch ME_ol
                fprintf('    tfest(%dp%dz) failed: %s\n', np_ol, nz_ol, ME_ol.message);
            end
        end
    end
    if isempty(best_ol)   % fallback to the old fixed order if the sweep found nothing
        best_ol = tfest(data_id_ol, 2, 1, tfOpt_ol); bestNP_ol = 2; bestNZ_ol = 1;
    end
    tf_ol{si} = best_ol;   % stash for Bode / margin analysis below
    fprintf('  AIC-best TF: %dp%dz  (AIC=%.1f)\n', bestNP_ol, bestNZ_ol, bestAIC_ol);

    % OL mean prediction -- x0 from findstates on mean pre-onset window
    y_pre_ol_mean = mean(ncDfk_bc(:, 1:iOn_ol-1), 1)';
    x0_ol = findstates(best_ol, iddata(y_pre_ol_mean, u_pre, Ts_ol));
    yp_ol = sim(best_ol, iddata([], u_mean_ol, Ts_ol), x0_ol).OutputData;
    yp_ol = yp_ol + (y_mean_ol(1) - yp_ol(1));   % anchor at actual y_0

    SS_res = sum((y_mean_ol - yp_ol).^2, 'omitnan');
    SS_tot = sum((y_mean_ol - mean(y_mean_ol,'omitnan')).^2, 'omitnan');
    R2_ol  = 1 - SS_res / max(SS_tot, eps);

    p_ol   = pole(best_ol);
    tau_ol = sort(abs(1 ./ real(p_ol(real(p_ol) < 0))));
    fprintf('  %dp%dz  R2=%.3f  tau =', bestNP_ol, bestNZ_ol, R2_ol);
    if ~isempty(tau_ol), fprintf('  %.3f s', tau_ol); end
    fprintf('\n');

    % Trial-level OL R^2 and accumulate UserData for interactive figure
    nNC_ud = min(nNc_ol, numel(data_ol_s.er_ncDfk));
    R2_ol_trials = nan(nNC_ud, 1);
    for j = 1:nNC_ud
        u_j = ncInp_ds(j,:)';
        y_j = y_trials_ol(j,:)';
        x0_j = findstates(best_ol, iddata(ncDfk_bc(j, 1:iOn_ol-1)', u_pre, Ts_ol));
        yp_j = sim(best_ol, iddata([], u_j, Ts_ol), x0_j).OutputData;
        ss_res_j = sum((y_j - yp_j).^2, 'omitnan');
        ss_tot_j = sum((y_j - mean(y_j,'omitnan')).^2, 'omitnan');
        R2_ol_trials(j) = 1 - ss_res_j / max(ss_tot_j, eps);
        ud_nc_tf(end+1) = struct('field', fld, 'stim_idx', data_ol_s.nc(j), ...
            'lbl', 'OL', 'mse', data_ol_s.er_ncDfk(j));
    end
    r2_nc_all  = [r2_nc_all;  R2_ol_trials];
    mse_nc_all = [mse_nc_all; data_ol_s.er_ncDfk(1:nNC_ud)];
    fprintf('  OL trial-level R2: med=%.3f  IQR=%.3f\n', median(R2_ol_trials,'omitnan'), iqr(R2_ol_trials));

    % Panel 1: OL trial traces + mean +/- SEM + TF fit
    ax_ol = nexttile(tlo_ol);
    hold(ax_ol, 'on');
    for j = 1:nNc_ol
        plot(ax_ol, t_ol, y_trials_ol(j,:), ...
            'Color', [col_s, 0.15], 'LineWidth', 0.4, 'HandleVisibility', 'off');
    end
    fill(ax_ol, [t_ol, fliplr(t_ol)], ...
        [(y_mean_ol+y_sem_ol)', fliplr((y_mean_ol-y_sem_ol)')], ...
        col_s, 'FaceAlpha', 0.2, 'EdgeColor', 'none', 'HandleVisibility', 'off');
    plot(ax_ol, t_ol, y_mean_ol, 'Color', col_s, 'LineWidth', 2, 'DisplayName', 'OL mean');
    plot(ax_ol, t_ol, yp_ol, 'k--', 'LineWidth', 1.5, ...
        'DisplayName', sprintf('TF fit  R^2=%.2f', R2_ol));
    u_sc = max(abs(y_mean_ol)) / max(abs(u_mean_ol) + eps);
    plot(ax_ol, t_ol, u_mean_ol*u_sc, 'Color', [0.6 0.6 0.6], ...
        'LineWidth', 1, 'LineStyle', ':', 'DisplayName', 'Input (scaled)');
    xline(ax_ol, dur_ol, 'k:', 'LineWidth', 0.75, 'HandleVisibility', 'off');
    xlabel(ax_ol, 'Time (s)', 'FontWeight', 'bold', 'FontSize', 6);
    ylabel(ax_ol, 'dF/F (%)', 'FontWeight', 'bold', 'FontSize', 6);
    legend(ax_ol, 'Box', 'off', 'FontSize', 6, 'Location', 'best');
    title(ax_ol, sprintf('Session %d -- %s  %s  en%d  (n=%d OL)', ...
        si, mouse.(fld).mn, mouse.(fld).td, mouse.(fld).en, nNc_ol), ...
        'FontSize', 6, 'FontWeight', 'bold');
    set(ax_ol, 'Box', 'off', 'TickDir', 'out', 'FontSize', 6, 'FontWeight', 'bold');

    % CL data prep
    wcDfk_ol = data_ol_s.wcDfk;
    wcInp_ol = data_ol_s.wcInp;
    nWc_ol   = size(wcDfk_ol, 1);
    wcInp_ds = resample(wcInp_ol', Fs_ol, Fs_in)';
    wcInp_ds = wcInp_ds(:, 1:nSamp_ol);
    baseline_wc = mean(wcDfk_ol(:, 1:iOn_ol-1), 2);
    wcDfk_bc    = wcDfk_ol - baseline_wc;
    y_trials_wc = wcDfk_bc(:, iOn_ol : iOn_ol + nSamp_ol - 1);
    y_mean_wc   = mean(y_trials_wc, 1)';
    y_sem_wc    = std(y_trials_wc, 0, 1)' / sqrt(nWc_ol);
    u_mean_wc   = mean(wcInp_ds, 1)';

    % CL mean prediction using OL model -- x0 from findstates on mean pre-onset window
    y_pre_wc_mean = mean(wcDfk_bc(:, 1:iOn_ol-1), 1)';
    x0_wc = findstates(best_ol, iddata(y_pre_wc_mean, u_pre, Ts_ol));
    yp_wc = sim(best_ol, iddata([], u_mean_wc, Ts_ol), x0_wc).OutputData;
    yp_wc = yp_wc + (y_mean_wc(1) - yp_wc(1));   % anchor at actual y_0

    SS_res_wc = sum((y_mean_wc - yp_wc).^2, 'omitnan');
    SS_tot_wc = sum((y_mean_wc - mean(y_mean_wc,'omitnan')).^2, 'omitnan');
    R2_wc     = 1 - SS_res_wc / max(SS_tot_wc, eps);
    fprintf('  CL mean pred  R2=%.3f  (n=%d CL trials)\n', R2_wc, nWc_ol);

    % Trial-level CL R^2 and accumulate UserData for interactive figure
    nWC_ud = min(nWc_ol, numel(data_ol_s.er_wcDfk));
    R2_cl_trials = nan(nWC_ud, 1);
    for j = 1:nWC_ud
        u_j = wcInp_ds(j,:)';
        y_j = y_trials_wc(j,:)';
        x0_j = findstates(best_ol, iddata(wcDfk_bc(j, 1:iOn_ol-1)', u_pre, Ts_ol));
        yp_j = sim(best_ol, iddata([], u_j, Ts_ol), x0_j).OutputData;
        ss_res_j = sum((y_j - yp_j).^2, 'omitnan');
        ss_tot_j = sum((y_j - mean(y_j,'omitnan')).^2, 'omitnan');
        R2_cl_trials(j) = 1 - ss_res_j / max(ss_tot_j, eps);
        ud_wc_tf(end+1) = struct('field', fld, 'stim_idx', data_ol_s.wc(j), ...
            'lbl', 'CL', 'mse', data_ol_s.er_wcDfk(j));
    end
    r2_wc_all  = [r2_wc_all;  R2_cl_trials];
    mse_wc_all = [mse_wc_all; data_ol_s.er_wcDfk(1:nWC_ud)];
    fprintf('  CL trial-level R2: med=%.3f  IQR=%.3f\n', median(R2_cl_trials,'omitnan'), iqr(R2_cl_trials));

    % Panel 2: CL actual vs OL-TF prediction (mean)
    ax_wc = nexttile(tlo_ol);
    hold(ax_wc, 'on');
    plot(ax_wc, t_ol, y_mean_ol, 'Color', [col_s, 0.3], 'LineWidth', 1, 'DisplayName', 'OL mean (ref)');
    fill(ax_wc, [t_ol, fliplr(t_ol)], ...
        [(y_mean_wc+y_sem_wc)', fliplr((y_mean_wc-y_sem_wc)')], ...
        colCL, 'FaceAlpha', 0.2, 'EdgeColor', 'none', 'HandleVisibility', 'off');
    plot(ax_wc, t_ol, y_mean_wc,  'Color', colCL, 'LineWidth', 2, 'DisplayName', 'CL actual');
    plot(ax_wc, t_ol, yp_wc, 'k--', 'LineWidth', 1.5, ...
        'DisplayName', sprintf('OL-TF(CL mean input)  R^2=%.2f', R2_wc));
    u_sc_wc = max(abs(y_mean_wc)) / max(abs(u_mean_wc) + eps);
    plot(ax_wc, t_ol, u_mean_wc*u_sc_wc, 'Color', [0.6 0.6 0.6], ...
        'LineWidth', 1, 'LineStyle', ':', 'DisplayName', 'CL input (scaled)');
    xline(ax_wc, dur_ol, 'k:', 'LineWidth', 0.75, 'HandleVisibility', 'off');
    xlabel(ax_wc, 'Time (s)', 'FontWeight', 'bold', 'FontSize', 6);
    ylabel(ax_wc, 'dF/F (%)', 'FontWeight', 'bold', 'FontSize', 6);
    legend(ax_wc, 'Box', 'off', 'FontSize', 6, 'Location', 'best');
    title(ax_wc, sprintf('CL actual vs OL-TF pred  (n=%d CL)', nWc_ol), ...
        'FontSize', 6, 'FontWeight', 'bold');
    set(ax_wc, 'Box', 'off', 'TickDir', 'out', 'FontSize', 6, 'FontWeight', 'bold');

    % Panel 3: random CL trial vs OL-TF prediction
    ti   = randi(nWc_ol);
    u_st = wcInp_ds(ti, :)';
    y_st = y_trials_wc(ti, :)';
    x0_st = findstates(best_ol, iddata(wcDfk_bc(ti, 1:iOn_ol-1)', u_pre, Ts_ol));
    yp_st = sim(best_ol, iddata([], u_st, Ts_ol), x0_st).OutputData;
    yp_st = yp_st + (y_st(1) - yp_st(1));   % anchor at actual y_0

    ax_st = nexttile(tlo_ol);
    hold(ax_st, 'on');
    plot(ax_st, t_ol, y_st, 'Color', colCL, 'LineWidth', 1.5, ...
        'DisplayName', sprintf('CL trial %d', ti));
    plot(ax_st, t_ol, yp_st, 'k--', 'LineWidth', 1.5, 'DisplayName', 'OL-TF pred');
    u_sc_st = max(abs(y_st)) / max(abs(u_st) + eps);
    plot(ax_st, t_ol, u_st*u_sc_st, 'Color', [0.6 0.6 0.6], ...
        'LineWidth', 1, 'LineStyle', ':', 'DisplayName', 'Input (scaled)');
    xline(ax_st, dur_ol, 'k:', 'LineWidth', 0.75, 'HandleVisibility', 'off');
    xlabel(ax_st, 'Time (s)', 'FontWeight', 'bold', 'FontSize', 6);
    ylabel(ax_st, 'dF/F (%)', 'FontWeight', 'bold', 'FontSize', 6);
    legend(ax_st, 'Box', 'off', 'FontSize', 6, 'Location', 'best');
    title(ax_st, sprintf('CL trial %d vs OL-TF pred', ti), ...
        'FontSize', 6, 'FontWeight', 'bold');
    set(ax_st, 'Box', 'off', 'TickDir', 'out', 'FontSize', 6, 'FontWeight', 'bold');

    % Paper panel: OL trial average -1 to stimend+1 s + TF pred (zero input post-stim)
    n_post_extra = Fs_ol;                                    % 35 pts = 1 s post-stim
    t_pre_w      = ((0:iOn_ol-2) / Fs_ol) - 1;             % -1 to -1/35 s  (35 pts)
    t_stim_w     = (0:nSamp_ol-1) / Fs_ol;                 % 0 to dur_ol s
    t_post_extra = ((1:n_post_extra) / Fs_ol) + dur_ol;    % dur_ol+1/35 to dur_ol+1 s
    t_w_full     = [t_pre_w, t_stim_w, t_post_extra];

    pre_mn_w   = mean(ncDfk_bc(:, 1:iOn_ol-1), 1);
    pre_sem_w  = std(ncDfk_bc(:, 1:iOn_ol-1), 0, 1);

    % Post-stim actual data (if ncDfk_bc extends beyond stim window)
    col_post_s = iOn_ol + nSamp_ol;
    col_post_e = col_post_s + n_post_extra - 1;
    if size(ncDfk_bc, 2) >= col_post_e
        y_post_w   = mean(ncDfk_bc(:, col_post_s:col_post_e), 1);
        sem_post_w = std(ncDfk_bc(:, col_post_s:col_post_e), 0, 1);
    else
        y_post_w   = nan(1, n_post_extra);
        sem_post_w = nan(1, n_post_extra);
    end

    y_std_ol_w = std(y_trials_ol, 0, 1);                   % std for paper panel shading
    y_w_full   = [pre_mn_w,  y_mean_ol',  y_post_w];
    sem_w_full = [pre_sem_w, y_std_ol_w,  sem_post_w];

    % TF prediction: actual stim input then zero for 1 s post-stim
    u_pred_ext = [u_mean_ol; zeros(n_post_extra, 1)];
    yp_ext     = sim(best_ol, iddata([], u_pred_ext, Ts_ol), x0_ol).OutputData;
    yp_ext     = yp_ext + (y_mean_ol(1) - yp_ext(1));      % anchor at onset
    t_pred_ext = [t_stim_w, t_post_extra];

    % Merged paper panel: overlay this session's OL mean (solid) + TF fit (dashed)
    % on the single shared axis, coloured by the session gradient.
    colP = gradC_tf(si, :);
    hLegTF(si) = plot(ax_p, t_w_full, y_w_full, 'Color', colP, 'LineWidth', 1.2, ...
        'DisplayName', sprintf('Session %d', si));
    hFitTF(si) = plot(ax_p, t_pred_ext, yp_ext, '--', 'Color', colP, 'LineWidth', 1.0, ...
        'HandleVisibility', 'off');

    % Per-session R2 is COLLECTED, not drawn. The model order is dropped entirely (user,
    % 2026-08-17: "dont show the TF design (2p1z) its not required") -- the panel's claim is
    % that a low-order model fits, not which one AIC happened to pick, and with N sessions a
    % stacked per-session text block would bury the traces. Order still prints to console.
    R2_all_ol(si)  = R2_ol;        %#ok<SAGROW>
    ordNP_ol(si)   = bestNP_ol;    %#ok<SAGROW>
    ordNZ_ol(si)   = bestNZ_ol;    %#ok<SAGROW>
end

% ---- Decorate the merged TF paper panel once (after all sessions overlaid) ----
xline(ax_p, 0,   'Color',[0.5 0.5 0.5], 'LineWidth',0.5, 'HandleVisibility','off');
xline(ax_p, dur, 'Color',[0.5 0.5 0.5], 'LineWidth',0.5, 'HandleVisibility','off');
yline(ax_p, 0,   'Color',[0.7 0.7 0.7], 'LineWidth',0.5, 'HandleVisibility','off');
set(ax_p, 'XLim',[-1 dur+1], 'YLim',[-8 5], 'Clipping','off');
uistack(findobj(ax_p,'Type','patch'), 'bottom');
% Legend names the ENCODING only (solid = data, dashed = fit). With N sessions a row per
% session is unreadable at 6 pt and repeats a colour key that is a figure-level convention.
% The population R2 goes in one corner line -- that IS the panel's claim.
hDataDummy = plot(ax_p, nan, nan, '-',  'Color',[0.3 0.3 0.3], 'LineWidth',1.2, ...
    'DisplayName','OL mean');
hFitDummy  = plot(ax_p, nan, nan, '--', 'Color',[0.3 0.3 0.3], 'LineWidth',1.0, ...
    'DisplayName','LTI fit');
lgd_tf = legend(ax_p, [hDataDummy hFitDummy], 'Location','southwest');
paperLegend(lgd_tf);
% ItemTokenSize overrides the project default [6 6] HERE ONLY. This legend's whole job is to
% distinguish solid from dashed, and MATLAB scales its dash period with LineWidth: at 1.0 pt in
% a 6 pt token the fit swatch draws one dash and reads as a short solid line, i.e. the legend
% fails at the one thing it is for. 16 pt fits ~3 dashes, so the encoding is legible.
lgd_tf.ItemTokenSize = [16 6];
% Corner line reports the MEDIAN and the COUNT above threshold, not the range. The range is
% misleading here: two sessions return large negative R2 (the fit is worse than a flat line),
% so "R^2 -4.98-0.98" reads as a broken panel when the actual result is that most sessions
% fit well and a minority fail outright. Naming the failures is the honest summary.
nGood = sum(R2_all_ol >= 0.5);
% ---- keep only the best-fitting OL_TF_SHOWN sessions on the paper panel ------------------
[~, ordR2] = sort(R2_all_ol, 'descend', 'MissingPlacement','last');
nShow  = min(OL_TF_SHOWN, sum(isfinite(R2_all_ol)));
keepS  = ordR2(1:nShow);
hideS  = setdiff(1:nSess_ol, keepS);
for si = hideS
    if isgraphics(hLegTF(si)), set(hLegTF(si), 'Visible','off'); end
    if isgraphics(hFitTF(si)), set(hFitTF(si), 'Visible','off'); end
end
if nShow < sum(isfinite(R2_all_ol))
    ttlP = sprintf('best %d of %d · shown R^2 %.2f-%.2f · all %d median %.2f', ...
        nShow, sum(isfinite(R2_all_ol)), min(R2_all_ol(keepS)), max(R2_all_ol(keepS)), ...
        sum(isfinite(R2_all_ol)), median(R2_all_ol,'omitnan'));
else
    ttlP = sprintf('%d sessions · R^2 median %.2f · %d/%d \\geq 0.5', ...
        numel(R2_all_ol), median(R2_all_ol,'omitnan'), nGood, numel(R2_all_ol));
end
% The corner line is OFF the panel (user, 2026-08-17: too verbose). It is still built above and
% printed below as CAPTION TEXT, because the panel shows an outcome-selected subset -- that fact
% now has to reach the reader through the caption, which is the one place it can be lost.
fprintf('[OL-TF] CAPTION MUST STATE: %s\n', ttlP);
fprintf('[OL-TF] paper panel shows sessions %s (R2 %s) of %d fitted\n', ...
    mat2str(sort(keepS)), mat2str(round(R2_all_ol(sort(keepS)),3)), sum(isfinite(R2_all_ol)));
badS = find(R2_all_ol < 0.5);
fprintf('\n[OL-TF] %d sessions | R2 median %.3f | >=0.5 in %d, >=0.7 in %d\n', ...
    numel(R2_all_ol), median(R2_all_ol,'omitnan'), nGood, sum(R2_all_ol>=0.7));
fprintf('[OL-TF] orders np %s nz %s\n', mat2str(ordNP_ol), mat2str(ordNZ_ol));
if ~isempty(badS)
    fprintf(2,'[OL-TF] BELOW 0.5 in %d session(s): ', numel(badS));
    fprintf(2,'s%d (R2=%.2f)  ', [badS; R2_all_ol(badS)]);
    fprintf(2,'\n        A negative R2 means the LTI fit is worse than a flat line -- these\n');
    fprintf(2,'        are not "slightly worse" sessions and must not be averaged over.\n');
end
paperAxes(ax_p, 'XLength',1, 'YLength',3, 'XLabel','1 s', 'YLabel','3% dF/F');

% Legend goes OUTSIDE, under the bottom-left corner. Inside 'southwest' puts it straight
% across the traces: the deepest session bottoms out near the axis floor, so the lower-left
% quadrant is not empty space here -- it is the result. Laid out horizontally so two entries
% cost one shallow strip rather than a tall block. The scale bars live inside the axes, so
% nothing collides. Must run AFTER paperAxes, which moves the axes.
drawnow;
lgd_tf.Orientation = 'horizontal';
lgd_tf.Units       = 'normalized';
lgdPos = lgd_tf.Position;
axPos  = get(ax_p, 'Position');
% The axes must GIVE UP the strip first. Just moving the legend below axPos(2) runs it off the
% bottom of the figure (the default axes already sits at 0.11), where it lands on the "1 s"
% scale label. Raising the axes floor by the legend height buys clean space instead.
dy = lgdPos(4) + 0.03;
set(ax_p, 'Position', [axPos(1), axPos(2)+dy, axPos(3), axPos(4)-dy]);
% Indented past the x scale bar: flush left, the legend's solid swatch butts up against the
% "1 s" bar on the same baseline and the two read as one continuous line.
lgd_tf.Position = [axPos(1) + 0.11*axPos(3), axPos(2) + 0.01, lgdPos(3), lgdPos(4)];

% Resolve output dir whether run from brain_paper/ root or controller-analysis/
if exist(fullfile('paper','images','figure2'), 'dir')
    out_tf_dir = fullfile('paper','images','figure2');
elseif exist(fullfile('..','paper','images','figure2'), 'dir')
    out_tf_dir = fullfile('..','paper','images','figure2');
else
    out_tf_dir = '.';
    warning('tf_fit: cannot find paper/images/figure2/ -- exporting to current folder.');
end
paperExport(fig_tf_paper, fullfile(out_tf_dir, 'ol_tf_trial_avg.pdf'));
fprintf('OL TF paper figure (trial avg -1 to +1 s) ready\n');

% Interactive validation figure -- trial R^2 vs trial MSE, click -> plotSingleTrial
fig_tf_i = figure('Color', 'w', 'Name', 'TF Validation -- trial R^2 vs MSE (click to inspect)');
fig_tf_i.Units    = 'inches';
fig_tf_i.Position = [1, 1, 6, 5];
hold on;

sc_nc_tf = scatter(r2_nc_all, mse_nc_all, 20, colOL, 'o', 'filled', ...
    'MarkerFaceAlpha', 0.5, 'DisplayName', 'OL');
sc_nc_tf.UserData      = ud_nc_tf;
sc_nc_tf.ButtonDownFcn = @(src,ev) scatterClickCallback(src, ev, mouse, fields);

sc_wc_tf = scatter(r2_wc_all, mse_wc_all, 20, colCL, 'o', 'filled', ...
    'MarkerFaceAlpha', 0.5, 'DisplayName', 'CL');
sc_wc_tf.UserData      = ud_wc_tf;
sc_wc_tf.ButtonDownFcn = @(src,ev) scatterClickCallback(src, ev, mouse, fields);

xline(0, 'k:', 'LineWidth', 0.75, 'HandleVisibility', 'off');
legend('Box', 'off', 'Location', 'northwest', 'FontSize', 9, 'FontWeight', 'bold');
xlabel('OL-TF trial R^2',   'FontWeight', 'bold');
ylabel('Trial MSE  ||e||',  'FontWeight', 'bold');
title('TF validation -- click any point to inspect trial', 'FontSize', 9);
set(gca, 'Box', 'off', 'TickDir', 'out');
fprintf('TF validation figure ready -- click any point to inspect that trial.\n');

% exportgraphics(fig_ol, 'paper/ol_tf_three_sessions.pdf', 'ContentType', 'vector');


%% ── Bode plot + phase-margin analysis ────────────────────────────────────────
% Uses tf_ol{1..nSess_ol} stashed in the loop above.
% Requires Control System Toolbox (license confirmed present).

freq_hz  = logspace(-2, 1.5, 500);   % 0.01 – ~32 Hz (beyond Nyquist = 17.5 Hz)
freq_rad = freq_hz * 2 * pi;

fig_bode = figure('Color','w','Name','OL TF -- Bode plot');
fig_bode.Units    = 'inches';
fig_bode.Position = [2 2 7 5];

ax_mag = subplot(2,1,1);  hold(ax_mag,'on');
ax_ph  = subplot(2,1,2);  hold(ax_ph, 'on');

sess_labels = cell(nSess_ol,1);
fprintf('\n── Bode / phase-margin summary ──────────────────────────────────\n');

for si = 1:nSess_ol
    G   = tf_ol{si};
    col = ol_colors(si,:);

    % --- Bode magnitude & phase at dense freq grid
    [mag, ph] = bode(G, freq_rad);
    mag_db = 20*log10(squeeze(mag));
    ph_deg = squeeze(ph);          % already in degrees (unwrapped by bode())

    plot(ax_mag, freq_hz, mag_db, 'Color', col, 'LineWidth', 1.5);
    plot(ax_ph,  freq_hz, ph_deg, 'Color', col, 'LineWidth', 1.5);

    % --- Phase margin & gain/phase crossover via margin()
    % margin() needs a continuous TF; tfest returns idtf -> convert
    G_ct = tf(G);   % idtf -> standard CT tf (continuous-time)
    [Gm, Pm, Wcg, Wcp] = margin(G_ct);

    % --- Frequency where phase first hits -90 deg
    % Interpolate (ph_deg goes from 0 toward more negative values)
    idx90 = find(ph_deg <= -90, 1, 'first');
    if ~isempty(idx90) && idx90 > 1
        % linear interpolation between idx90-1 and idx90
        f1 = freq_hz(idx90-1); f2 = freq_hz(idx90);
        p1 = ph_deg(idx90-1);  p2 = ph_deg(idx90);
        f_90hz = f1 + (f2-f1)*(-90-p1)/(p2-p1);
    else
        f_90hz = NaN;
    end

    fld = fields{ol_sess_idx(si)};
    sess_labels{si} = sprintf('S%d %s %s', si, mouse.(fld).mn, mouse.(fld).td);

    fprintf('Session %d (%s  %s):\n', si, mouse.(fld).mn, mouse.(fld).td);
    fprintf('  Phase margin     = %.1f deg  @ %.3f Hz\n', Pm,   Wcp/(2*pi));
    fprintf('  Gain  margin     = %.1f dB   @ %.3f Hz\n', 20*log10(Gm), Wcg/(2*pi));
    fprintf('  Phase = -90 deg  @ %.3f Hz\n', f_90hz);
    fprintf('  Poles: %s\n', mat2str(round(pole(G_ct),3)));
    fprintf('  Zeros: %s\n', mat2str(round(zero(G_ct),3)));
end
fprintf('─────────────────────────────────────────────────────────────────\n');

% --- Cosmetics: magnitude panel
yline(ax_mag, 0, 'k:', 'LineWidth', 0.75, 'HandleVisibility','off');
set(ax_mag, 'XScale','log','Box','off','TickDir','out','FontSize',9,'FontWeight','bold');
xlabel(ax_mag, 'Frequency (Hz)', 'FontWeight','bold');
ylabel(ax_mag, 'Magnitude (dB)', 'FontWeight','bold');
title(ax_mag,  'OL TF -- Bode magnitude', 'FontSize',9);
legend(ax_mag, sess_labels, 'Box','off','Location','southwest','FontSize',8);
xlim(ax_mag, [freq_hz(1) freq_hz(end)]);

% --- Cosmetics: phase panel
yline(ax_ph, -90, 'k--', 'LineWidth', 0.75, 'HandleVisibility','off');  % -90 deg ref
yline(ax_ph,   0, 'k:',  'LineWidth', 0.75, 'HandleVisibility','off');
set(ax_ph, 'XScale','log','Box','off','TickDir','out','FontSize',9,'FontWeight','bold');
xlabel(ax_ph, 'Frequency (Hz)', 'FontWeight','bold');
ylabel(ax_ph, 'Phase (deg)',    'FontWeight','bold');
title(ax_ph,  'OL TF -- Bode phase',      'FontSize',9);
xlim(ax_ph, [freq_hz(1) freq_hz(end)]);

fprintf('Bode figure ready.\n');
