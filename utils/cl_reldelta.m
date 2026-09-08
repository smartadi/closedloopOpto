function [rel, comp] = cl_reldelta(P_l, onsetCol, Fs, opts)
% CL_RELDELTA  Canonical closed-loop spectral STATE = relative 2-4 Hz power.
%
% This is the PRIMARY closed-loop delta definition across all CL analyses
% (user decision 2026-09-08). It is the exact predictor `Xrel` from
% cl_rmse_factor_windows.m, extracted so every CL script computes the state
% the same way instead of each rolling its own (the precomputed normalized
% `wcFreqSpec` path is a DIFFERENT measure and must not be mixed in).
%
%   rel(t) = bandpow(seg_t, hi) / bandpow(seg_t, tot)
%
% where seg_t is the buffered readout trace of trial t over the window
% [-pre, +post] s around onset, and bandpow = linear-detrend -> Hann window
% -> one-sided periodogram -> sum of |FFT|^2 in [lo,hi). Numerator band is the
% "hard-to-control" 2-4 Hz sub-band; denominator is total 0.4-10 Hz power, so
% the ratio is power-INDEPENDENT (survives the 2026-07-01 signal-power control).
%
% INPUTS
%   P_l      trials x time buffered trace. Closed loop: d.pwcDfk_l. Open loop:
%            d.pncDfk_l. (Both are present for all 15 controller sessions.)
%   onsetCol onset column in P_l. For the *_l buffers this is 106 (=c0_l).
%   Fs       sample rate, Hz (controller = 35).
%   opts     (optional) struct:
%     .pre   window start before onset, s      (default 2)
%     .post  window end after onset,   s        (default 3 = stim end; dur=3)
%            --> set .post = 0 for a PRE-STIM-ONLY window (avoids the state
%                overlapping the outcome window in state-dependence analyses).
%     .hi    numerator band, Hz  (default [2 4])
%     .tot   denominator band, Hz (default [0.4 10])
%
% OUTPUTS
%   rel   nTrials x 1 relative 2-4 Hz power (NaN for all-NaN/short segments).
%   comp  struct with the absolute sub-band powers used, per trial:
%           .hipow (2-4 Hz), .totpow (0.4-10 Hz), .delta (1-4 Hz abs),
%           .slow (0.4-1 Hz abs) -- the "other definitions", kept as secondary.
%
% See also cl_rmse_factor_windows, ctrl_distrej_quartiles, ctrl_distrej_statedep.

if nargin < 4 || isempty(opts), opts = struct; end
if ~isfield(opts,'pre'),  opts.pre  = 2;        end
if ~isfield(opts,'post'), opts.post = 3;        end
if ~isfield(opts,'hi'),   opts.hi   = [2 4];    end
if ~isfield(opts,'tot'),  opts.tot  = [0.4 10]; end
delta_bnd = [1 4]; slow_bnd = [0.4 1];   % secondary definitions

nT = size(P_l,1);
sa = onsetCol - round(opts.pre*Fs);
sb = onsetCol + round(opts.post*Fs);
rel   = nan(nT,1);
hipow = nan(nT,1); totpow = nan(nT,1); dpow = nan(nT,1); spow = nan(nT,1);

if sa < 1 || sb > size(P_l,2)
    warning('cl_reldelta:window','window [%d,%d] out of trace range [1,%d]; clamping.', ...
        sa, sb, size(P_l,2));
    sa = max(1,sa); sb = min(size(P_l,2),sb);
end

for t = 1:nT
    seg = double(P_l(t, sa:sb));
    if all(isnan(seg)) || numel(seg) < 8, continue; end
    tot = bp(seg, Fs, opts.tot(1), opts.tot(2));
    hipow(t)  = bp(seg, Fs, opts.hi(1),  opts.hi(2));
    totpow(t) = tot;
    dpow(t)   = bp(seg, Fs, delta_bnd(1), delta_bnd(2));
    spow(t)   = bp(seg, Fs, slow_bnd(1),  slow_bnd(2));
    rel(t)    = hipow(t) / max(tot, eps);
end

comp = struct('hipow',hipow,'totpow',totpow,'delta',dpow,'slow',spow);
end

% ---- band power: linear-detrend, Hann, one-sided periodogram (== cl_rmse_factor_windows local_bandpow)
function p = bp(seg, Fs, lo, hi)
    seg = detrend(seg(:).','linear'); N = numel(seg);
    w = hann(N).'; P = abs(fft(seg.*w)).^2; P = P(1:floor(N/2)+1);
    fr = (0:floor(N/2))*Fs/N; p = sum(P(fr>=lo & fr<hi));
end
