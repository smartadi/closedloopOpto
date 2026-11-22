% controller-analysis/f4_reject_examples.m
% Fig 4H with the lasso predictor, step 1 (research-hub #100): one example CL trial per admissible
% session, the disturbance D against the CL error e = A - r over the settled window RR is computed on.
%
% Math approved by Aditya 2026-11-21: "Approve" (method block in the brain_paper session chat: the lasso
% becomes the contra->ipsi predictor for Fig 4F-4H; example trials first; RESEARCH L-2026-11-21-b).
% Display only: D and RR are those of f4_cl_reject_lmm.m lines 42-45, computed from the lasso Global by
% ctrl_sparse_kernel_cl.m (C.trial; G without yb, as the Fig 4H code).
%   admissible  the Fig 4H offset gate: (mean settled A_CL - r)^2 / mean settled (A_CL - r)^2 <= 1/3
%               (A only, so the same 11 sessions for any predictor)
%   RR          per CL trial sum over (1,3] s of (A - r)^2 / sum over (1,3] s of D^2, r = d.ref (-5)
%   example     per session, the CL trial whose RR is nearest the median of that session's per-trial RR
%               (finite, > 0); ties go to the earlier trial
%   panel       D(t) and e(t) = A(t) - r from -1 to the end of stimulation; (1,3] s shaded; trial RR printed
% Needs ctrl_sparse_kernel_cl.m results with C.trial (run 2026-11-21 or later).
% OUT controller-analysis/_preview/f4_reject_examples.png (PNG: not a paper panel)
root = 'C:\Users\aditya\Documents\projects\brain_paper';
dd   = fullfile(root, 'controller-analysis', 'data');
outview = fullfile(root, 'controller-analysis', '_preview');
addpath(fullfile(root, 'utils'));
PS = paperStyle();  cE = PS.col_cl;  cD = [0.35 0.35 0.35];
L = dir(fullfile(dd, 'ctrl_sparse_kernel_cl_AL_*.mat'));
CC = {};
for i = 1:numel(L)
    S = load(fullfile(dd, L(i).name));  C = S.C;
    assert(isfield(C, 'trial'), '%s: rerun ctrl_sparse_kernel_cl.m (no per-trial arrays)', C.session);
    if C.in4H, CC{end+1} = C; end %#ok<SAGROW>
end
CC = [CC{:}];  n = numel(CC);
fprintf('[f4-ex] %d admissible sessions (offset gate)\n', n);

nCol = 4;  nRow = ceil(n/nCol);  w = 3.4;  h = 2.2;  px = 4.35;  py = 3.35;  H = py*nRow + 1.6;
fig = figure('Color', 'w', 'Units', 'centimeters', 'Position', [2 1 17.6 H], 'Visible', 'off');
for k = 1:n
    C = CC(k);  Tr = C.trial;  rr = Tr.rr(:,2);  ok = find(isfinite(rr) & rr > 0);
    [~, j] = min(abs(rr(ok) - median(rr(ok))));  i = ok(j);
    e = Tr.Acl(i,:) - Tr.ref;  D = Tr.D(i,:,2);  t = C.tt;
    lab = paper_session_label(C.session);
    fprintf('[f4-ex] %-16s %-9s trial %3d of %3d | RR %.2f (session median %.2f, geometric mean %.2f)\n', ...
        C.session, lab, i, numel(rr), rr(i), median(rr(ok)), C.RR_lasso);
    r = ceil(k/nCol);  c = mod(k-1, nCol);
    a = axes('Units', 'centimeters', 'Position', [1.0 + c*px, H - 1.2 - r*py + (py - h - 0.55), w, h]);  hold(a, 'on');
    t1 = t(Tr.wr(1)) - 0.5/35;  t2 = t(Tr.wr(end));
    patch(a, [t1 t2 t2 t1], [-1e3 -1e3 1e3 1e3], [0.93 0.93 0.93], 'EdgeColor', 'none');
    plot(a, [t(1) t(end)], [0 0], '-', 'Color', [0.6 0.6 0.6], 'LineWidth', 0.5);
    plot(a, t, D, '-', 'Color', cD, 'LineWidth', 1.0);
    plot(a, t, e, '-', 'Color', cE, 'LineWidth', 1.0);
    yl = [min([e D]) max([e D])];  yl = yl + [-0.08 0.08]*diff(yl);  ylim(a, yl);  xlim(a, [t(1) t(end)]);
    title(a, sprintf('%s (%s)', lab, strrep(C.session(1:12), '_', ' ')), 'FontSize', 7, 'FontWeight', 'bold');
    text(a, 0.98, 0.95, sprintf('RR %.2f', rr(i)), 'Units', 'normalized', 'FontSize', 6, ...
        'HorizontalAlignment', 'right', 'VerticalAlignment', 'top');
    set(a, 'FontSize', 6, 'TickDir', 'out', 'LineWidth', 0.5, 'Box', 'off', 'Layer', 'top');
    if c == 0, ylabel(a, '%\DeltaF/F', 'FontSize', 7, 'FontWeight', 'bold'); end
    if r == nRow || k + nCol > n, xlabel(a, 'Time from onset (s)', 'FontSize', 7, 'FontWeight', 'bold'); end
end
annotation(fig, 'textbox', [0.01 1 - 1.1/H 0.98 1.0/H], 'String', ...
    {'Closed loop, lasso Global. One trial per admissible session, the trial with the median rejection ratio.', ...
     'Blue, CL error e = A - r (r = -5%); grey, disturbance D (Fig 4H); shaded, settled window 1-3 s; RR = \Sigma e^2 / \Sigma D^2 over that window.'}, ...
    'EdgeColor', 'none', 'FontSize', 6, 'Interpreter', 'tex');
exportgraphics(fig, fullfile(outview, 'f4_reject_examples.png'), 'Resolution', 300);
close(fig);
fprintf('[f4-ex] wrote %s\n', fullfile(outview, 'f4_reject_examples.png'));
