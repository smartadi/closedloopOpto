function fh = f2_fitfig(P, A, M, D, opt)
%F2_FITFIG  ONE figure per session that shows what the ipsi predictor actually does.
%
% WHY THIS EXISTS. The stream reported the fit as a number (held-out spont R^2) and never drew it.
% A single R^2 cannot distinguish a predictor that tracks the trace sample-by-sample from one that
% merely gets the slow envelope right and is scored generously by a variance ratio -- and it says
% nothing at all about WHERE the predictors sit or what the evoked decomposition looks like. This
% draws all of it, on one page, per session:
%
%   ROW 1   HELD-OUT SPONTANEOUS FIT -- the actual ipsi trace and the prediction, on frames the fit
%           never saw. This IS the model. If the red does not sit on the black here, no downstream
%           number means anything. Residual underneath on the same scale, so the error is visible
%           rather than inferred from a ratio.
%   ROW 2   pred-vs-actual scatter on the same held-out frames (identity line = perfect; a slope
%           away from 1 is a gain error a variance-ratio R^2 partly forgives) | the WEIGHT MAP,
%           i.e. which contra pixels the prediction is actually built from, and how strongly |
%           the dose curves Actual / Global / Local.
%   ROW 3   per-amplitude evoked decomposition, plus the CATCH control drawn on the SAME axes
%           convention in the last tile. The catch tile is the one to look at first: it should be
%           flat. Anything that looks like a dip there is being manufactured.
%
% Drawn inside the per-session loop while P is still in memory (the held-out design Zte is ~80 MB
% and is deliberately not carried on the result structs).
%
% INPUT   P,A,M,D  the four stage structs for ONE session
%         opt  .nSpont(1500)  held-out samples to draw in row 1
%              .maxAmpTiles(5) per-amp tiles in row 3; excess amps are dropped and REPORTED
%              .export('')    folder -> also save a 300-dpi PNG
% OUTPUT  fh  figure handle
% -------------------------------------------------------------------------------------------------
if nargin < 5, opt = struct(); end
def = struct('nSpont',1500, 'maxAmpTiles',5, 'export','');
fn = fieldnames(def);
for i = 1:numel(fn)
    if ~isfield(opt,fn{i}) || isempty(opt.(fn{i})), opt.(fn{i}) = def.(fn{i}); end
end
nG = P.nG;  b = M.b;  bPix = b(1:nG);  preN = P.preN;  Fs = P.Fs;
tt = P.rel(:)/Fs;

fh = figure('Color','w','Name',sprintf('[F2-FIT] %s', P.label), 'Position',[40 40 1560 900]);
T  = tiledlayout(fh, 3, 6, 'TileSpacing','compact', 'Padding','compact');

%% ---- ROW 1: the held-out spontaneous fit ------------------------------------------------------
% These frames are the interstim segments the model was NOT trained on, concatenated. The x axis is
% therefore sample index, not continuous time -- said on the axis rather than left to be assumed.
yhat = P.muY + P.Zte*b;
n    = min(opt.nSpont, numel(P.yte));
idx  = 1:n;
ax = nexttile(T, 1, [1 6]); hold(ax,'on'); box(ax,'on');
plot(ax, idx, P.yte(idx), 'k-','LineWidth',1.1,'DisplayName','actual ipsi (held out)');
plot(ax, idx, yhat(idx),  '-','Color',[.85 .2 .2],'LineWidth',1.0,'DisplayName','prediction');
res = P.yte(idx) - yhat(idx);
plot(ax, idx, res - (max(P.yte(idx))-min(res)) - 1, '-','Color',[.35 .55 .95],'LineWidth',0.9, ...
     'DisplayName','residual (offset below)');
yline(ax, -(max(P.yte(idx))-min(res)) - 1, 'k:','HandleVisibility','off');
xlim(ax,[1 n]); xlabel(ax,'held-out spontaneous frame (concatenated interstim segments)');
ylabel(ax,'\DeltaF/F %');  legend(ax,'Location','best','FontSize',7,'Box','off');
title(ax, sprintf(['HELD-OUT SPONTANEOUS FIT — R^2 = %.4f   (time-shift null %+.3f)   |   %d predictors, ' ...
    'ridge %.4g%s'], M.r2_spont, M.r2_shift, numel(M.S), M.ridge, ...
    local_tern(M.use_motion,' | +motion regressor','')), 'FontSize',10,'FontWeight','bold');

%% ---- ROW 2a: predicted vs actual ---------------------------------------------------------------
ax = nexttile(T, 7, [1 2]); hold(ax,'on'); box(ax,'on');
ss = unique(round(linspace(1, numel(P.yte), min(6000, numel(P.yte)))));
scatter(ax, P.yte(ss), yhat(ss), 4, [.25 .45 .8], 'filled', 'MarkerFaceAlpha',0.15);
lims = [min([P.yte(ss);yhat(ss)]) max([P.yte(ss);yhat(ss)])];
plot(ax, lims, lims, 'k--','LineWidth',1.1);
pf = polyfit(P.yte(ss), yhat(ss), 1);
plot(ax, lims, polyval(pf,lims), '-','Color',[.85 .2 .2],'LineWidth',1.3);
axis(ax,'square'); xlim(ax,lims); ylim(ax,lims);
xlabel(ax,'actual \DeltaF/F %'); ylabel(ax,'predicted');
title(ax, sprintf('held-out: slope %.3f (1 = no gain error)', pf(1)), 'FontSize',8,'FontWeight','bold');

%% ---- ROW 2b: WHERE the prediction comes from ---------------------------------------------------
ax = nexttile(T, 9, [1 2]); hold(ax,'on');
image(ax, repmat(P.dspImg,[1 1 3])); axis(ax,'image','off'); set(ax,'YDir','reverse');
act = find(bPix ~= 0);
if ~isempty(act)
    w  = bPix(act);  amax = max(abs(w));
    sz = 6 + 60*abs(w)/max(amax,eps);
    scatter(ax, P.dspGc(act), P.dspGr(act), sz, w, 'filled', 'MarkerEdgeColor',[.3 .3 .3],'LineWidth',0.2);
    colormap(ax, local_div());  clim(ax, [-amax amax]);
    cb = colorbar(ax); cb.Label.String = 'weight'; cb.FontSize = 7;
end
% pixels the detector EXCLUDED at any amplitude, so the map shows what was left out as well as in
exc = find(any(A.affected,2));
plot(ax, P.dspGc(exc), P.dspGr(exc), 'x','Color',[.2 .2 .2],'MarkerSize',3,'LineWidth',0.4);
plot(ax, P.dspSc, P.dspSr, 'r+','MarkerSize',13,'LineWidth',1.8);
title(ax, sprintf('predictor weights (%d active) | x = stim-affected, excluded | + = ipsi site', numel(act)), ...
      'FontSize',8,'FontWeight','bold');

%% ---- ROW 2c: dose curves -----------------------------------------------------------------------
ax = nexttile(T, 11, [1 2]); hold(ax,'on'); box(ax,'on');
plot(ax, P.amps, D.Adip, '-o','Color','k','LineWidth',1.7,'MarkerFaceColor','k','DisplayName','Actual');
plot(ax, P.amps, D.Gdip, '-s','Color',[.85 .2 .2],'LineWidth',1.3,'MarkerFaceColor',[.85 .2 .2],'DisplayName','Global (leak)');
plot(ax, P.amps, D.Ldip, '-^','Color',[.1 .4 .85],'LineWidth',1.3,'MarkerFaceColor',[.1 .4 .85],'DisplayName','Local (residual)');
bad = ~D.ampOK;
if any(bad)
    plot(ax, P.amps(bad), D.Adip(bad), 'o','Color',[.5 .5 .5],'MarkerSize',11,'LineWidth',1.2, ...
         'DisplayName','no response (excluded)');
end
yline(ax,0,'k:','HandleVisibility','off');
xlabel(ax,'amplitude (V)'); ylabel(ax,'dip \DeltaF/F %'); legend(ax,'Location','southwest','FontSize',6,'Box','off');
title(ax, sprintf('capture %.0f%% / leak %.0f%% (over %d responding amps)', ...
      D.capMed, D.leakMed, nnz(D.ampOK)), 'FontSize',8,'FontWeight','bold');

%% ---- ROW 3: per-amp evoked decomposition + the CATCH control ------------------------------------
% Amps are chosen from the RESPONDING set and evenly spaced; if more than maxAmpTiles respond, the
% dropped ones are named rather than silently omitted.
ok = find(D.ampOK(:).');
if isempty(ok), ok = 1:P.nA; end
nT_ = min(opt.maxAmpTiles, numel(ok));
pick = ok(unique(round(linspace(1, numel(ok), nT_))));
if numel(ok) > numel(pick)
    fprintf('[F2-FIT] %s: row 3 shows %d of %d responding amps (%s V); dropped %s V\n', ...
        P.label, numel(pick), numel(ok), strjoin(compose('%.2g',P.amps(pick).'),','), ...
        strjoin(compose('%.2g',P.amps(setdiff(ok,pick)).'),','));
end
for q = 1:numel(pick)
    ai = pick(q);
    ax = nexttile(T, 12+q); hold(ax,'on'); box(ax,'on');
    local_agl(ax, tt, D.trA{ai}, D.trG{ai}, D.trL{ai}, P.dcc{ai}, preN);
    title(ax, sprintf('%.2g V  (cap %.0f%%, leak %.0f%%)', P.amps(ai), D.capPct(ai), D.leakPct(ai)), ...
          'FontSize',8,'FontWeight','bold');
    if q == 1
        ylabel(ax,'\DeltaF/F %');
        legend(ax,{'Actual','Global','Local'},'FontSize',5,'Location','southeast','Box','off');
    end
    xlabel(ax,'t re onset (s)');
end
% the control, last tile, same convention -> comparable by eye against the amps beside it
ax = nexttile(T, 18); hold(ax,'on'); box(ax,'on');
local_agl(ax, tt, D.catch.trA, D.catch.trG, D.catch.trL, P.dcc{pick(1)}, preN);
ttl = sprintf('CATCH (%s, n=%d): %+.0f%% of stim Local', D.catch.kind, D.catch.nT, 100*D.catch.ratio);
if abs(D.catch.ratio) > 0.15
    title(ax, ttl, 'FontSize',8,'FontWeight','bold','Color',[.75 0 0]);
else
    title(ax, ttl, 'FontSize',8,'FontWeight','bold','Color',[0 .45 0]);
end
xlabel(ax,'t re onset (s)');

cav = '';  if ~isempty(P.caveat), cav = sprintf('\n⚠ %s', P.caveat); end
title(T, sprintf('%s   —   ipsi predictor from %d stim-UNAFFECTED contra px%s', ...
      P.label, M.nCand, cav), 'FontWeight','bold','FontSize',11);

if ~isempty(opt.export)
    if ~exist(opt.export,'dir'), mkdir(opt.export); end
    f = fullfile(opt.export, sprintf('f2_fit_%s.png', P.sess_tag));
    exportgraphics(fh, f, 'Resolution', 300);      % PNG: diagnostic, not a paper panel
    fprintf('[F2-FIT] saved %s\n', f);
end
end

% -------------------------------------------------------------------------------------------------
function local_agl(ax, tt, Aq, Gq, Lq, dc, preN)
% One Actual / Global / Local panel, with the dip window shaded. Shared so the per-amp tiles and the
% catch tile are drawn identically -- if they were drawn by different code the comparison they exist
% to support would not be a fair one.
if isempty(Aq), text(ax,0.5,0.5,'n/a','HorizontalAlignment','center'); axis(ax,'off'); return; end
yl = [min([Aq;Gq;Lq])-0.15, max([Aq;Gq;Lq])+0.15];
if isempty(dc), dc = (preN+1):numel(tt); end
patch(ax, [tt(dc(1)) tt(dc(end)) tt(dc(end)) tt(dc(1))], [yl(1) yl(1) yl(2) yl(2)], ...
      [.85 .92 1], 'EdgeColor','none','FaceAlpha',0.7,'HandleVisibility','off');
plot(ax, tt, Aq, 'k-','LineWidth',1.5);
plot(ax, tt, Gq, '-','Color',[.85 .2 .2],'LineWidth',1.2);
plot(ax, tt, Lq, '-','Color',[.1 .4 .85],'LineWidth',1.3);
xline(ax,0,'k:','HandleVisibility','off'); yline(ax,0,'k:','HandleVisibility','off');
xlim(ax,[-0.4 0.8]); ylim(ax,yl);
end

function C = local_div()
% Blue-white-red diverging map, so a weight's SIGN is readable at a glance and zero is white.
n = 128;  t = linspace(0,1,n).';  o = ones(n,1);
C = [ t, t, o ; o, flipud(t), flipud(t) ];        % blue -> white -> red
end

function s = local_tern(c,a,b)
if c, s = a; else, s = b; end
end
