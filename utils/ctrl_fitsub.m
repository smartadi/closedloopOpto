function [b, R2te, R2tr] = ctrl_fitsub(F, Su)
%CTRL_FITSUB  Dense ridge-stabilised OLS on a contra-pixel SUBSET, from a precomputed Gram.
%
%   Every candidate predictor set is a SUBSET of the same contra grid and the z-scoring is
%   per-pixel, so the normal equations for any subset are just submatrices of one Gram matrix.
%   Building that Gram once turns a threshold/K sweep from "a fresh pass over 60k frames per
%   candidate" into O(K^3) per candidate, which is what makes ctrl_select_k.m and the GUI sweep
%   feasible at all.
%
%   ALGEBRAICALLY IDENTICAL to ctrl_ols_ol_stimblind.m's direct fit -- same per-pixel z-score,
%   same 1e-6*mean(column energy) stabiliser, same train/test frames out of Stage 1. Only the
%   arithmetic route differs. (Lifted out of ctrl_affected_gui.m's local_fitsub_ 2026-08-10 so the
%   GUI, the K selector and Stage 2 cannot drift apart.)
%
% INPUT
%   F   Gram struct, built once per session (see ctrl_gram_build below for the exact contents):
%         .Gtr .ctr .sse0tr .sstr    train-block Gram / cross-term / SSE at b=0 / total SS
%         .Gte .cte .sse0te .sste    same for the held-out test block
%         .mu .sd .muY               the z-score and target offset the Gram was built under
%   Su  [K x 1] indices of the kept (predictor) pixels into the full grid
%
% OUTPUT
%   b     [K x 1] weights
%   R2te  held-out R^2   <- the number ctrl_r2_floor() gates on
%   R2tr  train R^2
%
% The R^2s come straight from the Gram identity
%   SSE(b) = SSE(0) - 2 b'c + b'G b
% so no frames are touched here.

Su = Su(:);
Gs = F.Gtr(Su,Su);
lam = 1e-6*mean(diag(Gs));
b = (Gs + lam*eye(numel(Su))) \ F.ctr(Su);
R2tr = 1 - (F.sse0tr - 2*(b.'*F.ctr(Su)) + b.'*Gs*b)        / max(F.sstr, eps);
R2te = 1 - (F.sse0te - 2*(b.'*F.cte(Su)) + b.'*F.Gte(Su,Su)*b) / max(F.sste, eps);
end
