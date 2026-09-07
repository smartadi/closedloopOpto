function paths = cp_orient_save(sess_tag, T, dataDir)
%CP_ORIENT_SAVE  Persist a FINALIZED session display view T so the whole repo picks it up.
%
% The orientation checker (ctrl_orient_checker) lets you fix a session's view by eye and then
% commits it here. There are two canonical homes for the per-session view and this writes BOTH,
% so no consumer is left on a stale frame and no Stage-1 re-run is needed:
%
%   1. cp_orient_ctrl_<sess>.mat  (variable `T`)  -- the standalone cache cp_orient() loads. Any
%      future cp_orient(...,'cache_file',this) returns this T verbatim (dims permitting).
%   2. ctrl_ols_spont_<sess>.mat  (top-level `Torient`, appended) -- the Stage-1 cache that
%      ctrl_ols_ol_stimblind / ctrl_affected_gui / ctrl_site_diag read as S1.Torient and render
%      through cp_orient_img/fwd/inv. Appending just this one variable leaves the rest untouched.
%
% Because every renderer and click inverse in the repo routes through cp_orient_img/fwd/inv, and
% those now honour the optional T.rot, committing T here re-orients ALL of them consistently.
%
% INPUTS
%   sess_tag  e.g. 'AL_0033_0212_e2'
%   T         view struct (.tr .fu .fl .H .W .Hd .Wd, optional .rot); .created/.confirmed stamped
%   dataDir   controller-analysis/data (optional; defaults next to this file's project)
%
% OUTPUT paths.orient_file / paths.s1_file (written; '' if the S1 cache was absent).

if nargin < 3 || isempty(dataDir)
    here = fileparts(mfilename('fullpath'));                 % utils/
    dataDir = fullfile(fileparts(here), 'controller-analysis', 'data');
end
assert(~isempty(sess_tag) && ischar(sess_tag), 'cp_orient_save: sess_tag must be a char row.');
assert(isstruct(T) && isfield(T,'tr'), 'cp_orient_save: T must be a cp_orient view struct.');

T.confirmed = true;
T.created   = char(datetime('now','Format','yyyy-MM-dd HH:mm'));

orient_file = fullfile(dataDir, sprintf('cp_orient_ctrl_%s.mat', sess_tag));
save(orient_file, 'T');
paths.orient_file = orient_file;

s1_file = fullfile(dataDir, sprintf('ctrl_ols_spont_%s.mat', sess_tag));
if exist(s1_file,'file')
    Torient = T;
    save(s1_file, 'Torient', '-append');
    paths.s1_file = s1_file;
else
    paths.s1_file = '';
    warning('cp_orient_save:noS1', ...
        'No Stage-1 cache %s -- saved standalone view only; run ctrl_ols_spont to bake Torient.', s1_file);
end

fprintf('[cp_orient_save] %s : %s%s -> %s\n', sess_tag, ...
    local_name(T), local_rot(T), ...
    local_two(paths.orient_file, paths.s1_file));
end

function s = local_name(T)
p = {}; if T.tr, p{end+1}='transpose'; end
if T.fu, p{end+1}='flipud'; end
if T.fl, p{end+1}='fliplr'; end
if isempty(p), s='native'; else, s=strjoin(p,'+'); end
end
function s = local_rot(T)
if isfield(T,'rot') && T.rot~=0, s=sprintf(' + rot %+g deg', T.rot); else, s=''; end
end
function s = local_two(a,b)
if isempty(b), s=a; else, [~,fa]=fileparts(a); [~,fb]=fileparts(b); s=sprintf('%s + %s', fa, fb); end
end
