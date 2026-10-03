function paper_final_mirror(fig, path)
% PAPER_FINAL_MIRROR  Write the jn-style (rule-book) copy of a FINAL panel straight into
% the Illustrator pull-folder, paper/figures_final/panels/<section>/.
%
% Called from BOTH utils/paperExport.m and utils/jnExport.m, so a panel lands whichever
% exporter its producer happens to use. No-op unless the global PAPER_FINAL is true:
%     global PAPER_FINAL; PAPER_FINAL = true;     % then run any producer script
%
% ---- ONE FOLDER (user, 2026-10-02) ----------------------------------------------------
% This used to write a parallel paper/figures_v3/ tree, which meant TWO folders claiming to
% hold the final panels. There is now exactly one: paper/figures_final/panels/<section>/.
% That folder is what gets pulled into Illustrator; figures_v3 is deleted.
%
% ---- IT MIRRORS ONLY FINALIZED PANELS -------------------------------------------------
% The gate is paper/figures_final/MANIFEST.txt, the project's definition of "final"
% (CLAUDE.md: "a panel is final iff it is listed in MANIFEST.txt"). A producer typically
% exports many panels -- exploratory views, supplements, per-mode variants -- and mirroring
% all of them filled the folder with ~30 files nobody asked for. Only a basename listed in
% the manifest is written; everything else is skipped silently.
%
% The destination is the manifest's own [section], NOT the source path, so the two tf_cv_*
% panels whose source lives in images/figure2/ land under supplementary/ as the manifest says.
%
% What the jn pass changes: jnAxesAll(fig) -- Arial, tick labels 6 pt regular, axis labels
% and title 7 pt bold, ticks out, box off, axis line 0.5 pt (FIGURE_RULEBOOK §3). Line
% weights are NOT touched: paperStyle's lw_* were already on the rule-book values, and the
% two styles' condition colours are identical (col_ol [1 0 0], col_cl [0 0.40 0.85]) --
% checked, not assumed. Typography was the real divergence.
%
% A 300-dpi PNG preview is written beside each PDF. The caller has already written its own
% images/figures_v2 original, so this is purely additive. Failures NEVER propagate: losing a
% mirror must not abort a producer mid-figure.
global PAPER_FINAL PAPER_FINAL_LOG                                  %#ok<GVMIS>
if isempty(PAPER_FINAL) || ~PAPER_FINAL, return; end
[~, base, ext] = fileparts(char(path));
if ~any(strcmpi(ext, {'.pdf','.svg','.eps'})), return; end          % vector panels only

sec = local_manifest_section([base ext]);
if isempty(sec), return; end                                        % not a FINAL panel -> skip

try
    root = fileparts(fileparts(mfilename('fullpath')));             % utils/.. = project root
    out  = fullfile(root, 'paper', 'figures_final', 'panels', sec, [base ext]);
    d    = fileparts(out);
    if ~exist(d,'dir'); mkdir(d); end
    jnAxesAll(fig);                                                 % rule-book typography pass
    exportgraphics(fig, out, 'ContentType','vector');
    exportgraphics(fig, regexprep(out,'\.(pdf|svg|eps)$','.png'), 'Resolution',300);
    fprintf('   [final+jn] panels%s%s%s%s\n', filesep, sec, filesep, [base ext]);
    if isempty(PAPER_FINAL_LOG); PAPER_FINAL_LOG = {}; end
    PAPER_FINAL_LOG{end+1} = out;
catch ME
    if strcmp(ME.identifier,'MATLAB:print:CannotCreateOutputFile') || ...
       contains(lower(ME.message),'permission')
        warning('paper_final_mirror:locked', ...
            ['%s is LOCKED (open in Illustrator/Acrobat?) -- panel NOT updated. ' ...
             'Close it and re-run.'], [base ext]);
    else
        warning('paper_final_mirror:failed', 'mirror failed for %s (%s)', char(path), ME.message);
    end
end
end

% -----------------------------------------------------------------------------------------
function sec = local_manifest_section(base)
% Return the manifest [section] that lists this basename, or '' if it is not final.
% Parsed once per MATLAB session and cached; `clear paper_final_mirror` re-reads it after
% the manifest is edited.
persistent MAP
if isempty(MAP)
    MAP  = containers.Map('KeyType','char','ValueType','char');
    root = fileparts(fileparts(mfilename('fullpath')));
    mf   = fullfile(root,'paper','figures_final','MANIFEST.txt');
    if ~isfile(mf)
        warning('paper_final_mirror:noManifest', ...
            'MANIFEST.txt not found at %s -- nothing will be mirrored', mf);
        sec = ''; return;
    end
    txt = strsplit(fileread(mf), newline);
    cur = '';
    for i = 1:numel(txt)
        ln = strtrim(txt{i});
        if isempty(ln) || startsWith(ln,'#'), continue; end
        if startsWith(ln,'[') && endsWith(ln,']')
            cur = ln(2:end-1); continue;
        end
        if isempty(cur), continue; end
        % the WHOLE line is the path (it may contain spaces); we key on its basename
        [~, nm, ex] = fileparts(ln);
        MAP([nm ex]) = cur;
    end
end
if isKey(MAP, base), sec = MAP(base); else, sec = ''; end
end
