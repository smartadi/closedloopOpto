function RB = imp_tf_robust_fig(S, outDir, opts)
%IMP_TF_ROBUST_FIG  Panel block: impulse time constants, their variability, and why it doesn't matter.
%
% =====================================================================================
% THE ARGUMENT THIS BLOCK MAKES
% =====================================================================================
% The weak version of the LTI claim is "the plant is the same in every session". That is
% a hostage to fortune: the moment tau moves between sessions a referee has a hole to
% push on, and tau almost certainly does move (different animal, different expression,
% different window, different day).
%
% The strong version -- and the one that matches how the experiment is actually run --
% is: **every session gets its own controller anyway, so between-session plant variation
% is an expected operating condition, not a threat. What has to be true is (a) that
% within a session the plant is low-order LTI, and (b) that the family of plants is
% tight enough that the design transfers.** That is a ROBUSTNESS claim, and robustness
% claims are demonstrated, not asserted.
%
% Four panels, each answering one question:
%   TF-A  what IS the time constant, and how precisely do we know it?
%           -> tau forest: per-session tau_slow with its trial-bootstrap CI.
%   TF-B  is the between-session spread REAL, or is it fit noise?
%           -> between-session SD vs mean within-session bootstrap SD, and the ratio.
%              Ratio ~1 => the sessions are consistent with ONE shared time constant.
%              Ratio >>1 => genuine inter-experiment variability. BOTH are publishable;
%              they just lead to different sentences.
%   TF-C  does the plant change with DRIVE, inside a session?
%           -> tau from per-amplitude refits. This is the one that would actually break
%              the controller design, because a single session's controller cannot be
%              robust to its own plant moving with the command it sends. Flat = safe.
%   TF-D  does a model fitted on one session describe another?
%           -> cross-session model-swap R^2 matrix. Diagonal = self-fit (the ceiling);
%              off-diagonal = session i's model against session j's measured response.
%              Off-diagonal close to diagonal is the DIRECT statement that the plants
%              are interchangeable, i.e. that a controller designed on one lands in the
%              right basin on another. Free-gain scoring, so this is a claim about
%              DYNAMICS (shape), not about gain -- gain is re-tuned per session by
%              construction (see the gain-grid / auto-tune methods figure).
%
% Read together: TF-C says each session is a well-behaved LTI plant across its own
% operating range; TF-A/B say the plants differ by a stated amount; TF-D says that
% difference does not stop the model transferring. Per-session tuning closes the gap.
%
% INPUT
%   S      cell array of imp_tf_fit_session outputs (matched-range fits preferred).
%   outDir folder for the PDFs.
%   opts   .tag ''  .export true  .amp_norm true (normalise TF-C x-axis to max amp)
%          .panels  which of {'A','B','C','D'} to draw   (default {'A','D'})
%
% .panels EXISTS BECAUSE THE BLOCK IS NOT ALWAYS WANTED WHOLE. As of 2026-08-10 the
% figure set is A (timescale forest), D (model-swap grid), the shape overlay, and the
% new all-poles panel; B and C are computed and printed but not drawn by default. The
% CODE for B/C stays -- TF-C in particular is the panel that would break the design if
% it sloped, so it must remain one option away, not a deletion to be re-derived.
%
% OUTPUT
%   RB     struct: tau1, sdBetween, sdWithin, ratio, X (swap matrix), labels, figs.

if nargin < 3, opts = struct(); end
if ~isfield(opts,'tag'),      opts.tag      = '';    end
if ~isfield(opts,'export'),   opts.export   = true;  end
if ~isfield(opts,'amp_norm'), opts.amp_norm = true;  end
if ~isfield(opts,'panels'),   opts.panels   = {'A','D'}; end
wantP = @(c) any(strcmpi(opts.panels, c));

PS = paperStyle();
ok = cellfun(@(s) isstruct(s) && isfield(s,'ok') && s.ok && ~isempty(s.h), S);
S  = S(ok);
n  = numel(S);
assert(n >= 2, '[TFROBUST] need >=2 usable session fits for a variability panel.');

% FIG-2 COLOUR POLICY (user, 2026-08-10): ACROSS SESSIONS = the blue ramp, everywhere in
% Fig 2. Same session index -> same shade in the shape overlay, this block and the pole
% panel, so a reader can carry identity from one panel to the next.
% Session colour is indexed by SESSION NUMBER via PS.sessColor, not resampled per panel --
% see the note in paperStyle.m. PS.sessGrad(n) used to give session 1 a different shade in a
% 3-session panel than in a 4-session one.
grad = @(k) PS.sessColor(k);
lbl  = cellfun(@(s) string(s.label), S);   % FULL label -> RB struct + console mapping
% Tick labels are s1..sN (user, 2026-08-12: "in model swap use name s1,s2,s3,s4"). Short
% enough that the swap matrix does not need rotated ticks, and the k -> real session mapping
% is printed once by the driver and belongs in the caption.
lblS = "s" + string(1:n).';

tau1 = nan(n,1); lo = nan(n,1); hi = nan(n,1); sdW = nan(n,1);
tau2 = nan(n,1); lo2 = nan(n,1); hi2 = nan(n,1);
for k = 1:n
    if ~isempty(S{k}.tau), tau1(k) = S{k}.tau(1); end
    % SECOND pole where the selected order has one (user, 2026-08-12: "make tau forest more
    % informative by also showing other poles"). Sessions whose AIC-selected model is
    % first-order simply have no fast pole -- that is a fact about the fit, so it is left
    % as a gap in the panel rather than filled in from a re-fit at a forced order.
    if numel(S{k}.tau) >= 2, tau2(k) = S{k}.tau(2); end
    % *** BUG FIX 2026-08-12. *** tauCI is [maxPoles x 2] (imp_tf_fit_session line ~260:
    % [prctile(tauBoot,2.5,1).' , prctile(tauBoot,97.5,1).']), so row = pole, col = bound.
    % The previous code read it with LINEAR indices -- lo = tauCI(1), hi = tauCI(2) -- and
    % MATLAB is column-major, so tauCI(2) is row 2 of column 1: the FAST pole's 2.5th
    % percentile, not the slow pole's 97.5th. Whenever maxPoles >= 2 the TF-A error bar was
    % therefore drawn from slow-tau-lower to fast-tau-lower, i.e. a backwards interval that
    % is not a confidence interval for anything. Correct only in the maxPoles == 1 case.
    if isfield(S{k},'tauCI') && ~isempty(S{k}.tauCI)
        lo(k) = S{k}.tauCI(1,1);  hi(k) = S{k}.tauCI(1,2);
        if size(S{k}.tauCI,1) >= 2, lo2(k) = S{k}.tauCI(2,1);  hi2(k) = S{k}.tauCI(2,2); end
    end
    if isfield(S{k},'tauSD') && ~isempty(S{k}.tauSD), sdW(k)=S{k}.tauSD(1); end
end
hasFast = any(isfinite(tau2));
sdB   = std(tau1,'omitnan');
mW    = mean(sdW,'omitnan');
ratio = sdB / mW;

mu = mean(tau1,'omitnan');
figA = gobjects(0); figB = gobjects(0); figC = gobjects(0); figD = gobjects(0);

%% ---- TF-A : tau forest -------------------------------------------------------------
if wantP('A')
% Widened 4 -> 5 cm: a log axis carrying two decades of tau needs the room.
figA = paperFig(PS.f2w, PS.f2h);  axA = axes(figA); hold(axA,'on');   % TF-A -- Fig-2 grid
% Each session gets ONE row and keeps ONE colour; the two poles are separated by MARKER
% (filled circle = slow, open square = fast), not by hue. Encoding pole type in colour
% would have cost the session identity that every other Fig-2 panel carries.
dy = 0.16;
if isfinite(mu) && isfinite(sdB)
    patch(axA, [mu-sdB mu+sdB mu+sdB mu-sdB], [0.4 0.4 n+0.6 n+0.6], [.86 .86 .86], ...
        'EdgeColor','none','FaceAlpha',0.6);
    xline(axA, mu, '-', 'Color',[.45 .45 .45], 'LineWidth', PS.lw_ref);
end
for k = 1:n
    yS = k + hasFast*dy;                       % slow row nudges up only if a fast row exists
    if isfinite(lo(k)) && isfinite(hi(k))
        plot(axA, [lo(k) hi(k)], [yS yS], '-', 'Color', grad(k), 'LineWidth', PS.lw_fit);
    end
    plot(axA, tau1(k), yS, 'o', 'MarkerSize',3.5, ...
         'MarkerFaceColor',grad(k), 'MarkerEdgeColor',grad(k));
    if isfinite(tau2(k))
        yF = k - dy;
        if isfinite(lo2(k)) && isfinite(hi2(k))
            plot(axA, [lo2(k) hi2(k)], [yF yF], '-', 'Color', grad(k), 'LineWidth', PS.lw_fit);
        end
        plot(axA, tau2(k), yF, 's', 'MarkerSize',3.2, ...
             'MarkerFaceColor','none', 'MarkerEdgeColor',grad(k), 'LineWidth',0.6);
    end
end
ylim(axA,[0.4 n+0.6]);  set(axA,'YTick',1:n,'YTickLabel',cellstr(lblS),'TickLabelInterpreter','none');
if hasFast
    % LOG x: tau_fast and tau_slow differ by an order of magnitude, so on a linear axis every
    % fast pole collapses onto the y-axis and the panel says nothing about their agreement.
    set(axA,'XScale','log');
    xlabel(axA,'\tau (s)');
    hSlow = plot(axA, NaN, NaN, 'o', 'MarkerSize',3.5, 'MarkerFaceColor',[.35 .35 .35], 'MarkerEdgeColor',[.35 .35 .35]);
    hFast = plot(axA, NaN, NaN, 's', 'MarkerSize',3.2, 'MarkerFaceColor','none', 'MarkerEdgeColor',[.35 .35 .35], 'LineWidth',0.6);
    lgA = legend(axA, [hSlow hFast], {'slow','fast'}, 'Location','best', 'Box','off');
    lgA.ItemTokenSize = PS.lgd_token;  lgA.FontSize = PS.fs;  lgA.FontWeight = PS.fw;
else
    xlabel(axA,'\tau_{slow} (s)');
end
set(axA,'FontSize',PS.fs,'FontWeight',PS.fw,'TickDir','out','Box','off');
end

%% ---- TF-B : is the spread real? -----------------------------------------------------
if wantP('B')
figB = paperFig(4, 4);  axB = axes(figB); hold(axB,'on');
% The two bars are NOT sessions, so they stay off the session ramp -- they are the same
% quantity measured two ways, and get two tints of the navy family so the per-session
% dots read as a different kind of thing sitting on top of them.
bar(axB, 1, sdB, 0.6, 'FaceColor',PS.grad0,          'EdgeColor','none');
bar(axB, 2, mW,  0.6, 'FaceColor',[.72 .80 .88], 'EdgeColor','none');
% Per-session within-SD as dots over the mean bar: shows the "within" bar is an
% average of n numbers, not a single measurement. Thin white edge so a dot landing on
% the bar of its own colour family is still visible.
for k = 1:n
    if isfinite(sdW(k))
        plot(axB, 2, sdW(k), 'o', 'MarkerSize',3, 'MarkerFaceColor',grad(k), ...
            'MarkerEdgeColor',[1 1 1], 'LineWidth',0.3);
    end
end
set(axB,'XTick',[1 2],'XTickLabel',{'between','within'});
ylabel(axB,'SD of \tau_{slow} (s)');
ylim(axB,[0 max([sdB; sdW; eps])*1.35]);
if isfinite(ratio)
    text(axB, 1.5, max([sdB; sdW])*1.22, sprintf('ratio %.2f', ratio), ...
        'HorizontalAlignment','center','FontSize',PS.fs,'FontWeight',PS.fw);
end
set(axB,'FontSize',PS.fs,'FontWeight',PS.fw,'TickDir','out','Box','off');
end

%% ---- TF-C : does tau move with drive, within a session? -----------------------------
if wantP('C')
figC = paperFig(5, 4);  axC = axes(figC); hold(axC,'on');
hC = gobjects(n,1);
for k = 1:n
    if ~isfield(S{k},'tau_amp') || isempty(S{k}.tau_amp), continue; end
    ta = S{k}.tau_amp(:,1);  ua = S{k}.uA(:);
    m  = min(numel(ta), numel(ua));  ta = ta(1:m); ua = ua(1:m);
    v  = isfinite(ta) & isfinite(ua) & ua > 0;
    if nnz(v) < 2, continue; end
    x = ua(v);  if opts.amp_norm, x = x/max(x); end
    hC(k) = plot(axC, x, ta(v), '-o', 'Color',grad(k), 'MarkerSize',2.6, ...
        'MarkerFaceColor',grad(k), 'MarkerEdgeColor','none', 'LineWidth',PS.lw_fit);
end
if isfinite(mu), yline(axC, mu, '--', 'Color',[.45 .45 .45], 'LineWidth',PS.lw_ref); end
if opts.amp_norm, xlabel(axC,'laser amplitude (norm.)'); else, xlabel(axC,'laser amplitude (V)'); end
ylabel(axC,'\tau_{slow} (s)');
set(axC,'FontSize',PS.fs,'FontWeight',PS.fw,'TickDir','out','Box','off');
% TF-C is the load-bearing panel and the only one where the curves overlap heavily, so
% it carries the key. TF-A/TF-D name their sessions on the axis; TF-B's dots inherit it.
vC = isgraphics(hC);
if any(vC)
    lgC = legend(axC, hC(vC), cellstr(lblS(vC)), 'Location','best', 'Box','off');
    lgC.ItemTokenSize = PS.lgd_token;  lgC.FontSize = PS.fs;  lgC.FontWeight = PS.fw;
    lgC.Interpreter = 'none';
    if nnz(vC) >= 3, lgC.NumColumns = 2; end
end
end

%% ---- TF-D : cross-session model swap ------------------------------------------------
% X is computed UNCONDITIONALLY -- the self-vs-swap R^2 verdict is printed on every run
% and lands in RB, so turning the panel off must not turn the number off with it.
% X(i,j) = R^2 of session i's FITTED unit response against session j's MEASURED response,
% with the scale free. Free gain is the point: gain is re-tuned per session anyway, so the
% question is whether the DYNAMICS transfer, not whether the gain happens to match.
X = nan(n,n);
for i = 1:n
    hi_ = S{i}.h(:);
    for j = 1:n
        hm = S{j}.h_meas(:);
        m  = min(numel(hi_), numel(hm));
        a  = hi_(1:m);  b = hm(1:m);
        v  = isfinite(a) & isfinite(b);
        if nnz(v) < 5, continue; end
        av = a(v);  bv = b(v);
        g  = (av.'*bv)/max(av.'*av, eps);                 % best-fitting scale
        X(i,j) = 1 - sum((bv - g*av).^2)/max(sum((bv-mean(bv)).^2), eps);
    end
end
if wantP('D')
figD = paperFig(PS.f2w, PS.f2h);  axD = axes(figD);   % TF-D -- Fig-2 grid
% Sequential navy ramp instead of flipud(gray): still monotonic in lightness (so it
% survives a greyscale print and the cell-text contrast rule below still works), but
% mid-range R^2 values are far easier to place against the colourbar in colour.
imagesc(axD, X, [0 1]); axis(axD,'square'); colormap(axD, PS.cmapSeq(256));
set(axD,'XTick',1:n,'XTickLabel',cellstr(lblS),'YTick',1:n,'YTickLabel',cellstr(lblS), ...
    'TickLabelInterpreter','none','FontSize',PS.fs,'FontWeight',PS.fw,'TickDir','out');
xtickangle(axD,0);   % s1..sN fit horizontally; rotation was only needed for date labels
xlabel(axD,'applied to session'); ylabel(axD,'model from session');
cb = colorbar(axD); cb.Label.String = 'R^2 (free gain)';
cb.FontSize = PS.fs; cb.Label.FontSize = PS.fs; cb.Label.FontWeight = PS.fw;
% Annotate each cell so the panel is readable in print, not just on screen.
cmD = PS.cmapSeq(256);
for i = 1:n
    for j = 1:n
        if ~isfinite(X(i,j)), continue; end
        % Pick the text colour from the LUMINANCE of the cell it sits on rather than
        % from a hard-coded value threshold -- the threshold was tuned for grey and is
        % wrong for any other ramp, and an unreadable annotation defeats the panel.
        c  = cmD(max(1, min(256, round(X(i,j)*255)+1)), :);
        tc = [0 0 0];  if (0.299*c(1)+0.587*c(2)+0.114*c(3)) < 0.55, tc = [1 1 1]; end
        text(axD, j, i, sprintf('%.2f', X(i,j)), 'HorizontalAlignment','center', ...
            'FontSize',PS.fs-1,'FontWeight',PS.fw,'Color',tc);
    end
end
end

%% ---- export + the numbers the caption needs ------------------------------------------
dg  = diag(X);
offd = X(~eye(n));
RB = struct('labels',{lbl},'tau1',tau1,'tauCI',[lo hi],'sdWithin',sdW, ...
            'sdBetween',sdB,'meanWithin',mW,'ratio',ratio,'X',X, ...
            'selfR2',mean(dg,'omitnan'),'swapR2',mean(offd,'omitnan'), ...
            'figs',[figA figB figC figD]);

if opts.export
    if ~exist(outDir,'dir'), mkdir(outDir); end
    sfx = opts.tag;  if ~isempty(sfx) && sfx(1) ~= '_', sfx = ['_' sfx]; end
    % Export only the panels that were actually drawn -- a stale PDF left on disk from a
    % previous run is worse than a missing one, because assembly cannot tell them apart.
    if ~isempty(figA), paperExport(figA, fullfile(outDir, sprintf('tf_tau_forest%s.pdf',      sfx))); end
    if ~isempty(figB), paperExport(figB, fullfile(outDir, sprintf('tf_tau_variability%s.pdf', sfx))); end
    if ~isempty(figC), paperExport(figC, fullfile(outDir, sprintf('tf_tau_vs_amp%s.pdf',      sfx))); end
    if ~isempty(figD), paperExport(figD, fullfile(outDir, sprintf('tf_model_swap%s.pdf',      sfx))); end
end

fprintf('\n---- [TF-ROBUST] the four numbers this block reports -------------------------\n');
fprintf('  tau_slow          : mean %.3f s  (between-session SD %.3f s)\n', mean(tau1,'omitnan'), sdB);
fprintf('  within-session SD : %.3f s (mean of the trial bootstraps)\n', mW);
fprintf('  ratio             : %.2f  -> %s\n', ratio, i_verdict(ratio));
fprintf('  model swap R^2    : self %.3f  vs  cross-session %.3f  (drop %.3f)\n', ...
        mean(dg,'omitnan'), mean(offd,'omitnan'), mean(dg,'omitnan')-mean(offd,'omitnan'));
fprintf('  => %s\n', i_swapVerdict(mean(dg,'omitnan'), mean(offd,'omitnan')));
end

function s = i_verdict(r)
if ~isfinite(r),  s = 'no bootstrap CI -- cannot separate real spread from fit noise';
elseif r < 1.5,   s = 'consistent with ONE shared time constant';
elseif r < 3,     s = 'mild inter-session variability';
else,             s = 'GENUINE inter-session variability -- report tau as a range, and lean on per-session tuning';
end
end

function s = i_swapVerdict(selfR2, swapR2)
d = selfR2 - swapR2;
if ~isfinite(d),   s = 'swap matrix incomplete';
elseif d < 0.05,   s = 'models are INTERCHANGEABLE -- a design transfers across sessions unchanged';
elseif d < 0.15,   s = 'models transfer with a small penalty -- per-session tuning closes it';
else,              s = 'models do NOT transfer -- per-session identification is REQUIRED, say so in Methods';
end
end
