function out = cp_cleanres(P)
% cp_cleanres — deploy the BLEED-FREE contra predictor: does the stim residual survive?
% ------------------------------------------------------------------------------
% [CP-CLEAN] (S12) showed the predictive and bleed pixel populations are disjoint, so
% dropping every bleed-suspect contra pixel leaves the held-out (non-stim) prediction
% unchanged. This section deploys that bleed-free predictor two ways:
%
%   (A) NON-STIM prediction quality  — held-out primary-pixel R^2, full vs bleed-free.
%       Both should be ~equal (the predictive signal lives in the bleed-free pixels).
%
%   (B) STIM-TRIAL residual          — apply full and bleed-free predictors to the REAL
%       peri-stim windows and form residual = actual_ipsi - contra_prediction. During
%       stim the bleed pixels carry the ipsi->contra leaked stim signal, so a FULL
%       predictor *could* absorb part of the local response through them; a bleed-free
%       predictor CANNOT. If the two residual dips (0-200 ms) match, the isolated local
%       stim effect is NOT a bleed-absorption artifact — it is genuine local response,
%       and the ~identical contra absorption is distributed network co-suppression.
%
% Same no-refit identity as CP-CLEAN / cp_pixel_recon: with orthonormal contra SVD
% modes, restricting the readout to a pixel subset is w_keep = U(keep,:)'*pixw(keep);
% the deployed prediction is V(:,g)'*w_keep*(100/mI_kern) (+ causal DC align).
%
% INPUT P (struct): pixw[Npix x1] signed predictive weight (h_pixw); U_K[Npix x K]
%   contra SVD loadings (U_svd_raw(:,1:h_K)); V_c[K x nFrames] contra modes (V_c_full,
%   rows 1:K); y[nFrames x1] primary-pixel %dF/F trace (y_full); te[.],tr[.] held-out /
%   train NON-STIM frame indices (h_te,h_tr); mI_kern; idx_c[Npix x1] contra linear idx
%   (pixw row order); b_p[Nb x1] bleed perm p-value, b_idx_c[Nb x1] its idx; onf[nT x1]
%   stim onset FRAMES (b_onf), amp[nT x1] per-trial amplitude (b_amp); Fs; paper_root;
%   (optional) alpha (0.05), mn/td/en.
pixw = P.pixw(:);  Npix = numel(pixw);  K = size(P.U_K,2);
alpha = 0.05;  if isfield(P,'alpha') && ~isempty(P.alpha), alpha = P.alpha; end
sc = 100/P.mI_kern;

% --- align bleed p onto pixw pixel order, build the two readouts ------------------
[tf, loc] = ismember(P.idx_c, P.b_idx_c);
if ~all(tf), error('cp_cleanres: %d predictive pixels lack a bleed entry (idx mismatch).', nnz(~tf)); end
bp = P.b_p(loc);  keep = bp >= alpha;                 % bleed-free contra pixels
w_full  = P.U_K.'          * pixw;                    % full readout (mode space) == wraw
w_clean = P.U_K(keep,:).'  * pixw(keep);              % bleed-free readout (no refit)

fprintf('\n[CP-CLEANRES] bleed-free predictor (%s %s e%d): %d contra px, %d bleed-free / %d dropped (p<%.2f)\n', ...
    getf(P,'mn','?'), getf(P,'td','?'), getf(P,'en',0), Npix, nnz(keep), nnz(~keep), alpha);

% --- (A) held-out NON-STIM primary-pixel R^2 -------------------------------------
r2 = @(w) sseExplainedCal( P.y(P.te).', ...
        ( (P.V_c(:,P.te).'*w)*sc + mean( P.y(P.tr) - (P.V_c(:,P.tr).'*w)*sc ) ).' );
r2full = r2(w_full);  r2clean = r2(w_clean);
fprintf('  (A) NON-STIM held-out R^2:  FULL=%.3f | bleed-free=%.3f  (Delta=%+.4f)\n', ...
    r2full, r2clean, r2clean-r2full);

% --- (B) STIM-TRIAL peri-stim residual -------------------------------------------
Fs = P.Fs;  pre = round(Fs);  post = round(Fs);  nImp = pre+post+1;
t_imp = (-pre:post)/Fs;  pre_bl = 1:pre;  iDip = find(t_imp >= 0 & t_imp <= 0.2);
nz = P.amp > 0;  onf = P.onf(nz);  amp = P.amp(nz);  nT = numel(onf);
A = nan(nT,nImp);  PF = nan(nT,nImp);  PC = nan(nT,nImp);
for j = 1:nT
    g = onf(j)-pre : onf(j)+post;
    if g(1) < 1 || g(end) > numel(P.y), continue; end
    ya = P.y(g);  A(j,:) = ya - mean(ya(pre_bl),'omitnan');
    vp = P.V_c(:,g).';
    yhF = vp*w_full*sc;   PF(j,:) = yhF - mean(yhF(pre_bl),'omitnan');
    yhC = vp*w_clean*sc;  PC(j,:) = yhC - mean(yhC(pre_bl),'omitnan');
end
rF = A - PF;  rC = A - PC;
mA=mean(A,1,'omitnan'); mPF=mean(PF,1,'omitnan'); mPC=mean(PC,1,'omitnan');
mrF=mean(rF,1,'omitnan'); mrC=mean(rC,1,'omitnan');
dip = @(m) mean(m(iDip),'omitnan');
fprintf('  (B) STIM residual dip 0-200 ms (%d trials): actual=%+.3f | FULL res=%+.3f (%.0f%% of dip) | bleed-free res=%+.3f (%.0f%%)\n', ...
    nT, dip(mA), dip(mrF), 100*dip(mrF)/dip(mA), dip(mrC), 100*dip(mrC)/dip(mA));

% --- per-amplitude (bleed strongest at high amp -> gap must stay small) -----------
uA = unique(amp);  nAmp = numel(uA);
dipA=nan(nAmp,1); dipRF=nan(nAmp,1); dipRC=nan(nAmp,1);
for ia = 1:nAmp
    m = amp==uA(ia);
    dipA(ia)=dip(mean(A(m,:),1,'omitnan'));
    dipRF(ia)=dip(mean(rF(m,:),1,'omitnan'));
    dipRC(ia)=dip(mean(rC(m,:),1,'omitnan'));
end
maxgap = max(abs(dipRC-dipRF));
fprintf('  (B) per-amp residual dip gap |bleed-free - full|: max=%.4f %%dF/F over %d amps  [<~0.03 -> no bleed absorption]\n', ...
    maxgap, nAmp);

% --- figure -----------------------------------------------------------------------
fig = figure('Color','w','Position',[70 70 1200 450]);
subplot(1,3,1); hold on;
plot(t_imp,mA,'k','LineWidth',1.6); plot(t_imp,mPF,'Color',[0.85 0.2 0.1],'LineWidth',1.2);
plot(t_imp,mPC,'Color',[0.1 0.35 0.9],'LineWidth',1.2);
xline(0,'k:'); yline(0,'k:'); xlim([-0.5 1]);
xlabel('time re onset (s)','FontWeight','bold'); ylabel('\DeltaF/F (%)','FontWeight','bold');
legend({'actual ipsi','FULL pred','bleed-free pred'},'Box','off','FontSize',8,'Location','southeast');
title('Peri-stim: actual vs predictions','FontWeight','bold'); set(gca,'Box','off','TickDir','out');
subplot(1,3,2); hold on;
yl = [min(mA)*1.1 max([mrF mrC 0.5])];
patch([0 0.2 0.2 0],[yl(1) yl(1) yl(2) yl(2)],[0.95 0.9 0.55],'FaceAlpha',0.35,'EdgeColor','none');
plot(t_imp,mrF,'Color',[0.85 0.2 0.1],'LineWidth',1.6); plot(t_imp,mrC,'Color',[0.1 0.35 0.9],'LineWidth',1.4);
plot(t_imp,mA,'k:','LineWidth',1.0); xline(0,'k:'); yline(0,'k:'); xlim([-0.5 1]); ylim(yl);
xlabel('time re onset (s)','FontWeight','bold'); ylabel('residual \DeltaF/F (%)','FontWeight','bold');
legend({'0-200 ms','residual (FULL)','residual (bleed-free)','actual'},'Box','off','FontSize',8,'Location','southeast');
title('Local stim residual survives (bleed-free \approx full)','FontWeight','bold'); set(gca,'Box','off','TickDir','out');
subplot(1,3,3); hold on;
bh=bar(uA,[dipRF dipRC],'grouped'); bh(1).FaceColor=[0.85 0.2 0.1]; bh(2).FaceColor=[0.1 0.35 0.9];
plot(uA,dipA,'ko-','LineWidth',1.2,'MarkerFaceColor','k');
xlabel('stim amplitude','FontWeight','bold'); ylabel('residual dip 0-200 ms (%dF/F)','FontWeight','bold');
legend({'FULL','bleed-free','actual dip'},'Box','off','FontSize',8,'Location','southwest');
title(sprintf('Per-amplitude residual dip (max gap %.3f)',maxgap),'FontWeight','bold'); set(gca,'Box','off','TickDir','out');
sgtitle('CP-CLEANRES: bleed-free predictor on STIM trials — local residual is preserved','FontWeight','bold');
exportgraphics(fig, fullfile(P.paper_root,'cp_cleanres.png'), 'Resolution',200);
fprintf('[CP-CLEANRES] exported cp_cleanres.png\n');

out = struct('r2full',r2full,'r2clean',r2clean,'keep',keep,'w_clean',w_clean, ...
             'dip_actual',dip(mA),'dip_resFull',dip(mrF),'dip_resClean',dip(mrC), ...
             'uA',uA,'dipRF',dipRF,'dipRC',dipRC,'maxgap',maxgap);
end

function v = getf(S,f,d)
if isfield(S,f) && ~isempty(S.(f)); v = S.(f); else; v = d; end
end
