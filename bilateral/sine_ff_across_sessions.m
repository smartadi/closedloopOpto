% bilateral/sine_ff_across_sessions.m
% Cross-session summary of the feedforward sine sessions (s1/s2/s3): three
% point-plots, each with the 4 modes on x and ONE point per session per mode.
%   sine_combined_rmse.pdf      – total RMSE over the stim window (% dF/F)
%   sine_combined_variance.pdf  – total across-trial variance over the window
%   sine_combined_phase.pdf     – 1 Hz phase lag (deg)
% Requires: load_bilateral.m has run (`sessions` with s1/s2/s3).
%
% n=3 sessions -> NO across-session significance test (Wilcoxon signed-rank
% cannot reach p<0.25 at n=3). These panels show DIRECTION + CONSISTENCY:
% each session is a point, paired across modes by a faint line; the bold bar
% is the across-session mean. Report within-session stats separately (5G).
% Metric definitions match sine_ff_plots_combined.m (raw dF/F vs sine ref,
% stim window 0..dur).

SESS_TAGS = {'s1','s2','s3'};
SIDE      = 'right';
fs        = 35;
EXPORT    = true;

MODE_CODES  = [2 1 3 0];
MODE_SHORT  = {'OL','OL+p','CL','CL+p'};
MODE_COLS   = [1.00 0.00 0.00;    % OL       red
               1.00 0.55 0.25;    % OL+prev  orange
               0.00 0.40 0.85;    % CL       blue
               0.00 0.50 0.00];   % CL+prev  green
SESS_MARK   = {'o','^','s'};      % one marker per session
nS = numel(SESS_TAGS); nMode = numel(MODE_CODES);

PS = paperStyle(); setPaperDefaults();
if exist(fullfile('paper','images','figure5'),'dir'); outDir=fullfile('paper','images','figure5');
elseif exist(fullfile('..','paper','images','figure5'),'dir'); outDir=fullfile('..','paper','images','figure5');
else; outDir='.'; end

%% ---- Gather per-(session,mode) metrics ---------------------------------
RMSE = nan(nS,nMode); VARr = nan(nS,nMode); LAG = nan(nS,nMode); NT = nan(nS,nMode);
for si = 1:nS
    s = sessions.(SESS_TAGS{si});
    dur = s.sine.dur; nPre = round(2*fs); nR = round(dur*fs);
    Tref = (0:nR)/fs;
    Xf = [ones(numel(Tref),1), sin(2*pi*s.sine.hz*Tref).', cos(2*pi*s.sine.hz*Tref).'];
    fPh = @(y) atan2([0 0 1]*(Xf\y(:)), [0 1 0]*(Xf\y(:)));
    sideMask = strcmp({s.trial_meta.side}, SIDE);
    dF = s.(SIDE).dFoF(:).'; rr = s.ref_raw(:).';
    for m = 1:nMode
        tr = [s.trial_meta(([s.trial_meta.ff_cond]==MODE_CODES(m)) & sideMask).trial_idx];
        T = []; R = [];
        for j = 1:numel(tr)
            i0 = s.onset_idx(tr(j));
            if isnan(i0) || i0-nPre<1 || i0+nR>numel(dF) || i0+nR>numel(rr); continue; end
            T = [T; dF(i0:i0+nR)];  R = [R; s.sine.ref0 - rr(i0:i0+nR)];
        end
        NT(si,m) = size(T,1);
        if isempty(T); continue; end
        RMSE(si,m) = mean(sqrt(mean((T-R).^2, 2)));
        VARr(si,m) = mean(var(T, 0, 1));
        LAG(si,m)  = (mod(fPh(mean(R,1)) - fPh(mean(T,1)) + pi, 2*pi) - pi) * 180/pi;
    end
    fprintf('%s n/mode=%s\n', SESS_TAGS{si}, mat2str(NT(si,:)));
end

%% ---- Draw one point-plot per metric -----------------------------------
metrics = {RMSE, VARr, LAG};
ylabs   = {'Trial RMSE (% dF/F)', 'Across-trial variance', 'Phase lag (\circ)'};
fnames  = {'sine_combined_rmse.pdf', 'sine_combined_variance.pdf', 'sine_combined_phase.pdf'};
jit = linspace(-0.14, 0.14, nS);

for p = 1:3
    M = metrics{p};
    fig = paperFig(5.5, 4.5);
    lm=0.20; rm=0.04; bm=0.16; tm=0.06;
    ax = axes(fig, 'Position', [lm bm 1-lm-rm 1-bm-tm]); hold(ax,'on');

    if p == 3   % phase panel: zero reference line
        yline(ax, 0, 'k-', 'LineWidth', PS.lw_zero, 'HandleVisibility','off');
    end

    % faint paired lines: each session across the 4 modes
    for si = 1:nS
        plot(ax, (1:nMode)+jit(si), M(si,:), '-', 'Color', [0.6 0.6 0.6 0.45], ...
            'LineWidth', 0.5, 'HandleVisibility','off');
    end
    % session points, coloured by mode, marker by session
    hS = gobjects(1,nS);
    for si = 1:nS
        for m = 1:nMode
            h = plot(ax, m+jit(si), M(si,m), SESS_MARK{si}, 'MarkerSize', 4, ...
                'MarkerFaceColor', MODE_COLS(m,:), 'MarkerEdgeColor', 'none');
            if m==1; hS(si)=h; end
        end
    end
    % across-session mean bar per mode
    for m = 1:nMode
        plot(ax, [m-0.22 m+0.22], mean(M(:,m),'omitnan')*[1 1], 'k-', ...
            'LineWidth', 1.5, 'HandleVisibility','off');
    end

    xlim(ax, [0.5 nMode+0.5]);
    ax.XTick = 1:nMode; ax.XTickLabel = MODE_SHORT; ax.XTickLabelRotation = 30;
    ylabel(ax, ylabs{p}, 'FontSize', PS.fs, 'FontWeight', PS.fw);
    set(ax, 'Box','off', 'TickDir','out', 'FontSize', PS.fs, 'FontWeight', PS.fw);
    lg = legend(hS, SESS_TAGS, 'Location','best'); paperLegend(lg);
    if EXPORT; paperExport(fig, fullfile(outDir, fnames{p})); end
end

fprintf('\n=== across-session summary (rows s1/s2/s3, cols OL/OL+p/CL/CL+p) ===\n');
fprintf('RMSE:\n');     disp(RMSE);
fprintf('VARIANCE:\n'); disp(VARr);
fprintf('PHASE(deg):\n');disp(LAG);
