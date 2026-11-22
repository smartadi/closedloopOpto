% controller-analysis/f4_rr_diag.m
% Fig 4H diagnostic (research-hub #100): does the disturbance D have the right size? Checked on OL trials,
% where no loop acts, for three contra->ipsi kernels: the cached Stage-2 ridge (the paper's), the ridge
% refit on today's data and the lasso.
%
% Math approved by Aditya 2026-11-21: "approve" (method block in the brain_paper session chat;
% RESEARCH L-2026-11-21-g). Diagnostic only: the Fig 4H statistic is unchanged.
% Per session and kernel, OL trials j, settled window W = (1,3] s, baseline [-1,0) s:
%   Ar_j(t) = A_OL,j(t) - mean over [-1,0) s of A_OL,j
%   a_j(t)  = Ar_j(t) - mean over OL trials of Ar(t)            (fluctuation around the mean laser response)
%   Gr_j(t) = G_OL,j(t) - mean over [-1,0) s of G_OL,j
%   D_j(t)  = Gr_j(t) - g_OL, g_OL = mean of Gr over OL trials and W   (built as the CL D, f4_cl_reject_lmm.m)
%   RR_OL,j = sum over W of a_j^2 / sum over W of D_j^2; session geometric mean over finite RR_OL > 0
%   beta    = sum over trials and W of a*D / sum of D^2         (calibration slope of a on D)
%   identity: sum a^2 = beta^2 sum D^2 + sum (a - beta D)^2, so RR_OL (pooled) = beta^2 + unexplained / sum D^2
% Next to them, the CL RR of the same kernel (session geometric mean, as Fig 4H).
% Reading: beta near 1 means D has the size of the site's own fluctuation; beta > 1 means D is too small,
% which inflates RR by about beta^2 whatever the loop does. CL RR below RR_OL means the loop cut the error
% below what the site does without control.
% Needs load_sessions.m (mouse, fields) and ctrl_sparse_kernel_cl.m results with C.trial.Aol (2026-11-21).
% OUT controller-analysis/data/f4_rr_diag.csv, controller-analysis/_preview/f4_rr_diag.png (PNG: not a paper panel)
assert(exist('mouse', 'var') && exist('fields', 'var'), 'run load_sessions.m first');
root = 'C:\Users\aditya\Documents\projects\brain_paper';
here = fullfile(root, 'controller-analysis');  dd = fullfile(here, 'data');  bpData = fullfile(root, 'data');
outview = fullfile(here, '_preview');  addpath(fullfile(root, 'utils'));
CFG = struct('nSV_load', 500, 'Fs', 35, 'pre_s', 1.0, 'resp_s', 3.0);

% planted check: a = D exactly gives beta = 1 and RR_OL = 1
rng(1);  Dp = randn(20, 140);  [bp, rp] = rrdiag_terms(Dp, Dp, 71:140);
assert(abs(bp - 1) < 1e-12 && all(abs(rp - 1) < 1e-12), 'planted check failed');
fprintf('[f4-diag] planted check a = D: beta %.12f, RR_OL %.12f\n', bp, exp(mean(log(rp))));

kn = {'cached ridge', 'ridge refit', 'lasso'};  Q = struct([]);
for s = 1:numel(fields)
    fld = fields{s};  M = mouse.(fld);  mm = mouse;
    if ~isfield(M, 'd') || isempty(M.d)
        pth = fullfile(bpData, sprintf('%sctrl%s%s%d.mat', M.mn, M.td(6:7), M.td(9:10), M.en));
        if ~exist(pth, 'file'), continue; end
        tmp = load(pth);  if ~isfield(tmp, 'd'), continue; end
        mm.(fld).d = tmp.d;  mm.(fld).data = tmp.data;  clear tmp
        if ~isfield(mm.(fld).d, 'ref'), mm.(fld).d.ref = -5; end
    end
    S = imp_build_session(mm, fields, s, dd, CFG);  clear mm
    if ~S.ok, continue; end
    f = fullfile(dd, sprintf('ctrl_sparse_kernel_cl_%s.mat', S.sess_tag));
    if ~exist(f, 'file'), continue; end
    L = load(f);  C = L.C;  Tr = C.trial;
    assert(isfield(Tr, 'Aol'), '%s: rerun ctrl_sparse_kernel_cl.m (no OL arrays)', C.session);
    pre = S.pre;  bwin = 1:pre;  wr = pre + round(1*S.Fs) + 1 : pre + round(CFG.resp_s*S.Fs);
    assert(isequal(wr, Tr.wr) && isequal(pre, Tr.pre), '%s: window mismatch', C.session);
    % kernel 1, cached ridge, from the paper's trial builder; kernels 2-3 from ctrl_sparse_kernel_cl.m
    Aol = {S.Aol, Tr.Aol, Tr.Aol};  Gol = {S.Gol, Tr.Gol(:,:,1), Tr.Gol(:,:,2)};
    Gr = S.Gol - mean(S.Gol(:,bwin), 2);  Dc = S.Gcl - mean(S.Gcl(:,bwin), 2) - mean(mean(Gr(:,wr), 2));
    rrCL = {sum((S.Acl(:,wr) - S.ref).^2, 2) ./ sum(Dc(:,wr).^2, 2), Tr.rr(:,1), Tr.rr(:,2)};
    q = struct('session', C.session, 'label', paper_session_label(C.session), 'in4H', C.in4H, ...
        'nOL', size(S.Aol, 1), 'nCL', size(S.Acl, 1), 'dAol', NaN);
    if isequal(size(S.Aol), size(Tr.Aol)), q.dAol = max(abs(S.Aol(:) - Tr.Aol(:))); end
    for k = 1:3
        Ar = Aol{k} - mean(Aol{k}(:,bwin), 2);  a = Ar - mean(Ar, 1);
        Grk = Gol{k} - mean(Gol{k}(:,bwin), 2);  D = Grk - mean(mean(Grk(:,wr), 2));
        [b, rOL] = rrdiag_terms(a, D, wr);
        q.(sprintf('beta_%d', k)) = b;
        q.(sprintf('RRol_%d', k)) = gm_pos(rOL);
        q.(sprintf('RRcl_%d', k)) = gm_pos(rrCL{k});
    end
    Q = [Q, q]; %#ok<AGROW>
end
QT = struct2table(Q);
writetable(QT, fullfile(dd, 'f4_rr_diag.csv'));
fprintf('\n[f4-diag] per session: CL RR / OL placebo RR / beta, for %s | %s | %s\n', kn{:});
for i = 1:height(QT)
    mk = ' ';  if ~QT.in4H(i), mk = '*'; end
    fprintf('  %-16s %-9s %s nOL %3d | %5.2f %5.2f %5.2f | %5.2f %5.2f %5.2f | %5.2f %5.2f %5.2f | OL A diff %.2g\n', ...
        QT.session{i}, QT.label{i}, mk, QT.nOL(i), QT.RRcl_1(i), QT.RRol_1(i), QT.beta_1(i), ...
        QT.RRcl_2(i), QT.RRol_2(i), QT.beta_2(i), QT.RRcl_3(i), QT.RRol_3(i), QT.beta_3(i), QT.dAol(i));
end
fprintf('  (* outside the Fig 4H offset gate; OL A diff = largest |A_OL| difference, paper builder vs ctrl_sparse_kernel_cl)\n');

% ---- figure: per session, CL RR and OL placebo RR (top), beta (bottom), one column per kernel ----
PS = paperStyle();  [~, ord] = sort(QT.RRcl_1);  QT = QT(ord, :);  g = logical(QT.in4H);  n = height(QT);
lab = strrep(QT.label, 'Mouse ', '');
fig = figure('Color', 'w', 'Units', 'centimeters', 'Position', [2 2 17.6 9.6], 'Visible', 'off');
for k = 1:3
    a1 = axes(fig, 'Units', 'centimeters', 'Position', [1.3 + (k-1)*5.6, 5.4, 4.8, 3.3]);  hold(a1, 'on');
    plot(a1, [0.3 n+0.7], [1 1], '--', 'Color', [0.4 0.4 0.4], 'LineWidth', 0.5);
    rc = QT.(sprintf('RRcl_%d', k));  ro = QT.(sprintf('RRol_%d', k));
    for i = 1:n, plot(a1, [i i], [rc(i) ro(i)], '-', 'Color', [0.75 0.75 0.75], 'LineWidth', 0.5); end
    h1 = plot(a1, 1:n, rc, 'o', 'MarkerSize', 3.5, 'MarkerFaceColor', PS.col_cl, 'MarkerEdgeColor', PS.col_cl);
    h2 = plot(a1, 1:n, ro, 'o', 'MarkerSize', 3.5, 'MarkerFaceColor', 'w', 'MarkerEdgeColor', PS.col_ol);
    set(a1, 'YScale', 'log', 'XLim', [0.3 n+0.7], 'XTick', 1:n, 'XTickLabel', {}, 'FontSize', 6, 'TickDir', 'out', ...
        'LineWidth', 0.5, 'Box', 'off', 'Layer', 'top');
    title(a1, kn{k}, 'FontSize', 7, 'FontWeight', 'bold');
    if k == 1
        ylabel(a1, 'RR', 'FontSize', 7, 'FontWeight', 'bold');
        lg = legend(a1, [h1 h2], {'CL', 'OL placebo'}, 'FontSize', 6, 'Box', 'off', 'Location', 'northwest');
        lg.ItemTokenSize = [6 6];
    end
    a2 = axes(fig, 'Units', 'centimeters', 'Position', [1.3 + (k-1)*5.6, 1.2, 4.8, 3.3]);  hold(a2, 'on');
    plot(a2, [0.3 n+0.7], [1 1], '--', 'Color', [0.4 0.4 0.4], 'LineWidth', 0.5);
    bb = QT.(sprintf('beta_%d', k));
    plot(a2, find(g), bb(g), 's', 'MarkerSize', 3.5, 'MarkerFaceColor', 'k', 'MarkerEdgeColor', 'k');
    plot(a2, find(~g), bb(~g), 's', 'MarkerSize', 3.5, 'MarkerFaceColor', 'w', 'MarkerEdgeColor', [0.5 0.5 0.5]);
    set(a2, 'XLim', [0.3 n+0.7], 'XTick', 1:n, 'XTickLabel', lab, 'FontSize', 6, 'TickDir', 'out', 'LineWidth', 0.5, ...
        'Box', 'off', 'Layer', 'top');
    xtickangle(a2, 90);
    xlabel(a2, 'Session (Mouse)', 'FontSize', 7, 'FontWeight', 'bold');
    if k == 1, ylabel(a2, 'Calibration slope \beta', 'FontSize', 7, 'FontWeight', 'bold'); end
end
allRR = [QT.RRcl_1; QT.RRcl_2; QT.RRcl_3; QT.RRol_1; QT.RRol_2; QT.RRol_3];
yt = [0.1 0.2 0.3 0.5 1 2 3 5];
set(findobj(fig, 'Type', 'axes', '-and', 'YScale', 'log'), 'YLim', [min(allRR) max(allRR)] .* [0.8 1.25], ...
    'YTick', yt, 'YTickLabel', compose('%g', yt));
set(findobj(fig, 'Type', 'axes', '-and', 'YScale', 'linear'), 'YLim', [0 max([QT.beta_1; QT.beta_2; QT.beta_3]) * 1.1]);
annotation(fig, 'textbox', [0.01 0.955 0.98 0.045], 'String', ...
    'Fig 4H diagnostic. Top: session geometric-mean RR, CL (filled) and OL placebo (open). Bottom: \beta of OL a on D over 1-3 s (open = outside the 4H gate).', ...
    'EdgeColor', 'none', 'FontSize', 6, 'Interpreter', 'tex');
exportgraphics(fig, fullfile(outview, 'f4_rr_diag.png'), 'Resolution', 300);  close(fig);
fprintf('[f4-diag] wrote data/f4_rr_diag.csv and _preview/f4_rr_diag.png\n');

% ======================================================================================
function [b, rOL] = rrdiag_terms(a, D, wr)   % calibration slope (pooled) and per-trial OL placebo RR
aw = a(:, wr);  Dw = D(:, wr);
b = sum(aw(:) .* Dw(:)) / sum(Dw(:).^2);
rOL = sum(aw.^2, 2) ./ sum(Dw.^2, 2);
end

function g = gm_pos(r)                         % session geometric mean over finite r > 0
r = r(isfinite(r) & r > 0);  g = exp(mean(log(r)));
end
