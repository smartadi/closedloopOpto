function labs = imp_mouse_label(mnList)
%IMP_MOUSE_LABEL  Per-ANIMAL legend labels for a set of sessions: "Mouse 1a", "Mouse 2", ...
%
% Sessions are NOT mice: the impulse set is AL_0041 e1, AL_0041 e2, AL_0033 e1, AL_0048 e1,
% so a bare "Mouse 1..4" would claim four animals where there are three. This numbers the
% UNIQUE mouse names in order of appearance and suffixes a/b/... when one animal contributes
% more than one session (AL_0041 -> Mouse 1a, Mouse 1b).
%
% Shared helper so EVERY figure labels the same session the same way (user, 2026-08-24:
% "legends across the figures must consistently use mouse instead of session"). The logic was
% previously inlined in dose_response.m only; it now lives here and dose_response calls it.
%
% INPUT  mnList  cell/string array of mouse names, one per session, IN PANEL ORDER
%                (e.g. {'AL_0041','AL_0041','AL_0033','AL_0048'}), OR a cell array of session
%                structs each with a .mn field.
% OUTPUT labs    cell array of char labels, same length and order as the input.

n = numel(mnList);
mn = strings(n,1);
for i = 1:n
    if iscell(mnList), x = mnList{i}; else, x = mnList(i); end
    if isstruct(x) && isfield(x,'mn'), mn(i) = string(x.mn); else, mn(i) = string(x); end
end
[~, ~, mIdx] = unique(mn, 'stable');           % unique animals, in order of first appearance
labs = cell(n,1);
for i = 1:n
    sib = find(mIdx == mIdx(i));               % all sessions from this animal
    if numel(sib) > 1
        labs{i} = sprintf('Mouse %d%c', mIdx(i), char('a' + find(sib == i) - 1));
    else
        labs{i} = sprintf('Mouse %d', mIdx(i));
    end
end
end
