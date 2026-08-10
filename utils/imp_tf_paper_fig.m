function figs = imp_tf_paper_fig(S, outDir, opts)
%IMP_TF_PAPER_FIG  The Fig-2 TF SHAPE panel (2C-i).
%
% Replaces the 6-panel [TFX] diagnostic dashboard for PAPER use. That dashboard is
% still the right thing to read while working (it shows gRatio, rho, LOAO and the
% per-amplitude pole drift), but it asks the reader to hold six questions at once.
% A figure panel should make ONE claim. This one makes:
%
%   2C-i   "the impulse response has the SAME SHAPE in every session, and a
%           low-order linear model reproduces it"
%          -> peak-normalised h(t), measured SOLID vs fitted DASHED, one line
%             per session on the session gradient. If the solid lines lie on
%             top of each other, the preparation is consistent. If dashed
%             tracks solid, the LTI model is adequate. Both are read by eye,
%             which is the point.
%
% Peak-normalisation is deliberate: it removes the amplitude/gain difference
% between sessions so the panel is about SHAPE only. Size is a separate claim
% and lives in the dose-response panel (2B) and in gRatio.
%
% THE TIME-CONSTANT PANELS LIVE ELSEWHERE. tau, its variability, its dependence
% on drive, and the cross-session model swap are the four-panel block in
% `imp_tf_robust_fig.m` -- they make a robustness argument that needs more than
% one axis. (Both functions used to emit tf_tau_forest.pdf and would silently
% overwrite each other; the forest now belongs to imp_tf_robust_fig alone.)
%
% INPUT
%   S      cell array of imp_tf_fit_session outputs (matched-range preferred).
%          Entries with S{k}.ok == false are skipped.
%   outDir folder for the PDF (created if missing).
%   opts   .tag      filename suffix                        (default '')
%          .tmax_s   x-limit, seconds                       (default 0.5)
%          .export   write PDF                              (default true)
%
% OUTPUT
%   figs   fig_shape handle.
%
% Size follows PAPER.md: 6x4 cm, 6 pt bold.

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

%% ---- export ------------------------------------------------------------------------
if opts.export
    if ~exist(outDir,'dir'), mkdir(outDir); end
    sfx = opts.tag;  if ~isempty(sfx) && sfx(1) ~= '_', sfx = ['_' sfx]; end
    paperExport(fig1, fullfile(outDir, sprintf('tf_shape_across_sessions%s.pdf', sfx)));
end
figs = fig1;
end
