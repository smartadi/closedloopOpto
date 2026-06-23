% bilateral-analysis/debug_stimstarts.m
% ------------------------------------------------------------------------
% DEBUG: plot the whole-experiment dF/F trace for each controlled pixel with
% vertical lines at d.stimStarts (and d.stimEnds, if present) overlaid, to
% check that stim onset times line up with the stim-evoked deflections.
%
% Uses the `d` struct already in the workspace (run a loader or
% cl_ol_single_session.m first so `d` exists). Does NOT clear the workspace.
% ------------------------------------------------------------------------

assert(exist('d','var') == 1, ...
    'No `d` in workspace. Run cl_ol_single_session.m (or initialize_data) first.');
if ~isfolder('bilateral-analysis') && isfolder(fullfile('..','bilateral-analysis')); cd('..'); end
addpath(genpath('utils'));

%% ---- knobs -------------------------------------------------------------
MARK_ENDS = true;     % also draw d.stimEnds (if available)
ZOOM_S    = 0;        % if > 0, add a second figure zoomed to first ZOOM_S seconds
% ------------------------------------------------------------------------

t  = d.timeBlue(:)';
ss = d.stimStarts(:)';
if isfield(d,'stimEnds'); se = d.stimEnds(:)'; else; se = []; end
if isfield(d,'inpVals'); iv = d.inpVals(:)'; else; iv = []; end
if isfield(d,'inpTime'); it = d.inpTime(:)'; else; it = []; end
n_in = min(numel(iv), numel(it));   % guard against length mismatch
iv = iv(1:n_in); it = it(1:n_in);

% --- console diagnostics -------------------------------------------------
fprintf('timeBlue: %d samples, range [%.3f .. %.3f] s, dt=%.4f s (%.2f Hz)\n', ...
    numel(t), t(1), t(end), median(diff(t)), 1/median(diff(t)));
fprintf('stimStarts: %d events, range [%.3f .. %.3f]\n', numel(ss), min(ss), max(ss));
if max(ss) <= numel(t) && all(ss == round(ss))
    fprintf('  NOTE: stimStarts look like SAMPLE INDICES (integers <= numel(timeBlue)), not times.\n');
end
if min(ss) < t(1) || max(ss) > t(end)
    fprintf('  WARNING: some stimStarts fall OUTSIDE the timeBlue range — onsets misaligned.\n');
end
fprintf('median inter-stim interval: %.3f s\n', median(diff(sort(ss))));
if ~isempty(it)
    fprintf('inpTime: %d samples, range [%.3f .. %.3f] s, dt=%.5f s (%.0f Hz)\n', ...
        numel(it), it(1), it(end), median(diff(it)), 1/median(diff(it)));
else
    fprintf('inpVals/inpTime: not present in d.\n');
end

% --- controlled pixel(s) -------------------------------------------------
pix_all = double(d.params.pixel);
if size(pix_all,2) ~= 2 && size(pix_all,1) == 2; pix_all = pix_all.'; end
nSite = size(pix_all,1);

%% ---- main figure: full experiment, dF per site + input trace -----------
nRow = nSite + 1;   % extra row for the laser input trace
figure('Name','debug stimStarts','Color','w');
for s = 1:nSite
    dFoF = pixelDFoF_dbg(d, pix_all(s,:));
    ax = subplot(nRow, 1, s);
    plot(ax, t, dFoF, 'Color', [0.1 0.1 0.8], 'LineWidth', 0.4); hold(ax,'on');
    yl = padlim([min(dFoF) max(dFoF)]);
    drawStimLines(ax, ss, se, yl, MARK_ENDS);
    hold(ax,'off');
    xlim(ax, [t(1) t(end)]); ylim(ax, yl);
    xlabel(ax,'Time (s)'); ylabel(ax,'\DeltaF/F (%)');
    title(ax, sprintf('site %d  pixel [x=%d y=%d]   (red = stimStarts%s)', ...
        s, round(pix_all(s,1)), round(pix_all(s,2)), ...
        ternary(MARK_ENDS && ~isempty(se), ', green-- = stimEnds', '')), ...
        'Interpreter','none');
end

% --- input trace (d.inpVals vs d.inpTime) ---
axI = subplot(nRow, 1, nRow);
if ~isempty(iv)
    plot(axI, it, iv, 'Color', [0.4 0.4 0.4], 'LineWidth', 0.4); hold(axI,'on');
    yl = padlim([min(iv) max(iv)]);
    drawStimLines(axI, ss, se, yl, MARK_ENDS);
    hold(axI,'off');
    xlim(axI, [t(1) t(end)]); ylim(axI, yl);
    xlabel(axI,'Time (s)'); ylabel(axI,'input (a.u.)');
    title(axI, 'inputs: d.inpVals (red = stimStarts)', 'Interpreter','none');
else
    text(axI, 0.5, 0.5, 'no d.inpVals / d.inpTime', 'Units','normalized', ...
        'HorizontalAlignment','center'); axis(axI,'off');
end

%% ---- optional zoom -----------------------------------------------------
if ZOOM_S > 0
    figure('Name','debug stimStarts (zoom)','Color','w');
    for s = 1:nSite
        dFoF = pixelDFoF_dbg(d, pix_all(s,:));
        ax = subplot(nRow, 1, s);
        plot(ax, t, dFoF, 'Color', [0.1 0.1 0.8], 'LineWidth', 0.6); hold(ax,'on');
        yl = padlim([min(dFoF) max(dFoF)]);
        drawStimLines(ax, ss, se, yl, MARK_ENDS);
        hold(ax,'off');
        xlim(ax, [t(1) t(1)+ZOOM_S]); ylim(ax, yl);
        xlabel(ax,'Time (s)'); ylabel(ax,'\DeltaF/F (%)');
        title(ax, sprintf('site %d (first %g s)', s, ZOOM_S));
    end
    axIz = subplot(nRow, 1, nRow);
    if ~isempty(iv)
        plot(axIz, it, iv, 'Color', [0.4 0.4 0.4], 'LineWidth', 0.6); hold(axIz,'on');
        yl = padlim([min(iv) max(iv)]);
        drawStimLines(axIz, ss, se, yl, MARK_ENDS);
        hold(axIz,'off');
        xlim(axIz, [t(1) t(1)+ZOOM_S]); ylim(axIz, yl);
        xlabel(axIz,'Time (s)'); ylabel(axIz,'input (a.u.)');
        title(axIz, sprintf('inputs (first %g s)', ZOOM_S), 'Interpreter','none');
    else
        axis(axIz,'off');
    end
end

fprintf('debug_stimstarts.m done — %d site(s), %d stim onsets.\n', nSite, numel(ss));


%% ===== local helpers ===================================================
function drawStimLines(ax, ss, se, yl, markEnds)
% Draw stimStarts (red) and optionally stimEnds (green dashed) as vertical
% lines spanning yl, each as a single line object via NaN-separated segments.
    if ~isempty(ss)
        xx = [ss; ss; nan(1,numel(ss))];
        yy = repmat([yl(1); yl(2); nan], 1, numel(ss));
        plot(ax, xx(:), yy(:), 'r-', 'LineWidth', 0.5);
    end
    if markEnds && ~isempty(se)
        xe = [se; se; nan(1,numel(se))];
        ye = repmat([yl(1); yl(2); nan], 1, numel(se));
        plot(ax, xe(:), ye(:), 'Color',[0 0.6 0], 'LineStyle','--', 'LineWidth', 0.5);
    end
end

function yl = padlim(yl)
% Guarantee a strictly increasing [lo hi] for ylim (handles flat traces).
    if ~(yl(2) > yl(1)); yl = yl(1) + [-1 1]; end
end

function dFk = pixelDFoF_dbg(d, pixel)
    try k = double(d.params.kernel); catch; k = 10; end
    x = round(pixel(1)); y = round(pixel(2));
    if isfield(d,'svd') && isfield(d.svd,'U') && isfield(d.svd,'V') && isfield(d.svd,'mimg')
        U = d.svd.U; V = d.svd.V; mimg = d.svd.mimg;
        nSV = size(U,3);
        if size(V,1) ~= nSV && size(V,2) == nSV; V = V'; end
        imkernel = U(y-k:y+k, x-k:x+k, :);
        F  = reshape(mean(imkernel,[1,2]), [1, nSV]) * V;
        mI = mean(mimg(y-k:y+k, x-k:x+k), 'all');
        dFk = F / mI * 100;
    else
        [~, dFk] = getpixel_dFoF(d, 1, [x y], 0);
    end
    dFk = double(dFk(:)');
end

function out = ternary(cond, a, b)
    if cond; out = a; else; out = b; end
end
