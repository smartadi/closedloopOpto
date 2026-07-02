function cp_pixel_recon(P)
% cp_pixel_recon — PIXEL-isolated contra->ipsi reconstruction.
% ------------------------------------------------------------------------------
% Predict the ipsi primary pixel using ONLY the top-weight contra PIXELS (not the
% top canonical components). Because the contra SVD spatial modes are orthonormal,
% the [CP-HEMI] readout is a pixelwise weighted sum,
%     yhat(t) = sum_p  pixw(p) * contra_activity(p,t),
% so restricting to a pixel subset = summing over those pixels only:
%     yhat_topM(t) = V(:,t)' * ( U(topM,:)' * pixw(topM) ).
% Rank contra pixels by |pixw|, accumulate top f%, DC-align on train, score held-out
% primary-pixel R^2 -> "how large a contra region do we need?". Contrast with the
% component recon: 1 canonical component ~ 90%, but that mode is spatially SPREAD, so
% a focal high-weight region alone predicts poorly (distributed coupling).
%
% INPUT P (struct): pixw[Npix x1] signed per-contra-pixel weight (rank-kbest map);
%   U_K[Npix x K] contra SVD spatial loadings (U_svd_raw(:,1:K)); Vte[K x nTe],
%   Vtr[K x nTr] contra modes on held-out/train frames; yte[nTe x1], ytr[nTr x1]
%   actual primary %dF/F; mI_kern; idx_c[Npix x1] contra linear indices; nY,nX,mimg;
%   px_prim,py_prim; Fs; segL; paper_root.
pixw = P.pixw(:);  Npix = numel(pixw);  K = size(P.U_K,2);
[~, ord] = sort(abs(pixw), 'descend');           % rank contra pixels by |weight|
r2 = @(yh) sseExplainedCal(P.yte(:).', yh(:).');
predW = @(w) (P.Vte.'*w)*(100/P.mI_kern);        % held-out prediction for mode-weight w
dcW   = @(w) mean(P.ytr - (P.Vtr.'*w)*(100/P.mI_kern));   % causal DC align on train

fracs = [0.0005 0.001 0.002 0.005 0.01 0.02 0.05 0.1 0.2 0.5 1.0];
R2p = nan(size(fracs));  npx = nan(size(fracs));
for i = 1:numel(fracs)
    m = max(1, round(fracs(i)*Npix));  npx(i) = m;  sel = ord(1:m);
    w = P.U_K(sel,:).' * pixw(sel);              % effective mode weight from ONLY the top pixels
    R2p(i) = r2(predW(w) + dcW(w));
end
fullR2 = R2p(end);
f90 = find(R2p >= 0.90*fullR2, 1);  f95 = find(R2p >= 0.95*fullR2, 1);
fprintf('\n[CP-PXRECON] pixel-isolated recon (contra %d px | full R^2=%.3f):\n', Npix, fullR2);
for i = 1:numel(fracs)
    fprintf('   top %6.2f%% (%6d px): R^2=%+.3f (%.0f%% of full)\n', 100*fracs(i), npx(i), R2p(i), 100*R2p(i)/max(fullR2,eps));
end
fprintf('   -> 90%% of full needs top %.2f%% (%d px) | 95%% needs top %.2f%% (%d px)  [distributed, NOT focal]\n', ...
    100*fracs(f90), npx(f90), 100*fracs(f95), npx(f95));

% ---- figure ------------------------------------------------------------------
A = P.mimg.'; glo=prctile(A(:),1); ghi=max(prctile(A(:),99),glo+eps); gimg=min(max((A-glo)/(ghi-glo),0),1);
fig = figure('Color','w','Position',[60 60 1250 620]);
subplot(2,3,1);                                    % R^2 vs region size
semilogx(100*fracs, R2p, '-o','Color',[0.1 0.35 0.9],'MarkerFaceColor',[0.1 0.35 0.9],'MarkerSize',4); hold on;
yline(fullR2,'k:'); yline(0.9*fullR2,'r:','90%');
xlabel('top contra pixels (% of hemisphere)','FontWeight','bold'); ylabel('primary-pixel R^2','FontWeight','bold');
title('Pixel-isolated recon vs region size','FontWeight','bold'); grid on; set(gca,'Box','off','TickDir','out');
subplot(2,3,2);                                    % signed weight map
wlim = prctile(abs(pixw),99); if wlim<eps, wlim=1; end
km = nan(P.nY,P.nX); km(P.idx_c) = pixw;
cmapK=[linspace(0.23,1,128)',linspace(0.30,1,128)',linspace(0.75,1,128)';linspace(1,0.80,128)',linspace(1,0.10,128)',linspace(1,0.10,128)'];
image(cp_weight_composite(P.mimg.',km.',cmapK,[-wlim wlim])); axis image off; hold on;
plot(P.px_prim,P.py_prim,'g+','MarkerSize',10,'LineWidth',2); title('contra weight map (all pixels)','FontWeight','bold');
subplot(2,3,3);                                    % example held-out segment: top5% vs full
nSeg = floor(size(P.Vte,2)/P.segL);  sPick = max(1,round(nSeg/2));
sel5 = ord(1:round(0.05*Npix)); w5 = P.U_K(sel5,:).'*pixw(sel5);
wF   = P.U_K.'*pixw;
idx = (sPick-1)*P.segL + (1:P.segL); tt=(0:P.segL-1)/P.Fs;
yh5 = (P.Vte(:,idx).'*w5)*(100/P.mI_kern) + dcW(w5);
yhF = (P.Vte(:,idx).'*wF)*(100/P.mI_kern) + dcW(wF);
plot(tt,P.yte(idx),'k','LineWidth',1.3); hold on; plot(tt,yhF,'b','LineWidth',1.2); plot(tt,yh5,'Color',[0.9 0.5 0],'LineWidth',1.2);
legend({'actual','full','top5%'},'Box','off','FontSize',7); title(sprintf('held-out seg %d',sPick),'FontWeight','bold');
xlabel('time (s)','FontWeight','bold'); ylabel('\DeltaF/F (%)','FontWeight','bold'); set(gca,'Box','off','TickDir','out');
tf = [0.01 0.05 0.20];                             % spatial masks
for i = 1:3
    subplot(2,3,3+i); m=round(tf(i)*Npix); sel=ord(1:m);
    ov=repmat(gimg,1,1,3); msk=false(P.nY,P.nX); msk(P.idx_c(sel))=true; mskT=msk.';
    Rr=ov(:,:,1);Gg=ov(:,:,2);Bb=ov(:,:,3); Rr(mskT)=1;Gg(mskT)=0.2;Bb(mskT)=0.1; ov=cat(3,Rr,Gg,Bb);
    image(ov); axis image off; hold on; plot(P.px_prim,P.py_prim,'g+','MarkerSize',10,'LineWidth',2);
    title(sprintf('top %.0f%% pixels (R^2=%.2f)',100*tf(i),R2p(abs(fracs-tf(i))<1e-9)),'FontWeight','bold');
end
sgtitle('CP-PXRECON pixel-isolated contra->ipsi (predict from only the top-weight contra pixels)','FontWeight','bold');
exportgraphics(fig, fullfile(P.paper_root,'cp_pxrecon.png'), 'Resolution',200);
fprintf('[CP-PXRECON] exported cp_pxrecon.png\n');
end
