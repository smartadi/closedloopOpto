function ctrl_mpc_varx_supp_panels(sess)
%CTRL_MPC_VARX_SUPP_PANELS  PROTOTYPE supplementary figure: the VARX that the Fig 6 MPC uses -- how it is built and
%   how well it predicts (user 2026-10-16). Static session AL_0033 2025-02-26 e2; same model as the MPC
%   (L = 10, Q = 35, ridge 100). Held-out OL protocol of mpc_varx_embed.py. Data: mpc_varx_supp.py.
%   Panels (draft letters):
%     A inputs: brain map, 100 spots coloured by their weight in the one-step y equation, controlled site
%     B construction diagram (TikZ, varx_construction_diagram.tex)
%     C rolling 1 s forecasts on a held-out OL trial          D R^2 vs lead: VARX | site + laser only | AR | naive
%     E validation R^2 (200 ms) over lags L x ridge lambda      F learned laser response vs measured OL average
%     H whiteness: autocorrelation of one-step residuals vs the signal
%   OUT paper/images/supp_varx/varx_*.png (+ PDF with PAPER_FINAL) and _draft_layout_supp_varx.png
if nargin < 1, sess = 'AL_0033_0226_e2'; end
here = fileparts(mfilename('fullpath')); dataDir = fullfile(here,'data'); addpath(genpath(fullfile(here,'..','utils')));
figDir = fullfile(here,'..','paper','images','supp_varx'); if ~exist(figDir,'dir'), mkdir(figDir); end
PS = paperStyle(); S = jnStyle();
C.m = [0.45 0.20 0.60]; C.g = [0.62 0.62 0.62]; C.k = [0 0 0]; C.edge = [0.45 0.45 0.45]; C.site = PS.col_cl;
C.ol = [1 0 0]; C.s = [0.20 0.55 0.75];
W1 = 2.8; H = 3.0;
D = load(fullfile(dataDir, sprintf('mpc_varx_supp_%s.mat', sess)));
Fs = double(D.Fs);
exp_ = @(fig, name) ctrl_mpc_export(fig, fullfile(figDir, [name '.png']));

% ---- A: inputs on the brain, coloured by weight in the y equation ------------------------------------------------
mimg = double(D.mimg); mask = logical(D.mask); rc = double(D.rc); site = double(D.site_rc);
w = double(D.w_chan(:)); ws = w(2:end) / max(w(2:end));                     % spots only, normalised
fig = jnFig(3.2, H); ax = axes(fig, 'Units','centimeters', 'Position', [0.05 0.35 2.55 2.55]); hold(ax,'on');
g = mimg / prctile(mimg(mask), 99); g(~mask) = 1; image(ax, repmat(min(g,1), 1, 1, 3) * 0.55 + 0.45);
cm = interp1([0 1], [0.92 0.90 0.95; C.m], linspace(0,1,64));
[~, o] = sort(ws);
scatter(ax, rc(o,2), rc(o,1), 7, ws(o), 'filled', 'MarkerEdgeColor', 'none'); colormap(ax, cm); caxis(ax, [0 1]);
plot(ax, site(2), site(1), 'p', 'MarkerSize', 6, 'MarkerFaceColor', C.site, 'MarkerEdgeColor', 'w', 'LineWidth', 0.3);
axis(ax, 'image', 'ij', 'off');
cb = colorbar(ax, 'Units','centimeters', 'Position', [2.7 0.6 0.12 1.6], 'Ticks', [0 1], 'TickLabels', {'0','1'});
cb.FontSize = S.fs_tick; cb.Box = 'off';
text(ax, 0.5, -0.04, 'weight in y equation', 'Units','normalized', 'FontSize', S.fs_annot, 'HorizontalAlignment','center', ...
    'VerticalAlignment','top');
exp_(fig, 'varx_A_inputs'); close(fig);
[~, iTop] = maxk(ws, 5); fprintf('[VARX-P] site self-weight %.2f vs max spot %.2f; top spots dist to site (px) %s\n', ...
    w(1), max(w(2:end)), mat2str(round(hypot(rc(iTop,1)-site(1), rc(iTop,2)-site(2)))));

% ---- B: construction diagram (TikZ) ------------------------------------------------------------------------------
tmp = fullfile(tempdir, 'varx_diagram'); if ~exist(tmp,'dir'), mkdir(tmp); end
copyfile(fullfile(here, 'varx_construction_diagram.tex'), tmp);
[st, out] = system(sprintf('cd /d "%s" && pdflatex -interaction=nonstopmode varx_construction_diagram.tex', tmp));
if st ~= 0, error('pdflatex failed:\n%s', out(max(1,end-800):end)); end
copyfile(fullfile(tmp, 'varx_construction_diagram.pdf'), fullfile(figDir, 'varx_B_construction.pdf'));
system(sprintf('pdftoppm -png -r 300 -singlefile "%s" "%s"', fullfile(tmp, 'varx_construction_diagram.pdf'), ...
    fullfile(figDir, 'varx_B_construction')));

% ---- C: rolling forecasts on a held-out OL trial -------------------------------------------------------------------
t = double(D.ex_t(:)); y = double(D.ex_y(:)); u = double(D.ex_u(:)); og = double(D.ex_org(:)); fc = double(D.ex_fc);
hz = (1:size(fc,2)).'/Fs;
fig = jnFig(4.6, H);
ax1 = axes(fig, 'Units','centimeters', 'Position', [0.6 1.2 4.0 1.45]); hold(ax1,'on');
ax2 = axes(fig, 'Units','centimeters', 'Position', [0.6 0.4 4.0 0.35]); hold(ax2,'on');
yl = [min([y; fc(:)]) max([y; fc(:)])] + [-0.4 0.4]; dur = 3;
for a = {ax1, yl; ax2, [-0.1 3]}.'
    patch(a{1}, [0 dur dur 0], a{2}([1 1 2 2]), [0.9 0.9 0.9], 'FaceAlpha', 0.4, 'EdgeColor','none');
end
plot(ax1, t, y, '-', 'Color', C.k, 'LineWidth', S.lw_ind + 0.2);
for i = 1:numel(og)
    plot(ax1, og(i) + hz, fc(i,:), '-', 'Color', C.m, 'LineWidth', S.lw_mean);
    plot(ax1, og(i), y(find(t >= og(i) - 1e-9, 1)), 'o', 'MarkerSize', 2, 'MarkerFaceColor', C.m, 'MarkerEdgeColor','none');
end
stairs(ax2, t, u, '-', 'Color', [0.55 0.55 0.55], 'LineWidth', PS.lw_inp);
xlim(ax1, [-1.5 4.5]); xlim(ax2, [-1.5 4.5]); ylim(ax1, yl); ylim(ax2, [-0.1 3]);
paperAxes(ax1, 'XLength', 1, 'YLength', 2, 'XLabel', '1 s', 'YLabel', '2% \DeltaF/F');
paperAxes(ax2, 'XLength', 0, 'YLength', 1.5, 'YLabel', '0.5 mW');
text(ax1, 0.02, 1.02, 'recorded', 'Units','normalized', 'Color', C.k, 'FontSize', S.fs_annot, 'FontWeight','bold', 'VerticalAlignment','bottom');
text(ax1, 0.35, 1.02, '1 s VARX forecasts', 'Units','normalized', 'Color', C.m, 'FontSize', S.fs_annot, 'FontWeight','bold', 'VerticalAlignment','bottom');
exp_(fig, 'varx_C_forecasts'); close(fig);

% ---- D: R^2 vs lead ------------------------------------------------------------------------------------------------
lm = double(D.lead_ms(:));
fig = jnFig(W1, H); ax = axes(fig, 'Units','centimeters', 'Position', [0.85 0.7 W1-0.95 2.05]); hold(ax,'on');
for x = [200 1000], plot(ax, [x x], [-0.25 1], ':', 'Color', C.g, 'LineWidth', S.lw_axis); end
plot(ax, [25 1100], [0 0], '-', 'Color', C.g, 'LineWidth', S.lw_axis);
plot(ax, lm, D.R2_naive, '-', 'Color', C.g, 'LineWidth', S.lw_mean);
plot(ax, lm, D.R2_ar, '-', 'Color', C.k, 'LineWidth', S.lw_ind + 0.3);
plot(ax, lm, D.R2_site, '-', 'Color', C.s, 'LineWidth', S.lw_mean);
plot(ax, lm, D.R2_varx, '-', 'Color', C.m, 'LineWidth', S.lw_mean);
set(ax, 'XScale','log', 'XTick', [30 200 1000], 'XTickLabel', {'30','200','1000'}, 'YTick', [0 0.5 1]);
xlim(ax, [25 1100]); ylim(ax, [-0.25 1]); xlabel(ax, 'lead (ms)'); ylabel(ax, 'R^2'); jnAxes(ax);
nm = {'VARX', 'site + laser', 'AR', 'naive'}; cl = [C.m; C.s; C.k; C.g];
for j = 1:4, text(ax, 0.98, 0.98 - 0.1*(j-1), nm{j}, 'Units','normalized', 'Color', cl(j,:), 'FontSize', S.fs_annot, ...
        'FontWeight','bold', 'HorizontalAlignment','right', 'VerticalAlignment','top'); end
exp_(fig, 'varx_D_r2_lead'); close(fig);

% ---- E: validation landscape over L x lambda (200 ms) --------------------------------------------------------------
nmS = cellstr(D.sweep_names); r200 = double(D.sweep_r2_200(:));
tk = regexp(nmS, '^L=(\d+) lambda=([\d.e+]+)$', 'tokens', 'once'); ok = ~cellfun(@isempty, tk);
Lv = cellfun(@(c) str2double(c{1}), tk(ok)); lv = cellfun(@(c) str2double(c{2}), tk(ok)); rv = r200(ok);
Ls = unique(Lv); ls = unique(lv); M = nan(numel(Ls), numel(ls));
for i = 1:numel(rv), M(Ls == Lv(i), ls == lv(i)) = rv(i); end
fig = jnFig(W1, H); ax = axes(fig, 'Units','centimeters', 'Position', [0.8 0.95 W1-1.3 1.6]); hold(ax,'on');
imagesc(ax, 1:numel(ls), 1:numel(Ls), M); colormap(ax, interp1([0 1], [1 1 1; C.m], linspace(0,1,64)));
caxis(ax, [0.55 0.65]); axis(ax, 'ij', 'tight');
plot(ax, find(ls == 100), find(Ls == 10), 's', 'MarkerSize', 5, 'MarkerEdgeColor', C.k, 'LineWidth', 0.6);
set(ax, 'XTick', 1:numel(ls), 'XTickLabel', arrayfun(@(v) sprintf('10^{%d}', round(log10(v))), ls, 'uni', 0), ...
    'YTick', 1:numel(Ls), 'YTickLabel', Ls);
xlabel(ax, 'ridge \lambda'); ylabel(ax, 'lags L'); jnAxes(ax);
cb = colorbar(ax, 'Units','centimeters', 'Position', [W1-0.45 0.95 0.12 1.6], 'Ticks', [0.55 0.65]); cb.FontSize = S.fs_tick; cb.Box = 'off';
title(ax, 'validation R^2, 200 ms', 'FontSize', S.fs_annot, 'FontWeight', 'bold');
exp_(fig, 'varx_E_sweep'); close(fig);
fprintf('[VARX-P] sweep: chosen (L 10, lam 100) %.3f | best %.3f | range %.3f-%.3f\n', M(Ls==10, ls==100), max(M(:)), min(M(:)), max(M(:)));

% ---- F: learned laser response vs measured OL trial average ---------------------------------------------------------
tr = double(D.resp_t(:)); mm = double(D.resp_meas(:)); se = double(D.resp_sem(:)); md = double(D.resp_model(:));
fig = jnFig(W1, H);
ax1 = axes(fig, 'Units','centimeters', 'Position', [0.6 1.2 W1-0.7 1.45]); hold(ax1,'on');
ax2 = axes(fig, 'Units','centimeters', 'Position', [0.6 0.4 W1-0.7 0.35]); hold(ax2,'on');
yl = [min([mm-se; md]) max([mm+se; md])] + [-0.3 0.3];
patch(ax1, [0 3 3 0], yl([1 1 2 2]), [0.9 0.9 0.9], 'FaceAlpha', 0.4, 'EdgeColor','none');
patch(ax2, [0 3 3 0], [-0.1 -0.1 3 3], [0.9 0.9 0.9], 'FaceAlpha', 0.4, 'EdgeColor','none');
fill(ax1, [tr; flipud(tr)], [mm+se; flipud(mm-se)], C.ol, 'FaceAlpha', 0.25, 'EdgeColor','none');
plot(ax1, tr, mm, '-', 'Color', C.ol, 'LineWidth', S.lw_mean);
plot(ax1, tr, md, '-', 'Color', C.m, 'LineWidth', S.lw_mean);
stairs(ax2, tr, double(D.resp_u(:)), '-', 'Color', [0.55 0.55 0.55], 'LineWidth', PS.lw_inp);
xlim(ax1, tr([1 end])); xlim(ax2, tr([1 end])); ylim(ax1, yl); ylim(ax2, [-0.1 3]);
paperAxes(ax1, 'XLength', 1, 'YLength', 2, 'XLabel', '1 s', 'YLabel', '2%');
paperAxes(ax2, 'XLength', 0, 'YLength', 1.5, 'YLabel', '0.5 mW');
text(ax1, 0.0, 1.02, 'OL mean', 'Units','normalized', 'Color', C.ol, 'FontSize', S.fs_annot, 'FontWeight','bold', 'VerticalAlignment','bottom');
text(ax1, 0.62, 1.02, 'VARX', 'Units','normalized', 'Color', C.m, 'FontSize', S.fs_annot, 'FontWeight','bold', 'VerticalAlignment','bottom');
exp_(fig, 'varx_F_laser_response'); close(fig);
fprintf('[VARX-P] laser response: R^2(model vs measured OL mean) %.3f\n', 1 - sum((mm-md).^2)/sum((mm-mean(mm)).^2));

% ---- H: whiteness -----------------------------------------------------------------------------------------------------
lagms = (0:numel(D.acf_y)-1).' * 1000 / Fs;
fig = jnFig(W1, H); ax = axes(fig, 'Units','centimeters', 'Position', [0.85 0.7 W1-0.95 2.05]); hold(ax,'on');
plot(ax, [0 1000], [0 0], '-', 'Color', C.g, 'LineWidth', S.lw_axis);
plot(ax, lagms, D.acf_y, '-', 'Color', C.k, 'LineWidth', S.lw_mean);
plot(ax, lagms, D.acf_res, '-', 'Color', C.m, 'LineWidth', S.lw_mean);
set(ax, 'XTick', [0 500 1000], 'YTick', [0 0.5 1]); xlim(ax, [0 1000]); ylim(ax, [-0.2 1]);
xlabel(ax, 'lag (ms)'); ylabel(ax, 'autocorrelation'); jnAxes(ax);
text(ax, 0.95, 0.95, 'signal y', 'Units','normalized', 'Color', C.k, 'FontSize', S.fs_annot, 'FontWeight','bold', 'HorizontalAlignment','right', 'VerticalAlignment','top');
text(ax, 0.95, 0.82, 'VARX residual', 'Units','normalized', 'Color', C.m, 'FontSize', S.fs_annot, 'FontWeight','bold', 'HorizontalAlignment','right', 'VerticalAlignment','top');
exp_(fig, 'varx_H_whiteness'); close(fig);
fprintf('[VARX-P] panels -> %s\n', figDir);
end
