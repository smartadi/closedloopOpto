function [suffix, mode] = ctrl_pred_tag()
%CTRL_PRED_TAG  Which contra->ipsi predictor is in force, and the cache suffix it writes to.
%
%   PROJECT MODEL: 'ridge'. Decided 2026-08-12 (user: "keep ridge only") after the three-way
%   comparison. Ridge is the only one of the three that is fully STIM-BLIND -- neither the fit nor
%   the lambda selection ever sees a stim trial -- and every bias it leaves points AWAY from the
%   conclusions: its residual leak understates Local and understates rejection, so a claim made on
%   ridge can only get stronger under correction. The other two remain reachable for reverts and
%   for the robustness lines already in RESEARCH, but nothing new should be built on them.
%
%   THE REVERT SWITCH. Set the base-workspace variable CTRL_PRED:
%     'rank'   RETIRED. Pixel selection: keep the K least-affected contra px, K by ctrl_select_k.
%              Byte-identical to everything built before 2026-08-12. Caches:
%                 ctrl_ols_ol_stimblind_<tag>.mat
%     'ridge'  keep the WHOLE grid, shrink the weights, lambda chosen stim-blind from catch
%              windows (utils/ctrl_ridge_path.m). Caches:
%                 ctrl_ols_ol_stimblind_ridge_<tag>.mat
%     'deflate' RETIRED. Ridge PLUS one linear equality constraint: the weights are forced
%              orthogonal to the measured contralateral stim-response direction, so the predictor
%              cannot transmit the stimulus (utils/ctrl_deflate.m). Caches:
%                 ctrl_ols_ol_stimblind_deflate_<tag>.mat
%              RETIRED BECAUSE it is not stim-blind: the constraint direction d is measured on
%              laser-on trials, so its flat Global and 100% Local are the constraint restated, not
%              a measurement. It survives only as the ROBUSTNESS bracket already banked in
%              RESEARCH 2026-08-12: the CL/OL rejection contrast moves 0.682 -> 0.697 (signrank
%              p = 0.305, CL better 13/13 under both), so the contrast the paper rests on is
%              model-independent even though the absolute ER level is not.
%
%   The three write to DIFFERENT files on purpose, so the retired models stay on disk and a revert
%   is one variable rather than a rebuild. No mode ever overwrites another mode's caches.
%
%   Every script that reads or writes a Stage-2 cache must route its filename through here, or
%   the two models will silently mix -- a 'ridge' Global scored against a 'rank' decomposition
%   is not a comparison of anything.

mode = 'ridge';          % PROJECT DEFAULT since 2026-08-13. Was 'rank'.
try
    v = evalin('base','CTRL_PRED');
    if ~isempty(v) && (ischar(v) || isstring(v)); mode = lower(char(v)); end
catch
    % not set in base -> default. (Also the path taken inside functions/parfor.)
end
switch mode
    case 'rank',    suffix = '';
    case 'ridge',   suffix = '_ridge';
    case 'deflate', suffix = '_deflate';
    otherwise
        error(['ctrl_pred_tag: CTRL_PRED must be ''rank'', ''ridge'' or ''deflate'' ' ...
               '(got ''%s'').'], mode);
end
end
