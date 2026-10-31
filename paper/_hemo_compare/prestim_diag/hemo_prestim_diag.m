function R = hemo_prestim_diag(outDir)
% HEMO_PRESTIM_DIAG  READ-ONLY (2026-10-11). Does the NEW server hemo correction create a
% pre-stimulus rise in the trial-averaged impulse response?
% Kernel trace (load_experiments definition) from four sources, each aligned to the stim:
%   old    corr_hemoApr2021/  index-aligned (published convention)
%   new    corr/              aligned by its own timestamps (the fix in load_experiments)
%   blue   blue/ raw + detrendAndFilt (no hemo correction), by its timestamps
%   violet violet/ raw + detrendAndFilt, violet U + violet mean image, by its timestamps
% Baseline = mean over -1.0..-0.3 s (NOT the onset sample, so a pre-onset drift is visible).
% x-axis = real frame time minus stim time (trial mean), so blue and violet interleave honestly.
% Sham = same pipeline at random non-stim times (null).  Writes only into outDir.
ex = {'AL_0041','2025-12-02',1; 'AL_0041','2025-12-02',2; 'AL_0033','2025-01-29',1};
bp = 'C:\Users\aditya\Documents\projects\brain_paper';
fs = 35; nSV = 500; tw = -35:35; base = tw >= -35 & tw <= -11; pre = tw >= -7 & tw <= -1;
post = tw >= 0 & tw <= 7;
src = {'old','new','blue','violet'};
R = struct([]);
for e = 1:size(ex,1)
    [mn, td, en] = ex{e,:};
    sr = expPath(mn, td, en);
    d  = loadData(sr, mn, td, en);
    px = d.params.pixel(1,:); k = d.params.kernel;
    rows = px(2)-k:px(2)+k; cols = px(1)-k:px(1)+k;
    S  = load(fullfile(bp,'impulse-analysis','data',sprintf('stim_vars_%s_%s_en%d.mat',mn,td,en)));
    amps = S.uAmp(:)';
    Tall = sort(S.stimStarts(:));
    % sham times: uniform, >= 3 s from any stim
    rng(1); Ts = Tall(1) + rand(4000,1) * (Tall(end) - Tall(1));
    Ts = Ts(min(abs(Ts - Tall'), [], 2) > 3); Ts = Ts(1:min(400, end));
    r = struct('sess', sprintf('%s %s e%d', mn, td, en), 'amp', amps);
    for s = 1:4
        switch src{s}
            case 'old',    f = 'corr_hemoApr2021'; vf = 'svdTemporalComponents_corr'; uf = 'blue';
            case 'new',    f = 'corr';             vf = 'svdTemporalComponents_corr'; uf = 'blue';
            case 'blue',   f = 'blue';             vf = 'svdTemporalComponents';      uf = 'blue';
            case 'violet', f = 'violet';           vf = 'svdTemporalComponents';      uf = 'violet';
        end
        U  = readUfromNPY(fullfile(sr, uf, 'svdSpatialComponents.npy'), nSV);
        uk = reshape(mean(U(rows,cols,:), [1 2]), 1, nSV); clear U
        mimg = readNPY(fullfile(sr, uf, 'meanImage.npy')); mI = mean(mimg(rows,cols), 'all');
        V = readVfromNPY(fullfile(sr, f, [vf '.npy']), nSV);
        t = double(readNPY(fullfile(sr, f, [vf '.timestamps.npy']))); t = t(:);
        if any(strcmp(src{s}, {'blue','violet'})), V = detrendAndFilt(V, 1/mean(diff(t))); end
        dF = double(uk * V) / mI * 100; clear V
        nT = numel(dF); t = t(1:min(end, nT));
        if strcmp(src{s}, 'old')
            idx = @(T) round((T - d.timeBlue(1)) * fs) + 1;
            t = double(d.timeBlue(:)); t = t(1:min(end, nT));   % old columns = blue frames 1..N
        else
            idx = @(T) round(interp1(t, (1:numel(t))', T, 'nearest', 'extrap'));
        end
        [tr, se, tx, n] = deal(nan(numel(amps), numel(tw)), nan(numel(amps), numel(tw)), nan(numel(amps), numel(tw)), zeros(1, numel(amps)));
        for i = 1:numel(amps)
            T = S.stimStarts(S.idxByAmp{i}); T = T(:);
            [tr(i,:), se(i,:), tx(i,:), n(i)] = seg(dF, t, idx(T), T, tw, base);
        end
        [shm, shse, shx] = seg(dF, t, idx(Ts), Ts, tw, base);
        r.(src{s}) = struct('tr', tr, 'se', se, 'tx', tx, 'n', n, 'sham', shm, 'shamse', shse, 'shamx', shx, ...
            'pre', mean(tr(:, pre), 2)', 'post', mean(tr(:, post), 2)', 'shampre', mean(shm(pre)));
    end
    R = [R r]; %#ok<AGROW>
    fprintf('\n== %s  (pre = mean -200..-29 ms re -1..-0.3 s baseline; post = 0..200 ms)\n', r.sess);
    fprintf('%-8s', 'amp'); fprintf('%8.2f', amps); fprintf('   | sham pre\n');
    for s = 1:4
        fprintf('%-8s', [src{s} ' pre']);  fprintf('%8.3f', r.(src{s}).pre);  fprintf('   | %7.3f\n', r.(src{s}).shampre);
        fprintf('%-8s', [src{s} ' pst']);  fprintf('%8.3f', r.(src{s}).post); fprintf('\n');
    end
end
save(fullfile(outDir, 'hemo_prestim_diag.mat'), 'R');

% ---- Figure 1: per session, strongest amp (4 sources + sham), and all-amp new vs blue
col = [0 0 0; .85 .2 .2; .1 .45 .85; .55 .2 .75];
f1 = figure('Color','w','Position',[30 30 1500 900]);
for e = 1:numel(R)
    r = R(e); [~, ia] = max(r.amp);
    ax = subplot(numel(R), 4, (e-1)*4 + 1); hold on
    for s = 1:4
        q = r.(src{s}); x = q.tx(ia,:) * 1e3;
        fill([x fliplr(x)], [q.tr(ia,:)+q.se(ia,:) fliplr(q.tr(ia,:)-q.se(ia,:))], col(s,:), 'FaceAlpha', .15, 'EdgeColor', 'none', 'HandleVisibility', 'off');
        plot(x, q.tr(ia,:), '.-', 'Color', col(s,:), 'LineWidth', 1.2);
    end
    plot(r.new.shamx * 1e3, r.new.sham, '--', 'Color', [.6 .6 .6]);
    xline(0, ':'); yline(0, ':'); xlim([-1000 1000]);
    title(sprintf('%s  %.2f V (n=%d)', r.sess, r.amp(ia), r.new.n(ia))); ylabel('\DeltaF/F re baseline (%)');
    if e == 1, legend({'old corr (index)','new corr (ts)','raw blue','raw violet','sham (new)'}, 'FontSize', 7, 'Location', 'southwest'); end
    ax2 = subplot(numel(R), 4, (e-1)*4 + 2); copyobj(ax.Children, ax2); xlim([-400 400]); xline(0,':'); title('zoom \pm400 ms'); grid on
    for s = [2 3]
        subplot(numel(R), 4, (e-1)*4 + 1 + s); hold on
        cm = parula(numel(r.amp) + 1); q = r.(src{s});
        for i = 1:numel(r.amp), plot(q.tx(i,:) * 1e3, q.tr(i,:), 'Color', cm(i,:), 'LineWidth', 1); end
        xline(0, ':'); yline(0, ':'); xlim([-1000 1000]);
        title(sprintf('%s, all amps (dark=low)', src{s}));
    end
    if e == numel(R), for c = 1:4, subplot(numel(R), 4, (e-1)*4 + c); xlabel('time from stim (ms)'); end, end
end
exportgraphics(f1, fullfile(outDir, 'hemo_prestim_traces.png'), 'Resolution', 150);

% ---- Figure 2: pre-stim deflection vs amp, and the resample-step impulse response
f2 = figure('Color','w','Position',[30 30 1500 420]);
for e = 1:numel(R)
    subplot(1, numel(R) + 1, e); hold on
    for s = 1:4, plot(R(e).amp, R(e).(src{s}).pre, '-o', 'Color', col(s,:), 'MarkerFaceColor', col(s,:), 'MarkerSize', 4); end
    yline(R(e).new.shampre, '--', 'Color', [.6 .6 .6]); yline(0, ':');
    title(R(e).sess); xlabel('laser (V)'); ylabel('mean -200..-29 ms (%)');
    if e == 1, legend([src {'sham new'}], 'FontSize', 7, 'Location', 'best'); end
end
% synthetic: a one-frame dip at blue frame 0 pushed through hemoCorrect's resample step
subplot(1, numel(R) + 1, numel(R) + 1); hold on
tb = (0:699)' / fs + 0.0005 * randn(700, 1); x = zeros(700, 1); x(350) = -1;
[xs, ts] = resample(x, tb, fs * 2); xs = xs(2:2:end); ts = ts(2:2:end);
stem((ts - tb(350)) * 1e3, xs, 'filled', 'MarkerSize', 3); xlim([-300 300]); xline(0, ':');
title('hemoCorrect resample step: 1-frame dip in -> out'); xlabel('ms from dip'); grid on
exportgraphics(f2, fullfile(outDir, 'hemo_prestim_dose.png'), 'Resolution', 150);
fprintf('\n-> %s\n', outDir);
end

function [m, se, tx, n] = seg(dF, t, b, T, tw, base)
ok = b + tw(1) >= 1 & b + tw(end) <= numel(dF);
b = b(ok); T = T(ok); n = numel(b);
if n == 0, [m, se, tx] = deal(nan(1, numel(tw))); return, end
X = dF(b + tw); X = X - mean(X(:, base), 2);
m = mean(X, 1); se = std(X, 0, 1) / sqrt(n);
tx = mean(t(b + tw) - T, 1);
end
