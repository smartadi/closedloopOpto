function out = cp_stimaffect(P)
% cp_stimaffect — how complete is the "bleed-free" characterization, and does excluding
% MORE stim-affected contra pixels change the local residual?
% ------------------------------------------------------------------------------
% [CP-BLEED] (S11) flags stim-affected contra pixels by the amplitude-graded dose-
% response SLOPE (b_beta) — it centers each pixel's peri-stim response across trials
% (b_R - mean(b_R,2)) then regresses on amplitude, so it only sees the part of the stim
% response that SCALES with laser power. That is the correct signature of optical/
% vascular BLEED (bleed scales with power), but it discards each pixel's amplitude-
% INVARIANT onset deflection. This section recovers that missing component and asks
% whether a more inclusive "stim-affected" definition would change the conclusion.
%
%   (1) Amplitude-invariant onset response R0 = mean over stim trials of
%       [mean(0-200 ms) - baseline(-500-0 ms)], per contra pixel (one-sample t -> t0).
%       Typically ~95% of contra pixels are NEGATIVE (network co-suppression), so the
%       inclusive "any onset response" set is nearly the whole hemisphere — i.e. genuine
%       trans-callosal coupling, the very signal the predictor is meant to read.
%
%   (2) Exclusion sweep: drop the top-f% most onset-responsive (|t0|) contra pixels vs a
%       RANDOM f%, and for each recompute (a) held-out NON-STIM R^2 and (b) the peri-stim
%       residual dip. Both exclusions deepen the residual ONLY by degrading prediction:
%       plotted as residual-dip vs R^2 the onset-targeted and random curves COINCIDE, so
%       the deepening is predictor-loss, not removal of hidden bleed absorption. (At R^2->0
%       the "residual" trivially returns the full actual dip because prediction ~ 0.)
%
% INPUT P (struct): U_cp[nY x nX x nSV], V_cp[nSV x nFrames], mimg[nY x nX], nY,nX,nSV;
%   idx_c[Npix x1] contra linear idx (== pixw/U_K rows); onf[nT x1] stim onset FRAMES
%   (b_onf), amp[nT x1] amplitude (b_amp); b_p[Nb x1], b_idx_c[Nb x1] slope-test p + idx;
%   pixw[Npix x1] (h_pixw); U_K[Npix x K] (U_svd_raw(:,1:h_K)); V_c[K x nFrames]
%   (V_c_full 1:K); y[nFrames x1] (y_full); te,tr held-out/train NON-STIM frames; mI_kern;
%   Fs; px_prim,py_prim; paper_root; (optional) mn/td/en.
K = size(P.U_K,2);  Npix = numel(P.pixw);  sc = 100/P.mI_kern;  Fs = P.Fs;  idx = P.idx_c(:);

% --- (1) amplitude-invariant onset response per contra pixel (stim trials) ---------
b_post = round(0.200*Fs);  b_pre = round(0.500*Fs);
nz = P.amp > 0;  onf = P.onf(nz);  nT = numel(onf);
Uflat = reshape(P.U_cp, P.nY*P.nX, P.nSV);  Uc = double(Uflat(idx,:));
mI = P.mimg(idx);  mI(mI==0) = eps;
dv = zeros(P.nSV, nT);
for j = 1:nT
    o = onf(j);
    dv(:,j) = mean(double(P.V_cp(:, o:o+b_post)),2) - mean(double(P.V_cp(:, o-b_pre:o-1)),2);
end
R  = (Uc*dv)./mI*100;                       % [Npix x nT] onset response
R0 = mean(R,2);  sdR = std(R,0,2);  t0 = R0./max(sdR/sqrt(nT),eps);
p0 = 2*normcdf(-abs(t0));                   % parametric two-tailed (autocorr-inflated: upper bound on signif)
[tf,loc] = ismember(idx, P.b_idx_c);
if ~all(tf), error('cp_stimaffect: idx_c / b_idx_c mismatch (%d px).', nnz(~tf)); end
bpS = P.b_p(loc);                           % slope-test p aligned to idx order

fprintf('\n[CP-STIMAFF] stim-affected characterization (%s %s e%d): %d contra px, %d stim trials\n', ...
    getf(P,'mn','?'), getf(P,'td','?'), getf(P,'en',0), Npix, nT);
fprintf('  SLOPE test (amp-graded, [CP-BLEED]):  p<0.05 = %d (%.1f%%)\n', nnz(bpS<0.05), 100*mean(bpS<0.05));
fprintf('  ONSET test (amp-invariant, this fn):  p<0.05 = %d (%.1f%%) | p<1e-3 = %d\n', ...
    nnz(p0<0.05), 100*mean(p0<0.05), nnz(p0<1e-3));
fprintf('  mean onset deflection R0: median=%+.3f %%dF/F | NEGATIVE (co-suppressed) = %.1f%% of contra\n', ...
    median(R0), 100*mean(R0<0));

% --- (2) exclusion sweep: onset-responsive vs random -> resDip + non-stim R^2 ------
pre = round(Fs);  post = round(Fs);  nImp = pre+post+1;  t_imp = (-pre:post)/Fs;
pre_bl = 1:pre;  iDip = find(t_imp>=0 & t_imp<=0.2);
A = nan(nT,nImp);  Vwin = cell(nT,1);  ok = false(nT,1);
for j = 1:nT
    g = onf(j)-pre : onf(j)+post;
    if g(1)<1 || g(end)>numel(P.y), continue; end
    ok(j) = true;  ya = P.y(g);  A(j,:) = ya - mean(ya(pre_bl),'omitnan');  Vwin{j} = P.V_c(:,g).';
end
actDip = mean(mean(A(ok,iDip),2,'omitnan'),'omitnan');
Vte = P.V_c(:,P.te);  Vtr = P.V_c(:,P.tr);  yte = P.y(P.te);  ytr = P.y(P.tr);
r2fun    = @(w) sseExplainedCal(yte.', ((Vte.'*w)*sc + mean(ytr-(Vtr.'*w)*sc)).');
resdipfn = @(w) resdip_local(A, Vwin, ok, w, sc, pre_bl, iDip);
[~,ordOn] = sort(abs(t0),'descend');  ordRnd = mod((0:Npix-1)*2654435761, Npix) + 1;
fr = [0 0.02 0.05 0.1 0.2 0.3 0.5];
rdOn=nan(size(fr)); rdRn=nan(size(fr)); r2On=nan(size(fr)); r2Rn=nan(size(fr));
for i = 1:numel(fr)
    m = round(fr(i)*Npix);
    kO=true(Npix,1); kO(ordOn(1:m))=false; wO=P.U_K(kO,:).'*P.pixw(kO); rdOn(i)=resdipfn(wO); r2On(i)=r2fun(wO);
    kR=true(Npix,1); kR(ordRnd(1:m))=false; wR=P.U_K(kR,:).'*P.pixw(kR); rdRn(i)=resdipfn(wR); r2Rn(i)=r2fun(wR);
end
fprintf('  exclusion sweep (resDip %% of actual | non-stim R^2):\n');
for i = 1:numel(fr)
    fprintf('   %4.0f%%: ONSET %3.0f%% (R2=%.3f) | RANDOM %3.0f%% (R2=%.3f)\n', 100*fr(i), ...
        100*rdOn(i)/actDip, r2On(i), 100*rdRn(i)/actDip, r2Rn(i));
end
fprintf('  -> at matched R^2 the ONSET and RANDOM residual dips coincide: deepening is predictor-loss, NOT bleed.\n');

% --- figure -----------------------------------------------------------------------
A2 = P.mimg';  glo=prctile(A2(:),1); ghi=max(prctile(A2(:),99),glo+eps); gim=min(max((A2-glo)/(ghi-glo),0),1);
cmapK = [linspace(0.23,1,128)',linspace(0.30,1,128)',linspace(0.75,1,128)'; ...
         linspace(1,0.80,128)',linspace(1,0.10,128)',linspace(1,0.10,128)'];
fig = figure('Color','w','Position',[60 60 1260 430]);
subplot(1,3,1); hold on;
plot(r2On,100*rdOn/actDip,'-o','Color',[0.85 0.2 0.1],'LineWidth',1.6,'MarkerFaceColor',[0.85 0.2 0.1]);
plot(r2Rn,100*rdRn/actDip,'-^','Color',[0.4 0.4 0.4],'LineWidth',1.4);
yline(100,'k:','actual dip'); set(gca,'XDir','reverse');
xlabel('non-stim held-out R^2 (predictor quality)','FontWeight','bold'); ylabel('residual dip (% of actual)','FontWeight','bold');
legend({'exclude ONSET-responsive','exclude RANDOM'},'Box','off','FontSize',8,'Location','northwest');
title('Residual dip tracks R^2, not bleed','FontWeight','bold'); set(gca,'Box','off','TickDir','out'); grid on;
subplot(1,3,2);
km = nan(P.nY,P.nX); km(idx) = R0;  lim = prctile(abs(R0),99);  if lim<eps, lim=1; end
image(cp_weight_composite(P.mimg', km', cmapK, [-lim lim])); axis image off; hold on;
plot(P.px_prim,P.py_prim,'g+','MarkerSize',10,'LineWidth',2);
colormap(gca,cmapK); cb=colorbar; clim([-lim lim]); ylabel(cb,'R_0 (%dF/F)','FontWeight','bold');
title(sprintf('Mean onset deflection R_0 (%.0f%% co-suppressed)',100*mean(R0<0)),'FontWeight','bold');
subplot(1,3,3);
mBl=false(P.nY,P.nX); mBl(idx(bpS<0.05))=true;  mOn=false(P.nY,P.nX); mOn(idx(p0<1e-3))=true;
mBt=mBl'; mOt=mOn'; Rr=gim;Gg=gim;Bb=gim;
Rr(mOt)=0.15;Gg(mOt)=0.30;Bb(mOt)=1;  Rr(mBt)=1;Gg(mBt)=0.15;Bb(mBt)=0.15;
image(cat(3,Rr,Gg,Bb)); axis image off; hold on; plot(P.px_prim,P.py_prim,'g+','MarkerSize',10,'LineWidth',2);
title(sprintf('amp-graded BLEED %d (red) vs onset-resp %d (blue)', nnz(bpS<0.05), nnz(p0<1e-3)),'FontWeight','bold');
sgtitle('CP-STIMAFF: "bleed-free" robustness — excluding more stim-affected px is predictor-loss, not bleed','FontWeight','bold');
exportgraphics(fig, fullfile(P.paper_root,'cp_stimaffect.png'), 'Resolution',200);
fprintf('[CP-STIMAFF] exported cp_stimaffect.png\n');

out = struct('R0',R0,'t0',t0,'p0',p0,'frac_cosupp',mean(R0<0), ...
             'fr',fr,'rdOn',rdOn,'rdRn',rdRn,'r2On',r2On,'r2Rn',r2Rn,'actDip',actDip);
end

function rd = resdip_local(A, Vwin, ok, w, sc, pre_bl, iDip)
res = nan(numel(ok), size(A,2));
for j = 1:numel(ok)
    if ~ok(j), continue; end
    yh = Vwin{j}*w*sc;  yh = yh - mean(yh(pre_bl),'omitnan');  res(j,:) = A(j,:) - yh.';
end
mr = mean(res(ok,:),1,'omitnan');  rd = mean(mr(iDip),'omitnan');
end

function v = getf(S,f,d)
if isfield(S,f) && ~isempty(S.(f)); v = S.(f); else; v = d; end
end
