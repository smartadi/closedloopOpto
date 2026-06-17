function art_cell = build_onset_artifact(nAmp, nzMask, imp_data, t_full, X_cp_m, nPred, pre_f, post_f, nF_m)
% Returns art_cell{ia}: [(pre_f+post_f) x nPred] mean onset-locked contra SVD
% deviation, baseline-subtracted using the first pre_f (pre-onset) frames.
nWin     = pre_f + post_f;
art_cell = cell(nAmp, 1);
for ia = 1:nAmp
    art_cell{ia} = zeros(nWin, nPred);
    if ~nzMask(ia); continue; end
    starts = imp_data.startTimes{ia}(:);
    devsum = zeros(nWin, nPred); nval = 0;
    for j = 1:numel(starts)
        [~, ion] = min(abs(t_full - starts(j)));
        i0 = ion - pre_f; i1 = ion + post_f - 1;
        if i0 < 1 || i1 > nF_m; continue; end
        chunk = X_cp_m(i0:i1, 1:nPred);
        bl    = mean(chunk(1:pre_f, :), 1, 'omitnan');
        devsum = devsum + (chunk - bl); nval = nval + 1;
    end
    art_cell{ia} = devsum / max(nval, 1);
end
end
