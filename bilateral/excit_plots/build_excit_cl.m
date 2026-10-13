% bilateral/excit_plots/build_excit_cl.m
% QUICK exploratory look: does excitatory CLOSED-LOOP do anything on AL_0048?
% Source: 2026-07-21 exp1 (FFA build). Excitatory = galvo_x_mm<0 (LEFT). CL=mode1, OL=mode0.
% Excitatory CL trials include ref=+5 (the proper "drive activity UP" setpoint). We window the
% readout pixel (derived from data) and overlay CL vs OL to see if the controller reaches/holds ref.
% Onset: FFA logs kk at trial END -> onset = timeBlue(kk) - dur. Output PNG -> excit_plots/step/? no: /tf? -> put in excit_plots/cl/.
clc; close all; clear;
root='C:\Users\aditya\Documents\projects\brain_paper'; cd(root); addpath(genpath(fullfile(root,'utils')));
outdir=fullfile(root,'bilateral','excit_plots','cl'); if ~exist(outdir,'dir'); mkdir(outdir); end
MN='AL_0048'; TD='2026-07-21'; EN=1; fs=35;
% FFA columns
C_KK=2; C_MODE=3; C_KP=5; C_KI=6; C_REF=9; C_DUR=10; C_GX=15;
PRE_S=2; POST_S=3;

sr=expPath(MN,TD,EN); d=loadData(sr,MN,TD,EN);
nSV=2000; mv='blue';
d.svd.U=readUfromNPY(fullfile(sr,mv,'svdSpatialComponents.npy'),nSV);
d.svd.V=readVfromNPY(fullfile(sr,mv,'svdTemporalComponents.npy'),nSV);
d.svd.mimg=readNPY(fullfile(sr,mv,'meanImage.npy'));
d.svd.t=readNPY(fullfile(sr,mv,'svdTemporalComponents.timestamps.npy'));
U=d.svd.U; V=d.svd.V; mimg=d.svd.mimg; [nY,nX,nSVr]=size(U); if size(V,1)~=nSVr&&size(V,2)==nSVr; V=V.'; end
Uf=reshape(U,[],nSVr); t=d.svd.t(:).';
ip=d.input_params;
gx=ip(:,C_GX); mode=ip(:,C_MODE); ref=ip(:,C_REF); dur=ip(:,C_DUR); kp=ip(:,C_KP); kk=round(ip(:,C_KK));
onset = t(min(max(kk,1),numel(t))) - dur(:).';   % trial-END frame minus dur
isExc = gx<0;
fprintf('07-21/1: %d trials. excitatory(gx<0)=%d | exc CL(mode1)=%d exc OL(mode0)=%d\n',size(ip,1),nnz(isExc),nnz(isExc&mode==1),nnz(isExc&mode==0));
fprintf('  exc CL refs: %s | exc CL Kp: %s\n', mat2str(unique(ref(isExc&mode==1))'), mat2str(unique(kp(isExc&mode==1))'));

% ---- excitatory readout pixel from ref=+5 CL trials (peak positive, LEFT hemi, masked) ----
if isfield(d.params,'bregma'); midX=round(d.params.bregma(1)); else; midX=round(nX/2); end
brain=mimg>0.30*max(mimg(:)); bord=30; ed=true(nY,nX); ed(bord+1:nY-bord,bord+1:nX-bord)=false;
selP = isExc & mode==1 & ref>0;             % ref=+5 excitatory CL
if nnz(selP)<3; selP = isExc & mode==1; end % fallback: any excitatory CL
on=onset(selP);
fi=frames_win(t,fs,on,0.2,2.0); bi=frames_win(t,fs,on,-PRE_S,-0.2);
rmap=imgaussfilt(reshape(Uf*(mean(V(:,fi),2)-mean(V(:,bi),2)),nY,nX)./max(mimg,eps)*100,2);
hm=false(nY,nX); hm(:,1:midX)=true; rr=rmap; rr(~(hm&brain&~ed))=NaN;
[~,li]=max(rr(:)); [py,px]=ind2sub([nY nX],li); PIX=[px py];
fprintf('excitatory readout pixel [x=%d y=%d] peak=%.2f%%\n',px,py,rmap(py,px));
dd=pixdfof(U,V,mimg,PIX,10);

% ---- window + plot: exc CL (ref+5) vs exc OL, readout dF/F ----
npre=round(PRE_S*fs); npost=round(POST_S*fs); T=(-npre:npost)/fs;
conds={'exc CL (ref +5)', isExc&mode==1&ref>0, [0.80 0.20 0.15];
       'exc CL (ref -5)', isExc&mode==1&ref<0, [0.90 0.55 0.20];
       'exc OL',          isExc&mode==0,       [0.45 0.45 0.45]};
fig=figure('Color','w','Units','centimeters','Position',[2 2 22 8]);
tl=tiledlayout(fig,1,2,'TileSpacing','compact','Padding','compact');
% panel 1: readout
ax=nexttile(tl); hold(ax,'on'); lo=0; hi=0; lg=gobjects(0); lgl={};
DUR=round(median(dur(isExc)));
patch(ax,[0 DUR DUR 0],[-1e3 -1e3 1e3 1e3],[.93 .93 .93],'EdgeColor','none','HandleVisibility','off');
for c=1:size(conds,1)
    sel=find(conds{c,2}); Tr=[];
    for j=1:numel(sel)
        [~,i0]=min(abs(t-onset(sel(j)))); if i0-npre<1||i0+npost>numel(dd); continue; end
        Tr=[Tr; dd(i0-npre:i0+npost)]; %#ok<AGROW>
    end
    if isempty(Tr); continue; end
    mu=mean(Tr,1); sd=std(Tr,0,1); col=conds{c,3};
    fill(ax,[T fliplr(T)],[mu+sd fliplr(mu-sd)],col,'FaceAlpha',0.12,'EdgeColor','none','HandleVisibility','off');
    h=plot(ax,T,mu,'-','Color',col,'LineWidth',1.6); lg(end+1)=h; lgl{end+1}=sprintf('%s (n=%d)',conds{c,1},size(Tr,1)); %#ok<AGROW>
    lo=min(lo,min(mu-sd)); hi=max(hi,max(mu+sd));
end
yline(ax,5,'--','Color',[0.80 0.20 0.15],'LineWidth',1,'HandleVisibility','off');   % +5 setpoint
yline(ax,-5,'--','Color',[0.90 0.55 0.20],'LineWidth',1,'HandleVisibility','off');  % -5 setpoint
yline(ax,0,':','Color',[.6 .6 .6],'HandleVisibility','off'); xline(ax,0,':','Color',[.6 .6 .6],'HandleVisibility','off');
pad=0.12*max(hi-lo,eps); ylim(ax,[min(lo,-6)-pad max(hi,6)+pad]); xlim(ax,[-PRE_S POST_S]);
box(ax,'off'); set(ax,'TickDir','out','FontSize',9); xlabel(ax,'time from stim onset (s)'); ylabel(ax,'\DeltaF/F (%) at excitatory readout');
title(ax,sprintf('Excitatory readout (pix [%d,%d]) — does CL reach +5?',px,py),'FontSize',9);
legend(ax,lg,lgl,'Box','off','Location','best','FontSize',7);
% panel 2: excitatory laser command (inpVals594) for CL vs OL
ax2=nexttile(tl); hold(ax2,'on');
haveIn = isfield(d,'inpVals594') && isfield(d,'inpTime594') && ~isempty(d.inpVals594);
if haveIn
    inT=d.inpTime594(:).'; inV=abs(d.inpVals594(:).');
    for c=[1 3]
        sel=find(conds{c,2}); Tin=(-PRE_S:1/fs:POST_S); M=[];
        for j=1:numel(sel)
            m=interp1(inT-onset(sel(j)),inV,Tin,'linear',NaN); M=[M;m]; %#ok<AGROW>
        end
        if isempty(M); continue; end
        plot(ax2,Tin,mean(M,1,'omitnan'),'-','Color',conds{c,3},'LineWidth',1.6,'DisplayName',conds{c,1});
    end
    xline(ax2,0,':','Color',[.6 .6 .6],'HandleVisibility','off');
    box(ax2,'off'); set(ax2,'TickDir','out','FontSize',9); xlabel(ax2,'time from stim onset (s)'); ylabel(ax2,'594 nm laser command (|V|)');
    title(ax2,'Excitatory laser command: CL (modulated) vs OL (fixed)','FontSize',9); legend(ax2,'Box','off','Location','best','FontSize',7);
else
    text(ax2,0.5,0.5,'no inpVals594','Units','normalized','HorizontalAlignment','center'); axis(ax2,'off');
end
title(tl,sprintf('%s %s/%d — excitatory CLOSED-LOOP attempt',MN,TD,EN),'FontSize',10,'FontWeight','bold');
exportgraphics(fig,fullfile(outdir,'excit_cl_readout.png'),'Resolution',300);
fprintf('[build_excit_cl] wrote excit_cl_readout.png -> %s\n',outdir);

function idx=frames_win(t,fs,onsets,w0,w1)
    idx=[]; for o=onsets(:)'; [~,i0]=min(abs(t-o)); a=max(1,i0+round(w0*fs)); b=min(numel(t),i0+round(w1*fs)); idx=[idx a:b]; end %#ok<AGROW>
end
function dfk=pixdfof(U,V,mimg,pixel,k)
    x=round(pixel(1)); y=round(pixel(2)); nSV=size(U,3); if size(V,1)~=nSV&&size(V,2)==nSV; V=V.'; end
    y0=max(1,y-k); y1=min(size(U,1),y+k); x0=max(1,x-k); x1=min(size(U,2),x+k);
    imk=U(y0:y1,x0:x1,:); ims=reshape(mean(imk,[1 2]),[1 nSV]); F=ims*V; mI=mean(mimg(y0:y1,x0:x1),'all'); dfk=double(F/mI*100);
end
