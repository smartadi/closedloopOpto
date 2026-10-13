% bilateral/excit_plots/build_excit_ol_avg.m
% EXPLORATORY (not manuscript): the OPEN-LOOP trial-averaged response on the
% EXCITATORY side (galvo_x<0 = LEFT), pooled across the excitatory-side controller/
% characterization experiments. This is the plant/OL characterization for controller design.
%
% Excitatory OL sessions (real 638 nm drive; verified galvo x<0 = excitatory-left):
%   06-05/2  trial_type  2.0 s STEP (amps 0.5/1.0)      -- the "steps as input" experiment
%   06-07/1  spot_idx    1.0 s sustained (amp 0.25)     -- 100-trial OL characterization
%   06-20/1  spot_idx    1.0 s sustained (amps 0.5/1.0) -- 100-trial OL characterization
%   06-11/5  spot_idx    1.0 s (amp 0.062, thin)
%   06-11/6  spot_idx    1.0 s (amp 0.125, thin)
% Both header formats log col2 = kk_start = ONSET frame directly; col8 = galvo_x_mm.
% Onset = svd_t(kk_start). Excitatory readout pixel derived per session from its own
% excitatory OL trials (left-hemi, brain-masked, peak +dF/F). Trial-average = mean +/- SEM.
% Output PNG -> bilateral/excit_plots/ol/.
clc; close all; clear;
root='C:\Users\aditya\Documents\projects\brain_paper'; cd(root); addpath(genpath(fullfile(root,'utils')));
outdir=fullfile(root,'bilateral','excit_plots','ol'); if ~exist(outdir,'dir'); mkdir(outdir); end
fs=35;                                   % imaging Hz
% col map (shared): 2=kk_start(onset), 5=amplitude, 6=trial_dur(char) / n.a.(TT), 8=galvo_x
C_KK=2; C_AMP=5; C_DUR=6; C_GX=8; C_TT=3;

% session table: {tag, date, exp, fmt('tt'|'char'), stepdur(TT only)}
S = { '06-05/2 (2 s step)', '2026-06-05', 2, 'tt',   2.0 ;
      '06-07/1 (1 s)',      '2026-06-07', 1, 'char', NaN ;
      '06-20/1 (1 s)',      '2026-06-20', 1, 'char', NaN ;
      '06-11/5 (1 s, thin)','2026-06-11', 5, 'char', NaN ;
      '06-11/6 (1 s, thin)','2026-06-11', 6, 'char', NaN };
nS=size(S,1);
R=struct('tag',{},'T',{},'mu',{},'sem',{},'dur',{},'n',{},'pix',{},'peak',{});

for si=1:nS
    tag=S{si,1}; TD=S{si,2}; EN=S{si,3}; fmt=S{si,4}; stepdur=S{si,5};
    fprintf('\n=== %s ===\n',tag);
    sr=expPath('AL_0048',TD,EN); d=loadData(sr,'AL_0048',TD,EN);
    nSV=2000; mv='blue';
    U=readUfromNPY(fullfile(sr,mv,'svdSpatialComponents.npy'),nSV);
    V=readVfromNPY(fullfile(sr,mv,'svdTemporalComponents.npy'),nSV);
    mimg=readNPY(fullfile(sr,mv,'meanImage.npy'));
    t=readNPY(fullfile(sr,mv,'svdTemporalComponents.timestamps.npy')); t=t(:).';
    [nY,nX,nSVr]=size(U); if size(V,1)~=nSVr && size(V,2)==nSVr; V=V.'; end
    Uf=reshape(U,[],nSVr);
    ip=d.input_params;
    kk=round(ip(:,C_KK)); gx=ip(:,C_GX); amp=ip(:,C_AMP);
    kk=min(max(kk,1),numel(t)); onset=t(kk);
    if strcmp(fmt,'tt')
        dur=stepdur; sel = gx<0 & ip(:,C_TT)==1;          % excitatory STEP trials
    else
        dur=median(ip(:,C_DUR)); sel = gx<0;               % excitatory OL (char = OL)
    end
    fprintf('  excitatory OL trials: %d | dur=%.2fs | amps=%s\n',nnz(sel),dur,mat2str(unique(amp(sel))'));

    % ---- derive excitatory readout pixel from these trials (left hemi, masked) ----
    if isfield(d.params,'bregma')&&~isempty(d.params.bregma); midX=round(d.params.bregma(1)); else; midX=round(nX/2); end
    brain=mimg>0.30*max(mimg(:)); bord=30; ed=true(nY,nX); ed(bord+1:nY-bord,bord+1:nX-bord)=false;
    on=onset(sel);
    fi=frames_win(t,fs,on,0.1,dur); bi=frames_win(t,fs,on,-1.2,-0.1);
    rmap=imgaussfilt(reshape(Uf*(mean(V(:,fi),2)-mean(V(:,bi),2)),nY,nX)./max(mimg,eps)*100,2);
    hm=false(nY,nX); hm(:,1:midX)=true; rr=rmap; rr(~(hm&brain&~ed))=NaN;
    [pk,li]=max(rr(:)); [py,px]=ind2sub([nY nX],li);
    fprintf('  excitatory pixel [x=%d y=%d] peak=%.2f%%\n',px,py,pk);

    % ---- window + trial-average (mean +/- SEM), baseline-subtracted ----
    PRE_S=1.2; POST_S=dur+2.5; npre=round(PRE_S*fs); npost=round(POST_S*fs); T=(-npre:npost)/fs;
    dd=pixdfof(U,V,mimg,[px py],10);
    idx=find(sel); Tr=[];
    for j=1:numel(idx)
        [~,i0]=min(abs(t-onset(idx(j)))); if i0-npre<1||i0+npost>numel(dd); continue; end
        seg=dd(i0-npre:i0+npost); seg=seg-mean(seg(1:max(1,npre-round(0.1*fs)))); Tr=[Tr;seg]; %#ok<AGROW>
    end
    R(si)=struct('tag',tag,'T',T,'mu',mean(Tr,1),'sem',std(Tr,0,1)/sqrt(size(Tr,1)), ...
                 'dur',dur,'n',size(Tr,1),'pix',[px py],'peak',pk);
end

% ================= plot: per-session OL average + overlay ==================
fig=figure('Color','w','Units','centimeters','Position',[2 2 26 14]);
tl=tiledlayout(fig,2,3,'TileSpacing','compact','Padding','compact');
col=[0.80 0.20 0.15];
for si=1:nS
    r=R(si); ax=nexttile(tl); hold(ax,'on');
    lo=min(r.mu-r.sem); hi=max(r.mu+r.sem); pad=0.12*max(hi-lo,eps); yl=[lo-pad hi+pad];
    ph=patch(ax,[0 r.dur r.dur 0],[yl(1) yl(1) yl(2) yl(2)],[.92 .92 .92],'EdgeColor','none','HandleVisibility','off'); uistack(ph,'bottom');
    fill(ax,[r.T fliplr(r.T)],[r.mu+r.sem fliplr(r.mu-r.sem)],col,'FaceAlpha',0.15,'EdgeColor','none','HandleVisibility','off');
    plot(ax,r.T,r.mu,'-','Color',col,'LineWidth',1.8);
    yline(ax,0,':','Color',[.6 .6 .6],'HandleVisibility','off');
    xline(ax,0,':','Color',[.6 .6 .6],'HandleVisibility','off'); xline(ax,r.dur,':','Color',[.6 .6 .6],'HandleVisibility','off');
    ylim(ax,yl); xlim(ax,[-r.T(1)*0-1.2 r.dur+2.5]); box(ax,'off'); set(ax,'TickDir','out','FontSize',9);
    xlabel(ax,'time from onset (s)'); ylabel(ax,'\DeltaF/F (%)');
    title(ax,sprintf('%s  n=%d  pix[%d,%d]',r.tag,r.n,r.pix(1),r.pix(2)),'FontSize',8.5);
end
% overlay panel (normalized time by onset; peak-normalized shape comparison)
ax=nexttile(tl); hold(ax,'on'); cmap=lines(nS);
for si=1:nS
    r=R(si); mu=r.mu/max(max(r.mu),eps);
    plot(ax,r.T,mu,'-','Color',cmap(si,:),'LineWidth',1.4,'DisplayName',sprintf('%s',strtok(r.tag,' ')));
end
xline(ax,0,':','Color',[.6 .6 .6],'HandleVisibility','off'); yline(ax,0,':','Color',[.6 .6 .6],'HandleVisibility','off');
xlim(ax,[-1.2 4.5]); box(ax,'off'); set(ax,'TickDir','out','FontSize',9);
xlabel(ax,'time from onset (s)'); ylabel(ax,'peak-normalized \DeltaF/F'); title(ax,'overlay (shape)','FontSize',8.5);
legend(ax,'Box','off','Location','northeast','FontSize',6.5);
title(tl,'AL\_0048 excitatory-side OPEN-LOOP trial-average (plant characterization) — 638 nm, galvo x<0','FontSize',10,'FontWeight','bold');
exportgraphics(fig,fullfile(outdir,'excit_ol_avg.png'),'Resolution',300);
fprintf('\n[build_excit_ol_avg] wrote excit_ol_avg.png -> %s\n',outdir);

% ---- local functions ----
function idx=frames_win(t,fs,onsets,w0,w1)
    idx=[]; for o=onsets(:)'; [~,i0]=min(abs(t-o)); a=max(1,i0+round(w0*fs)); b=min(numel(t),i0+round(w1*fs)); idx=[idx a:b]; end %#ok<AGROW>
end
function dfk=pixdfof(U,V,mimg,pixel,k)
    x=round(pixel(1)); y=round(pixel(2)); nSV=size(U,3); if size(V,1)~=nSV&&size(V,2)==nSV; V=V.'; end
    y0=max(1,y-k); y1=min(size(U,1),y+k); x0=max(1,x-k); x1=min(size(U,2),x+k);
    imk=U(y0:y1,x0:x1,:); ims=reshape(mean(imk,[1 2]),[1 nSV]); F=ims*V; mI=mean(mimg(y0:y1,x0:x1),'all'); dfk=double(F/mI*100);
end
