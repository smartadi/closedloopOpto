function d = ctrl_cache_stamp(d, data, why)
% CTRL_CACHE_STAMP  Record how a controller cache was built, into d.provenance.
%
%   d = ctrl_cache_stamp(d, data, 'new build');   % call immediately before save()
%
% WHY THIS EXISTS (2026-10-02). The published Fig-4C magnitudes did not reproduce, and
% pinning down why took a five-way elimination -- motion statistic, pre-buffer, the two new
% sessions, their dF/F recompute, and finally running the pre-finalization script itself --
% only to conclude "the caches changed". That whole exercise was necessary ONLY because a
% cache carries no record of how it was made. Of the 15 caches then on disk, 13 did not even
% record dff_w, and none recorded a dF/F mode or a build date.
%
% The fields are deliberately the ones that changed a published number this year:
%   dff_mode  0/2 = trailing rolling baseline, 1 = F/meanImage (changed for m14/m15 on
%             2026-10-01; it is the amplitude-scaling choice Fig-4C turned out to track)
%   dff_w     baseline length in samples (= d.params.horizon, 1400 = 40.0 s at 35 Hz)
%   slim      whether d.svd was dropped by utils/slim_ctrl_cache.m
% Anything absent is recorded as NaN/'' rather than guessed, so an unstamped older cache
% stays visibly unknown instead of acquiring a plausible-looking lie.
if nargin < 3 || isempty(why), why = ''; end
p = struct();
p.stamped_utc = datetime('now','TimeZone','UTC','Format','uuuu-MM-dd HH:mm:ss');
p.reason      = char(why);
p.dff_mode    = local_get(data, 'dff_mode');
p.dff_w       = local_get(data, 'dff_w');
if isnan(p.dff_w) && isfield(d,'params') && isfield(d.params,'horizon')
    p.dff_w = double(d.params.horizon);     % what getpixel_dFoF would have used
end
p.slim        = ~(isfield(d,'svd') && ~isempty(d.svd));
p.git         = local_git();
d.provenance  = p;
end

function v = local_get(s, f)
if isstruct(s) && isfield(s,f) && ~isempty(s.(f)), v = double(s.(f)); else, v = NaN; end
end

function h = local_git()
% Short commit of the code that built this cache. '' when git is unavailable -- never guessed.
h = '';
try
    root = fileparts(fileparts(mfilename('fullpath')));
    [st, out] = system(sprintf('git -C "%s" rev-parse --short HEAD', root));
    if st == 0, h = strtrim(out); end
catch
end
end
