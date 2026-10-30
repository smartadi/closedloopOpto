%% imp_relabs_exemplars.m -- what RELATIVE and ABSOLUTE 2-4 Hz power pick out, on impulse trials.
% Supplementary candidate (Aditya 2026-10-29: "show example activity of both classes relative and
% absolute to show how they differ ... we already did this for controller trials lets do it for
% these as well"). The controller version is controller-analysis/f4_delta_candidates.m (selection
% aid) and f4_state_exemplars_supp.m (paper supplement); this is the Fig 2g counterpart.
%
% Same trials, window and estimator as Fig 2g (imp_state_trialvar.m):
%   window   [-1, 0) s before onset, 35 samples (cols 71:105 of the -3..3 s dfImp timebase)
%   spectrum mean removed, Hann, FFT, 1 Hz bins; absolute = sum of 2, 3, 4 Hz bins (DPa),
%            relative = DPa / sum of the 0.4-10 Hz bins (DPr), i.e. 1..10 Hz at 1 Hz resolution
%   trials   amplitude 0 skipped, cells with < 8 trials skipped, n trimmed as in STV (1516 trials)
%
% Panels (exported separately, paper/images/supplementary/relabs/):
%   a  relative vs absolute power, every trial, z-scored within session (log10 for absolute)
%   b  three trials from one session on one y-axis: typical, high absolute / low relative,
%      high relative / low absolute; each over its own amplitude mean (gray)
%   c  mean pre-stimulus spectra of those trial groups in the same session: absolute power, and
%      power as a fraction of the 0.4-10 Hz total (the quantity relative power sums over 2-4 Hz)
%
% Requires: load_experiments (allExperiments, t_win in the base workspace).
% Knobs: REX_SESS (experiment index for b and c; default 3 = AL_0033 2025-01-29 = Mouse 1b, the
% largest trial count and the Fig 2c session). Exemplars and groups are chosen by rule, not by eye.

if ~exist('REX_SESS','var') || isempty(REX_SESS), REX_SESS = 3; end
PS = paperStyle();  setPaperDefaults();
fs = 35;  tAxis = -3 : 1/fs : 3;  iOn = find(tAxis >= 0, 1);
iPow = (iOn - round(1.0*fs)) : (iOn - 1);
assert(numel(iPow) == 35 && abs(tAxis(iPow(1)) + 1) < 1e-9, '[REX] state window is not [-1, 0) s');
C_abs = [0.55 0.25 0.60];  C_rel = [0.35 0.55 0.30];  C_typ = [0.35 0.35 0.35];   % Fig 4a colours
outDir = fullfile(paperRoot, 'images', 'supplementary', 'relabs');
if ~exist(outDir, 'dir'), mkdir(outDir); end
mlab = imp_mouse_label(allExperiments);

%% per-trial table, all sessions (mirrors imp_state_trialvar.m section 1)
T = struct('sess',[], 'amp',[], 'row',[], 'dpa',[], 'dpr',[]);
S = cell(numel(allExperiments), 1);                    % per-session spectra, trials x bins
for e = 1:numel(allExperiments)
    imp = allExperiments(e).imp;
    for a = 1:numel(imp.uAmp)
        df = imp.dfImp{a};  pk = imp.Peak_imp{a}(:);
        if isempty(df) || isempty(pk), continue; end
        n = min([size(df,1), numel(pk), size(imp.motTrace{a},1)]);
        if n < 8 || imp.uAmp{a} == 0, continue; end
        [P, f] = local_spec(df(1:n, iPow), fs);
        dpa = sum(P(:, f >= 2 & f <= 4), 2);
        dpr = dpa ./ max(sum(P(:, f >= 0.4 & f <= 10), 2), eps);
        T.sess = [T.sess; repmat(e,n,1)];  T.amp = [T.amp; repmat(a,n,1)];  T.row = [T.row; (1:n)'];
        T.dpa  = [T.dpa; dpa];             T.dpr = [T.dpr; dpr];
        S{e} = [S{e}; P];
    end
end
za = local_zby(log10(T.dpa), T.sess);  zr = local_zby(T.dpr, T.sess);
rhoAll = corr(T.dpa, T.dpr, 'type', 'Spearman');
rhoSess = arrayfun(@(e) corr(T.dpa(T.sess==e), T.dpr(T.sess==e), 'type','Spearman'), unique(T.sess)');
fprintf('[REX] %d trials, %d sessions | Spearman(abs, rel): pooled %.2f, per session %s\n', ...
        numel(za), numel(unique(T.sess)), rhoAll, mat2str(rhoSess, 2));

%% exemplars and groups in the chosen session, by rule
m = T.sess == REX_SESS;  idx = find(m);
sA = za(m) - zr(m);  sA(za(m) < 0.5) = -inf;  [~, k] = max(sA);  iA = idx(k);   % high abs, low rel
% High relative = highest relative power among trials with at least average absolute power.
% The first rule (high relative AND low absolute, mirroring f4_delta_candidates) picked trials too
% small for any rhythm to show (Aditya 2026-10-29: "these high relatives ones dont have the short
% bursts i was hoping exist"). Requiring z_abs >= 0 brings out the 2-4 Hz bursts, and the pick then
% matches the high-absolute exemplar in absolute power, so the two differ in spectral shape only.
% Candidate gallery (top 6 per session) was checked by eye; every session shows the bursts.
sR = zr(m);  sR(za(m) < 0) = -inf;  [~, k] = max(sR);  iR = idx(k);            % high rel, abs >= mean
[~, k] = min(za(m).^2 + zr(m).^2);  iT = idx(k);                                % typical
gA = m & za > 1 & zr < 0;  gR = m & zr > 1 & za >= 0;  gT = m & abs(za) < 0.5 & abs(zr) < 0.5;
for q = [iT iA iR]
    fprintf('[REX] %s exemplar: amp %d trial %d | z_abs %+.1f z_rel %+.1f | abs %.3g rel %.2f\n', ...
            mlab{REX_SESS}, T.amp(q), T.row(q), local_r1(za(q)), local_r1(zr(q)), T.dpa(q), T.dpr(q));
end
fprintf('[REX] %s groups: typical n=%d, high-abs/low-rel n=%d, high-rel/abs>=mean n=%d\n', ...
        mlab{REX_SESS}, nnz(gT), nnz(gA), nnz(gR));

%% (a) relative vs absolute, every trial
figA = paperFig(4.0, 3.6);  axA = gca;  hold(axA, 'on');
for e = unique(T.sess)'
    s = T.sess == e;
    scatter(axA, za(s), zr(s), 2, PS.sess(e,:), 'filled', 'MarkerFaceAlpha', 0.35);
end
for q = [iT iA iR]
    c = C_typ;  if q == iA, c = C_abs; elseif q == iR, c = C_rel; end
    plot(axA, za(q), zr(q), 'o', 'MarkerSize', 4, 'MarkerEdgeColor', c, 'LineWidth', 1.2);
end
xlabel(axA, ['Absolute 2' char(8211) '4 Hz power (z)']);
ylabel(axA, ['Relative 2' char(8211) '4 Hz power (z)']);
title(axA, sprintf('\\rho = %.2f, %d trials', rhoAll, numel(za)), 'FontWeight', PS.fw);
set(axA, 'Box', 'off', 'TickDir', 'out', 'FontSize', PS.fs, 'FontWeight', PS.fw);
axis(axA, 'square');
jnAxesAll(figA);
paperExport(figA, fullfile(outDir, 'relabs_scatter.pdf'));

%% (b) example trials, one y-axis
% Raw trial traces only. A light 2-4 Hz band-pass overlay was tried 2026-10-29 and removed (Aditya:
% "we dont need that"). The amplitude-mean line was dropped too: this panel is about the state
% before onset.
twin = [-1.5 1.0];  iT_ = tAxis >= twin(1) & tAxis <= twin(2);  tv = tAxis(iT_);
ex = [iT iA iR];  cx = {C_typ, C_abs, C_rel};
nm = {'Typical', 'High absolute', 'High relative'};
Y = cell(1,3);
for j = 1:3
    df = allExperiments(REX_SESS).imp.dfImp{T.amp(ex(j))};
    Y{j} = df(T.row(ex(j)), iT_);
end
yl = [min(cellfun(@min, Y)), max(cellfun(@max, Y))];  yl = yl + [-0.08 0.18]*diff(yl);
figB = paperFig(7.6, 3.3);
tl = tiledlayout(figB, 1, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
for j = 1:3
    ax = nexttile(tl);  hold(ax, 'on');
    patch(ax, [-1 0 0 -1], yl([1 1 2 2]), [0.90 0.90 0.90], 'EdgeColor', 'none');
    lz = yl(1) + 0.90*diff(yl);  lh = 0.06*diff(yl);
    plot(ax, [twin(1) 0 0 0.025 0.025 twin(2)], lz + [0 0 lh lh 0 0], 'r', 'LineWidth', 0.6);
    plot(ax, tv, Y{j},  '-', 'Color', cx{j}, 'LineWidth', 1.0);
    xlim(ax, twin);  ylim(ax, yl);  xticks(ax, -1:1);
    title(ax, nm{j}, 'FontWeight', PS.fw, 'Color', cx{j});   % z values: panel a circles + caption
    set(ax, 'Box', 'off', 'TickDir', 'out', 'FontSize', PS.fs, 'FontWeight', PS.fw);
    if j > 1, set(ax, 'YTickLabel', []); end
end
ylabel(tl, '\DeltaF/F (%)', 'FontSize', PS.fs, 'FontWeight', PS.fw);
xlabel(tl, 'Time from onset (s)', 'FontSize', PS.fs, 'FontWeight', PS.fw);
jnAxesAll(figB);
paperExport(figB, fullfile(outDir, sprintf('relabs_traces_%s.pdf', strrep(mlab{REX_SESS}, ' ', ''))));

%% (c) mean pre-stimulus spectra of the groups
Ps = S{REX_SESS};  ms = find(m);  fb = f >= 1 & f <= 10;
grp = {gT(ms), gA(ms), gR(ms)};
figC = paperFig(7.0, 3.3);   % 'normal' spacing: the relative tile's 2-line y label needs the room
tl = tiledlayout(figC, 1, 2, 'TileSpacing', 'normal', 'Padding', 'compact');
axs = [nexttile(tl) nexttile(tl)];
for j = 1:3
    Pj = Ps(grp{j}, :);
    Pn = Pj ./ sum(Pj(:, f >= 0.4 & f <= 10), 2);
    plot(axs(1), f(fb), mean(Pj(:, fb), 1), '-o', 'Color', cx{j}, 'MarkerFaceColor', cx{j}, ...
         'MarkerSize', 1.8, 'LineWidth', 1.0);  hold(axs(1), 'on');
    plot(axs(2), f(fb), mean(Pn(:, fb), 1), '-o', 'Color', cx{j}, 'MarkerFaceColor', cx{j}, ...
         'MarkerSize', 1.8, 'LineWidth', 1.0);  hold(axs(2), 'on');
end
set(axs(1), 'YScale', 'log');
ylabel(axs(1), 'Power ((% \DeltaF/F)^2 Hz^{-1})');
ylabel(axs(2), {'Fraction of', ['0.4' char(8211) '10 Hz power']});
title(axs(1), 'Absolute', 'FontWeight', PS.fw);  title(axs(2), 'Relative', 'FontWeight', PS.fw);
for ax = axs
    yy = ylim(ax);
    hb = patch(ax, [2 4 4 2], yy([1 1 2 2]), [0.90 0.90 0.90], 'EdgeColor', 'none');
    uistack(hb, 'bottom');  ylim(ax, yy);  xlim(ax, [0.5 10.5]);  xticks(ax, 2:2:10);  xtickangle(ax, 0);
    set(ax, 'Box', 'off', 'TickDir', 'out', 'FontSize', PS.fs, 'FontWeight', PS.fw, 'Layer', 'top');
end
yy = ylim(axs(1));  tk = 10.^(-3:2);  tk = tk(tk >= yy(1) & tk <= yy(2));
set(axs(1), 'YTick', tk, 'YTickLabel', compose('%g', tk'), 'YMinorTick', 'off');
xlabel(tl, 'Frequency (Hz)', 'FontSize', PS.fs, 'FontWeight', PS.fw);
% No legend: at 6 pt it covered the curves in either tile. The colours are panel b's titles
% (gray typical, purple high absolute, green high relative); group sizes go in the caption.
jnAxesAll(figC);
paperExport(figC, fullfile(outDir, sprintf('relabs_spectra_%s.pdf', strrep(mlab{REX_SESS}, ' ', ''))));

%% local functions
function [P, f] = local_spec(seg, fs)
% Periodogram as imp_state_trialvar.m local_delta (mean removed, Hann, one-sided half), scaled to a
% one-sided density in (% dF/F)^2 / Hz for display (project rule: absolute spectra in those units).
% The scale is one constant on every non-DC bin, so DPa z-scores and the DPr ratio are unchanged.
n = size(seg, 2);  w = hannwin(n).';
x = seg - mean(seg, 2, 'omitnan');  x(~isfinite(x)) = 0;
X = abs(fft(x .* w, [], 2)).^2 / (fs * sum(w.^2));  f = (0:n-1) * (fs/n);
half = 1:floor(n/2);  f = f(half);  P = X(:, half);  P(:, 2:end) = 2 * P(:, 2:end);
end

function v = local_r1(x)
v = round(x, 1);  v(v == 0) = 0;   % no "-0.0" in printouts
end

function z = local_zby(x, g)
z = nan(size(x));
for k = unique(g)'
    s = g == k;  z(s) = (x(s) - mean(x(s), 'omitnan')) ./ std(x(s), 'omitnan');
end
end
