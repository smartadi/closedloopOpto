function R = slim_ctrl_cache(cacheFile, doReplace)
%SLIM_CTRL_CACHE  Drop the re-downloadable SVD from a controller cache.
%
%   R = slim_ctrl_cache(file)         % dry run: report only, change nothing
%   R = slim_ctrl_cache(file, true)   % write-verify-replace
%
% WHY (2026-10-02). A controller cache is ~3.2 GB, of which d.svd is 2950 MB
% (92 %): U alone is 560x560x2000 single = 2.5 GB. The per-trial arrays that
% every figure actually reads -- the whole `data` struct -- are 6.6 MB, 0.2 %.
% So cache size has nothing to do with the trial-array duplication; it is the
% SVD, and the SVD is re-readable from the server in ~20 s per session.
%
% SAFE because the no-SVD state is already the norm: 6 of the 15 caches never
% had one (12-46 MB on disk) and both Fig-3 and Fig-4 run across all fifteen.
% The single consumer that wants it, controller-analysis/contra_prediction_controller.m,
% already detects the absence and reloads (its line 74 prints "has no .svd --
% reloading via initialize_data").
%
% Also drops d.lightRaw594 / d.lightRaw638 (25 MB each): verified to have ZERO
% consumers outside loadData.m. Deliberately KEEPS d.inpVals / d.inpTime /
% d.lightRaw even though they are copies of the per-wavelength arrays, because
% they have 61 / 59 / 4 call sites between them -- 75 MB is not worth that risk
% next to the 2950 MB above.
%
% The replace is write-verify-then-rename: the original is untouched until a
% reloaded copy of the new file has been confirmed field-by-field identical on
% `data` and on every retained field of `d`.

if nargin < 2 || isempty(doReplace), doReplace = false; end
assert(isfile(cacheFile), 'slim_ctrl_cache:missing', 'No such file: %s', cacheFile);

DROP = {'svd','lightRaw594','lightRaw638'};

f0 = dir(cacheFile);
S  = load(cacheFile);                       % d + data
assert(isfield(S,'d') && isfield(S,'data'), 'slim_ctrl_cache:shape', ...
       '%s does not hold both d and data.', cacheFile);

present = DROP(isfield(S.d, DROP));
R = struct('file', cacheFile, 'mb_before', f0.bytes/1e6, 'dropped', {present}, ...
           'mb_after', NaN, 'verified', false, 'replaced', false);

if isempty(present)
    fprintf('  %-24s already slim (%.1f MB)\n', f0.name, f0.bytes/1e6);
    R.mb_after = f0.bytes/1e6;  R.verified = true;
    return
end

d = rmfield(S.d, present);
data = S.data;

if ~doReplace
    fprintf('  %-24s %8.1f MB  would drop: %s\n', f0.name, f0.bytes/1e6, strjoin(present,', '));
    return
end

% MUST end in .mat: save() writes MAT format regardless, but load() guesses
% the format from the extension and refuses anything it does not recognise.
tmp = [cacheFile(1:end-4) '.slim.mat'];
save(tmp, 'd', 'data', '-v7.3');

% ---- verify the rewritten file before touching the original ----
V = load(tmp);
ok = true;  why = '';
fn = fieldnames(data);
for q = 1:numel(fn)
    if ~isequaln(V.data.(fn{q}), data.(fn{q}))
        ok = false; why = sprintf('data.%s differs', fn{q}); break
    end
end
if ok
    fn = fieldnames(d);
    for q = 1:numel(fn)
        if ~isequaln(V.d.(fn{q}), d.(fn{q}))
            ok = false; why = sprintf('d.%s differs', fn{q}); break
        end
    end
end
if ok && numel(fieldnames(V.data)) ~= numel(fieldnames(data))
    ok = false; why = 'data field count differs';
end
clear V

if ~ok
    delete(tmp);
    error('slim_ctrl_cache:verify', 'Verification FAILED for %s (%s). Original untouched.', ...
          cacheFile, why);
end
R.verified = true;

delete(cacheFile);
movefile(tmp, cacheFile);
f1 = dir(cacheFile);
R.mb_after = f1.bytes/1e6;  R.replaced = true;

fprintf('  %-24s %8.1f -> %7.1f MB  (-%.1f MB)  dropped: %s\n', ...
    f0.name, R.mb_before, R.mb_after, R.mb_before-R.mb_after, strjoin(present,', '));
end
