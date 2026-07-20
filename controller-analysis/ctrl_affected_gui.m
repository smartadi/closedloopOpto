% ctrl_affected_gui.m -- interactive STIM-AFFECTED contra-pixel detector for OL trials.
%
% CRITERION (user, 2026-07-19): a pixel is stim-AFFECTED if its trial-averaged mean over the
%   STIM window is LOWER than its mean over the PRE-STIM window by a threshold (a dip during stim).
%   Quantified as a z-score:  z = (mean_stim - mean_pre) / sd_pre .  Affected if z < -zThr (a dip;
%   set two_sided=true to also catch increases, |z|>zThr). Computed per OPEN-LOOP trial then averaged.
%
% GUI (non-blocking -- creates the figure and returns; interact on the MATLAB desktop):
%   * background   = whole-brain trial-avg deflection map (%dF, stim-pre): see the focal ipsi dip
%                    + any contra propagation.
%   * contra grid  = the predictor-candidate pixels, coloured RED (affected) / BLUE (unaffected)
%                    at the current threshold; the laser site is the green +.
%   * slider       = z-threshold; live-updates the red/blue split + the affected count.
%   * click a pixel-> right axes shows that pixel's peri-stim trace (trial-avg +/-SEM) with the
%                    pre & stim windows shaded, its z, and the affected verdict. Convince yourself,
%                    then read off the chosen zThr and pass it to the predictor (ctrl_ols_ol_stimblind).
%
% PREREQS: ctrl_ols_spont.m (Stage 1) for this session -> data/ctrl_ols_spont_<sess>.mat;
%          `mouse`,`fields` in the workspace (load_sessions.m).

%% [CFG]
selField  = 4;
nSV_load  = 500;
Fs        = 35;
pre_s     = 6.0;      % pre-stim window [-6,0] s (trials are 18 s apart -> no overlap with prior stim)
zThr0     = 1.0;      % initial score threshold (slider default). Score = dip depth in baseline-SD
                      % units of the TRIAL-AVERAGED trace. LOWER = more conservative (drops weaker dips).
two_sided = false;    % false = DOWNWARD only (affected iff dip: score < -thr). We only care about dips.

assert(exist('mouse','var') && exist('fields','var'), '[CTRL-AFF] run load_sessions.m first.');
here = fileparts(mfilename('fullpath'));
if isempty(here) || contains(here,tempdir,'IgnoreCase',true) || contains(here,'Editor_','IgnoreCase',true)
    here = fullfile(pwd,'controller-analysis');  if ~exist(here,'dir'); here = pwd; end
end
dataDir = fullfile(here,'data');

%% [LOAD] Stage 1 cache + U/V
fld = fields{selField};
d_s = mouse.(fld).d;  data = mouse.(fld).data;
mn=mouse.(fld).mn; td=mouse.(fld).td; en=mouse.(fld).en;
sess_tag = sprintf('%s_%s%s_e%d', mn, td(6:7), td(9:10), en);
S1 = load(fullfile(dataDir, sprintf('ctrl_ols_spont_%s.mat', sess_tag)));
gridIdx=S1.gridIdx; grR=S1.grR; grC=S1.grC; nG=S1.nG;
px_prim=S1.px_prim; py_prim=S1.py_prim; dur=S1.trial_dur;

[U_cp,V_cp,t_svd,mimg_cp] = loadUVt(expPath(mn,td,en), nSV_load);
V_cp=double(V_cp); [nY,nX]=size(mimg_cp); nSV=size(U_cp,3);
Uflat=reshape(U_cp,nY*nX,nSV); t_full=t_svd(:); T=size(V_cp,2);

%% [COMPUTE] peri-stim windows + deflection stats
pre=round(pre_s*Fs); post=round(dur*Fs); rel=-pre:post; nRel=numel(rel);
bwin=1:pre; swin=pre+1:pre+post;
ol_starts=sort(d_s.stimStarts(data.nc(:)));
onF=zeros(numel(ol_starts),1);
for j=1:numel(ol_starts), [~,onF(j)]=min(abs(t_full-ol_starts(j))); end
onF=onF(onF>pre & onF+post<=T); nTr=numel(onF);

% whole-brain trial-avg deflection map (%dF, stim - pre) via SVD projection (cheap)
preFr=[]; stimFr=[];
for j=1:nTr, preFr=[preFr, onF(j)+rel(bwin)]; stimFr=[stimFr, onF(j)+rel(swin)]; end %#ok<AGROW>
dV = mean(V_cp(:,stimFr),2) - mean(V_cp(:,preFr),2);
deflMapRaw = Uflat*dV;                                  % [nPix x 1] raw dF deflection
deflMap = reshape(deflMapRaw ./ max(mimg_cp(:),eps), nY, nX) * 100;   % %dF (sign preserved)

% grid-pixel affectedness on the TRIAL-AVERAGED response (average over the 92 OL trials FIRST,
% then measure the dip -- NOT a single-trial statistic):
%   periAvg(px,t) = mean over trials of the peri-stim %dF trace
%   deflection    = mean(periAvg over STIM window) - mean(periAvg over PRE window)   (dip -> negative)
%   score         = deflection / SD(periAvg over PRE window)   = dip depth in baseline-SD units
% Affected (DOWNWARD only) iff score < -threshold. The pre baseline SD is the residual wobble of
% the AVERAGED trace over the 6 s pre-window -> a real dip must clear that floor.
Xg = double(Uflat(gridIdx,:))*V_cp;                     % [nG x T] dF
mIg = max(mimg_cp(gridIdx),eps);                        % per-grid mean image -> %dF
periAvg = zeros(nG,nRel);
for j=1:nTr, periAvg = periAvg + Xg(:, onF(j)+rel); end
periAvg = (periAvg / nTr) ./ mIg * 100;                 % [nG x nRel] TRIAL-AVERAGED %dF trace
defl    = mean(periAvg(:,swin),2) - mean(periAvg(:,bwin),2);   % trial-avg deflection (%dF), dip<0
base_sd = std(periAvg(:,bwin),0,2) + eps;               % temporal SD of the averaged baseline
zGrid   = defl ./ base_sd;                              % score (dip depth in baseline-SD units)

% package for callbacks
GD = struct('Uflat',Uflat,'V',V_cp,'mimg',mimg_cp,'onF',onF,'rel',rel,'pre',pre,'post',post, ...
    'bwin',bwin,'swin',swin,'Fs',Fs,'nY',nY,'nX',nX,'gridIdx',gridIdx,'grR',grR,'grC',grC,'nG',nG, ...
    'zGrid',zGrid,'defl',defl,'sd_pre',sd_pre,'deflMap',deflMap,'px_prim',px_prim,'py_prim',py_prim, ...
    'two_sided',two_sided,'sess_tag',sess_tag,'nTr',nTr,'dur',dur);

%% [GUI] non-blocking
% Reuse a single window: delete any prior instance of THIS detector so re-runs don't stack windows.
delete(findall(0,'Type','figure','Tag','ctrl_affected_gui'));
figA = figure('Color','w','Tag','ctrl_affected_gui', ...
    'Name',sprintf('Affected detector: %s',sess_tag),'Position',[60 60 1350 640]);
GD.axMap = axes('Parent',figA,'Position',[0.04 0.16 0.44 0.76]);
GD.axPix = axes('Parent',figA,'Position',[0.56 0.16 0.40 0.72]);
% threshold slider
sld_max = max(6, ceil(max(abs(zGrid))));                % cover the full score range
GD.sld = uicontrol(figA,'Style','slider','Units','normalized','Position',[0.10 0.05 0.32 0.03], ...
    'Min',0.5,'Max',sld_max,'Value',min(zThr0,sld_max),'Callback',@(s,~)aff_update(figA));
GD.txt = uicontrol(figA,'Style','text','Units','normalized','Position',[0.10 0.085 0.32 0.03], ...
    'String','','BackgroundColor','w','FontSize',10,'HorizontalAlignment','left');
uicontrol(figA,'Style','text','Units','normalized','Position',[0.035 0.045 0.06 0.035], ...
    'String','dip score','BackgroundColor','w','FontSize',9);
guidata(figA, GD);
set(figA,'WindowButtonDownFcn',@(f,~)aff_click(f));
aff_draw_map(figA);
aff_update(figA);
title(GD.axPix,'click a pixel to inspect its peri-stim trace');
fprintf('[CTRL-AFF] %s | GUI open. %d OL trials. Pre window [-%.0f,0]s. Slider = dip score; click any pixel.\n', sess_tag, nTr, pre_s);
fprintf('[CTRL-AFF] trial-averaged dip score (dip / averaged-baseline SD); grid range [%.1f, %.1f] (dips are negative)\n', min(zGrid), max(zGrid));

%% ---- callbacks ----
function aff_draw_map(figA)
GD=guidata(figA); ax=GD.axMap; cla(ax); hold(ax,'on');
lim=prctile(abs(GD.deflMap(~isnan(GD.deflMap))),99);
imagesc(ax, GD.deflMap, [-lim lim]); axis(ax,'image','ij','off');
colormap(ax, local_div()); cb=colorbar(ax); cb.Label.String='trial-avg \DeltaF/F stim-pre (%)';
plot(ax, GD.py_prim, GD.px_prim, 'g+','MarkerSize',15,'LineWidth',2.5);
GD.hGrid = scatter(ax, GD.grC, GD.grR, 22, [0 0 0], 'filled');  % recolored in aff_update
guidata(figA,GD);
end

function aff_update(figA)
GD=guidata(figA); z=get(GD.sld,'Value');
if GD.two_sided, aff = abs(GD.zGrid) > z; else, aff = GD.zGrid < -z; end   % DOWNWARD dips only
cols=repmat([0.15 0.55 0.95],GD.nG,1); cols(aff,:)=repmat([0.9 0.15 0.1],nnz(aff),1);
set(GD.hGrid,'CData',cols,'SizeData',22+18*double(aff));
set(GD.txt,'String',sprintf('dip score > %.2f  ->  %d affected / %d unaffected  (%.0f%% kept for predictor)', ...
    z, nnz(aff), GD.nG-nnz(aff), 100*(GD.nG-nnz(aff))/GD.nG));
title(GD.axMap, sprintf('%s: deflection map + contra grid (red=affected)', strrep(GD.sess_tag,'_','\_')));
GD.aff=aff; guidata(figA,GD);
end

function aff_click(figA)
GD=guidata(figA);
cp=get(GD.axMap,'CurrentPoint'); c=round(cp(1,1)); r=round(cp(1,2));
if r<1||r>GD.nY||c<1||c>GD.nX, return; end
p=sub2ind([GD.nY GD.nX],r,c);
tr=double(GD.Uflat(p,:))*GD.V;                          % pixel dF timecourse
mI=GD.mimg(r,c); if abs(mI)<eps, mI=1; end
M=zeros(GD.nTr,numel(GD.rel));
for j=1:GD.nTr, M(j,:)=tr(GD.onF(j)+GD.rel); end
M=(M/mI)*100; M=M-mean(M(:,GD.bwin),2);                 % %dF, per-trial baseline-sub
m=mean(M,1); se=std(M,0,1)/sqrt(GD.nTr);                % m = TRIAL-AVERAGED trace
defl=mean(m(GD.swin))-mean(m(GD.bwin));                 % trial-avg deflection (%dF), dip<0
zz=defl/(std(m(GD.bwin))+eps);                          % score = dip / averaged-baseline SD (matches grid)
z=get(GD.sld,'Value'); isAff = (GD.two_sided && abs(zz)>z) || (~GD.two_sided && zz<-z);
ax=GD.axPix; cla(ax); hold(ax,'on'); tt=GD.rel/GD.Fs;
yl=[min(m-se) max(m+se)]; if diff(yl)<=0, yl=[-1 1]; end
patch(ax,[tt(GD.bwin(1)) 0 0 tt(GD.bwin(1))],[yl(1) yl(1) yl(2) yl(2)],[0.6 0.6 0.6],'FaceAlpha',0.12,'EdgeColor','none');
patch(ax,[0 tt(GD.swin(end)) tt(GD.swin(end)) 0],[yl(1) yl(1) yl(2) yl(2)],[0.9 0.5 0.1],'FaceAlpha',0.10,'EdgeColor','none');
fill(ax,[tt fliplr(tt)],[m+se fliplr(m-se)],[0.2 0.4 0.8],'FaceAlpha',0.2,'EdgeColor','none');
plot(ax,tt,m,'-','Color',[0.1 0.2 0.6],'LineWidth',1.6); xline(ax,0,'k:'); yline(ax,0,'k:');
xlim(ax,[tt(1) tt(end)]); xlabel(ax,'time from stim (s)'); ylabel(ax,'\DeltaF/F (%)');
title(ax, sprintf('px (r%d,c%d): trial-avg dip=%.2f%%  score=%.2f  ->  %s', r,c,defl,zz, ...
    ternA(isAff,'AFFECTED','unaffected')));
% mark the clicked pixel on the map
GD2=guidata(figA); if isfield(GD2,'hMark')&&ishandle(GD2.hMark), delete(GD2.hMark); end
GD2.hMark=plot(GD.axMap, c, r, 'ko','MarkerSize',10,'LineWidth',1.5); guidata(figA,GD2);
end

function s=ternA(c,a,b); if c,s=a;else,s=b;end; end
function cm=local_div()
n=128; cm=[[linspace(0.15,1,n)' linspace(0.25,1,n)' linspace(0.75,1,n)']; ...
           [linspace(1,0.85,n)' linspace(1,0.20,n)' linspace(1,0.15,n)']];
end
