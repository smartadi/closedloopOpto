function [y, tt, cols] = tq(T, cond, sig, tspan)
%TQ  Query a unified trial struct by TIME, not by column index.
%
%   y          = tq(T, 'cl', 'dfk', [-1 4])    % trials x samples, -1..+4 s
%   [y, tt]    = tq(T, 'ol', 'motion', [-2 0]) % tt = matching time vector
%   [y,~,cols] = tq(...)                       % the column indices used
%
% This is the whole point of the restructure: no call site should ever again
% contain a bare column number like 36, 71, 106, 351 or an idiom like
% "cols 142:end". Ask for seconds; the struct knows where its onset is.
%
% Errors rather than clamps when the span exceeds the stored grid, and the
% message says what the grid actually covers -- silent clamping is how the
% Fig-3 panel-H "3 s post-stimulation" window came to be about 1 s.
%
% See also: build_trials, trial_windows, trialwin.

assert(isstruct(T) && isfield(T,'onset_col') && isfield(T,'fs'), 'tq:badStruct', ...
       'T must come from build_trials.');

cond = lower(char(cond));
assert(isfield(T, cond), 'tq:cond', ...
       'Unknown condition "%s". Known: ol, cl.', cond);

sig = lower(char(sig));
assert(isfield(T.(cond), sig), 'tq:signal', ...
       'Unknown signal "%s". Known: %s.', sig, strjoin(T.signals, ', '));

assert(numel(tspan) == 2 && all(isfinite(tspan)) && tspan(2) > tspan(1), ...
       'tq:span', 'tspan must be [t0 t1] seconds with t1 > t0.');

% Round rather than floor/ceil so a window is never silently biased one way.
c0 = T.onset_col + round(tspan(1) * T.fs);
c1 = T.onset_col + round(tspan(2) * T.fs);

if c0 < 1 || c1 > T.n
    error('tq:outOfRange', ...
        ['Span [%g %g] s does not fit: this struct covers %g to %g s ' ...
         '(%d columns, onset at %d) and the request needs columns %d:%d. ' ...
         'Rebuild with a wider span -- do not clamp.'], ...
        tspan(1), tspan(2), T.t(1), T.t(end), T.n, T.onset_col, c0, c1);
end

cols = c0:c1;
y    = T.(cond).(sig)(:, cols);
tt   = T.t(cols);
end
