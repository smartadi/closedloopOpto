function plot_window(tlo, t_ax, y_j, X_j, beta, pY, pX, r2, label_str, col_pred)
% Plot one pre-stim window: actual vs predicted, with R² in title.
    [Phi_j, yo_j] = buildLagMatrix(y_j, X_j, pY, pX);
    yp_j = Phi_j * beta;
    ax   = nexttile(tlo);
    hold(ax,'on');
    plot(ax, t_ax, yo_j, 'Color',[0.1 0.1 0.1],'LineWidth',0.8,'DisplayName','Actual');
    plot(ax, t_ax, yp_j, 'Color',col_pred,      'LineWidth',0.8,'LineStyle','--','DisplayName','Predicted');
    yline(ax, 0, 'k:', 'LineWidth',0.4,'HandleVisibility','off');
    hold(ax,'off');
    set(ax,'Box','off','TickDir','out','FontSize',6,'FontWeight','bold');
    xlabel(ax,'Time re onset (s)','FontSize',6,'FontWeight','bold');
    r2_str = 'n/a';
    if isfinite(r2); r2_str = sprintf('%.2f',r2); end
    title(ax, sprintf('%s  R^2=%s', label_str, r2_str),'FontSize',6,'FontWeight','bold');
end
