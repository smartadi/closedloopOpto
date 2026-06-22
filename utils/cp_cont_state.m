function cp_cont_state(tag, xlab, x, AGL, devS, devP, okMask, R, fname)
% cp_cont_state — continuous brain-state effect on the residual (CP-VAR / CP-DELTA).
% Used by contra_residual.m. Prints the decisive partial test
%   partial(dev_stim, state | dev_pre)
% (state-dependence of the LOCAL stim response beyond contra-prediction quality)
% plus the Actual/Global/Local decomposition of where the effect lives, and draws:
%   cols 1-3 — |dip dev| vs state for Actual / Global / Local (scatter + trend)
%   col  4   — Local |dip dev| vs state quintiles (dose-response)
%
% tag    short label for prints/title (e.g. 'PreVar')      | xlab  axis label (TeX ok)
% x      [nT x 1] state vector                              | AGL   {3x2} {name, |dev|} from cp_agl
% devS/devP  dev_stim / dev_pre (R.devS / R.devP)           | okMask finite+low-motion mask (R.okV/R.okD)
% R      cp_residual_core output (for paper_root + labels)  | fname output png name
[rS,pS] = corr(devS(okMask), x(okMask), 'type','Spearman','rows','complete');
[rP,pP] = corr(devP(okMask), x(okMask), 'type','Spearman','rows','complete');
[rA,pA] = partialcorr(devS(okMask), x(okMask), devP(okMask), 'type','Spearman','rows','complete');
fprintf('\n[CP-%s] dev_stim rho=%+.3f p=%.2g | dev_pre rho=%+.3f p=%.2g | PARTIAL(stim|pre) rho=%+.3f p=%.2g (n=%d)\n', ...
    tag, rS,pS, rP,pP, rA,pA, sum(okMask));
rr = nan(1,3);
for c = 1:3, m = okMask & isfinite(AGL{c,2}); rr(c) = corr(AGL{c,2}(m), x(m),'type','Spearman','rows','complete'); end
fprintf('  |dip dev| vs %s:  Actual %+.3f | Global %+.3f | Local %+.3f\n', tag, rr(1), rr(2), rr(3));

fig = paperFig(22, 6);
for c = 1:3
    ax = subplot(1,4,c); hold(ax,'on');
    m = okMask & isfinite(AGL{c,2});  xv = x(m);  yv = AGL{c,2}(m);
    scatter(ax, xv, yv, 7, [0.5 0.5 0.5], 'filled', 'MarkerFaceAlpha',0.3);
    if numel(xv) > 2
        pc = polyfit(xv,yv,1);  xl = [min(xv) max(xv)];
        plot(ax, xl, polyval(pc,xl), 'r-', 'LineWidth',1.2);
    end
    title(ax, sprintf('%s  \\rho=%+.2f', AGL{c,1}, rr(c)), 'FontSize',6,'FontWeight','bold');
    set(ax,'Box','off','TickDir','out','FontSize',6,'FontWeight','bold');
    xlabel(ax, xlab, 'FontSize',6,'FontWeight','bold');
    if c==1, ylabel(ax, '|dip dev| (z)', 'FontSize',6,'FontWeight','bold'); end
end
ax4 = subplot(1,4,4); hold(ax4,'on');                 % Local dose-response (state quintiles)
m = okMask & isfinite(AGL{3,2});  xv = x(m);  yv = AGL{3,2}(m);
edges = quantile(xv, 0:0.2:1);  bin = discretize(xv, edges);
bc = nan(1,5); bm = nan(1,5); bse = nan(1,5);
for b = 1:5
    sel = bin == b;
    bc(b) = mean(xv(sel),'omitnan'); bm(b) = mean(yv(sel),'omitnan'); bse(b) = std(yv(sel),'omitnan')/sqrt(max(sum(sel),1));
end
errorbar(ax4, bc, bm, bse, '-o', 'Color',[0.85 0.2 0.1], 'MarkerFaceColor',[0.85 0.2 0.1], 'LineWidth',1, 'MarkerSize',4, 'CapSize',4);
set(ax4,'Box','off','TickDir','out','FontSize',6,'FontWeight','bold');
xlabel(ax4, xlab, 'FontSize',6,'FontWeight','bold'); ylabel(ax4, 'Local |dip dev| (z)', 'FontSize',6,'FontWeight','bold');
title(ax4, 'Local dose-response (quintiles)', 'FontSize',6,'FontWeight','bold');
sgtitle(fig, sprintf('CP-%s effect on residual  %s %s e%d  (cols 1-3 Actual/Global/Local; col 4 Local dose-resp)', ...
    tag, R.mn, R.td, R.en), 'FontSize',6,'FontWeight','bold','Interpreter','tex');
paperExport(fig, fullfile(R.paper_root,'images','figure2',fname));
fprintf('[CP-%s] Exported %s\n', tag, fname);
end
