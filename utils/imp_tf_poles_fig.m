function PF = imp_tf_poles_fig(S, outDir, opts)
%IMP_TF_POLES_FIG  Panel TF-E: EVERY time constant of every session, not just the slowest.
%
% =====================================================================================
% WHY THIS PANEL EXISTS
% =====================================================================================
% TF-A reports tau_slow -- one number per session, the slowest stable pole. That is the
% right headline (it sets the settling time the controller has to live with), but on its
% own it hides two things a referee can reasonably ask about:
%
%   1. HOW MANY modes did each session actually need? A session fitted with 2 poles and
%      a session fitted with 4 are not the same claim about "low-order LTI", and TF-A
%      draws them as one dot each. Order is a result, not a setting, and it should be
%      visible on a figure rather than only in a console table.
%   2. Are the FAST modes shared too? If tau_slow agrees across sessions but the fast
%      poles are scattered over a decade, the plants agree only in their tail. That is
%      still fine for a PI design, but it is a weaker statement than "same dynamics",
%      and the figure should not let the stronger one be read in by accident.
%
% So: one row per session, LOG tau axis, one marker per stable pole. The slowest pole is
% drawn filled and large (it is the TF-A dot, so the two panels are visibly the same
% measurement); the remaining poles are smaller and open. The cross-session mean +- SD
% band of tau_slow is kept from TF-A so the eye lands in the same place on both.
%
% LOG AXIS IS NOT COSMETIC. Time constants here span roughly 10 ms to 1 s. On a linear
% axis every fast pole collapses onto the y-axis and the panel would say only what TF-A
% already says. The question "are the fast modes shared" is a question about RATIOS.
%
% COMPLEX POLES ARE MARKED, not silently converted. tau = -1/Re(p) is well defined for a
% complex pair, but a complex pair means the response RINGS, which is a different
% physical statement from an overdamped relaxation, and a conjugate pair contributes TWO
% identical tau values that would otherwise be drawn as two coincident markers implying
% two modes. Conjugates are collapsed to one marker (Im >= 0) and outlined so the panel
% distinguishes "3 relaxations" from "1 relaxation + 1 resonance".
%
% INPUT
%   S      cell array of imp_tf_fit_session outputs. Entries with ok == false skipped.
%   outDir folder for the PDF (created if missing).
%   opts   .tag ''  .export true  .fname 'tf_pole_spectrum'
%
% OUTPUT
%   PF     struct: tau (cell, per session), isComplex (cell), order [n x 3] np/nz/nd,
%          labels (full), fig.
%
% Size 5 x 4 cm, 6 pt bold, blue session ramp -- FIG-2 COLOUR POLICY: across sessions is
% always the blue ramp, and session k is the same shade here as in every other Fig-2 panel.

if nargin < 3, opts = struct(); end
if ~isfield(opts,'tag'),    opts.tag    = '';   end
if ~isfield(opts,'export'), opts.export = true; end
if ~isfield(opts,'fname'),  opts.fname  = 'tf_pole_spectrum'; end

PS = paperStyle();
ok = cellfun(@(s) isstruct(s) && isfield(s,'ok') && s.ok, S);
S  = S(ok);
n  = numel(S);
assert(n >= 1, '[TFPOLES] no usable session fits.');

CS   = PS.sessGrad(n);
lblS = "Session " + string(1:n).';
lbl  = cellfun(@(s) string(s.label), S);

% ---- pull the stable poles, collapse conjugate pairs ------------------------------------
tauC = cell(n,1);  cplx = cell(n,1);  ordM = nan(n,3);
for k = 1:n
    ordM(k,:) = [S{k}.np, S{k}.nz, S{k}.nd];
    p = S{k}.poles(:);
    p = p(real(p) < 0 & isfinite(p));          % same stability rule as T.tau
    p = p(imag(p) >= -1e-9);                   % one marker per conjugate PAIR
    tauC{k} = -1 ./ real(p);
    cplx{k} = abs(imag(p)) > 1e-6;
end

tau1 = cellfun(@(t) i_slowest(t), tauC);
mu   = mean(tau1,'omitnan');  sdB = std(tau1,'omitnan');

%% ---- the panel -------------------------------------------------------------------------
fig = paperFig(5, 4);  ax = axes(fig); hold(ax,'on');
set(ax,'XScale','log');
% Same mean +- SD band as TF-A, so the two panels register against each other by eye.
if isfinite(mu) && isfinite(sdB) && mu-sdB > 0
    patch(ax, [mu-sdB mu+sdB mu+sdB mu-sdB], [0.4 0.4 n+0.6 n+0.6], [.86 .86 .86], ...
        'EdgeColor','none','FaceAlpha',0.6);
    xline(ax, mu, '-', 'Color',[.45 .45 .45], 'LineWidth', PS.lw_ref);
end
for k = 1:n
    t = tauC{k};  c = CS(k,:);
    if isempty(t), continue; end
    [t, iSrt] = sort(t, 'descend');  isC = cplx{k}(iSrt);
    % A hairline through the row's poles: turns "where are the modes" into one glance
    % per session instead of a scatter the reader has to group by colour.
    if numel(t) > 1
        plot(ax, [min(t) max(t)], [k k], '-', 'Color', [c 0.45], 'LineWidth', 0.5);
    end
    for j = 1:numel(t)
        if j == 1                                  % slowest = the TF-A dot
            mk = 'o';  ms = 4.5;  fc = c;
        else                                       % faster modes
            mk = 'o';  ms = 2.8;  fc = [1 1 1];
        end
        if isC(j), mk = 'd'; end                   % complex pair -> the response rings
        plot(ax, t(j), k, mk, 'MarkerSize', ms, 'MarkerFaceColor', fc, ...
            'MarkerEdgeColor', c, 'LineWidth', 0.6);
    end
end
ylim(ax, [0.4 n+0.6]);
% Order printed at the right margin: the panel's second job is to show that model order
% is a RESULT, not a setting. Placed in NORMALISED units -- data coordinates on a log
% axis whose limits are not known until every marker is drawn would clip on any session
% set whose taus happen to run past the anchor.
for k = 1:n
    text(ax, 0.985, (k - 0.4)/(n + 0.2), sprintf('%dp%dz%dd', ordM(k,1), ordM(k,2), ordM(k,3)), ...
        'Units','normalized', 'HorizontalAlignment','right', 'VerticalAlignment','middle', ...
        'FontSize', PS.fs-1, 'FontWeight', PS.fw, 'Color', CS(k,:));
end
set(ax, 'YTick', 1:n, 'YTickLabel', cellstr(lblS), 'TickLabelInterpreter','none');
xlabel(ax, '\tau (s, log scale)');
set(ax, 'FontSize', PS.fs, 'FontWeight', PS.fw, 'TickDir','out', 'Box','off');

% Encoding legend -- session identity is already on the y-axis, so these three rows are
% the only thing a reader cannot deduce from the panel itself.
hS = plot(ax, NaN, NaN, 'o', 'MarkerSize',4.5, 'MarkerFaceColor',[.35 .35 .35], 'MarkerEdgeColor',[.35 .35 .35]);
hF = plot(ax, NaN, NaN, 'o', 'MarkerSize',2.8, 'MarkerFaceColor',[1 1 1],       'MarkerEdgeColor',[.35 .35 .35]);
hC = plot(ax, NaN, NaN, 'd', 'MarkerSize',2.8, 'MarkerFaceColor',[1 1 1],       'MarkerEdgeColor',[.35 .35 .35]);
lg = legend(ax, [hS hF hC], {'\tau_{slow}','faster mode','complex pair'}, ...
            'Location','southeast', 'Box','off');
lg.ItemTokenSize = PS.lgd_token;  lg.FontSize = PS.fs;  lg.FontWeight = PS.fw;

%% ---- export + console ------------------------------------------------------------------
if opts.export
    if ~exist(outDir,'dir'), mkdir(outDir); end
    sfx = opts.tag;  if ~isempty(sfx) && sfx(1) ~= '_', sfx = ['_' sfx]; end
    paperExport(fig, fullfile(outDir, sprintf('%s%s.pdf', opts.fname, sfx)));
end

fprintf('\n---- [TF-POLES] every stable time constant, slowest first --------------------\n');
for k = 1:n
    t = sort(tauC{k},'descend');
    tag = '';
    if any(cplx{k}), tag = '   (contains a COMPLEX pair -> the response rings)'; end
    fprintf('  Session %d  %-24s %dp%dz%dd  tau = %s s%s\n', k, lbl(k), ...
        ordM(k,1), ordM(k,2), ordM(k,3), mat2str(round(t(:).',4)), tag);
end
nMode = cellfun(@numel, tauC);
fprintf('  modes per session : %s  (min %d, max %d)\n', mat2str(nMode(:).'), min(nMode), max(nMode));
if numel(unique(ordM(:,1))) > 1
    fprintf(2,['  ORDER IS NOT SHARED across sessions (np = %s). "Low-order LTI" is still\n' ...
               '        fine, but do not write "the same model" -- write the range.\n'], ...
        mat2str(ordM(:,1).'));
end

PF = struct('tau',{tauC},'isComplex',{cplx},'order',ordM,'labels',{lbl},'fig',fig);
end

% =================================================================================================
function t1 = i_slowest(t)
if isempty(t), t1 = NaN; else, t1 = max(t); end
end
