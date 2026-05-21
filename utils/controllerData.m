function data = controllerData(data, d, t)
% Classify trials into wc/nc, slice dFk/motion/input windows, and compute
% H2 error and variance per trial — single pass, preallocated arrays.

trials = [zeros(length(d.input_params) - t, 1); ones(t, 1)];

dFk   = data.dFk;
nc    = find(d.input_params(:,3) == 0 & trials == 1);
wc    = find(d.input_params(:,3) == 1 & trials == 1);
dur   = d.params.dur;
tBlue = d.timeBlue(:)';
ti    = d.inpTime(:)';




%%




mv = d.motion;

% Session-level spectrogram: 2-s Hann window → Δf = 0.5 Hz exactly, 1-s hop
Fs        = 35;
specWin   = 2 * Fs;          % 70 samples = 2 s
specHop   = Fs;              % 35 samples = 1 s time step
nBands    = 20;              % bands [0,0.5) … [9.5,10) Hz, one FFT bin each
pre_bins  = 6;               % spectrogram bins stored before onset (6 s)
post_bins = dur + 3;         % bins after onset: trial end + 3 s buffer

[S_spec, ~, t_spec] = spectrogram(dFk, hann(specWin), specWin-specHop, specWin, Fs);
S_bands = abs(S_spec(1:nBands, :)).^2;
S_norm  = S_bands ./ (sum(S_bands, 1) + eps);   % 20 × nSpecTime  (power ratios 0-10 Hz)

W_freq       = pre_bins + post_bins + 1;         % total bins per stored trial window
freqBandCtrs = (0:nBands-1)*0.5 + 0.25;         % 0.25, 0.75, … 9.75 Hz (band centres)
freqOnsetBin = pre_bins + 1;                     % onset column within stored window (= 3)

% Window sizes (samples) — derived once from dur
W_dfk  = 35*(dur+2) + 1;     % i-35 : i+35*(dur+1)
W_pdfk = 35*(dur+13) + 1;    % i-350 : i+35*(dur+3)
W_mot  = 35*(dur+2) + 1;     % i-70  : i+35*dur  (2s pre to trial end)
W_inp  = dur*2000 + 1;       % i2   : i2+dur*2000

% Vectorised nearest-neighbour lookup (tBlue/ti are uniformly sampled)
dt_blue = tBlue(2) - tBlue(1);
dt_in   = ti(2) - ti(1);

ncIdx   = max(1, min(numel(tBlue), round((d.stimStarts(nc)  - tBlue(1)) / dt_blue) + 1));
wcIdx   = max(1, min(numel(tBlue), round((d.stimStarts(wc)  - tBlue(1)) / dt_blue) + 1));
ncIdxIn = max(1, min(numel(ti),    round((d.stimStarts(nc)  - ti(1))    / dt_in)   + 1));
wcIdxIn = max(1, min(numel(ti),    round((d.stimStarts(wc)  - ti(1))    / dt_in)   + 1));

nNc = numel(nc);
nWc = numel(wc);

% Preallocate all output arrays
ncDfk    = zeros(nNc, W_dfk);
pncDfk   = zeros(nNc, W_pdfk);
ncInp    = zeros(nNc, W_inp);
ncmotion = zeros(nNc, W_mot);
er_ncDfk = zeros(nNc, 1);
vr_ncDfk = zeros(nNc, 1);

wcDfk    = zeros(nWc, W_dfk);
pwcDfk   = zeros(nWc, W_pdfk);
wcInp    = zeros(nWc, W_inp);
wcmotion = zeros(nWc, W_mot);
er_wcDfk = zeros(nWc, 1);
vr_wcDfk = zeros(nWc, 1);

ncFreqSpec = zeros(nNc, W_freq, nBands);
wcFreqSpec = zeros(nWc,  W_freq, nBands);
ncFreqPow  = zeros(nNc, W_freq, nBands);   % absolute power (S_bands, no ratio)
wcFreqPow  = zeros(nWc,  W_freq, nBands);

% NC trials — slice windows and compute error in the same pass
% for j = 1:nNc
%     i  = ncIdx(j);
%     i2 = ncIdxIn(j);
%     ncDfk(j,:)    = dFk(i-35 : i+35*(dur+1));
%     pncDfk(j,:)   = dFk(i-350 : i+35*(dur+3));
%     ncInp(j,:)    = d.inpVals(i2 : i2+dur*2000)';
%     ncmotion(j,:) = mv1(i-350 : i+35*(dur+2));
%     seg = dFk(i : i+35*dur);
%     er_ncDfk(j)   = norm(seg - d.ref);
%     vr_ncDfk(j)   = var(seg);
% end
% 
% % WC trials
% for j = 1:nWc
%     i  = wcIdx(j);
%     i2 = wcIdxIn(j);
%     wcDfk(j,:)    = dFk(i-35 : i+35*(dur+1));
%     pwcDfk(j,:)   = dFk(i-350 : i+35*(dur+3));
%     wcInp(j,:)    = d.inpVals(i2 : i2+dur*2000)';
%     wcmotion(j,:) = mv1(i-350 : i+35*(dur+2));
%     seg = dFk(i : i+35*dur);
%     er_wcDfk(j)   = norm(seg - d.ref);
%     vr_wcDfk(j)   = var(seg);
% end

t = tBlue;
for j = 1:length(nc)
    [a i] = min(abs(t - d.stimStarts(nc(j))));
    [a i2] = min(abs(ti - d.stimStarts(nc(j))));

    % i  = ncIdx(j);
    % i2 = ncIdxIn(j);
    ncDfk(j,:)    = dFk(i-35 : i+35*(dur+1));
    pncDfk(j,:)   = dFk(i-350 : i+35*(dur+3));
    ncInp(j,:)    = d.inpVals(i2 : i2+dur*2000)';
    ncmotion(j,:) = mv(i-70 : i+35*dur);
    seg = dFk(i : i+35*dur);
    er_ncDfk(j)   = norm(seg - d.ref);
    vr_ncDfk(j)   = var(seg);
    t_on = (i-1)/Fs;
    [~, sc] = min(abs(t_spec - t_on));
    c1 = sc - pre_bins;  c2 = sc + post_bins;
    if c1 >= 1 && c2 <= size(S_norm,2)
        ncFreqSpec(j,:,:) = S_norm(:,   c1:c2)';
        ncFreqPow(j,:,:)  = S_bands(:,  c1:c2)';
    end
end

% WC trials
for j = 1:length(wc)
   [a i] = min(abs(t - d.stimStarts(wc(j))));
       [a i2] = min(abs(ti - d.stimStarts(wc(j))));


    % i2 = wcIdxIn(j);
    wcDfk(j,:)    = dFk(i-35 : i+35*(dur+1));
    pwcDfk(j,:)   = dFk(i-350 : i+35*(dur+3));
    wcInp(j,:)    = d.inpVals(i2 : i2+dur*2000)';
    wcmotion(j,:) = mv(i-70 : i+35*dur);
    seg = dFk(i : i+35*dur);
    er_wcDfk(j)   = norm(seg - d.ref);
    vr_wcDfk(j)   = var(seg);
    t_on = (i-1)/Fs;
    [~, sc] = min(abs(t_spec - t_on));
    c1 = sc - pre_bins;  c2 = sc + post_bins;
    if c1 >= 1 && c2 <= size(S_norm,2)
        wcFreqSpec(j,:,:) = S_norm(:,   c1:c2)';
        wcFreqPow(j,:,:)  = S_bands(:,  c1:c2)';
    end
end

data.ncInp    = ncInp;
data.wcInp    = wcInp;
data.wc       = wc;
data.nc       = nc;
data.ncDfk    = ncDfk;
data.wcDfk    = wcDfk;
data.pncDfk   = pncDfk;
data.pwcDfk   = pwcDfk;
data.ncmotion = ncmotion;
data.wcmotion = wcmotion;
data.er_wcDfk = er_wcDfk;
data.er_ncDfk = er_ncDfk;
data.vr_wcDfk = vr_wcDfk;
data.vr_ncDfk = vr_ncDfk;

data.ncFreqSpec   = ncFreqSpec;
data.wcFreqSpec   = wcFreqSpec;
data.ncFreqPow    = ncFreqPow;
data.wcFreqPow    = wcFreqPow;
data.freqBandCtrs = freqBandCtrs;
data.freqOnsetBin = freqOnsetBin;

disp('analysis done')
end
