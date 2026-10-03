function W = f4_state_window(name)
%F4_STATE_WINDOW  The ONE definition of the Fig-4 state-measurement window.
%
%   W = f4_state_window('peri')    % DEFAULT, the paper window: -2 s to +3 s, all states
%   W = f4_state_window('legacy')  % reproduces Fig-4 numbers published before 2026-10-02
%   W = f4_state_window('pre2')    % diagnostic: -2 s to onset, strictly pre-stimulus
%   W = f4_state_window('pre1')    % diagnostic: -1 s to onset (= Fig 2's window)
%
% Returns sample-offset vectors RELATIVE TO THE ONSET COLUMN of each buffer:
%   W.spec   offsets for the spectral states (relative 2-4 Hz, absolute 1-4 Hz)
%   W.mot    offsets for the motion state
%   W.label  human-readable window, for printouts and captions
%   W.name   the key it was built from
% Use as  buf(:, onsetCol + W.spec)  and  motion(:, motOnsetCol + W.mot).
%
% THE WINDOW IS A DESIGN DECISION, NOT A DEFAULT (user, 2026-10-02):
%   Fig 4 evaluates controller PERFORMANCE under state, and performance over a trial is shaped
%   both by activity before the stimulus starts and by activity while it runs, up to stimulus
%   end at +3 s. So Fig 4 measures all its states over -2 s to +3 s -- a PERI-stimulus window,
%   and the text must call it that, not "pre-stimulus". (Fig 2 is different on purpose: an
%   impulse is a single-instant stimulus, so its states are strictly pre-stimulus, -1 s to
%   onset; that lives in impulse-analysis/imp_state_trialvar.m, not here.)
%   And motion, relative 2-4 Hz and absolute 1-4 Hz must use the SAME window.
%
% WHY 'peri' IS 175 SAMPLES, AND WHAT 'legacy' IS:
%   Before 2026-10-02 the three states were NOT on the same window. Motion used
%   onset-70..onset+104 (175 samples, -2.000..+2.971 s); the spectral states used
%   onset-70..onset+105 (176 samples, -2.000..+3.000 s) -- an off-by-one between two index
%   conventions in two different scripts. 'peri' puts all three on the half-open window
%   [-2, +3) = onset-70..onset+104 = 175 samples = exactly 5.0 s, which also gives the
%   periodogram an exact 0.2 Hz grid (35/175) instead of 0.199 Hz (35/176).
%   'legacy' keeps the old split, so the previously published numbers stay reproducible.
%
% The diagnostic pre windows end on the LAST SAMPLE BEFORE ONSET. Measured 2026-10-02: under
% them the Fig-4D motion effects vanish (ctrl p 0.0015 -> 0.27/0.40) and the rel-2-4 Hz story
% inverts, i.e. Fig 4's state effects are carried largely by during-trial activity -- which is
% the reason the paper window is peri-stimulus. See RESEARCH 2026-10-02.
%
% W.bandpow is the spectral ESTIMATOR that goes with the window (see utils/f4_bandpow.m):
% 'continuous' for every current window -- band edges exact and independent of N -- and
% 'bins' only for 'legacy', so the one switch reproduces the old numbers completely.
% 'peri_p1' / 'peri_m1' are +-1-sample diagnostics that exist to TEST that independence.
if nargin < 1 || isempty(name), name = 'peri'; end
name = validatestring(lower(char(name)), {'peri','legacy','pre2','pre1','peri_p1','peri_m1'}, ...
                      mfilename, 'name');
Fs = 35;
W.bandpow = 'continuous';
switch name
    case 'peri'
        W.spec  = -round(2*Fs) : round(3*Fs) - 1;     % -70 .. +104  (175 samples, [-2,+3))
        W.mot   = W.spec;                             % SAME window for every state
        W.label = '-2 s to +3 s, all states (peri-stimulus; paper window)';
    case 'legacy'
        W.spec  = -round(2*Fs) : round(3*Fs);         % -70 .. +105  (176 samples)
        W.mot   = -round(2*Fs) : round(3*Fs) - 1;     % -70 .. +104  (175 samples)
        W.bandpow = 'bins';
        W.label = '-2 s to +3 s, pre-2026-10-02 split (spectral 176 / motion 175, FFT bins)';
    case 'peri_p1'
        W.spec  = -round(2*Fs) : round(3*Fs);         % one sample LONGER (176)
        W.mot   = W.spec;
        W.label = 'diagnostic: paper window +1 sample';
    case 'peri_m1'
        W.spec  = -round(2*Fs) : round(3*Fs) - 2;     % one sample SHORTER (174)
        W.mot   = W.spec;
        W.label = 'diagnostic: paper window -1 sample';
    case 'pre2'
        W.spec  = -round(2*Fs) : -1;                  % -70 .. -1
        W.mot   = W.spec;
        W.label = '-2 s to onset (pre-stimulus diagnostic)';
    case 'pre1'
        W.spec  = -round(1*Fs) : -1;                  % -35 .. -1
        W.mot   = W.spec;
        W.label = '-1 s to onset (pre-stimulus diagnostic; Fig-2 window)';
end
W.name = name;
end
