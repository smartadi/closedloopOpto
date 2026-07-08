%% cp_hemo_ablation.m — does hemodynamic correction change OUR CP-HEMI number?
%
% The Ye/Zhiwen positive control (cp_zhiwen_validate.m) left one confound open: his SVD is
% hemodynamically corrected; is ours? For AL_0033 2025-01-29 e1 the server has blue/ (raw),
% violet/ (hemo reference) and corr/ (corrected) — and loadUVt PREFERS corr/, so our headline
% CP-HEMI 0.925 already ran on CORRECTED data. This script proves that empirically and measures
% the hemo effect directly on our own data by running the IDENTICAL whole-hemi pooled RRR twice,
% swapping ONLY the temporal components:
%   CORR : corr/svdTemporalComponents_corr.npy      (hemo-corrected — what CP-HEMI uses)
%   BLUE : blue/svdTemporalComponents.npy + detrendAndFilt  (uncorrected — loadUVt's fallback)
% Same spatial U (corr corrects temporal only), same contra/ipsi masks, same interstim frames,
% same K=50 / train 2/3 / rank sweep. Delta(CORR-BLUE) = the hemodynamic-correction effect.
%
% Expected: CORR reproduces ~0.925. If BLUE ~ CORR -> hemo correction is not the story (our gap
% vs Zhiwen is prep/SNR at matched preprocessing). If they differ -> we've quantified it.

clear; clc;
BP = 'C:\Users\aditya\Documents\projects\brain_paper';
addpath(genpath(fullfile(BP,'utils')));

mn='AL_0033'; td='2025-01-29'; en=1;
serverRoot = expPath(mn, td, en);
dd = fullfile(BP,'impulse-analysis','data');
K=50; maxPix=2000; trainFrac=2/3; maxFrm=60000; settle_s=1.0; nSV=500; Fs=35;

%% ---- site + ROI masks (shared; spatial U is identical for corr & blue) ----
SS = load(fullfile(dd,sprintf('cp_stim_site_%s_%s%s_e%d.mat',mn,td(6:7),td(9:10),en)));
px_prim = double(SS.rowcol(1)); py_prim = double(SS.rowcol(2));   % [row col] = [373 353]

fprintf('=== loading CORR SVD via loadUVt (prefers corr/) ===\n');
[U, Vcorr, t, mimg] = loadUVt(serverRoot, nSV);                   % U=blue spatial, Vcorr=corrected
[nY,nX] = size(mimg);  U = double(U);  Uflat = reshape(U, nY*nX, size(U,3));
fprintf('U %s  Vcorr %s  t %d\n', mat2str(size(U)), mat2str(size(Vcorr)), numel(t));

roi_file = fullfile(dd, sprintf('cp_roi2_%s_%s%s_e%d.mat',mn,td(6:7),td(9:10),en));
M = cp_roi_masks(mimg, roi_file, px_prim, py_prim, struct('redefine',false,'thr_pctile',20,'plot',false));
contra_mask = M.contra;  ipsi_mask = M.ipsi;
fprintf('masks: contra=%d px  ipsi=%d px\n', nnz(contra_mask), nnz(ipsi_mask));

%% ---- interstim spontaneous frames (shared; mirrors CP-HEMI S08) ----
sv = load(fullfile(dd,sprintf('stim_vars_%s_%s_en%d.mat',mn,td,en)));
nz = find(sv.uAmp > 0);                                          % drop amp-0 gap-fill
oi = [];  for k = nz(:)', oi = [oi; sv.idxByAmp{k}(:)]; end       %#ok<AGROW> (mixed row/col cells)
onset_t = sort(sv.stimStarts(oi));                               % nonzero-amp onset times
onsets = zeros(numel(onset_t),1);
for j=1:numel(onset_t), [~,onsets(j)] = min(abs(t - onset_t(j))); end
nF = numel(t);  settle = round(settle_s*Fs);  frames = [];
for j=1:numel(onsets)
    i0 = onsets(j)+settle;
    if j<numel(onsets), i1 = onsets(j+1)-1; else, i1 = nF; end
    i0=max(i0,1); i1=min(i1,nF);
    if i1>=i0, frames=[frames, i0:i1]; end %#ok<AGROW>
end
frames = unique(frames);
if numel(frames)>maxFrm, frames = frames(round(linspace(1,numel(frames),maxFrm))); end
nTr = floor(trainFrac*numel(frames));
tr = frames(1:nTr);  te = frames(nTr+1:end);
fprintf('interstim frames: %d (%.0f s)  train %d / test %d\n', numel(frames), numel(frames)/Fs, numel(tr), numel(te));

%% ---- CORR condition (should reproduce ~0.925) ----
fprintf('\n=== CORR (hemo-corrected) ===\n');
poolR2_corr = hemi_pool(Uflat, double(Vcorr), contra_mask, ipsi_mask, tr, te, K, maxPix, nY, nX);
clear Vcorr

%% ---- BLUE condition (uncorrected + detrendAndFilt, = loadUVt fallback) ----
fprintf('\n=== BLUE (uncorrected) ===\n');
Vblue = readVfromNPY(fullfile(serverRoot,'blue','svdTemporalComponents.npy'), nSV);
Vblue = detrendAndFilt(double(Vblue), Fs);                        % exactly loadUVt's else-branch
poolR2_blue = hemi_pool(Uflat, double(Vblue), contra_mask, ipsi_mask, tr, te, K, maxPix, nY, nX);
clear Vblue

%% ---- report + figure ----
rmk=10;
[pkC,ipC]=max(poolR2_corr); [pkB,ipB]=max(poolR2_blue);
fprintf('\n============ HEMO ABLATION (AL_0033 2025-01-29 e1) ============\n');
fprintf('CORR (hemo-corrected)  : rank%d=%.3f | peak=%.3f@rank%d\n', rmk, poolR2_corr(rmk), pkC, ipC);
fprintf('BLUE (uncorrected)     : rank%d=%.3f | peak=%.3f@rank%d\n', rmk, poolR2_blue(rmk), pkB, ipB);
fprintf('delta (CORR-BLUE)      : rank%d=%+.3f | peak=%+.3f\n', rmk, poolR2_corr(rmk)-poolR2_blue(rmk), pkC-pkB);
fprintf('reference: Zhiwen whole-hemi (his data, corrected) 0.971@%d; our CP-HEMI headline 0.925\n', rmk);
fprintf('===============================================================\n');
save(fullfile(dd,'cp_hemo_ablation.mat'), 'poolR2_corr','poolR2_blue','tr','te','K');

fig = paperFig(9,7); ax=axes(fig,'Position',[0.15 0.16 0.80 0.76]); hold(ax,'on');
plot(ax,1:K,poolR2_corr,'-o','Color',[0.10 0.50 0.80],'MarkerSize',3,'LineWidth',1.5,'DisplayName','CORR (hemo-corrected)');
plot(ax,1:K,poolR2_blue,'-s','Color',[0.85 0.30 0.10],'MarkerSize',3,'LineWidth',1.5,'DisplayName','BLUE (uncorrected)');
yline(ax,0.971,'k:','LineWidth',1.0,'HandleVisibility','off'); text(ax,K,0.971,'  Zhiwen 0.971','FontSize',5,'HorizontalAlignment','right','VerticalAlignment','bottom');
xline(ax,rmk,':','Color',[0.6 0.6 0.6],'HandleVisibility','off');
xlabel(ax,'rank (# components)','FontWeight','bold','FontSize',6); ylabel(ax,'held-out pooled R^2','FontWeight','bold','FontSize',6);
ylim(ax,[0 1]); xlim(ax,[1 K]);
lg=legend(ax,'Location','southeast','FontSize',5); lg.ItemTokenSize=[6 6];
title(ax,'AL\_0033 CP-HEMI: hemo-corrected vs uncorrected','FontSize',6,'FontWeight','bold');
exportgraphics(fig, fullfile(dd,'cp_hemo_ablation.png'), 'Resolution',300);
fprintf('exported %s\n', fullfile(dd,'cp_hemo_ablation.png'));

%% ================= local helper: whole-hemi pooled RRR (mirrors CP-HEMI S08) ==================
function poolR2 = hemi_pool(Uflat, V, contra_mask, ipsi_mask, tr, te, K, maxPix, nY, nX) %#ok<INUSD>
% contra redoSVD -> regressor modes ; ipsi redoSVD -> target field ; CanonCor2 rank sweep.
idx_c   = find(contra_mask(:));
[~, Vc] = redoSVD(double(Uflat(idx_c,:)), V);   Vc = double(Vc);
idx_i_full = find(ipsi_mask(:));
[Ui_raw, Vi] = redoSVD(double(Uflat(idx_i_full,:)), V);  Ui_raw=double(Ui_raw); Vi=double(Vi);
idx_i = idx_i_full;
if numel(idx_i) > maxPix, idx_i = idx_i(1:ceil(numel(idx_i)/maxPix):end); end
[~, sel] = ismember(idx_i, idx_i_full);
Uips = Ui_raw(sel, 1:K);                                  % [P x K]

Xtr = zscore(Vc(1:K,tr),[],2)';   Xte = zscore(Vc(1:K,te),[],2)';    % [n x K]
Ytr = (Uips * Vi(1:K,tr))';       Yte = (Uips * Vi(1:K,te))';        % [n x P]
[a,b,~] = CanonCor2({Ytr},{Xtr});
poolR2 = nan(K,1);
for n=1:K
    Yhat = Xte * b(:,1:n) * a(:,1:n)';
    poolR2(n) = sseExplainedCal(Yte(:)', Yhat(:)');
end
end
