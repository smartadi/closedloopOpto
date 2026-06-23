% bilateral-analysis/debug_stimstarts.m
% ------------------------------------------------------------------------
% DEBUG: single plot of the whole-experiment dF/F trace(s) for the controlled
% pixel(s) plus the input fields in IN_FIELDS (e.g. d.inpVals638, d.inpVals594)
% vs d.inpTime, with vertical lines at d.stimStarts (and d.stimEnds) overlaid,
% to check that stim onsets line up with the deflections / input commands.
%
% Uses the `d` struct already in the workspace (run a loader or
% cl_ol_single_session.m first so `d` exists). Does NOT clear the workspace.
% ------------------------------------------------------------------------
close all;
assert(exist('d','var') == 1, ...
    'No `d` in workspace. Run cl_ol_single_session.m (or initialize_data) first.');
if ~isfolder('bilateral-analysis') && isfolder(fullfile('..','bilateral-analysis')); cd('..'); end
addpath(genpath('utils'));

%% ---- knobs -------------------------------------------------------------
MARK_ENDS     = true;    % also draw d.stimEnds (if available)
ZOOM_S        = 0;       % if > 0, set xlim to the first ZOOM_S seconds
IN_FIELDS     = {'inpVals638','inpVals594'};   % input fields of d to overlay (vs d.inpTime)
SHOW_DETECTED = true;    % overlay onsets re-detected from the input fields (magenta)
IN_THRESH     = 0.1;     % rising-edge threshold on the input command
MIN_GAP       = 2;       % s, minimum interval between detected onsets
% ------------------------------------------------------------------------

t  = d.timeBlue(:)';
ss = d.stimStarts(:)';
if isfield(d,'stimEnds'); se = d.stimEnds(:)'; else; se = []; end
if isfield(d,'inpTime'); it = d.inpTime(:)'; else; it = []; end

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

%% ---- single plot: dF per site + input channels + stimStarts ------------
figure('Name','debug stimStarts','Color','w');
ax = axes; hold(ax,'on');

% dF/F trace(s) for the controlled pixel(s)
for s = 1:nSite
    dFoF = pixelDFoF_dbg(d, pix_all(s,:));
    plot(ax, t, dFoF, 'LineWidth', 0.5, ...
        'DisplayName', sprintf('dF site %d [%d,%d]', s, round(pix_all(s,1)), round(pix_all(s,2))));
end

% input fields (e.g. d.inpVals638, d.inpVals594) vs d.inpTime
for f = 1:numel(IN_FIELDS)
    fn = IN_FIELDS{f};
    if ~isfield(d, fn)
        fprintf('  skip input field d.%s (not present)\n', fn); continue;
    end
    yv = d.(fn)(:)';
    if isempty(it); xv = 1:numel(yv); else; n = min(numel(it), numel(yv)); xv = it(1:n); yv = yv(1:n); end
    plot(ax, xv, yv, 'LineWidth', 0.5, 'DisplayName', sprintf('d.%s', fn));
end

% re-detect onsets from the input command (rising edge), to compare against
% d.stimStarts — mode-1 onsets look offset by a stale leading zero-buffer.
det = [];
if SHOW_DETECTED && ~isempty(it)
    sig = zeros(1, numel(it));
    for f = 1:numel(IN_FIELDS)
        fn = IN_FIELDS{f};
        if ~isfield(d, fn); continue; end
        yv = d.(fn)(:)';  n = min(numel(it), numel(yv));
        sig(1:n) = max(sig(1:n), abs(yv(1:n)));
    end
    rise = sig(2:end) > IN_THRESH & sig(1:end-1) <= IN_THRESH;
    on   = it([false, rise]);
    if ~isempty(on); det = on([true, diff(on) > MIN_GAP]); end
    if ~isempty(det)
        fprintf('detected %d input onsets; first=%.3f s  (stimStarts(1)=%.3f s, offset=%+.3f s)\n', ...
            numel(det), det(1), ss(1), ss(1)-det(1));
    else
        fprintf('SHOW_DETECTED: no rising edges above IN_THRESH=%.3g in %s\n', ...
            IN_THRESH, strjoin(IN_FIELDS, ','));
    end
end

% stimStarts (red) / stimEnds (green dashed) verticals over the full y-range
yl = ylim(ax);
drawStimLines(ax, ss, se, yl, MARK_ENDS);
if ~isempty(det)
    xd = [det; det; nan(1,numel(det))];
    yd = repmat([yl(1); yl(2); nan], 1, numel(det));
    plot(ax, xd(:), yd(:), 'm-', 'LineWidth', 0.75, 'DisplayName', 'detected onsets');
end
ylim(ax, yl);
if ZOOM_S > 0; xlim(ax, [t(1) t(1)+ZOOM_S]); else; xlim(ax, [t(1) t(end)]); end

hold(ax,'off');
xlabel(ax,'Time (s)'); ylabel(ax,'\DeltaF/F (%)  /  input');
title(ax,'dF + inputs;  red = stimStarts, green-- = stimEnds','Interpreter','none');
legend(ax,'show','Location','best');

fprintf('debug_stimstarts.m done — %d site(s), %d stim onsets.\n', nSite, numel(ss));


%% ===== local helpers ===================================================
function drawStimLines(ax, ss, se, yl, markEnds)
% Draw stimStarts (red) and optionally stimEnds (green dashed) as vertical
% lines spanning yl, each as a single line object via NaN-separated segments.
    if ~isempty(ss)
        xx = [ss; ss; nan(1,numel(ss))];
        yy = repmat([yl(1); yl(2); nan], 1, numel(ss));
        plot(ax, xx(:), yy(:), 'r-', 'LineWidth', 0.5, 'HandleVisibility','off');
    end
    if markEnds && ~isempty(se)
        xe = [se; se; nan(1,numel(se))];
        ye = repmat([yl(1); yl(2); nan], 1, numel(se));
        plot(ax, xe(:), ye(:), 'Color',[0 0.6 0], 'LineStyle','--', 'LineWidth', 0.5, 'HandleVisibility','off');
    end
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
