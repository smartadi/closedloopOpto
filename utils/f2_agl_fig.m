function fh = f2_agl_fig(D, opt)
%F2_AGL_FIG  Per-amplitude trial-averaged Actual / Global / Local traces, plus the catch tile.
%
% One tile per amplitude showing the three traces the whole decomposition rests on:
%   Actual  (black)  the ipsi site, trial-averaged, baseline-subtracted over the pre-window
%   Global  (red)    the contra prediction b'z, the SAME weight vector at every amplitude
%   Local   (blue)   Actual - Global, i.e. the claimed local stim effect
%
% *** WHY THE Y-AXIS IS SHARED ACROSS TILES, INCLUDING CATCH ***
% Per-tile autoscaling makes a 0.003 dF/F non-response look identical to a 1.4 dF/F response, and
% makes the catch tile -- which MUST be flat -- look like it has structure. One scale for the whole
% session is the only presentation in which "this amplitude did nothing" and "the no-stim control is
% empty" are visible rather than hidden. Set opt.share_y=false only to inspect a single weak amp.
%
% The catch tile is drawn by the SAME code path as the amp tiles (local_tile), so the comparison it
% exists to support is a fair one. It is placed last and outlined so it cannot be misread as an amp.
%
% INPUT  D    the struct returned by f2_decomp (needs .trA/.trG/.trL, .rel, .dcc, .amps, .nT_amp,
%             .capPct, .ampOK, .preN, .catch, .label)
% OPTS   .export ('')      directory for a 300-dpi PNG (diagnostic, NOT a paper panel)
%        .share_y (true)   common y-limits across every tile
%        .xlim ([-0.4 0.8])
% OUTPUT fh   figure handle
% -------------------------------------------------------------------------------------------------
if nargin < 2, opt = struct(); end
def = struct('export','', 'share_y',true, 'xlim',[-0.4 0.8]);
fn = fieldnames(def);
for i = 1:numel(fn)
    if ~isfield(opt,fn{i}), opt.(fn{i}) = def.(fn{i}); end
end

% D.rel is in FRAMES (e.g. -18..35), not seconds -- convert once, here. Plotting it raw against a
% seconds-scaled xlim silently shows a one-frame sliver instead of erroring.
tt   = D.rel(:) / D.Fs;
nA   = numel(D.trA);
have = find(~cellfun(@isempty, D.trA(:)).');
hasCatch = isfield(D,'catch') && ~isempty(D.catch) && ~isempty(D.catch.trA);
nT   = numel(have) + hasCatch;

% ---- shared limits, computed over EVERYTHING that will be drawn ---------------------------------
if opt.share_y
    allv = [];
    for a = have, allv = [allv; D.trA{a}(:); D.trG{a}(:); D.trL{a}(:)]; end %#ok<AGROW>
    if hasCatch, allv = [allv; D.catch.trA(:); D.catch.trG(:); D.catch.trL(:)]; end
    pad = 0.08*max(range(allv), eps);
    yl  = [min(allv)-pad, max(allv)+pad];
else
    yl = [];
end

nCol = min(5, nT);  nRow = ceil(nT/nCol);
fh = figure('Color','w','Position',[60 60 300*nCol 230*nRow]);
tl = tiledlayout(fh, nRow, nCol, 'TileSpacing','compact', 'Padding','compact');

for q = 1:numel(have)
    a  = have(q);
    ax = nexttile(tl); hold(ax,'on'); box(ax,'off');
    local_tile(ax, tt, D.trA{a}, D.trG{a}, D.trL{a}, D.dcc{a}, D.preN, yl, opt.xlim);

    % Non-responding amps are LABELLED, never dropped: a reader must be able to see that the
    % capture ratio for that row was excluded from the median because Actual was ~0, not because
    % the trace was inconvenient.
    ok  = ~isfield(D,'ampOK') || D.ampOK(a);
    ttl = sprintf('%.2f V   n=%d', D.amps(a), D.nT_amp(a));
    if ok, ttl = sprintf('%s   cap %.0f%%', ttl, D.capPct(a));
    else,  ttl = sprintf('%s   (no response)', ttl);
    end
    title(ax, ttl, 'FontWeight', local_tern(ok,'bold','normal'), ...
          'Color', local_tern(ok,[0 0 0],[.45 .45 .45]), 'FontSize',9);

    if q == 1
        % ItemTokenSize is not accepted as a legend() construction argument in every release --
        % set it on the handle afterwards so this works regardless of MATLAB version.
        lg = legend(ax, {'Actual (ipsi)','Global (contra pred.)','Local (residual)'}, ...
                    'Location','southeast','FontSize',7,'Box','off');
        try, lg.ItemTokenSize = [10 6]; catch, end %#ok<CTCH>
    end
end

if hasCatch
    ax = nexttile(tl); hold(ax,'on'); box(ax,'on');
    local_tile(ax, tt, D.catch.trA, D.catch.trG, D.catch.trL, D.dcc{have(1)}, D.preN, yl, opt.xlim);
    set(ax,'XColor',[.2 .5 .2],'YColor',[.2 .5 .2],'LineWidth',1.2);
    title(ax, sprintf('CATCH %s   n=%d   (%.0f%% of stim Local)', D.catch.kind, D.catch.nT, ...
          100*D.catch.ratio), 'FontSize',9,'Color',[.15 .45 .15]);
end

xlabel(tl, 'time from stim onset (s)', 'FontSize',10);
ylabel(tl, '\DeltaF/F (%)', 'FontSize',10);
ttl = {sprintf('%s  |  per-amp trial-averaged Actual / Global / Local', D.label)};
if isfield(D,'caveat') && ~isempty(D.caveat)
    ttl{2} = ['[' D.caveat ']'];    % own line: as a suffix it runs off the canvas and is lost
end
title(tl, ttl, 'FontSize',11, 'FontWeight','bold', 'Interpreter','none');

if ~isempty(opt.export)
    if ~exist(opt.export,'dir'), mkdir(opt.export); end
    tag = regexprep(D.label, '[^A-Za-z0-9]+', '_');
    f = fullfile(opt.export, sprintf('f2_agl_%s.png', tag));
    exportgraphics(fh, f, 'Resolution', 300);      % PNG: diagnostic, not a paper panel
    fprintf('[F2-AGL] saved %s\n', f);
end
end

% -------------------------------------------------------------------------------------------------
function local_tile(ax, tt, Aq, Gq, Lq, dc, preN, yl, xl)
if isempty(Aq), text(ax,0.5,0.5,'n/a','HorizontalAlignment','center'); axis(ax,'off'); return; end
if isempty(yl), yl = [min([Aq;Gq;Lq])-0.15, max([Aq;Gq;Lq])+0.15]; end
if isempty(dc), dc = (preN+1):numel(tt); end
patch(ax, [tt(dc(1)) tt(dc(end)) tt(dc(end)) tt(dc(1))], [yl(1) yl(1) yl(2) yl(2)], ...
      [.85 .92 1], 'EdgeColor','none','FaceAlpha',0.7,'HandleVisibility','off');
plot(ax, tt, Aq, 'k-','LineWidth',1.5);
plot(ax, tt, Gq, '-','Color',[.85 .2 .2],'LineWidth',1.2);
plot(ax, tt, Lq, '-','Color',[.1 .4 .85],'LineWidth',1.3);
xline(ax,0,'k:','HandleVisibility','off'); yline(ax,0,'k:','HandleVisibility','off');
xlim(ax, xl); ylim(ax, yl);
end

function s = local_tern(c,a,b)
if c, s = a; else, s = b; end
end
