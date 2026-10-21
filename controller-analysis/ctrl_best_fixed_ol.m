% controller-analysis/ctrl_best_fixed_ol.m
% Review M1 (2026-10-20): offline "best fixed input" open-loop baseline for Fig 3H.
%
% The reviewer: most of the CL advantage is removal of the OL calibration offset (K_r), so compare
% CL with the best constant input, not the rough one that ran. We cannot rerun OL at another power,
% so we use the paper's own model of the trial-averaged plant: linear in the command, with an
% additive trial-to-trial disturbance. With b the OL pre-onset level (-1..0 s) and g(t) the OL trial
% average, an OL trial is y_i(t) = b + h(t) + n_i(t), h = g - b the laser effect, n_i = y_i - g.
% A fixed command c*u_OL would have given y_i'(t) = b + c*h(t) + n_i(t). c* minimises the mean
% squared error to the reference over the stimulation window (0-3 s), fitted on the SAME OL trials
% (in-sample oracle, which favours OL) and capped so c*u_OL stays at or below the 2.45 V command
% limit. Under this model across-trial variance does not depend on c, so Fig 3I is unchanged by
% recalibration; only RMSE (Fig 3H) is recomputed.
%
% Output: per-session table + CL/best and best/OL ratio stats (utils/ratio_session_stats, the
% Fig 3H scheme) -> controller-analysis/data/ctrl_best_fixed_ol.mat; PNG (not a paper panel)
% -> paper/images/review/ctrl_best_fixed_ol.png.

root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root, 'utils'));
REF  = -5;            % %dF/F, project-wide reference
UMAX = 2.45;          % V, command limit (Methods)
c0 = 36; c1 = 71; c2 = 141;                     % ncDfk cols: onset, +1 s, +3 s (35 Hz, col 1 = -1 s)
win  = {'early', c0:c1;  'late', c1+1:c2;  'full', c0:c2};
rmsw = @(M, cols) sqrt(mean((M(:, cols) - REF).^2, 2));

nS = 15;
T = table('Size', [nS 13], 'VariableTypes', [{'string','string'}, repmat({'double'}, 1, 11)], ...
    'VariableNames', {'label','mouse','nOL','nCL','uOL','cStar','capped', ...
                      'offOL','offBest','rmseOL_late','rmseBest_late','rmseCL_late','uCLrel'});
R = struct();
for w = 1:size(win,1), R.(win{w,1}) = nan(nS, 3); end     % cols: OL, best, CL mean trial RMSE
TR = struct('ol', [], 'best', [], 'cl', []);              % trial averages, for the supp example panel

for k = 1:nS
    [lab, info] = paper_session_label(sprintf('m%d', k));
    td = char(info.td);
    f  = fullfile(root, 'data', sprintf('%sctrl%s%s%d.mat', char(info.mn), td(6:7), td(9:10), info.en));
    S  = load(f, 'data');  D = S.data;
    Y  = D.ncDfk;  Yc = D.wcDfk;

    g = mean(Y, 1);  b = mean(g(1:c0-1));  h = g - b;  N = Y - g;
    tw = c0:c2;
    cStar = sum(h(tw) .* (REF - b)) / sum(h(tw).^2);
    uOL = median(max(D.ncInp, [], 2));
    capped = false;
    if uOL > 0 && cStar * uOL > UMAX, cStar = UMAX / uOL; capped = true; end
    cStar = max(cStar, 0);
    Yb = b + cStar * h + N;
    TR.ol(k,:) = g;  TR.best(k,:) = b + cStar * h;  TR.cl(k,:) = mean(Yc, 1);

    for w = 1:size(win,1)
        cols = win{w,2};
        R.(win{w,1})(k,:) = [mean(rmsw(Y, cols)), mean(rmsw(Yb, cols)), mean(rmsw(Yc, cols))];
    end
    % Mean CL command relative to the OL command over 1-3 s (ncInp/wcInp span the 3 s stimulation
    % at 2 kHz). Unitless, so it is valid for the 40 Hz-modulated early sessions and the 2026 build.
    ns = size(D.ncInp, 2);  lc = round(ns/3)+1 : ns;
    uCLrel = mean(D.wcInp(:, lc), 'all') / mean(D.ncInp(:, lc), 'all');
    T(k,:) = {string(lab), string(info.mn), size(Y,1), size(Yc,1), uOL, cStar, capped, ...
              mean(g(tw)) - REF, mean(b + cStar*h(tw)) - REF, ...
              R.late(k,1), R.late(k,2), R.late(k,3), uCLrel};
end

%% [BFO-STATS] same scheme as Fig 3H: per-session ratio, geometric mean, t-based CI, LMM (1|mouse)
mice = cellstr(T.mouse);
ST = struct();
for w = 1:size(win,1)
    X = R.(win{w,1});
    ST.(win{w,1}).cl_ol   = ratio_session_stats(X(:,3) ./ X(:,1), mice);   % reproduces Table 4
    ST.(win{w,1}).cl_best = ratio_session_stats(X(:,3) ./ X(:,2), mice);   % feedback beyond calibration
    ST.(win{w,1}).best_ol = ratio_session_stats(X(:,2) ./ X(:,1), mice);   % what recalibration alone buys
end

fprintf('\n[BFO] best fixed input: c* range %.2f-%.2f (median %.2f), capped in %d/%d sessions\n', ...
    min(T.cStar), max(T.cStar), median(T.cStar), sum(T.capped), nS);
fprintf('[BFO] mean stim-window offset from reference (%%dF/F): OL median %.2f, best-fixed median %.2f\n', ...
    median(T.offOL), median(T.offBest));
fprintf('\n%-7s %-9s %-34s %-34s %-34s\n', 'window', '', 'CL/OL (Table 4 check)', 'CL/best-fixed', 'best-fixed/OL');
for w = 1:size(win,1)
    s = ST.(win{w,1});
    p = @(x) sprintf('%.2f [%.2f %.2f] p=%.2g (%d/15<1)', x.geo, x.geoCI(1), x.geoCI(2), x.lmm_p, x.nBelow1);
    fprintf('%-7s %-9s %-34s %-34s %-34s\n', win{w,1}, '', p(s.cl_ol), p(s.cl_best), p(s.best_ol));
end
fprintf('\n[BFO] LMM t(df) CL/best: early %.2f(%.1f) late %.2f(%.1f) full %.2f(%.1f)\n', ...
    ST.early.cl_best.lmm_t, ST.early.cl_best.lmm_df, ST.late.cl_best.lmm_t, ST.late.cl_best.lmm_df, ...
    ST.full.cl_best.lmm_t, ST.full.cl_best.lmm_df);
fprintf('[BFO] one-sample t on log(CL/best): early p=%.2g late p=%.2g full p=%.2g\n', ...
    ST.early.cl_best.t_p, ST.late.cl_best.t_p, ST.full.cl_best.t_p);
% Did feedback find the best fixed input on its own? Mean CL command (1-3 s) / OL command vs c*.
[rho, prho] = corr(T.cStar, T.uCLrel, 'Type', 'Spearman');
fprintf(['[BFO] mean CL command / OL command (1-3 s): median %.2f (range %.2f-%.2f); best-fixed c*: ' ...
         'median %.2f; Spearman rho(c*, CL/OL command) = %.2f, p = %.3g; |log(uCL/c*)| median %.2f\n'], ...
    median(T.uCLrel), min(T.uCLrel), max(T.uCLrel), median(T.cStar), rho, prho, ...
    median(abs(log(T.uCLrel ./ T.cStar))));
disp(T);

save(fullfile(root, 'controller-analysis', 'data', 'ctrl_best_fixed_ol.mat'), 'T', 'R', 'ST', 'TR', 'win', 'REF', 'UMAX');

%% [BFO-FIG] per-session steady-state RMSE: OL as run, best fixed input, CL (PNG, review only)
PS = paperStyle(); setPaperDefaults();
fig = figure('Color','w','Units','centimeters','Position',[2 2 16 5.5]);
tl  = tiledlayout(fig, 1, 3, 'Padding','compact', 'TileSpacing','compact');
cOL = [0.85 0.1 0.1]; cB = [0.5 0.5 0.5]; cCL = [0 0.45 0.95];
for w = 1:size(win,1)
    nexttile; hold on
    X = R.(win{w,1});
    plot(repmat([1 2 3], nS, 1)', X', '-', 'Color', [0.75 0.75 0.75], 'LineWidth', 0.4);
    scatter(ones(nS,1), X(:,1), 10, cOL, 'filled');
    scatter(2*ones(nS,1), X(:,2), 10, cB, 'filled');
    scatter(3*ones(nS,1), X(:,3), 10, cCL, 'filled');
    s = ST.(win{w,1}).cl_best;
    title(sprintf('%s: CL/best %.2f [%.2f %.2f]', win{w,1}, s.geo, s.geoCI(1), s.geoCI(2)), 'FontWeight','bold');
    set(gca, 'XTick', 1:3, 'XTickLabel', {'OL as run','best fixed','CL'}, 'XLim', [0.5 3.5]);
    ylabel('mean trial RMSE (%\DeltaF/F)'); box off
end
title(tl, 'M1: CL vs best fixed OL input (in-sample c^*)', 'FontWeight','bold');
outDir = fullfile(root, 'paper', 'images', 'review');
if ~exist(outDir, 'dir'), mkdir(outDir); end
exportgraphics(fig, fullfile(outDir, 'ctrl_best_fixed_ol.png'), 'Resolution', 300);
fprintf('[BFO] figure -> %s\n', fullfile(outDir, 'ctrl_best_fixed_ol.png'));

%% [BFO-SUPP] supplementary figure (user 2026-10-20: "make the figure into supplementary panel figure")
% Four panels, paper style, PDF via paperExport (mirrored into figures_final/panels/supp_best_fixed
% when PAPER_FINAL is on and the basename is in MANIFEST.txt):
%   A supp_bfo_example      the session with the median c* (1d): OL as run, best fixed input (model), CL.
%                           Not the Fig 3 example 2a: its OL was already near the reference (c* = 1.05).
%   B supp_bfo_rmse_early   per-session mean trial RMSE 0-1 s: OL as run / best fixed / CL
%   C supp_bfo_rmse_late    same, 1-3 s (B and C share one y-range)
%   D supp_bfo_command      mean CL command (1-3 s) vs best fixed input, both relative to the OL command
cB = [0.5 0.5 0.5];  sd = fullfile(root, 'paper', 'images', 'supplementary');
styl = @(ax) set(ax, 'FontSize', PS.fs, 'FontWeight', PS.fw, 'TickDir', 'out', 'Box', 'off', ...
    'LineWidth', 0.5, 'Color', 'none');

% A: example session, laser command (user 2026-10-20: inputs, not trial-averaged dF/F, which
% confuses the reader). Command amplitude = 40 ms moving peak, so the 40 Hz-modulated early
% sessions show their drive level; it is the raw command for the unmodulated 2026 build.
[~, kx] = min(abs(T.cStar - median(T.cStar)));
[~, info] = paper_session_label(sprintf('m%d', kx));  td = char(info.td);
S = load(fullfile(root, 'data', sprintf('%sctrl%s%s%d.mat', char(info.mn), td(6:7), td(9:10), info.en)), 'data');
dsU = 20;  fsU = 2000;                                      % ncInp/wcInp at 2 kHz; plot every 10 ms
eOL = movmax(S.data.ncInp, 80, 2);  eCL = movmax(S.data.wcInp, 80, 2);
eOL = eOL(:, 1:dsU:end);  eCL = eCL(:, 1:dsU:end);
tu = (0:size(eOL, 2) - 1) * dsU / fsU;
uO = median(eOL, 1);  mC = mean(eCL, 1);  sC = std(eCL, 0, 1);
fA = paperFig(4.0, 3.4);
ax = axes(fA, 'Position', [0.20 0.24 0.76 0.52]); hold(ax, 'on');
fill(ax, [tu fliplr(tu)], [mC - sC, fliplr(mC + sC)], PS.col_cl, 'FaceAlpha', PS.fa, 'EdgeColor', 'none');
hA = [plot(ax, tu, uO,               '-', 'Color', PS.col_ol, 'LineWidth', PS.lw_mean), ...
      plot(ax, tu, T.cStar(kx) * uO, '-', 'Color', cB,        'LineWidth', PS.lw_mean), ...
      plot(ax, tu, mC,               '-', 'Color', PS.col_cl, 'LineWidth', PS.lw_mean)];
set(ax, 'XLim', [0 3], 'XTick', 0:3, 'YLim', [0 3]);
styl(ax);
xlabel(ax, 'Time from onset (s)', 'FontWeight', PS.fw);
ylabel(ax, 'Command (V)', 'FontWeight', PS.fw);
lg = legend(ax, hA, {'OL as run', 'Best fixed', 'CL'}, 'Location', 'northoutside', ...
    'Orientation', 'horizontal', 'Color', 'none');
paperLegend(lg);
title(ax, T.label(kx), 'FontSize', PS.fs, 'FontWeight', PS.fw);
paperExport(fA, fullfile(sd, 'supp_bfo_example.pdf'));
fprintf('[BFO-SUPP] A: %s command OL %.2f V, best fixed %.2f V, CL mean over 1-3 s %.2f V\n', ...
    T.label(kx), median(uO), T.cStar(kx) * median(uO), mean(mC(tu >= 1)));

% B, C: per-session RMSE, three inputs
yTop = 1.05 * max([R.early(:); R.late(:)]);
wl = {'early', '0-1 s'; 'late', '1-3 s'};
for w = 1:2
    X = R.(wl{w,1});  s = ST.(wl{w,1}).cl_best;
    fW = paperFig(4.0, 3.4);
    ax = axes(fW, 'Position', [0.20 0.15 0.76 0.66]); hold(ax, 'on');
    plot(ax, repmat([1 2 3], nS, 1)', X', '-', 'Color', [0.75 0.75 0.75], 'LineWidth', PS.lw_trial);
    scatter(ax, ones(nS,1),   X(:,1), 6, PS.col_ol, 'filled');
    scatter(ax, 2*ones(nS,1), X(:,2), 6, cB,        'filled');
    scatter(ax, 3*ones(nS,1), X(:,3), 6, PS.col_cl, 'filled');
    set(ax, 'XTick', 1:3, 'XTickLabel', {'OL', 'Best', 'CL'}, 'XLim', [0.6 3.4], 'YLim', [0 yTop]);
    styl(ax);
    ylabel(ax, 'Trial RMSE (% \DeltaF/F)', 'FontWeight', PS.fw);
    title(ax, {wl{w,2}, sprintf('CL/best %.2f [%.2f, %.2f]', s.geo, s.geoCI(1), s.geoCI(2))}, ...
        'FontSize', PS.fs, 'FontWeight', PS.fw);
    paperExport(fW, fullfile(sd, sprintf('supp_bfo_rmse_%s.pdf', wl{w,1})));
end

% D: did feedback find the best fixed input? Open markers = c* capped at the command limit.
fD = paperFig(4.0, 3.4);
ax = axes(fD, 'Position', [0.22 0.22 0.70 0.60]); hold(ax, 'on');
lim = [0.5 2];
plot(ax, lim, lim, ':', 'Color', [0.3 0.3 0.3], 'LineWidth', PS.lw_ref);
cp = logical(T.capped);
scatter(ax, T.cStar(~cp), T.uCLrel(~cp), 8, PS.col_cl, 'filled');
scatter(ax, T.cStar(cp),  T.uCLrel(cp),  8, PS.col_cl, 'LineWidth', 0.5);
set(ax, 'XLim', lim, 'YLim', lim, 'XTick', [0.5 1 1.5 2], 'YTick', [0.5 1 1.5 2]);
axis(ax, 'square'); styl(ax);
xlabel(ax, 'Best fixed / OL input', 'FontWeight', PS.fw);
ylabel(ax, 'CL / OL command', 'FontWeight', PS.fw);
title(ax, ['\rho = ' sprintf('%.2f, p = %.3f', rho, prho)], 'FontSize', PS.fs, 'FontWeight', PS.fw);
paperExport(fD, fullfile(sd, 'supp_bfo_command.pdf'));
fprintf('[BFO-SUPP] D axis range check: c* %.2f-%.2f, CL command %.2f-%.2f (axes %.1f-%.1f)\n', ...
    min(T.cStar), max(T.cStar), min(T.uCLrel), max(T.uCLrel), lim);
