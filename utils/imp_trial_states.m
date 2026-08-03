function ST = imp_trial_states(d_s, data, t_full, pre, post, nF, Fs)
% imp_trial_states  Per-trial pre-stim BRAIN STATE for the rejection analysis.
%
% SINGLE SOURCE OF TRUTH for the two states used against rho_{1-3}: extracted from
% internal_model_principle.m ([IMP-STATE-QUARTILE]) so the single-session workbench
% (Stream 1) and the cross-session batch (Stream 2, imp_state_across_sessions.m)
% can never drift apart -- the same contract imp_build_session/imp_reject_core hold
% for the trial builder and the rho kernel.
%
% Definitions MATCH the figure-4 factor analysis (cl_rmse_factor_windows.m) exactly,
% and are recomputed from PRIMITIVES (d.motion, data.dFk) so no controllerData cache
% field is required:
%   motion  = mean z-motion^2 over [-2 s, trial end]        (energy; d.motion is z-scored)
%   rel del = bandpow(2-4 Hz)/bandpow(0.4-10 Hz) over [-2 s, +3 s]
%             (per-trial periodogram: linear detrend + Hann + one-sided |FFT|^2)
% NB, as in fig-4: the window spans -2 s THROUGH the trial, not pre-stim only. A
% strictly pre-onset variant would need pre_s/post_s changed here (one place).
%
% Trial order: onsets are sorted and edge-dropped with the SAME rule deal_trials uses
% (onF>pre & onF+post<=nF), so the returned vectors align element-for-element with
% rho_ol/rho_cl. Callers should assert the counts match.
%
% IN   d_s,data  session structs (need d.stimStarts, d.params.dur, d.timeBlue, d.motion;
%                 data.nc/wc trial index, data.dFk)
%      t_full    frame time vector; pre/post/nF  windowing as in imp_build_session
% OUT  ST .mot_ol .mot_cl .delt_ol .delt_cl  [nTrial x 1] per condition
%         .haveMot  false if the session has no motion trace (mot_* all NaN)
%         .n_ol .n_cl  trial counts
%         .names    display labels, in the order a caller should plot them

if nargin < 7 || isempty(Fs); Fs = 35; end
mot_pre = 2;  spec_pre_s = 2;  spec_post_s = 3;          % fig-4 windows
durc = d_s.params.dur;

ST = struct();
ST.haveMot = isfield(d_s,'motion') && ~isempty(d_s.motion) && isfield(d_s,'timeBlue') ...
             && any(d_s.motion ~= 0);
tB  = d_s.timeBlue(:);  dfk = data.dFk(:);
mv  = [];  if ST.haveMot; mv = d_s.motion(:); end

ons_ol = local_trial_onsets(d_s.stimStarts(data.nc(:)), t_full, pre, post, nF);
ons_cl = local_trial_onsets(d_s.stimStarts(data.wc(:)), t_full, pre, post, nF);

pmot = @(o) local_fig4_motion(o, tB, mv, Fs, mot_pre, durc);
pdel = @(o) local_fig4_delta(o, tB, dfk, Fs, spec_pre_s, spec_post_s);

ST.mot_ol  = arrayfun(pmot, ons_ol);   ST.mot_cl  = arrayfun(pmot, ons_cl);
ST.delt_ol = arrayfun(pdel, ons_ol);   ST.delt_cl = arrayfun(pdel, ons_cl);
ST.n_ol = numel(ons_ol);  ST.n_cl = numel(ons_cl);
ST.names = {'motion energy', 'rel \delta power (2-4 Hz)'};
end

% ---- locals (moved verbatim from internal_model_principle.m) --------------------
function ons = local_trial_onsets(starts, t_full, pre, post, nF)
% Sorted, edge-kept onset TIMES (same trials, same order deal_trials produces).
[~,ord] = sort(starts);  s = starts(ord);
onF = zeros(numel(s),1);
for j = 1:numel(s), [~,onF(j)] = min(abs(t_full - s(j))); end
keep = onF > pre & onF + post <= nF;
ons  = s(keep);
end

function x = local_fig4_motion(o, tB, mv, Fs, pre_s, dur)
if isempty(mv), x = NaN; return; end
[~,i] = min(abs(tB - o));  a = i - round(pre_s*Fs);  b = i + round(dur*Fs) - 1;
if a >= 1 && b <= numel(mv), x = mean(mv(a:b).^2); else, x = NaN; end
end

function x = local_fig4_delta(o, tB, dfk, Fs, pre_s, post_s)
[~,i] = min(abs(tB - o));  a = i - round(pre_s*Fs);  b = i + round(post_s*Fs);
if a < 1 || b > numel(dfk), x = NaN; return; end
seg = dfk(a:b);
x = local_bandpow(seg,Fs,2,4) / max(local_bandpow(seg,Fs,0.4,10), eps);
end

function p = local_bandpow(seg, Fs, lo, hi)
% identical to cl_rmse_factor_windows: linear-detrend, Hann, one-sided |FFT|^2.
seg = detrend(double(seg(:)).','linear');  N = numel(seg);
w = hann(N).';  P = abs(fft(seg.*w)).^2;  P = P(1:floor(N/2)+1);
fr = (0:floor(N/2))*Fs/N;  p = sum(P(fr >= lo & fr < hi));
end
