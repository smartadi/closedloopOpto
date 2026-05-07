function heatmapClickCallback(src, ev, ud)
% ButtonDownFcn for Figure I spectral heatmap.
% ev.IntersectionPoint(2) = y in data coords = trial rank (1 = lowest MSE).
% ud fields: sorted_order, trial_idx, d, dFk, freq_spec, freqBandCtrs, freqOnsetBin, lbl

rank      = round(ev.IntersectionPoint(2));
rank      = max(1, min(rank, numel(ud.sorted_order)));

trial_pos = ud.sorted_order(rank);          % index into nc/wc trial array
stim_idx  = ud.trial_idx(trial_pos);        % index into d.stimStarts
freq_spec = squeeze(ud.freq_spec(trial_pos, :, :));   % W_freq × 20

plotSingleTrial(stim_idx, ud.d.timeBlue, ud.dFk, ud.d, ud.lbl, ...
                freq_spec, ud.freqBandCtrs, ud.freqOnsetBin);
end
