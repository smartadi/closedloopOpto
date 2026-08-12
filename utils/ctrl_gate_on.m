function on = ctrl_gate_on()
%CTRL_GATE_ON  Single switch for the R^2 admission gate across every cross-session batch.
%
% `ctrl_r2_floor` says WHERE the floor is; this says WHETHER it is applied. They were previously
% tangled together in a per-script `USE_GATE = true` constant, so turning the gate off meant
% editing four scripts and remembering to put them all back.
%
% DEFAULT: OFF (user instruction, 2026-08-12 -- "make it for all dont reject any"). Every session
% that has a Stage-2 cache is reported.
%
% Override from the base workspace, no file edits:
%   CTRL_GATE = true;    % re-arm the 0.85 floor
%   CTRL_GATE = false;   % report every session
%
% ⚠ WHAT OFF MEANS. The floor exists because a Global prediction that is itself poor hands its own
% error to Local, so Local stops being "what the laser did" and becomes "what the laser did plus
% whatever the predictor got wrong". Ungated aggregates are therefore diagnostic: legitimate for
% looking at all sessions side by side, not for a reported number, unless the per-session R^2 is
% carried alongside so a reader can see which sessions are weak. f4_reject_panels stamps UNGATED
% on its panels for exactly this reason rather than refusing to draw them.
%
% See also CTRL_R2_FLOOR.

on = false;                                   % project default: report every session
if evalin('base','exist(''CTRL_GATE'',''var'')')
    v = evalin('base','CTRL_GATE');
    if ~isempty(v); on = logical(v); end
end
end
