% bilateral/excit_plots/build_step_excit.m
% EXPLORATORY (not manuscript) excitatory STEP-response plots for AL_0048.
% Source: 2026-06-05 exp 2 -- dedicated OL characterization, trial_type 0=impulse(0.057s),
% 1=STEP(2.0s), both hemispheres. EXCITATORY = galvo_x_mm<0 (LEFT); INHIBITORY = galvo_x>0 (RIGHT).
% Shows the excitatory step rise + post-offset REBOUND vs the inhibitory dip.
% Response pixel per side is derived FROM THE DATA (peak |response| in that hemisphere).
% Outputs PNG -> bilateral/excit_plots/step/.  Run from repo root (or bilateral/).
clc; close all; clear;
root='C:\Users\aditya\Documents\projects\brain_paper'; cd(root); addpath(genpath(fullfile(root,'utils')));
outdir=fullfile(root,'bilateral','excit_plots','step'); if ~exist(outdir,'dir'); mkdir(outdir); end

MN='AL_0048'; TD='2026-06-05'; EN=2;
fs=35;                 % imaging Hz
COL_TT=3; COL_AMP=5; COL_GX=8;   % 06-05/2 input_params columns
PRE_S=1.5; POST_S=3.0; STEP_DUR=2.0;

%% ---- load (bypass initialize_data's findStims, which needs params.dur) ----
sr=expPath(MN,TD,EN);
d=loadData(sr,MN,TD,EN);
nSV=2000; mv='blue';
d.svd.U=readUfromNPY(fullfile(sr,mv,'svdSpatialComponents.npy'),nSV);
d.svd.V=readVfromNPY(fullfile(sr,mv,'svdTemporalComponents.npy'),nSV);
d.svd.mimg=readNPY(fullfile(sr,mv,'meanImage.npy'));
d.svd.t=readNPY(fullfile(sr,mv,'svdTemporalComponents.timestamps.npy'));
ip=d.input_params; t=d.svd.t(:).';
fprintf('06-05/2: %d trials x %d cols; %d SVD frames (timeBlue %d).\n',size(ip,1),size(ip,2),numel(t),numel(d.timeBlue));
fr=round(ip(:,2));
fprintf('kk_start range [%d..%d]; using as frame index into SVD frames.\n',min(fr),max(fr));
fr=min(max(fr,1),numel(t)); onset=t(fr);
gx=ip(:,COL_GX); tt=ip(:,COL_TT); amp=ip(:,COL_AMP);
isStep=tt==1; isExc=gx<0; isInh=gx>0;
fprintf('step trials: exc=%d inh=%d | amps(step)=%s\n', nnz(isStep&isExc),nnz(isStep&isInh), mat2str(unique(amp(isStep))'));

%% ---- SVD handles ----
assert(isfield(d,'svd')&&isfield(d.svd,'U')&&isfield(d.svd,'V'),'need d.svd U/V');
U=d.svd.U; V=d.svd.V; mimg=d.svd.mimg; [nY,nX,nSV]=size(U);
if size(V,1)~=nSV && size(V,2)==nSV; V=V.'; end
Uf=reshape(U,[],nSV);
if isfield(d.params,'bregma')&&numel(d.params.bregma)>=1; midX=round(d.params.bregma(1)); else; midX=round(nX/2); end
fprintf('midline col=%d (nX=%d)\n',midX,nX);

%% ---- brain mask (exclude dark vessels/edges that blow up dF/F) + border ----
brain = mimg > 0.30*max(mimg(:));                 % dim vessels/edges out
bord=30; edge=true(nY,nX); edge(bord+1:nY-bord,bord+1:nX-bord)=false;
valid_all = brain & ~edge;

%% ---- derive response pixel per side from step trials (dF/F map, masked) ----
sides={'exc',isStep&isExc,'left',+1; 'inh',isStep&isInh,'right',-1};
PIX=struct();
for s=1:size(sides,1)
    nm=sides{s,1}; on=onset(sides{s,2}); hemi=sides{s,3}; sgn=sides{s,4};
    fi=frames_in(t,fs,on,0.1,STEP_DUR); bi=frames_in(t,fs,on,-PRE_S,-0.1);
    resp=Uf*(mean(V(:,fi),2)-mean(V(:,bi),2));        % raw fluor response
    rmap=reshape(resp,nY,nX)./max(mimg,eps)*100;      % -> %dF/F
    rmap=imgaussfilt(rmap,2);                          % smooth to avoid single hot pixels
    hm=false(nY,nX); if strcmp(hemi,'left'); hm(:,1:midX)=true; else; hm(:,midX:end)=true; end
    rr=rmap; rr(~(hm & valid_all))=NaN;
    if sgn>0; [~,li]=max(rr(:)); else; [~,li]=min(rr(:)); end
    [py,px]=ind2sub([nY nX],li); PIX.(nm)=[px py];
    fprintf('[%s] response pixel [x=%d y=%d] peakdFF=%.2f%% (%s)\n',nm,px,py,rmap(py,px),hemi);
end

%% ---- window step trials per side per amp, plot ----
kern=10; try; kern=double(d.params.kernel); catch; end
npre=round(PRE_S*fs); npost=round(POST_S*fs); T=(-npre:npost)/fs;
cols=struct('exc',[0.80 0.20 0.15],'inh',[0.15 0.35 0.80]);
amps=unique(amp(isStep)); amps=amps(amps>0);

fig=figure('Color','w','Units','centimeters','Position',[2 2 20 8]);
tl=tiledlayout(fig,1,2,'TileSpacing','compact','Padding','compact');
for s=1:size(sides,1)
    nm=sides{s,1}; msk=sides{s,2}; dd=pixdfof(U,V,mimg,PIX.(nm),kern);
    ax=nexttile(tl); hold(ax,'on');
    lg=gobjects(0); lgl={}; shades=linspace(0.45,1,max(numel(amps),1)); lo=0; hi=0;
    for ai=1:numel(amps)
        sel=find(msk & amp==amps(ai)); Tr=[];
        for j=1:numel(sel)
            [~,i0]=min(abs(t-onset(sel(j)))); if i0-npre<1||i0+npost>numel(dd); continue; end
            seg=dd(i0-npre:i0+npost); seg=seg-mean(seg(1:max(1,npre-round(0.1*fs)))); Tr=[Tr;seg]; %#ok<AGROW>
        end
        if isempty(Tr); continue; end
        c=cols.(nm)*shades(ai)+(1-shades(ai)); mu=mean(Tr,1); sd=std(Tr,0,1);
        fill(ax,[T fliplr(T)],[mu+sd fliplr(mu-sd)],c,'FaceAlpha',0.12,'EdgeColor','none','HandleVisibility','off');
        h=plot(ax,T,mu,'-','Color',c,'LineWidth',1.6); lg(end+1)=h; lgl{end+1}=sprintf('amp %.2g (n=%d)',amps(ai),size(Tr,1)); %#ok<AGROW>
        lo=min(lo,min(mu-sd)); hi=max(hi,max(mu+sd));
    end
    pad=0.12*max(hi-lo,eps); yl=[lo-pad hi+pad]; ylim(ax,yl);
    ph=patch(ax,[0 STEP_DUR STEP_DUR 0],[yl(1) yl(1) yl(2) yl(2)],[.92 .92 .92],'EdgeColor','none','HandleVisibility','off'); uistack(ph,'bottom');
    yline(ax,0,':','Color',[.6 .6 .6],'HandleVisibility','off');
    xline(ax,0,':','Color',[.6 .6 .6],'HandleVisibility','off'); xline(ax,STEP_DUR,':','Color',[.6 .6 .6],'HandleVisibility','off');
    xlim(ax,[-PRE_S POST_S]); box(ax,'off'); set(ax,'TickDir','out','FontSize',9);
    xlabel(ax,'time from step onset (s)'); ylabel(ax,'\DeltaF/F (%, baseline-subtracted)');
    title(ax,sprintf('%s (%s hemi, pix [%d,%d])',upper(nm),hemi_name(nm),PIX.(nm)(1),PIX.(nm)(2)),'FontSize',9);
    if ~isempty(lg); legend(ax,lg,lgl,'Box','off','Location','northeast','FontSize',7); end
    if strcmp(nm,'exc'); text(ax,STEP_DUR+0.05,yl(1)+0.15*range(yl),'rebound \rightarrow','Color',cols.exc,'FontWeight','bold','FontSize',8); end
end
title(tl,sprintf('%s %s/%d — 2 s STEP: excitatory rebound vs inhibitory dip',MN,TD,EN),'FontSize',10,'FontWeight','bold');
exportgraphics(fig,fullfile(outdir,'step_excit_vs_inhib.png'),'Resolution',300);
fprintf('[build_step_excit] wrote step_excit_vs_inhib.png -> %s\n',outdir);

%% ---- local functions ----
function idx=frames_in(t,fs,onsets,w0,w1)
    idx=[];
    for o=onsets(:)'
        [~,i0]=min(abs(t-o)); a=max(1,i0+round(w0*fs)); b=min(numel(t),i0+round(w1*fs)); idx=[idx a:b]; %#ok<AGROW>
    end
end
function dfk=pixdfof(U,V,mimg,pixel,k)
    x=round(pixel(1)); y=round(pixel(2)); nSV=size(U,3);
    if size(V,1)~=nSV && size(V,2)==nSV; V=V.'; end
    y0=max(1,y-k); y1=min(size(U,1),y+k); x0=max(1,x-k); x1=min(size(U,2),x+k);
    imk=U(y0:y1,x0:x1,:); ims=reshape(mean(imk,[1 2]),[1 nSV]);
    F=ims*V; mI=mean(mimg(y0:y1,x0:x1),'all'); dfk=double(F/mI*100);
end
function s=hemi_name(nm); if strcmp(nm,'exc'); s='left/exc'; else; s='right/inh'; end; end
