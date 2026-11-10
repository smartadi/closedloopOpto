function sine_panels(sess)
%SINE_PANELS  Poster copy of Fig 5's sine panels for SfN box 4, with three conditions: OL, CL, CL + preview.
%   Aditya 2026-11-05: show open loop, closed loop and CL + preview only (OL + preview dropped).
%   Same session, signal, trial selection and definitions as bilateral/sine_ff_plots_combined.m (Fig 5 primary,
%   s2 = AL_0048 2026-07-14/1, the rig's 40 s trailing dF/F from sine_rig_dff), and the same styles
%   (paperStyle + the jnAxesAll pass that the final panels get). The paper panels are not touched.
%   sess: sessions.s2 from load_bilateral.m, or omitted to load its cache, data/AL_0048_bil_07141.mat (3.3 GB).
% OUT  poster/sfn2026/panels/sine3_{avg,var,rmse,lag}_raw.pdf (git-ignored); panel_swap.py crops each to ink.
here = fileparts(mfilename('fullpath')); root = fullfile(here, '..', '..');
addpath(fullfile(root, 'utils')); addpath(fullfile(root, 'bilateral'));
if nargin < 1
    tmp = load(fullfile(root, 'data', 'AL_0048_bil_07141.mat'), 'sess'); sess = tmp.sess;
end
assert(strcmp(sess.td, '2026-07-14') && sess.en == 1, 'expects Fig 5''s primary session, AL_0048 2026-07-14/1');
out = fullfile(here, 'panels');
PS = paperStyle(); setPaperDefaults(); close all

SIDE = 'right'; PRE = 2; POST = 2; W_BASE = 1400;
d = sess.d; dFoF = sine_rig_dff(sess); sn = sess.sine; fs = 35; dur = sn.dur;
MODE_CODES  = [2 3 0];                                  % ff_cond: 2 = OL, 3 = CL, 0 = CL + preview
MODE_LABELS = {'Open loop', 'Closed loop', 'CL + preview'};
MODE_SHORT  = {'OL', 'CL', 'CL+p'};
MODE_COLS   = [1.00 0.00 0.00; 0.00 0.40 0.85; 0.00 0.50 0.00];   % locked OL red, CL blue, CL+p green
nMode = numel(MODE_CODES);
nPre = round(PRE*fs); nPost = round((dur+POST)*fs);
T = (-nPre:nPost) / fs; Tref = (0:round(dur*fs)) / fs; x1 = 0; x2 = dur;

% ---- gather, as sine_ff_plots_combined.m
traces = cell(1,nMode); refs = cell(1,nMode); rmseV = cell(1,nMode); nTr = zeros(1,nMode);
sideMask = strcmp({sess.trial_meta.side}, SIDE);
for m = 1:nMode
    trials = [sess.trial_meta(([sess.trial_meta.ff_cond]==MODE_CODES(m)) & sideMask).trial_idx];
    for j = 1:numel(trials)
        i0 = sess.onset_idx(trials(j));
        if isnan(i0) || i0-nPre <= W_BASE || i0+nPost > numel(dFoF); continue; end
        if i0+round(dur*fs) > numel(sess.ref_raw); continue; end
        traces{m} = [traces{m}; dFoF(i0-nPre : i0+nPost)];
        Rj = -sess.ref_raw(i0 : i0+round(dur*fs)).';
        refs{m} = [refs{m}; Rj(:)'];
        seg = dFoF(i0 : i0+round(dur*fs));
        rmseV{m} = [rmseV{m}; sqrt(mean((seg(:) - Rj(:)).^2))];
    end
    nTr(m) = size(traces{m},1);
end
refPlot = mean(cell2mat(refs(:)), 1);

% ---- trials + average, one column per condition (Fig 5C)
PW = 12.5; lm = 0.05; rm = 0.01; cg = 0.03;
cW = (1 - lm - rm - (nMode-1)*cg) / nMode; cL = lm + (0:nMode-1)*(cW + cg);
fig = paperFig(PW, 3.36); bm = 0.12; tm = 0.12; axH = 1 - bm - tm;   % 3.36: ink no taller than the panel it replaces
axB = gobjects(1,nMode);
for m = 1:nMode
    axB(m) = axes(fig, 'Position', [cL(m), bm, cW, axH]); hold(axB(m),'on');
    plot(axB(m), T, zeros(size(T)), 'k', 'LineWidth', PS.lw_zero, 'HandleVisibility','off');
    mu = mean(traces{m},1); sd = std(traces{m},0,1);
    fill(axB(m), [T fliplr(T)], [mu+sd fliplr(mu-sd)], MODE_COLS(m,:), 'FaceAlpha', PS.fa, 'EdgeColor','none');
    h1 = plot(axB(m), T, mu, 'Color', MODE_COLS(m,:), 'LineWidth', PS.lw_mean);
    h2 = plot(axB(m), Tref, refPlot, '--k', 'LineWidth', PS.lw_ref);
    xline(axB(m), 0); xline(axB(m), dur);
    ylim(axB(m), [-8 6]); xlim(axB(m), [-PRE dur+POST]);
    addStimPatch(axB(m), x1, x2);
    uistack(findobj(axB(m),'Type','line'), 'top'); hold(axB(m),'off');
    if m == 1
        paperAxes(axB(m), 'XLength',1, 'YLength',2, 'XLabel','1 s', 'YLabel','2% dF/F');
        hLeg = [h1 h2];
    else
        paperAxes(axB(m));
    end
    text(axB(m), 0.5, 1.06, sprintf('%s (n=%d)', MODE_LABELS{m}, nTr(m)), 'Units','normalized', ...
        'HorizontalAlignment','center', 'Clipping','off');
end
lgd = legend(axB(1), hLeg, {'mean \pm std','Target'}, 'Orientation','horizontal');
paperLegend(lgd); lgd.Units = 'normalized'; lgd.Position(2) = 0.01; lgd.Position(1) = 0.5 - lgd.Position(3)/2;
linkaxes(axB,'x');
export(fig, fullfile(out, 'sine3_avg_raw.pdf'));

% ---- variance across trials over time (Fig 5E)
fig = paperFig(5.2, 3.4);
ax = axes(fig, 'Position', [0.13, 0.12, 0.82, 0.80]); hold(ax,'on');
for m = 1:nMode, plot(ax, T, var(traces{m},0,1), 'Color', MODE_COLS(m,:), 'LineWidth', PS.lw_mean); end
xline(ax, 0, 'LineWidth', PS.lw_zero); xline(ax, dur, 'LineWidth', PS.lw_zero);
xlim(ax, [-PRE dur+POST]); addStimPatch(ax, x1, x2);
uistack(findobj(ax,'Type','line'), 'top'); hold(ax,'off');
paperAxes(ax, 'XLength',1, 'YLength',0, 'XLabel','1 s');
text(ax, -0.12, 0.5, 'Variance across trials', 'Units','normalized', 'Rotation',90, ...
    'HorizontalAlignment','center', 'VerticalAlignment','middle', 'Color','k', 'Clipping','off');
export(fig, fullfile(out, 'sine3_var_raw.pdf'));

% ---- trial RMSE, log axis, half-violin + every trial + median/IQR (Fig 5G)
allRmse = cell2mat(rmseV(:)); yLo = 0.85*min(allRmse); yHi = 1.15*max(allRmse);
fig = paperFig(3.6, 3.4);
ax = axes(fig, 'Position', [0.24, 0.15, 0.71, 0.75]); hold(ax,'on'); set(ax, 'YScale','log');
hw = 0.34; rng(0,'twister');
for m = 1:nMode
    L = log10(rmseV{m});
    [fk, yk] = ksdensity(L, 'Support', [log10(yLo) log10(yHi)], 'BoundaryCorrection','reflection');
    fk = fk/max(fk)*hw;
    fill(ax, [m-fk, m*ones(size(fk))], 10.^[yk, fliplr(yk)], MODE_COLS(m,:), 'FaceAlpha', PS.fa, 'EdgeColor','none');
    jit = (rand(size(rmseV{m}))-0.5)*0.16;
    plot(ax, m+0.14+jit, rmseV{m}, 'o', 'MarkerSize', 1.2, 'MarkerFaceColor', MODE_COLS(m,:), 'MarkerEdgeColor','none');
    q = prctile(rmseV{m}, [25 50 75]);
    plot(ax, [m+0.28 m+0.28], q([1 3]), '-', 'Color', MODE_COLS(m,:), 'LineWidth', 1.0);
    plot(ax, m+0.28+[-0.07 0.07], q(2)*[1 1], '-', 'Color', MODE_COLS(m,:), 'LineWidth', 1.5);
end
xlim(ax, [0.4 nMode+0.7]); ylim(ax, [yLo yHi]);
cleanAxes(ax);
set(ax, 'YColor','k', 'YTick', [1 2 5 10 20], 'YTickLabel', {'1','2','5','10','20'}, 'YMinorTick','off', ...
    'TickDir','out', 'FontSize',PS.fs, 'FontWeight',PS.fw);
ax.YAxis.MinorTickValues = [];
text(ax, -0.24, 0.5, 'Trial RMSE (% \DeltaF/F)', 'Units','normalized', 'Rotation',90, 'HorizontalAlignment','center', ...
    'VerticalAlignment','middle', 'Color','k', 'FontSize',PS.fs, 'FontWeight',PS.fw, 'Clipping','off');
for m = 1:nMode
    text(ax, m, yLo, MODE_SHORT{m}, 'HorizontalAlignment','center', 'VerticalAlignment','top', ...
        'FontSize',PS.fs, 'FontWeight',PS.fw, 'Clipping','off');
end
hold(ax,'off');
export(fig, fullfile(out, 'sine3_rmse_raw.pdf'));

% ---- phase lag of the 1 Hz fundamental, mean response vs mean target (Fig 5H)
Xf = [ones(numel(Tref),1), sin(2*pi*sn.hz*Tref).', cos(2*pi*sn.hz*Tref).'];
fAmp = @(y) hypot([0 1 0]*(Xf\y(:)), [0 0 1]*(Xf\y(:)));
fPh  = @(y) atan2([0 0 1]*(Xf\y(:)), [0 1 0]*(Xf\y(:)));
iRef = (nPre+1):(nPre+1+round(dur*fs)); lags = nan(1,nMode); gains = nan(1,nMode);
for m = 1:nMode
    mu = mean(traces{m}(:, iRef),1); mr = mean(refs{m},1);
    lags(m) = (mod(fPh(mr)-fPh(mu)+pi, 2*pi)-pi) * 180/pi; gains(m) = fAmp(mu)/fAmp(mr);
end
prevLook = 360 * sn.hz * sess.d.input_params(find([sess.trial_meta.ff_cond]>=0,1), 8) / fs;
fig = paperFig(3.6, 3.4);
ax = axes(fig, 'Position', [0.32, 0.20, 0.63, 0.72]); hold(ax,'on');
for m = 1:nMode, bar(ax, m, lags(m), 0.6, 'FaceColor', MODE_COLS(m,:), 'FaceAlpha', 0.75, 'EdgeColor','none'); end
yline(ax, 0, 'k-', 'LineWidth', PS.lw_zero);
yline(ax, prevLook, '--', 'Color', [0.5 0.5 0.5], 'LineWidth', PS.lw_ref);
text(ax, nMode+0.55, prevLook, sprintf('preview %.0f\\circ', prevLook), 'Color', [0.5 0.5 0.5], ...
    'HorizontalAlignment','right', 'VerticalAlignment','bottom', 'FontSize', PS.fs, 'Clipping','off');
hold(ax,'off'); xlim(ax, [0.4 nMode+0.6]);
ax.XTick = 1:nMode; ax.XTickLabel = MODE_SHORT; ax.XTickLabelRotation = 30;
ylabel(ax, 'Phase lag (\circ)', 'FontSize', PS.fs, 'FontWeight', PS.fw);
set(ax, 'Box','off', 'TickDir','out', 'FontSize', PS.fs, 'FontWeight', PS.fw);
export(fig, fullfile(out, 'sine3_lag_raw.pdf'));

fprintf('[SINE3] %s %s/%d, n per mode %s | preview lookahead %.0f deg\n', sess.mn, sess.td, sess.en, mat2str(nTr), prevLook);
for m = 1:nMode
    fprintf('  %-5s median RMSE %.2f | lag %5.1f deg | gain %.2f | across-trial var 0-%g s mean %.2f\n', MODE_SHORT{m}, ...
        median(rmseV{m}), lags(m), gains(m), dur, mean(var(traces{m}(:, iRef), 0, 1)));
end
end

function export(fig, path)
% the final panels' rule-book typography pass, then the vector export every panel uses.
% 2026-11-10: then the poster type standard (poster_type.m) and a second print, panels/poster/sine_<x>_raw.pdf,
% on the figure's own page (print -vector; exportgraphics rescales small panels). poster_fix() holds what a
% size change alone can't do.
% Then poster_lab_axes (the lab's axis style, Aditya's pick 2026-11-10).
jnAxesAll(fig);
exportgraphics(fig, path, 'ContentType', 'vector');
[d, n] = fileparts(path); n = strrep(erase(n, '_raw'), 'sine3_', '');
poster_type(fig); poster_fix(fig, n); poster_lab_axes(fig); drawnow;
fig.Units = 'centimeters'; cm = fig.Position(3:4);
if isappdata(fig, 'canvas')        % a resized canvas sometimes springs back (3.00 -> 3.41 cm): set it again, check
    cm = getappdata(fig, 'canvas'); fig.Position(3:4) = cm; drawnow;
    assert(all(abs(fig.Position(3:4) - cm) < 0.02), 'sine %s: canvas %.2f x %.2f cm', n, fig.Position(3:4));
end
set(fig, 'PaperUnits', 'centimeters', 'PaperSize', cm, 'PaperPosition', [0 0 cm]);
if ~isfolder(fullfile(d, 'poster')), mkdir(fullfile(d, 'poster')); end
sls_check(fig, 'MinFontPt', 7, 'Ignore', {'spine', 'space'});
print(fig, fullfile(d, 'poster', ['sine_' n '_raw.pdf']), '-dpdf', '-vector');
close(fig);
end

function poster_fix(fig, n)
% Poster-only layout fixes after poster_type (box 4). Layout ideas (Aditya 2026-11-10, from a lab-style
% Fig 3): no dark lines at target on/off, the grey band marks it; column titles left-aligned in the
% condition colours; the variance panel gets a y axis in %^2 (it had no scale), time keeps its 1 s bar.
delete(findall(fig, 'Type', 'constantline'));
cols = {'Open loop', [1.00 0.00 0.00]; 'Closed loop', [0.00 0.40 0.85]; 'CL + preview', [0.00 0.50 0.00]};
switch n
    case 'avg'
        for t = findall(fig, 'Type', 'text').'
            s = strjoin(cellstr(t.String), '');
            k = find(cellfun(@(c) startsWith(s, c), cols(:, 1)), 1);   % startsWith(s, list) is one logical: always picked red
            if ~isempty(k), set(t, 'Color', cols{k, 2}, 'Position', [0 1.06 0], 'HorizontalAlignment', 'left'); end
        end
    case 'var'                                                      % rig dF/F is in %, so its variance is in %^2
        ax = findall(fig, 'Type', 'axes'); ax = ax(1);
        delete(findall(ax, 'Type', 'text', 'String', 'Variance across trials'));
        set(ax, 'Visible', 'on', 'Color', 'none', 'Box', 'off', 'YTickMode', 'auto', 'YTickLabelMode', 'auto', 'YColor', 'k');
        ax.XAxis.Visible = 'off';
        ylabel(ax, {'Across-trial', ['variance (%' char(178) ')']}, 'FontSize', 7.5, 'Visible', 'on');   % two lines: one line made the panel too tall for its slot
        % room on the left for ticks + label, and no taller than the slot it replaces (3.57 in = 3.05 cm printed)
        fig.Units = 'centimeters'; fig.Position(4) = 3.0; W = fig.Position(3); setappdata(fig, 'canvas', [W 3.0]);
        ax.Units = 'centimeters'; ax.Position = [1.55 0.5 W - 1.65 2.3];
        % the 1 s bar sat on the corner, where it now reads as part of the y axis: move it to the right end
        bar = findall(ax, 'Type', 'line', '-function', @(h) numel(h.XData) == 2 && diff(h.YData) == 0 ...
            && abs(diff(h.XData) - 1) < 1e-9);
        sb = findall(ax, 'Type', 'text', 'String', '1 s');
        dx = ax.XLim(2) - max(bar.XData);
        bar.XData = bar.XData + dx;
        set(sb, 'VerticalAlignment', 'top', 'Position', [sb.Position(1) + dx, bar.YData(1) - 0.05 * diff(ax.YLim), 0]);
    case 'rmse'
        set(findall(fig, 'Type', 'text', 'String', 'Trial RMSE (% \DeltaF/F)'), 'String', 'Per-trial RMSE (%)');   % window = the whole 4 s sine
    case 'lag'                                                      % rotated ticks need not be: 3 short names
        ax = findall(fig, 'Type', 'axes'); ax(1).XTickLabelRotation = 0;
end
end
