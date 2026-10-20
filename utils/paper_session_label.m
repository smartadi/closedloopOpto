function [lab, info] = paper_session_label(x, style)
%PAPER_SESSION_LABEL  The ONE paper-wide label for a recording session: "Mouse 1e", "Mouse 4".
%
% RULE (user 2026-10-19): a session is named by its mouse number; when a mouse contributes more
% than one session ANYWHERE in the paper, a letter follows the number, assigned in date order
% (then experiment number) across every session of that mouse in the paper -- controller,
% impulse, gain grid, auto-tune and sinusoid alike. So a session keeps the same label in every
% figure, table and sentence. Mouse numbers follow the cohort table: 1 = AL_0033, 2 = AL_0039,
% 3 = AL_0048, 4 = AL_0051, 5 = AL_0041.
%
% INPUT  x      one session, as any of:
%                 struct with .mn/.td/.en (load_sessions, allExperiments), or with .label or
%                 .sess_tag holding one of the string forms below;
%                 'AL_0033 2025-01-29 e1'   (imp_tf_fit_session .label)
%                 'AL_0033_2025-01-29_e1'   (contra_prediction_controller sess_tag)
%                 'AL_0033_0212_e2'         (ctrl_lti_sysid / f4 reject sess_tag)
%                 'm4'                      (load_sessions field name, controller set only)
%               or a cell array of these (returns a cell array).
%        style  'full' (default) -> 'Mouse 1e';  'short' -> 'M1e' (cramped ticks).
% OUTPUT lab    label (char), or cell of labels.
%        info   registry row(s): mn, td, en, label, role, nSess (paper sessions of that mouse).
%
% Adding a session to the paper: add its row to REG below, in any position (letters are
% recomputed from date order), and update the cohort table / Table S1 in the manuscript.

if nargin < 2 || isempty(style), style = 'full'; end
if iscell(x)
    lab = cell(size(x));  info = cell(size(x));
    for i = 1:numel(x), [lab{i}, info{i}] = paper_session_label(x{i}, style); end
    return
end
if isstruct(x) && numel(x) > 1
    lab = cell(size(x));  info = cell(size(x));
    for i = 1:numel(x), [lab{i}, info{i}] = paper_session_label(x(i), style); end
    return
end

%        mouse      date          exp  role
REG = { ...
    'AL_0033', '2025-01-20', 3, 'ctrl m1';
    'AL_0033', '2025-01-29', 1, 'impulse';
    'AL_0033', '2025-02-12', 2, 'ctrl m2';
    'AL_0033', '2025-02-24', 2, 'ctrl m3';
    'AL_0033', '2025-02-26', 2, 'ctrl m4 (MPC replay)';
    'AL_0033', '2025-03-04', 1, 'ctrl m5';
    'AL_0033', '2025-03-05', 1, 'gain grid (Fig S2)';
    'AL_0033', '2025-03-05', 2, 'ctrl m6';
    'AL_0033', '2025-03-17', 3, 'auto-tune (Fig S2)';
    'AL_0033', '2025-03-20', 4, 'ctrl m7';
    'AL_0033', '2025-04-15', 2, 'ctrl m8';
    'AL_0033', '2025-04-19', 1, 'ctrl m12';
    'AL_0039', '2025-04-19', 1, 'ctrl m10 (Fig 3 example)';
    'AL_0039', '2025-04-20', 1, 'ctrl m9';
    'AL_0039', '2025-04-20', 2, 'ctrl m13';
    'AL_0039', '2025-04-30', 3, 'ctrl m11';
    'AL_0048', '2026-07-01', 6, 'sine s1';
    'AL_0048', '2026-07-14', 1, 'sine s2 (Fig 5 example, Fig 6 sine replay)';
    'AL_0048', '2026-07-15', 1, 'impulse';
    'AL_0048', '2026-07-21', 1, 'sine s3';
    'AL_0048', '2026-07-29', 2, 'ctrl m14';
    'AL_0051', '2026-07-29', 2, 'ctrl m15';
    'AL_0041', '2025-12-02', 1, 'impulse';
    'AL_0041', '2025-12-02', 2, 'impulse';
    };
MOUSE = {'AL_0033', 'AL_0039', 'AL_0048', 'AL_0051', 'AL_0041'};
CTRL_EN = [3 2 2 2 1 2 4 2 1 1 3 1 2 2 2];   % load_sessions m1..m15 exp numbers, for 'm#' input

[mn, td, en] = i_parse(x, REG, CTRL_EN);

% letters: date order, then exp, within mouse
rows = find(strcmp(REG(:,1), mn));
if isempty(rows), error('paper_session_label:unknownMouse', 'Mouse %s is not in the paper registry.', mn); end
key  = strcat(REG(rows,2), '_', compose('%02d', cell2mat(REG(rows,3))));
[~, so] = sort(key);  rows = rows(so);
if isempty(td)                                    % mouse-only request
    k = [];
else
    md = @(d) d(end-4:end);                       % 'MM-DD' (tags carry no year; unique per mouse)
    k = find(arrayfun(@(r) strcmp(md(REG{r,2}), md(td)) && REG{r,3} == en, rows), 1);
    if isempty(k)
        error('paper_session_label:unknownSession', ...
            'Session %s %s e%d is not in the paper registry (utils/paper_session_label.m).', mn, td, en);
    end
end

num = find(strcmp(MOUSE, mn));
if strcmpi(style, 'short'), pre = 'M'; else, pre = 'Mouse '; end
if numel(rows) > 1 && ~isempty(k)
    lab = sprintf('%s%d%c', pre, num, char('a' + k - 1));
else
    lab = sprintf('%s%d', pre, num);
end
if isempty(k)
    info = struct('mn', mn, 'td', '', 'en', NaN, 'label', lab, 'role', 'mouse', 'nSess', numel(rows));
else
    r = rows(k);
    info = struct('mn', mn, 'td', REG{r,2}, 'en', REG{r,3}, 'label', lab, 'role', REG{r,4}, 'nSess', numel(rows));
end
end

function [mn, td, en] = i_parse(x, REG, CTRL_EN)
mn = '';  td = '';  en = NaN;
if isstruct(x)
    if isfield(x,'mn') && isfield(x,'td') && ~isempty(x.td)
        mn = char(x.mn);  td = char(x.td);
        if isfield(x,'en') && ~isempty(x.en), en = double(x.en); end
    elseif isfield(x,'label'),    x = x.label;
    elseif isfield(x,'sess_tag'), x = x.sess_tag;
    elseif isfield(x,'mn'),       mn = char(x.mn);
    end
end
if isempty(mn)
    s = char(string(x));
    t = regexp(s, '^m(\d+)$', 'tokens', 'once');
    if ~isempty(t)                                % load_sessions field name
        i = str2double(t{1});
        c = REG(~cellfun(@isempty, regexp(REG(:,4), sprintf('^ctrl m%d( |$)', i))), :);
        assert(size(c,1) == 1 && c{3} == CTRL_EN(i), 'paper_session_label: bad controller index %s', s);
        mn = c{1};  td = c{2};  en = c{3};  return
    end
    t = regexp(s, '^(AL_\d+)[ _](\d{4}-\d{2}-\d{2})[ _/]e?(\d+)$', 'tokens', 'once');
    if isempty(t), t = regexp(s, '^(AL_\d+)_(\d{2})(\d{2})_e(\d+)$', 'tokens', 'once');
        if ~isempty(t), t = {t{1}, ['xxxx-' t{2} '-' t{3}], t{4}}; end
    end
    if isempty(t), t = regexp(s, '^(AL_\d+)$', 'tokens', 'once'); end
    if isempty(t), error('paper_session_label:parse', 'Cannot parse session "%s".', s); end
    mn = t{1};
    if numel(t) >= 3, td = t{2};  en = str2double(t{3}); end
end
if ~isempty(td) && isnan(en)                      % date given without exp: must be unique
    r = find(strcmp(REG(:,1), mn) & endsWith(REG(:,2), td(end-4:end)));
    if numel(r) ~= 1
        error('paper_session_label:ambiguous', '%s %s needs an experiment number.', mn, td);
    end
    en = REG{r,3};
end
end
