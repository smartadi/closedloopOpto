function G = ctrl_seed_fc_group(sessions, opt)
%CTRL_SEED_FC_GROUP  Raw seed FC (site vs cortex) averaged over the 12 controller sessions on one 60-node grid.
%   Supp panel for hub #32 (user 2026-10-19: RAW coupling only -- no laser removal, no GSR).
%   Per session: pixel r-map of the site seed (5x5 px) with every pixel, evoked (trial mean) removed,
%   base [-2,0) s vs stim [+1,+3) s, OL and CL (same as ctrl_seed_fc). No CCF registration exists for
%   controller sessions, so maps go to a BRAIN-NORMALISED frame (as ctrl_lu_regions_export): display
%   orientation (cp_orient, anterior up), AP = fraction of the brain's row extent, ML = (col - midline) /
%   max lateral extent, signed so the stimulated hemisphere is +. A common node grid (~nNode nodes, equal
%   physical spacing using the session-mean brain size) sits inside the consensus mask (>= 75% of sessions).
%   Node value = mean r over a 3x3 normalised-raster neighbourhood; sessions averaged in Fisher z.
%   Node stats: signed-rank across sessions on delta r, BH-FDR q < 0.05 -> ring.
%   Per-session delta r = mean over nodes > excl_mm from that session's site.
% OUT  data/ctrl_seed_fc_group_<sess>.mat (per-session cache), data/ctrl_seed_fc_group.mat,
%      paper/images/supp_seedfc/seedfc_group.pdf (+png) via jnExport
if nargin < 1 || isempty(sessions)
    sessions = {'AL_0033_0212_e2','AL_0033_0224_e2','AL_0033_0226_e2','AL_0033_0304_e1','AL_0033_0305_e2', ...
                'AL_0033_0320_e4','AL_0033_0415_e2','AL_0033_0419_e1','AL_0039_0419_e1','AL_0039_0420_e1', ...
                'AL_0039_0420_e2','AL_0039_0430_e3'};
end
if nargin < 2, opt = struct(); end
df = struct('nSV', 200, 'base', [-2 0], 'stim', [1 3], 'nNode', 60, 'excl_mm', 0.5, 'consensus', 0.75, ...
            'redo', false, 'q', 0.05, 'erode', 5);
fn = fieldnames(df); for i = 1:numel(fn), if ~isfield(opt, fn{i}), opt.(fn{i}) = df.(fn{i}); end, end
here = fileparts(mfilename('fullpath')); dataDir = fullfile(here, 'data'); addpath(genpath(fullfile(here, '..', 'utils')));
pxmm = 1000/17.3;
ap = linspace(0, 1, 101).'; ml = linspace(-1, 1, 101);              % normalised raster
cn = {'OL', 'CL'}; wn = {'base', 'stim'}; nS = numel(sessions);

C = cell(nS, 1);
for i = 1:nS
    cf = fullfile(dataDir, sprintf('ctrl_seed_fc_group_%s.mat', sessions{i}));
    if ~opt.redo && exist(cf, 'file'), C{i} = orderfields(load(cf)); continue, end
    C{i} = orderfields(one_session(sessions{i}, opt, ap, ml, dataDir, here));
    Pi = C{i}; save(cf, '-struct', 'Pi', '-v7');
end
P = [C{:}];

% ---- common node grid ---------------------------------------------------------------------------
Mfrac = mean(cat(3, P.Mn), 3); cons = Mfrac >= opt.consensus;
consN = imerode(cons, strel('disk', opt.erode));          % node mask: keep nodes off the brain edge
%   (edge nodes read r ~0.95-0.97 with the site in every session -- skull-edge pixels, not cortex; 2026-10-19)
Lap = mean([P.L_px]); Lml = mean([P.lat_px]);                       % session-mean brain size (px)
best = inf;
for d = 5:0.25:80                                                    % physical spacing (px)
    sa = d / Lap; sm = d / Lml;
    [GA, GM] = ndgrid(0:sa:1, -1:sm:1);
    ia = round(GA(:) * 100) + 1; im = round((GM(:) + 1) * 50) + 1;
    in = consN(sub2ind(size(consN), ia, im));
    if abs(nnz(in) - opt.nNode) < best, best = abs(nnz(in) - opt.nNode); node = [ia(in) im(in)]; dsp = d; end
end
nN = size(node, 1);
fprintf('[GROUP] %d sessions | %d nodes, spacing %.2f mm\n', nS, nN, dsp / pxmm);

% node values per session: z = atanh(r), 3x3 raster neighbourhood
for c = 1:2
    for w = 1:2
        Z = nan(nS, nN);
        for i = 1:nS
            A = P(i).(cn{c}).(wn{w});
            for k = 1:nN
                b = A(max(1,node(k,1)-1):min(101,node(k,1)+1), max(1,node(k,2)-1):min(101,node(k,2)+1));
                Z(i, k) = mean(atanh(min(b(:), 0.999)), 'omitnan');
            end
        end
        G.(cn{c}).(wn{w}) = Z;
    end
    G.(cn{c}).dz = G.(cn{c}).stim - G.(cn{c}).base;
    G.(cn{c}).dr = tanh(G.(cn{c}).stim) - tanh(G.(cn{c}).base);        % per session, per node
    p = nan(1, nN);
    for k = 1:nN, x = G.(cn{c}).dr(:, k); x = x(~isnan(x)); if numel(x) >= 6, p(k) = signrank(x); end, end
    G.(cn{c}).p = p; G.(cn{c}).sig = bh(p, opt.q);
    % per-session summary over nodes away from that session's site
    for i = 1:nS
        dmm = hypot((node(:,1) - 1)/100 * P(i).L_px - P(i).site_n(1) * P(i).L_px, ...
                    ((node(:,2) - 1)/50 - 1) * P(i).lat_px - P(i).site_n(2) * P(i).lat_px) / pxmm;
        f = dmm > opt.excl_mm;
        G.(cn{c}).sess_base(i) = mean(tanh(G.(cn{c}).base(i, f)), 'omitnan');
        G.(cn{c}).sess_stim(i) = mean(tanh(G.(cn{c}).stim(i, f)), 'omitnan');
    end
    G.(cn{c}).sess_dr = G.(cn{c}).sess_stim - G.(cn{c}).sess_base;
    fprintf('[GROUP] %s: r %.3f -> %.3f | session dr %+.3f +- %.3f (SEM), %d/%d < 0, signrank p = %.4f | %d/%d nodes FDR<%.2f\n', ...
        cn{c}, mean(G.(cn{c}).sess_base), mean(G.(cn{c}).sess_stim), mean(G.(cn{c}).sess_dr), ...
        std(G.(cn{c}).sess_dr)/sqrt(nS), nnz(G.(cn{c}).sess_dr < 0), nS, signrank(G.(cn{c}).sess_dr), ...
        nnz(G.(cn{c}).sig), nN, opt.q);
end
fprintf('[GROUP] CL vs OL session dr: paired signrank p = %.4f\n', signrank(G.CL.sess_dr, G.OL.sess_dr));
G.Mn = {P.Mn}; G.L_px = [P.L_px]; G.lat_px = [P.lat_px];
G.node = node; G.cons = cons; G.Mfrac = Mfrac; G.Lap = Lap; G.Lml = Lml; G.ap = ap; G.ml = ml;
G.site_n = reshape([P.site_n], 2, []).'; G.sessions = sessions; G.mouse = cellfun(@(s) str2double(s(6:7)), sessions);
G.opt = opt; G.pxmm = pxmm; G.spacing_mm = dsp / pxmm;
save(fullfile(dataDir, 'ctrl_seed_fc_group.mat'), '-struct', 'G', '-v7');
panel(G, here);
end

% =====================================================================================================
function P = one_session(sess, opt, ap, ml, dataDir, here)
tk = regexp(sess, '(AL_\d+)_(\d\d)(\d\d)_e(\d+)', 'tokens', 'once');
Z = load(fullfile(here, '..', 'data', sprintf('%sctrl%s%s%s.mat', tk{1}, tk{2}, tk{3}, tk{4})), 'd', 'data');
dz = Z.d; Dz = Z.data; tb = dz.timeBlue(:); Fs = 35; T = numel(tb);
on = arrayfun(@(t) find(tb >= t, 1), dz.stimStarts(:));
ons = {on(Dz.nc(:)), on(Dz.wc(:))};
valid = (1:T).' >= double(dz.params.horizon);
sr = expPath(tk{1}, sprintf('2025-%s-%s', tk{2}, tk{3}), str2double(tk{4}));
[U, V, tsvd, mimg] = cp_loadUVt(sr, opt.nSV, tb);
[nY, nX, nSV] = size(U); Uf = reshape(U, nY*nX, nSV);
n = min(numel(tsvd), size(V, 2));
V = interp1(tsvd(1:n), double(V(:, 1:n)).', tb, 'linear', 'extrap').';
st = load(fullfile(dataDir, sprintf('cp_stim_site_ctrl_%s.mat', sess))); s = double(st.rowcol);
ocf = fullfile(dataDir, sprintf('cp_orient_ctrl_%s.mat', sess));
try, T0 = cp_orient(mimg, s(1), s(2), struct('cache_file', ocf, 'redefine', false, 'confirm', false));
catch, T0 = load(ocf); T0 = T0.T; end                  % older caches lack .sym_* (cp_orient print only)
Mk = cp_roi_masks(mimg, fullfile(dataDir, sprintf('cp_roi2_ctrl_%s.mat', sess)), s(1), s(2), ...
                  struct('redefine', false, 'thr_pctile', 20, 'plot', false, 'T', T0));
mask = logical(Mk.contra) | logical(Mk.ipsi);
h = 2; [b1, b2] = ndgrid(s(1)-h:s(1)+h, s(2)-h:s(2)+h); us = mean(Uf(sub2ind([nY nX], b1(:), b2(:)), :), 1);

% display frame + normalisation
Md = cp_orient_img(T0, mask); [rr, cc] = find(Md);
[sdr, sdc] = cp_orient_fwd(T0, s(1), s(2));
mid = T0.mid_disp_col; r0 = min(rr); r1 = max(rr); lat = max(abs(cc - mid));
sgn = sign(sdc - mid); if sgn == 0, sgn = 1; end           % stimulated hemisphere -> +ML
[MLg, APg] = meshgrid(ml, ap);
Rq = r0 + APg * (r1 - r0); Cq = mid + sgn * MLg * lat;
P.Mn = interp2(double(Md), Cq, Rq, 'nearest', 0) > 0.5;
P.site_n = [(sdr - r0) / (r1 - r0), sgn * (sdc - mid) / lat];
P.L_px = r1 - r0; P.lat_px = lat; P.sess = sess;
fprintf('[GROUP] %s: site AP %.2f ML %+.2f | %d OL %d CL\n', sess, P.site_n, numel(ons{1}), numel(ons{2}));

wb = round(opt.base(1)*Fs):round(opt.base(2)*Fs)-1; ws = round(opt.stim(1)*Fs):round(opt.stim(2)*Fs)-1;
cn = {'OL', 'CL'};
for c = 1:2
    o = ons{c}; o = o(o + min(wb) >= find(valid, 1) & o + max(ws) <= T);
    for w = {'base', 'stim'}
        ix = o + (strcmp(w{1}, 'base') * wb + strcmp(w{1}, 'stim') * ws);
        Vt = reshape(V(:, reshape(ix.', 1, [])), nSV, size(ix, 2), []); Vt = Vt - mean(Vt, 3);
        X = reshape(Vt, nSV, []); nn = size(X, 2); sv = us * X;
        r = (Uf * (X * sv.') / nn) ./ sqrt(sum((Uf * ((X * X.') / nn)) .* Uf, 2) * var(sv, 1));
        r = reshape(r, nY, nX); r(~mask) = NaN;
        Rd = cp_orient_img(T0, r);
        A = interp2(Rd, Cq, Rq, 'linear', NaN); A(~P.Mn) = NaN;
        P.(cn{c}).(w{1}) = A;
    end
end
end

function sig = bh(p, q)
sig = false(size(p)); ok = ~isnan(p); ps = sort(p(ok)); m = numel(ps);
k = find(ps <= (1:m) / m * q, 1, 'last');
if ~isempty(k), sig(ok) = p(ok) <= ps(k); end
end

function panel(G, here)
% Per-session delta r maps, each in its own brain (user 2026-10-20: no pooled map, no shared site markers).
% Rows 1-2 OL, rows 3-4 CL; nodes = the common grid restricted to that session's mask; star = its site.
% Right: per-session delta r, OL vs CL (locked colours OL red, CL blue; marker = mouse).
S = jnStyle(); cmD = divcm(256); cl = [-0.3 0.3]; nS = numel(G.sessions);
mlN = (G.node(:,2) - 1)/50 - 1; apN = (G.node(:,1) - 1)/100;
xl = max(G.lat_px) / G.pxmm * [-1 1]; yl = [0 max(G.L_px) / G.pxmm];
fig = jnFig(17.6, 9.8);
nc = 6; W = 1.95; Hh = W * diff(yl) / diff(xl); dx = 2.2; x00 = 0.75;
yB = {[7.75 5.75], [3.65 1.65]};                         % OL block rows, CL block rows (bottom of axes, cm)
cn = {'OL', 'CL'};
for c = 1:2
    for i = 1:nS
        rw = ceil(i / nc); cl_i = i - (rw - 1) * nc;
        ax = axes(fig, 'Units', 'centimeters', 'Position', [x00 + (cl_i - 1) * dx, yB{c}(rw), W, Hh]); hold(ax, 'on');
        X = G.ml * G.lat_px(i) / G.pxmm; Y = G.ap * G.L_px(i) / G.pxmm;
        contourf(ax, X, Y, double(G.Mn{i}), [0.5 0.5], 'FaceColor', [0.92 0.92 0.92], 'LineColor', [0.45 0.45 0.45], ...
            'LineWidth', S.lw_axis);
        v = G.(cn{c}).dr(i, :).'; ok = ~isnan(v);
        ci = round(1 + (min(max(v(ok), cl(1)), cl(2)) - cl(1)) / diff(cl) * 255);
        scatter(ax, mlN(ok) * G.lat_px(i) / G.pxmm, apN(ok) * G.L_px(i) / G.pxmm, 4, cmD(ci, :), 'filled', 'MarkerEdgeColor', 'none');
        plot(ax, G.site_n(i,2) * G.lat_px(i) / G.pxmm, G.site_n(i,1) * G.L_px(i) / G.pxmm, 'p', 'MarkerSize', 4.5, ...
            'MarkerFaceColor', 'w', 'MarkerEdgeColor', 'k', 'LineWidth', 0.4);
        set(ax, 'YDir', 'reverse'); axis(ax, 'equal', 'off'); xlim(ax, xl); ylim(ax, yl);
        tg = regexp(G.sessions{i}, 'AL_(\d+)_(\d\d)(\d\d)_e(\d+)', 'tokens', 'once');
        text(ax, 0, yl(1) - 0.15, sprintf('AL%s %s-%s e%s  %+.2f', tg{1}(3:4), tg{2}, tg{3}, tg{4}, G.(cn{c}).sess_dr(i)), ...
            'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'FontSize', S.fs_min);
        if cl_i == 1 && rw == 1
            text(ax, xl(1) - 0.6, yl(2) + 0.6, cn{c}, 'Rotation', 90, 'HorizontalAlignment', 'center', ...
                'FontSize', S.fs_label, 'FontWeight', 'bold');
        end
        if c == 2 && i == nS - nc + 1      % 2 mm scale bar, bottom-left map
            plot(ax, xl(1) + [0 2], yl(2) * [1 1] + 0.55, 'k', 'LineWidth', 1, 'Clipping', 'off');
            text(ax, xl(1) + 1, yl(2) + 0.6, '2 mm', 'HorizontalAlignment', 'center', 'VerticalAlignment', 'top', ...
                'FontSize', S.fs_annot);
        end
        colormap(ax, cmD); clim(ax, cl);
        if c == 2 && i == nS
            cb = colorbar(ax, 'southoutside'); cb.Units = 'centimeters';
            cb.Position = [x00 + 2 * dx, 0.75, 2 * dx, 0.12]; cb.FontSize = S.fs_tick; cb.TickDirection = 'out';
            cb.LineWidth = S.lw_axis; cb.Ticks = [-0.3 0 0.3]; cb.Label.String = '\Deltar with site (stim - base)';
            cb.Label.FontSize = S.fs_tick;
        end
    end
end
% per-session delta r, OL vs CL
ax = axes(fig, 'Units', 'centimeters', 'Position', [14.65 1.6 2.5 7.2]); hold(ax, 'on');
cO = [0.85 0.2 0.15]; cC = [0.15 0.35 0.8];
plot(ax, [1 2], [G.OL.sess_dr(:) G.CL.sess_dr(:)].', '-', 'Color', [0.7 0.7 0.7], 'LineWidth', S.lw_ind);
mk = {'o', 's'}; ms = [33 39];
for m = 1:2
    i = G.mouse == ms(m);
    scatter(ax, ones(nnz(i), 1), G.OL.sess_dr(i), 10, cO, mk{m}, 'filled');
    scatter(ax, 2 * ones(nnz(i), 1), G.CL.sess_dr(i), 10, cC, mk{m}, 'filled');
end
errorbar(ax, [0.75 2.25], [mean(G.OL.sess_dr) mean(G.CL.sess_dr)], ...
    [std(G.OL.sess_dr) std(G.CL.sess_dr)] / sqrt(nS), 'k_', 'LineWidth', S.lw_err, 'CapSize', 0);
yline(ax, 0, ':', 'Color', [0.3 0.3 0.3], 'LineWidth', S.lw_ref);
text(ax, 1.5, 0.085, sprintf('CL vs OL p = %.4f', signrank(G.CL.sess_dr, G.OL.sess_dr)), ...
    'HorizontalAlignment', 'center', 'FontSize', S.fs_annot);
set(ax, 'XTick', [1 2], 'XTickLabel', {'OL', 'CL'}, 'XLim', [0.5 2.5], 'YLim', [-0.4 0.1], 'FontSize', S.fs_tick);
ylabel(ax, '\Deltar (stim - base)', 'FontSize', S.fs_label, 'FontWeight', 'bold');
title(ax, sprintf('%d sessions', nS), 'FontSize', S.fs_label, 'FontWeight', 'bold');
jnExport(fig, fullfile(here, '..', 'paper', 'images', 'supp_seedfc', 'seedfc_group.pdf'));
end

function cm = divcm(n)
x = linspace(-1, 1, n).'; b = [0.13 0.40 0.67]; r = [0.70 0.09 0.17]; w = [1 1 1];
cm = (x < 0) .* (w + (-x) .* (b - w)) + (x >= 0) .* (w + x .* (r - w));
end
