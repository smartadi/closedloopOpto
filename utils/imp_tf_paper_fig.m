function figs = imp_tf_paper_fig(S, outDir, opts)
%IMP_TF_PAPER_FIG  The two Fig-2 TF panels, one message each.
%
% Replaces the 6-panel [TFX] diagnostic dashboard for PAPER use. That dashboard is
% still the right thing to read while working (it shows gRatio, rho, LOAO and the
% per-amplitude pole drift), but it asks the reader to hold six questions at once.
% A figure panel should make ONE claim.
%
% THE CLAIM Fig 2 needs is a two-parter, so there are two panels:
%
%   2C-i   "the impulse response has the SAME SHAPE in every session, and a
%           low-order linear model reproduces it"
%          -> peak-normalised h(t), measured SOLID vs fitted DASHED, one line
%             per session on the session gradient. If the solid lines lie on
%             top of each other, the preparation is consistent. If dashed
%             tracks solid, the LTI model is adequate. Both are read by eye,
%             which is the point.
%
%   2C-ii  "and the time constant is the same NUMBER, within uncertainty"
%          -> tau forest: per-session slowest tau with its bootstrap CI.
%             Overlapping CIs + a between/within SD ratio near 1 is what
%             "it replicates" actually looks like. Three numbers with no
%             uncertainty would support neither claim.
%
% Peak-normalisation in 2C-i is deliberate: it removes the amplitude/gain
% difference between sessions so the panel is about SHAPE only. Size is a
% separate claim and lives in the dose-response panel (2B) and in gRatio.
%
% INPUT
%   S      cell array of imp_tf_fit_session outputs (matched-range preferred).
%          Entries with S{k}.ok == false are skipped.
%   outDir folder for the PDFs (created if missing).
%   opts   .tag      filename suffix                        (default '')
%          .tmax_s   x-limit for panel i, seconds           (default 0.5)
%          .export   write PDFs                             (default true)
%
% OUTPUT
%   figs   [fig_shape fig_tau] handles.
%
% Sizes follow PAPER.md: 2C-i 6x4 cm, 2C-ii 4x4 cm, 6 pt bold.

if nargin < 3, opts = struct(); end
if ~isfield(opts,'tag'),    opts.tag    = '';   end
if ~isfield(opts,'tmax_s'), opts.tmax_s = 0.5;  end
if ~isfield(opts,'export'), opts.export = true; end

PS = paperStyle();
ok = cellfun(@(s) isstruct(s) && isfield(s,'ok') && s.ok && ~isempty(s.h), S);
S  = S(ok);
n  = numel(S);
assert(n >= 1, '[TFPAPER] no usable session fits.');

% Session gradient: dark -> light, same convention as panel 2I (ol_tf_trial_avg).
grad = @(k) [0 0 0] + (0.62*(k-1)/max(n-1,1));

%% ---- 2C-i : measured vs fitted h(t), peak-normalised ------------------------------
fig1 = paperFig(6, 4);
ax1  = axes(fig1); hold(ax1,'on');
for k = 1:n
    t  = S{k}.tPost(:);
    hm = S{k}.h_meas(:);  hf = S{k}.h(:);
    m  = min(numel(t), min(numel(hm), numel(hf)));
    t  = t(1:m);  hm = hm(1:m);  hf = hf(1:m);
    % Peak-normalise on the MEASURED trace and apply the same scale to the fit,
    % so the fit is still judged against the data rather than re-scaled to match.
    sc = max(abs(hm(isfinite(hm))));
    if isempty(sc) || sc == 0, continue; end
    c = grad(k);
    plot(ax1, t, hm/sc, '-',  'Color', c, 'LineWidth', PS.lw_mean);
    plot(ax1, t, hf/sc, '--', 'Color', c, 'LineWidth', PS.lw_fit);
end
yline(ax1, 0, '-', 'Color', [.6 .6 .6], 'LineWidth', PS.lw_zero);
xlim(ax1, [0 opts.tmax_s]);
xlabel(ax1, 'time from onset (s)');
ylabel(ax1, 'normalised \DeltaF/F');
set(ax1, 'FontSize', PS.fs, 'FontWeight', PS.fw, 'TickDir','out', 'Box','off');
% Two-entry legend explaining the ENCODING, not the sessions -- session identity is
% the gradient and belongs in the caption, not in n legend rows.
hM = plot(ax1, NaN, NaN, '-',  'Color', [0 0 0], 'LineWidth', PS.lw_mean);
hF = plot(ax1, NaN, NaN, '--', 'Color', [0 0 0], 'LineWidth', PS.lw_fit);
lg = legend(ax1, [hM hF], {'measured','LTI fit'}, 'Location','southeast', 'Box','off');
lg.ItemTokenSize = [6 6];  lg.FontSize = PS.fs;  lg.FontWeight = PS.fw;

%% ---- 2C-ii : tau forest with bootstrap CIs ----------------------------------------
tau1 = nan(n,1); lo = nan(n,1); hi = nan(n,1); lbl = cell(n,1);
for k = 1:n
    if ~isempty(S{k}.tau), tau1(k) = S{k}.tau(1); end          % slowest time constant
    if isfield(S{k},'tauCI') && ~isempty(S{k}.tauCI)
        lo(k) = S{k}.tauCI(1);  hi(k) = S{k}.tauCI(2);
    end
    lbl{k} = S{k}.label;
end
fig2 = paperFig(4, 4);
ax2  = axes(fig2); hold(ax2,'on');
yy = (1:n).';
% Cross-session mean +/- SD band: the "one shared time constant" reference.
mu = mean(tau1,'omitnan');  sd = std(tau1,'omitnan');
if isfinite(mu)
    xb = [mu-sd mu+sd];
    patch(ax2, [xb(1) xb(2) xb(2) xb(1)], [0.4 0.4 n+0.6 n+0.6], [.85 .85 .85], ...
        'EdgeColor','none', 'FaceAlpha', 0.5);
    xline(ax2, mu, '-', 'Color', [.45 .45 .45], 'LineWidth', PS.lw_ref);
end
for k = 1:n
    if isfinite(lo(k)) && isfinite(hi(k))
        plot(ax2, [lo(k) hi(k)], [yy(k) yy(k)], '-', 'Color', grad(k), 'LineWidth', PS.lw_fit);
    end
    plot(ax2, tau1(k), yy(k), 'o', 'MarkerSize', 3.5, ...
        'MarkerFaceColor', grad(k), 'MarkerEdgeColor', grad(k));
end
ylim(ax2, [0.4 n+0.6]);  set(ax2, 'YTick', yy, 'YTickLabel', lbl);
xlabel(ax2, '\tau_{slow} (s)');
set(ax2, 'FontSize', PS.fs, 'FontWeight', PS.fw, 'TickDir','out', 'Box','off');

%% ---- export ------------------------------------------------------------------------
if opts.export
    if ~exist(outDir,'dir'), mkdir(outDir); end
    sfx = opts.tag;  if ~isempty(sfx) && sfx(1) ~= '_', sfx = ['_' sfx]; end
    paperExport(fig1, fullfile(outDir, sprintf('tf_shape_across_sessions%s.pdf', sfx)));
    paperExport(fig2, fullfile(outDir, sprintf('tf_tau_forest%s.pdf', sfx)));
end
figs = [fig1 fig2];
end
