function [U, V, t, mimg] = cp_loadUVt(expRoot, nSV, tFallback)
% cp_loadUVt  loadUVt with a Timeline-timestamp fallback.
%
% Five of the 13 controller sessions (m6 m7 m8 m11 m12 -- the ones with no hemo-corrected
% `corr/` folder) also ship WITHOUT `blue/svdTemporalComponents.timestamps.npy`, so the
% vendored loadUVt (utils/Pipelines/widefield, DO NOT MODIFY) throws before returning.
% Those sessions are therefore invisible to every contra->ipsi stage, which is why the
% cross-session batch could only ever see the corrected subset.
%
% The frame timebase is not actually lost: `d.timeBlue` (built by initialize_data from
% Timeline) is the per-blue-frame time vector and is already cached with every session.
% Verified on m4 (which has BOTH): identical length (138286) and max|timeBlue - t_svd|
% = 0.0216 s < one 35 Hz frame (0.0286 s), corr = 1.000000 -- RESEARCH 2026-08-02.
%
% Behaviour
%   * timestamps present  -> plain loadUVt (bit-identical to before; corrected `corr/` V is
%     still preferred exactly as loadUVt prefers it).
%   * timestamps missing AND tFallback supplied -> load U/mimg/V directly and use tFallback
%     as t, replicating loadUVt's uncorrected branch INCLUDING detrendAndFilt(V, Fs) so the
%     preprocessing matches. V and t are truncated to a common length.
%   * timestamps missing and no tFallback -> rethrow, so nothing silently changes.
%
% NOTE: the fallback sessions are the UNCORRECTED ones (no hemodynamic correction). Carry
% that as a covariate in any pooled result -- it bears on the T1 hemodynamic objection.
%
% Usage:  [U,V,t,mimg] = cp_loadUVt(expPath(mn,td,en), nSV, d_s.timeBlue);

if nargin < 3; tFallback = []; end

tsFile = fullfile(expRoot, 'blue', 'svdTemporalComponents.timestamps.npy');
corrOK = exist(fullfile(expRoot, 'corr', 'svdTemporalComponents_corr.npy'), 'file') > 0;

if corrOK || exist(tsFile, 'file')
    [U, V, t, mimg] = loadUVt(expRoot, nSV);
    return;
end

if isempty(tFallback)
    error('cp_loadUVt:noTimestamps', ...
        ['No svdTemporalComponents.timestamps.npy and no corr/ for %s, and no timeBlue ' ...
         'fallback was passed. Call cp_loadUVt(expRoot, nSV, d.timeBlue).'], expRoot);
end

fprintf(1, 'cp_loadUVt: no timestamps npy -- using Timeline d.timeBlue as the frame timebase\n');
U    = readUfromNPY(fullfile(expRoot, 'blue', 'svdSpatialComponents.npy'), nSV);
mimg = readNPY(fullfile(expRoot, 'blue', 'meanImage.npy'));
V    = readVfromNPY(fullfile(expRoot, 'blue', 'svdTemporalComponents.npy'), nSV);

t = tFallback(:);
n = min(numel(t), size(V, 2));
if numel(t) ~= size(V, 2)
    fprintf(1, 'cp_loadUVt: timeBlue %d vs V %d frames -- truncating both to %d\n', ...
        numel(t), size(V, 2), n);
end
t = t(1:n);  V = V(:, 1:n);

Fs = 1 / mean(diff(t));
V  = detrendAndFilt(V, Fs);        % same preprocessing as loadUVt's uncorrected branch
end
