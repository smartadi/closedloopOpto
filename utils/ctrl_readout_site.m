function R = ctrl_readout_site(Uflat, V, mimg, dfk, cands, k, horizon, nY, nX, w_warm, opts)
%CTRL_READOUT_SITE  Which pixel is the controller's READOUT? Decided per session, from the data.
%
%   The readout site and the LASER site are two different questions and had been conflated. The
%   laser spot is found by cp_find_stim_site (deepest OL inhibition). The readout is whatever pixel
%   the online controller actually computed `data.dFk` from -- by construction `d.params.pixel`,
%   except that the load/save path flips x<->y, so it may need transposing (user, 2026-08-10).
%
%   Rather than guess, every candidate is rebuilt through the exact getpixel mode-0 recipe
%   (cp_svd_rolling_dfk) and scored against data.dFk on TWO numbers:
%       r      correlation      -- same SHAPE
%       scale  std ratio        -- same SIZE
%   Both are required. Pearson r alone is scale-free, and on AL_0039_0419_e1 that let a rim pixel
%   with 9x too little amplitude (r=0.797, scale=0.11) beat the true readout (r=0.617) -- picking
%   it would have anchored the whole decomposition on a vessel artefact. RESEARCH 2026-08-10.
%
%   THE RULE: among candidates whose scale is plausible, take the highest r. If none is plausible,
%   fall back to the highest r overall and flag it (R.guard_failed) -- the caller decides.
%
% INPUT
%   Uflat [nY*nX x nSV], V [nSV x T], mimg [nY x nX]   session SVD
%   dfk   [T x 1]   the canonical data.dFk this site must reproduce
%   cands struct array with .name and .rc = [row col] (native), in preference order
%   k, horizon      kernel half-width and rolling-baseline horizon (from d.params)
%   w_warm          rolling-baseline warm-up length to exclude
%   opts (optional): .scale_lo(0.5) .scale_hi(2.0) .verbose(true)
%
% OUTPUT  R: .rc .name .r .scale .idx .guard_failed .cands (all candidates scored)

if nargin < 11 || isempty(opts), opts = struct(); end
if ~isfield(opts,'scale_lo'), opts.scale_lo = 0.5;  end
if ~isfield(opts,'scale_hi'), opts.scale_hi = 2.0;  end
if ~isfield(opts,'verbose'),  opts.verbose  = true; end

vv0 = w_warm + 1;
sd_dfk = std(dfk(vv0:end), 'omitnan');

n = numel(cands);
r = nan(n,1);  sc = nan(n,1);
for i = 1:n
    rc = round(cands(i).rc);
    [y, ok] = cp_svd_rolling_dfk(Uflat, V, mimg, rc(1), rc(2), k, horizon, nY, nX);
    if ~ok, continue; end
    vv = vv0:min(numel(y), numel(dfk));
    r(i)  = corr(y(vv), dfk(vv), 'rows','complete');
    sc(i) = std(y(vv),'omitnan') / max(sd_dfk, eps);
    cands(i).r = r(i);  cands(i).scale = sc(i);
end

okAmp = sc >= opts.scale_lo & sc <= opts.scale_hi & isfinite(r);
if any(okAmp)
    rr = r;  rr(~okAmp) = -Inf;
    [~, idx] = max(rr);
    guard_failed = false;
else
    [~, idx] = max(r);
    guard_failed = true;
end

R = struct('rc', round(cands(idx).rc), 'name', cands(idx).name, ...
           'r', r(idx), 'scale', sc(idx), 'idx', idx, ...
           'guard_failed', guard_failed, 'cands', cands, ...
           'scale_lo', opts.scale_lo, 'scale_hi', opts.scale_hi);

if opts.verbose
    fprintf('[ctrl_readout_site] candidate scoring against data.dFk\n');
    fprintf('    %-10s %-16s %-8s %-8s %s\n','name','[row col]','corr','scale','');
    for i = 1:n
        mark = '';
        if i == idx, mark = '  <- CHOSEN'; elseif ~okAmp(i), mark = '  (amplitude implausible)'; end
        fprintf('    %-10s [row %3d col %3d]  %-8.3f %-8.2f%s\n', ...
            cands(i).name, round(cands(i).rc(1)), round(cands(i).rc(2)), r(i), sc(i), mark);
    end
    if guard_failed
        fprintf(2, ['[ctrl_readout_site] NO candidate had a plausible amplitude (scale in [%.1f, %.1f]). ' ...
                    'Fell back to the best correlation -- treat this session''s readout as unverified.\n'], ...
                opts.scale_lo, opts.scale_hi);
    end
end
end
