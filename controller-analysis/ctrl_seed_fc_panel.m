function ctrl_seed_fc_panel(sess)
%CTRL_SEED_FC_PANEL  Supp panel (hub #32): correlation of ~60 cortical spots with the controlled site,
%   baseline vs stim, OL (top) and CL (bottom). Columns: baseline r, stim r, delta r (stim - base).
%   Spots whose paired trial-bootstrap 95% CI on delta r excludes 0 get a black ring.
%   Reads data/ctrl_seed_fc_<sess>.mat (run ctrl_seed_fc first). Referenced from the variance paragraph.
% OUT  paper/images/supp_seedfc/seedfc_spots_<sess>.pdf (+ .png) via jnExport
if nargin < 1, sess = 'AL_0033_0226_e2'; end
here = fileparts(mfilename('fullpath')); addpath(genpath(fullfile(here, '..', 'utils')));
R = load(fullfile(here, 'data', sprintf('ctrl_seed_fc_%s.mat', sess)));
S = jnStyle(); pxmm = R.opt.px_mm;

% crop to the mask, grey brain backdrop
[mr, mc] = find(R.mask); r0 = min(mr) - 5; r1 = max(mr) + 5; c0 = min(mc) - 5; c1 = max(mc) + 5;
img = double(R.mimg(r0:r1, c0:c1)); m = imfill(bwareafilt(R.mask(r0:r1, c0:c1), 1), 'holes');
lo = prctile(img(m), 1); hi = prctile(img(m), 99); g = 0.80 + 0.15 * min(max((img - lo) / (hi - lo), 0), 1);
bg = repmat(g, 1, 1, 3); bg(repmat(~m, 1, 1, 3)) = 1;
sp = R.spot_rc - [r0 c0] + 1; st = R.site - [r0 c0] + 1;

cmR = parula(256); cmD = divcm(256);
fig = jnFig(8.5, 6.8);
W = 2.3; H = W * size(img, 1) / size(img, 2); x0 = [0.75 3.15 5.75]; y0 = [3.95 1.55];
cn = {'OL', 'CL'}; col = {'base', 'stim', 'd'}; ttl = {'Baseline', 'Stim', '\Deltar (stim - base)'};
for c = 1:2
    Rc = R.(cn{c});
    for k = 1:3
        ax = axes(fig, 'Units', 'centimeters', 'Position', [x0(k) y0(c) W H]); hold(ax, 'on');
        image(ax, bg); axis(ax, 'image', 'ij', 'off');
        contour(ax, double(m), [0.5 0.5], 'Color', [0.35 0.35 0.35], 'LineWidth', S.lw_axis);
        if k < 3, v = Rc.(col{k}).spot_r; cm = cmR; cl = [0.3 1];
        else, v = Rc.stim.spot_r - Rc.base.spot_r; cm = cmD; cl = [-0.3 0.3]; end
        ci = round(1 + (min(max(v, cl(1)), cl(2)) - cl(1)) / diff(cl) * 255);
        scatter(ax, sp(:,2), sp(:,1), 9, cm(ci, :), 'filled', 'MarkerEdgeColor', 'none');
        if k == 3
            sg = Rc.spot_sig;
            scatter(ax, sp(sg,2), sp(sg,1), 9, 'k', 'LineWidth', 0.4);
        end
        plot(ax, st(2), st(1), 'p', 'MarkerSize', 6, 'MarkerFaceColor', 'w', 'MarkerEdgeColor', 'k', 'LineWidth', 0.4);
        colormap(ax, cm); clim(ax, cl);
        if c == 1
            text(ax, size(img,2)/2, -12, ttl{k}, 'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', ...
                'FontSize', S.fs_label, 'FontWeight', 'bold');
        end
        if k == 1
            text(ax, -10, size(img,1)/2, cn{c}, 'Rotation', 90, 'HorizontalAlignment', 'center', ...
                'VerticalAlignment', 'bottom', 'FontSize', S.fs_label, 'FontWeight', 'bold');
        end
        if k < 3, lab = sprintf('mean r %.2f', mean(v)); else, lab = sprintf('%d/%d spots p<0.05', nnz(Rc.spot_sig), numel(v)); end
        text(ax, size(img,2)/2, size(img,1) + 4, lab, 'HorizontalAlignment', 'center', 'VerticalAlignment', 'top', ...
            'FontSize', S.fs_annot);
        if c == 2 && k == 1      % 2 mm scale bar
            plot(ax, [5 5 + 2*pxmm], (size(img,1) - 4) * [1 1], 'k', 'LineWidth', 1);
            text(ax, 5 + pxmm, size(img,1) - 9, '2 mm', 'HorizontalAlignment', 'center', ...
                'VerticalAlignment', 'bottom', 'FontSize', S.fs_annot);
        end
        if c == 2 && k >= 2
            cb = colorbar(ax, 'southoutside'); cb.Units = 'centimeters';
            cb.Position = [x0(k) + 0.25, 0.75, W - 0.5, 0.12]; cb.FontSize = S.fs_tick; cb.TickDirection = 'out';
            cb.LineWidth = S.lw_axis;
            if k == 2, cb.Ticks = [0.3 0.65 1]; cb.Label.String = 'r with site (baseline, stim)';
            else, cb.Ticks = [-0.3 0 0.3]; cb.Label.String = '\Deltar'; end
            cb.Label.FontSize = S.fs_tick;
        end
    end
end
jnExport(fig, fullfile(here, '..', 'paper', 'images', 'supp_seedfc', sprintf('seedfc_spots_%s.pdf', sess)));
end

function cm = divcm(n)
% blue - white - red diverging
x = linspace(-1, 1, n).';
b = [0.13 0.40 0.67]; r = [0.70 0.09 0.17]; w = [1 1 1];
cm = (x < 0) .* (w + (-x) .* (b - w)) + (x >= 0) .* (w + x .* (r - w));
end
