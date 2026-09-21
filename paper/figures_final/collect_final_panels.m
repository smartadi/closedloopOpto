function collect_final_panels(varargin)
% collect_final_panels  Sync figures_final/panels/ to MANIFEST.txt EXACTLY.
%
%   Reads MANIFEST.txt (next to this script). For every [section] it makes
%   panels/<section>/ contain exactly the listed source panels: copies each
%   listed source in from paper/images/, and DELETES any *.pdf already in the
%   folder that is not on the list. That is what keeps the Illustrator pull-
%   folder free of retired/exploratory panels.
%
%   collect_final_panels           % apply changes
%   collect_final_panels('dry')    % report only, delete/copy nothing
%
% THE RULE: a panel is "final" iff it is listed in MANIFEST.txt. Lock a panel ->
% add its line + re-run; retire one -> delete its line + re-run. Never pull
% Illustrator art from paper/images/figureN/ (working dirs) -- pull from
% figures_final/panels/ only.

dry = ~isempty(varargin) && any(strcmpi(varargin{1},{'dry','dryrun','-n'}));
here     = fileparts(mfilename('fullpath'));
imgroot  = fullfile(here,'..','images');
manifest = fullfile(here,'MANIFEST.txt');
assert(isfile(manifest),'MANIFEST.txt not found next to collect_final_panels.m');

% ---- parse MANIFEST into sec.<name> = {relpaths} ----------------------------
lines = string(splitlines(fileread(manifest)));
sec = struct(); cur = '';
for i = 1:numel(lines)
    ln = strip(lines(i));
    if ln=="" || startsWith(ln,'#'); continue; end
    if startsWith(ln,'[') && endsWith(ln,']')
        cur = char(extractBetween(ln,'[',']'));
        if ~isfield(sec,cur); sec.(cur) = strings(0,1); end
        continue;
    end
    if isempty(cur); warning('line before any [section]: %s',ln); continue; end
    sec.(cur)(end+1,1) = ln; %#ok<AGROW>
end

figs = fieldnames(sec);
nCopy=0; nDel=0; nMiss=0; nKeep=0;
fprintf('\n=== collect_final_panels %s ===\n', ternary(dry,'(DRY RUN)',''));
for f = 1:numel(figs)
    fn = figs{f}; destdir = fullfile(here,'panels',fn);
    if ~isfolder(destdir)
        if ~dry; mkdir(destdir); end
        fprintf('[%s] created panels/%s/\n', fn, fn);
    end
    want = sec.(fn); wantBase = strings(0,1);
    % ---- copy listed sources in ----
    for k = 1:numel(want)
        src = fullfile(imgroot, char(want(k)));
        [~,b,e] = fileparts(char(want(k))); base = [b e];
        wantBase(end+1,1) = string(base); %#ok<AGROW>
        dest = fullfile(destdir, base);
        if ~isfile(src)
            fprintf('  MISSING  %-40s (source not found: %s)\n', base, want(k));
            nMiss = nMiss+1; continue;
        end
        needcopy = ~isfile(dest) || dir(src).datenum > dir(dest).datenum;
        if needcopy
            if ~dry; copyfile(src,dest); end
            fprintf('  copy     %s\n', base); nCopy = nCopy+1;
        else
            nKeep = nKeep+1;
        end
    end
    % ---- delete anything in the folder not on the list ----
    existing = dir(fullfile(destdir,'*.pdf'));
    for k = 1:numel(existing)
        if ~any(wantBase == string(existing(k).name))
            if ~dry; delete(fullfile(destdir,existing(k).name)); end
            fprintf('  DELETE   %s  (not in manifest)\n', existing(k).name); nDel = nDel+1;
        end
    end
end
fprintf('--- %d copied, %d up-to-date, %d deleted, %d missing sources ---\n', ...
    nCopy, nKeep, nDel, nMiss);
if nMiss>0; fprintf('  (missing = listed in MANIFEST but not yet exported to paper/images/)\n'); end
if dry; fprintf('  DRY RUN: nothing was changed.\n'); end
end

function o=ternary(c,a,b); if c; o=a; else; o=b; end; end
