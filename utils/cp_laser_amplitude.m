function [uAmp, info] = cp_laser_amplitude(inpVals, inpTime, varargin)
% CP_LASER_AMPLITUDE  Convert a raw laser command trace to the TRUE input amplitude.
%
%   [uAmp, info] = cp_laser_amplitude(inpVals, inpTime)
%
% WHY (user, 2026-07-20)
%   In the EARLY controller experiments the laser was driven with a sine CARRIER whose
%   AMPLITUDE encodes the true command:  raw(t) = A(t) * (1 + sin(2*pi*fc*t))/2,  so the raw
%   trace swings 0..A at fc (~50 Hz) and its running MEAN is only A/2. In LATER experiments the
%   command value is written directly (no carrier). Treating the raw carrier as the input is
%   wrong twice over: it halves the amplitude AND, once resampled to the 35 Hz widefield grid,
%   the carrier ALIASES into a spurious low-frequency "dither" that corrupts system ID.
%
% WHAT IT DOES
%   Detects whether a carrier is present (dominant spectral peak above CARRIER_MIN_HZ holding a
%   substantial share of the AC power). If so, returns the peak ENVELOPE (running max over one
%   carrier period) = A(t). If not, returns inpVals unchanged (direct-value sessions).
%
% INPUTS
%   inpVals, inpTime  raw command and its timestamps (native rate, e.g. 2 kHz)
% NAME-VALUE
%   'CarrierMinHz'  (10)   ignore spectral peaks below this (real command dynamics live low)
%   'PowerFrac'     (0.15) min share of AC power in the peak to declare a carrier
%   'Mode'          ('auto') force 'envelope' or 'direct' to override detection
% OUTPUTS
%   uAmp   [numel(inpVals) x 1] true amplitude command
%   info   struct: mode, carrier_hz, power_frac, period_samples, fs_native
%
% See also: ctrl_lti_sysid.m (Stage 4a plant ID), ctrl_ols_cl_deploy.m

p = inputParser;
p.addParameter('CarrierMinHz', 10);
p.addParameter('PowerFrac',    0.15);
p.addParameter('Mode',         'auto');
p.parse(varargin{:});
opt = p.Results;

inpVals = double(inpVals(:));  inpTime = double(inpTime(:));
fs = 1/median(diff(inpTime));

% ---- find a segment INSIDE one laser-ON epoch --------------------------------------------
% A carrier dips to 0 every cycle, so thresholding raw samples would split one ON epoch into
% half-cycles. Envelope-smooth first (100 ms covers any carrier >= 10 Hz), then find epochs.
% Detecting across ON/OFF boundaries would let the broadband on/off switching swamp the
% carrier bin (that is a real failure mode: it reads as ~3% power and misdetects as 'direct').
env0 = movmax(inpVals, max(3, round(fs*0.1)));
on   = env0 > 0.2*max(env0);
dOn  = diff([false; on(:); false]);
runS = find(dOn==1);  runE = find(dOn==-1)-1;
if isempty(runS)
    uAmp = inpVals;
    info = struct('mode','direct','carrier_hz',NaN,'power_frac',0,'period_samples',1,'fs_native',fs,'mean_peak_ratio',NaN);
    return;
end
[runLen, ir] = max(runE-runS+1);
if runLen < 512                                   % too short to judge -> assume direct
    uAmp = inpVals;
    info = struct('mode','direct','carrier_hz',NaN,'power_frac',0,'period_samples',1,'fs_native',fs,'mean_peak_ratio',NaN);
    return;
end
i0 = runS(ir);  i1 = min(runE(ir), i0 + 2^15 - 1);
seg = inpVals(i0:i1);  segAC = seg - mean(seg);
N = numel(segAC);  P = abs(fft(segAC)).^2;  P = P(2:floor(N/2));  fax = (1:numel(P))*fs/N;
ok = fax >= opt.CarrierMinHz;
carrier_hz = NaN;  pfrac = 0;
if any(ok)
    Pk = P;  Pk(~ok) = 0;
    [pmax, ip] = max(Pk);
    carrier_hz = fax(ip);
    pfrac = pmax / max(sum(P), eps);
end

% Direct physical test: for raw = A*(1+sin)/2 the running mean is HALF the running peak;
% for a directly-commanded (flat) value the two coincide.
meanPeakRatio = NaN;
if isfinite(carrier_hz)
    per_t = max(3, round(fs/carrier_hz));
    meanPeakRatio = mean(seg) / max(mean(movmax(seg, per_t)), eps);
end

isCarrier = strcmpi(opt.Mode,'envelope') || ...
    (strcmpi(opt.Mode,'auto') && isfinite(carrier_hz) && ...
     (pfrac >= opt.PowerFrac || meanPeakRatio < 0.8));

if ~isCarrier
    uAmp = inpVals;
    info = struct('mode','direct','carrier_hz',carrier_hz,'power_frac',pfrac, ...
                  'period_samples',1,'fs_native',fs,'mean_peak_ratio',meanPeakRatio);
    return;
end

% ---- envelope = running peak over exactly one carrier period ----
per = max(3, round(fs/carrier_hz));
uAmp = movmax(inpVals, per);
% movmax smears the edges of an ON epoch by +/- half a period; re-zero where the raw command is
% off across the whole window so onsets/offsets stay sharp.
offMask = movmax(abs(inpVals), per) < 1e-3;
uAmp(offMask) = 0;
info = struct('mode','envelope','carrier_hz',carrier_hz,'power_frac',pfrac, ...
              'period_samples',per,'fs_native',fs,'mean_peak_ratio',meanPeakRatio);
end
