% bilateral/bil_pick_viewer.m
% Pick an AL_0048 experiment + trial type(s) and launch pixelTuningCurveViewerSVD on them.
% Run from the brain_paper/ root.
%
% WHY THIS EXISTS
%   Most AL_0048 sessions cannot be opened by initialize_data/loadData: the Signals runs
%   (opto_bilateralImpulse638, opto_brainGrid638) ship no input_params.csv, and the ones
%   that do use three different column layouts across builds. The ONE thing every session
%   has is the raw 2 kHz Timeline: lightCommand594/638 + galvoX/galvoY. So trials are
%   derived from those traces here, which works for all 47 experiments uniformly and never
%   goes stale when a rig build changes. See bilateral/AL0048_CATALOG.md for the inventory.
%
% TRIAL TYPE
%   A "type" is (hemisphere, galvo site binned to GX_BIN, command level binned to CMD_BIN).
%   Duration is REPORTED, not grouped on: it jitters by a frame on pulsed runs and varies
%   continuously on closed-loop runs, so grouping by it shatters real conditions into
%   dozens of singletons.
%
% USAGE (two steps)
%   1. set SESS_DATE / SESS_EXP, leave SEL = []   -> prints the trial-type menu, then stops
%   2. set SEL = [i j ...]                        -> loads the SVD, launches the viewer
%
% Viewer controls: click to move pixel/time/condition, arrows for time, up/down for
% condition, 'p' play, '-'/'=' caxis, 'r' draw ROI -> returns roi struct to the workspace.

%% ---- config ------------------------------------------------------------
SUBJECT   = 'AL_0048';
SESS_DATE = '2026-06-20';   % see AL0048_CATALOG.md
SESS_EXP  = 1;

SEL       = [];             % [] = list types and stop | vector of type indices to view
LASER     = '';             % '638' | '594' | '' = whichever line actually fired

SIDE_KEEP = 'both';         % 'both' | 'L' (excitatory) | 'R' (inhibitory)
MIN_N     = 5;              % hide types with fewer trials than this from the menu
CALC_WIN  = [-1 4];         % peri-event window (s) handed to the viewer
NSV       = 100;            % SVD components loaded (viewer pre-calc cost scales with this)
LABEL_BY  = 'type';         % 'type' = one viewer condition per selected type
                            % 'side' = pool selected types into L / R
                            % 'amp'  = pool selected types by command level

% trial-type binning + bout detection
GX_BIN      = 0.5;          % galvo-X bin (V) — sites are ~0.9 V apart, so 0.5 separates them
CMD_BIN     = 0.1;          % command-level bin (V)
LASER_THR   = 0.3;          % V, light-gate threshold
MERGE_GAP_S = 0.5;          % sub-pulses closer than this are ONE bout (sine carriers etc.)
FLAT_SD     = 0.05;         % within-bout command SD below which the bout is a constant step
% -------------------------------------------------------------------------

if ~isfolder('bilateral') && isfolder(fullfile('..', 'bilateral'))
    cd('..');
end
addpath(genpath('utils'));

expRoot = expPath(SUBJECT, SESS_DATE, SESS_EXP);
if ~isfolder(expRoot)
    error('bil_pick_viewer:noExp', 'No such experiment folder: %s', expRoot);
end
fprintf('\n=== %s %s exp %d ===\n%s\n', SUBJECT, SESS_DATE, SESS_EXP, expRoot);

%% ---- pick the laser line ------------------------------------------------
if isempty(LASER)
    cand = {'638', '594'};
    LASER = '';
    for k = 1:numel(cand)
        f = fullfile(expRoot, sprintf('lightCommand%s.raw.npy', cand{k}));
        if exist(f, 'file') && any(readNPY(f) > LASER_THR)
            LASER = cand{k};
            break;
        end
    end
    if isempty(LASER)
        error('bil_pick_viewer:noLaser', 'Neither 638 nor 594 fired in this experiment.');
    end
    fprintf('laser auto-selected: %s nm\n', LASER);
end

%% ---- DAQ traces + exact sample->Timeline-seconds map --------------------
lc = double(readNPY(fullfile(expRoot, sprintf('lightCommand%s.raw.npy', LASER)))); lc = lc(:);
gx = double(readNPY(fullfile(expRoot, 'galvoX.raw.npy'))); gx = gx(:);
gy = double(readNPY(fullfile(expRoot, 'galvoY.raw.npy'))); gy = gy(:);

% <chan>.timestamps_Timeline.npy is [sampleIdx0 t0; sampleIdxN tN] (0-based idx) — use it
% rather than assuming 2 kHz, so a rig-rate change cannot silently shift every onset.
tsFile = fullfile(expRoot, sprintf('lightCommand%s.timestamps_Timeline.npy', LASER));
if exist(tsFile, 'file')
    ts = double(readNPY(tsFile));
    slope = (ts(2,2) - ts(1,2)) / (ts(2,1) - ts(1,1));
    idx2t = @(i) ts(1,2) + (i - 1 - ts(1,1)) * slope;   % i = 1-based MATLAB index
    FS = 1 / slope;
else
    FS = 2000;
    idx2t = @(i) (i - 1) / FS;
    warning('bil_pick_viewer:noDaqTs', 'No DAQ timestamps file — assuming %g Hz from 0.', FS);
end
fprintf('DAQ %g Hz, %.1f s\n', FS, idx2t(numel(lc)));

%% ---- bouts --------------------------------------------------------------
on = lc > LASER_THR;
dd = diff(int8(on));
sIx = find(dd == 1) + 1;
eIx = find(dd == -1) + 1;
if on(1);   sIx = [1; sIx];            end
if on(end); eIx = [eIx; numel(on)];    end
if isempty(sIx)
    error('bil_pick_viewer:noBouts', 'No %s nm light above %.2f V in this experiment.', ...
        LASER, LASER_THR);
end

gapN = MERGE_GAP_S * FS;               % merge sub-pulses into one bout
mS = sIx(1); mE = [];
for k = 2:numel(sIx)
    if sIx(k) - eIx(k-1) > gapN
        mE(end+1,1) = eIx(k-1); %#ok<SAGROW>
        mS(end+1,1) = sIx(k);   %#ok<SAGROW>
    end
end
mE(end+1,1) = eIx(end);

nB = numel(mS);
bout = struct('t0', cell(nB,1), 'dur', [], 'gx', [], 'gy', [], 'cmd', [], 'flat', []);
for k = 1:nB
    seg = lc(mS(k):mE(k));
    hi  = seg(seg > LASER_THR);
    bout(k).t0   = idx2t(mS(k));
    bout(k).dur  = (mE(k) - mS(k)) / FS;
    bout(k).gx   = median(gx(mS(k):mE(k)));
    bout(k).gy   = median(gy(mS(k):mE(k)));
    bout(k).cmd  = median(hi);
    bout(k).flat = std(hi) < FLAT_SD;
end
fprintf('%d light bouts detected\n', nB);

%% ---- group into trial types --------------------------------------------
allGx  = [bout.gx]';
allCmd = [bout.cmd]';
key = [round(allGx / GX_BIN) * GX_BIN, round(allCmd / CMD_BIN) * CMD_BIN];
[uKey, ~, g] = unique(key, 'rows');

types = repmat(struct('side', '', 'gx', 0, 'cmd', 0, 'n', 0, 'durMed', 0, ...
                      'durMin', 0, 'durMax', 0, 'flatFrac', 0, 'ix', []), ...
               size(uKey, 1), 1);
for k = 1:size(uKey, 1)
    ix = find(g == k);
    d  = [bout(ix).dur];
    types(k) = struct( ...
        'side',   ternary(uKey(k,1) < 0, 'L', 'R'), ...
        'gx',     uKey(k,1), 'cmd', uKey(k,2), 'n', numel(ix), ...
        'durMed', median(d), 'durMin', min(d), 'durMax', max(d), ...
        'flatFrac', mean([bout(ix).flat]), 'ix', ix);
end
[~, ord] = sort([types.n], 'descend');
types = types(ord);

sideOK = strcmp(SIDE_KEEP, 'both') | strcmp({types.side}, SIDE_KEEP);
keep   = [types.n] >= MIN_N & sideOK;
types  = types(keep);
if isempty(types)
    error('bil_pick_viewer:noTypes', ...
        'No trial type with n >= %d on side ''%s''. Lower MIN_N or widen SIDE_KEEP.', ...
        MIN_N, SIDE_KEEP);
end

fprintf('\n  #  side          galvoX   cmd      n    dur (med [min-max])      shape\n');
fprintf(  '  -- ------------- -------- ------ ----- ------------------------ ---------------\n');
for k = 1:numel(types)
    T = types(k);
    % flat/modulated is only meaningful for bouts long enough to have a plateau — a 25 ms
    % pulse is all ramp, so its command SD says nothing about its shape.
    if T.durMed < 0.1
        shape = 'impulse';
    elseif T.flatFrac > 0.8
        shape = 'CONSTANT step';
    elseif T.flatFrac < 0.2
        shape = 'modulated';
    else
        shape = sprintf('mixed (%.0f%% flat)', 100 * T.flatFrac);
    end
    % A >3x duration spread means two conditions (e.g. impulse trials and step trials)
    % share one (site, power) key — they must be split before any trial average.
    if T.durMax > 3 * max(T.durMin, 1e-6)
        shape = [shape ' !! SPLIT BY DURATION'];
    end
    fprintf('  %2d  %-13s %+6.2f V %5.2f V %5d  %6.3f s [%.3f-%.3f]   %s\n', k, ...
        ternary(strcmp(T.side, 'L'), 'LEFT/excit', 'RIGHT/inhib'), ...
        T.gx, T.cmd, T.n, T.durMed, T.durMin, T.durMax, shape);
end

if isempty(SEL)
    fprintf(['\nSet SEL to the row number(s) above and re-run to launch the viewer, ' ...
             'e.g.  SEL = [1 2];\n\n']);
    return;
end
if any(SEL < 1) || any(SEL > numel(types))
    error('bil_pick_viewer:badSel', 'SEL must index rows 1..%d of the table above.', ...
        numel(types));
end

%% ---- load the SVD -------------------------------------------------------
if ~isfolder(fullfile(expRoot, 'blue'))
    error('bil_pick_viewer:noWidefield', ...
        ['This experiment has no saved widefield (blue/ missing) — trials exist but ' ...
         'cannot be viewed. See AL0048_CATALOG.md.']);
end
[U, V, t] = cp_loadUVt(expRoot, NSV);         % U [Y X nSV], V [nSV T], t [1 T]
t = double(t(:))';
if numel(t) ~= size(V, 2)
    % Seen on 2026-07-29/2: 54839 timestamps vs 54828 V samples. The SVD writer drops
    % trailing frames, so truncate from the END; a front truncation would shift every
    % onset by ~0.3 s. Verify onsets still land at t=0 in the viewer.
    n = min(numel(t), size(V, 2));
    fprintf('t %d vs V %d frames — truncating BOTH to %d (trailing frames dropped)\n', ...
        numel(t), size(V, 2), n);
    t = t(1:n);  V = V(:, 1:n);
end
fprintf('SVD: U %dx%dx%d, V %dx%d, t %.1f-%.1f s\n', size(U,1), size(U,2), size(U,3), ...
    size(V,1), size(V,2), t(1), t(end));

%% ---- build the event list ----------------------------------------------
eventTimes = []; eventLabels = {};
for k = SEL(:)'
    T  = types(k);
    tt = [bout(T.ix).t0];
    switch LABEL_BY
        case 'type', lab = sprintf('%s %+.1fV %.2fV', T.side, T.gx, T.cmd);
        case 'side', lab = T.side;
        case 'amp',  lab = sprintf('%.2f V', T.cmd);
        otherwise,   error('bil_pick_viewer:badLabel', 'LABEL_BY must be type|side|amp.');
    end
    eventTimes  = [eventTimes, tt];                                     %#ok<AGROW>
    eventLabels = [eventLabels, repmat({lab}, 1, numel(tt))];           %#ok<AGROW>
end

% drop events whose window falls outside the imaging record
okE = eventTimes + CALC_WIN(1) >= t(1) & eventTimes + CALC_WIN(2) <= t(end);
if ~all(okE)
    fprintf('dropping %d/%d events whose %g..%g s window falls outside the SVD record\n', ...
        sum(~okE), numel(okE), CALC_WIN(1), CALC_WIN(2));
    eventTimes = eventTimes(okE);  eventLabels = eventLabels(okE);
end

uL = unique(eventLabels, 'stable');
fprintf('\nlaunching viewer: %d events, %d conditions\n', numel(eventTimes), numel(uL));
for k = 1:numel(uL)
    fprintf('   %-22s n=%d\n', uL{k}, sum(strcmp(eventLabels, uL{k})));
end

pixelTuningCurveViewerSVD(U, V, t, eventTimes, eventLabels, CALC_WIN);

%% ---- local helper -------------------------------------------------------
function out = ternary(cond, a, b)
if cond, out = a; else, out = b; end
end
