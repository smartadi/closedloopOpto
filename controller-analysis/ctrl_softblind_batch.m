% ctrl_softblind_batch.m -- run SOFT-BLIND across sessions and tabulate feasibility.  [SOFTBATCH]
%
% For each session it runs Stage-2 (ctrl_ols_ol_stimblind.m) under CTRL_PRED='softblind' with the
% RECOMMENDED op-point rule SOFT_MODE='r2budget' (blind as hard as the R^2 floor allows). Each run
% saves its own ctrl_ols_ol_stimblind_softblind_<sess>.mat cache; this driver additionally collects a
% one-row-per-session FEASIBILITY TABLE:
%
%   ridgeR2   held-out spont R^2 with NO blinding (leakW=0)      -- the ceiling
%   opR2      held-out spont R^2 at the deployed op point         -- what we pay
%   cost      ridgeR2 - opR2                                      -- R^2 given up to blind
%   leakAll   d'b/d'b_free at op point, fit on ALL trials         -- optimistic leak
%   leakHold  d'b/d'b_free at op point, d fit on ODD/scored EVEN  -- HONEST leak (circularity guard)
%   feas      any curve point clears the R^2 floor                -- is the session usable at all
%   frac      leak fraction the op point targets (1=ridge .. 0=deflate)
%
% USAGE (single evaluate call so base vars reach run()):
%   BATCH_LIST=1:13; CTRL_PRED='softblind'; run('controller-analysis/ctrl_softblind_batch.m');
% Subset:  BATCH_LIST=[2 3 11];  ...
% Partial batches are safe: every finished session leaves a cache on disk.

if ~exist('BATCH_LIST','var') || isempty(BATCH_LIST); BATCH_LIST = 1:13; end
CTRL_PRED = 'softblind';                                   % force the mode for ctrl_pred_tag
if ~exist('SOFT_MODE','var') || isempty(SOFT_MODE); SOFT_MODE = 'minleak'; end

here_b  = fullfile(fileparts(mfilename('fullpath')));
if isempty(here_b); here_b = fullfile(pwd,'controller-analysis'); end
tgt_b   = fullfile(here_b,'ctrl_ols_ol_stimblind.m');
r2floor_b = ctrl_r2_floor();

SB = struct('selField',{},'sess',{},'ridgeR2',{},'opR2',{},'cost',{}, ...
            'leakAll',{},'leakHold',{},'feas',{},'frac',{});
fprintf('\n================ SOFT-BLIND BATCH (mode=%s, R^2 floor=%.2f) ================\n', ...
        SOFT_MODE, r2floor_b);

for si = BATCH_LIST(:).'
    BATCH_selField = si;
    fprintf('\n---- [SOFTBATCH] session index %d ----\n', si);
    try
        run(tgt_b);
        S = RPATH.SOFT;  k = S.sel_idx;
        row = struct('selField',si,'sess',sess_tag, ...
                     'ridgeR2',S.R2te_free,'opR2',S.R2te(k),'cost',S.R2te_free-S.R2te(k), ...
                     'leakAll',S.leak_all(k),'leakHold',S.leak_hold(k), ...
                     'feas',logical(S.feasible),'frac',S.sel_frac);
    catch ME
        fprintf(2,'[SOFTBATCH] selField %d FAILED: %s\n', si, ME.message);
        row = struct('selField',si,'sess','(error)','ridgeR2',NaN,'opR2',NaN,'cost',NaN, ...
                     'leakAll',NaN,'leakHold',NaN,'feas',false,'frac',NaN);
    end
    SB(end+1) = row; %#ok<SAGROW>
end

% ---- feasibility table -------------------------------------------------------
fprintf('\n================ FEASIBILITY TABLE (mode=%s) ================\n', SOFT_MODE);
fprintf('%-4s %-22s %7s %7s %6s %8s %8s %5s %6s\n', ...
        'idx','session','ridgeR2','opR2','cost','leakAll','leakHold','feas','frac');
for i = 1:numel(SB)
    r = SB(i);
    fprintf('%-4d %-22s %7.3f %7.3f %6.3f %8.2f %8.2f %5d %6.2f\n', ...
        r.selField, r.sess, r.ridgeR2, r.opR2, r.cost, r.leakAll, r.leakHold, r.feas, r.frac);
end
nFeas = sum([SB.feas]);
fprintf('\n[SOFTBATCH] %d/%d sessions feasible (ridge clears R^2 floor %.2f).\n', ...
        nFeas, numel(SB), r2floor_b);

save(fullfile(here_b,'data','ctrl_softblind_batch_summary.mat'),'SB','r2floor_b','SOFT_MODE');
fprintf('[SOFTBATCH] summary -> controller-analysis/data/ctrl_softblind_batch_summary.mat\n');
