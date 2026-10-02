function [idx, w] = trialwin(arrName, tspan, dur, Fs)
%TRIALWIN  Resolve a time span in seconds to column indices, or error.
%
%   idx = trialwin('dfk',    [0 3],  dur)   % stimulation window in dfk
%   idx = trialwin('motion', [-2 3], dur)   % motion baseline through trial end
%   [idx, w] = trialwin(...)                % also return that array's geometry
%
% WHY THIS EXISTS (2026-10-01). Every window in this project used to be written
% as literal column numbers (c0=36, c0_mot=71, c0_l=106, c0_p=351, c1=71,
% c2=141, "cols 142:end", "1:3*Fs"). Two failure modes followed:
%
%   1. The wrong onset applied to the wrong array. dfk and motion are both 176
%      columns at dur = 3 but their onsets differ by 35 samples, so the mistake
%      produces a plausible-looking result shifted by one second.
%   2. SILENT CLAMPING. The idiom max(1, c0-k) : min(end, c0+m) does not fail
%      when the request exceeds the array -- it quietly returns a shorter
%      window, and the resulting average is computed over the wrong interval.
%      This is how the Fig-3 panel-H "3 s post-stimulation" window came to be
%      about 1 s without anyone noticing.
%
% This function refuses both: it looks the onset up by array name, and it
% ERRORS rather than clamps when the span does not fit. If you want clamping,
% ask for it explicitly by intersecting the result yourself.
%
% See also: trial_windows (the geometry), onset_provenance_audit.

if nargin < 4 || isempty(Fs), Fs = 35; end
W = trial_windows(dur, Fs);

assert(ischar(arrName) || isstring(arrName), 'trialwin:name', ...
       'arrName must be a char or string.');
arrName = char(arrName);
assert(isfield(W, arrName) && ismember(arrName, W.names), 'trialwin:unknownArray', ...
       'Unknown array "%s". Known: %s.', arrName, strjoin(W.names, ', '));
w = W.(arrName);

assert(numel(tspan) == 2 && all(isfinite(tspan)) && tspan(2) > tspan(1), ...
       'trialwin:span', 'tspan must be [t0 t1] seconds with t1 > t0.');

% Round rather than floor/ceil so a window is never silently biased one way.
i0 = w.onset_col + round(tspan(1) * Fs);
i1 = w.onset_col + round(tspan(2) * Fs);

if i0 < 1 || i1 > w.n
    error('trialwin:outOfRange', ...
        ['Window [%g %g] s does not fit in "%s": that array spans %g to %g s ' ...
         '(%d columns, onset at %d), and the request needs columns %d:%d. ' ...
         'Use a wider array (%s) or a narrower span -- do not clamp.'], ...
        tspan(1), tspan(2), arrName, w.t_first, w.t_last, w.n, w.onset_col, ...
        i0, i1, strjoin(setdiff(W.names, {arrName}), ', '));
end

idx = i0:i1;
end
