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
%
% OUTPUT
%   RB     struct: tau1, sdBetween, sdWithin, ratio, X (swap matrix), labels, figs.

if nargin < 3, opts = struct(); end
if ~isfield(opts,'tag'),      opts.tag      = '';    end
if ~isfield(opts,'export'),   opts.export   = true;  end
if ~isfield(opts,'amp_norm'), opts.amp_norm = true;  end

PS = paperStyle();
ok = cellfun(@(s) isstruct(s) && isfield(s,'ok') && s.ok && ~isempty(s.h), S);
S  = S(ok);
n  = numel(S);
assert(n >= 2, '[TFROBUST] need >=2 usable session fits for a variability panel.');

lbl  = cellfun(@(s) string(s.label), S);
grad = @(k) [0 0 0] + (0.62*(k-1)/max(n-1,1));

tau1 = nan(n,1); lo = nan(n,1); hi = nan(n,1); sdW = nan(n,1);
for k = 1:n
    if ~isempty(S{k}.tau), tau1(k) = S{k}.tau(1); end
    if isfield(S{k},'tauCI') && ~isempty(S{k}.tauCI), lo(k)=S{k}.tauCI(1); hi(k)=S{k}.tauCI(2); end
    if isfield(S{k},'tauSD') && ~isempty(S{k}.tauSD), sdW(k)=S{k}.tauSD(1); end
end
sdB   = std(tau1,'omitnan');
mW    = mean(sdW,'omitnan');
ratio = sdB / mW;

%% ---- TF-A : tau forest -------------------------------------------------------------
figA = paperFig(4, 4);  axA = axes(figA); hold(axA,'on');
mu = mean(tau1,'omitnan');
if isfinite(mu) && isfinite(sdB)
    patch(axA, [mu-sdB mu+sdB mu+sdB mu-sdB], [0.4 0.4 n+0.6 n+0.6], [.86 .86 .86], ...
        'EdgeColor','none','FaceAlpha',0.6);
    xline(axA, mu, '-', 'Color',[.45 .45 .45], 'LineWidth', PS.lw_ref);
end
for k = 1:n
    if isfinite(lo(k)) && isfinite(hi(k))
        plot(axA, [lo(k) hi(k)], [k k], '-', 'Color', grad(k), 'LineWidth', PS.lw_fit);
    end
    plot(axA, tau1(k), k, 'o', 'MarkerSize',3.5, 'MarkerFaceColor',grad(k), 'MarkerEdgeColor',grad(k));
end
ylim(axA,[0.4 n+0.6]);  set(axA,'YTick',1:n,'YTickLabel',lbl);
xlabel(axA,'\tau_{slow} (s)');
set(axA,'FontSize',PS.fs,'FontWeight',PS.fw,'TickDir','out','Box','off');

%% ---- TF-B : is the spread real? -----------------------------------------------------
figB = paperFig(4, 4);  axB = axes(figB); hold(axB,'on');
bar(axB, 1, sdB, 0.6, 'FaceColor',[.30 .30 .30], 'EdgeColor','none');
bar(axB, 2, mW,  0.6, 'FaceColor',[.72 .72 .72], 'EdgeColor','none');
% Per-session within-SD as dots over the mean bar: shows the "within" bar is an
% average of n numbers, not a single measurement.
for k = 1:n
    if isfinite(sdW(k))
        plot(axB, 2, sdW(k), 'o', 'MarkerSize',2.6, 'MarkerFaceColor',grad(k), 'MarkerEdgeColor','none');
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

%% ---- TF-C : does tau move with drive, within a session? -----------------------------
figC = paperFig(5, 4);  axC = axes(figC); hold(axC,'on');
for k = 1:n
    if ~isfield(S{k},'tau_amp') || isempty(S{k}.tau_amp), continue; end
    ta = S{k}.tau_amp(:,1);  ua = S{k}.uA(:);
    m  = min(numel(ta), numel(ua));  ta = ta(1:m); ua = ua(1:m);
    v  = isfinite(ta) & isfinite(ua) & ua > 0;
    if nnz(v) < 2, continue; end
    x = ua(v);  if opts.amp_norm, x = x/max(x); end
    plot(axC, x, ta(v), '-o', 'Color',grad(k), 'MarkerSize',2.6, ...
        'MarkerFaceColor',grad(k), 'MarkerEdgeColor','none', 'LineWidth',PS.lw_fit);
end
if isfinite(mu), yline(axC, mu, '--', 'Color',[.45 .45 .45], 'LineWidth',PS.lw_ref); end
if opts.amp_norm, xlabel(axC,'laser amplitude (norm.)'); else, xlabel(axC,'laser amplitude (V)'); end
ylabel(axC,'\tau_{slow} (s)');
set(axC,'FontSize',PS.fs,'FontWeight',PS.fw,'TickDir','out','Box','off');

%% ---- TF-D : cross-session model swap ------------------------------------------------
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
figD = paperFig(4.5, 4);  axD = axes(figD);
imagesc(axD, X, [0 1]); axis(axD,'square'); colormap(axD, flipud(gray));
set(axD,'XTick',1:n,'XTickLabel',lbl,'YTick',1:n,'YTickLabel',lbl, ...
    'FontSize',PS.fs,'FontWeight',PS.fw,'TickDir','out');
xtickangle(axD,45);
xlabel(axD,'applied to session'); ylabel(axD,'model from session');
cb = colorbar(axD); cb.Label.String = 'R^2 (free gain)';
cb.FontSize = PS.fs; cb.Label.FontSize = PS.fs; cb.Label.FontWeight = PS.fw;
% Annotate each cell so the panel is readable in print, not just on screen.
for i = 1:n
    for j = 1:n
        if ~isfinite(X(i,j)), continue; end
        tc = [0 0 0]; if X(i,j) > 0.6, tc = [1 1 1]; end
        text(axD, j, i, sprintf('%.2f', X(i,j)), 'HorizontalAlignment','center', ...
            'FontSize',PS.fs-1,'FontWeight',PS.fw,'Color',tc);
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
    paperExport(figA, fullfile(outDir, sprintf('tf_tau_forest%s.pdf',   sfx)));
    paperExport(figB, fullfile(outDir, sprintf('tf_tau_variability%s.pdf', sfx)));
    paperExport(figC, fullfile(outDir, sprintf('tf_tau_vs_amp%s.pdf',   sfx)));
    paperExport(figD, fullfile(outDir, sprintf('tf_model_swap%s.pdf',   sfx)));
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
