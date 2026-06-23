% bilateral-analysis/cl_ol_single_session.m
% ------------------------------------------------------------------------
% STANDALONE single-session controller analysis (CL vs OL) for one AL_0048
% bilateral session. Self-contained: does NOT depend on load_bilateral.m or
% the multi-session sessions{} pipeline — run this file directly.
%
% It reproduces the classic single-session controller comparison
% (analysisPlots_combined: open-loop vs closed-loop) but generalised to the
% dual-opsin bilateral case: it loops over whichever hemispheres have a
% selected pixel and analyses each side independently with its own reference.
%
% Per side it produces:
%   Fig 1  all-trials + mean trace          (OL panel | CL panel)
%   Fig 2  variance across trials over time  (OL vs CL)
%   Fig 3  trial-MSE half-violin            (OL vs CL)
% plus a console summary of MSE (mean / median) and the OL/CL ratio.
%
% Run from the brain_paper/ root (or from bilateral-analysis/ — it will cd up).
% Requires server access for initialize_data (same as load_bilateral.m).
% ------------------------------------------------------------------------

%% ---- Workspace ---------------------------------------------------------
clc; close all; clear all;
if ~isfolder('bilateral-analysis') && isfolder(fullfile('..', 'bilateral-analysis'))
    cd('..');
end
addpath(genpath('utils'));

%% ---- Session knobs -----------------------------------------------------
MN  = 'AL_0048';
TD  = '2026-06-20';   % YYYY-MM-DD
EN  = 2;              % experiment number

dur    = 3;           % controller / MSE window (s): t = 0 to +dur post-onset
fs_img = 35;          % imaging frame rate (Hz)
r_load = 1;           % 1 = use assembled-session cache if present | 0 = recompute

%% ---- Reference levels (per side, signed) -------------------------------
% Left = excitatory opsin (ref > 0); Right = inhibitory opsin (ref < 0).
REF_L = +5;
REF_R = -5;

%% ---- OL / CL trial flag  (VERIFY against the diagnostic printout!) ------
% Open/closed-loop flag in input_params. Classic controller sessions use
% column 3 (0 = open-loop, 1 = closed-loop). The script prints unique values
% per input_params column on load — confirm and adjust if this session differs.
OLCL_COL = 3;         % column holding the open/closed-loop flag
OL_CODE  = 0;         % value meaning open-loop
CL_CODE  = 1;         % value meaning closed-loop

%% ---- Trial -> site assignment (only for multi-site sessions) ------------
% Controlled-pixel locations come from d.params.pixel (handled below). If this
% session controls more than one site AND trials are tagged per site in
% input_params, set TRIAL_SITE_COL to that column (values 1..nSite, matching
% the row order of d.params.pixel). Leave empty to use ALL trials for every
% site — correct for a single-site session.
TRIAL_SITE_COL = [];

%% ---- Stim-onset re-detection (fix findStims mode-1 buffer offset) -------
% findStims mode 1 (used by initialize_data) computes onsets as
% t(input_params(:,2) - horizon); the horizon subtraction assumes a leading
% zero-buffer this session no longer has, so d.stimStarts land ~37-40 s early.
% findStims is a do-not-modify util, so we re-derive onsets here from the
% actual input command (rising edge), then override d.stimStarts/d.stimEnds.
REDETECT_STIMS = true;
IN_FIELDS      = {'inpVals638','inpVals594'};  % input command fields (vs d.inpTime)
IN_THRESH      = 0.1;   % rising-edge threshold
MIN_GAP        = 2;     % s, minimum interval between detected onsets

EXPORT_FIG = false;   % true -> PNGs to paper/images/bilateral/
% ------------------------------------------------------------------------


%% ===== Load / assemble session =========================================
cachePath = fullfile('data', sprintf('%s_clol_%s%s%d.mat', MN, TD(6:7), TD(9:10), EN));

if exist(cachePath, 'file') && r_load == 1
    S = load(cachePath);
    d     = S.d;
    sides = S.sides;
    fprintf('Loaded assembled-session cache: %s\n', cachePath);
else
    d = initialize_data(MN, EN, TD);
    if ~isfield(d, 'ref'); d.ref = -5; end

    % --- Re-detect stim onsets from the input command --------------------
    % Override findStims mode-1 onsets (offset by a stale zero-buffer).
    if REDETECT_STIMS
        det = detectStimsFromInput(d, IN_FIELDS, IN_THRESH, MIN_GAP);
        nTr = size(d.input_params, 1);
        if isempty(det)
            warning('REDETECT_STIMS: no input rising edges found — keeping findStims onsets.');
        else
            fprintf('Re-detected %d input onsets; first=%.3f s (findStims stimStarts(1)=%.3f s, offset=%+.3f s)\n', ...
                numel(det), det(1), d.stimStarts(1), d.stimStarts(1)-det(1));
            if numel(det) == nTr
                d.stimStarts = det(:)';                 % one onset per trial, in order
                d.stimEnds   = det(:)' + dur;           % dur seconds
                fprintf('  -> replaced d.stimStarts with detected onsets (count matches %d trials).\n', nTr);
            else
                shift = det(1) - d.stimStarts(1);       % constant-offset fallback
                d.stimStarts = d.stimStarts(:)' + shift;
                if isfield(d,'stimEnds'); d.stimEnds = d.stimEnds(:)' + shift; end
                warning(['detected %d onsets != %d trials; applied constant shift %+.3f s ' ...
                         'to findStims onsets instead.'], numel(det), nTr, shift);
            end
        end
    end

    % --- Controlled pixel(s) from d.params -------------------------------
    % d.params.pixel              : Nsite x 2 actual image pixels [x y] (x=col, y=row)
    % d.params.pixel_positions_mm : Nsite x 2 distance from bregma in mm
    %     mm x < 0 -> left  hemisphere (excitatory, ref = REF_L)
    %     mm x > 0 -> right hemisphere (inhibitory, ref = REF_R)
    assert(isfield(d,'params') && isfield(d.params,'pixel') && ~isempty(d.params.pixel), ...
        'd.params.pixel not found — cannot locate the controlled pixel(s).');
    pix_all = double(d.params.pixel);
    if size(pix_all,2) ~= 2 && size(pix_all,1) == 2; pix_all = pix_all.'; end
    nSite = size(pix_all,1);

    if isfield(d.params,'pixel_positions_mm') && ~isempty(d.params.pixel_positions_mm)
        mm_all = double(d.params.pixel_positions_mm);
        if size(mm_all,2) ~= 2 && size(mm_all,1) == 2; mm_all = mm_all.'; end
    else
        mm_all = nan(nSite,2);
    end

    % Frame width for the (rare) mm-missing fallback side assignment.
    if isfield(d,'svd') && isfield(d.svd,'mimg') && ~isempty(d.svd.mimg)
        frmW = size(d.svd.mimg,2);
    else
        frmW = 560;
    end

    sides = struct('name', {}, 'ref', {}, 'pix', {}, 'mm', {}, 'site', {}, 'dFoF', {});
    for s = 1:nSite
        pix = pix_all(s,:);
        mm  = mm_all(min(s,size(mm_all,1)), :);
        if ~isnan(mm(1))
            isLeft = mm(1) < 0;                 % bregma-relative mm
        else
            isLeft = pix(1) < frmW/2;           % fallback: pixel column
        end
        if isLeft; base = 'left'; ref = REF_L; else; base = 'right'; ref = REF_R; end
        nm = base;
        if ~isempty(sides) && any(strcmp({sides.name}, nm)); nm = sprintf('%s%d', base, s); end

        dFoF = pixelDFoF(d, pix);
        sides(end+1) = struct('name', nm, 'ref', ref, 'pix', pix, ...
                              'mm', mm, 'site', s, 'dFoF', dFoF); %#ok<SAGROW>
        fprintf('[site %d] %s: pixel [x=%d y=%d], mm [%.2f %.2f], ref=%g\n', ...
            s, nm, round(pix(1)), round(pix(2)), mm(1), mm(2), ref);
    end

    if ~exist('data', 'dir'); mkdir('data'); end
    save(cachePath, 'd', 'sides', '-v7.3');
    fprintf('Saved assembled-session cache: %s\n', cachePath);
end

%% ===== input_params diagnostic =========================================
ip = d.input_params;
fprintf('\ninput_params: %d trials x %d cols. Unique values per column:\n', ...
    size(ip,1), size(ip,2));
for c = 1:size(ip,2)
    u = unique(ip(:,c));
    if numel(u) <= 8
        fprintf('  col %d: %s\n', c, mat2str(u(:)'));
    else
        fprintf('  col %d: %d unique (min %.3g, max %.3g)\n', c, numel(u), min(u), max(u));
    end
end
if isempty(TRIAL_SITE_COL); siteStr = 'all trials per site'; ...
else; siteStr = sprintf('col %d', TRIAL_SITE_COL); end
fprintf('Using OL/CL flag = col %d (OL=%g, CL=%g); trial->site = %s\n\n', ...
    OLCL_COL, OL_CODE, CL_CODE, siteStr);


%% ===== Per-side controller analysis ====================================
PS = paperStyle();
t      = d.timeBlue(:)';
n_pre  = round(3 * fs_img);          % 3 s pre-onset
n_win  = round((dur + 3) * fs_img);  % onset .. dur+3 s
n_err  = round(dur * fs_img);        % MSE window (0 .. dur)
T      = (-n_pre : n_win) / fs_img;  % trace time axis
Tref   = (0 : n_err) / fs_img;

results = struct();

for si = 1:numel(sides)
    sd   = sides(si);
    dFoF = sd.dFoF;
    ref  = sd.ref;
    if numel(dFoF) ~= numel(t)
        warning('[%s] dFoF length (%d) ~= timeBlue length (%d) — using min overlap.', ...
            sd.name, numel(dFoF), numel(t));
    end

    % --- trial selection: this site's trials, split by OL/CL --------------
    nTrials = size(ip, 1);
    if ~isempty(TRIAL_SITE_COL) && numel(sides) > 1
        sideMask = ip(:, TRIAL_SITE_COL) == sd.site;
    else
        sideMask = true(nTrials, 1);
        if numel(sides) > 1 && si == 1
            warning(['Multi-site session but TRIAL_SITE_COL is empty: using ALL ' ...
                     'trials for every site. Set TRIAL_SITE_COL if trials are site-tagged.']);
        end
    end
    olMask = sideMask & ip(:, OLCL_COL) == OL_CODE;
    clMask = sideMask & ip(:, OLCL_COL) == CL_CODE;
    nc = find(olMask);   % open-loop trial indices
    wc = find(clMask);   % closed-loop trial indices

    if isempty(nc) && isempty(wc)
        fprintf('[%s] no OL/CL trials after filtering — skipping.\n', sd.name);
        continue;
    end

    % --- window each trial: pre .. dur+3 s; MSE over 0 .. dur -------------
    [ncTr, er_nc] = sliceTrials(dFoF, t, d.stimStarts, nc, n_pre, n_win, n_err, ref);
    [wcTr, er_wc] = sliceTrials(dFoF, t, d.stimStarts, wc, n_pre, n_win, n_err, ref);

    results.(sd.name).nc     = nc;     results.(sd.name).wc     = wc;
    results.(sd.name).ncTr   = ncTr;   results.(sd.name).wcTr   = wcTr;
    results.(sd.name).er_nc  = er_nc;  results.(sd.name).er_wc  = er_wc;
    results.(sd.name).ref    = ref;

    fprintf('[%s] OL: %d trials, MSE mean=%.3f median=%.3f | CL: %d trials, MSE mean=%.3f median=%.3f | OL/CL=%.2f\n', ...
        sd.name, numel(nc), mean(er_nc,'omitnan'), median(er_nc,'omitnan'), ...
        numel(wc), mean(er_wc,'omitnan'), median(er_wc,'omitnan'), ...
        mean(er_nc,'omitnan')/mean(er_wc,'omitnan'));

    %% ---- Fig 1: all trials + mean (OL | CL) ----------------------------
    f1 = paperFig(9, 4);
    set(f1, 'Name', sprintf('CLvsOL traces | %s | %s', sd.name, MN));
    axOL = axes(f1, 'Position', [0.08 0.14 0.42 0.74]);
    axCL = axes(f1, 'Position', [0.55 0.14 0.42 0.74]);
    drawTracePanel(axOL, T, ncTr, ref, dur, PS.col_ol, PS, ...
        sprintf('Open-Loop (%s)', sd.name));
    drawTracePanel(axCL, T, wcTr, ref, dur, PS.col_cl, PS, ...
        sprintf('Closed-Loop (%s)', sd.name));
    linkaxes([axOL axCL], 'xy');

    %% ---- Fig 2: variance over time (OL vs CL) --------------------------
    f2 = paperFig(6, 4);
    set(f2, 'Name', sprintf('CLvsOL variance | %s | %s', sd.name, MN));
    ax2 = axes(f2, 'Position', [0.15 0.14 0.80 0.78]);
    hold(ax2, 'on');
    if ~isempty(ncTr)
        plot(ax2, T, var(ncTr, 0, 1), 'Color', PS.col_ol, 'LineWidth', PS.lw_mean, 'DisplayName','OL');
    end
    if ~isempty(wcTr)
        plot(ax2, T, var(wcTr, 0, 1), 'Color', PS.col_cl, 'LineWidth', PS.lw_mean, 'DisplayName','CL');
    end
    xline(ax2, 0, 'LineWidth', PS.lw_zero, 'HandleVisibility','off');
    xline(ax2, dur, 'LineWidth', PS.lw_zero, 'HandleVisibility','off');
    addStimPatch(ax2, 0, dur);
    uistack(findobj(ax2,'Type','line'), 'top');
    hold(ax2, 'off');
    xlim(ax2, [-3 dur+3]);
    xlabel(ax2, 'Time (s)', 'FontSize', PS.fs, 'FontWeight', PS.fw);
    ylabel(ax2, 'Variance across trials', 'FontSize', PS.fs, 'FontWeight', PS.fw);
    title(ax2, sprintf('%s | %s', sd.name, MN), 'FontSize', PS.fs, 'FontWeight', PS.fw);
    lgd2 = legend(ax2, 'Location', 'best'); paperLegend(lgd2);

    %% ---- Fig 3: trial-MSE half-violin (OL vs CL) -----------------------
    f3 = paperFig(3, 4);
    set(f3, 'Name', sprintf('CLvsOL MSE | %s | %s', sd.name, MN));
    ax3 = axes(f3, 'Position', [0.18 0.15 0.77 0.75]);
    hold(ax3, 'on');
    hw = 0.3;
    if numel(er_nc) > 1
        [fA, yA] = ksdensity(er_nc); fA = fA / max(fA) * hw;
        fill(ax3, [1 - fA, ones(1,numel(fA))], [yA, fliplr(yA)], PS.col_ol, ...
            'FaceAlpha', PS.fa, 'EdgeColor','none', 'HandleVisibility','off');
        plot(ax3, 1 - 0.1, mean(er_nc,'omitnan'), '*', 'Color', PS.col_ol, ...
            'MarkerSize', 5, 'LineWidth', 1, 'HandleVisibility','off');
    end
    if numel(er_wc) > 1
        [fB, yB] = ksdensity(er_wc); fB = fB / max(fB) * hw;
        fill(ax3, [1 + fB, ones(1,numel(fB))], [yB, fliplr(yB)], PS.col_cl, ...
            'FaceAlpha', PS.fa, 'EdgeColor','none', 'HandleVisibility','off');
        plot(ax3, 1 + 0.1, mean(er_wc,'omitnan'), '*', 'Color', PS.col_cl, ...
            'MarkerSize', 5, 'LineWidth', 1, 'HandleVisibility','off');
    end
    hold(ax3, 'off');
    xlim(ax3, [0.5 1.5]); ax3.XTick = [];
    ylabel(ax3, 'Trial MSE  (||\DeltaF/F - ref||)', 'FontSize', PS.fs, 'FontWeight', PS.fw);
    title(ax3, sprintf('%s', sd.name), 'FontSize', PS.fs, 'FontWeight', PS.fw);
    set(ax3, 'Box','off', 'TickDir','out', 'FontSize', PS.fs, 'FontWeight', PS.fw);

    %% ---- Optional export -----------------------------------------------
    if EXPORT_FIG
        outDir = fullfile('paper', 'images', 'bilateral');
        if ~exist(outDir, 'dir'); mkdir(outDir); end
        exportgraphics(f1, fullfile(outDir, sprintf('clol_traces_%s_%s.png', MN, sd.name)), 'Resolution', 300);
        exportgraphics(f2, fullfile(outDir, sprintf('clol_variance_%s_%s.png', MN, sd.name)), 'Resolution', 300);
        exportgraphics(f3, fullfile(outDir, sprintf('clol_mse_%s_%s.png', MN, sd.name)), 'Resolution', 300);
    end
end

fprintf('\ncl_ol_single_session.m complete for %s %s exp %d.\n', MN, TD, EN);


%% ===== Local helpers ===================================================
function det = detectStimsFromInput(d, fields, thr, minGap)
% Detect stim onsets as rising edges (> thr) of the combined input command in
% `fields` (vs d.inpTime), deduped by a minGap-second refractory. Returns onset
% TIMES (row vector). Mirrors findStims mode 0 but on the per-channel fields.
    det = [];
    if ~isfield(d,'inpTime') || isempty(d.inpTime); return; end
    it  = d.inpTime(:)';
    sig = zeros(1, numel(it));
    for f = 1:numel(fields)
        if ~isfield(d, fields{f}); continue; end
        yv = d.(fields{f})(:)';  n = min(numel(it), numel(yv));
        sig(1:n) = max(sig(1:n), abs(yv(1:n)));
    end
    rise = sig(2:end) > thr & sig(1:end-1) <= thr;
    on   = it([false, rise]);
    if ~isempty(on); det = on([true, diff(on) > minGap]); end
end

function dFk = pixelDFoF(d, pixel)
% Single-pixel dF/F (% of mean image) reconstructed from the session SVD at
% image coordinate pixel = [x y] (x = column, y = row). Mirrors the SVD path
% of utils/getpixel_dFoF (mode 1). Falls back to getpixel_dFoF if d.svd is
% absent (re-reads SVD from the server; r=0 forces recompute per pixel).
    try k = double(d.params.kernel); catch; k = 10; end
    x = round(pixel(1)); y = round(pixel(2));
    if isfield(d, 'svd') && isfield(d.svd, 'U') && isfield(d.svd, 'V') && isfield(d.svd, 'mimg')
        U = d.svd.U; V = d.svd.V; mimg = d.svd.mimg;
        nSV = size(U, 3);
        if size(V, 1) ~= nSV && size(V, 2) == nSV; V = V'; end   % want [nSV x T]
        if x-k < 1 || y-k < 1 || x+k > size(U,2) || y+k > size(U,1)
            error('pixelDFoF: pixel [x=%d y=%d] +/- kernel %d is outside U [%dx%d].', ...
                x, y, k, size(U,1), size(U,2));
        end
        imkernel = U(y-k:y+k, x-k:x+k, :);
        imstack  = reshape(mean(imkernel, [1, 2]), [1, nSV]);
        F        = imstack * V;                                  % 1 x T
        mI       = mean(mimg(y-k:y+k, x-k:x+k), 'all');
        dFk      = F / mI * 100;
    else
        [~, dFk] = getpixel_dFoF(d, 1, [x y], 0);
    end
    dFk = double(dFk(:)');
end

function [traces, err] = sliceTrials(dFoF, t, stimStarts, idx, n_pre, n_win, n_err, ref)
% Window each trial around stim onset and compute per-trial MSE (norm to ref
% over the 0..dur window). Skips trials whose window runs off either edge.
    traces = [];
    err    = NaN(numel(idx), 1);
    for j = 1:numel(idx)
        [~, i0] = min(abs(t - stimStarts(idx(j))));
        if i0 - n_pre < 1 || i0 + n_win > numel(dFoF); continue; end
        traces      = [traces; dFoF(i0 - n_pre : i0 + n_win)]; %#ok<AGROW>
        seg         = dFoF(i0 : i0 + n_err);
        err(j)      = norm(seg - ref);
    end
end

function drawTracePanel(ax, T, traces, ref, dur, col, PS, ttl)
% All-trials (faint) + mean (+/- std ribbon) + reference, with stim patch.
    hold(ax, 'on');
    if ~isempty(traces)
        mu = mean(traces, 1);
        sd = std(traces, 0, 1);
        fill(ax, [T fliplr(T)], [mu+sd fliplr(mu-sd)], col, ...
            'FaceAlpha', PS.fa, 'EdgeColor','none', 'HandleVisibility','off');
        plot(ax, T, traces', 'Color', [0.7 0.7 0.7], 'LineWidth', PS.lw_trial, 'HandleVisibility','off');
        plot(ax, T, mu, 'Color', col, 'LineWidth', PS.lw_mean, 'HandleVisibility','off');
    end
    plot(ax, [0 dur], [ref ref], '--k', 'LineWidth', PS.lw_ref, 'HandleVisibility','off');
    xline(ax, 0, 'LineWidth', PS.lw_zero, 'HandleVisibility','off');
    xline(ax, dur, 'LineWidth', PS.lw_zero, 'HandleVisibility','off');
    addStimPatch(ax, 0, dur);
    uistack(findobj(ax,'Type','line'), 'top');
    hold(ax, 'off');
    xlim(ax, [-3 dur+3]);
    xlabel(ax, 'Time (s)', 'FontSize', PS.fs, 'FontWeight', PS.fw);
    ylabel(ax, '\DeltaF/F (%)', 'FontSize', PS.fs, 'FontWeight', PS.fw);
    title(ax, ttl, 'FontSize', PS.fs, 'FontWeight', PS.fw);
    set(ax, 'Box','off', 'TickDir','out', 'FontSize', PS.fs, 'FontWeight', PS.fw);
end
