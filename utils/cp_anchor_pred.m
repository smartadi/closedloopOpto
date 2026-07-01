function [yhat_a, dc] = cp_anchor_pred(yact, yhat, win)
%CP_ANCHOR_PRED  Causal per-trial DC re-anchoring of a contra->ipsi prediction.
%
%   yhat_a = CP_ANCHOR_PRED(yact, yhat, win) shifts the prediction by a single
%   constant so it matches the actual trace's mean over the anchor window WIN:
%       dc     = mean(yact(win) - yhat(win))
%       yhat_a = yhat + dc
%
%   The whole-hemisphere readout has NO intercept and its contra regressors are
%   z-scored over the entire block, so the prediction's absolute DC level drifts
%   per segment/trial (slow bleaching / slow-state level shifts the contra modes
%   don't carry). That uncalibrated offset is what drives per-segment raw R^2
%   negative even when the shape is right -- and, untreated, would inject a spurious
%   baseline into the stim residual (= actual - prediction = local stim effect).
%
%   WIN must be a CAUSAL window (indices into the trace) that contains no
%   stim-driven signal: a lead-in for spontaneous segments, or the PRE-STIM
%   baseline for stim trials. Anchoring on the pre-stim baseline makes
%   residual = yact - yhat_a the pure local response, with no DC contamination.
%   Default WIN = whole trace (equivalent to mean-matching).
%
%   See cp_residual_core (stim residual) and contra_prediction [CP-HEMI].

if nargin < 3 || isempty(win), win = 1:numel(yact); end
dc     = mean(yact(win) - yhat(win), 'omitnan');
yhat_a = yhat + dc;
end
