% bilateral/sine_ff_paper_panels.m
% PAPER PANELS — feedforward sine-wave section (Fig 4, sine-reference column).
% Individual vector PDFs in Fig-3 style, exported per session for Illustrator
% assembly. Both sessions are exported side-by-side-ready:
%   s1 = AL_0048 2026-07-01/6  (87 trials,  Kp .08, Ki .01,  Kref .075, amp 3)
%   s2 = AL_0048 2026-07-14/1  (200 trials, Kp .08, Ki 0,    Kref .05,  amp 2)
%
% Requires: load_bilateral.m has been run (`sessions` in workspace).
% Panels (per session), all vector PDF -> paper/images/figure4/:
%   4A_<mode>  4 x 4   all trials (grey) + mean (mode colour) + reference
%   4B         6 x 4   trial-avg of all 4 modes + reference          (+/- SEM)
%   4C         5 x 4   across-trial variance over time, 4 modes
%   4D         5 x 4   trial MSE half-violins, 4 modes               (+ Wilcoxon)
%   4E         5 x 4   MSE over time, 4 modes                        (+/- SEM)
%   4F         5 x 4   1 Hz gain + phase lag summary, 4 modes
%
% Row fits (total 17 cm, gap 0.3): 4x4 + 3*0.3 = 16.9 OK | 4C+4D+4E = 15.6 OK

%% ---- Knobs -------------------------------------------------------------
PANEL_SESSIONS = {'s1', 's2'};
SIDE       = 'right';
fs_img     = 35;
n_pre_s    = 1.0;      % pre-onset context (s)
REF_SIGN   = -1;       % commanded sine sign in dF/F space (right = inhibitory)
EXPORT     = true;     % PAPER PANELS -> vector PDF (see CLAUDE.md export rule)

MODE_CODES  = [2 1 3 0];
MODE_LABELS = {'OL', 'OL+prev', 'CL', 'CL+prev'};
% Red family = open loop, green family = closed loop; lighter = +preview.
MODE_COLS   = [1.00 0.00 0.00;
               1.00 0.55 0.25;
               0.00 0.50 0.00;
               0.25 0.75 0.35];
COL_TRIAL   = [0.80 0.80 0.80];
% -------------------------------------------------------------------------

PS = paperStyle();
if exist(fullfile('paper','images'), 'dir')
    paper_root = 'paper';
elseif exist(fullfile('..','paper','images'), 'dir')
    paper_root = fullfile('..','paper');
else
    paper_root = 'paper';
end
outDir = fullfile(paper_root, 'images', 'figure4');
if EXPORT && ~exist(outDir, 'dir'); mkdir(outDir); end

for si = 1:numel(PANEL_SESSIONS)
    tagS = PANEL_SESSIONS{si};
    if ~isfield(sessions, tagS); warning('%s not in sessions — skipped.', tagS); continue; end
    sess = sessions.(tagS);
    if isfield(sess,'skip') && sess.skip
        warning('%s skipped at load — no panels.', tagS); continue;
    end
    dFoF = sess.(SIDE).dFoF; sn = sess.sine;
    sfx  = sprintf('%s_%s_%d', sess.mn, sess.td, sess.en);

    n_win = round(sn.dur * fs_img);
    n_pre = round(n_pre_s * fs_img);
    t_ax  = (-n_pre : n_win) / fs_img;
    t_ref = (0 : n_win) / fs_img;
    t_post = t_ax >= 0;

    %% ---- Collect per-mode trials -------------------------------------
    nMode  = numel(MODE_CODES);
    traces = cell(1,nMode); refs = cell(1,nMode); mse = cell(1,nMode); nTr = zeros(1,nMode);
    sideMask = strcmp({sess.trial_meta.side}, SIDE);
    for m = 1:nMode
        trials = [sess.trial_meta(([sess.trial_meta.ff_cond]==MODE_CODES(m)) & sideMask).trial_idx];
        for j = 1:numel(trials)
            i0 = sess.onset_idx(trials(j));
            if isnan(i0) || i0-n_pre < 1 || i0+n_win > numel(dFoF) || i0+n_win > numel(sess.ref_raw)
                continue;
            end
            seg = dFoF(i0-n_pre : i0+n_win);
            Rj  = sn.ref0 + REF_SIGN * sess.ref_raw(i0 : i0+n_win).';
            traces{m} = [traces{m}; seg(:)'];
            refs{m}   = [refs{m};   Rj(:)'];
            mse{m}    = [mse{m}; mean((seg(n_pre+1:end).' - Rj(:)).^2)];
        end
        nTr(m) = size(traces{m},1);
    end
    refPlot = mean(cell2mat(refs(:)), 1);

    % shared y-limits across the per-mode trace panels
    allv = cell2mat(traces(:));
    ylTr = [min(allv(:)) max(allv(:))] + [-0.05 0.05]*range(allv(:));

    %% ---- 4A: per-mode trials + mean (4 x 4 each) ---------------------
    for m = 1:nMode
        f = paperFig(4,4); ax = axes(f,'Position',[0.16 0.14 0.80 0.76]); hold(ax,'on');
        plot(ax, t_ax, traces{m}.', 'Color', COL_TRIAL, 'LineWidth', PS.lw_trial);
        plot(ax, t_ax, mean(traces{m},1), 'Color', MODE_COLS(m,:), 'LineWidth', PS.lw_mean);
        plot(ax, t_ref, refPlot, 'k--', 'LineWidth', PS.lw_ref);
        hold(ax,'off'); xlim(ax,[t_ax(1) t_ax(end)]); ylim(ax, ylTr);
        title(ax, sprintf('%s (n=%d)', MODE_LABELS{m}, nTr(m)), 'FontSize',PS.fs,'FontWeight',PS.fw);
        paperAxes(ax, 'XLength',1, 'YLength',5, 'XLabel','1 s', 'YLabel','5%');
        if EXPORT
            paperExport(f, fullfile(outDir, sprintf('sine_4A_%s_%s.pdf', ...
                matlab.lang.makeValidName(MODE_LABELS{m}), sfx)));
        end
    end

    %% ---- 4B: trial-avg all modes + reference (6 x 4) -----------------
    f = paperFig(6,4); ax = axes(f,'Position',[0.13 0.14 0.84 0.76]); hold(ax,'on');
    for m = 1:nMode
        mu  = mean(traces{m},1);
        sem = std(traces{m},0,1)/sqrt(nTr(m));
        fill(ax,[t_ax fliplr(t_ax)],[mu+sem fliplr(mu-sem)], MODE_COLS(m,:), ...
            'FaceAlpha',PS.fa,'EdgeColor','none','HandleVisibility','off');
        plot(ax, t_ax, mu, 'Color', MODE_COLS(m,:), 'LineWidth', PS.lw_mean, ...
            'DisplayName', MODE_LABELS{m});
    end
    plot(ax, t_ref, refPlot, 'k--', 'LineWidth', PS.lw_ref, 'DisplayName','reference');
    hold(ax,'off'); xlim(ax,[t_ax(1) t_ax(end)]);
    lg = legend(ax,'Location','northeast'); paperLegend(lg);
    paperAxes(ax, 'XLength',1, 'YLength',2, 'XLabel','1 s', 'YLabel','2%');
    if EXPORT; paperExport(f, fullfile(outDir, sprintf('sine_4B_trialavg_%s.pdf', sfx))); end

    %% ---- 4C: across-trial variance over time (5 x 4) -----------------
    f = paperFig(5,4); ax = axes(f,'Position',[0.17 0.14 0.80 0.76]); hold(ax,'on');
    for m = 1:nMode
        plot(ax, t_ax, var(traces{m},0,1), 'Color', MODE_COLS(m,:), ...
            'LineWidth', PS.lw_mean, 'DisplayName', MODE_LABELS{m});
    end
    hold(ax,'off'); xlim(ax,[t_ax(1) t_ax(end)]);
    lg = legend(ax,'Location','northeast'); paperLegend(lg);
    text(ax,-0.13,0.5,'Variance across trials','Units','normalized','Rotation',90, ...
        'HorizontalAlignment','center','FontSize',PS.fs,'FontWeight',PS.fw,'Clipping','off');
    paperAxes(ax, 'XLength',1, 'YLength',10, 'XLabel','1 s', 'YLabel','10');
    if EXPORT; paperExport(f, fullfile(outDir, sprintf('sine_4C_variance_%s.pdf', sfx))); end

    %% ---- 4D: trial MSE half-violins (5 x 4) --------------------------
    f = paperFig(5,4); ax = axes(f,'Position',[0.17 0.16 0.80 0.74]); hold(ax,'on');
    hw = 0.32;
    for m = 1:nMode
        if nTr(m) < 2; continue; end
        [fd,yd] = ksdensity(mse{m}); fd = fd/max(fd)*hw;
        fill(ax,[m-fd, m*ones(size(fd))],[yd, fliplr(yd)], MODE_COLS(m,:), ...
            'FaceAlpha',0.5,'EdgeColor','none');
        plot(ax, m, mean(mse{m}), 'k.', 'MarkerSize',6);
    end
    hold(ax,'off'); xlim(ax,[0.5 nMode+0.5]);
    ax.XTick = 1:nMode; ax.XTickLabel = MODE_LABELS; ax.XTickLabelRotation = 30;
    ylabel(ax,'Trial MSE (\DeltaF/F)^2','FontSize',PS.fs,'FontWeight',PS.fw);
    set(ax,'Box','off','TickDir','out','FontSize',PS.fs,'FontWeight',PS.fw);
    % Wilcoxon on the two locked contrasts
    pOLCL = NaN; pCLpv = NaN;
    if nTr(1)>=2 && nTr(3)>=2; pOLCL = ranksum(mse{1}, mse{3}); end
    if nTr(3)>=2 && nTr(4)>=2; pCLpv = ranksum(mse{3}, mse{4}); end
    fprintf('[%s] 4D  OL vs CL p=%.4g | CL vs CL+prev p=%.4g\n', tagS, pOLCL, pCLpv);
    if EXPORT; paperExport(f, fullfile(outDir, sprintf('sine_4D_mse_violin_%s.pdf', sfx))); end

    %% ---- 4E: MSE over time (5 x 4) -----------------------------------
    f = paperFig(5,4); ax = axes(f,'Position',[0.17 0.14 0.80 0.76]); hold(ax,'on');
    for m = 1:nMode
        E   = (traces{m}(:, n_pre+1:end) - refs{m}).^2;
        mu  = mean(E,1); sem = std(E,0,1)/sqrt(size(E,1));
        fill(ax,[t_ref fliplr(t_ref)],[mu+sem fliplr(mu-sem)], MODE_COLS(m,:), ...
            'FaceAlpha',PS.fa,'EdgeColor','none','HandleVisibility','off');
        plot(ax, t_ref, mu, 'Color', MODE_COLS(m,:), 'LineWidth', PS.lw_mean, ...
            'DisplayName', MODE_LABELS{m});
    end
    hold(ax,'off'); xlim(ax,[0 sn.dur]);
    lg = legend(ax,'Location','northeast'); paperLegend(lg);
    text(ax,-0.13,0.5,'MSE (\DeltaF/F)^2','Units','normalized','Rotation',90, ...
        'HorizontalAlignment','center','FontSize',PS.fs,'FontWeight',PS.fw,'Clipping','off');
    paperAxes(ax, 'XLength',1, 'YLength',10, 'XLabel','1 s', 'YLabel','10');
    if EXPORT; paperExport(f, fullfile(outDir, sprintf('sine_4E_mse_time_%s.pdf', sfx))); end

    %% ---- 4F: 1 Hz gain + phase lag summary (5 x 4) -------------------
    Xf   = [ones(numel(t_ref),1), sin(2*pi*sn.hz*t_ref).', cos(2*pi*sn.hz*t_ref).'];
    fAmp = @(y) hypot([0 1 0]*(Xf\y(:)), [0 0 1]*(Xf\y(:)));
    fPh  = @(y) atan2([0 0 1]*(Xf\y(:)), [0 1 0]*(Xf\y(:)));
    gains = nan(1,nMode); lags = nan(1,nMode);
    for m = 1:nMode
        if nTr(m) < 1; continue; end
        mu = mean(traces{m}(:, n_pre+1:end),1); mr = mean(refs{m},1);
        gains(m) = fAmp(mu)/fAmp(mr);
        lg_ = mod(fPh(mr)-fPh(mu)+pi, 2*pi)-pi;
        lags(m)  = lg_/(2*pi*sn.hz)*1000;
    end
    f = paperFig(5,4); ax = axes(f,'Position',[0.17 0.16 0.66 0.74]);
    yyaxis(ax,'left');
    b = bar(ax, 1:nMode, gains, 0.6, 'FaceColor','flat', 'EdgeColor','none', 'FaceAlpha',0.75);
    b.CData = MODE_COLS;
    yline(ax, 1, 'k:', 'LineWidth', PS.lw_zero);
    ylabel(ax,'1 Hz gain','FontSize',PS.fs,'FontWeight',PS.fw);
    ax.YColor = 'k'; ylim(ax,[0 max(1.2, max(gains)*1.15)]);
    yyaxis(ax,'right');
    plot(ax, 1:nMode, lags, 'ks', 'MarkerSize',4, 'MarkerFaceColor','k', 'LineStyle','none');
    yline(ax, 0, 'k--', 'LineWidth', PS.lw_zero);
    ylabel(ax,'Phase lag (ms)','FontSize',PS.fs,'FontWeight',PS.fw); ax.YColor = 'k';
    xlim(ax,[0.5 nMode+0.5]); ax.XTick = 1:nMode; ax.XTickLabel = MODE_LABELS;
    ax.XTickLabelRotation = 30;
    set(ax,'Box','off','TickDir','out','FontSize',PS.fs,'FontWeight',PS.fw);
    title(ax,'Gain (bars) / lag (squares)','FontSize',PS.fs,'FontWeight',PS.fw);
    if EXPORT; paperExport(f, fullfile(outDir, sprintf('sine_4F_gain_phase_%s.pdf', sfx))); end

    fprintf('[%s] gains: %s | lags(ms): %s\n', tagS, mat2str(gains,3), mat2str(round(lags)));
end

fprintf('\nPanels -> %s\n', outDir);
