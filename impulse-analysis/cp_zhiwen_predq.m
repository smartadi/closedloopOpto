%% cp_zhiwen_predq.m — spontaneous contra->ipsi PREDICTABILITY vs BRAIN STATE, on Ye/Zhiwen data
%
% Port of our [CP-PREDQ] (utils/cp_spont_predq.m) to Zhiwen's spontaneous session, to ask whether
% the AL_0033 finding — predictability is power-CONFOUNDED with variance/abs-delta but genuinely
% (power-independently) higher in synchronized states (relative-delta) — replicates on his
% cleaner, hemo-corrected data.
%
% MODEL (his validated regime, from cp_zhiwen_validate.m Arm A): predictor = LEFT-hemi Allen
% SENSORY SVD modes (K=50, z-scored); target = the RIGHT-hemi sensory field's spatial-MEAN trace
% (a single robust "primary-like" signal). Fit a linear readout on a TRAIN block, deploy on a
% held-out TEST block, then RANDOMLY SAMPLE 3-s windows from the test block. Per window:
%   local R^2 = 1 - var(y-yhat)/var(y)         (contra->ipsi predictability)
% vs three neural states (NO motion trace on his data):
%   Variance var(y)              power-CONFOUND (var is R^2's denominator)
%   abs delta power 1-4 Hz       power-CONFOUND (~ signal power)
%   Relative delta (delta/total) power-INDEP    (spectral ratio) -- the meaningful test
% Reports Spearman rho(R^2, state) for each. Exports data/cp_zhiwen_predq.png/.mat.

clear; clc;
YE='C:\Users\aditya\Documents\projects\YE-et-al-2023-spirals';
BP='C:\Users\aditya\Documents\projects\brain_paper';
addpath(genpath(fullfile(YE,'spirals','utils')));
addpath(fullfile(BP,'utils')); addpath(fullfile(BP,'utils','npy-matlab','npy-matlab'));
data_folder=fullfile(YE,'data');  fname='AB_0004_20210330_1';
ses_root=fullfile(data_folder,'spirals','svd',fname);
out_root=fullfile(BP,'impulse-analysis','data');

K=50; nSVfull=200; svd_span=1:58000; tr_idx=1:40000; te_idx=40001:58000; scale=8;
winSec=3; nWin=400; rngSeed=7;           % 3-s windows (user), randomly sampled from the test block
% NB: target lives in the FULL nSVfull(=200)-dim signal; predictor = only K(=50) left-hemi modes.
% This rank asymmetry is what makes single-pixel prediction lossy (R^2<1) with the window-to-window
% dynamic range that carries state-dependence. Using K modes to predict a K-dim target is
% near-degenerate (R^2~1, no range) -- that was the first attempt's ceiling artifact.

%% ---- load + warp + sensory hemispheres (as cp_zhiwen_validate.m Arm A) ----
[U,V,t,mimg]=loadUVt1(ses_root);  Fs=1/median(diff(t));  U=U(:,:,1:nSVfull); V=double(V(1:nSVfull,:));
fprintf('%s  Fs=%.2f Hz  nT=%d\n', fname, Fs, size(V,2));
atl=load(fullfile(data_folder,'tables','isocortex_horizontal_projection_outline.mat'));
[~,st]=get_cortex_atlas_path(data_folder); spath=string(st.structure_id_path);
tf=load(fullfile(data_folder,'spirals','rf_tform',[fname '_tform.mat']));
Utr=imwarp(U,tf.tform,'OutputView',imref2d(size(atl.projectedTemplate1)));
areaPath(1)="/997/8/567/688/695/315/453/"; areaPath(2)="/997/8/567/688/695/315/247/";
areaPath(3)="/997/8/567/688/695/315/669/"; areaPath(4)="/997/8/567/688/695/315/254/";
areaPath(5)="/997/8/567/688/695/315/22/312782546/"; areaPath(6)="/997/8/567/688/695/315/22/417/";
areaPath(7)="/997/8/567/688/695/315/541/"; areaPath(9)="/997/8/567/688/695/315/677/";
areaPath(10)="/997/8/567/688/695/1089/"; areaPath(11)="/997/8/567/688/695/315/677/";
sensoryArea=strcat(areaPath(:));
[~,UselL]=select_area(sensoryArea,spath,st,atl.coords,Utr,atl.projectedAtlas1,atl.projectedTemplate1,'left', scale);
[~,UselR]=select_area(sensoryArea,spath,st,atl.coords,Utr,atl.projectedAtlas1,atl.projectedTemplate1,'right',scale);

%% ---- predictor = LEFT redoSVD modes ; target = a SINGLE representative RIGHT sensory pixel ----
% CP-PREDQ predicts ONE pixel (the primary/recording pixel, R^2~0.85 with real window-to-window
% spread) -- that spread carries the state-dependence. The hemisphere spatial-MEAN is the global
% mode (R^2~0.999, no dynamic range), so we predict a single pixel instead. To avoid arbitrariness
% and test-set selection bias, pick the right-sensory pixel whose TRAIN contra->pixel R^2 is
% closest to the MEDIAN across sensory pixels (a typical pixel), then evaluate state on held-out.
[~,VnewL]=redoSVD(double(UselL),V(:,svd_span));  Vleft=double(VnewL(1:K,:));   % top K left modes = predictor
UselR=double(UselR);
Xtr =[ones(numel(tr_idx),1) zscore(Vleft(:,tr_idx),[],2)'];  % [nTr x K+1]
Xall=[ones(size(Vleft,2),1) zscore(Vleft,[],2)'];            % z over full span (consistent scaling)
Yall = UselR * V(1:nSVfull,svd_span);                        % [P x nSpan] FULL-dim right-sensory pixel traces
Ytr  = Yall(:,tr_idx)';                                      % [nTr x P]
W    = Xtr \ Ytr;                                            % [(K+1) x P] per-pixel readouts (one solve)
Rtr  = Ytr - Xtr*W;   R2tr = 1 - sum(Rtr.^2)./max(sum((Ytr-mean(Ytr)).^2),eps);   % [1 x P] train R^2
[~,pStar] = min(abs(R2tr - median(R2tr,'omitnan')));         % representative (median-R^2) pixel
fprintf('target pixel: median-train-R^2 sensory px #%d of %d  (trainR^2=%.3f, medianR^2=%.3f)\n', ...
    pStar, numel(R2tr), R2tr(pStar), median(R2tr,'omitnan'));
y    = Yall(pStar,:);                                        % [1 x nSpan] actual target-pixel trace
yhat = (Xall*W(:,pStar))';                                   % [1 x nSpan] contra prediction

%% ---- randomly sample 3-s windows from the held-out TEST block ----
Lw=round(winSec*Fs);  win=hann(Lw); Wn=sum(win.^2); nfft=2^nextpow2(Lw);
fr=(0:nfft-1)'/nfft*Fs; nB=floor(nfft/2)+1; dband=fr(1:nB)>=1 & fr(1:nB)<=4;
rng(rngSeed);
lo=te_idx(1); hi=te_idx(end)-Lw+1;  starts=lo+floor(rand(nWin,1)*(hi-lo+1));
lr2=nan(nWin,1); pv=nan(nWin,1); dpow=nan(nWin,1); drel=nan(nWin,1);
for i=1:nWin
    idx=starts(i):starts(i)+Lw-1;
    yv=y(idx)'; yh=yhat(idx)'; rv=yv-yh;
    lr2(i)=1-var(rv)/max(var(yv),eps);
    pv(i)=var(yv);
    Xf=fft(yv(:).*win,nfft); pw=abs(Xf(1:nB)).^2*2/(Fs*Wn);
    dpow(i)=mean(pw(dband)); drel(i)=sum(pw(dband))/max(sum(pw),eps);
end
states=[pv dpow drel];
statesL={'Variance  var(y)','\delta power 1-4 Hz (abs)','Relative \delta  (\delta/total)'};
flags  ={'power-CONFOUND','power-CONFOUND','power-INDEP'};

%% ---- report + figure ----
fprintf('\n===== [CP-PREDQ] on Ye/Zhiwen %s : %d random %.0f-s spontaneous windows (held-out) =====\n', fname, nWin, winSec);
fprintf('full-span contra->target readout R^2 (test) = %.3f | median window R^2 = %.3f\n', ...
    1-var(y(te_idx)-yhat(te_idx))/var(y(te_idx)), median(lr2,'omitnan'));
rhos=nan(3,1);
for k=1:3
    [rr,pp]=corr(states(:,k),lr2,'type','Spearman','rows','complete'); rhos(k)=rr;
    fprintf('   R^2 vs %-26s rho=%+.2f (p=%.1g)  [%s]\n', statesL{k}, rr, pp, flags{k});
end
save(fullfile(out_root,'cp_zhiwen_predq.mat'),'lr2','states','statesL','flags','rhos','winSec','nWin','Fs','fname');

fig=figure('Color','w','Position',[60 60 1180 380]);
for k=1:3
    x=states(:,k); ax=subplot(1,3,k); hold(ax,'on');
    scatter(ax,x,lr2,12,[0.35 0.45 0.85],'filled','MarkerFaceAlpha',0.30);
    e=quantile(x,linspace(0,1,9)); b=discretize(x,e); b(isnan(b))=8;
    mx=accumarray(b,x,[8 1],@median,NaN); my=accumarray(b,lr2,[8 1],@median,NaN);
    ey=accumarray(b,lr2,[8 1],@(v)std(v)/sqrt(numel(v)),NaN);
    errorbar(ax,mx,my,ey,'k-o','LineWidth',2,'MarkerFaceColor','k','MarkerSize',5,'CapSize',3);
    [rr,pp]=corr(x,lr2,'type','Spearman','rows','complete');
    tc=[0 0 0]; if abs(rr)<0.05, tc=[0 0.55 0]; end
    xlim(ax,[min(x) quantile(x,0.99)]); ylim(ax,[min(-0.2,quantile(lr2,0.01)) 1.05]);
    xlabel(ax,statesL{k},'FontWeight','bold'); if k==1, ylabel(ax,'local R^2 (contra\rightarrowipsi)','FontWeight','bold'); end
    title(ax,{sprintf('\\rho=%+.2f (p=%.1g)',rr,pp),flags{k}},'FontWeight','bold','FontSize',9,'Color',tc);
    yline(ax,median(lr2,'omitnan'),':','Color',[0.5 0.5 0.5]); set(ax,'Box','off','TickDir','out'); grid(ax,'on');
end
sgtitle(sprintf('Ye/Zhiwen %s — spontaneous contra\\rightarrowipsi predictability vs state (%d random %.0f-s windows)',fname,nWin,winSec),'FontWeight','bold','FontSize',11,'Interpreter','tex');
exportgraphics(fig,fullfile(out_root,'cp_zhiwen_predq.png'),'Resolution',220);
fprintf('exported %s\n', fullfile(out_root,'cp_zhiwen_predq.png'));

%% ---- ROBUSTNESS: are the state-rhos stable across the choice of target pixel? ----
% The single median-R^2 pixel above could be idiosyncratic. Re-run the same 400 windows for a
% sample of sensory pixels spanning the realistic single-pixel regime (train R^2 in [0.6,0.98]),
% and summarise the distribution of each state-rho. Reuses the already-fitted per-pixel readouts W.
rng(11);
cand=find(R2tr>=0.6 & R2tr<=0.98);  sel=cand(randperm(numel(cand),min(150,numel(cand))));
RH=nan(numel(sel),3);
for ii=1:numel(sel)
    p=sel(ii); yP=Yall(p,:); yhP=(Xall*W(:,p))';
    l=nan(nWin,1); v=nan(nWin,1); da=nan(nWin,1); dr=nan(nWin,1);
    for i=1:nWin
        idx=starts(i):starts(i)+Lw-1; yv=yP(idx)'; rv=yv-yhP(idx)';
        l(i)=1-var(rv)/max(var(yv),eps); v(i)=var(yv);
        Xf=fft(yv(:).*win,nfft); pw=abs(Xf(1:nB)).^2*2/(Fs*Wn);
        da(i)=mean(pw(dband)); dr(i)=sum(pw(dband))/max(sum(pw),eps);
    end
    RH(ii,1)=corr(v,l,'type','Spearman','rows','complete');
    RH(ii,2)=corr(da,l,'type','Spearman','rows','complete');
    RH(ii,3)=corr(dr,l,'type','Spearman','rows','complete');
end
fprintf('\n--- robustness over %d sensory pixels (train R^2 in [0.6,0.98]) ---\n', numel(sel));
for k=1:3
    fprintf('  %-26s median rho=%+.2f  IQR[%+.2f,%+.2f]  %%rho<0=%.0f%%\n', statesL{k}, ...
        median(RH(:,k)), quantile(RH(:,k),.25), quantile(RH(:,k),.75), 100*mean(RH(:,k)<0));
end
save(fullfile(out_root,'cp_zhiwen_predq.mat'),'lr2','states','statesL','flags','rhos','RH','winSec','nWin','Fs','fname','-append');
