function plotSingleTrial(stim_idx, t, dFk, d, lbl, freq_spec, freqBandCtrs, freqOnsetBin)
% Plot dFk, motion (if available), input, and optionally spectrogram for one trial.
% stim_idx     : index into d.stimStarts
% t            : d.timeBlue
% dFk          : pixel dF/F trace (1 x T)
% d            : session struct
% lbl          : 'OL' or 'CL'
% freq_spec    : (optional) W_freq x 20 per-trial spectrogram from ncFreqSpec/wcFreqSpec
% freqBandCtrs : (optional) 1x20 band centres (Hz)
% freqOnsetBin : (optional) onset bin index within freq_spec (default 7)

if nargin < 6;  freq_spec    = [];  end
if nargin < 7;  freqBandCtrs = [];  end
if nargin < 8;  freqOnsetBin = 7;   end

hasSpec = ~isempty(freq_spec);

tt  = d.inpTime;
v   = d.inpVals;
dur = d.params.dur;

[~, i]  = min(abs(t  - d.stimStarts(stim_idx)));
[~, k]  = min(abs(tt - d.stimStarts(stim_idx)));
[~, k2] = min(abs(tt - d.stimEnds(stim_idx)));

pre = 3;
i0  = max(1,          i - pre*35);
i1  = min(numel(dFk), i + 35*(dur + pre));
Tout = (-pre : 1/35 : dur+pre);
Tout = Tout(1 : i1-i0+1);

hasMot = isfield(d, 'motion') && numel(d.motion) >= i1;
nRows  = 2 + hasMot + hasSpec;

fig = figure('Color','w');
fig.Units    = 'inches';
fig.Position = [2, 2, 5, 1.5*nRows + 0.5];

r = 0;

% Row 1 — dF/F trace
r = r + 1;
subplot(nRows, 1, r); hold on;
plot(Tout, dFk(i0:i1), 'LineWidth', 1.5);
plot(Tout, -5*ones(size(Tout)), '--k', 'LineWidth', 1);
xline(0, 'k'); xline(dur, 'k');
xlim([-pre, dur+pre]);
ylabel('dF/F'); box off;
title(sprintf('Trial %d  |  %s  |  %s %s e%d', ...
    stim_idx, lbl, d.mn, d.td, d.en), 'Interpreter','none', 'FontSize', 9);

% Row 2 — motion (optional)
if hasMot
    r = r + 1;
    subplot(nRows, 1, r); hold on;
    plot(Tout, d.motion(i0:i1), 'k', 'LineWidth', 1.2);
    xline(0, 'k'); xline(dur, 'k');
    xlim([-pre, dur+pre]);
    ylabel('Motion'); box off;
end

% Row 3 (or 2) — input
r = r + 1;
subplot(nRows, 1, r); hold on;
plot(tt(k:k2) - tt(k), v(k:k2), 'LineWidth', 1.5);
xline(0, 'k'); xline(dur, 'k');
xlim([-pre, dur+pre]);
ylabel('Input');
if ~hasSpec; xlabel('Time (s)'); end
box off;

% Row 4 (or 3) — spectrogram
if hasSpec
    r = r + 1;
    W_freq = size(freq_spec, 1);
    t_spec = (0:W_freq-1) - (freqOnsetBin - 1);   % seconds from onset
    subplot(nRows, 1, r);
    imagesc(t_spec, freqBandCtrs, freq_spec');     % [20 x W_freq]
    set(gca, 'YDir','normal');
    hold on;
    xline(0,   'w', 'LineWidth', 1.5);
    xline(dur, 'w', 'LineWidth', 1.5);
    xlim([-pre, dur+pre]);
    xlabel('Time (s)'); ylabel('Freq (Hz)');
    colormap(gca, 'hot'); box off;
end
end
