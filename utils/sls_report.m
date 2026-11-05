function n = sls_report(fig, pdfpath, varargin)
% SLS_REPORT  Print the lab-style REQUIRED problems of a finished panel; never errors.
%
%   sls_report(fig, 'paper/figures_final/panels/figure3/panel_D.pdf')
%   n = sls_report(fig, pdf, 'MinFontPt', 5)       % n = number of required problems
%
% Two checks, because each sees what the other cannot:
%   1. sls_check(fig): the live MATLAB figure -- data past an axis end, colormaps,
%      overlaps, units, type size as set.
%   2. utils/sls_audit_pdf.py on the written PDF -- type size and overlaps as actually
%      exported (exportgraphics/print can rescale a small panel), colormaps in images.
%      Needs `py -3` with PyMuPDF (the lab PC's Python 3.14 has it); skipped otherwise.
% Called by paper_final_mirror for every final panel, so a PAPER_FINAL rebuild reports
% itself. Preferences (spines, ticks, space, fonts) are left to an explicit sls_check.
%
% See also SLS_CHECK, PAPER_FINAL_MIRROR.

p = inputParser;
p.addParameter('MinFontPt', 5);
p.parse(varargin{:});
minPt = p.Results.MinFontPt;
n = 0;
[~, nm, ext] = fileparts(char(pdfpath));
tag = [nm ext];

if ~isempty(fig) && isgraphics(fig)
    try
        I = sls_check(fig, 'MinFontPt', minPt, 'Quiet', true);
        I = I(strcmp({I.level}, 'required'));
        for k = 1:numel(I)
            fprintf('   [lab check] %s  %s: %s: %s\n', tag, I(k).kind, I(k).where, I(k).message);
        end
        n = n + numel(I);
    catch ME
        fprintf('   [lab check] %s  sls_check failed: %s\n', tag, ME.message);
    end
end

if endsWith(lower(char(pdfpath)), '.pdf') && isfile(pdfpath)
    script = fullfile(fileparts(mfilename('fullpath')), 'sls_audit_pdf.py');
    [st, txt] = system(sprintf('py -3 -I "%s" "%s" --min-pt %g', script, pdfpath, minPt));
    if st ~= 0
        fprintf('   [lab check] %s  PDF audit skipped (needs py -3 with PyMuPDF)\n', tag);
    else
        req = regexp(txt, '\[req:[^\r\n]*', 'match');
        for k = 1:numel(req)
            fprintf('   [lab check] %s  PDF %s\n', tag, req{k});
        end
        n = n + numel(req);
    end
end
end
