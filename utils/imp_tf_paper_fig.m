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
if ~isfield(opts,'tag'),     opts.tag     = '';   end
if ~isfield(opts,'tmax_s'),  opts.tmax_s  = 0.5;  end
if ~isfield(opts,'export'),  opts.export  = true; end
% Display knobs added 2026-08-19 for the talk deck. Defaults reproduce the paper panel
% exactly (no lead-in, project legend token), so PAPER.md's 2C-i is unaffected unless asked.
if ~isfield(opts,'preshow'), opts.preshow = false; end   % draw pre-onset lead-in + stim mark
if ~isfield(opts,'tmin_s'),  opts.tmin_s  = 0.15; end    % seconds of lead-in to show
if ~isfield(opts,'lgd_len'), opts.lgd_len = 6;    end    % legend token length (pt)
if ~isfield(opts,'cvtag'),   opts.cvtag   = false; end   % footer naming the validation used

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
fig1 = paperFig(PS.f2w, PS.f2h);   % 2C-i -- Fig-2 grid (see paperStyle f2w/f2h)
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
    % Pre-onset lead-in, drawn in the same hue and joined to the post trace so the dip is
    % read against a visible baseline instead of starting mid-fall. Display only -- the fit
    % is post-onset, which is why no dashed counterpart is drawn here.
    if opts.preshow && isfield(S{k},'h_measPre') && ~isempty(S{k}.h_measPre)
        plot(ax1, [S{k}.tPre(:); t(1)], [S{k}.h_measPre(:); hm(1)]/sc, '-', ...
             'Color', c, 'LineWidth', PS.lw_mean, 'HandleVisibility','off');
    end
    hLine(k) = plot(ax1, t, hm/sc, '-',  'Color', c, 'LineWidth', PS.lw_mean);
    % Fit drawn in the SAME hue, dashed and thinner: hue = session, dash = model.
    % Keeping the fit on the session's own colour is what lets the eye check the pair
    % locally instead of hunting for a black dashed line among four solid ones.
    plot(ax1, t, hf/sc, '--', 'Color', c, 'LineWidth', PS.lw_fit);
end
yline(ax1, 0, '-', 'Color', [.6 .6 .6], 'LineWidth', PS.lw_zero);
if opts.preshow, xlim(ax1, [-opts.tmin_s opts.tmax_s]); else, xlim(ax1, [0 opts.tmax_s]); end

% STIM ONSET MARKER. A panel whose x-axis starts before zero needs to say WHERE the stimulus
% landed, or the lead-in reads as part of the response. Drawn as a light rule plus a filled
% marker at the top -- the same red dot used on the single-session trace panel, so the two
% panels teach the reader one symbol rather than two.
if opts.preshow
    xline(ax1, 0, '-', 'Color', [.75 .75 .75], 'LineWidth', PS.lw_zero, ...
          'HandleVisibility','off');
    yl_t = ylim(ax1);
    plot(ax1, 0, yl_t(2) - 0.06*diff(yl_t), 'v', 'MarkerSize', 4, ...
         'MarkerFaceColor', [0.85 0 0], 'MarkerEdgeColor','none', 'HandleVisibility','off');
    text(ax1, 0.035*opts.tmax_s, yl_t(2) - 0.06*diff(yl_t), 'stim', ...
         'Color', [0.85 0 0], 'FontSize', PS.fs, 'FontWeight', PS.fw, ...
         'HorizontalAlignment','left', 'VerticalAlignment','middle');
    ylim(ax1, yl_t);
end
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
% Corner: southeast is right for the paper panel, but a LONG token there runs the two
% samples straight through the dip and the rising limb. Above the traces (northeast) is the
% only genuinely empty quadrant once the lead-in is drawn -- nothing exceeds ~0.6 normalised.
lgLoc = 'southeast';  if opts.preshow, lgLoc = 'northeast'; end
lg  = legend(ax1, [hM hF], {'measured','LTI fit'}, 'Location',lgLoc, 'Box','off');
% LONGER TOKEN THAN THE PROJECT DEFAULT, on purpose (user, 2026-08-19: "i want the legend
% trace to be longer so that the dash is visible as a dash and not a line"). At the standard
% [6 6] the dashed sample is barely one dash long, so the key that distinguishes measured
% from fit is the one thing on the panel you cannot read. Everything else keeps PS.lgd_token.
lg.ItemTokenSize = [opts.lgd_len PS.lgd_token(2)];
lg.FontSize = PS.fs;  lg.FontWeight = PS.fw;
lg.Interpreter = 'none';

% ---- VALIDATION TAG (opts.cvtag) -------------------------------------------------------
% READ THIS BEFORE CALLING THE PANEL CROSS-VALIDATED. The dashed curve is S{k}.h, the unit
% response of the model fitted on ALL amplitudes of that session -- it is an IN-SAMPLE fit,
% not a held-out prediction. The cross-validated quantity in the same struct is R2_loao:
% refit without one amplitude, then predict that amplitude (leave-one-amplitude-out, see
% imp_tf_fit_session.m). They are different numbers and only the second generalises.
% So the tag states BOTH rather than putting the word "cross-validated" on a curve that is
% not one: the shape is in-sample, and the held-out R2 is quoted beside it.
if opts.cvtag
    lo = [];
    for k = 1:n
        if isfield(S{k},'R2_loao')
            v = S{k}.R2_loao(:);  lo = [lo; v(isfinite(v))];   %#ok<AGROW>
        end
    end
    if isempty(lo)
        txt = 'fit: in-sample (no LOAO available)';
    else
        txt = sprintf('fit: in-sample  |  leave-one-amplitude-out R^2 = %.2f (median, %d folds)', ...
                      median(lo), numel(lo));
    end
    text(ax1, 0.5, -0.235, txt, 'Units','normalized', ...
         'HorizontalAlignment','center', 'VerticalAlignment','top', ...
         'FontSize', max(4.5, PS.fs*0.85), 'FontWeight', PS.fw, 'Color', [0.25 0.25 0.25], ...
         'Clipping','off');
    fprintf('[TFFIG] %s\n', txt);
end

%% ---- export ------------------------------------------------------------------------
if opts.export
    if ~exist(outDir,'dir'), mkdir(outDir); end
    sfx = opts.tag;  if ~isempty(sfx) && sfx(1) ~= '_', sfx = ['_' sfx]; end
    paperExport(fig1, fullfile(outDir, sprintf('tf_shape_across_sessions%s.pdf', sfx)));
end
figs = fig1;
end
