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

% FIGURE-2 COLOUR POLICY (user, 2026-08-10), applied here and in every other Fig-2 panel:
%   grey ramp  = amplitudes WITHIN one session (panel then carries the session in its title)
%   blue ramp  = ACROSS impulse sessions   <- this panel
%   separate ramp = across the OL/step sessions, which are a different session set
% So sessions use PS.sessGrad (navy -> light cyan), NOT a qualitative hue set. The
% legibility complaint that briefly put Okabe-Ito here is fixed the other way: every
% panel is now explicitly LABELLED, which is what was actually missing.
% Colour comes from PS.sessColor(k), which is anchored at PS.NSESS -- so session k is the
% SAME shade here as in every other Fig-2 panel (user, 2026-08-12: "2c-i does not follow
% colors set for different session in other plots"). The previous PS.sessGrad(n) resampled
% the ramp to however many sessions this panel drew, so adding AL_0048 as the 4th session
% silently recoloured sessions 1-3 here and nowhere else.
grad = @(k) PS.sessColor(k);

%% ---- 2C-i : measured vs fitted h(t), peak-normalised ------------------------------
fig1 = paperFig(6, 4);
ax1  = axes(fig1); hold(ax1,'on');
hLine = gobjects(n,1);
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
    hLine(k) = plot(ax1, t, hm/sc, '-',  'Color', c, 'LineWidth', PS.lw_mean);
    % Fit drawn in the SAME hue, dashed and thinner: hue = session, dash = model.
    % Keeping the fit on the session's own colour is what lets the eye check the pair
    % locally instead of hunting for a black dashed line among four solid ones.
    plot(ax1, t, hf/sc, '--', 'Color', c, 'LineWidth', PS.lw_fit);
end
yline(ax1, 0, '-', 'Color', [.6 .6 .6], 'LineWidth', PS.lw_zero);
xlim(ax1, [0 opts.tmax_s]);
xlabel(ax1, 'time from onset (s)');
ylabel(ax1, 'normalised \DeltaF/F');
set(ax1, 'FontSize', PS.fs, 'FontWeight', PS.fw, 'TickDir','out', 'Box','off');
% ONE legend, and it names the ENCODING only -- solid = measured, dashed = fit. The
% per-session rows are gone (user, 2026-08-12: "dont need to make new legends everytime"):
% session colour is now fixed by index across the whole figure, so it is a FIGURE-level key
% that belongs once in the caption or a shared legend, not re-declared inside every panel
% at 6 pt. Repeating it here also cost four legend rows out of a 6x4 cm axis.
hM  = plot(ax1, NaN, NaN, '-',  'Color', [0 0 0], 'LineWidth', PS.lw_mean);
hF  = plot(ax1, NaN, NaN, '--', 'Color', [0 0 0], 'LineWidth', PS.lw_fit);
lg  = legend(ax1, [hM hF], {'measured','LTI fit'}, 'Location','southeast', 'Box','off');
lg.ItemTokenSize = PS.lgd_token;  lg.FontSize = PS.fs;  lg.FontWeight = PS.fw;
lg.Interpreter = 'none';

%% ---- export ------------------------------------------------------------------------
if opts.export
    if ~exist(outDir,'dir'), mkdir(outDir); end
    sfx = opts.tag;  if ~isempty(sfx) && sfx(1) ~= '_', sfx = ['_' sfx]; end
    paperExport(fig1, fullfile(outDir, sprintf('tf_shape_across_sessions%s.pdf', sfx)));
end
figs = fig1;
end
