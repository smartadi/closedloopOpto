function collect_final_panels(varargin)
%COLLECT_FINAL_PANELS  Verify (and prune) the Illustrator pull-folder against MANIFEST.txt.
%
%   collect_final_panels          % report + prune anything the manifest does not list
%   collect_final_panels('dry')   % report only, delete nothing
%
% ---- WHAT CHANGED 2026-10-02 (user: "only maintain one single folder") -------------------
% This used to COPY each manifest source out of paper/figures_v2 or paper/images into
% panels/. It must not any more. Panels are now written directly into
% panels/<section>/ by utils/paper_final_mirror.m, which applies the jn rule-book
% typography pass (labels 7 pt bold / ticks 6 pt regular) on the way out. Copying from the
% v2/images working dirs would overwrite those jn panels with their NON-jn originals and
% silently undo the restyle -- the exact kind of last-writer-wins trap that put a secondary
% statistic into a published panel earlier the same day.
%
% So the roles are now clean:
%   utils/paper_final_mirror.m  WRITES panels/   (gated on this manifest, jn styling applied)
%   this function              CHECKS panels/   (prunes unlisted, names anything missing)
%
% panels/<section>/ is the ONE folder to pull into Illustrator. paper/images/figureN and
% paper/figures_v2/figureN remain working dirs full of superseded and exploratory panels --
% never point the assembly at them. paper/figures_v3 is deleted; it no longer exists.
%
% To REGENERATE the panels, run the producers with the mirror on:
%   global PAPER_FINAL; PAPER_FINAL = true;   then run the producer scripts.
here = fileparts(mfilename('fullpath'));
dry  = ~isempty(varargin) && any(strcmpi(varargin{1},{'dry','dryrun','-n'}));

man = fullfile(here,'MANIFEST.txt');
assert(isfile(man), 'MANIFEST.txt not found at %s', man);
txt = strsplit(fileread(man), newline);

want = containers.Map('KeyType','char','ValueType','any');   % section -> {basenames}
cur  = '';
for i = 1:numel(txt)
    ln = strtrim(txt{i});
    if isempty(ln) || startsWith(ln,'#'), continue; end
    if startsWith(ln,'[') && endsWith(ln,']')
        cur = ln(2:end-1);
        if ~isKey(want,cur); want(cur) = {}; end
        continue;
    end
    if isempty(cur), continue; end
    [~,nm,ex] = fileparts(ln);            % whole line is the path; it may contain spaces
    want(cur) = [want(cur), {[nm ex]}];
end

fprintf('\n=== collect_final_panels %s ===\n', local_tern(dry,'(DRY RUN)',''));
nOK = 0; nMiss = 0; nPrune = 0; missing = {};
for s = keys(want)
    sec     = s{1};
    destdir = fullfile(here,'panels',sec);
    listed  = want(sec);
    if ~exist(destdir,'dir')
        fprintf('  [%s] folder does not exist -- %d panel(s) missing\n', sec, numel(listed));
        nMiss = nMiss + numel(listed);
        missing = [missing, strcat(sec,'/',listed)];                       %#ok<AGROW>
        continue;
    end
    for k = 1:numel(listed)
        if isfile(fullfile(destdir,listed{k}))
            nOK = nOK + 1;
        else
            fprintf('  MISSING  %-46s [%s]\n', listed{k}, sec);
            nMiss = nMiss + 1;
            missing{end+1} = [sec '/' listed{k}];                          %#ok<AGROW>
        end
    end
    % prune anything present but not listed (PNG previews are matched to their PDF)
    present = dir(fullfile(destdir,'*.*'));
    for k = 1:numel(present)
        f = present(k).name;
        if present(k).isdir || strcmpi(f,'README.txt'), continue; end
        [~,nm,ex] = fileparts(f);
        key = [nm '.pdf'];                      % a .png is kept iff its .pdf is listed
        if strcmpi(ex,'.pdf'), key = f; end
        if ~any(strcmpi(key, listed))
            fprintf('  PRUNE    %-46s [%s]\n', f, sec);
            if ~dry, delete(fullfile(destdir,f)); end
            nPrune = nPrune + 1;
        end
    end
end

fprintf('--- %d present, %d missing, %d %s ---\n', nOK, nMiss, nPrune, ...
        local_tern(dry,'would be pruned','pruned'));
if nMiss > 0
    fprintf(['\nTo rebuild the missing panels:\n' ...
             '    global PAPER_FINAL; PAPER_FINAL = true;\n' ...
             '    <run the producer script for each>\n' ...
             'Figure-1 panels have no producer (hand-made assets) -- see panels/figure1/README.txt.\n']);
end
end

function out = local_tern(c,a,b)
if c, out = a; else, out = b; end
end
