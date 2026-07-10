% kernelmap_paint.m — PAPER KERNELMAP (paint edition).
% 6 ipsi targets in a TRIANGLE (rows of 1,2,3 as seen in the figure). Contra side: smooth PAINT
% (opacity = |contra weight|) + the sparse predictor grid on top, each grid pixel colored by the ipsi
% target it most strongly predicts (winner-take-all). Colorblind-safe (Okabe-Ito). No title/legend/axes
% (clean panel — export a high-res vector PDF for the paper once placement is decided).
%
% PREREQUISITE: run `ols_pixel_predictor_wip.m` FIRST (after `load_experiments.m`). This script reuses
% the live base-workspace variables it leaves behind: D, dspImg, dspGr, dspGc, mn, td, en. It does NOT
% reload data. Re-run this file any time to regenerate the panel from the current session.
Hd = size(dspImg,1);  Wd = size(dspImg,2);
gr = round(dspGr);  gc = round(dspGc);  nG = numel(gr);
vg = gr>=1 & gr<=Hd & gc>=1 & gc<=Wd;

% ---- ipsi targets selected in DISPLAY space (so "rows" match the figure): rows of 1,2,3 top->bottom ----
ipM = logical(D.ipsi);  [ir, ic] = find(ipM);
[idr, idc] = orient_fwd_local(D.T, ir, ic);            % display coords of every ipsi pixel
band = 0.16*(max(idr)-min(idr));
dlev = prctile(idr,[18 50 82]);  counts = [1 2 3];  qsets = {0.5, [0.30 0.70], [0.20 0.50 0.80]};
targ = zeros(0,2);
for k = 1:3
    m = abs(idr - dlev(k)) <= band;  if nnz(m) < 3, m = true(size(idr)); end
    qs = qsets{k};
    for j = 1:counts(k)
        ct = prctile(idc(m), qs(j)*100);
        d = (idr - dlev(k)).^2 + (idc - ct).^2;  d(~m) = inf;
        [~,mi] = min(d);  targ = [targ; ir(mi) ic(mi)]; %#ok<AGROW>
    end
end
targ = unique(targ,'rows','stable');  nTk = size(targ,1);

pal = [0.00 0.45 0.70;    % blue
       0.84 0.37 0.00;    % vermillion
       0.00 0.62 0.45;    % bluish green
       0.90 0.62 0.00;    % orange
       0.80 0.47 0.65;    % reddish purple
       0.34 0.71 0.91];   % sky blue
sigma = 20;  alphaMax = 0.62;  aFloor = 0.07;

figP = figure('Color','w','Position',[70 40 800 780]);
ax = axes(figP); hold(ax,'on');
image(ax, repmat(dspImg,[1 1 3]));  axis(ax,'image','off');  set(ax,'YDir','reverse');

B = zeros(nG,nTk);  cvA = zeros(nTk,1);
for t = 1:nTk
    [bpx,cvk,~,~,~] = ols_refit_local(D,targ(t,1),targ(t,2));
    B(:,t) = bpx;  cvA(t) = cvk;
    w = abs(bpx);
    F  = accumarray([gr(vg) gc(vg)], w(vg), [Hd Wd]);
    Fs = gsmooth(F, sigma);  Fs = Fs/max(Fs(:)+eps);
    A  = (alphaMax * max(0,(Fs-aFloor)/(1-aFloor))).^0.85;
    col = pal(t,:);
    rgb = cat(3, col(1)*ones(Hd,Wd), col(2)*ones(Hd,Wd), col(3)*ones(Hd,Wd));
    hI = image(ax, rgb);  set(hI,'AlphaData',A);
end

% discrete predictor GRID on top of the contra paint: each pixel = its winner target's color
Bn = abs(B) ./ (max(abs(B),[],1)+eps);
[wmax, wt] = max(Bn,[],2);
sh = wmax > 0.15 & vg(:);
scatter(ax, dspGc(sh), dspGr(sh), 6+50*wmax(sh), pal(wt(sh),:), 'filled', ...
        'MarkerEdgeColor',[.1 .1 .1], 'LineWidth',0.15, 'MarkerFaceAlpha',0.9);
scatter(ax, dspGc(~sh & vg(:)), dspGr(~sh & vg(:)), 4, [.55 .55 .55], 'filled', 'MarkerFaceAlpha',0.35);

for t = 1:nTk
    [tr,tc] = orient_fwd_local(D.T, targ(t,1), targ(t,2));
    plot(ax, tc, tr, 'o', 'MarkerSize',11, 'MarkerFaceColor',pal(t,:), 'MarkerEdgeColor','k', 'LineWidth',1.3);
end
% no title / legend / axis text — clean map for a later high-res PDF export
outp = fullfile('C:\Users\aditya\Documents\projects\brain_paper','paper','kernelmap_paint.png');
exportgraphics(figP, outp, 'Resolution', 300);
fprintf('SAVED %s  (%d targets)\n', outp, nTk);
% For the paper panel (vector), instead use:
%   exportgraphics(figP, fullfile('paper','kernelmap_paint.pdf'), 'ContentType','vector');

% ================= local helpers =================
function Fs = gsmooth(F, sigma)
r = ceil(3*sigma);  x = -r:r;  g = exp(-x.^2/(2*sigma^2));  g = g/sum(g);
Fs = conv2(g, g.', F, 'same');
end

function [bpix,cv,yte,yhat_te,nActive] = ols_refit_local(D,row,col)
kr = max(1,row-D.k):min(D.nY,row+D.k);  kc = max(1,col-D.k):min(D.nX,col+D.k);
[KR,KC] = ndgrid(kr,kc);  kidx = sub2ind([D.nY,D.nX],KR(:),KC(:));
mI = mean(D.mimg(kr,kc),'all');
y_all = (mean(D.Uflat(kidx,:),1)*D.V)/max(mI,eps)*100;
y_sp = double(y_all(D.frames)).';  ytr = y_sp(D.itr);  yte = y_sp(D.ite);
switch D.fit_mode
    case 'lasso'
        muy = mean(ytr);  c = D.Ztr.'*(ytr-muy);
        lam1 = D.l1_frac*max(abs(c));  lam2 = D.ridge*median(D.Gdiag);
        betaz = cd_lasso_local(D.G,c,D.Gdiag,lam1,lam2);
        S = find(betaz~=0);
        if D.debias && ~isempty(S)
            As = [ones(numel(D.itr),1) D.Ztr(:,S)];  cs = As\ytr;
            betaz = zeros(numel(betaz),1);  betaz(S) = cs(2:end);
            yhat_te = cs(1) + D.Ate(:,1+S)*cs(2:end);
        else
            yhat_te = muy + D.Ate(:,2:end)*betaz;
        end
    case 'ridge'
        coef = D.fitOp*ytr;  betaz = coef(2:end);  yhat_te = D.Ate*coef;
    otherwise
        coef = D.fitOp(ytr);  betaz = coef(2:end);  yhat_te = D.Ate*coef;
end
bpix = betaz ./ D.sd_p;
cv = 1 - sum((yte(:)-yhat_te(:)).^2)/max(sum((yte(:)-mean(yte(:))).^2),eps);
nActive = nnz(betaz);
end

function b = cd_lasso_local(G,c,dg,lam1,lam2)
if nargin<5||isempty(lam2), lam2 = 0; end
p = numel(c);  b = zeros(p,1);  Gb = zeros(p,1);
for it = 1:400
    maxd = 0;
    for j = 1:p
        rj = c(j) - Gb(j) + dg(j)*b(j);
        bj = sign(rj)*max(abs(rj)-lam1,0)/(dg(j)+lam2);
        dbj = bj - b(j);
        if dbj~=0, Gb = Gb + G(:,j)*dbj;  b(j) = bj;  if abs(dbj)>maxd, maxd = abs(dbj); end;  end
    end
    if maxd < 1e-6*max(1,max(abs(b))), break; end
end
end

function [rd,cd] = orient_fwd_local(T,r,c)
dl = T.posOfOrig(sub2ind([T.H T.W],r,c));  [rd,cd] = ind2sub([T.Hd T.Wd],dl);
end
