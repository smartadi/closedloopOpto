function [suffix, mode] = ctrl_pred_tag()
%CTRL_PRED_TAG  Which contra->ipsi predictor is in force, and the cache suffix it writes to.
%
%   THE REVERT SWITCH. Set the base-workspace variable CTRL_PRED:
%     'rank'   (default) pixel selection: keep the K least-affected contra px, K by ctrl_select_k.
%              Byte-identical to everything built before 2026-08-12. Caches:
%                 ctrl_ols_ol_stimblind_<tag>.mat
%     'ridge'  keep the WHOLE grid, shrink the weights, lambda chosen stim-blind from catch
%              windows (utils/ctrl_ridge_path.m). Caches:
%                 ctrl_ols_ol_stimblind_ridge_<tag>.mat
%     'deflate' ridge PLUS one linear equality constraint: the weights are forced orthogonal to
%              the measured contralateral stim-response direction, so the predictor cannot
%              transmit the stimulus (utils/ctrl_deflate.m). Caches:
%                 ctrl_ols_ol_stimblind_deflate_<tag>.mat
%              WHY: across 13 sessions the Global leak is predicted by ONE scalar -- the
%              alignment b'*dip of the weights with the per-pixel co-suppression pattern
%              (Spearman -0.91 with leak%, 0.89 with the Global trough), while ||b|| manages
%              only 0.51. Shrinkage was an indirect handle on the right quantity; this is the
%              direct one. RESEARCH 2026-08-12.
%
%   The two write to DIFFERENT files on purpose, so both models coexist on disk and switching
%   back is one variable rather than a rebuild. Nothing the 'rank' model produced is ever
%   overwritten by the 'ridge' model.
%
%   Every script that reads or writes a Stage-2 cache must route its filename through here, or
%   the two models will silently mix -- a 'ridge' Global scored against a 'rank' decomposition
%   is not a comparison of anything.

mode = 'rank';
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
