% bilateral/cl_ol_single_session.m
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
%   Fig 4  input-command traces             (OL panel | CL panel, all + mean)
%   Fig 5  mean instantaneous tracking err   (OL vs CL overlaid)
% plus a console summary of MSE (mean / median) and the OL/CL ratio.
%
% Run from the brain_paper/ root (or from bilateral/ — it will cd up).
% Requires server access for initialize_data (same as load_bilateral.m).
% ------------------------------------------------------------------------

%% ---- Workspace ---------------------------------------------------------
clc; close all; clear all;
if ~isfolder('bilateral') && isfolder(fullfile('..', 'bilateral'))
    cd('..');
end
addpath(genpath('utils'));

%% ---- Session knobs -----------------------------------------------------
% MN  = 'AL_0048';
% TD  = '2026-06-20';   % YYYY-MM-DD
% EN  = 2;              % experiment number


MN  = 'AL_0048';
TD  = '2026-06-24';   % YYYY-MM-DD
EN  = 5;              % experiment number

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

%% ---- Trial range: warm-up exclusion ------------------------------------
% Only the last USE_LAST_N trials feed the OL/CL comparison; the earlier
% trials are session-start warm-up (controller settling — e.g. AL_0048 06-24
% e5 opens with a CL block whose first trials carry pre-onset input/high
% baseline). Set USE_LAST_N = Inf to use every trial.
USE_LAST_N = 100;

%% ---- Stim-onset derivation (fix findStims mode-1 buffer offset) ---------
% findStims mode 1 (used by initialize_data) computes onsets as
% t(input_params(:,2) - horizon); the horizon subtraction assumes a leading
% zero-buffer this session no longer has, so d.stimStarts land ~37-40 s early.
% findStims is a do-not-modify util, so we re-derive onsets here. input_params
% column 2 holds an imaging-frame index, but it is logged at TRIAL END, so
% timeBlue at that frame is ONSET_LEAD_S seconds AFTER the true stim onset.
% ONSET_LEAD_S = 2.918 s was measured from the OL input-pulse rising edges
% (std 0.009 s across 51 trials); the true onset is timeBlue(frame) - lead.
% This is exact and one onset per trial. (Rising-edge re-detection was tried
% and rejected: the input is continuously active for CL trials, and the
% nearest-neighbour offset estimate aliases when the offset (~37 s) exceeds
% half the ~11 s trial spacing.)
REDETECT_STIMS  = true;
ONSET_FRAME_COL = 2;        % input_params column holding the (trial-end) frame index
ONSET_LEAD_S    = 2.918;    % s, subtract from frame time to reach true stim onset
% Per-condition lead override. ONSET_LEAD_S was measured on OL rising edges; CL
% trials log the trial-end frame with a different lead (CL input is continuously
% active), so reusing the OL lead lands the CL marker ~1 s late and the stim
% appears at t = -1. Set ONSET_LEAD_S_CL to the CL-specific lead to realign CL
% onsets to t = 0; leave [] to use ONSET_LEAD_S for every trial.
ONSET_LEAD_S_CL = ONSET_LEAD_S + 1.0;   % [] -> same lead as OL
% combined input command fields (vs d.inpTime) — used only for debug overlays
IN_FIELDS       = {'inpVals638','inpVals594'};

%% ---- Debug -------------------------------------------------------------
% DEBUG shows: (1) brain image + controlled-pixel/kernel overlay, (2) full
% experiment dF + input + corrected stimStarts, (3) N_EX example OL/CL trials
% with the windowed input overlaid — to verify pixel/kernel and trial cutting
% BEFORE trusting the CL/OL analysis. Set RUN_ANALYSIS = false to stop after
% the debug figures.
DEBUG        = true;
N_EX         = 4;     % example trials per condition (OL / CL)
RUN_ANALYSIS = true;  % false -> only debug figures, skip CL/OL analysis figures

EXPORT_FIG = true;   % true -> PNGs to paper/images/bilateral/
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

%% ===== Stim onsets from input_params frame index ======================
% input_params(:,ONSET_FRAME_COL) is an imaging-frame index logged at trial
% END, so timeBlue at that frame is ONSET_LEAD_S after the true stim onset; we
% subtract the lead to recover the onset (one per trial, in input_params order).
% This bypasses findStims mode 1, which subtracts a horizon buffer this session
% no longer has and lands onsets ~37 s early. Runs on EVERY execution so a stale
% cache cannot leave the offset findStims onsets in place; findStims (a
% do-not-modify util) is untouched.
if REDETECT_STIMS
    nTr = size(d.input_params, 1);
    fr  = round(d.input_params(:, ONSET_FRAME_COL));
    if any(fr < 1) || any(fr > numel(d.timeBlue))
        warning(['ONSET_FRAME_COL=%d has %d frame indices outside timeBlue ' ...
                 '[1..%d] — clamping.'], ONSET_FRAME_COL, ...
                 sum(fr < 1 | fr > numel(d.timeBlue)), numel(d.timeBlue));
        fr = min(max(fr, 1), numel(d.timeBlue));
    end
    % per-trial lead: OL trials use ONSET_LEAD_S; CL trials use the CL-specific
    % lead (if set) so their onset realigns to t = 0 instead of t = -1.
    lead = repmat(ONSET_LEAD_S, nTr, 1);
    nCL  = 0;
    if ~isempty(ONSET_LEAD_S_CL)
        clTr       = d.input_params(:, OLCL_COL) == CL_CODE;
        lead(clTr) = ONSET_LEAD_S_CL;
        nCL        = nnz(clTr);
    end
    d.stimStarts = d.timeBlue(fr).' - lead.';         % 1 x nTr, imaging clock
    d.stimEnds   = d.stimStarts + dur;                % dur seconds
    if isempty(ONSET_LEAD_S_CL)
        leadCLStr = sprintf('CL %.3f s (same)', ONSET_LEAD_S);
    else
        leadCLStr = sprintf('CL %.3f s for %d trials', ONSET_LEAD_S_CL, nCL);
    end
    fprintf(['Stim onsets from input_params(:,%d) frame index - lead (OL %.3f s, ' ...
             '%s): %d trials, first onset %.2f s, median trial gap %.2f s.\n'], ...
             ONSET_FRAME_COL, ONSET_LEAD_S, leadCLStr, nTr, d.stimStarts(1), ...
             median(diff(d.stimStarts)));
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

% combined input command (for debug overlays)
[inT, inSig] = combinedInput(d, IN_FIELDS);

%% ===== DEBUG: brain/pixel overlay + full-experiment traces =============
if DEBUG
    % (1) brain image + controlled-pixel / kernel box
    if isfield(d,'svd') && isfield(d.svd,'mimg') && ~isempty(d.svd.mimg)
        try kdbg = double(d.params.kernel); catch; kdbg = 10; end
        figure('Name','DEBUG brain + pixel overlay','Color','w');
        imagesc(d.svd.mimg); axis image off; colormap(gca,'gray'); hold on;
        for si = 1:numel(sides)
            px = sides(si).pix;
            plot(px(1), px(2), 'r+', 'MarkerSize', 14, 'LineWidth', 1.5);
            rectangle('Position', [px(1)-kdbg, px(2)-kdbg, 2*kdbg, 2*kdbg], ...
                'EdgeColor','r', 'LineWidth', 1);
            text(px(1)+kdbg+4, px(2), sprintf('%s [%d,%d]', sides(si).name, ...
                round(px(1)), round(px(2))), 'Color','r', 'FontWeight','bold', 'Interpreter','none');
        end
        title(sprintf('mean image + controlled pixel(s), kernel=%d', kdbg));
        hold off;
    else
        warning('DEBUG: d.svd.mimg not available — skipping brain overlay.');
    end

    % (2) full-experiment dF + input + corrected stimStarts, per site
    for si = 1:numel(sides)
        figure('Name', sprintf('DEBUG full trace | %s', sides(si).name), 'Color','w');
        ax = axes; hold(ax,'on');
        plot(ax, t, sides(si).dFoF, 'Color',[0.1 0.1 0.8], 'LineWidth',0.4, 'DisplayName','dF');
        if ~isempty(inSig)
            plot(ax, inT, inSig, 'Color',[0.5 0.5 0.5], 'LineWidth',0.4, 'DisplayName','input');
        end
        yl = ylim(ax);
        drawStimVerticals(ax, d.stimStarts, yl, 'r');
        ylim(ax, yl); xlim(ax, [t(1) t(end)]);
        xlabel(ax,'Time (s)'); ylabel(ax,'\DeltaF/F (%) / input');
        title(ax, sprintf('%s: full trace, red = stimStarts (corrected)', sides(si).name), ...
            'Interpreter','none');
        legend(ax,'show','Location','best'); hold(ax,'off');
    end
end

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
    % keep only the last USE_LAST_N trials (drop session-start warm-up)
    useMask  = false(nTrials, 1);
    firstUse = max(1, nTrials - USE_LAST_N + 1);
    useMask(firstUse:nTrials) = true;
    if si == 1
        fprintf('Trial range: using last %d of %d trials (%d..%d); dropped first %d as warm-up.\n', ...
            min(USE_LAST_N, nTrials), nTrials, firstUse, nTrials, firstUse - 1);
    end

    olMask = sideMask & useMask & ip(:, OLCL_COL) == OL_CODE;
    clMask = sideMask & useMask & ip(:, OLCL_COL) == CL_CODE;
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

    %% ---- DEBUG: example OL/CL trials (dF + windowed input) -------------
    if DEBUG
        plotExampleTrials(T, ncTr, nc, d.stimStarts, inT, inSig, ref, dur, ...
            PS.col_ol, sprintf('%s OL', sd.name), N_EX);
        plotExampleTrials(T, wcTr, wc, d.stimStarts, inT, inSig, ref, dur, ...
            PS.col_cl, sprintf('%s CL', sd.name), N_EX);
    end

    if ~RUN_ANALYSIS; continue; end

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
    e_nc = er_nc(isfinite(er_nc));   % drop off-edge (NaN) trials — ksdensity rejects NaN
    e_wc = er_wc(isfinite(er_wc));
    if numel(e_nc) > 1
        [fA, yA] = ksdensity(e_nc); fA = fA / max(fA) * hw;
        fill(ax3, [1 - fA, ones(1,numel(fA))], [yA, fliplr(yA)], PS.col_ol, ...
            'FaceAlpha', PS.fa, 'EdgeColor','none', 'HandleVisibility','off');
        plot(ax3, 1 - 0.1, mean(e_nc), '*', 'Color', PS.col_ol, ...
            'MarkerSize', 5, 'LineWidth', 1, 'HandleVisibility','off');
    end
    if numel(e_wc) > 1
        [fB, yB] = ksdensity(e_wc); fB = fB / max(fB) * hw;
        fill(ax3, [1 + fB, ones(1,numel(fB))], [yB, fliplr(yB)], PS.col_cl, ...
            'FaceAlpha', PS.fa, 'EdgeColor','none', 'HandleVisibility','off');
        plot(ax3, 1 + 0.1, mean(e_wc), '*', 'Color', PS.col_cl, ...
            'MarkerSize', 5, 'LineWidth', 1, 'HandleVisibility','off');
    end
    hold(ax3, 'off');
    xlim(ax3, [0.5 1.5]); ax3.XTick = [];
    ylabel(ax3, 'Trial MSE  (||\DeltaF/F - ref||)', 'FontSize', PS.fs, 'FontWeight', PS.fw);
    title(ax3, sprintf('%s', sd.name), 'FontSize', PS.fs, 'FontWeight', PS.fw);
    set(ax3, 'Box','off', 'TickDir','out', 'FontSize', PS.fs, 'FontWeight', PS.fw);

    %% ---- Fig 4: input-command traces (OL | CL), all trials + mean ------
    % Window the combined input command per trial onto a common onset-relative
    % axis (its own sample rate, not the imaging grid) and overlay every trial
    % plus the across-trial mean — OL pulses vs CL continuous drive.
    f4 = [];
    if ~isempty(inSig)
        dt_in = median(diff(inT));
        Tin   = (-3 : dt_in : dur + 3);
        ncIn  = sliceInputTrials(inT, inSig, d.stimStarts, nc, Tin);
        wcIn  = sliceInputTrials(inT, inSig, d.stimStarts, wc, Tin);

        f4 = paperFig(9, 4);
        set(f4, 'Name', sprintf('CLvsOL input | %s | %s', sd.name, MN));
        axOLi = axes(f4, 'Position', [0.08 0.14 0.42 0.74]);
        axCLi = axes(f4, 'Position', [0.55 0.14 0.42 0.74]);
        drawInputPanel(axOLi, Tin, ncIn, dur, PS.col_ol, PS, sprintf('OL input (%s)', sd.name));
        drawInputPanel(axCLi, Tin, wcIn, dur, PS.col_cl, PS, sprintf('CL input (%s)', sd.name));
        linkaxes([axOLi axCLi], 'xy');
    else
        fprintf('[%s] no input command (d.inpTime empty) — skipping input-trace figure.\n', sd.name);
    end

    %% ---- Fig 5: mean instantaneous tracking error (OL vs CL) -----------
    % |dF/F - ref| averaged across trials at each time point, OL and CL on the
    % same axes (+/- SEM ribbon). CL should pull the post-onset error below OL.
    f5 = paperFig(6, 4);
    set(f5, 'Name', sprintf('CLvsOL tracking error | %s | %s', sd.name, MN));
    ax5 = axes(f5, 'Position', [0.15 0.14 0.80 0.78]);
    hold(ax5, 'on');
    plotMeanErr(ax5, T, ncTr, ref, PS.col_ol, PS, 'OL');
    plotMeanErr(ax5, T, wcTr, ref, PS.col_cl, PS, 'CL');
    xline(ax5, 0, 'LineWidth', PS.lw_zero, 'HandleVisibility','off');
    xline(ax5, dur, 'LineWidth', PS.lw_zero, 'HandleVisibility','off');
    addStimPatch(ax5, 0, dur);
    uistack(findobj(ax5,'Type','line'), 'top');
    hold(ax5, 'off');
    xlim(ax5, [-3 dur+3]);
    xlabel(ax5, 'Time (s)', 'FontSize', PS.fs, 'FontWeight', PS.fw);
    ylabel(ax5, 'Mean |\DeltaF/F - ref| (%)', 'FontSize', PS.fs, 'FontWeight', PS.fw);
    title(ax5, sprintf('%s | %s', sd.name, MN), 'FontSize', PS.fs, 'FontWeight', PS.fw);
    lgd5 = legend(ax5, 'Location', 'best'); paperLegend(lgd5);

    %% ---- Optional export -----------------------------------------------
    if EXPORT_FIG
        outDir = fullfile('paper', 'images', 'bilateral');
        if ~exist(outDir, 'dir'); mkdir(outDir); end
        exportgraphics(f1, fullfile(outDir, sprintf('clol_traces_%s_%s.png', MN, sd.name)), 'Resolution', 300);
        exportgraphics(f2, fullfile(outDir, sprintf('clol_variance_%s_%s.png', MN, sd.name)), 'Resolution', 300);
        exportgraphics(f3, fullfile(outDir, sprintf('clol_mse_%s_%s.png', MN, sd.name)), 'Resolution', 300);
        if ~isempty(f4)
            exportgraphics(f4, fullfile(outDir, sprintf('clol_input_%s_%s.png', MN, sd.name)), 'Resolution', 300);
        end
        exportgraphics(f5, fullfile(outDir, sprintf('clol_trackerr_%s_%s.png', MN, sd.name)), 'Resolution', 300);
    end
end

fprintf('\ncl_ol_single_session.m complete for %s %s exp %d.\n', MN, TD, EN);


%% ===== Local helpers ===================================================
function [inT, inSig] = combinedInput(d, fields)
% Combined input command magnitude (max across fields) vs d.inpTime.
    inT = []; inSig = [];
    if ~isfield(d,'inpTime') || isempty(d.inpTime); return; end
    inT = d.inpTime(:)';  inSig = zeros(1, numel(inT));
    for f = 1:numel(fields)
        if ~isfield(d, fields{f}); continue; end
        yv = d.(fields{f})(:)';  n = min(numel(inT), numel(yv));
        inSig(1:n) = max(inSig(1:n), abs(yv(1:n)));
    end
end

function drawStimVerticals(ax, x, yl, color)
% Vertical lines at x spanning yl, as one line object (NaN-separated).
    x = x(:)';
    if isempty(x); return; end
    xx = [x; x; nan(1,numel(x))];
    yy = repmat([yl(1); yl(2); nan], 1, numel(x));
    plot(ax, xx(:), yy(:), '-', 'Color', color, 'LineWidth', 0.5, 'HandleVisibility','off');
end

function plotExampleTrials(T, traces, trialIdx, onsets, inT, inSig, ref, dur, col, condLabel, N_EX)
% Plot up to N_EX evenly-spaced example trials: dF/F (left axis) + the
% onset-windowed input command (right axis), with ref and stim markers.
    if isempty(traces); fprintf('  no %s trials to show.\n', condLabel); return; end
    sel = unique(round(linspace(1, size(traces,1), min(N_EX, size(traces,1)))));
    figure('Name', sprintf('DEBUG examples | %s', condLabel), 'Color','w');
    for e = 1:numel(sel)
        r  = sel(e);
        ax = subplot(1, numel(sel), e);
        yyaxis(ax,'left');
        plot(ax, T, traces(r,:), 'Color', col, 'LineWidth', 0.9); hold(ax,'on');
        plot(ax, [0 dur], [ref ref], '--k', 'LineWidth', 0.8);
        ylabel(ax,'\DeltaF/F (%)');
        if ~isempty(inT)
            yyaxis(ax,'right');
            t0 = onsets(trialIdx(r));
            m  = inT >= t0 - 3 & inT <= t0 + dur + 3;
            plot(ax, inT(m) - t0, inSig(m), 'Color', [0.5 0.5 0.5], 'LineWidth', 0.5);
            ylabel(ax,'input');
        end
        xline(ax, 0, 'k-', 'HandleVisibility','off');
        xline(ax, dur, 'k:', 'HandleVisibility','off');
        xlim(ax, [-3 dur+3]); xlabel(ax,'Time (s)');
        title(ax, sprintf('%s tr %d', condLabel, trialIdx(r)), 'Interpreter','none');
        hold(ax,'off');
    end
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

function inTr = sliceInputTrials(inT, inSig, onsets, idx, Tin)
% Interpolate the combined input command onto the common onset-relative axis
% Tin (one row per trial). Uses the input's own time base (inT), so it is not
% downsampled to the imaging grid. NaN outside each trial's available range.
    inTr = NaN(numel(idx), numel(Tin));
    for j = 1:numel(idx)
        t0 = onsets(idx(j));
        inTr(j,:) = interp1(inT - t0, inSig, Tin, 'linear', NaN);
    end
end

function drawInputPanel(ax, T, traces, dur, col, PS, ttl)
% All-trials (faint) + across-trial mean input command, with stim patch. No
% reference line (input has no setpoint).
    hold(ax, 'on');
    if ~isempty(traces)
        mu = mean(traces, 1, 'omitnan');
        plot(ax, T, traces', 'Color', [0.7 0.7 0.7], 'LineWidth', PS.lw_trial, 'HandleVisibility','off');
        plot(ax, T, mu, 'Color', col, 'LineWidth', PS.lw_mean, 'HandleVisibility','off');
    end
    xline(ax, 0, 'LineWidth', PS.lw_zero, 'HandleVisibility','off');
    xline(ax, dur, 'LineWidth', PS.lw_zero, 'HandleVisibility','off');
    addStimPatch(ax, 0, dur);
    uistack(findobj(ax,'Type','line'), 'top');
    hold(ax, 'off');
    xlim(ax, [-3 dur+3]);
    xlabel(ax, 'Time (s)', 'FontSize', PS.fs, 'FontWeight', PS.fw);
    ylabel(ax, 'Input command', 'FontSize', PS.fs, 'FontWeight', PS.fw);
    title(ax, ttl, 'FontSize', PS.fs, 'FontWeight', PS.fw);
    set(ax, 'Box','off', 'TickDir','out', 'FontSize', PS.fs, 'FontWeight', PS.fw);
end

function plotMeanErr(ax, T, traces, ref, col, PS, lbl)
% Mean instantaneous absolute tracking error |dF/F - ref| across trials at each
% time point, with a faint +/- SEM ribbon. Drawn onto the shared axes so OL and
% CL overlay directly.
    if isempty(traces); return; end
    e   = abs(traces - ref);
    mu  = mean(e, 1, 'omitnan');
    n   = sum(isfinite(e), 1);
    sem = std(e, 0, 1, 'omitnan') ./ sqrt(max(n, 1));
    fill(ax, [T fliplr(T)], [mu+sem fliplr(mu-sem)], col, ...
        'FaceAlpha', PS.fa, 'EdgeColor','none', 'HandleVisibility','off');
    plot(ax, T, mu, 'Color', col, 'LineWidth', PS.lw_mean, 'DisplayName', lbl);
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
