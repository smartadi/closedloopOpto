function L = imp_sess_label(s)
%IMP_SESS_LABEL  Short display label for one fitted session: "AL_0033 2025-01-29 e3" -> "0033 01/29".
%
% A 6 pt legend or tick label inside a 4-6 cm panel cannot carry the full session
% string, and what actually distinguishes these rows is the mouse number and the day.
% Lives in utils/ rather than as a local copy in each figure file: the TF shape panel
% and the TF-A/C/D robustness panels must label the SAME session the SAME way, or the
% reader cannot carry an identity from one panel to the next.
%
% INPUT  s  one imp_tf_fit_session output (uses .mn/.td; falls back to .label).
% OUTPUT L  char row vector, no LaTeX-significant characters beyond '/'.
%
% Set the tick/legend Interpreter to 'none' where this is used -- the fallback path
% returns the full label, which contains underscores.

if ~isstruct(s), L = char(string(s)); return; end
if ~isfield(s,'mn') || isempty(s.mn)
    if isfield(s,'label'), L = char(s.label); else, L = '?'; end
    return
end
mn = regexprep(char(s.mn), '^[A-Za-z]+_', '');          % AL_0033 -> 0033
d  = '';
if isfield(s,'td') && ~isempty(s.td)
    d = regexprep(char(string(s.td)), '\D', '');        % 2025-01-29 -> 20250129
    if numel(d) >= 8, d = [d(5:6) '/' d(7:8)]; else, d = char(string(s.td)); end
end
% Site matters only where a session contributes more than one readout (AL_0048 has an
% excitatory and an inhibitory site); appended only when present so the common case
% stays two tokens wide.
sTag = '';
if isfield(s,'site') && ~isempty(s.site), sTag = [' ' char(string(s.site))]; end
L = strtrim(sprintf('%s %s%s', mn, d, sTag));
end
