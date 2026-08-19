% export_ampmaps.m — per-amplitude response maps for the dose-spread animation.
%
% Pulls the same maps the supplementary figure uses (impulse-analysis/
% spatial_spread.m): trial-averaged dF/F, baseline −500→0 ms vs peak
% 0→+200 ms, one map per laser amplitude. Nothing is recomputed here, so the
% animation cannot drift from the panel in the paper.
%
% REQUIRES `allExperiments` in the base workspace:
%     run('impulse-analysis/load_experiments.m')     % slow: reads SVD off the server
% then
%     run('presentation/export_ampmaps.m')
%
% Writes presentation/assets/ampmaps_<mouse>_<date>_en<n>.mat (v7).

% select by name, not by position: the index into allExperiments shifts
% whenever the experiments list in load_experiments.m is edited
WANT  = {'AL_0033', '2025-01-29', 1};
pxMM  = 0.173;        % mm per pixel
vToMW = 1.8 / 4.9;    % command volts -> mW

ROOT = fileparts(fileparts(mfilename('fullpath')));
if ~exist(fullfile(ROOT, 'presentation', 'assets'), 'dir')
    error('cannot locate %s', fullfile(ROOT, 'presentation', 'assets'));
end

ae  = evalin('base', 'allExperiments');
hit = find(arrayfun(@(x) strcmp(x.mn, WANT{1}) && strcmp(x.td, WANT{2}) && ...
                         x.en == WANT{3}, ae), 1);
if isempty(hit)
    error('%s %s en%d not found in allExperiments', WANT{1}, WANT{2}, WANT{3});
end
e = ae(hit);

uA    = e.uAmp(:);
vIdx  = find(uA > 0);                  % drop the 0 mW (catch) level
nV    = numel(vIdx);
mimg  = e.mimg;
bmask = e.brainMask(:);
[nr, nc] = size(mimg);

maps = nan(nr, nc, nV, 'single');
for k = 1:nV
    full_k = nan(nr * nc, 1);
    full_k(bmask) = e.imp.resp_map{vIdx(k)};
    maps(:, :, k) = single(reshape(full_k, nr, nc));
end

% peak pixel of the strongest amplitude (same rule as spatial_spread.m)
[~, iStrong] = min(cellfun(@min, e.imp.resp_map(vIdx)));
mstrong = maps(:, :, iStrong);
[pr_pk, pc_pk] = find(mstrong == min(mstrong(:)), 1);

amps_mW = uA(vIdx) * vToMW;
mouse = e.mn; date_str = e.td; en = e.en;
brainMask = reshape(bmask, nr, nc);

fprintf('%s %s en%d — %d amplitudes: %s mW\n', mouse, date_str, en, nV, ...
    strjoin(arrayfun(@(x) sprintf('%.2f', x), amps_mW, 'uni', 0), ', '));
fprintf('peak pixel (row,col) = (%d,%d);  map range %.2f .. %.2f %%dF/F\n', ...
    pr_pk, pc_pk, min(maps(:)), max(maps(:)));

out = fullfile(ROOT, 'presentation', 'assets', ...
    sprintf('ampmaps_%s_%s_en%d.mat', mouse, date_str, en));
save(out, 'maps', 'amps_mW', 'mimg', 'brainMask', 'pr_pk', 'pc_pk', ...
     'pxMM', 'mouse', 'date_str', 'en', '-v7');
fprintf('wrote %s (%.1f MB)\n', out, dir(out).bytes / 1e6);
