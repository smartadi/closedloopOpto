function cp_cont_state(tag, xlab, x, AGL, dv, devP, okMask, R, fname)
% cp_cont_state — continuous brain-state effect on the residual (CP-VAR / CP-DELTA).
% Used by contra_prediction.m. Prints the decisive partial test
%   partial(DV, state | dev_pre)     DV = L1-dev (PRIMARY), passed by caller
% (state-dependence of the LOCAL stim response beyond contra-prediction quality)
% plus the Actual/Global/Local decomposition of where the effect lives, and draws:
%   cols 1-3 — DV (L1-dev) vs state for Actual / Global / Local (scatter + trend)
%   col  4   — Local L1-dev vs state quintiles (dose-response)
%
% tag    short label for prints/title (e.g. 'PreVar')      | xlab  axis label (TeX ok)
% x      [nT x 1] state vector                              | AGL   {3x2} {name, L1-dev} from cp_agl
% dv/devP    primary DV (R.devL1) / dev_pre control (R.devP)| okMask finite+low-motion mask (R.okV/R.okD)
% R      cp_residual_core output (for paper_root + labels)  | fname output png name
[rS,pS] = corr(dv(okMask), x(okMask), 'type','Spearman','rows','complete');
[rP,pP] = corr(devP(okMask), x(okMask), 'type','Spearman','rows','complete');
[rA,pA] = partialcorr(dv(okMask), x(okMask), devP(okMask), 'type','Spearman','rows','complete');
fprintf('\n[CP-%s] L1-dev rho=%+.3f p=%.2g | dev_pre rho=%+.3f p=%.2g | PARTIAL(L1|pre) rho=%+.3f p=%.2g (n=%d)\n', ...
    tag, rS,pS, rP,pP, rA,pA, sum(okMask));
rr = nan(1,3);
for c = 1:3, m = okMask & isfinite(AGL{c,2}); rr(c) = corr(AGL{c,2}(m), x(m),'type','Spearman','rows','complete'); end
fprintf('  L1-dev vs %s:  Actual %+.3f | Global %+.3f | Local %+.3f\n', tag, rr(1), rr(2), rr(3));

compClr = [0.20 0.20 0.20; 0.15 0.40 0.80; 0.85 0.20 0.20];   % Actual / Global / Local
fig = figure('Color','w','Name',sprintf('CP-%s',tag), ...
    'Units','pixels','Position',[50 90 1560 430]);
for c = 1:3
    ax = subplot(1,4,c); hold(ax,'on');
    m = okMask & isfinite(AGL{c,2});  xv = x(m);  yv = AGL{c,2}(m);
    scatter(ax, xv, yv, 16, [0.6 0.6 0.6], 'filled', 'MarkerFaceAlpha',0.30);
    if numel(xv) > 2
        pc = polyfit(xv,yv,1);  xl = [min(xv) max(xv)];
        plot(ax, xl, polyval(pc,xl), '-', 'Color',compClr(c,:), 'LineWidth',2.2);
    end
    yline(ax, 1, ':', 'Color',[0.5 0.5 0.5]);   % 1 = amplitude-average trial
    title(ax, sprintf('%s   \\rho=%+.2f', AGL{c,1}, rr(c)), 'FontSize',13,'FontWeight','bold','Color',compClr(c,:));
    set(ax,'Box','off','TickDir','out','FontSize',12);  grid(ax,'on');
    xlabel(ax, xlab, 'FontSize',13,'FontWeight','bold');
    if c==1, ylabel(ax, 'L1-dev (\times amp-avg)', 'FontSize',13,'FontWeight','bold'); end
end
ax4 = subplot(1,4,4); hold(ax4,'on');                 % Local dose-response (state quintiles)
m = okMask & isfinite(AGL{3,2});  xv = x(m);  yv = AGL{3,2}(m);
edges = quantile(xv, 0:0.2:1);  bin = discretize(xv, edges);
bc = nan(1,5); bm = nan(1,5); bse = nan(1,5);
for b = 1:5
    sel = bin == b;
    bc(b) = mean(xv(sel),'omitnan'); bm(b) = mean(yv(sel),'omitnan'); bse(b) = std(yv(sel),'omitnan')/sqrt(max(sum(sel),1));
end
errorbar(ax4, bc, bm, bse, '-o', 'Color',[0.85 0.2 0.1], 'MarkerFaceColor',[0.85 0.2 0.1], 'LineWidth',2.0, 'MarkerSize',7, 'CapSize',8);
yline(ax4, 1, ':', 'Color',[0.5 0.5 0.5]);   % 1 = amplitude-average trial
set(ax4,'Box','off','TickDir','out','FontSize',12);  grid(ax4,'on');
xlabel(ax4, xlab, 'FontSize',13,'FontWeight','bold'); ylabel(ax4, 'Local L1-dev (\times amp-avg)', 'FontSize',13,'FontWeight','bold');
title(ax4, 'Local dose-response (quintiles)', 'FontSize',13,'FontWeight','bold','Color',compClr(3,:));
sgtitle(fig, sprintf('CP-%s on residual  %s %s e%d   —   cols 1-3 = Actual / Global / Local (L1-dev vs state);   col 4 = Local dose-response', ...
    tag, R.mn, R.td, R.en), 'FontSize',14,'FontWeight','bold','Interpreter','tex');
exportgraphics(fig, fullfile(R.paper_root,'images','figure2',fname), 'Resolution',200);
fprintf('[CP-%s] Exported %s\n', tag, fname);

% ---- explainer ------------------------------------------------------------------
fprintf('  HOW TO READ [CP-%s]: cols 1-3 = L1-dev (predictability; lower=more predictable) vs %s\n', tag, tag);
fprintf('  for Actual / Global / Local. Effect in Actual+Global that COLLAPSES in Local => GLOBAL/network;\n');
fprintf('  survives in Local => genuinely local. Decisive test = PARTIAL(L1|pre) rho=%+.3f p=%.2g (col-3 slope after\n', rA, pA);
fprintf('  removing prediction-quality). NOTE: L1-dev carries var(y), so raw %s-vs-L1 is partly a power confound.\n', tag);
end
