function art_cell = build_onset_artifact(nAmp, nzMask, imp_data, t_full, X_cp_m, ...
    nPred, pre_f, post_f, nF_m, spont_ref)
% Returns art_cell{ia}: [(pre_f+post_f) x nPred] mean onset-locked contra SVD
% deviation for each amplitude, capturing only the stimulus-specific component.
%
% Baseline modes (spont_ref argument):
%   'none'    (default) — subtract pre-stim MEAN per trial. Removes DC offset
%             but leaves any pre-stim trend extrapolated into the stim window.
%
%   'detrend' (Option C) — fit a line to the pre-stim window per trial and
%             extrapolate it into the stim window. Subtracting this expected
%             spontaneous trajectory isolates the stim-driven deflection only,
%             removing slow hemodynamic/arousal drifts that are correlated with
%             trial timing but not caused by the stimulus.
%
% Args:
%   nAmp, nzMask, imp_data, t_full, X_cp_m, nPred, pre_f, post_f, nF_m
%       — same as before
%   spont_ref   string, optional, default 'none'

if nargin < 10 || isempty(spont_ref)
    spont_ref = 'none';
end

use_detrend = strcmp(spont_ref, 'detrend');

nWin = pre_f + post_f;
t_pre_col = (0:pre_f-1)';              % [pre_f x 1] time index for pre-stim fit
A_pre     = [t_pre_col, ones(pre_f,1)];% [pre_f x 2] design matrix
t_win_col = (0:nWin-1)';               % [nWin  x 1] time index for full window
A_win     = [t_win_col, ones(nWin,1)]; % [nWin  x 2]

art_cell = cell(nAmp, 1);

for ia = 1:nAmp
    art_cell{ia} = zeros(nWin, nPred);
    if ~nzMask(ia); continue; end
    starts = imp_data.startTimes{ia}(:);
    devsum = zeros(nWin, nPred);
    nval   = 0;

    for j = 1:numel(starts)
        [~, ion] = min(abs(t_full - starts(j)));
        i0 = ion - pre_f;
        i1 = ion + post_f - 1;
        if i0 < 1 || i1 > nF_m; continue; end

        chunk = X_cp_m(i0:i1, 1:nPred);   % [nWin x nPred]

        if use_detrend
            % Fit line to pre-stim portion of each mode, extrapolate forward.
            % coeff = [slope; intercept] per mode, [2 x nPred].
            coeff    = A_pre \ chunk(1:pre_f, :);
            expected = A_win * coeff;          % [nWin x nPred]
        else
            bl       = mean(chunk(1:pre_f, :), 1, 'omitnan');  % [1 x nPred]
            expected = repmat(bl, nWin, 1);    % [nWin x nPred]
        end

        devsum = devsum + (chunk - expected);
        nval   = nval + 1;
    end

    art_cell{ia} = devsum / max(nval, 1);
end
fprintf('[build_onset_artifact] mode=''%s''  %d amps processed\n', spont_ref, nAmp);
end
