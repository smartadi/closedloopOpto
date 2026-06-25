function H = cp_hemi_predictor(P)
% cp_hemi_predictor -- build the [CP-HEMI] contra->primary-pixel linear map.
%
% Returns the Zhiwen-faithful whole-hemisphere RRR predictor collapsed to an
% AFFINE map on the contra SVD modes, so the primary-pixel "Global" prediction
% can be applied pointwise to ANY frames (e.g. trial windows):
%
%     yhat_dF(t) = V_c_full(1:K, t).' * H.bk + H.b0        (% dF/F, ~ y_full units)
%
% This is the SAME field->kernel-average readout used by the [CP-HEMI] section of
% contra_prediction.m: predict the whole ipsi field from the contra modes by
% reduced-rank regression (CanonCor2), then average the predicted field over the
% recording kernel. Here it is expressed as a fixed linear functional of the
% contra modes so cp_residual_core can use it as the residual "Global" component.
%
% NB on standardization: [CP-HEMI] z-scores the train and test blocks
% independently (Zhiwen-style); a *deployable* pointwise map cannot re-z-score per
% trial window, so this helper standardizes train AND test with the TRAIN-block
% per-mode mean/std and bakes them into (bk, b0). H.cv is therefore the held-out
% R^2 of the map as actually deployed (differs trivially from the section's number
% because of the z-scoring convention, not the method).
%
% INPUT  P (struct), required fields:
%   U_cp,V_cp,mimg_cp,nY_cp,nX_cp,nSV_cp  -- session SVD (loadUVt)
%   V_c_full                              -- redoSVD contra-mode timeseries [m x T]
%   ipsi_mask_cp                          -- ipsi(target) hemisphere mask (cp_roi_masks)
%   py_prim,px_prim,k_prim                -- primary pixel + recording-kernel half-width
%   y_full,t_full,all_starts_cp,nF_m,Fs   -- primary trace, time, nonzero stim onsets
%   path_cp                               -- cache stem (ipsi SVD cached alongside)
% Optional: K(50) maxPix(2000) maxFrm(60000) trainFrac(2/3) settle_s(1.0)
%           win_mode('interstim') spont_pre(6)
%
% OUTPUT H: bk [K x1], b0, K, cv (held-out primary-pixel R^2 of the deployed map),
%           rankSel (RRR rank chosen by held-out kernel R^2), kernR2 [K x1],
%           pool10 (whole-hemi pooled R^2 @ rank 10, reporting), nTr, nTe.

K        = getf(P,'K',50);
maxPix   = getf(P,'maxPix',2000);
maxFrm   = getf(P,'maxFrm',60000);
trainFrac= getf(P,'trainFrac',2/3);
settle_s = getf(P,'settle_s',1.0);
win_mode = getf(P,'win_mode','interstim');
Fs       = P.Fs;
rankMark = min(10, K);

% ---- ipsi (target) hemisphere mask (midline-split, passed in) ---------------------
ipsi_mask = P.ipsi_mask_cp;
full_idx  = find(ipsi_mask(:));
idx_ipsi  = full_idx;                                  % scored set (downsampled below)
if numel(idx_ipsi) > maxPix
    idx_ipsi = idx_ipsi(1:ceil(numel(idx_ipsi)/maxPix):end);
end

% ---- ipsi SVD (cached alongside the contra cache; same path as [CP-HEMI]) ---------
path_ipsi = strrep(P.path_cp, '.mat', '_svdraw_ml_ipsi.mat');   % _ml = midline-split mask
if exist(path_ipsi,'file')
    t = load(path_ipsi,'U_ipsi_raw','V_ipsi_full');
    U_ipsi_raw = t.U_ipsi_raw;  V_ipsi_full = t.V_ipsi_full;
    fprintf('[cp_hemi_predictor] loaded ipsi SVD cache: %s\n', path_ipsi);
else
    Uflat = reshape(P.U_cp, P.nY_cp*P.nX_cp, P.nSV_cp);
    Uip   = double(Uflat(full_idx,:));
    fprintf('[cp_hemi_predictor] running redoSVD on ipsi mask (%d px)...\n', size(Uip,1));
    [U_ipsi_raw, V_ipsi_full] = redoSVD(Uip, double(P.V_cp));
    U_ipsi_raw = double(U_ipsi_raw);  V_ipsi_full = double(V_ipsi_full);
    save(path_ipsi,'U_ipsi_raw','V_ipsi_full','-v7.3');
end

% ---- recording-kernel footprint (matches getpixel_dFoF / how y_full is built) -----
kk = double(P.k_prim);
kr = (P.px_prim-kk):(P.px_prim+kk);  kr = kr(kr>=1 & kr<=P.nY_cp);   % rows (pixel(2))
kc = (P.py_prim-kk):(P.py_prim+kk);  kc = kc(kc>=1 & kc<=P.nX_cp);   % cols (pixel(1))
[KR,KC]  = ndgrid(kr,kc);
idx_kern = intersect(sub2ind([P.nY_cp,P.nX_cp],KR(:),KC(:)), full_idx);
if isempty(idx_kern)
    error('cp_hemi_predictor: kernel footprint falls outside the ipsi field mask.');
end
[~,sel_kern] = ismember(idx_kern, full_idx);
meanU   = mean(U_ipsi_raw(sel_kern,1:K), 1);           % [1 x K] mean ipsi-SVD loading
mI_kern = mean(P.mimg_cp(kr,kc), 'all');               % == y_full's mI(1) normalizer

% ---- spontaneous frames (post-settle inter-stim, same as [CP-HEMI]) ---------------
ons = zeros(numel(P.all_starts_cp),1);
for j = 1:numel(P.all_starts_cp)
    [~,ons(j)] = min(abs(P.t_full - P.all_starts_cp(j)));
end
frames = [];
switch win_mode
    case 'interstim'
        settle = round(settle_s*Fs);
        for j = 1:numel(ons)
            i0 = ons(j) + settle;
            if j < numel(ons);  i1 = ons(j+1) - 1;  else;  i1 = P.nF_m;  end
            i0 = max(i0,1);  i1 = min(i1, P.nF_m);
            if i1 >= i0;  frames = [frames, i0:i1];  end %#ok<AGROW>
        end
    otherwise   % 'prestim'
        pf = round(getf(P,'spont_pre',6)*Fs);
        for j = 1:numel(ons)
            i0 = ons(j) - pf;  i1 = ons(j) - 1;
            if i0 >= 1 && i1 <= P.nF_m;  frames = [frames, i0:i1];  end %#ok<AGROW>
        end
end
frames = unique(frames);
if numel(frames) > maxFrm
    frames = frames(round(linspace(1, numel(frames), maxFrm)));
end
nTr = floor(trainFrac * numel(frames));
tr  = frames(1:nTr);  te = frames(nTr+1:end);

% ---- regressors: TRAIN-stats standardization (deployable map) ---------------------
mu_tr = mean(P.V_c_full(1:K,tr), 2);                   % [K x 1]
sd_tr = std (P.V_c_full(1:K,tr), 0, 2);  sd_tr(sd_tr==0) = 1;
Xtr = ((P.V_c_full(1:K,tr) - mu_tr) ./ sd_tr).';       % [nTr x K]
Xte = ((P.V_c_full(1:K,te) - mu_tr) ./ sd_tr).';       % [nTe x K] (same stats -> deployable)

% ---- whole-hemi RRR (CanonCor2) on the downsampled scored set ---------------------
[~,sel] = ismember(idx_ipsi, full_idx);
Uips = U_ipsi_raw(sel, 1:K);
Ytr  = (Uips * V_ipsi_full(1:K,tr)).';                 % [nTr x P]
Yte  = (Uips * V_ipsi_full(1:K,te)).';
[a,b,~] = CanonCor2({Ytr}, {Xtr});                     % a:[P x K]  b:[K x K]
Ztr = Xtr * b;                                         % canonical latents (orthonormal/train)
Zte = Xte * b;

% ---- whole-hemi pooled R^2 at rankMark (Zhiwen-comparable, reporting only) ---------
Yh_pool = Zte(:,1:rankMark) * a(:,1:rankMark).';
pool10  = sseExplainedCal(Yte(:).', Yh_pool(:).');

% ---- primary-pixel field->kernel readout vs y_full; pick best held-out rank -------
aKern = Ztr \ (meanU * V_ipsi_full(1:K,tr)).';         % [K x 1] (Ztr orthonormal on train)
yte_real = P.y_full(te);
kernR2 = nan(K,1);
for n = 1:K
    yhdF = (Zte(:,1:n) * aKern(1:n)) / mI_kern * 100;
    kernR2(n) = sseExplainedCal(yte_real(:).', yhdF(:).');
end
[cv, rankSel] = max(kernR2);

% ---- collapse to an affine map on the RAW contra modes ----------------------------
w  = b(:,1:rankSel) * aKern(1:rankSel);                % [K x 1]
bk = (100/mI_kern) * (w ./ sd_tr);                     % [K x 1]
b0 = -(100/mI_kern) * (mu_tr.' * (w ./ sd_tr));        % scalar

H = struct('bk',bk, 'b0',b0, 'K',K, 'cv',cv, 'rankSel',rankSel, ...
           'kernR2',kernR2, 'pool10',pool10, 'nTr',numel(tr), 'nTe',numel(te));
fprintf(['[cp_hemi_predictor] K=%d nTr=%d nTe=%d | pooled R^2@%d=%.3f | ' ...
         'primary-pixel R^2=%.3f @rank%d\n'], K, numel(tr), numel(te), ...
         rankMark, pool10, cv, rankSel);
end

% ---------------------------------------------------------------------------------
function v = getf(P,f,d)
if isfield(P,f) && ~isempty(P.(f)), v = P.(f); else, v = d; end
end
