function S = ct_process_set(sessList, cfg, tag)
% CT_PROCESS_SET  Load each controller-tuning session (motion-free, states.csv-based),
% compute per-trial cost ||y-ref|| over cfg.COST_WIN, group by unique (Kp,Ki).
% Helper for controller-tuning/load_grid.m. Returns struct array S (one per loaded session).
%
% Kept in its own file (not a local function of load_grid.m) so that editing the
% load_grid.m registry/knobs is always picked up -- MATLAB caches a script's local
% functions and would otherwise run a stale copy until `clear functions; rehash`.
%
% DATA MODEL (resolved 2026-06-27 from the share, see RESEARCH 2026-06-27):
%   * y  = states.csv : the regulated kernel-mean signal in % dF/F, logged at the
%          35 Hz imaging rate, 300000-sample pre-allocated buffer. Median ~0; a few
%          hundred logging-glitch samples (|y| up to 1e5) are NaN'd via cfg.YCLIP.
%   * input_params layout is per RIG-VERSION (detect by #columns), not per mouse:
%        8-col -> onset = col2 (index into the SAME 35 Hz states axis; matches the
%                 input_amps.csv rising edge), Kp = col5, Ki = col6, |ref| = col7.
%        7-col -> gains = col2:3, |ref| = col4; NO onset column and no input_amps,
%                 so onsets are unavailable (session held until a Timeline adapter).
%   * ref is taken from the data (-|col7|), overriding any stale registry value.

S = struct([]);
for si = 1:numel(sessList)
    s = sessList(si);
    fprintf('\n[%s %d/%d] %s %s e%d (ip=%s, status=%s) ...\n', ...
        tag, si, numel(sessList), s.mn, s.td, s.en, s.ip, s.status);
    if strcmp(s.status,'hold')
        fprintf('  HOLD: %s -- skipped.\n', s.note);
        continue;
    end
    try
        [y, gains, onset, ref] = ct_load_session(s, cfg);
    catch ME
        warning('ct:load','  LOAD FAILED (%s %s e%d): %s', s.mn, s.td, s.en, ME.message);
        continue;
    end

    nUse  = min(size(gains,1), numel(onset));
    gains = round(gains(1:nUse,:), 6);
    onset = round(onset(1:nUse)) + cfg.ONSET_OFF;

    n3   = round(cfg.COST_WIN(2)*cfg.FS);
    nPre = round(-cfg.PLOT_WIN(1)*cfg.FS);
    nPost= round( cfg.PLOT_WIN(2)*cfg.FS);

    costTr = nan(nUse,1); ic0 = nan(nUse,1);
    traces = nan(nUse, nPre+nPost+1);
    for j = 1:nUse
        i0 = onset(j);
        if isnan(i0) || i0-nPre < 1 || i0+max(n3,nPost) > numel(y); continue; end
        seg = y(i0 : i0+n3);
        if mean(isnan(seg)) > 0.5; continue; end       % too many glitch samples
        % glitch-robust ||y-ref||_2 : RMSE over finite samples, rescaled to the
        % full window length so it matches norm() when no samples are NaN.
        costTr(j)   = sqrt(mean((seg-ref).^2,'omitnan')) * sqrt(numel(seg));
        ic0(j)      = y(i0);
        traces(j,:) = y(i0-nPre : i0+nPost);
    end
    gate = abs(ic0) <= cfg.IC_GATE;     % NaN onset (glitch) -> gated out

    % one-line alignment check (verify onset units / ref on first run)
    j1 = find(~isnan(onset),1);
    if ~isempty(j1)
        fprintf('  align-check: trial1 onset idx=%d, y len=%d, y(onset)=%.2f, ref=%g, fs=%g\n', ...
            onset(j1), numel(y), y(min(max(onset(j1),1),numel(y))), ref, cfg.FS);
    end

    [C,~,ic] = unique(gains, 'rows');
    nNode = zeros(size(C,1),1); J = nan(size(C,1),1); Jsem = J;
    nodeMean = nan(size(C,1), size(traces,2)); nodeStd = nodeMean;
    for k = 1:size(C,1)
        sel = (ic==k) & gate & ~isnan(costTr);
        nNode(k)      = nnz(sel);
        J(k)          = mean(costTr(sel));
        Jsem(k)       = std(costTr(sel)) / sqrt(max(nNode(k),1));
        nodeMean(k,:) = mean(traces(sel,:), 1, 'omitnan');
        nodeStd(k,:)  = std(traces(sel,:), 0, 1, 'omitnan');
    end

    rec = struct();
    rec.mn=s.mn; rec.td=s.td; rec.en=s.en; rec.ref=ref; rec.fs=cfg.FS;
    rec.tt = (-nPre:nPost)/cfg.FS;
    rec.C=C; rec.J=J; rec.Jsem=Jsem; rec.nNode=nNode;
    rec.nodeMean=nodeMean; rec.nodeStd=nodeStd;
    rec.trial=(1:nUse)'; rec.Kp=gains(:,1); rec.Ki=gains(:,2);
    rec.costTr=costTr; rec.gate=gate;
    if isempty(S); S = rec; else; S(end+1) = rec; end %#ok<AGROW>

    fprintf('  OK: trials=%d (gated %d) | nodes=%d | Kp[%g %g] Ki[%g %g] | Jmin=%.3g\n', ...
        nUse, nnz(gate), size(C,1), min(C(:,1)), max(C(:,1)), min(C(:,2)), max(C(:,2)), min(J));
end
end


function [y, gains, onset, ref] = ct_load_session(s, cfg)
% Read ONLY what this session has: states.csv (output) + input_params (gains/onset).
% No initialize_data, no video, no SVD. Layout auto-detected by #columns.

% --- input_params (root or data/ subdir; search both) ---
ipPath = find_session_file(s, 'input_params.csv');
IP = readmatrix(ipPath);
ncol = size(IP,2);

switch ncol
    case num2cell(8:20)                          % 8(+)-col rig version
        onset = IP(:,2);                         % onset index in the 35 Hz states axis
        gains = IP(:,[5 6]);                     % Kp, Ki
        ref   = -abs(IP(1,7));                   % setpoint from data (col7 = |ref|)
    case 7                                       % old rig version: no onset column
        gains = IP(:,[2 3]);                     %#ok<NASGU> % Kp, Ki
        error('ct:noOnset', ...
            '7-col input_params has no onset column and no input_amps.csv -- mark status=hold');
    otherwise
        error('ct:badIP', 'unexpected input_params width: %d cols', ncol);
end

% --- output trace y(t) = states.csv (% dF/F @35 Hz), glitch-clipped ---
yPath = find_session_file(s, 'states.csv');
y = read_csv_row(yPath);
y(abs(y) > cfg.YCLIP) = NaN;                      % NaN sparse logging glitches
y = double(y(:)).';
end


function p = find_session_file(s, name)
% Locate a session file, preferring s.ip ('root'|'data') but falling back to the other.
root = expPath(s.mn, s.td, s.en);
cand = { fullfile(root, name), fullfile(root, 'data', name) };
if strcmp(s.ip,'data'); cand = cand([2 1]); end  % try data/ first
for i = 1:numel(cand)
    if isfile(cand{i}); p = cand{i}; return; end
end
error('ct:fileNotFound', '%s not found (looked in %s and data/)', name, root);
end


function v = read_csv_row(p)
% Robust read of a single space-delimited row in scientific notation (readmatrix
% mis-parses the trailing-space, single-line states/amps logs as 1x1 NaN).
fid = fopen(p,'r');
C = textscan(fid, '%f');
fclose(fid);
v = C{1}(:).';
end
