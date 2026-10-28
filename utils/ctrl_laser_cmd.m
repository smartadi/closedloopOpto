function [u, t, name] = ctrl_laser_cmd(d)
% CTRL_LASER_CMD  The laser command channel that actually drove stimulation in a session.
%
%   [u, t, name] = ctrl_laser_cmd(d)
%
% The 2026-07 builds log three command channels (inpVals, inpVals594, inpVals638); inpVals is a
% copy of the 594 nm channel. AL_0048 2026-07-29/2 stimulated through 638 nm, so reading
% d.inpVals gave a flat ~0 V command for every trial (RESEARCH 2026-10-27, "BUG: AL_0048 laser
% command"). Rule (same as stats_v2/loader.py): the channel with the largest 99.9th percentile;
% a tie keeps the first of inpVals, inpVals594, inpVals638. Old builds only have inpVals.
% t is the matching time vector (inpTime594/638 equal inpTime in every session checked).
cands = {'inpVals', 'inpVals594', 'inpVals638'};
best = -inf;  name = 'inpVals';
for c = cands
    if ~isfield(d, c{1}), continue; end
    v = sort(d.(c{1})(:));
    p = v(max(1, ceil(0.999 * numel(v))));   % 99.9th percentile without the Statistics toolbox
    if p > best, best = p; name = c{1}; end
end
u = d.(name);
tn = strrep(name, 'Vals', 'Time');
if isfield(d, tn), t = d.(tn); else, t = d.inpTime; end
end
