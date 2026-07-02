function cp_clean_predict(P)
% cp_clean_predict — marry [CP-KRECON] (S10) and [CP-BLEED] (S11): predict the ipsi
% primary pixel from ONLY the bleed-free contra pixels.
% ------------------------------------------------------------------------------
% [CP-KRECON] ranks contra pixels by predictive weight |pixw|; [CP-BLEED] flags the
% contra pixels whose activity is amplitude-graded (ipsi->contra leakage, |beta|).
% If the contra->ipsi prediction were riding on that leakage, dropping the bleed
% pixels would gut it. This section shows it does NOT: the predictive population and
% the bleed population are spatially DISJOINT, so removing every bleed-suspect pixel
% costs almost nothing while the pixels that actually carry the prediction are a
% different, distributed set.
%
% Because the contra SVD spatial modes are orthonormal, the [CP-HEMI] readout is a
% pixelwise weighted sum yhat(t)=V(:,t)'*(U(keep,:)'*pixw(keep)); restricting to a
% pixel subset needs NO refit (same identity as cp_pixel_recon).
%
% Three exclusion curves vs % contra pixels removed:
%   BLEED       remove top-B% by |beta|  (the confound test — should stay flat)
%   PREDICTIVE  remove top-B% by |pixw|  (upper bound — should collapse)
%   RANDOM      remove B% at random      (dilution baseline)
% + "keep only bleed-free" point (drop every pixel with bleed p<alpha).
%
% INPUT P (struct): pixw[Npix x1] signed predictive weight (h_pixw); U_K[Npix x K]
%   contra SVD loadings (U_svd_raw(:,1:h_K)); Vte[K x nTe],Vtr[K x nTr] contra modes
%   on held-out/train frames; yte[nTe x1],ytr[nTr x1] actual primary %dF/F; mI_kern;
%   idx_c[Npix x1] contra linear idx (pixw/U_K row order); b_beta[Nb x1] bleed slope,
%   b_p[Nb x1] bleed perm p-value, b_idx_c[Nb x1] their contra linear idx; nY,nX,mimg;
%   px_prim,py_prim; paper_root; (optional) alpha (default 0.05).
pixw = P.pixw(:);  Npix = numel(pixw);  K = size(P.U_K,2);
alpha = 0.05;  if isfield(P,'alpha') && ~isempty(P.alpha), alpha = P.alpha; end

% --- align the bleed map onto the predictive pixel order (idx match) --------------
[tf, loc] = ismember(P.idx_c, P.b_idx_c);
if ~all(tf)
    error('cp_clean_predict: %d predictive pixels have no bleed entry — idx_c / b_idx_c mismatch.', nnz(~tf));
end
beta = P.b_beta(loc);  bp = P.b_p(loc);        % bleed slope + p aligned to pixw rows
abeta = abs(beta);

% --- no-refit R^2 for an arbitrary keep-mask --------------------------------------
sc = 100/P.mI_kern;
r2keep = @(keep) sseExplainedCal( P.yte(:).', ...
    ( (P.Vte.'*(P.U_K(keep,:).'*pixw(keep)))*sc ...
      + mean( P.ytr - (P.Vtr.'*(P.U_K(keep,:).'*pixw(keep)))*sc ) ).' );
fullR2 = r2keep(true(Npix,1));

% --- disjointness: is a big predictive weight also a big bleed slope? --------------
rho = corr(abeta, abs(pixw), 'type','Spearman','rows','complete');

% --- exclusion sweep --------------------------------------------------------------
[~,ordB] = sort(abeta,  'descend');            % most-bleed first
[~,ordP] = sort(abs(pixw),'descend');          % most-predictive first
ordR = mod((0:Npix-1)*2654435761, Npix) + 1;   % deterministic pseudo-shuffle (no rng)
Bpct = [0 0.005 0.01 0.02 0.05 0.1 0.2 0.3 0.5];
r2B = nan(size(Bpct));  r2P = nan(size(Bpct));  r2R = nan(size(Bpct));
for i = 1:numel(Bpct)
    m = round(Bpct(i)*Npix);
    kB=true(Npix,1); kB(ordB(1:m))=false; r2B(i)=r2keep(kB);
    kP=true(Npix,1); kP(ordP(1:m))=false; r2P(i)=r2keep(kP);
    kR=true(Npix,1); kR(ordR(1:m))=false; r2R(i)=r2keep(kR);
end

% --- keep ONLY bleed-free pixels (drop every pixel with bleed p<alpha) ------------
keepClean = bp >= alpha;
r2Clean = r2keep(keepClean);
nDrop = nnz(~keepClean);

fprintf('\n[CP-CLEAN] marry KRECON+BLEED — predict from bleed-free contra pixels (%s %s e%d):\n', ...
    getf(P,'mn','?'), getf(P,'td','?'), getf(P,'en',0));
fprintf('   full R^2 = %.3f  | disjointness rho(|beta|,|pixw|) = %+.3f\n', fullR2, rho);
fprintf('   exclude top 5%%:  BLEED R^2=%.3f (%+.3f) | PREDICTIVE R^2=%.3f (%+.3f) | RANDOM R^2=%.3f\n', ...
    r2B(Bpct==0.05), r2B(Bpct==0.05)-fullR2, r2P(Bpct==0.05), r2P(Bpct==0.05)-fullR2, r2R(Bpct==0.05));
fprintf('   keep ONLY bleed-free (p>=%.2f, drop %d of %d px): R^2=%.3f (%+.3f vs full)\n', ...
    alpha, nDrop, Npix, r2Clean, r2Clean-fullR2);

% --- figure -----------------------------------------------------------------------
A=P.mimg.'; glo=prctile(A(:),1); ghi=max(prctile(A(:),99),glo+eps); gim=min(max((A-glo)/(ghi-glo),0),1);
fig = figure('Color','w','Position',[70 70 1180 480]);
subplot(1,2,1); hold on;
plot(100*Bpct,r2B,'-o','Color',[0.1 0.35 0.9],'LineWidth',1.5,'MarkerFaceColor',[0.1 0.35 0.9]);
plot(100*Bpct,r2P,'-s','Color',[0.85 0.2 0.1],'LineWidth',1.5,'MarkerFaceColor',[0.85 0.2 0.1]);
plot(100*Bpct,r2R,'-^','Color',[0.5 0.5 0.5],'LineWidth',1.2);
yline(fullR2,'k:');
plot(100*nDrop/Npix, r2Clean, 'p','Color',[0 0.6 0.2],'MarkerFaceColor',[0 0.6 0.2],'MarkerSize',11);
xlabel('% contra pixels EXCLUDED','FontWeight','bold'); ylabel('primary-pixel R^2','FontWeight','bold');
legend({'exclude most-BLEED','exclude most-PREDICTIVE','exclude RANDOM','full', ...
        sprintf('keep bleed-free (p>=%.2f)',alpha)}, 'Location','southwest','Box','off','FontSize',8);
title('Bleed pixels are dispensable for prediction','FontWeight','bold');
set(gca,'Box','off','TickDir','out'); grid on;

subplot(1,2,2);
mfrac = 0.02;  mm = round(mfrac*Npix);
mB=false(P.nY,P.nX); mB(P.idx_c(ordB(1:mm)))=true;
mP=false(P.nY,P.nX); mP(P.idx_c(ordP(1:mm)))=true;
mBt=mB'; mPt=mP'; Rr=gim; Gg=gim; Bb=gim;
Rr(mBt)=1;   Gg(mBt)=0.15; Bb(mBt)=0.15;          % bleed = red
Rr(mPt)=0.15;Gg(mPt)=0.30; Bb(mPt)=1;             % predictive = blue
Rr(mBt&mPt)=1;Gg(mBt&mPt)=1; Bb(mBt&mPt)=0.1;     % overlap = yellow
image(cat(3,Rr,Gg,Bb)); axis image off; hold on;
plot(P.px_prim,P.py_prim,'g+','MarkerSize',10,'LineWidth',2);
title(sprintf('top %.0f%% BLEED (red) vs PREDICTIVE (blue) — overlap %d px', 100*mfrac, nnz(mB&mP)), ...
    'FontWeight','bold');
sgtitle('CP-CLEAN: predict ipsi from bleed-free contra pixels (KRECON x BLEED)','FontWeight','bold');
exportgraphics(fig, fullfile(P.paper_root,'cp_clean_predict.png'), 'Resolution',200);
fprintf('[CP-CLEAN] exported cp_clean_predict.png\n');
end

function v = getf(S,f,d)
if isfield(S,f) && ~isempty(S.(f)); v = S.(f); else; v = d; end
end
