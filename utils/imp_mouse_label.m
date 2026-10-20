function labs = imp_mouse_label(sessList, style)
%IMP_MOUSE_LABEL  Paper-wide session labels for a list of sessions: "Mouse 5a", "Mouse 1b", ...
%
% Thin wrapper over utils/paper_session_label.m, which holds the ONE registry.
% RULE (user 2026-10-19): mouse number, plus a letter when the mouse has more than one session
% anywhere in the paper; letters run in date order across ALL of that mouse's sessions, so a
% session has the same label in every figure. (Until 2026-10-19 letters were assigned within
% each panel's list, so Fig 2 showed "Mouse 1" for the AL_0033 impulse session and Fig 4G
% relettered Mouse 1 after dropping m2.)
%
% style (optional): 'full' (default) -> "Mouse 5a"; 'short' -> "M5a" (cramped ticks).
%
% INPUT  sessList  struct array / cell of structs with .mn/.td/.en (or .label / .sess_tag),
%                  or a cell/string array of session strings understood by paper_session_label.
%                  A bare mouse name ('AL_0041') gives the mouse-only label ("Mouse 5"), which is
%                  right for per-mouse panels; it errors if that mouse repeats in the list.
% OUTPUT labs      cell array of char labels, same length and order as the input.

if nargin < 2 || isempty(style), style = 'full'; end
if isstruct(sessList), sessList = num2cell(sessList); end
if isstring(sessList), sessList = cellstr(sessList); end
n = numel(sessList);
labs = cell(n, 1);  mouseOnly = false(n, 1);
for i = 1:n
    [labs{i}, info] = paper_session_label(sessList{i}, style);
    mouseOnly(i) = strcmp(info.role, 'mouse') && info.nSess > 1;
end
for i = find(mouseOnly)'
    if nnz(strcmp(labs, labs{i})) > 1
        error('imp_mouse_label:needSession', ...
            '"%s" repeats without a date: pass session structs (.mn/.td/.en) instead of mouse names.', labs{i});
    end
end
end
