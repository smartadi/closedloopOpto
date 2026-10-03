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

    % ---- SIZE GUARD (user, 2026-10-02: "must not be oversized") -----------------------
    % The vector export tight-crops to CONTENT, so the page that lands in Illustrator can be
    % bigger than the canvas we designed. Measure what actually got written and complain if
    % it overhangs; silence here is how an oversized panel reaches the assembly unnoticed.
    pu = fig.Units; fig.Units = 'centimeters'; cv = fig.Position(3:4); fig.Units = pu;
    [pw, ph] = pdf_page_cm(out);
    tol  = 0.15;                                 % cm; ~1.5 mm of honest antialias/linewidth
    over = [pw - cv(1), ph - cv(2)];

    % Oversized -> try pulling the content inside the canvas and export again. Done ONLY on
    % panels that actually overflow, so the ones that already fit keep their exact layout.
    %
    % KEEP-BEST-OF-TWO: the refit is a heuristic and it can make a panel WORSE (tf_cv_single
    % went 5.93 -> 6.35 cm when the axes shrank but a clipping-off scale bar did not follow).
    % So the refit is exported to a scratch file, measured, and adopted only if it genuinely
    % reduces the overflow. An automatic fixer that is allowed to degrade a paper panel is
    % worse than no fixer at all.
    if ~isnan(pw) && any(over > tol)
        try
            tmp = [tempname '.pdf'];
            jn_fit_canvas(fig);
            exportgraphics(fig, tmp, 'ContentType','vector');
            [pw2, ph2] = pdf_page_cm(tmp);
            best0 = max(over);
            best1 = max([pw2 - cv(1), ph2 - cv(2)]);
            if ~isnan(pw2) && best1 < best0 - 0.01
                copyfile(tmp, out);
                exportgraphics(fig, regexprep(out,'\.(pdf|svg|eps)$','.png'), 'Resolution',300);
                fprintf('   [fit] %-40s %5.2f x %5.2f  ->  %5.2f x %5.2f cm\n', ...
                        [base ext], pw, ph, pw2, ph2);
                pw = pw2; ph = ph2; over = [pw - cv(1), ph - cv(2)];
            else
                fprintf('   [fit] %-40s refit REJECTED (%.2f x %.2f would not improve)\n', ...
                        [base ext], pw2, ph2);
            end
            if isfile(tmp), delete(tmp); end
        catch
            % refit failed outright -- keep the original export
        end
    end

    if ~isnan(pw) && any(over > tol)
        warning('paper_final_mirror:oversized', ...
            ['%s is OVERSIZED: page %.2f x %.2f cm vs canvas %.2f x %.2f cm ' ...
             '(+%.2f, +%.2f). Content is overhanging the canvas — shrink the axes or pull ' ...
             'the legend/labels inside; do NOT just scale it in Illustrator.'], ...
            [base ext], pw, ph, cv(1), cv(2), over(1), over(2));
        tag = sprintf(' OVERSIZE +%.2f/+%.2f', over(1), over(2));
    else
        tag = '';
    end
    fprintf('   [final+jn] panels%s%s%s%-46s %5.2f x %5.2f cm%s\n', ...
            filesep, sec, filesep, [base ext], pw, ph, tag);

    if isempty(PAPER_FINAL_LOG); PAPER_FINAL_LOG = {}; end
    PAPER_FINAL_LOG{end+1} = struct('file',out, 'sec',sec, 'name',[base ext], ...
                                    'page_cm',[pw ph], 'canvas_cm',cv, 'over_cm',over);
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
        % The line is the path, optionally followed by a '# w x h cm' size note (recorded by
        % the size audit so Illustrator placement is deterministic). Strip the note; the path
        % itself may contain spaces, so split on '#' only, never on whitespace.
        hh = strfind(ln, '#');
        if ~isempty(hh), ln = strtrim(ln(1:hh(1)-1)); end
        if isempty(ln), continue; end
        [~, nm, ex] = fileparts(ln);
        MAP([nm ex]) = cur;
    end
end
if isKey(MAP, base), sec = MAP(base); else, sec = ''; end
end
