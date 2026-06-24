function explained_var = sseExplainedCal(signals, predicted_signals)
% sseExplainedCal  Fraction of variance explained, per channel (row).
%
% EXTERNAL DEPENDENCY — vendored verbatim from Ye et al. 2023 spirals:
%   spirals_mirror/utils/sseExplainedCal.m
% Used by contra_prediction.m [CP-HEMI] to reproduce Zhiwen Ye's R²-vs-rank
% metric. Pass row vectors (1 x N) for a single pooled value across all
% channels/time; pass [channel x tsample] for a per-channel column.
%
% signals          = channel x tsample
% predicted_signals = channel x tsample
sse_residual = sum((signals - predicted_signals).^2,2);
sse_total    = sum((signals - nanmean(signals,2)).^2,2);
explained_var = 1 - (sse_residual./sse_total);
end
