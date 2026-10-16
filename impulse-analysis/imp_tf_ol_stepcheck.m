%% imp_tf_ol_stepcheck.m -- EXPLORATORY: does sustained OL stimulation relax the way the impulse LTI models predict?
%
% Read-only on every paper pipeline. Reads the controller caches (data/<mn>ctrl<mmdd><en>.mat, variable
% `data` only -- `d` holds the multi-GB SVD and is never loaded) and the two impulse TF caches.
%
% The question (ALT_WINDOW_DECISION.md, "how much does each mode matter"): the impulse data under LTI
% predict that a sustained input's suppression peaks at ~0.2 s and relaxes 59-117 % within 1 s (the
% rebound's area offsets the dip's). The planned Results sentence says the rebound is a slow drift
% that the PI integral removes. Open-loop controller trials apply a ~constant laser command for 3 s
% with no feedback, so they test this directly.
%
% Per session: trial-averaged OL dF/F (pncDfk, -10..+6 s; baseline = mean over -1..0 s), the mean OL
% command (ncInp, 2 kHz -> 35 Hz bins), and
%   peak suppression (min of the 3-sample-smoothed trace over 0-3 s) and its time,
%   relaxation by 1 s and by 3 s = (y(t) - peak)/|peak|, y(t) = mean over a 0.2 s bin ending at t,
%   offset overshoot = max over 3-4.5 s, % of |peak| (positive = above baseline).
% Prediction: the session's mean OL command pushed through an impulse TF (lsim, ZOH, 35 Hz; h is per
% sample, so a held command sums h exactly as the data would). Mouse 1 (AL_0033) uses the impulse fits
% of AL_0033 2025-01-29 (both caches); Mouse 3 (AL_0048) uses AL_0048's, with a unit step because its
% OL command is not in the cache (reads ~0 V; newbuild channel). Mice without impulse fits (AL_0039,
% AL_0051) are compared with the range of all four impulse models' step predictions (shape only).
% Output: paper/images/figure3/alt_step_check/ol_step_vs_impulse.png (+ the console table).

here = fileparts(mfilename('fullpath'));  root = fileparts(here);
addpath(fullfile(root,'utils'));
outDir = fullfile(root,'paper','images','figure3','alt_step_check');
if ~exist(outDir,'dir'), mkdir(outDir); end
fs = 35;  Ts = 1/fs;  PS = paperStyle();
FITS = {'current 0-0.5 s', fullfile(here,'data','imp_tf_fits.mat');
        'alt -0.5..1.0 s', fullfile(here,'data','imp_tf_fits_win_m0p5_1p0.mat')};
F = cell(2,1);  for q = 1:2, L = load(FITS{q,2}); F{q} = L.Sprim; end
impMn = cellfun(@(s) s.mn, F{1}, 'UniformOutput', false);      % AL_0041 AL_0041 AL_0033 AL_0048

files = dir(fullfile(root,'data','*ctrl*.mat'));
R = struct([]);
for i = 1:numel(files)
    L = load(fullfile(files(i).folder, files(i).name), 'data');  D = L.data;  clear L
    mn  = files(i).name(1:7);
    dur = (size(D.ncInp,2) - 1) / 2000;
    nT  = size(D.pncDfk, 2);  t = ((0:nT-1) - 350) / fs;             % pncDfk = i-350 : i+35*(dur+3)
    y   = mean(double(D.pncDfk), 1, 'omitnan');
    y   = y - mean(y(t >= -1 & t < 0));
    % command at 35 Hz: mean of each frame's 2 kHz samples, zero outside the trial
    uk  = mean(double(D.ncInp), 1);  nF = floor(numel(uk) / (2000/fs));
    u35 = arrayfun(@(k) mean(uk(round((k-1)*2000/fs)+1 : round(k*2000/fs))), 1:nF);
    u   = zeros(size(t));  i0 = find(t >= 0, 1);  u(i0:i0+nF-1) = u35;
    cmdKnown = mean(u35) > 0.05;
    m = i_metrics(y, t, dur);
    r = struct('file',files(i).name,'mn',mn,'nOL',size(D.ncDfk,1),'t',t,'y',y,'u',u, ...
               'cmd',mean(u35),'cmdKnown',cmdKnown,'m',m,'pred',[]);
    % ---- predictions -------------------------------------------------------------------------
    k = find(strcmp(impMn, mn), 1);
    uP = u;  if ~cmdKnown, uP = double(t >= 0 & t < dur); end         % unit step when cmd unknown
    for q = 1:2
        if ~isempty(k)
            yp = lsim(F{q}{k}.sys, uP(:), t(:) - t(1), 'zoh').';
            yp = yp - mean(yp(t >= -1 & t < 0));
            r.pred(q).set = FITS{q,1};  r.pred(q).y = yp;  r.pred(q).m = i_metrics(yp, t, dur);
        else
            % no impulse fit for this mouse: band of all four models' unit-step shapes
            Y = nan(numel(F{q}), numel(t));
            for kk = 1:numel(F{q})
                yp = lsim(F{q}{kk}.sys, double(t(:) >= 0 & t(:) < dur), t(:) - t(1), 'zoh').';
                Y(kk,:) = yp / abs(min(yp(t >= 0 & t <= 3)));
            end
            r.pred(q).set = FITS{q,1};  r.pred(q).Y = Y;  r.pred(q).y = [];
            r.pred(q).m = arrayfun(@(kk) i_metrics(Y(kk,:), t, dur), 1:size(Y,1));
        end
    end
    R = [R r];                                                           %#ok<AGROW>
end

% ---- table -----------------------------------------------------------------------------------------
fprintf('\n============ OPEN-LOOP SUSTAINED STIM (3 s) vs IMPULSE-MODEL PREDICTION ============\n');
fprintf('%-22s %4s %6s | measured: peak (%%dF/F) @ s, relax 1 s / 3 s, offset overshoot | pred current: relax 1/3 s, over | pred alt: relax 1/3 s, over\n', ...
    'session','nOL','cmd V');
for i = 1:numel(R)
    r = R(i);  m = r.m;
    s = sprintf('%-22s %4d %6.2f | %6.2f @ %.2f, %5.0f%% / %5.0f%%, %+5.0f%%', r.file, r.nOL, r.cmd*r.cmdKnown, ...
        m.pk, m.tpk, m.rel1, m.rel3, m.over);
    for q = 1:2
        p = r.pred(q);
        if ~isempty(p.y)
            s = [s sprintf(' | %5.0f%% / %5.0f%%, %+5.0f%% (pk %.2f)', p.m.rel1, p.m.rel3, p.m.over, p.m.pk)]; %#ok<AGROW>
        else
            s = [s sprintf(' | range %3.0f..%3.0f%% / %3.0f..%3.0f%%', min([p.m.rel1]), max([p.m.rel1]), ...
                                                                      min([p.m.rel3]), max([p.m.rel3]))]; %#ok<AGROW>
        end
    end
    if ~r.cmdKnown, s = [s '   [cmd not recorded: unit step]']; end
    fprintf('%s\n', s);
end
fprintf(['relax = (y(t) - peak)/|peak| (0 %% = suppression held; 100 %% = back at baseline; >100 %% = crossed\n' ...
         'above baseline); overshoot = max over 3-4.5 s, %% of |peak|. Peak = min of the 3-sample-smoothed trace.\n']);
OLSTEP = R;

% ---- figure: measured vs predicted, normalised to each trace's own peak ------------------------
mice = unique({R.mn}, 'stable');  nM = numel(mice);
f = paperFig(4.2*nM, 5.2);
tlo = tiledlayout(f, 1, nM, 'TileSpacing','compact', 'Padding','compact');
mLab = imp_mouse_label(mice);                                    % global numbering (Mouse 1 = AL_0033 ...)
for j = 1:nM
    ax = nexttile(tlo);  hold(ax,'on');
    patch(ax, [0 3 3 0], [-2 -2 2 2], [.94 .94 .94], 'EdgeColor','none');
    yline(ax, 0, '-', 'Color',[.75 .75 .75], 'LineWidth',PS.lw_zero);
    ii = find(strcmp({R.mn}, mice{j}));
    hM = gobjects(0);  hP = gobjects(0);  hA = gobjects(0);
    for i = ii
        r = R(i);  hM = plot(ax, r.t, r.y/abs(r.m.pk), '-', 'Color',[.55 .55 .55 .6], 'LineWidth',0.5);
    end
    % session-mean measured
    Ym = cell2mat(arrayfun(@(i) R(i).y/abs(R(i).m.pk), ii(:), 'UniformOutput', false));
    hMm = plot(ax, R(ii(1)).t, mean(Ym,1), 'k-', 'LineWidth', PS.lw_mean);
    r = R(ii(1));  cols = {[0.2 0.4 0.8], [0.85 0.45 0.05]};
    for q = 1:2
        p = r.pred(q);
        if ~isempty(p.y)
            Yp = cell2mat(arrayfun(@(i) R(i).pred(q).y/abs(R(i).pred(q).m.pk), ii(:), 'UniformOutput', false));
            h = plot(ax, r.t, mean(Yp,1), '--', 'Color', cols{q}, 'LineWidth', PS.lw_fit);
        else
            lo = min(p.Y,[],1);  hi = max(p.Y,[],1);
            h = fill(ax, [r.t fliplr(r.t)], [lo fliplr(hi)], cols{q}, 'FaceAlpha',0.18, 'EdgeColor','none');
        end
        if q == 1, hP = h; else, hA = h; end
    end
    xlim(ax, [-1 6]);  ylim(ax, [-1.4 1.4]);
    l2 = sprintf('n = %d session(s)', numel(ii));
    if ~R(ii(1)).cmdKnown, l2 = [l2 ', cmd not recorded']; end
    tl = {sprintf('%s (%s)', mLab{j}, mice{j}), l2};
    title(ax, tl, 'FontSize',PS.fs,'FontWeight',PS.fw,'Interpreter','none');
    set(ax,'FontSize',PS.fs,'FontWeight',PS.fw,'TickDir','out','Box','off','Layer','top');
    xlabel(ax,'time from OL onset (s)');  if j == 1, ylabel(ax,'\DeltaF/F / |peak|'); end
    if j == nM
        nmL = {'measured OL (mean)','pred: current 0-0.5 s fits','pred: alt -0.5..1.0 s fits'};
        lg = legend(ax, [hMm hP hA], nmL, 'Orientation','horizontal','Box','off');
        lg.String = nmL;  lg.Layout.Tile = 'south';
        lg.ItemTokenSize = PS.lgd_token;  lg.FontSize = PS.fs-1;
    end
end
title(tlo, {'OL 3 s laser (shaded) vs impulse-TF prediction; each trace normalised to its own peak suppression', ...
            'grey = sessions | dashed = model driven by the OL command | band = all 4 impulse models (mouse has no impulse fit)'}, ...
      'FontSize',PS.fs,'FontWeight',PS.fw);
exportgraphics(f, fullfile(outDir,'ol_step_vs_impulse.png'), 'Resolution', 300);
fprintf('[OLSTEP] panel -> %s\n', outDir);

% =================================================================================================
function m = i_metrics(y, t, dur)
ys = movmean(y, 3);
on = t >= 0 & t <= dur;  [pk, ip] = min(ys(on));  tOn = t(on);
bin = @(te) mean(y(t > te - 0.2 + 1e-9 & t <= te + 1e-9));
m.pk = pk;  m.tpk = tOn(ip);
m.rel1 = 100 * (bin(1.0) - pk) / abs(pk);
m.rel3 = 100 * (bin(dur) - pk) / abs(pk);
m.over = 100 * max(y(t > dur & t <= dur + 1.5)) / abs(pk);
end
