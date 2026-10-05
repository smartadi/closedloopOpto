% controller-tuning/tune_supp_panels.m
% SUPPLEMENTARY FIGURE S3 -- controller gain tuning, as INDIVIDUAL panels.
%
% RUN ORDER:  run load_grid.m FIRST (defines G and A), then this script.
%             global PAPER_FINAL; PAPER_FINAL = true;   % to mirror into figures_final
%
% ---- WHY THIS SCRIPT EXISTS -------------------------------------------------
% The supplementary figure is assembled in Illustrator from individual panels, like
% every other figure in the paper -- never stitched with \includegraphics + \hfill
% (user, 2026-10-05). Until now S3 was three LaTeX-stitched images from
% paper/images/tuning/, and those three files were STALE: they were exported in June
% 2026 by producers that have since been renamed (grid_cost_surface_* -> the current
% gain_grid.m writes gain_cost_surface_*), and autotune_convergence_both.pdf has no
% producer in the repo at all. So S3 could not be "re-exported smaller" -- it had to
% be regenerated, which is what this script does.
%
% gain_grid.m and auto_tune.m are deliberately left alone. They are the exploratory
% views (and gain_grid.m is also used for talk re-exports via GG_OUTDIR); this script
% is the paper producer, the same split imp_spatial_panels.m has from spatial_spread.m.
%
% ---- WHAT "REMOVE GRIDS" MEANT (user, 2026-10-05) ---------------------------
% Both readings, confirmed by the user:
%   1. axis gridlines OFF  -> grid(ax,'off') is set explicitly on every panel;
%   2. the per-node trace MONTAGE becomes one panel per node, so the nodes can be
%      laid out by hand instead of inheriting a tiledlayout.
%
% ---- AUTO-TUNE DATA SOURCE: Kdata/Kval, NOT input_params --------------------
% auto_tune.m plots a.Kp/a.Ki/a.costTr, which come from input_params -- and
% input_params logs EVERY APPLIED CANDIDATE, including the probes the optimizer
% rejected and reverted. That is the right view for debugging the search, and the
% wrong one for a figure captioned "the tuner converges": it shows the random probes
% as if they were the trajectory.
% The accepted path is saved separately by the rig as Kdata.npy (accepted (Kp,Ki))
% and Kval.npy (the online cost of each accepted point) -- see controller-tuning/
% CLAUDE.md, "Trajectory data". Those are what this script reads.
% Both files carry a TRAILING UNINITIALISED ROW (gains written, Kval = 0) which is
% not an iteration; it is dropped. Row 1 IS real -- it is the starting controller at
% (0,0), i.e. the no-feedback cost, and it is the anchor the descent is measured from.
%
% ---- NO INTERNAL MOUSE NAMES ON THE PANEL FACE ------------------------------
% User, 2026-10-05: internal identifiers (AL_....) and session dates must not appear
% in the paper. Panels are therefore unlabelled as to subject; the filename carries a
% neutral _m1/_m2 tag and the console prints the mapping so the caption can be written
% without guessing which panel is which.

if ~exist('G','var') || ~exist('A','var')
    error('Run load_grid.m first (G and/or A not found in workspace).');
end

setPaperDefaults();
PS = paperStyle();

% Resolve the output against the PROJECT ROOT, never the current folder. `run()`
% cd's into the script's own directory, so a relative 'paper/images/tuning' silently
% creates controller-tuning/paper/images/tuning/ and writes there -- which is exactly
% what has been happening: that stray tree already holds ~20 panels from gain_grid.m
% and auto_tune.m, while the real paper/images/tuning/ still has only the June files.
PROJ    = fileparts(fileparts(mfilename('fullpath')));
out_dir = fullfile(PROJ, 'paper', 'images', 'tuning');
if ~isfolder(out_dir); mkdir(out_dir); end

% ---- the sessions S3 reports -------------------------------------------------
% Grid and auto-tune may only be compared WITHIN a mouse (locked-in decision,
% controller-tuning/CLAUDE.md). These two pairs are the valid ones, and they are also
% the only two auto-tune sessions with a live online cost: the other two logged
% Kval == 0 throughout (dead online error -> the "trajectory" is a random walk) and
% must not appear in a convergence figure.
% ONE MOUSE ONLY (user, 2026-10-05). The second row -- AL_0034 grid 2024-10-17 e30
% + AL_0034 auto-tune 2024-10-25 e1 -- WAS within-mouse, so the same-mouse rule was
% never broken. It was dropped because putting it in visual parallel with this row
% asserted an equivalence that does not hold:
%   * its grid ran on the OLDER 7-column rig build (no onset column; onsets had to be
%     reconstructed from Timeline) while its own auto-tune partner ran on the 8-column
%     build, so the pair straddles a rig change that this row does not;
%   * its grid ran dur = 4 s and was scored over [0,4] while its partner ran 3 s over
%     [0,3]. J is an un-normalised norm(y-ref), so 140 samples against 105 inflates it
%     ~1.15x before any difference in control quality enters;
%   * its best node held only -3.65 against ref -5 (~1.35% steady-state error) from a
%     +1.42 baseline, where this row's best node holds -5.18 from -0.05;
%   * AL_0034 appears NOWHERE ELSE in the paper (the controller sessions are AL_0033,
%     AL_0039, AL_0048, AL_0050, AL_0051), so it introduced a subject the reader has
%     never met, for a weaker demonstration.
% FINDINGS.md already recorded that the two rows are not equivalent -- auto-tuning
% "settles into the grid's low-cost basin (clearest in AL_0033 03-17)" but "explores
% rather than pinpoints when the basin is broad/flat (AL_0034)", and "the flat basin
% makes a strong convergence claim unsupported here". The 3 x 2 layout contradicted
% that. Full check: RESEARCH 2026-10-05.
%
% Restoring the second mouse is a one-line change: add tag/gi/ai/nodes back below.
% Keep the same-mouse rule when doing so (controller-tuning/CLAUDE.md).
PAIRS = struct( ...
    'tag',  {''}, ...             % empty -> unsuffixed filenames; a 2nd entry needs tags
    'gi',   { 3 }, ...            % index into G: AL_0033 2025-03-05
    'ai',   { 4 }, ...            % index into A: AL_0033 2025-03-17
    'nodes',{ true });            % export per-node trace panels for this mouse?

fprintf('\n=== S3 tuning panels ===\n');

for p = 1:numel(PAIRS)
    g = G(PAIRS(p).gi);
    a = A(PAIRS(p).ai);
    tg = PAIRS(p).tag;
    % With one mouse the panels are unsuffixed (supp_tune_surface.pdf); with two or
    % more each needs its tag back, so the suffix is derived rather than hard-coded.
    sfx = ''; if ~isempty(tg), sfx = ['_' tg]; end
    lbl = tg;  if isempty(lbl), lbl = 'single'; end
    fprintf('\n[%s]  grid %s %s e%d  <->  auto-tune %s %s e%d\n', ...
        lbl, g.mn, g.td, g.en, a.mn, a.td, a.en);

    % ---- accepted auto-tune path ---------------------------------------------
    [Kacc, Jacc] = local_accepted_path(a);
    if isempty(Kacc)
        warning('tune_supp_panels:noPath', '[%s] no accepted path -- skipping.', lbl);
        continue
    end
    kEnd = Kacc(end,:);
    nDistinct = size(unique(round(Kacc, 9), 'rows'), 1);
    fprintf(['   accepted path: %d iterations (%d distinct gain points -- the rest ' ...
             'are reverted probes) | cost %.3g -> %.3g (-%.0f%%) | final (Kp=%.4g, Ki=%.4g)' newline], ...
        size(Kacc,1), nDistinct, Jacc(1), Jacc(end), 100*(1 - Jacc(end)/Jacc(1)), kEnd(1), kEnd(2));

    % ===================== PANEL: cost surface J(Kp,Ki) =======================
    Kp = g.C(:,1); Ki = g.C(:,2); J = g.J;
    [Jmin, im] = min(J);
    f1 = paperFig(3.4, 2.9);
    ax = axes(f1); hold(ax,'on'); grid(ax,'off');

    % Interpolated fill + the actual swept nodes on top. 'none' extrapolation keeps
    % the fill inside the convex hull of what was measured -- the surface must not
    % imply cost was sampled where it was not.
    try
        upK = linspace(min(Kp), max(Kp), 80);
        upI = linspace(min(Ki), max(Ki), 80);
        [GX, GY] = meshgrid(upK, upI);
        F  = scatteredInterpolant(Kp, Ki, J, 'natural', 'none');
        contourf(ax, GX, GY, F(GX, GY), 12, 'LineColor', 'none');
    catch ME
        warning('tune_supp_panels:interp', '[%s] surface interp failed (%s).', lbl, ME.message);
    end
    scatter(ax, Kp, Ki, 10, J, 'filled', 'MarkerEdgeColor', 'k', 'LineWidth', 0.25);

    % Where the ONLINE tuner landed, on the OFFLINE exhaustive surface. The two
    % methods are independent, so this placement is the panel's claim.
    plot(ax, kEnd(1), kEnd(2), 'p', 'MarkerSize', 9, 'MarkerFaceColor', 'w', ...
        'MarkerEdgeColor', 'k', 'LineWidth', 0.7);

    % The tuner is NOT constrained to the swept box, so it can converge outside it.
    % Widening the axes to include the star is the honest presentation: cropping it
    % would hide that the sweep did not cover where the search went.
    xr = [min([Kp; kEnd(1)]), max([Kp; kEnd(1)])];
    yr = [min([Ki; kEnd(2)]), max([Ki; kEnd(2)])];
    xlim(ax, xr + [-1 1]*0.04*max(eps, diff(xr)));
    ylim(ax, yr + [-1 1]*0.04*max(eps, diff(yr)));
    if kEnd(2) > max(Ki) || kEnd(1) > max(Kp) || kEnd(2) < min(Ki) || kEnd(1) < min(Kp)
        fprintf('   NOTE: the converged point lies OUTSIDE the swept grid box ');
        fprintf('(Kp [%g %g], Ki [%g %g]) -- axes widened to show it.\n', ...
            min(Kp), max(Kp), min(Ki), max(Ki));
    end
    xlabel(ax, 'K_p'); ylabel(ax, 'K_i');
    % THREE ticks per axis. MATLAB's automatic choice put 0 / 0.1 / 0.2 / 0.3 on a
    % 1.5 cm axis at 6 pt, where the labels touch and read as one number.
    local_three_ticks(ax);
    colormap(ax, parula);
    % OFFLINE vs ONLINE must be distinguishable. The surface is J recomputed
    % offline by ct_process_set; the convergence panel is the rig's own online
    % cost. They are different quantities (final-online / min-offline = 0.76
    % here), so labelling both 'cost' invited reading one scale across both.
    cb = colorbar(ax); cb.Label.String = 'offline cost J';
    cb.FontSize = PS.fs; cb.Label.FontSize = PS.fs; cb.Label.FontWeight = PS.fw;
    set(cb, 'Box', 'off', 'TickDirection', 'out');
    fprintf('   grid: %d nodes | min J=%.3g at (Kp=%g, Ki=%g)\n', numel(J), Jmin, Kp(im), Ki(im));
    paperExport(f1, fullfile(out_dir, sprintf('supp_tune_surface%s.pdf', sfx)));

    % ===================== PANEL: accepted gain path ==========================
    f2 = paperFig(2.9, 2.6);
    ax2 = axes(f2); hold(ax2,'on'); grid(ax2,'off');
    plot(ax2, Kacc(:,1), Kacc(:,2), '-', 'Color', PS.col_cl, 'LineWidth', PS.lw_mean);
    scatter(ax2, Kacc(:,1), Kacc(:,2), 9, 1:size(Kacc,1), 'filled', ...
        'MarkerEdgeColor', 'k', 'LineWidth', 0.25);
    plot(ax2, Kacc(1,1), Kacc(1,2), 'o', 'MarkerSize', 4, 'MarkerFaceColor', 'w', ...
        'MarkerEdgeColor', 'k', 'LineWidth', 0.6);                       % start (0,0)
    plot(ax2, kEnd(1), kEnd(2), 'p', 'MarkerSize', 9, 'MarkerFaceColor', 'w', ...
        'MarkerEdgeColor', 'k', 'LineWidth', 0.7);                       % converged
    colormap(ax2, parula);
    xlabel(ax2, 'K_p'); ylabel(ax2, 'K_i');
    axis(ax2, 'tight');
    % Extra headroom at the top: the converged point is a 9 pt star, and an 8%
    % margin is not enough to keep it off the axis box at this panel size.
    xl = xlim(ax2); yl = ylim(ax2);
    xlim(ax2, xl + [-1 1]*0.10*max(eps, diff(xl)));
    ylim(ax2, yl + [-0.10 0.22]*max(eps, diff(yl)));
    local_three_ticks(ax2);
    paperExport(f2, fullfile(out_dir, sprintf('supp_tune_path%s.pdf', sfx)));

    % ===================== PANEL: cost vs iteration ===========================
    % Greedy accept-if-lowered, so this is a staircase by construction -- it can only
    % go down. The panel's content is HOW FAR and HOW FAST it falls, not that it
    % decreases, and the (0,0) start is what the drop is measured against.
    f3 = paperFig(2.9, 2.2);
    ax3 = axes(f3); hold(ax3,'on'); grid(ax3,'off');
    it = 1:numel(Jacc);
    stairs(ax3, it, Jacc, '-', 'Color', PS.col_cl, 'LineWidth', PS.lw_mean);
    plot(ax3, it, Jacc, 'o', 'MarkerSize', 2.5, 'MarkerFaceColor', PS.col_cl, ...
        'MarkerEdgeColor', 'none');
    yline(ax3, Jacc(end), ':', 'Color', PS.col_zero, 'LineWidth', PS.lw_ref);
    xlim(ax3, [1 numel(Jacc)]);
    ylim(ax3, [0 max(Jacc)*1.08]);
    xlabel(ax3, 'tuning iteration'); ylabel(ax3, 'online cost (rig)');
    paperExport(f3, fullfile(out_dir, sprintf('supp_tune_cost%s.pdf', sfx)));

    % ===================== PANELS: one per grid node ==========================
    if PAIRS(p).nodes
        % NODE PANELS: corner axes, no tick furniture, smaller (user, 2026-10-05).
        % These are paper panels, so they follow the house minimalist style -- a
        % short scale bar in one corner instead of a boxed, ticked axis. With the
        % ticks and their labels gone the panel also stops being padded out to
        % ~2.9 cm by the tick text, which is what was keeping it from shrinking.
        % The bar is drawn on the FIRST node only and reads for the whole matrix,
        % the same convention as the S6 strip stack; a reserved band at the bottom
        % of every panel keeps node 01's crop equal to the rest.
        nN = size(g.C, 1);
        ylN = [-11.5 7.5];           % data band -8..+4 plus room for the bar below
        for k = 1:nN
            fN = paperFig(1.6, 1.3);
            axN = axes(fN); hold(axN,'on'); grid(axN,'off'); %#ok<LAXES>
            mu = g.nodeMean(k,:); sd = g.nodeStd(k,:);
            good = ~isnan(mu);
            if any(good)
                fill(axN, [g.tt(good) fliplr(g.tt(good))], ...
                     [mu(good)+sd(good) fliplr(mu(good)-sd(good))], ...
                     PS.col_cl, 'FaceAlpha', PS.fa, 'EdgeColor', 'none');
                plot(axN, g.tt(good), mu(good), 'Color', PS.col_cl, 'LineWidth', PS.lw_mean);
            end
            yline(axN, g.ref, '--', 'Color', PS.col_zero, 'LineWidth', PS.lw_ref);
            xlim(axN, [g.tt(1) g.tt(end)]);
            % Stim window as a SHADED BAND, not two xlines, and a clear band of
            % headroom above the data for the labels. At 1.9 cm the two vertical
            % lines ran the full panel height and the gain/J labels printed straight
            % across them; a band sits behind the trace and collides with nothing.
            % Ticks stop at +4 so the headroom does not read as plotted range.
            ylim(axN, ylN);
            pb = patch(axN, 'XData', [0 g.cwin(2) g.cwin(2) 0], ...
                'YData', [ylN(1) ylN(1) ylN(2) ylN(2)], ...
                'FaceColor', [0 0 0], 'FaceAlpha', 0.06, 'EdgeColor', 'none');
            uistack(pb, 'bottom');
            axis(axN, 'off');
            if k == 1
                % House corner-axis form, drawn by hand and clipped off so it sits
                % BELOW the data box rather than a fraction inside it -- the helper
                % places the bar inside, which at this size lands on the trace.
                % Both labels are kept to the RIGHT of the vertical arm so the bar
                % adds NO width: node 01 stays 2.54 cm wide like the other nine and
                % is only taller, which is harmless because it is the (0,0)
                % no-control reference and sits apart from the 3 x 3 matrix.
                xb = g.tt(1) + 0.12;
                yb = ylN(1) + 0.02*diff(ylN);
                plot(axN, [xb xb+1], [yb yb], '-', 'Color','k', 'LineWidth',PS.sca_lw, ...
                    'Clipping','off', 'HandleVisibility','off');
                plot(axN, [xb xb], [yb yb+5], '-', 'Color','k', 'LineWidth',PS.sca_lw, ...
                    'Clipping','off', 'HandleVisibility','off');
                text(axN, xb+0.5, yb - 0.04*diff(ylN), '1 s', 'Clipping','off', ...
                    'HorizontalAlignment','center', 'VerticalAlignment','top', ...
                    'FontSize',PS.fs, 'FontWeight',PS.fw);
                text(axN, xb+0.10, yb+2.5, '5%', 'Clipping','off', ...
                    'HorizontalAlignment','left', 'VerticalAlignment','middle', ...
                    'FontSize',PS.fs, 'FontWeight',PS.fw);
            end
            % Gains and cost go ON the panel: once the montage is gone, a bare trace
            % cannot be matched back to its node during assembly.
            % TOP of the panel, not the bottom: the regulated trace sits at the
            % reference (-5 %) and the bottom third is where it and its std band live,
            % so a label there overprints the data. Above 0 the panel is empty.
            % NAME THE GAINS (user, 2026-10-05). "0.05, 0.1" does not say which
            % number is which, and the two are not interchangeable -- the whole
            % point of the matrix is that Kp and Ki do different things to the
            % trace. Written out as K_p / K_i, which TeX renders as subscripts.
            text(axN, 0.02, 0.99, sprintf('K_p %.2g  K_i %.2g', g.C(k,1), g.C(k,2)), ...
                'Units','normalized', 'VerticalAlignment','top', ...
                'Interpreter','tex', 'FontSize', PS.fs, 'FontWeight', PS.fw);
            text(axN, 0.98, 0.99, sprintf('J=%.3g', g.J(k)), ...
                'Units','normalized', 'VerticalAlignment','top', ...
                'HorizontalAlignment','right', 'FontSize', PS.fs, 'FontWeight', PS.fw);
            % No axis titles and no tick labels: the corner bar on node 01 carries
            % both scales for the matrix.
            paperExport(fN, fullfile(out_dir, sprintf('supp_tune_node%s_%02d.pdf', sfx, k)));
            fprintf('     node %02d  (Kp=%.3g, Ki=%.3g)  J=%.3g\n', k, g.C(k,1), g.C(k,2), g.J(k));
        end
    end
end

fprintf(['\n[S3] node panels carry NO axis titles by design -- add ''time (s)'' and\n     ''dF/F (%%)'' once on the edge panels during assembly.' newline]);
fprintf('\n[S3] panels -> %s\n', out_dir);

% =============================================================================
function local_three_ticks(ax)
% THIN MATLAB's automatic ticks; do not replace them.
%
% The first attempt computed ticks as the axis limits and their midpoint. That
% produced labels like -0.012, 0.15, 0.312 -- the limits are padded by a few per
% cent to keep markers off the box, so the ends are not round numbers, and the long
% strings then auto-rotated. Round values matter more than exact placement.
%
% So: keep the ticks MATLAB chose (which are round by construction) and take every
% second one until at most three remain. The stride must be EVEN -- forcing the last
% tick to survive left pairs like 0.2 / 0.3 adjacent while 0 sat far away, and the
% close pair is exactly the crowding this is here to remove. Dropping the final tick
% costs nothing: the axis limit is still visible as the end of the box.
for d = ['X' 'Y']
    t = ax.([d 'Tick']);
    while numel(t) > 3
        t = t(1:2:end);
    end
    if numel(t) >= 2
        ax.([d 'Tick']) = t;
    end
end
end

% =============================================================================
function [Kacc, Jacc] = local_accepted_path(a)
% Accepted (Kp,Ki) path and its online cost, read from the rig's own Kdata/Kval.
% Returns empty if the session has no usable path, so the caller can skip it
% rather than plot a flat line and call it convergence.
Kacc = []; Jacc = [];
try
    root = expPath(a.mn, a.td, a.en);
    Kd = double(readNPY(fullfile(root, 'Kdata.npy')));
    Kv = double(readNPY(fullfile(root, 'Kval.npy')));
catch ME
    warning('tune_supp_panels:readNPY', 'Kdata/Kval unreadable (%s)', ME.message);
    return
end
Kv = Kv(:);
n  = min(size(Kd,1), numel(Kv));
Kd = Kd(1:n, 1:2); Kv = Kv(1:n);

% Drop the trailing uninitialised slot(s): the rig pre-allocates the arrays and the
% last row is written with a cost of exactly 0, which is not an achievable cost.
last = find(Kv > 0, 1, 'last');
if isempty(last) || last < 2
    warning('tune_supp_panels:deadCost', ...
        '%s %s e%d has no live online cost (Kval == 0) -- not a convergence session.', ...
        a.mn, a.td, a.en);
    return
end
Kacc = Kd(1:last, :);
Jacc = Kv(1:last);
end
