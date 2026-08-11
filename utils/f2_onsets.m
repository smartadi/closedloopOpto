function onF = f2_onsets(st, t_full, preN, postN, nFall)
%F2_ONSETS  Nearest movie frame to each stim start time, keeping only fully-contained windows.
% Extracted from ols_tf_pipeline.m's local_onsets so the Fig-2 stream and the old pipeline
% cannot drift apart on how an onset is snapped to a frame.
onF = zeros(numel(st),1);
for j = 1:numel(st), [~,onF(j)] = min(abs(t_full - st(j))); end
onF = onF(onF-preN >= 1 & onF+postN <= nFall);
end
