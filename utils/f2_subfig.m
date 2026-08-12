function fh = f2_subfig(P, SS, FR, M, opt)
%F2_SUBFIG  Viewer for the stim-evoked SUBSPACE model: spectrum, basis maps, weights, frontier.
%
% This is the figure that replaces staring at a binary affected-pixel mask. What you are checking:
%
%   SPECTRUM   does the stim response actually live in a few directions? A visible elbow means k is
%              read off the data rather than chosen. A flat spectrum means the "stim subspace" is
%              noise and no rank is defensible -- that is a finding, not a tuning problem.
%   BASIS      do V_1, V_2 ... look like plausible stim footprints (coherent, spatially smooth,
%              plausibly located) or like salt-and-pepper noise? This is the check a thresholded
%              mask cannot give you, because thresholding discards exactly this information.
%   WEIGHTS    where the surviving prediction comes from, after the stim directions are penalised.
%   FRONTIER   the R^2 price against held-out capture, with the random-subspace control.
%
% INPUT  P  f2_prep struct   SS  f2_subspace   FR  f2_frontier_sub   M  f2_model (for b)
% OPTS   .export('') directory for a 300-dpi PNG (diagnostic, NOT a paper panel)
%        .nBasis(4)  how many basis vectors to map
% -------------------------------------------------------------------------------------------------
if nargin < 5, opt = struct(); end
if ~isfield(opt,'export'), opt.export = ''; end
if ~isfield(opt,'nBasis'), opt.nBasis = 4; end

nB = min(opt.nBasis, SS.k);
fh = figure('Color','w','Position',[40 40 1650 880]);
T  = tiledlayout(fh, 3, max(4,nB+1), 'TileSpacing','compact','Padding','compact');

%% ---- ROW 1a: singular spectrum ------------------------------------------------------------------
ax = nexttile(T, 1, [1 2]); hold(ax,'on'); box(ax,'on');
sv = SS.sv;  nsh = min(numel(sv), 40);
bar(ax, 1:nsh, sv(1:nsh).^2/sum(sv.^2)*100, 'FaceColor',[.62 .68 .76],'EdgeColor','none');
xline(ax, SS.k+0.5, '-', 'Color',[.85 .2 .2],'LineWidth',1.6,'HandleVisibility','off');
text(ax, SS.k+0.8, max(sv(1:nsh).^2/sum(sv.^2)*100)*0.8, sprintf(' k = %d', SS.k), ...
     'Color',[.85 .2 .2],'FontWeight','bold','FontSize',9);
yyaxis(ax,'right');
plot(ax, 1:nsh, 100*SS.cumvar(1:nsh), '-','Color',[.1 .4 .85],'LineWidth',1.4);
yline(ax, 100*SS.nu, ':','Color',[.1 .4 .85],'HandleVisibility','off');
ylabel(ax,'cumulative %'); ylim(ax,[0 101]);
set(ax,'YColor',[.1 .4 .85]);
yyaxis(ax,'left'); ylabel(ax,'% of stim energy'); xlabel(ax,'singular direction');
set(ax,'YColor',[.35 .35 .35]);
title(ax, sprintf('stim-evoked spectrum  |  \\nu = %.2f \\rightarrow k = %d of %d px', ...
      SS.nu, SS.k, SS.nS), 'FontSize',9,'FontWeight','bold');

%% ---- ROW 1b: how arbitrary is k? ---------------------------------------------------------------
ax = nexttile(T, 3, [1 1]); hold(ax,'on'); box(ax,'on');
plot(ax, SS.nuGrid, SS.kAtNu, '-o','Color',[.2 .2 .2],'LineWidth',1.4,'MarkerFaceColor','w');
plot(ax, SS.nu, SS.k, 'o','Color',[.85 .2 .2],'MarkerFaceColor',[.85 .2 .2],'MarkerSize',8);
xlabel(ax,'\nu (variance explained)'); ylabel(ax,'k');
title(ax, 'k(\nu) - sensitivity of the only new knob', 'FontSize',9,'FontWeight','bold');
grid(ax,'on');

%% ---- ROW 1c: frontier ---------------------------------------------------------------------------
ax = nexttile(T, 4, [1 max(1,nB-2)]); hold(ax,'on'); box(ax,'on');
C = FR.curve;  x = max(C.frac, C.frac(2)/3);            % log axis: fold the 0 point to the left edge
plot(ax, x, C.capVal, '-o','Color',[.1 .4 .85],'LineWidth',1.7,'MarkerSize',3,'DisplayName','capture VAL (held-out trials)');
plot(ax, x, C.capSel, '--','Color',[.55 .70 .95],'LineWidth',1.2,'DisplayName','capture SEL (in-sample)');
plot(ax, x(C.iPick), C.capVal(C.iPick), 'o','Color',[.85 .2 .2],'MarkerFaceColor',[.85 .2 .2],...
     'MarkerSize',9,'DisplayName','pick (knee)');
yline(ax, FR.rand.cap_mean, ':','Color',[.45 .45 .45],'LineWidth',1.3,'DisplayName','random subspace');
set(ax,'XScale','log'); xlabel(ax,'leak penalty (fraction of trace(M)/n)'); ylabel(ax,'capture %');
yyaxis(ax,'right');
plot(ax, x, C.r2, '-','Color',[.2 .55 .3],'LineWidth',1.4,'DisplayName','spont R^2');
if any(isfinite(C.r2pre))
    plot(ax, x, C.r2pre, '-.','Color',[.45 .30 .65],'LineWidth',1.3,'DisplayName','pre-stim R^2');
end
yline(ax, C.r2_floor, ':','Color',[.2 .55 .3],'HandleVisibility','off');
ylabel(ax,'R^2'); set(ax,'YColor',[.2 .55 .3]);
yyaxis(ax,'left'); set(ax,'YColor',[.1 .4 .85]);
legend(ax,'Location','southoutside','FontSize',6,'Box','off','NumColumns',3);
title(ax, sprintf('frontier | price %.4f buys %+.0f pts | random %.0f%%', ...
      FR.r2_price, FR.cap_gain, FR.rand.cap_mean), 'FontSize',9,'FontWeight','bold');

%% ---- ROW 2: the basis vectors, mapped ------------------------------------------------------------
gS = SS.S;
for j = 1:nB
    ax = nexttile(T, max(4,nB+1) + j); hold(ax,'on');
    image(ax, repmat(P.dspImg,[1 1 3])); axis(ax,'image','off'); set(ax,'YDir','reverse');
    v = SS.Vk(:,j);  v = v(:);  vmax = max(abs(v));
    % (:) on the coordinates too -- SS.S is a ROW index vector, so P.dspGc(gS) comes back as a row
    % while v is a column, and scatter rejects the mismatch.
    scatter(ax, P.dspGc(gS(:)), P.dspGr(gS(:)), 8 + 46*abs(v)/max(vmax,eps), v, 'filled', ...
            'MarkerEdgeColor',[.3 .3 .3],'LineWidth',0.15);
    colormap(ax, local_div()); clim(ax, [-vmax vmax]);
    plot(ax, P.dspSc, P.dspSr, 'r+','MarkerSize',12,'LineWidth',1.7);
    title(ax, sprintf('V_%d  (%.0f%% of stim energy)', j, 100*SS.sv(j)^2/sum(SS.sv.^2)), ...
          'FontSize',8.5,'FontWeight','bold');
end

%% ---- ROW 2 last: PIXEL WEIGHT MAP ---------------------------------------------------------------
ax = nexttile(T, max(4,nB+1) + nB + 1); hold(ax,'on');
image(ax, repmat(P.dspImg,[1 1 3])); axis(ax,'image','off'); set(ax,'YDir','reverse');
bPix = M.b(1:P.nG);  act = find(bPix ~= 0);
if ~isempty(act)
    w = bPix(act);  w = w(:);  amax = max(abs(w));
    scatter(ax, P.dspGc(act(:)), P.dspGr(act(:)), 8 + 52*abs(w)/max(amax,eps), w, 'filled', ...
            'MarkerEdgeColor',[.3 .3 .3],'LineWidth',0.15);
    colormap(ax, local_div()); clim(ax, [-amax amax]);
    cb = colorbar(ax); cb.Label.String = 'weight'; cb.FontSize = 7;
end
plot(ax, P.dspSc, P.dspSr, 'r+','MarkerSize',12,'LineWidth',1.7);
title(ax, sprintf('PREDICTOR WEIGHTS (%d px, ungated)', numel(act)), 'FontSize',8.5,'FontWeight','bold');

%% ---- ROW 3: what the basis is built FROM, and what it leaves behind ------------------------------
% Left: the actual vs Global evoked trajectory at the strongest used amplitude, half B (held out).
ax = nexttile(T, 2*max(4,nB+1) + 1, [1 2]); hold(ax,'on'); box(ax,'on');
[~, qStrong] = max(SS.sB);
al = SS.aB{qStrong};  gg = SS.EB{qStrong}.' * M.b(SS.S(:));  ll = al - gg;
tt = (0:numel(al)-1)/P.Fs*1000;
plot(ax, tt, al, 'k-','LineWidth',1.7,'DisplayName','Actual');
plot(ax, tt, gg, '-','Color',[.85 .2 .2],'LineWidth',1.3,'DisplayName','Global');
plot(ax, tt, ll, '-','Color',[.1 .4 .85],'LineWidth',1.4,'DisplayName','Local');
yline(ax,0,'k:','HandleVisibility','off');
xlabel(ax,'ms from onset (full response window)'); ylabel(ax,'\DeltaF/F %');
legend(ax,'Location','best','FontSize',6,'Box','off');
eta = (al.'*gg)/max(al.'*al,eps);
title(ax, sprintf('HELD-OUT half, amp %d: capture %.0f%% over the WHOLE response (dip+rebound)', ...
      SS.ampsUsed(qStrong), 100*(1-eta)), 'FontSize',9,'FontWeight','bold');

% Right: per-amplitude capture on the held-out half, whole-response.
ax = nexttile(T, 2*max(4,nB+1) + 3, [1 max(2,nB-1)]); hold(ax,'on'); box(ax,'on');
capA = nan(1,numel(SS.EB)); capB = nan(1,numel(SS.EB));
for q = 1:numel(SS.EB)
    ga = SS.EA{q}.'*M.b(SS.S(:));  capA(q) = 100*(1 - (SS.aA{q}.'*ga)/max(SS.aA{q}.'*SS.aA{q},eps));
    gb = SS.EB{q}.'*M.b(SS.S(:));  capB(q) = 100*(1 - (SS.aB{q}.'*gb)/max(SS.aB{q}.'*SS.aB{q},eps));
end
xa = P.amps(SS.ampsUsed);  xa = xa(:).';  capA = capA(:).';  capB = capB(:).';
plot(ax, xa, capA, '--s','Color',[.55 .70 .95],'LineWidth',1.2,'MarkerFaceColor','w','DisplayName','half A (used to build V_k)');
plot(ax, xa, capB, '-o','Color',[.1 .4 .85],'LineWidth',1.7,'MarkerFaceColor',[.1 .4 .85],'DisplayName','half B (held out)');
yline(ax,100,'k:','HandleVisibility','off'); yline(ax,0,'k-','HandleVisibility','off');
yline(ax, FR.rand.cap_mean, ':','Color',[.45 .45 .45],'LineWidth',1.3,'DisplayName','random subspace');
xlabel(ax,'amplitude (V)'); ylabel(ax,'capture % (whole response)');
legend(ax,'Location','best','FontSize',6,'Box','off');
title(ax, 'per-amplitude capture - the gap between the curves IS the overfitting', ...
      'FontSize',9,'FontWeight','bold');

ttl = sprintf('%s   |   SUBSPACE-BLIND predictor, UNGATED (no TF detector)', P.label);
if ~isempty(P.caveat), ttl = {ttl, ['[' P.caveat ']']}; end
title(T, ttl, 'FontSize',11,'FontWeight','bold','Interpreter','none');

if ~isempty(opt.export)
    if ~exist(opt.export,'dir'), mkdir(opt.export); end
    f = fullfile(opt.export, sprintf('f2_sub_%s.png', P.sess_tag));
    exportgraphics(fh, f, 'Resolution', 300);       % PNG: diagnostic, not a paper panel
    fprintf('[F2-SUBFIG] saved %s\n', f);
end
end

% -------------------------------------------------------------------------------------------------
function C = local_div()
n = 128;  t = linspace(0,1,n).';  o = ones(n,1);
C = [ t, t, o ; o, flipud(t), flipud(t) ];          % blue -> white -> red, zero is white
end
