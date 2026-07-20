% ctrl_affected_gui.m -- interactive STIM-AFFECTED contra-pixel detector for OL trials.
%
% DIP SCORE (robust; user refinements 2026-07-19):
%   Work on the TRIAL-AVERAGED peri-stim trace (average the 92 OL trials FIRST, then measure).
%   * REFERENCE = level at ONSET = mean over [-1,0] s  (NOT the long pre-mean) -> a pixel that
%     starts high and dips still reads clearly negative.
%   * DIP       = (trough - reference), trough = deepest 0.5 s sliding-window mean over [0,dur] s
%     -> a transient dip that recovers before the stim window ends still counts.
%   * NORMALIZE by the pre-window SD ([-6,0] s wobble of the averaged trace).
%   score = (trough - ref) / sd_pre  (negative = dip).  A pixel is AFFECTED (downward only) by a
%   MANUAL threshold (slider: score < -thr) -- the user tunes the cut visually against the
%   deflection map. (Adaptive permutation selection was tried and rejected 2026-07-20: its null
%   carries the same trough-min bias, so it explains away the real midline dips as chance.)
%
% GUI (non-blocking): background = whole-brain trial-avg deflection map; contra grid coloured
%   red(affected)/blue(unaffected); slider = manual score thr; click any pixel -> its peri-stim
%   trace over [-10, dur+1] s with ref/trough/windows marked.
%
% PREREQS: ctrl_ols_spont.m (Stage 1) -> data/ctrl_ols_spont_<sess>.mat; `mouse`,`fields` in ws.

%% [CFG]
selField   = 4;
nSV_load   = 500;
Fs         = 35;
pre_s      = 6.0;      % pre-window (for the baseline SD)  [-6,0] s
ref_s      = 1.0;      % onset-reference window  [-1,0] s
disp_pre_s = 10.0;     % click-inspector display: onset - 10 s ...
disp_post_s= 1.0;      % ... to stim_end + 1 s
trough_s   = 0.5;      % sliding-window length for the trough (s)
score_thr0 = 1.0;      % manual slider default (score < -thr => affected)

assert(exist('mouse','var') && exist('fields','var'), '[CTRL-AFF] run load_sessions.m first.');
here = fileparts(mfilename('fullpath'));
if isempty(here) || contains(here,tempdir,'IgnoreCase',true) || contains(here,'Editor_','IgnoreCase',true)
    here = fullfile(pwd,'controller-analysis');  if ~exist(here,'dir'); here = pwd; end
end
dataDir = fullfile(here,'data');

%% [LOAD]
fld=fields{selField}; d_s=mouse.(fld).d; data=mouse.(fld).data;
mn=mouse.(fld).mn; td=mouse.(fld).td; en=mouse.(fld).en;
sess_tag=sprintf('%s_%s%s_e%d', mn, td(6:7), td(9:10), en);
S1=load(fullfile(dataDir,sprintf('ctrl_ols_spont_%s.mat',sess_tag)));
gridIdx=S1.gridIdx; grR=S1.grR; grC=S1.grC; nG=S1.nG;
px_prim=S1.px_prim; py_prim=S1.py_prim; dur=S1.trial_dur;
[U_cp,V_cp,t_svd,mimg_cp]=loadUVt(expPath(mn,td,en),nSV_load);
V_cp=double(V_cp); [nY,nX]=size(mimg_cp); nSV=size(U_cp,3);
Uflat=reshape(U_cp,nY*nX,nSV); t_full=t_svd(:); T=size(V_cp,2);

%% [COMPUTE] windows + trial-averaged dip score
pre=round(pre_s*Fs); dpre=round(disp_pre_s*Fs); dpost=round((dur+disp_post_s)*Fs);
rel=-dpre:dpost; nRel=numel(rel);                       % DISPLAY/extraction window [-10, dur+1] s
iPre = find(rel>=-pre & rel<0);                         % [-6,0) baseline SD
iRef = find(rel>=-round(ref_s*Fs) & rel<0);             % [-1,0) onset reference
iStim= find(rel>=0 & rel<=round(dur*Fs));               % [0,dur] stim
wlen = max(1,round(trough_s*Fs));
% map background windows
bwin=iPre; swin=iStim;

ol_starts=sort(d_s.stimStarts(data.nc(:)));
onF=zeros(numel(ol_starts),1);
for j=1:numel(ol_starts), [~,onF(j)]=min(abs(t_full-ol_starts(j))); end
onF=onF(onF>dpre & onF+dpost<=T); nTr=numel(onF);

mIg=max(mimg_cp(gridIdx),eps);
Xg=double(Uflat(gridIdx,:))*V_cp;                       % [nG x T] dF (grid)
% trial-averaged %dF trace
periAvg=zeros(nG,nRel);
for j=1:nTr, periAvg=periAvg+Xg(:,onF(j)+rel); end
periAvg=(periAvg/nTr)./mIg*100;
zGrid = dip_score_(periAvg, iRef, iStim, iPre, wlen);   % real trial-avg score (dip<0)

% whole-brain background deflection map (mean stim - mean pre), %dF -- context only
preFr=[]; stimFr=[];
for j=1:nTr, preFr=[preFr, onF(j)+rel(iPre)]; stimFr=[stimFr, onF(j)+rel(iStim)]; end %#ok<AGROW>
dV=mean(V_cp(:,stimFr),2)-mean(V_cp(:,preFr),2);
deflMap=reshape(Uflat*dV./max(mimg_cp(:),eps),nY,nX)*100;

fprintf('[CTRL-AFF] %s | %d OL trials | score range [%.2f, %.2f]\n', ...
    sess_tag, nTr, min(zGrid), max(zGrid));

%% [GUI]
delete(findall(0,'Type','figure','Tag','ctrl_affected_gui'));
figA=figure('Color','w','Tag','ctrl_affected_gui','Name',sprintf('Affected detector: %s',sess_tag), ...
    'Position',[50 60 1380 660]);
GD=struct('Uflat',Uflat,'V',V_cp,'mimg',mimg_cp,'onF',onF,'rel',rel,'iPre',iPre,'iRef',iRef, ...
    'iStim',iStim,'wlen',wlen,'Fs',Fs,'nY',nY,'nX',nX,'gridIdx',gridIdx,'grR',grR,'grC',grC,'nG',nG, ...
    'zGrid',zGrid,'deflMap',deflMap,'px_prim',px_prim,'py_prim',py_prim,'sess_tag',sess_tag,'nTr',nTr, ...
    'dur',dur,'mIg',mIg);
GD.axMap=axes('Parent',figA,'Position',[0.04 0.17 0.44 0.75]);
GD.axPix=axes('Parent',figA,'Position',[0.56 0.16 0.40 0.74]);
sld_max=max(4,ceil(max(abs(zGrid))));
GD.sld=uicontrol(figA,'Style','slider','Units','normalized','Position',[0.10 0.055 0.30 0.03], ...
    'Min',0.2,'Max',sld_max,'Value',min(score_thr0,sld_max),'Callback',@(s,~)aff_manual(figA));
GD.txt=uicontrol(figA,'Style','text','Units','normalized','Position',[0.04 0.095 0.44 0.03], ...
    'String','','BackgroundColor','w','FontSize',10,'HorizontalAlignment','left');
uicontrol(figA,'Style','text','Units','normalized','Position',[0.035 0.05 0.055 0.035], ...
    'String','dip score','BackgroundColor','w','FontSize',9);
guidata(figA,GD);
set(figA,'WindowButtonDownFcn',@(f,~)aff_click(f));
aff_draw_map(figA); aff_manual(figA);
title(GD.axPix,'click a pixel to inspect  [-10, dur+1] s');
fprintf('[CTRL-AFF] GUI open. Slider = manual score threshold (score < -thr => affected).\n');

%% ---- score + callbacks ----
function sc = dip_score_(A, iRef, iStim, iPre, wlen)
% A [N x nRel] trial-averaged traces -> [N x 1] dip score (negative = dip).
ref = mean(A(:,iRef),2);
Wm  = movmean(A(:,iStim), wlen, 2);                     % sliding-window mean over stim
trough = min(Wm,[],2);                                  % deepest sub-window (catches transient dips)
sd  = std(A(:,iPre),0,2) + eps;
sc  = (trough - ref)./sd;
end

function aff_draw_map(figA)
GD=guidata(figA); ax=GD.axMap; cla(ax); hold(ax,'on');
lim=prctile(abs(GD.deflMap(~isnan(GD.deflMap))),99);
imagesc(ax,GD.deflMap,[-lim lim]); axis(ax,'image','ij','off');
colormap(ax,local_div()); cb=colorbar(ax); cb.Label.String='trial-avg \DeltaF/F stim-pre (%)';
plot(ax,GD.py_prim,GD.px_prim,'g+','MarkerSize',15,'LineWidth',2.5);
GD.hGrid=scatter(ax,GD.grC,GD.grR,22,[0 0 0],'filled'); guidata(figA,GD);
end

function aff_setmask(figA, aff, label)
GD=guidata(figA);
cols=repmat([0.15 0.55 0.95],GD.nG,1); cols(aff,:)=repmat([0.9 0.15 0.1],nnz(aff),1);
set(GD.hGrid,'CData',cols,'SizeData',22+18*double(aff));
set(GD.txt,'String',sprintf('%s -> %d affected / %d unaffected (%.0f%% kept for predictor)', ...
    label, nnz(aff), GD.nG-nnz(aff), 100*(GD.nG-nnz(aff))/GD.nG));
title(GD.axMap,sprintf('%s: deflection map + contra grid (red=affected)',strrep(GD.sess_tag,'_','\_')));
GD.aff=aff; guidata(figA,GD);
end

function aff_manual(figA)
GD=guidata(figA);
z=get(GD.sld,'Value'); aff=GD.zGrid < -z;               % DOWNWARD dips only
aff_setmask(figA, aff, sprintf('manual: score < -%.2f',z));
end

function aff_click(figA)
GD=guidata(figA);
cp=get(GD.axMap,'CurrentPoint'); c=round(cp(1,1)); r=round(cp(1,2));
if r<1||r>GD.nY||c<1||c>GD.nX, return; end
p=sub2ind([GD.nY GD.nX],r,c);
tr=double(GD.Uflat(p,:))*GD.V; mI=GD.mimg(r,c); if abs(mI)<eps, mI=1; end
M=zeros(GD.nTr,numel(GD.rel)); for j=1:GD.nTr, M(j,:)=tr(GD.onF(j)+GD.rel); end
M=(M/mI)*100; m=mean(M,1); se=std(M,0,1)/sqrt(GD.nTr);   % trial-avg trace (%dF, NOT baseline-sub)
ref=mean(m(GD.iRef));
Wm=movmean(m(GD.iStim),GD.wlen); [troughv,it]=min(Wm); sd=std(m(GD.iPre))+eps;
sc=(troughv-ref)/sd; troughT=GD.rel(GD.iStim(it))/GD.Fs;
z=get(GD.sld,'Value'); isAff = sc < -z;   % click readout uses the manual slider threshold
vtxt=sprintf('score=%.2f (manual thr -%.2f)',sc,z);
ax=GD.axPix; cla(ax); hold(ax,'on'); tt=GD.rel/GD.Fs; yl=[min(m-se) max(m+se)]; if diff(yl)<=0,yl=[-1 1];end
patch(ax,[tt(GD.iPre(1)) 0 0 tt(GD.iPre(1))],[yl(1) yl(1) yl(2) yl(2)],[.6 .6 .6],'FaceAlpha',.10,'EdgeColor','none');
patch(ax,[0 tt(GD.iStim(end)) tt(GD.iStim(end)) 0],[yl(1) yl(1) yl(2) yl(2)],[.9 .5 .1],'FaceAlpha',.10,'EdgeColor','none');
fill(ax,[tt fliplr(tt)],[m+se fliplr(m-se)],[.2 .4 .8],'FaceAlpha',.2,'EdgeColor','none');
plot(ax,tt,m,'-','Color',[.1 .2 .6],'LineWidth',1.6);
yline(ax,ref,'--','Color',[.2 .5 .2],'LineWidth',1); plot(ax,troughT,troughv,'v','Color',[.8 .1 .1],'MarkerSize',9,'MarkerFaceColor',[.8 .1 .1]);
xline(ax,0,'k:'); xlim(ax,[tt(1) tt(end)]); xlabel(ax,'time from stim (s)'); ylabel(ax,'\DeltaF/F (%)');
title(ax,sprintf('px (r%d,c%d): ref=%.2f trough=%.2f@%.2fs  %s -> %s', ...
    r,c,ref,troughv,troughT,vtxt,ternA(isAff,'AFFECTED','unaffected')));
GD2=guidata(figA); if isfield(GD2,'hMark')&&ishandle(GD2.hMark),delete(GD2.hMark);end
GD2.hMark=plot(GD.axMap,c,r,'ko','MarkerSize',10,'LineWidth',1.5); guidata(figA,GD2);
end

function s=ternA(c,a,b); if c,s=a;else,s=b;end; end
function cm=local_div()
n=128; cm=[[linspace(0.15,1,n)' linspace(0.25,1,n)' linspace(0.75,1,n)']; ...
           [linspace(1,0.85,n)' linspace(1,0.20,n)' linspace(1,0.15,n)']];
end
