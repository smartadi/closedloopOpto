function labs = imp_mouse_label(mnList, style)
%IMP_MOUSE_LABEL  Per-ANIMAL legend labels for a set of sessions: "Mouse 5a", "Mouse 1", ...
%
% style (optional): 'full' (default) -> "Mouse 5a"; 'short' -> "M5a" (for cramped axis
% ticks / inline labels; user 2026-09-22: shorthand except inside a legend box).
%
% GLOBAL NUMBERING (user 2026-10-13): one ID per animal across the whole paper, matching the
% cohort table order -- Mouse 1 = AL_0033, 2 = AL_0039, 3 = AL_0048, 4 = AL_0051, 5 = AL_0041.
% (Before 2026-10-13 mice were numbered by order of first appearance in each panel, so Fig 2
% and Fig 4G gave the same animal different numbers.) Unknown mice get 6, 7, ... in order of
% appearance. A suffix a/b/... is added when one animal contributes more than one session to
% the list (the impulse set: AL_0041 e1/e2 -> Mouse 5a, Mouse 5b).
%
% INPUT  mnList  cell/string array of mouse names, one per session, IN PANEL ORDER
%                (e.g. {'AL_0041','AL_0041','AL_0033','AL_0048'}), OR a cell array of session
%                structs each with a .mn field.
% OUTPUT labs    cell array of char labels, same length and order as the input.

GLOBAL_ID = {'AL_0033', 'AL_0039', 'AL_0048', 'AL_0051', 'AL_0041'};

n = numel(mnList);
mn = strings(n,1);
for i = 1:n
    if iscell(mnList), x = mnList{i}; else, x = mnList(i); end
    if isstruct(x) && isfield(x,'mn'), mn(i) = string(x.mn); else, mn(i) = string(x); end
end
if nargin < 2 || isempty(style), style = 'full'; end
switch lower(style)
    case 'short', pre = 'M';
    otherwise,    pre = 'Mouse ';
end
id = zeros(n,1);  nextId = numel(GLOBAL_ID) + 1;
for i = 1:n
    k = find(strcmp(GLOBAL_ID, mn(i)), 1);
    if isempty(k)
        j = find(mn(1:i-1) == mn(i), 1);
        if isempty(j), k = nextId; nextId = nextId + 1; else, k = id(j); end
    end
    id(i) = k;
end
labs = cell(n,1);
for i = 1:n
    sib = find(mn == mn(i));                   % all sessions from this animal
    if numel(sib) > 1
        labs{i} = sprintf('%s%d%c', pre, id(i), char('a' + find(sib == i) - 1));
    else
        labs{i} = sprintf('%s%d', pre, id(i));
    end
end
end
