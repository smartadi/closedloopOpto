function S = ct_process_set(sessList, cfg, tag)
% CT_PROCESS_SET  Load each controller-tuning session (motion-free, cache-first),
% compute per-trial cost ||y-ref|| over cfg.COST_WIN, group by unique (Kp,Ki).
% Helper for controller-tuning/load_grid.m. Returns struct array S (one per loaded session).
%
% Kept in its own file (not a local function of load_grid.m) so that editing the
% load_grid.m registry/knobs is always picked up — MATLAB caches a script's local
% functions and would otherwise run a stale copy until `clear functions; rehash`.

S = struct([]);
for si = 1:numel(sessList)
    s = sessList(si);
    fprintf('\n[%s %d/%d] %s %s e%d (ref=%g, ip=%s, gain=%s, y=%s) ...\n', ...
        tag, si, numel(sessList), s.mn, s.td, s.en, s.ref, s.ip, s.gain, s.ysrc);
    if strcmp(s.status,'hold')
        fprintf('  HOLD: no usable output source yet -- skipped (needs a per-session adapter).\n');
        continue;
    end
    try
        [y, gains, onset] = ct_load_session(s, cfg);
    catch ME
        warning('ct:load','  LOAD FAILED (%s %s e%d): %s', s.mn, s.td, s.en, ME.message);
        continue;
    end

    nUse  = min(size(gains,1), numel(onset));
    gains = round(gains(1:nUse,:), 6);
    onset = round(onset(1:nUse)) + cfg.ONSET_OFF;
    ref   = s.ref;

    n3   = round(cfg.COST_WIN(2)*cfg.FS);
    nPre = round(-cfg.PLOT_WIN(1)*cfg.FS);
    nPost= round( cfg.PLOT_WIN(2)*cfg.FS);

    costTr = nan(nUse,1); ic0 = nan(nUse,1);
    traces = nan(nUse, nPre+nPost+1);
    for j = 1:nUse
        i0 = onset(j);
        if isnan(i0) || i0-nPre < 1 || i0+max(n3,nPost) > numel(y); continue; end
        seg         = y(i0 : i0+n3);
        costTr(j)   = norm(seg - ref);
        ic0(j)      = y(i0);
        traces(j,:) = y(i0-nPre : i0+nPost);
    end
    gate = abs(ic0) <= cfg.IC_GATE;

    % one-line alignment check (verify onset units on first run)
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


function [y, gains, onset] = ct_load_session(s, cfg)
% Read ONLY what this session has. No initialize_data, no video, no SVD.
root = expPath(s.mn, s.td, s.en);

% --- input_params (root or data/ subdir) ---
ipPath = fullfile(root, 'input_params.csv');
if strcmp(s.ip,'data'); ipPath = fullfile(root, 'data', 'input_params.csv'); end
if ~isfile(ipPath); error('input_params.csv not found at %s', ipPath); end
IP = readmatrix(ipPath);
onset = IP(:, cfg.ONSET_COL);

% --- gains: input_params cols 5:6, or per-trial Kr.npy ---
switch s.gain
    case 'ip'
        gains = IP(:, [cfg.KP_COL cfg.KI_COL]);
    case 'kr'
        krPath = fullfile(root, 'Kr.npy');
        if ~isfile(krPath); error('Kr.npy not found at %s', krPath); end
        Kr = double(readNPY(krPath));
        if size(Kr,2) < 2 && size(Kr,1) >= 2; Kr = Kr.'; end   % orient to [nTrials x >=2]
        gains = Kr(:, 1:2);
    otherwise
        error('unknown gain source ''%s''', s.gain);
end

% --- output trace y(t) = kernel-mean dF/F ---
switch s.ysrc
    case 'cache'                       % prototype-computed pixel cache in data/
        f = fullfile('data', s.yfile);
        if ~isfile(f); error('pixel cache not found: %s', f); end
        S = load(f);
        y = pick_trace(S);
    case 'mean'                        % rig-logged kernel mean (root or data/)
        mp = fullfile(root, 'mean_states.csv');
        if ~isfile(mp); mp = fullfile(root, 'data', 'mean_states.csv'); end
        if ~isfile(mp); error('mean_states.csv not found for %s', s.mn); end
        M = readmatrix(mp);
        y = M(:, find(any(~isnan(M) & M~=0, 1), 1, 'last'));   % last non-empty column
    otherwise
        error('unknown y source ''%s''', s.ysrc);
end
y = double(y(:)).';
end


function y = pick_trace(S)
% Return the dF/F vector from a loaded pixel-cache struct, tolerating unknown
% variable names (bare prototype caches vs getpixel_dFoF's 'dFk').
if isfield(S,'dFk'); y = S.dFk; return; end
fn = fieldnames(S); best = ''; blen = 0;
for i = 1:numel(fn)
    v = S.(fn{i});
    if isnumeric(v) && isvector(v) && numel(v) > blen; best = fn{i}; blen = numel(v); end
end
if isempty(best); error('no numeric vector found in pixel cache'); end
y = S.(best);
end
