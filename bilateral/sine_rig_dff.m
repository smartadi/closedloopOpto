function y = sine_rig_dff(sess)
%SINE_RIG_DFF  The rig's online dF/F for a bilateral sine session, on the ROW clock of onset_idx / ref_raw.
%   y = sine_rig_dff(sess)   sess = one entry of `sessions` from load_bilateral.m; y is a row vector, numel(timeBlue).
%
%   states.csv row k holds frame k-1's 40 s trailing dF/F at the controlled (right) pixel: the signal the PI fed
%   back on (error.csv = states + reference). Indexing y with the same row i0 as ref_raw(i0) therefore gives the
%   rig's own pairing, which ctrl_mpc_sine_export uses for Fig 6. Controller figures score this signal (CLAUDE.md:
%   the controller's dF/F is the trailing 40 s one), not the F/meanImage trace in sess.right.dFoF.
%   Rows before W_BASE + 1 are the rig's baseline warm-up; callers skip trials that reach into them.
%   The CSV is read from the server once and cached in data/sine_states_<mn>_<mmdd><en>.mat.
%   Check: states(k+1) must match the offline 40 s trailing dF/F of sess.right.dFoF at frame k best at lag 0.
W_BASE = 1400;                                        % d.params.horizon, 40 s at 35 Hz
root = fileparts(fileparts(mfilename('fullpath')));
cp = fullfile(root, 'data', sprintf('sine_states_%s_%s%s%d.mat', sess.mn, sess.td(6:7), sess.td(9:10), sess.en));
if exist(cp, 'file')
    tmp = load(cp); states = tmp.states;
else
    sr = expPath(sess.mn, sess.td, sess.en);
    states = reshape(readmatrix(fullfile(sr, 'states.csv'), 'FileType', 'text', 'Delimiter', ' '), [], 1);
    save(cp, 'states', '-v7');
end
T = numel(sess.d.timeBlue);
assert(numel(states) > T, 'states.csv has %d rows for %d frames', numel(states), T);

% Checked on the scored sine-trial windows only: across the whole session the rig trace also holds its
% start-up transient (first ~1.5 min) and, in 2026-07-21/1, the excluded stationary block, which pull a
% session-wide r down to 0.4-0.7 although the trials agree at r ~ 0.99 (RESEARCH 2026-10-28).
yr = dff_rolling(100 + double(sess.right.dFoF(:)).', W_BASE); yr = yr(:);
tm = sess.trial_meta; on = sess.onset_idx([tm([tm.ff_cond] >= 0 & strcmp({tm.side}, 'right')).trial_idx]);
on = on(isfinite(on) & on - 1 > W_BASE + 1 & on + 141 < T);
ii = reshape(on(:) - 1 + (0:140), 1, []);             % frames of the scored windows
c = [corr(states(ii + 1), yr(ii - 1)), corr(states(ii + 1), yr(ii)), corr(states(ii + 1), yr(ii + 1))];
fprintf('[RIG-DFF] %s %s/%d: corr(states row k+1, offline trailing dF/F frame k), trial windows: lag -1 %.3f | 0 %.3f | +1 %.3f\n', ...
    sess.mn, sess.td, sess.en, c);
assert(c(2) > max(c([1 3])) && c(2) > 0.95, 'states.csv does not match the controlled pixel one row ahead');
y = states(1:T).';
end
