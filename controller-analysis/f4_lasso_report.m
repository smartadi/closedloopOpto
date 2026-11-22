% controller-analysis/f4_lasso_report.m
% Fig 4H with the lasso predictor: report figures and table (research-hub #100, RESEARCH L-2026-11-22-c).
% Display only, no test (Aditya 2026-11-22: "we can skip the significance tests here and just do
% reporting style figure and writeup"). Every number comes from ctrl_sparse_kernel_cl.m and f4_rr_diag.m
% (math approved 2026-11-21, L-2026-11-21-a, -b, -g); the Actual is paired with V by time
% (utils/ctrl_pair_on_v.m, L-2026-11-22-b).
% Fig 1 (_preview/f4_lasso_report_summary.png), per session, lasso:
%   A  test R^2 of the fit, and R^2 on the spot ([-1,0) s, A vs G, trials pooled) on OL and CL trials
%   B  session geometric-mean RR on CL trials (Fig 4H), and the OL placebo RR (same ratio, no loop)
%   C  calibration slope beta of the OL fluctuation on D (1 = D has the size of the site's own fluctuation)
% Fig 2 (_preview/f4_lasso_report_trials.png), per session one OL and one CL trial: Actual and lasso
%   Global, each minus its own [-1,0) s mean (as Gr in Fig 4H), from -1 s to the end of stimulation.
%   Shown trial: the one whose sum over [-1,0) s of (Ar - Gr)^2 is nearest the session median (display
%   choice; ties to the earlier trial). Grey: [-1,0) s (reconstruction window) and (1,3] s (RR window).
% OUT controller-analysis/data/f4_lasso_report.csv, _preview/f4_lasso_report_summary.png,
%     _preview/f4_lasso_report_trials.png (PNG: not paper panels)
root = 'C:\Users\aditya\Documents\projects\brain_paper';
dd = fullfile(root, 'controller-analysis', 'data');  outview = fullfile(root, 'controller-analysis', '_preview');
addpath(fullfile(root, 'utils'));  PS = paperStyle();  cG = [0.45 0.45 0.45];
Q = readtable(fullfile(dd, 'f4_rr_diag.csv'));
lab = cellfun(@(s) strrep(paper_session_label(s), 'Mouse ', ''), Q.session, 'UniformOutput', false);
[~, ord] = sort(lab);  Q = Q(ord, :);  lab = lab(ord);  n = height(Q);  g = logical(Q.in4H);
CC = cell(n, 1);
for i = 1:n
    S = load(fullfile(dd, sprintf('ctrl_sparse_kernel_cl_%s.mat', Q.session{i})));  CC{i} = S.C;
    assert(isfield(CC{i}.trial, 'Gcl'), '%s: rerun ctrl_sparse_kernel_cl.m (no CL Global)', Q.session{i});
end
CC = [CC{:}];
T = table(Q.session, lab, g, Q.nOL, Q.nCL, [CC.R2te_lasso]', [CC.R2preOL_lasso]', [CC.R2preCL_lasso]', ...
    Q.RRcl_3, Q.RRol_3, Q.beta_3, 'VariableNames', {'session', 'label', 'in4H', 'nOL', 'nCL', 'R2_test', ...
    'R2_spot_OL', 'R2_spot_CL', 'RR_CL', 'RR_OL_placebo', 'beta'});
writetable(T, fullfile(dd, 'f4_lasso_report.csv'));
disp(T);

% ---- Fig 1: summary ----
fig = figure('Color', 'w', 'Units', 'centimeters', 'Position', [2 2 12 13.2], 'Visible', 'off');
x = 1:n;  xl = [0.4 n+0.6];
a1 = axes(fig, 'Units', 'centimeters', 'Position', [1.6 9.0 9.8 3.4]);  hold(a1, 'on');
h0 = plot(a1, x, T.R2_test, 's', 'MarkerSize', 4, 'MarkerFaceColor', cG, 'MarkerEdgeColor', cG);
h1 = plot(a1, x - 0.15, T.R2_spot_OL, 'o', 'MarkerSize', 3.5, 'MarkerFaceColor', PS.col_ol, 'MarkerEdgeColor', PS.col_ol);
h2 = plot(a1, x + 0.15, T.R2_spot_CL, 'o', 'MarkerSize', 3.5, 'MarkerFaceColor', PS.col_cl, 'MarkerEdgeColor', PS.col_cl);
set(a1, 'XLim', xl, 'YLim', [0.45 1], 'XTick', x, 'XTickLabel', {});
ylabel(a1, 'R^2', 'FontSize', 7, 'FontWeight', 'bold');
lg = legend(a1, [h0 h1 h2], {'test (spontaneous)', 'on the spot, OL', 'on the spot, CL'}, 'FontSize', 6, 'Box', 'off', ...
    'Location', 'southwest', 'NumColumns', 3);  lg.ItemTokenSize = [6 6];
title(a1, 'A  Trial reconstruction (lasso Global)', 'FontSize', 7, 'FontWeight', 'bold', 'HorizontalAlignment', 'left', 'Position', [xl(1) 1.0]);
a2 = axes(fig, 'Units', 'centimeters', 'Position', [1.6 4.95 9.8 3.4]);  hold(a2, 'on');
plot(a2, xl, [1 1], '--', 'Color', [0.4 0.4 0.4], 'LineWidth', 0.5);
for i = 1:n, plot(a2, [i i], [T.RR_CL(i) T.RR_OL_placebo(i)], '-', 'Color', [0.78 0.78 0.78], 'LineWidth', 0.5); end
h3 = plot(a2, x(g), T.RR_CL(g), 'o', 'MarkerSize', 3.5, 'MarkerFaceColor', PS.col_cl, 'MarkerEdgeColor', PS.col_cl);
plot(a2, x(~g), T.RR_CL(~g), 'o', 'MarkerSize', 3.5, 'MarkerFaceColor', 'w', 'MarkerEdgeColor', PS.col_cl);
h4 = plot(a2, x, T.RR_OL_placebo, 'o', 'MarkerSize', 3.5, 'MarkerFaceColor', 'w', 'MarkerEdgeColor', PS.col_ol);
yt = [0.3 0.5 1 2 3];
set(a2, 'YScale', 'log', 'XLim', xl, 'YLim', [0.3 3.6], 'YTick', yt, 'YTickLabel', compose('%g', yt), 'XTick', x, 'XTickLabel', {});
ylabel(a2, 'RR', 'FontSize', 7, 'FontWeight', 'bold');
lg = legend(a2, [h3 h4], {'CL (open: outside the 4H offset gate)', 'OL placebo (no loop)'}, 'FontSize', 6, 'Box', 'off', ...
    'Location', 'northwest');  lg.ItemTokenSize = [6 6];
title(a2, 'B  Disturbance rejection, 1-3 s', 'FontSize', 7, 'FontWeight', 'bold', 'HorizontalAlignment', 'left', 'Position', [xl(1) 3.6]);
a3 = axes(fig, 'Units', 'centimeters', 'Position', [1.6 0.9 9.8 3.4]);  hold(a3, 'on');
plot(a3, xl, [1 1], '--', 'Color', [0.4 0.4 0.4], 'LineWidth', 0.5);
plot(a3, x(g), T.beta(g), 's', 'MarkerSize', 4, 'MarkerFaceColor', 'k', 'MarkerEdgeColor', 'k');
plot(a3, x(~g), T.beta(~g), 's', 'MarkerSize', 4, 'MarkerFaceColor', 'w', 'MarkerEdgeColor', 'k');
set(a3, 'XLim', xl, 'YLim', [0.6 1.4], 'XTick', x, 'XTickLabel', lab);
ylabel(a3, '\beta (OL a on D)', 'FontSize', 7, 'FontWeight', 'bold');  xlabel(a3, 'Session (Mouse)', 'FontSize', 7, 'FontWeight', 'bold');
title(a3, 'C  Size of the predicted disturbance', 'FontSize', 7, 'FontWeight', 'bold', 'HorizontalAlignment', 'left', 'Position', [xl(1) 1.4]);
set([a1 a2 a3], 'FontSize', 6, 'TickDir', 'out', 'LineWidth', 0.5, 'Box', 'off', 'Layer', 'top');
exportgraphics(fig, fullfile(outview, 'f4_lasso_report_summary.png'), 'Resolution', 300);  close(fig);

% ---- Fig 2: one OL and one CL trial per session ----
nCol = 4;  nRow = ceil(2*n/nCol);  w = 3.4;  h = 1.75;  px = 4.25;  py = 2.55;  H = py*nRow + 1.4;
fig = figure('Color', 'w', 'Units', 'centimeters', 'Position', [2 1 17.6 H], 'Visible', 'off');
for i = 1:n
    C = CC(i);  Tr = C.trial;  t = C.tt;  bwin = 1:Tr.pre;  wr = Tr.wr;
    sets = {Tr.Aol, Tr.Gol(:,:,2), 'OL', PS.col_ol; Tr.Acl, Tr.Gcl(:,:,2), 'CL', PS.col_cl};
    for c = 1:2
        A = sets{c,1} - mean(sets{c,1}(:,bwin), 2);  G = sets{c,2} - mean(sets{c,2}(:,bwin), 2);
        err = sum((A(:,bwin) - G(:,bwin)).^2, 2);  [~, j] = min(abs(err - median(err)));
        k = 2*(i-1) + c;  r = ceil(k/nCol);  cc = mod(k-1, nCol);
        ax = axes(fig, 'Units', 'centimeters', 'Position', [1.0 + cc*px, H - 0.9 - r*py + (py - h - 0.45), w, h]);  hold(ax, 'on');
        yl = [min([A(j,:) G(j,:)]) max([A(j,:) G(j,:)])];  yl = yl + [-0.1 0.1]*diff(yl);
        patch(ax, [t(1) 0 0 t(1)], yl([1 1 2 2]), [0.93 0.93 0.93], 'EdgeColor', 'none');
        patch(ax, [t(wr(1)) t(wr(end)) t(wr(end)) t(wr(1))], yl([1 1 2 2]), [0.93 0.93 0.93], 'EdgeColor', 'none');
        plot(ax, t, A(j,:), '-', 'Color', sets{c,4}, 'LineWidth', 0.8);
        plot(ax, t, G(j,:), '-', 'Color', 'k', 'LineWidth', 0.8);
        set(ax, 'XLim', [t(1) t(end)], 'YLim', yl, 'FontSize', 6, 'TickDir', 'out', 'LineWidth', 0.5, 'Box', 'off', 'Layer', 'top');
        title(ax, sprintf('%s %s, trial %d of %d', lab{i}, sets{c,3}, j, size(A, 1)), 'FontSize', 6, 'FontWeight', 'bold');
        if cc == 0, ylabel(ax, '%\DeltaF/F', 'FontSize', 6, 'FontWeight', 'bold'); end
        if r == nRow || k + nCol > 2*n, xlabel(ax, 'Time from onset (s)', 'FontSize', 6, 'FontWeight', 'bold'); end
    end
end
annotation(fig, 'textbox', [0.01 1 - 0.9/H 0.98 0.85/H], 'String', ...
    {'Actual (red OL, blue CL) and lasso Global (black), each minus its own -1 to 0 s mean. Grey: -1 to 0 s (reconstruction) and 1 to 3 s (RR).', ...
     'Each panel is the trial whose -1 to 0 s squared error is the session median. Labels are paper sessions (Mouse 1c = AL\_0033\_0212, ...).'}, ...
    'EdgeColor', 'none', 'FontSize', 6, 'Interpreter', 'tex');
exportgraphics(fig, fullfile(outview, 'f4_lasso_report_trials.png'), 'Resolution', 300);  close(fig);
fprintf('[f4-report] wrote data/f4_lasso_report.csv, _preview/f4_lasso_report_summary.png, _preview/f4_lasso_report_trials.png\n');
