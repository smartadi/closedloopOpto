function art_cell = build_onset_artifact(nAmp, nzMask, imp_data, t_full, X_cp_m, ...
    nPred, pre_f, post_f, nF_m, spont_ref, spont_offset_f)
% Returns art_cell{ia}: [(pre_f+post_f) x nPred] onset-locked contra SVD
% artifact per amplitude, with optional spontaneous-reference subtraction.
%
% spont_ref modes:
%   'none'            (original) — subtract pre-stim MEAN only.
%
%   'shifted_window'  (Option C) — also compute a matched spontaneous window
%                     shifted spont_offset_f frames (~20 s) before each onset,
%                     average across trials, and subtract from the stim average.
%                     Result = stim-specific component only, with background
%                     contra dynamics (hemodynamic trends, arousal fluctuations
%                     correlated with trial timing) removed.
%
%   'detrend'         — fit a line to each mode's pre-stim window per trial
%                     and extrapolate into the stim window. Removes slow
%                     per-trial drift. Complementary to 'shifted_window'.
%
% Args:
%   nAmp, nzMask, imp_data, t_full, X_cp_m, nPred, pre_f, post_f, nF_m
%   spont_ref        string, optional, default 'shifted_window'
%   spont_offset_f   frames to shift back for spontaneous window,
%                    default 700 (~20 s at 35 Hz). Verify against actual ITI.

if nargin < 10 || isempty(spont_ref);    spont_ref      = 'shifted_window'; end
if nargin < 11 || isempty(spont_offset_f); spont_offset_f = 700; end   % ~20 s

use_shifted = strcmp(spont_ref, 'shifted_window');
use_detrend = strcmp(spont_ref, 'detrend');

nWin = pre_f + post_f;

% Pre-build design matrices for detrend mode
t_pre_col = (0:pre_f-1)';
A_pre     = [t_pre_col, ones(pre_f, 1)];
t_win_col = (0:nWin-1)';
A_win     = [t_win_col, ones(nWin,  1)];

art_cell = cell(nAmp, 1);

for ia = 1:nAmp
    art_cell{ia} = zeros(nWin, nPred);
    if ~nzMask(ia); continue; end
    starts = imp_data.startTimes{ia}(:);

    stim_sum  = zeros(nWin, nPred);  nval_st = 0;
    spont_sum = zeros(nWin, nPred);  nval_sp = 0;

    for j = 1:numel(starts)
        [~, ion] = min(abs(t_full - starts(j)));

        % ── Stim window ──────────────────────────────────────────────────────
        i0 = ion - pre_f;  i1 = ion + post_f - 1;
        if i0 < 1 || i1 > nF_m; continue; end
        chunk = X_cp_m(i0:i1, 1:nPred);

        if use_detrend
            coeff    = A_pre \ chunk(1:pre_f, :);
            expected = A_win * coeff;
        else
            bl       = mean(chunk(1:pre_f, :), 1, 'omitnan');
            expected = repmat(bl, nWin, 1);
        end
        stim_sum  = stim_sum  + (chunk - expected);
        nval_st   = nval_st + 1;

        % ── Spontaneous reference window (shifted back) ───────────────────────
        if use_shifted
            i0_sp = i0 - spont_offset_f;
            i1_sp = i1 - spont_offset_f;
            if i0_sp < 1 || i1_sp > nF_m; continue; end
            chunk_sp = X_cp_m(i0_sp:i1_sp, 1:nPred);
            bl_sp    = mean(chunk_sp(1:pre_f, :), 1, 'omitnan');
            spont_sum = spont_sum + (chunk_sp - bl_sp);
            nval_sp   = nval_sp + 1;
        end
    end

    stim_mean = stim_sum / max(nval_st, 1);

    if use_shifted && nval_sp > 0
        art_cell{ia} = stim_mean - spont_sum / nval_sp;
        if nval_sp < nval_st
            fprintf('[build_onset_artifact] amp %d: %d/%d trials had valid spont window\n', ...
                ia, nval_sp, nval_st);
        end
    else
        art_cell{ia} = stim_mean;
    end
end

fprintf('[build_onset_artifact] mode=''%s''  spont_offset=%d frames  %d amps\n', ...
    spont_ref, spont_offset_f, nAmp);
end
