function paper_v3_mirror(fig, path)
% PAPER_V3_MIRROR  Write a jn-style (rule-book) copy of a FINAL panel under figures_v3.
%
% Called from BOTH utils/paperExport.m and utils/jnExport.m, so a panel lands in v3 whichever
% exporter its producer happens to use. No-op unless the global PAPER_V3 is true:
%     global PAPER_V3; PAPER_V3 = true;     % then run any producer script
%
% ---- IT MIRRORS ONLY FINALIZED PANELS -------------------------------------------------------
% The gate is paper/figures_final/MANIFEST.txt, the project's existing definition of "final"
% (CLAUDE.md: "a panel is final iff it is listed in MANIFEST.txt"). A producer script typically
% exports many panels -- exploratory views, supplements, per-mode variants -- and mirroring all
% of them filled figures_v3 with ~30 files nobody asked for (user, 2026-10-02). Only a basename
% listed in the manifest is mirrored; everything else is skipped silently.
%
% The destination is the manifest's own [section], NOT the source path, so figures_v3/ ends up
% with the same layout as figures_final/panels/. That matters for the two tf_cv_* panels whose
% source lives in images/figure2/ but which the manifest files under [supplementary].
%
% What the jn pass changes: jnAxesAll(fig) -- Arial, tick labels 6 pt regular, axis labels and
% title 7 pt bold, ticks out, box off, axis line 0.5 pt (FIGURE_RULEBOOK §3). Line weights are
% NOT touched: paperStyle's lw_* were already moved onto the rule-book values, and the two
% styles' condition colours are identical (col_ol [1 0 0], col_cl [0 0.40 0.85]) -- checked,
% not assumed. Typography was the real divergence.
%
% The caller has ALREADY written its own v2/images original before this runs, so v3 is purely
% additive. Failures NEVER propagate: losing a mirror must not abort a producer mid-figure.
global PAPER_V3 PAPER_V3_LOG                                        %#ok<GVMIS>
if isempty(PAPER_V3) || ~PAPER_V3, return; end
[~, base, ext] = fileparts(char(path));
if ~any(strcmpi(ext, {'.pdf','.svg','.eps'})), return; end          % vector panels only

sec = local_manifest_section([base ext]);
if isempty(sec), return; end                                        % not a FINAL panel -> skip

try
    root = fileparts(fileparts(mfilename('fullpath')));             % utils/.. = project root
    v3   = fullfile(root, 'paper', 'figures_v3', sec, [base ext]);
    d    = fileparts(v3);
    if ~exist(d,'dir'); mkdir(d); end
    jnAxesAll(fig);                                                 % rule-book typography pass
    exportgraphics(fig, v3, 'ContentType','vector');
    exportgraphics(fig, regexprep(v3,'\.(pdf|svg|eps)$','.png'), 'Resolution',300);
    fprintf('   [v3+jn] %s%s%s\n', sec, filesep, [base ext]);
    if isempty(PAPER_V3_LOG); PAPER_V3_LOG = {}; end
    PAPER_V3_LOG{end+1} = v3;
catch ME
    warning('paper_v3_mirror:failed', 'v3 mirror failed for %s (%s)', char(path), ME.message);
end
end

% -----------------------------------------------------------------------------------------
function sec = local_manifest_section(base)
% Return the manifest [section] that lists this basename, or '' if it is not final.
% Parsed once per MATLAB session and cached; `clear paper_v3_mirror` forces a re-read after
% the manifest is edited.
persistent MAP
if isempty(MAP)
    MAP  = containers.Map('KeyType','char','ValueType','char');
    root = fileparts(fileparts(mfilename('fullpath')));
    mf   = fullfile(root,'paper','figures_final','MANIFEST.txt');
    if ~isfile(mf)
        warning('paper_v3_mirror:noManifest', ...
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
