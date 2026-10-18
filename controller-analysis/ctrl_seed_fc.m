function R = ctrl_seed_fc(sess, opt)
%CTRL_SEED_FC  Seed-based functional connectivity of the controlled site, baseline vs during-stim, OL and CL.
%   Question (hub #32, user 2026-10-18): during stimulation, is the stim site less coupled to the rest of
%   cortex ("inputs from other regions cut off")? Seed = the laser site (5x5 px box); map = Pearson r of
%   every pixel with the seed over pooled trial windows. Computed in SVD space (C = V V'/n, never builds
%   the pixel movie).
%   Windows (per trial, paired): BASE = [-2, 0) s pre-onset (laser off), STIM = [+1, +3) s post-onset
%   (skips the inhibitory transient; = the disturbance-rejection window). Same length -> same n.
%   Evoked removal: the condition's trial-averaged V (per window) is subtracted before r, so maps are
%   NOISE correlations -- otherwise the shared stim-locked response inflates r in OL.
%   Laser-partialled variant (opt.partial): STIM-window V is also residualised on laser lags 0..Q-1
%   (ridge, pooled across trials). In CL the laser is a function of the site's error, so this asks
%   whether the coupling is still there once the controller's own cancellation is regressed out.
%   OL vs CL is the mechanism test: OL has no feedback, so a drop in OL = a change in the circuit,
%   a drop only in CL = the controller cancelling the shared input.
% IN   sess  (default 'AL_0033_0226_e2' = m4; needs data/ctrl_mpc_arx_in_<sess>.mat + ctrl_mpc_wb_in_<sess>_n100.mat)
% OUT  R struct (maps, seed sd, distance curves); data/ctrl_seed_fc_<sess>.mat; paper/images/supp_seedfc/*.png
if nargin < 1 || isempty(sess), sess = 'AL_0033_0226_e2'; end
if nargin < 2, opt = struct(); end
df = struct('nSV', 200, 'base', [-2 0], 'stim', [1 3], 'Q', 35, 'lam', 100, 'partial', true, ...
            'excl_mm', 0.5, 'px_mm', NaN, 'nboot', 200, 'plot', true);
fn = fieldnames(df); for i = 1:numel(fn), if ~isfield(opt, fn{i}), opt.(fn{i}) = df.(fn{i}); end, end

here = fileparts(mfilename('fullpath')); dataDir = fullfile(here, 'data'); addpath(genpath(fullfile(here, '..', 'utils')));
A  = load(fullfile(dataDir, sprintf('ctrl_mpc_arx_in_%s.mat', sess)));
Wb = load(fullfile(dataDir, sprintf('ctrl_mpc_wb_in_%s_n100.mat', sess)), 'mask', 'mimg', 'site_rc');
F3 = load(fullfile(dataDir, sprintf('ctrl_mpc_lqr_%s_fig3.mat', sess)), 'P');
Z  = load(fullfile(here, '..', 'data', F3.P.rawFile), 'd'); tb = Z.d.timeBlue(:);
tk = regexp(sess, '(AL_\d+)_(\d\d)(\d\d)_e(\d+)', 'tokens', 'once');
sr = expPath(tk{1}, sprintf('2025-%s-%s', tk{2}, tk{3}), str2double(tk{4}));
[U, V, tsvd] = cp_loadUVt(sr, opt.nSV, tb);
[nY, nX, nS] = size(U); Uf = reshape(U, nY*nX, nS);
n = min(numel(tsvd), size(V, 2));
V = interp1(tsvd(1:n), double(V(:, 1:n)).', tb, 'linear', 'extrap').';   % nS x T on the dFk / laser clock
T = size(V, 2); Fs = A.Fs; u = double(A.u(:)); valid = logical(A.valid(:));
fprintf('[SEEDFC] %s | %d SV | %d frames | %d OL, %d CL trials\n', sess, nS, T, numel(A.onOL), numel(A.onCL));

% seed: 5x5 box at the laser site, same SVD space as the maps
s = Wb.site_rc; h = 2;
[b1, b2] = ndgrid(s(1)-h:s(1)+h, s(2)-h:s(2)+h); us = mean(Uf(sub2ind([nY nX], b1(:), b2(:)), :), 1);   % 1 x nS
mask = Wb.mask;

wb = round(opt.base(1)*Fs):round(opt.base(2)*Fs)-1;  ws = round(opt.stim(1)*Fs):round(opt.stim(2)*Fs)-1;
cond = {'OL', A.onOL(:); 'CL', A.onCL(:)};
for c = 1:2
    on = cond{c, 2}; on = on(on + min(wb) >= 1 & on + max(ws) <= T);
    ok = arrayfun(@(o) all(valid(o + [wb ws])), on); on = on(ok);
    for w = {'base', 'stim'}
        ix = on + (strcmp(w{1}, 'base') * wb + strcmp(w{1}, 'stim') * ws);   % nTr x nW frame indices
        Vt = reshape(V(:, ix.'), nS, size(ix, 2), []);                          % nS x nW x nTr
        Vt = Vt - mean(Vt, 3);                                                  % remove the evoked (trial-mean) part
        X  = reshape(Vt, nS, []);
        R.(cond{c,1}).(w{1}) = seedmap(Uf, us, X, mask);
        if opt.partial && strcmp(w{1}, 'stim')
            Lg = lagmat(u, ix, opt.Q); Lg = Lg - mean(Lg, 1);
            B  = (Lg.' * Lg + opt.lam * eye(opt.Q)) \ (Lg.' * X.');             % Q x nS
            R.(cond{c,1}).stim_p = seedmap(Uf, us, X - (Lg * B).', mask);
        end
        % trial bootstrap of the masked-mean r (excluding the site neighbourhood)
        R.(cond{c,1}).([w{1} '_ix']) = ix;
    end
    R.(cond{c,1}).nTr = numel(on);
    fprintf('[SEEDFC] %s: %d trials | seed sd base %.3f stim %.3f (ratio %.2f)\n', cond{c,1}, numel(on), ...
        R.(cond{c,1}).base.sd_seed, R.(cond{c,1}).stim.sd_seed, R.(cond{c,1}).stim.sd_seed / R.(cond{c,1}).base.sd_seed);
end

% distance from site, summary excluding the seed's own neighbourhood
[cc, rr] = meshgrid(1:nX, 1:nY); dpx = hypot(rr - s(1), cc - s(2));
if isnan(opt.px_mm), opt.px_mm = 1000/17.3; end                                 % rig: 57.8 px/mm (spatial_spread.m)
dmm = dpx / opt.px_mm; far = mask & dmm > opt.excl_mm;
edges = 0:0.5:ceil(max(dmm(mask))); R.dist_edges = edges;
for c = {'OL', 'CL'}
    for w = {'base', 'stim', 'stim_p'}
        if ~isfield(R.(c{1}), w{1}), continue, end
        r = R.(c{1}).(w{1}).r;
        R.(c{1}).(w{1}).mean_far = mean(r(far), 'omitnan');
        R.(c{1}).(w{1}).dcurve = arrayfun(@(k) mean(r(mask & dmm >= edges(k) & dmm < edges(k+1)), 'omitnan'), 1:numel(edges)-1);
    end
    fprintf('[SEEDFC] %s mean r (>%.1f mm): base %.3f  stim %.3f  stim|laser %.3f\n', c{1}, opt.excl_mm, ...
        R.(c{1}).base.mean_far, R.(c{1}).stim.mean_far, R.(c{1}).stim_p.mean_far);
end

% trial bootstrap of delta mean_far (stim - base), paired by trial
rng(1);
for c = {'OL', 'CL'}
    ixb = R.(c{1}).base_ix; ixs = R.(c{1}).stim_ix; nT = size(ixb, 1); d = nan(opt.nboot, 1);
    for b = 1:opt.nboot
        k = randi(nT, nT, 1);
        mb = bootmean(V, ixb(k, :), Uf, us, mask, far, nS);
        ms = bootmean(V, ixs(k, :), Uf, us, mask, far, nS);
        d(b) = ms - mb;
    end
    R.(c{1}).dboot = d; R.(c{1}).dci = prctile(d, [2.5 97.5]);
    fprintf('[SEEDFC] %s delta mean r (stim-base) = %.3f, 95%% CI [%.3f %.3f]\n', c{1}, ...
        R.(c{1}).stim.mean_far - R.(c{1}).base.mean_far, R.(c{1}).dci);
end
R.sess = sess; R.opt = opt; R.mask = mask; R.site = s; R.mimg = Wb.mimg;
Rs = rmfield(R, {}); for c = {'OL', 'CL'}, Rs.(c{1}) = rmfield(Rs.(c{1}), {'base_ix', 'stim_ix'}); end
save(fullfile(dataDir, sprintf('ctrl_seed_fc_%s.mat', sess)), '-struct', 'Rs', '-v7');
if opt.plot, plot_maps(R, here); end
end

% ---------------------------------------------------------------------------------------------------------
function M = seedmap(Uf, us, X, mask)
n = size(X, 2); C = (X * X.') / n;                % nS x nS
sv = us * X;                                      % seed time series
cv = Uf * (X * sv.') / n;                         % pixel x 1 covariance with seed
vp = sum((Uf * C) .* Uf, 2);                      % pixel variance
r  = cv ./ sqrt(vp * var(sv, 1));
r  = reshape(r, size(mask)); r(~mask) = NaN;
M  = struct('r', r, 'sd_seed', std(sv, 1));
end

function m = bootmean(V, ix, Uf, us, mask, far, nS)
Vt = reshape(V(:, ix.'), nS, size(ix, 2), []); Vt = Vt - mean(Vt, 3);
M = seedmap(Uf, us, reshape(Vt, nS, []), mask); m = mean(M.r(far), 'omitnan');
end

function Lg = lagmat(u, ix, Q)
% rows ordered like reshape(V(:, ix.'), nS, []) : time within trial fastest, then trial
ixr = reshape(ix.', [], 1); Lg = zeros(numel(ixr), Q);
for q = 0:Q-1, Lg(:, q+1) = u(max(1, ixr - q)); end
end

function plot_maps(R, here)
out = fullfile(here, '..', 'paper', 'images', 'supp_seedfc'); if ~exist(out, 'dir'), mkdir(out); end
f = figure('Color', 'w', 'Position', [100 100 1100 520]);
cols = {'base', 'stim'}; ttl = {'baseline [-2,0) s', 'stim [+1,+3) s'};
cm = redblue_cm(256);
for c = 1:2
    cn = {'OL', 'CL'}; cn = cn{c};
    for k = 1:3
        ax = subplot(2, 4, (c-1)*4 + k);
        if k < 3
            imagesc(R.(cn).(cols{k}).r, 'AlphaData', R.mask); colormap(ax, parula(256)); clim([0 1]);
            title(sprintf('%s %s\nmean r %.2f', cn, ttl{k}, R.(cn).(cols{k}).mean_far), 'FontSize', 8);
        else
            imagesc(R.(cn).stim.r - R.(cn).base.r, 'AlphaData', R.mask); colormap(ax, cm); clim([-0.3 0.3]);
            title(sprintf('%s \\Deltar (stim - base)', cn), 'FontSize', 8);
        end
        axis image off; hold on; plot(R.site(2), R.site(1), 'k+', 'MarkerSize', 6, 'LineWidth', 1);
        if c == 2 && k >= 2, cb = colorbar(ax, 'southoutside'); cb.FontSize = 7; end
    end
    ax = subplot(2, 4, (c-1)*4 + 4); hold on
    xc = R.dist_edges(1:end-1) + 0.25;
    plot(xc, R.(cn).base.dcurve, 'k', 'LineWidth', 1.5); plot(xc, R.(cn).stim.dcurve, 'r', 'LineWidth', 1.5);
    plot(xc, R.(cn).stim_p.dcurve, 'r--', 'LineWidth', 1);
    xlabel('distance from site (mm)'); ylabel('r with seed'); title(sprintf('%s: \\Deltar %.2f [%.2f %.2f]', cn, ...
        R.(cn).stim.mean_far - R.(cn).base.mean_far, R.(cn).dci), 'FontSize', 8);
    legend({'base', 'stim', 'stim|laser'}, 'Box', 'off', 'FontSize', 7); box off
end
sgtitle(sprintf('Seed FC at laser site -- %s (noise correlations, evoked removed)', strrep(R.sess, '_', '\_')), 'FontSize', 9);
exportgraphics(f, fullfile(out, sprintf('seedfc_%s.png', R.sess)), 'Resolution', 300);
end

function cm = redblue_cm(n)
x = linspace(-1, 1, n).'; cm = [min(1, 1 + x) .* (x < 0) + (x >= 0), 1 - abs(x), min(1, 1 - x) .* (x > 0) + (x <= 0)];
end
