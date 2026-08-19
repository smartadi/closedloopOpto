% ctrl_affected_gui.m -- interactive STIM-AFFECTED contra-pixel detector for OL trials.
%
% DIP SCORE (robust; user refinements 2026-07-19):
%   Work on the TRIAL-AVERAGED peri-stim trace (average the 92 OL trials FIRST, then measure).
%   * REFERENCE = level at ONSET = mean over [-1,0] s  (NOT the long pre-mean) -> a pixel that
%     starts high and dips still reads clearly negative.
%   * DIP       = (trough - reference), trough = deepest 0.5 s sliding-window mean over [0,dur] s
%     -> a transient dip that recovers before the stim window ends still counts.
%   * NORMALIZE by the pre-window SD ([-6,0] s wobble of the averaged trace).
%   score = (trough - ref) / sd_pre  (negative = dip).
%   (Adaptive permutation selection was tried and rejected 2026-07-20: its null carries the same
%   trough-min bias, so it explains away the real midline dips as chance.)
%
% SELECTION IS RANK-BASED SINCE 2026-08-10. The score is unchanged; how it is CUT is not. An
%   absolute threshold asks for contra pixels the laser does not reach, and in controller sessions
%   the median contra pixel dips 1-4 SDs -- so the cut deleted 70-99% of the grid and only 1 of 13
%   sessions cleared ctrl_r2_floor(). The slider is now K = how many of the LEAST-affected pixels
%   to keep, and ctrl_select_k marks the K that Stage 2 would choose unattended (the smallest K
%   still clearing the floor). Set det_base.method='dip' to get the old absolute slider back.
%
% GUI (non-blocking): background = whole-brain trial-avg deflection map; contra grid coloured
%   red(affected)/blue(kept); slider = K; click any pixel -> its peri-stim trace over
%   [-10, dur+1] s with ref/trough/windows marked.
%
% PREREQS: ctrl_ols_spont.m (Stage 1) -> data/ctrl_ols_spont_<sess>.mat; `mouse`,`fields` in ws.

%% [CFG]
selField   = 4;
% BATCH override: ctrl_roi_build_all.m opens this GUI mid-flow for the session it is building.
if exist('BATCH_selField','var') && ~isempty(BATCH_selField); selField = BATCH_selField; end
nSV_load   = 500;
Fs         = 35;
pre_s      = 6.0;      % pre-window (for the baseline SD)  [-6,0] s
ref_s      = 1.0;      % onset-reference window  [-1,0] s
disp_pre_s = 10.0;     % click-inspector display: onset - 10 s ...
disp_post_s= 1.0;      % ... to stim_end + 1 s
trough_s   = 0.5;      % sliding-window length for the trough (s)
score_thr0 = 1.0;      % manual slider default (score < -thr => affected)
pre_dec_s  = 1.0;      % [Build predictor] decomposition baseline window  [-1,0] s
dip_tran_s = 0.5;      % [Build predictor] transient dip window  [0,dip_tran_s] s (metrics)
trl_pre_s  = 2.0;      % ipsi trial panel: display window [-trl_pre_s, dur+1] s
nSweep     = 14;       % [R^2 vs thr] sweep resolution
r2_floor   = ctrl_r2_floor();   % held-out spont R^2 a pixel set must reach to be admitted (0.85)

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
k_prim=S1.k_prim; horizon=S1.horizon; frames=S1.frames; itr=S1.itr; ite=S1.ite;
contra_mask=logical(S1.contra_mask); ipsi_mask=logical(S1.ipsi_mask);   % the DRAWN ROI (per hemisphere)
brain_mask=contra_mask|ipsi_mask;                                       % nothing outside this is valid
fprintf('[CTRL-AFF] masks: contra(predictor) %d px | ipsi(target) %d px | target box = mimg(px+/-%d)\n', ...
    nnz(contra_mask), nnz(ipsi_mask), k_prim);
% cp_loadUVt, not loadUVt: 5 controller sessions (m6 m7 m8 m11 m12) ship without
% blue/svdTemporalComponents.timestamps.npy and the vendored loader throws on them, which made
% this GUI unopenable for a third of the set. RESEARCH 2026-08-02.
[U_cp,V_cp,t_svd,mimg_cp]=cp_loadUVt(expPath(mn,td,en),nSV_load,d_s.timeBlue);
V_cp=double(V_cp); [nY,nX]=size(mimg_cp); nSV=size(U_cp,3);
Uflat=reshape(U_cp,nY*nX,nSV); t_full=t_svd(:); T=size(V_cp,2);
% predictor target: SVD raw-kernel + rolling baseline dF/F at the laser site (same as Stage 1/2)
[y_full,~]=local_svd_rolling_dfk(Uflat,V_cp,mimg_cp,px_prim,py_prim,k_prim,horizon,nY,nX);

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
% The detector lives in utils/ctrl_affected_detect.m -- the SAME call ctrl_ols_ol_stimblind.m
% makes, so the rule tuned here is the rule that builds the predictor. Slider moves re-run it
% with a new .thr (cheap: nG x nRel), which keeps methods whose gate is not a pure amplitude cut
% (e.g. 'dip_or_shape') honest under the slider instead of freezing them at one threshold.
det_base = struct('method','least_affected','wlen',wlen);   % PRIMARY since 2026-08-10; 'dip' = old absolute cut
if exist('BATCH_detect','var') && isstruct(BATCH_detect)      % set by ctrl_residual_build.m
    fn_d = fieldnames(BATCH_detect);
    for q_d = 1:numel(fn_d), det_base.(fn_d{q_d}) = BATCH_detect.(fn_d{q_d}); end
    det_base.wlen = wlen;
    if isfield(BATCH_detect,'thr') && ~isempty(BATCH_detect.thr), score_thr0 = BATCH_detect.thr; end
end
detW  = struct('iPre',iPre,'iRef',iRef,'iStim',iStim);
DET0  = ctrl_affected_detect(periAvg, detW, det_base);
zGrid = DET0.score;                                    % real trial-avg score (dip<0)
fprintf('[CTRL-AFF] detector = ''%s''  (%s)\n', DET0.method, DET0.note);

% whole-brain background deflection map (mean stim - mean pre), %dF -- context only
preFr=[]; stimFr=[];
for j=1:nTr, preFr=[preFr, onF(j)+rel(iPre)]; stimFr=[stimFr, onF(j)+rel(iStim)]; end %#ok<AGROW>
dV=mean(V_cp(:,stimFr),2)-mean(V_cp(:,preFr),2);
deflMap=reshape(Uflat*dV./max(mimg_cp(:),eps),nY,nX)*100;
deflMap(~brain_mask)=NaN;                                % FAITHFUL: never show activity off the drawn brain ROI

fprintf('[CTRL-AFF] %s | %d OL trials | score range [%.2f, %.2f]\n', ...
    sess_tag, nTr, min(zGrid), max(zGrid));

%% [COMPUTE-TRIALS] ipsi trial responses (canonical dFk, the scale ref=-5 lives in)
% Browsed in the third panel BEFORE any fitting, so a session with unusable ipsi trials is caught
% here rather than after a predictor has been built on it.
dfk_canon = data.dFk(:);
ref_lvl = -5; if isfield(d_s,'ref') && ~isempty(d_s.ref), ref_lvl = d_s.ref; end
nF_ok = min(T, numel(dfk_canon));
tpre = round(trl_pre_s*Fs); tpost = round((dur+1)*Fs); relT = -tpre:tpost; ttT = relT/Fs;
Aol_i = local_trials_(sort(d_s.stimStarts(data.nc(:))), t_full, dfk_canon, relT, tpre, tpost, nF_ok);
if isfield(data,'wc') && ~isempty(data.wc)
    Acl_i = local_trials_(sort(d_s.stimStarts(data.wc(:))), t_full, dfk_canon, relT, tpre, tpost, nF_ok);
else
    Acl_i = [];
end
fprintf('[CTRL-AFF] ipsi trials: %d OL / %d CL at the laser site (canonical dFk, ref=%.1f)\n', ...
    size(Aol_i,1), size(Acl_i,1), ref_lvl);

%% [COMPUTE-GRAM] subset-fit algebra, precomputed ONCE
% Every candidate pixel set is a SUBSET of the same grid and the z-scoring is per-pixel, so the
% normal equations for any subset are submatrices of one Gram matrix. Precomputing it makes the
% threshold sweep and every Build effectively instant (O(nU^3) instead of a fresh pass over 60k
% frames), and it reproduces ctrl_ols_ol_stimblind.m's fit EXACTLY -- same z-score from the train
% block, same 1e-6*mean(column energy) ridge, same train/test frames out of Stage 1.
% Built by utils/ctrl_gram_build.m and solved by utils/ctrl_fitsub.m -- the SAME two functions
% ctrl_ols_ol_stimblind.m and ctrl_select_k.m use, so what the slider shows and what Stage 2
% commits cannot diverge. (Was an inline copy here until 2026-08-10.)
FIT = ctrl_gram_build(Xg, frames, itr, ite, dfk_canon);
[~,R2_ceiling] = ctrl_fitsub(FIT, (1:nG).');        % full grid, no exclusions = the ceiling
fprintf('[CTRL-AFF] full-grid ceiling held-out R^2 = %.3f  |  admission floor = %.2f (ctrl_r2_floor)\n', ...
    R2_ceiling, r2_floor);
if R2_ceiling < r2_floor
    fprintf(2,['[CTRL-AFF] ** the ceiling itself is below the floor -- NO pixel subset can pass on ' ...
               'this session. This is a capacity property of the session; check the ROI/site, but ' ...
               'do not expect any K or threshold to rescue it. **\n']);
end

% --- automatic K, the value Stage 2 would commit unattended --------------------------
% Shown as a marker on the slider and the sweep so the manual choice is made against it rather
% than in the dark. The GUI is now for INSPECTION; K* is the default answer.
KSEL_gui = struct('used',false,'K_star',NaN,'R2_star',NaN,'reachable',false);
if strcmpi(det_base.method,'least_affected')
    KSEL_gui = ctrl_select_k(FIT, zGrid, struct('verbose',true));
    KSEL_gui.used = true;
end

%% [GUI]
delete(findall(0,'Type','figure','Tag','ctrl_affected_gui'));
figA=figure('Color','w','Tag','ctrl_affected_gui','Name',sprintf('Affected detector: %s',sess_tag), ...
    'Position',[50 60 1380 660]);
GD=struct('Uflat',Uflat,'V',V_cp,'mimg',mimg_cp,'onF',onF,'rel',rel,'iPre',iPre,'iRef',iRef, ...
    'iStim',iStim,'wlen',wlen,'Fs',Fs,'nY',nY,'nX',nX,'gridIdx',gridIdx,'grR',grR,'grC',grC,'nG',nG, ...
    'zGrid',zGrid,'deflMap',deflMap,'px_prim',px_prim,'py_prim',py_prim,'sess_tag',sess_tag,'nTr',nTr, ...
    'dur',dur,'mIg',mIg, ...
    'Xg',Xg,'y_full',y_full,'frames',frames,'itr',itr,'ite',ite, ...        % predictor inputs
    'contra_mask',contra_mask,'brain_mask',brain_mask,'k_prim',k_prim,'dfk_canon',data.dFk(:), ...  % faithful masks + canonical (ref=-5) target
    'pre_dec_s',pre_dec_s,'dip_tran_s',dip_tran_s,'here',here);
GD.FIT=FIT; GD.r2_floor=r2_floor; GD.R2_ceiling=R2_ceiling; GD.nSweep=nSweep;
GD.periAvg=periAvg; GD.detW=detW; GD.det_base=det_base;   % re-run the detector on every slider move
if isfield(S1,'Torient'), GD.Tor=S1.Torient; else, GD.Tor=[]; end   % [] = native (pre-orientation cache)
GD.Aol_i=Aol_i; GD.Acl_i=Acl_i; GD.ttT=ttT; GD.ref_lvl=ref_lvl;
GD.axMap=axes('Parent',figA,'Position',[0.030 0.17 0.30 0.74]);
GD.axPix=axes('Parent',figA,'Position',[0.375 0.17 0.26 0.74]);
GD.axTrl=axes('Parent',figA,'Position',[0.700 0.17 0.28 0.74]);   % ipsi trial browser
% Slider semantics follow the detector method: K (pixels kept, rank rule) or the dip-score cut.
GD.KSEL=KSEL_gui;
if strcmpi(det_base.method,'least_affected')
    sld_min=10; sld_max=nG; sld_lab='K (px kept)';
    if KSEL_gui.used && isfinite(KSEL_gui.K_star); sld_val=KSEL_gui.K_star; else; sld_val=round(nG/2); end
else
    sld_min=0.2; sld_max=max(4,ceil(max(abs(zGrid)))); sld_lab='dip score'; sld_val=min(score_thr0,sld_max);
end
GD.sld=uicontrol(figA,'Style','slider','Units','normalized','Position',[0.060 0.055 0.20 0.03], ...
    'Min',sld_min,'Max',sld_max,'Value',max(sld_min,min(sld_val,sld_max)),'Callback',@(s,~)aff_manual(figA));
GD.txt=uicontrol(figA,'Style','text','Units','normalized','Position',[0.030 0.100 0.64 0.032], ...
    'String','','BackgroundColor','w','FontSize',10,'HorizontalAlignment','left');
uicontrol(figA,'Style','text','Units','normalized','Position',[0.003 0.050 0.056 0.035], ...
    'String',sld_lab,'BackgroundColor','w','FontSize',8);
uicontrol(figA,'Style','pushbutton','Units','normalized','Position',[0.275 0.048 0.105 0.05], ...
    'String','Build predictor','FontSize',10,'FontWeight','bold','Callback',@(b,~)aff_build(figA));
uicontrol(figA,'Style','pushbutton','Units','normalized','Position',[0.390 0.048 0.115 0.05], ...
    'String','R^2 vs threshold','FontSize',9,'Callback',@(b,~)aff_sweep(figA));
GD.chkForce=uicontrol(figA,'Style','checkbox','Units','normalized','Position',[0.515 0.052 0.155 0.04], ...
    'String',sprintf('save below floor (%.2f)',r2_floor),'BackgroundColor','w','FontSize',8);
% ---- ipsi trial browser controls ----
uicontrol(figA,'Style','text','Units','normalized','Position',[0.700 0.098 0.10 0.030], ...
    'String','ipsi trials:','BackgroundColor','w','FontSize',9,'HorizontalAlignment','left');
GD.popCond=uicontrol(figA,'Style','popupmenu','Units','normalized','Position',[0.700 0.050 0.075 0.040], ...
    'String',{'OL','CL','both'},'Value',1,'Callback',@(s,~)aff_trials(figA));
GD.sldTrl=uicontrol(figA,'Style','slider','Units','normalized','Position',[0.790 0.055 0.150 0.030], ...
    'Min',0,'Max',max(1,size(Aol_i,1)),'Value',0,'Callback',@(s,~)aff_trials(figA));
GD.txtTrl=uicontrol(figA,'Style','text','Units','normalized','Position',[0.945 0.048 0.050 0.038], ...
    'String','mean','BackgroundColor','w','FontSize',8);
guidata(figA,GD);
set(figA,'WindowButtonDownFcn',@(f,~)aff_click(f));
aff_draw_map(figA); aff_manual(figA); aff_trials(figA);
title(GD.axPix,'click a contra pixel to inspect  [-10, dur+1] s');
if strcmpi(det_base.method,'least_affected')
    fprintf(['[CTRL-AFF] GUI open. Slider = K, how many of the LEAST-affected contra px to keep; it ' ...
             'starts at the automatic K*=%d. "R^2 vs K" sweeps the range so the %.2f floor and the ' ...
             'blindness/capacity tradeoff are both visible. Trial slider = browse single ipsi ' ...
             'trials (0 = mean only).\n'], round(get(GD.sld,'Value')), r2_floor);
else
    fprintf(['[CTRL-AFF] GUI open. Slider = dip threshold (affected if score < -thr). "R^2 vs K" ' ...
             'sweeps the slider range so you can see where the %.2f floor is met.\n'], r2_floor);
end

%% ---- score + callbacks ----
% (dip_score_ moved to utils/ctrl_affected_detect.m 2026-08-10 -- one detector, shared with
%  ctrl_ols_ol_stimblind.m, so the tuned rule and the built rule cannot drift apart)

function aff_draw_map(figA)
% Drawn entirely in the SESSION VIEW (GD.Tor, from cp_orient via the Stage-1 cache): map, contra
% outline, target box, site and grid all pass through the same transform, and aff_click inverts
% through it, so what you click is what you get.
GD=guidata(figA); ax=GD.axMap; cla(ax); hold(ax,'on');
T=GD.Tor;
dMap=cp_orient_img(T,GD.deflMap);
lim=prctile(abs(dMap(~isnan(dMap))),99); if isempty(lim)||~(lim>0), lim=1; end
him=imagesc(ax,dMap,[-lim lim]); set(him,'AlphaData',~isnan(dMap));  % off-brain -> transparent
axis(ax,'image','ij','off'); set(ax,'Color',[1 1 1]);
colormap(ax,local_div()); cb=colorbar(ax); cb.Label.String='trial-avg \DeltaF/F stim-pre (%)';
% contra (predictor) mask outline -- the model only ever reads pixels INSIDE this
contour(ax,double(cp_orient_img(T,GD.contra_mask)),[0.5 0.5],'Color',[0.35 0.35 0.35],'LineWidth',0.7);
% ipsi target footprint = the mimg(px_prim +/- k_prim) box y_full averages. Map both corners
% through the view so the rectangle stays on the box after a transpose or a flip.
k=GD.k_prim;
[c1r,c1c]=cp_orient_fwd(T,GD.px_prim-k,GD.py_prim-k);
[c2r,c2c]=cp_orient_fwd(T,GD.px_prim+k,GD.py_prim+k);
rectangle(ax,'Position',[min(c1c,c2c) min(c1r,c2r) abs(c2c-c1c) abs(c2r-c1r)], ...
    'EdgeColor',[0 0.6 0],'LineWidth',1.5);
[sR,sC]=cp_orient_fwd(T,GD.px_prim,GD.py_prim);
plot(ax,sC,sR,'g+','MarkerSize',15,'LineWidth',2.5);
[gR,gC]=cp_orient_fwd(T,GD.grR,GD.grC);
GD.hGrid=scatter(ax,gC,gR,22,[0 0 0],'filled'); guidata(figA,GD);
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

function aff = aff_apply_(GD, z)
% Re-run the shared detector at slider value z. z means K (pixels kept) under the rank rule and a
% dip-score cut under 'dip'; for 'dip' this is exactly the old GD.zGrid < -z.
o = GD.det_base;
if strcmpi(o.method,'least_affected'); o.keep_n = round(z); else; o.thr = z; end
R = ctrl_affected_detect(GD.periAvg, GD.detW, o);
aff = R.affected;
end

function aff_manual(figA)
GD=guidata(figA);
z=get(GD.sld,'Value'); aff=aff_apply_(GD,z);           % DOWNWARD dips only
if strcmpi(GD.det_base.method,'least_affected')
    aff_setmask(figA, aff, sprintf('keep the %d least-affected px',round(z)));
else
    aff_setmask(figA, aff, sprintf('%s: thr %.2f',GD.det_base.method,z));
end
end

function aff_build(figA)
% Fit the Global predictor on the CURRENT slider's unaffected px, deploy on OL trials,
% pop the trial-avg + per-trial validation figures, report dip metrics.
GD=guidata(figA);
z=get(GD.sld,'Value'); aff=aff_apply_(GD,z); unaff=~aff; Su=find(unaff); nU=numel(Su);
set(GD.txt,'String',sprintf('building predictor @ score<-%.2f  (%d unaff px)...',z,nU)); drawnow;
if nU < 10, set(GD.txt,'String',sprintf('only %d unaff px @ score<-%.2f -- loosen threshold.',nU,z)); return; end
Fs=GD.Fs;

% ---- dense OLS Global on spontaneous, unaffected px only ----
% Solved from the precomputed Gram (see [COMPUTE-GRAM]); algebraically identical to Stage 2's
% direct fit, just instant, which is what lets the sweep try the whole threshold range.
[b,R2te,R2tr]=ctrl_fitsub(GD.FIT,Su);
mu=GD.FIT.mu(Su); sd=GD.FIT.sd(Su); muY=GD.FIT.muY;
Gall=muY+(((GD.Xg(Su,:)-mu)./sd).')*b;                  % counterfactual "no-stim" ipsi, all frames

% ---- deploy on OL trials: Actual / Global / Local ----
pre_d=round(GD.pre_dec_s*Fs); post_d=round(GD.dur*Fs); reld=-pre_d:post_d;
bwin=1:pre_d; twin=pre_d+1:pre_d+round(GD.dip_tran_s*Fs); swin=pre_d+1:pre_d+post_d;
nTr=GD.nTr; A_tr=zeros(nTr,numel(reld)); G_tr=zeros(nTr,numel(reld));
for j=1:nTr, A_tr(j,:)=GD.dfk_canon(GD.onF(j)+reld).'; G_tr(j,:)=Gall(GD.onF(j)+reld).'; end
bl=@(M)M-mean(M(:,bwin),2); A_tr=bl(A_tr); G_tr=bl(G_tr); L_tr=A_tr-G_tr;
Aa=mean(A_tr,1); Gg=mean(G_tr,1); Lo=mean(L_tr,1);
capt=@(w)100*mean(Lo(w))/mean(Aa(w)); leak=@(w)100*mean(Gg(w))/mean(Aa(w));
[~,imn]=min(Aa); Ldip=mean(L_tr(:,twin),2);
tt=reld/Fs;

fprintf('\n[CTRL-AFF-BUILD] %s  score<-%.2f  -> %d unaff / %d aff px\n', GD.sess_tag,z,nU,GD.nG-nU);
fprintf('   Global dense-OLS spont R^2 = %.3f (train %.3f) | full-grid ceiling %.3f | floor %.2f -> %s\n', ...
    R2te, R2tr, GD.R2_ceiling, GD.r2_floor, ternstr_aff(R2te>=GD.r2_floor,'PASS','FAIL'));
fprintf('   window        Actual  Global  Local  | local%%  shared%%\n');
fprintf('   transient[0,%.1fs] %6.2f %6.2f %6.2f | %5.0f  %5.0f\n', GD.dip_tran_s,mean(Aa(twin)),mean(Gg(twin)),mean(Lo(twin)),capt(twin),leak(twin));
fprintf('   sustained[0,%gs]  %6.2f %6.2f %6.2f | %5.0f  %5.0f\n', GD.dur,mean(Aa(swin)),mean(Gg(swin)),mean(Lo(swin)),capt(swin),leak(swin));
fprintf('   trough @%.2fs     %6.2f %6.2f %6.2f\n', reld(imn)/Fs,Aa(imn),Gg(imn),Lo(imn));
fprintf('   per-trial Local dip (transient): median %.2f  IQR [%.2f %.2f]\n', median(Ldip),prctile(Ldip,25),prctile(Ldip,75));
% ---- ADMISSION GATE, then persist the threshold for ctrl_ols_ol_stimblind.m ----
% A pixel set below the floor is not written: the decomposition hands everything the predictor
% misses to Local, so admitting a weak Global would manufacture a large Local out of prediction
% error. Loosen the threshold (keep more pixels) until it passes -- and watch Local% as you do,
% because that is the tradeoff the gate is trading against.
pass = R2te >= GD.r2_floor;
force = get(GD.chkForce,'Value')==1;
thr_file = fullfile(GD.here,'data',sprintf('ctrl_aff_thr_%s.mat',GD.sess_tag));
if pass || force
    % The METHOD travels with the slider value, so Stage 2 rebuilds under the same rule. Under the
    % rank rule the slider IS K, so it is saved as keep_n -- writing it into .thr would silently
    % become a dip-score cut when Stage 2 read it back.
    det = GD.det_base;
    if strcmpi(det.method,'least_affected'), det.keep_n = round(z); else, det.thr = z; end
    aff_dip_thr = z; R2_at_save = R2te; R2_floor_used = GD.r2_floor; forced_below_floor = ~pass;
    save(thr_file,'aff_dip_thr','det','R2_at_save','R2_floor_used','forced_below_floor');
    if pass
        fprintf('   >> PASS (%.3f >= %.2f): saved dip threshold %.2f -> %s\n', R2te, GD.r2_floor, z, thr_file);
    else
        fprintf(2,'   >> FORCED SAVE BELOW FLOOR (%.3f < %.2f) -- flagged in the cache as forced_below_floor.\n', ...
            R2te, GD.r2_floor);
    end
    fprintf('   >> NEXT: ctrl_ols_ol_stimblind.m (auto-uses this threshold) then internal_model_principle.m\n');
    set(GD.txt,'ForegroundColor',[0 0.35 0], ...
        'String',sprintf('score<-%.2f | %d unaff px | R^2=%.2f (ceiling %.2f) | Local %.0f%%/%.0f%%  [SAVED%s]', ...
        z,nU,R2te,GD.R2_ceiling,capt(twin),capt(swin),ternstr_aff(pass,'','  FORCED')));
else
    fprintf(2,['   >> BELOW FLOOR: R^2 %.3f < %.2f -- threshold NOT saved. Loosen the dip threshold ' ...
               '(keep more px), or tick the checkbox to force.\n'], R2te, GD.r2_floor);
    set(GD.txt,'ForegroundColor',[0.7 0 0], ...
        'String',sprintf('score<-%.2f | %d unaff px | R^2=%.2f < floor %.2f (ceiling %.2f) -- NOT SAVED, loosen the threshold', ...
        z,nU,R2te,GD.r2_floor,GD.R2_ceiling));
end

% ---- FIG 1: trial-average decomposition + metrics ----
f1=findall(0,'Type','figure','Tag','ctrl_pred_avg'); if isempty(f1), f1=figure('Tag','ctrl_pred_avg'); else, clf(f1); figure(f1); end
set(f1,'Color','w','Name','Build: trial-average','Position',[70 400 620 470]); ax=axes(f1); hold(ax,'on');
sdA=std(A_tr,0,1)/sqrt(nTr);
fill(ax,[tt fliplr(tt)],[Aa+sdA fliplr(Aa-sdA)],[0 0 0],'FaceAlpha',0.12,'EdgeColor','none');
plot(ax,tt,Aa,'k-','LineWidth',2); plot(ax,tt,Gg,'-','Color',[0.85 0.4 0.1],'LineWidth',1.5);
plot(ax,tt,Lo,'-','Color',[0.1 0.5 0.85],'LineWidth',1.5);
xline(ax,0,'k:'); yline(ax,0,'k:'); xlim(ax,[tt(1) tt(end)]);
xlabel(ax,'time from stim (s)'); ylabel(ax,'\DeltaF/F (%)');
legend(ax,{'\pmSEM','Actual','Global (unaff contra)','Local = residual'},'Box','off','Location','southwest','FontSize',8);
title(ax,sprintf('score<-%.2f | %d px | R^2=%.2f | Local %.0f%%/%.0f%% (tran/sust)',z,nU,R2te,capt(twin),capt(swin)));

% ---- FIG 2: per-trial residual at work ----
f2=findall(0,'Type','figure','Tag','ctrl_pred_trials'); if isempty(f2), f2=figure('Tag','ctrl_pred_trials'); else, clf(f2); figure(f2); end
set(f2,'Color','w','Name','Build: single OL trials','Position',[720 120 1160 720]);
tl=tiledlayout(f2,2,3,'TileSpacing','compact','Padding','compact');
sel=round(linspace(2,nTr-1,6)); cL=[0.1 0.5 0.85];
for q=1:6
    i=sel(q); ax=nexttile(tl,q); hold(ax,'on');
    A=A_tr(i,:); G=G_tr(i,:); L=L_tr(i,:);
    fill(ax,[tt fliplr(tt)],[A fliplr(G)],cL,'FaceAlpha',0.12,'EdgeColor','none');
    plot(ax,tt,A,'k-','LineWidth',1.5); plot(ax,tt,G,'-','Color',[0.85 0.4 0.1],'LineWidth',1.3);
    plot(ax,tt,L,'-','Color',cL,'LineWidth',1.1);
    xline(ax,0,'k:'); yline(ax,0,'k:'); xlim(ax,[tt(1) tt(end)]);
    title(ax,sprintf('trial %d  (Local dip %.1f%%)',i,mean(L(twin))),'FontSize',9);
    if q>3, xlabel(ax,'time from stim (s)'); end
    if mod(q,3)==1, ylabel(ax,'\DeltaF/F (%)'); end
    if q==1, legend(ax,{'residual','Actual','Global','Local'},'Box','off','Location','southwest','FontSize',7); end
end
sgtitle(f2,sprintf('single OL trials: Actual vs Global, residual=Local  (score<-%.2f, %d unaff px)',z,nU));
figure(figA);   % keep the detector fronted for the next tweak
end

function aff_click(figA)
GD=guidata(figA);
cp=get(GD.axMap,'CurrentPoint'); cc=cp(1,1); rr=cp(1,2);   % DISPLAY (x=col, y=row)
[rr,cc]=cp_orient_inv(GD.Tor,rr,cc);                       % -> native (row,col), same view as the draw
ri=round(rr); ci=round(cc);
% FAITHFUL: ignore clicks outside the drawn contra (predictor) mask
if ri<1||ri>GD.nY||ci<1||ci>GD.nX || ~GD.contra_mask(ri,ci)
    set(GD.txt,'String','click INSIDE the grey contra outline -- that is where the model reads.'); return;
end
% snap to the NEAREST contra grid node -> always inspect an ACTUAL model pixel
[~,g]=min((GD.grR-rr).^2+(GD.grC-cc).^2);
r=GD.grR(g); c=GD.grC(g);
tr=GD.Xg(g,:); mI=GD.mIg(g);                 % precomputed grid-pixel dF + baseline (identical to detector)
M=zeros(GD.nTr,numel(GD.rel)); for j=1:GD.nTr, M(j,:)=tr(GD.onF(j)+GD.rel); end
M=(M/mI)*100; m=mean(M,1); se=std(M,0,1)/sqrt(GD.nTr);   % trial-avg trace (%dF, NOT baseline-sub)
ref=mean(m(GD.iRef));
Wm=movmean(m(GD.iStim),GD.wlen); [troughv,it]=min(Wm); troughT=GD.rel(GD.iStim(it))/GD.Fs;
sc=GD.zGrid(g);                              % EXACT detector score coloring this node (red/blue)
z=get(GD.sld,'Value'); isAff = sc < -z;
vtxt=sprintf('grid px #%d  score=%.2f (thr -%.2f)',g,sc,z);
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

% ---- predictor target (IDENTICAL to ctrl_ols_spont.m/ctrl_ols_ol_stimblind.m; keep in sync) ----
function [y, ok] = local_svd_rolling_dfk(Uflat, V, mimg, prow, pcol, k, horizon, nY, nX)
% SVD-reconstructed RAW kernel fluorescence -> rolling-baseline dF/F (getpixel mode-0 match).
y = nan(size(V,2),1);  ok = false;
if prow<1||prow>nY||pcol<1||pcol>nX; return; end
kr = max(1,prow-k):min(nY,prow+k);  kc = max(1,pcol-k):min(nX,pcol+k);
[KR,KC] = ndgrid(kr,kc);  kidx = sub2ind([nY,nX], KR(:), KC(:));
mI = mean(mimg(kr,kc),'all');
if ~isfinite(mI) || abs(mI) < eps; return; end
Fsvd = mean(double(Uflat(kidx,:)),1) * V;
Fraw = mI + Fsvd(:);
w = max(1, round(horizon)-1);  T = numel(Fraw);  ii = (1:T).';
cs = [0; cumsum(Fraw)];  lo = max(ii-w,1);
base = (cs(ii+1)-cs(lo))./(ii-lo+1);
y = (Fraw - base)./base*100;  y(1:w) = NaN;
ok = true;
end

% =================================================================================================
% PRE-FIT WORKBENCH (added 2026-08-05): ipsi trial browser, threshold sweep, subset-fit algebra
% =================================================================================================
function aff_trials(figA)
% Third panel: the ipsi laser-site response, trial by trial, in canonical units (the scale ref
% lives in). Shown BEFORE any predictor exists, so an unusable session is caught before it is fitted.
GD=guidata(figA); ax=GD.axTrl; cla(ax); hold(ax,'on'); box(ax,'on');
mode=get(GD.popCond,'Value');                                  % 1=OL 2=CL 3=both
sets={}; cols={}; names={};
if mode==1 || mode==3, sets{end+1}=GD.Aol_i; cols{end+1}=[0.85 0.20 0.15]; names{end+1}='OL'; end
if mode==2 || mode==3, sets{end+1}=GD.Acl_i; cols{end+1}=[0.15 0.40 0.80]; names{end+1}='CL'; end
tt=GD.ttT;  k=round(get(GD.sldTrl,'Value'));
nMax=0; for q=1:numel(sets), nMax=max(nMax,size(sets{q},1)); end
set(GD.sldTrl,'Max',max(1,nMax));
% stim window + reference level: the two landmarks every trial is read against
yl0=[-12 6];
patch(ax,[0 GD.dur GD.dur 0],[yl0(1) yl0(1) yl0(2) yl0(2)],[0.95 0.95 0.6], ...
    'FaceAlpha',0.25,'EdgeColor','none','HandleVisibility','off');
yline(ax,GD.ref_lvl,'--','Color',[0 0.55 0.2],'LineWidth',1.1);
hLeg=[]; lbl={};
for q=1:numel(sets)
    A=sets{q}; if isempty(A), continue; end
    n=size(A,1);
    plot(ax,tt,A.','-','Color',[cols{q} 0.10],'LineWidth',0.3,'HandleVisibility','off');  % every trial, faint
    m=mean(A,1,'omitnan'); se=std(A,0,1,'omitnan')/sqrt(n);
    fill(ax,[tt fliplr(tt)],[m+se fliplr(m-se)],cols{q},'FaceAlpha',0.20,'EdgeColor','none', ...
        'HandleVisibility','off');
    h=plot(ax,tt,m,'-','Color',cols{q},'LineWidth',2);
    hLeg(end+1)=h; lbl{end+1}=sprintf('%s mean (n=%d)',names{q},n); %#ok<AGROW>
    if k>=1 && k<=n
        h2=plot(ax,tt,A(k,:),'-','Color',min(cols{q}*0.6+0.1,1),'LineWidth',1.4);
        hLeg(end+1)=h2; lbl{end+1}=sprintf('%s trial %d',names{q},k); %#ok<AGROW>
    end
end
xline(ax,0,'k:'); xlim(ax,[tt(1) tt(end)]); ylim(ax,yl0);
xlabel(ax,'time from stim (s)'); ylabel(ax,'\DeltaF/F (%) at laser site');
if ~isempty(hLeg), legend(ax,hLeg,lbl,'Box','off','Location','southwest','FontSize',7); end
title(ax,sprintf('ipsi trial responses (ref %.1f)',GD.ref_lvl),'FontSize',9);
if k>=1, set(GD.txtTrl,'String',sprintf('trial %d',k)); else, set(GD.txtTrl,'String','mean'); end
end

function aff_sweep(figA)
% Held-out spontaneous R^2, unaffected-pixel count and Local share ACROSS the whole threshold
% range, so the admissible window is visible instead of being found by trial and error. Every fit
% comes from the precomputed Gram, so the whole sweep costs a fraction of a second.
GD=guidata(figA);
zs=linspace(get(GD.sld,'Min'),get(GD.sld,'Max'),GD.nSweep);
R2=nan(size(zs)); nU=nan(size(zs)); LocPct=nan(size(zs));
Fs=GD.Fs; pre_d=round(GD.pre_dec_s*Fs); post_d=round(GD.dur*Fs); reld=-pre_d:post_d;
bwin=1:pre_d; swin=pre_d+1:pre_d+post_d;
for q=1:numel(zs)
    Su=find(~aff_apply_(GD,zs(q)));                 % unaffected = whatever the detector keeps
    nU(q)=numel(Su);
    if nU(q)<10, continue; end
    [b,r2te]=ctrl_fitsub(GD.FIT,Su);  R2(q)=r2te;
    mu=GD.FIT.mu(Su); sd=GD.FIT.sd(Su);
    Gall=GD.FIT.muY+(((GD.Xg(Su,:)-mu)./sd).')*b;
    nTr=GD.nTr; A_tr=zeros(nTr,numel(reld)); G_tr=zeros(nTr,numel(reld));
    for j=1:nTr, A_tr(j,:)=GD.dfk_canon(GD.onF(j)+reld).'; G_tr(j,:)=Gall(GD.onF(j)+reld).'; end
    A_tr=A_tr-mean(A_tr(:,bwin),2); G_tr=G_tr-mean(G_tr(:,bwin),2);
    Aa=mean(A_tr,1); Lo=mean(A_tr-G_tr,1);
    if abs(mean(Aa(swin)))>0.2, LocPct(q)=100*mean(Lo(swin))/mean(Aa(swin)); end
end
ok=R2>=GD.r2_floor;
isK = strcmpi(GD.det_base.method,'least_affected');
if isK, xlab='K (px kept)'; else, xlab='dip thr'; end
fprintf('\n[CTRL-AFF-SWEEP] %s  (floor %.2f, ceiling %.3f)\n', GD.sess_tag, GD.r2_floor, GD.R2_ceiling);
fprintf('   %-10s %-8s %-8s %-8s\n',xlab,'nKept','R2_te','Local%');
for q=1:numel(zs)
    fprintf('   %-10.2f %-8d %-8.3f %-8.0f%s\n', zs(q), nU(q), R2(q), LocPct(q), ternstr_aff(ok(q),'  <= PASS',''));
end
if any(ok)
    fprintf('   admissible %s: %.2f .. %.2f  (blindest passing point keeps %d px, Local %.0f%%)\n', ...
        xlab, min(zs(ok)), max(zs(ok)), nU(find(ok,1,'first')), LocPct(find(ok,1,'first')));
else
    fprintf(2,'   NO point in the slider range reaches the floor on this session.\n');
end
if isK && isfield(GD,'KSEL') && GD.KSEL.used && GD.KSEL.reachable
    fprintf('   automatic K* = %d (R^2 %.3f) -- what Stage 2 commits unattended\n', ...
        GD.KSEL.K_star, GD.KSEL.R2_star);
end
f=findall(0,'Type','figure','Tag','ctrl_aff_sweep');
if isempty(f), f=figure('Tag','ctrl_aff_sweep'); else, clf(f); figure(f); end
set(f,'Color','w','Name','R^2 vs selection','Position',[120 200 780 460]);
ax=axes(f); hold(ax,'on'); box(ax,'on');
yyaxis(ax,'left');
plot(ax,zs,R2,'-o','LineWidth',1.6,'MarkerFaceColor','auto');
yline(ax,GD.r2_floor,'--','Color',[0.7 0 0],'LineWidth',1.2,'Label','floor');
yline(ax,GD.R2_ceiling,':','Color',[0.4 0.4 0.4],'Label','full-grid ceiling');
if isK && isfield(GD,'KSEL') && GD.KSEL.used && GD.KSEL.reachable
    xline(ax,GD.KSEL.K_star,'-','Color',[0 0.5 0],'LineWidth',1.4, ...
        'Label',sprintf('K* = %d',GD.KSEL.K_star),'LabelOrientation','horizontal');
end
ylabel(ax,'held-out spontaneous R^2');
yyaxis(ax,'right');
plot(ax,zs,LocPct,'-s','LineWidth',1.2);
ylabel(ax,'Local share of Actual (%, sustained)');
if isK
    xlabel(ax,'K = number of LEAST-affected contra px kept (more K = more capacity, more bleed)');
else
    xlabel(ax,'dip-score threshold (affected if score < -thr)');
end
title(ax,sprintf('%s: the gate and the Local share move in OPPOSITE directions', ...
    strrep(GD.sess_tag,'_','\_')),'FontSize',10);
figure(figA);
end

% (local_fitsub_ moved to utils/ctrl_fitsub.m 2026-08-10 -- shared with ctrl_select_k.m and
%  ctrl_ols_ol_stimblind.m so the sweep and the committed fit use one solver)

function A=local_trials_(starts, t_full, y, rel, pre, post, nF)
% Peri-onset trials of a single trace, same onset->frame rule as imp_build_session.
onF=zeros(numel(starts),1);
for j=1:numel(starts), [~,onF(j)]=min(abs(t_full-starts(j))); end
onF=onF(onF>pre & onF+post<=nF); n=numel(onF);
A=zeros(n,numel(rel));
for j=1:n, A(j,:)=y(onF(j)+rel).'; end
end

function s=ternstr_aff(c,a,b); if c, s=a; else, s=b; end; end
