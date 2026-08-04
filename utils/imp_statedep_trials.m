function ST = imp_statedep_trials(P)
%IMP_STATEDEP_TRIALS  Per-trial LOCAL-dip DVs + brain-state markers for one impulse session.
%
% This is the compute core of [STATEDEP] / [STATEDEP-VAR] in ols_tf_pipeline.m, factored out so
% the INTERACTIVE section (§17c) and the HEADLESS per-session engine (§18 local_stimblind_session,
% used by the cross-session batch) run the IDENTICAL definitions. Two copies of these window
% constants is exactly how a cross-session comparison silently stops comparing like with like.
%
% For every trial it rebuilds the SELECT stim-blind prediction from THAT trial's own contra pixels,
% subtracts it from the trial's actual ipsi -> single-trial LOCAL residual, and reduces the residual
% over the dip window to three candidate DVs (all z-scored WITHIN amplitude, which removes the
% dose-response mean so only the trial-to-trial spread is tested):
%   DVz     DIPmean  signed mean residual over the dip window        (direction: <0 = deeper)
%   GAINz   template gain <r,mu>/<mu,mu> vs the amp-mean residual    (shape-aware, signed)
%   L1DEVz  mean |r - mu|                                            (unsigned = UNPREDICTABILITY)
%
% and four state markers at onset (windows per RESEARCH 2026-06-26, matching cp_residual_core):
%   MOT  total |z| motion over [-2,+0.5] s        POWER-INDEPENDENT  <- admissible
%   PVv  var(y) over [-1,+0.5] s                  POWER-CONFOUND     <- reported, not interpreted
%   DPa  absolute 1-4 Hz power, same window       POWER-CONFOUND     <- reported, not interpreted
%   DPr  RELATIVE delta = DPa / (0.5-30 Hz)       POWER-INDEPENDENT  <- admissible
% plus the two prediction-quality controls that every state partial conditions on:
%   PRE   pre-onset (-0.2..0 s) residual energy   (no stim -> pure fit quality)
%   POST  settled-tail (last 0.2 s) energy        (2nd stim-free probe, guards non-stationarity)
%
% P (all required unless noted):
%   Uflat [nPix x nSV], gridIdx, V [nSV x nFrames], mu_p, sd_p   z-scoring operators for the grid
%   y_full, nF          ipsi kernel trace and its length
%   onFcell{nA}         per-amp onset frame indices
%   bUse{nA}            per-amp SELECT stim-blind weights (empty amp -> skipped)
%   dipCols             dip-window columns: [1 x nCols] shared, or {nA} per amp (empty -> shared)
%   rel, preN, Wb, Fs, amps
%   motz                z-scored motion at blue cadence, or [] -> MOT is NaN
%   wantTraces          (optional, default true) also return per-trial A/G/L traces
%
% ST: per-trial column vectors concatenated across amps (DVz GAINz L1DEVz LD PRE POST MOT PVv DPa
%     DPr AMPv AMPi TRi), per-amp ldMean/ldStd, and trA/trG/trL cell arrays of [Wb x nT] traces.

if ~isfield(P,'wantTraces') || isempty(P.wantTraces), P.wantTraces = true; end
nA = numel(P.onFcell);  Fs = P.Fs;  preN = P.preN;  Wb = P.Wb;  rel = P.rel(:);
nG = numel(P.gridIdx);

% ---- windows (do not change without changing the twin in the other sessions' runs) -------------
tsec         = rel/Fs;
preCols      = find(tsec >= -0.2 & tsec < 0);          % matched pre-onset control window
postCtrlCols = ((Wb-round(0.2*Fs)+1):Wb).';            % last 0.2 s = settled-tail control
vd_preN  = round(1*Fs);    vd_postN  = round(0.5*Fs);  % var/delta window [-1,+0.5] s
motPreN  = round(2*Fs);    motPostN  = round(0.5*Fs);  % motion window    [-2,+0.5] s
nWvd   = vd_preN + vd_postN + 1;  win_r = hann(nWvd);  W_r = sum(win_r.^2);
nfft_r = 2^nextpow2(nWvd);  fr = (0:nfft_r-1)'/nfft_r*Fs;  nB_r = floor(nfft_r/2)+1;
delta_r = fr(1:nB_r) >= 1   & fr(1:nB_r) <= 4;         % 1-4 Hz delta band
tot_r   = fr(1:nB_r) >= 0.5 & fr(1:nB_r) <= 30;        % broadband for the RELATIVE-delta ratio

DVz=[]; GNz=[]; L1z=[]; LD=[]; PRE=[]; POST=[]; MOT=[]; PVv=[]; DPa=[]; DPr=[];
AMPv=[]; AMPi=[]; TRi=[];
ldMean = nan(nA,1);  ldStd = nan(nA,1);
trA = cell(nA,1);  trG = cell(nA,1);  trL = cell(nA,1);
sdf = @(x) (x - mean(x,'omitnan'))./max(std(x,'omitnan'), eps);

for ai = 1:nA
    onF = P.onFcell{ai}(:);  nT = numel(onF);
    if nT == 0 || isempty(P.bUse{ai}), continue; end
    b = P.bUse{ai};
    if iscell(P.dipCols), dc = P.dipCols{ai}; else, dc = P.dipCols; end
    if isempty(dc), dc = (preN+1):min(Wb, preN+round(0.3*Fs)); end

    idx = onF.' + rel;
    Zp  = (double(P.Uflat(P.gridIdx,:))*double(P.V(:,idx(:))) - P.mu_p)./P.sd_p;
    Zp  = reshape(Zp, nG, Wb, nT);
    A   = reshape(double(P.y_full(idx(:))), Wb, nT);
    A   = A - mean(A(1:preN,:), 1);                    % single-trial actual, baselined

    ld=nan(nT,1); dpre=nan(nT,1); dpost=nan(nT,1); mt=nan(nT,1);
    pvv=nan(nT,1); dpa=nan(nT,1); dpr=nan(nT,1);
    YG = nan(Wb,nT);  RL = nan(Wb,nT);
    for j = 1:nT
        yg = (b.'*Zp(:,:,j)).';  yg = yg - mean(yg(1:preN));   % single-trial stim-blind (Global)
        rL = A(:,j) - yg;                                      % single-trial Local residual
        YG(:,j) = yg;  RL(:,j) = rL;
        ld(j)    = mean(rL(dc));                               % Local dip = per-trial stim effect
        dpre(j)  = mean(rL(preCols).^2);                       % prediction quality, no stim
        dpost(j) = mean(rL(postCtrlCols).^2);                  % 2nd stim-free probe
        ion = onF(j);
        mw = ion-motPreN:ion+motPostN;
        if ~isempty(P.motz) && mw(1) >= 1 && mw(end) <= numel(P.motz)
            mt(j) = sum(abs(P.motz(mw)));
        end
        gp = ion-vd_preN:ion+vd_postN;
        if gp(1) >= 1 && gp(end) <= P.nF
            sp = double(P.y_full(gp));  pvv(j) = var(sp,'omitnan');
            Xf = fft(sp(:).*win_r, nfft_r);  pw = abs(Xf(1:nB_r)).^2 * 2/(Fs*W_r);
            dpa(j) = mean(pw(delta_r),'omitnan');
            dpr(j) = dpa(j)/max(mean(pw(tot_r),'omitnan'), eps);   % RELATIVE delta
        end
    end
    if P.wantTraces, trA{ai}=A; trG{ai}=YG; trL{ai}=RL; end
    ldMean(ai) = mean(ld,'omitnan');  ldStd(ai) = std(ld,'omitnan');

    muT = mean(RL(dc,:), 2, 'omitnan');                        % amp-mean residual template
    gn  = (RL(dc,:).'*muT)/max(muT.'*muT, eps);                % template gain
    l1d = mean(abs(RL(dc,:) - muT), 1).';                      % unsigned deviation

    DVz  = [DVz;  sdf(ld)];   GNz = [GNz; sdf(gn)];  L1z = [L1z; sdf(l1d)];        %#ok<AGROW>
    LD   = [LD; ld];  PRE = [PRE; dpre];  POST = [POST; dpost];                    %#ok<AGROW>
    MOT  = [MOT; mt];  PVv = [PVv; pvv];  DPa = [DPa; dpa];  DPr = [DPr; dpr];     %#ok<AGROW>
    AMPv = [AMPv; P.amps(ai)*ones(nT,1)];  AMPi = [AMPi; ai*ones(nT,1)];           %#ok<AGROW>
    TRi  = [TRi; (1:nT).'];                                                        %#ok<AGROW>
end

ST = struct('DVz',DVz,'GAINz',GNz,'L1DEVz',L1z,'LD',LD,'PRE',PRE,'POST',POST, ...
            'MOT',MOT,'PVv',PVv,'DPa',DPa,'DPr',DPr,'AMPv',AMPv,'AMPi',AMPi,'TRi',TRi, ...
            'ldMean',ldMean,'ldStd',ldStd,'trA',{trA},'trG',{trG},'trL',{trL});
end
