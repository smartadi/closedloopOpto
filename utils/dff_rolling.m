function [dFk, Fbase] = dff_rolling(Fabs, w)
%DFF_ROLLING  Trailing rolling-baseline dF/F, in percent.
%
%   dFk = dff_rolling(Fabs, w)      % w = baseline length in SAMPLES
%   [dFk, Fbase] = dff_rolling(...) % also return the baseline itself
%
%   dFk(t) = (Fabs(t) - mean(Fabs(t-w+1 : t))) / mean(...) * 100
%
% WHY THIS EXISTS (2026-10-01). Two reasons.
%
% 1. getpixel_dFoF.m mode 0 computes this inline, and its edge handling is
%    WRONG: it pads with `ones(1,w)`, i.e. the literal number 1.0, while Fabs
%    is raw fluorescence in the hundreds-to-thousands. For the first w samples
%    the "baseline" is therefore mostly 1.0 and dF/F explodes -- measured up to
%    74,303 % across the thirteen mode-0 sessions. It has never affected a
%    published number only because every session's first trial window starts
%    more than w samples in (tightest: m11 at sample 1950 vs w = 1399). This
%    function pads with Fabs(1) instead, so the lead-in is merely imprecise
%    rather than catastrophic.
%
% 2. The two new sessions (m14 AL_0048, m15 AL_0051) were built with mode 1,
%    which is `F / meanImage * 100` and applies NO rolling baseline, so they
%    retained 2-10x more slow drift than the other thirteen. This function
%    puts them on the same definition.
%
% EQUIVALENCE NOTE. Inside the analysis region (sample index > w) this is
% bit-for-bit the same estimator as mode 0 -- a plain trailing boxcar. The
% padding differs only over the first w samples, which no trial window reads.
% So applying this to the thirteen existing sessions would not move any
% published number; it is the new sessions that change.
%
% See also: getpixel_dFoF, build_trials.

Fabs = double(Fabs(:))';
T    = numel(Fabs);

assert(isscalar(w) && w >= 1 && w == fix(w), 'dff_rolling:w', ...
       'w must be a positive integer number of samples.');
assert(T > w, 'dff_rolling:short', ...
       'Trace (%d samples) must be longer than the baseline window (%d).', T, w);
assert(all(isfinite(Fabs)), 'dff_rolling:nonfinite', ...
       'Fabs contains non-finite values.');
assert(min(Fabs) > 0, 'dff_rolling:sign', ...
       ['Fabs must be ABSOLUTE fluorescence (strictly positive); got min %.3f. ' ...
        'SVD-reconstructed traces are mean-subtracted -- add the mean image ' ...
        'value back before calling.'], min(Fabs));

% Pad with the first sample, not with 1.0: the baseline then starts at the
% trace's own level and the lead-in degrades gracefully instead of exploding.
pad  = repmat(Fabs(1), 1, w - 1);
Fk   = [pad, Fabs];
cs   = [0, cumsum(Fk)];
i    = 1:T;
Fbase = (cs(i + w) - cs(i)) / w;

dFk = (Fabs - Fbase) ./ Fbase * 100;
end
