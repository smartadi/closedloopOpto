%% stim_network_coupling.m
% [SNC] PROVE: photostim drives a DISTRIBUTED network-wide co-suppression of the
% contra hemisphere, not a focal optical/opsin bleed confined to the homotopic
% site. This is the physiological justification for treating the Global (contra
% -> ipsi) prediction's residual stim dip as legitimate shared-network
% disturbance (see internal_model_principle.m A=G+L decomposition), and it is the
% per-node feature the automated affected-pixel detector (Stage 2) thresholds.
%
% Claim, three independent tests on the contra grid nodes (all stim-triggered):
%   A1  spatial map   : per-node stim-evoked %dF/F dip rendered on the brain.
%   A2  distance law  : dip vs distance from the homotopic contra site. Focal
%                       bleed -> sharp PSF-width falloff; network -> broad/flat,
%                       significant suppression far beyond the focal radius.
%   A3  timecourse    : near vs far node dip timecourse + onset latency. An
%                       optical artifact is instantaneous (laser-locked step);
%                       network coupling has a physiological rise (tens of ms).
%
% Preconditions: run load_sessions.m first; Stage-1 cache
%   data/ctrl_ols_spont_<sess>.mat must exist (contra grid + masks + site).
% Reuses the SAME grid, masks, site, and per-pixel rolling-baseline dF/F as the
% predictor pipeline -- no new ROIs, no projection.
%
% Output: figure -> paper/images/predictor_saga/SNC_<sess>.png
%         struct  -> data/stim_network_coupling_<sess>.mat  (SNC)

%% [SNC-CFG] --------------------------------------------------------------------
selField   = 4;
nSV_load   = 500;
Fs         = 35;
pre_s      = 1.0;          % pre-stim baseline [-1,0] s
settle_win = [1 3];        % settled window (s) -> headline dip (post inhibitory transient)
early_win  = [0 3];        % full response window (s)
sig_z      = 2;            % |z| across trials -> node counts as significantly suppressed
rng(7,'twister');

PS = paperStyle();

assert(exist('mouse','var') && exist('fields','var'), '[SNC] run load_sessions.m first.');
here = fileparts(mfilename('fullpath'));
if isempty(here) || contains(here,tempdir,'IgnoreCase',true) || contains(here,'Editor_','IgnoreCase',true)
    here = fullfile(pwd,'controller-analysis'); if ~exist(here,'dir'); here = pwd; end
end
dataDir = fullfile(here,'data');
fig_dir = fullfile(here,'..','paper','images','predictor_saga'); if ~exist(fig_dir,'dir'); mkdir(fig_dir); end

%% [SNC-LOAD] -------------------------------------------------------------------
fld = fields{selField};
d_s = mouse.(fld).d;  data = mouse.(fld).data;
mn = mouse.(fld).mn; td = mouse.(fld).td; en = mouse.(fld).en;
sess_tag = sprintf('%s_%s%s_e%d', mn, td(6:7), td(9:10), en);
S1 = load(fullfile(dataDir, sprintf('ctrl_ols_spont_%s.mat', sess_tag)));
gridIdx=S1.gridIdx; grR=S1.grR; grC=S1.grC; nG=numel(gridIdx);
px_prim=S1.px_prim; py_prim=S1.py_prim; k_prim=S1.k_prim; horizon=S1.horizon; dur=S1.trial_dur;
contra_mask=logical(S1.contra_mask); ipsi_mask=logical(S1.ipsi_mask);

[U_cp,V_cp,t_svd,mimg_cp] = loadUVt(expPath(mn,td,en), nSV_load);
V_cp=double(V_cp); [nY,nX]=size(mimg_cp); nSV=size(U_cp,3);
Uflat=reshape(U_cp,nY*nX,nSV); t_full=t_svd(:); nF=min(size(V_cp,2),numel(t_full));

%% [SNC-NODE-DFF] per-node rolling-baseline %dF/F (single-pixel box, k=0) --------
% Identical baseline as the predictor target (local_svd_rolling_dfk), one pixel
% per grid node. This is what the contra grid "sees" during stim.
Xdf = nan(nG,nF);
for g=1:nG
    [yg,okg] = local_svd_rolling_dfk(Uflat,V_cp,mimg_cp,grR(g),grC(g),0,horizon,nY,nX);
    if okg, Xdf(g,:) = yg(1:nF).'; end
end
okNode = all(isfinite(Xdf(:,horizon:end)),2);           % nodes with a clean trace
fprintf('[SNC] %s | %d grid nodes (%d clean) | horizon %d\n', sess_tag, nG, nnz(okNode), horizon);

%% [SNC-TRIALS] stim-triggered node responses ----------------------------------
pre=round(pre_s*Fs); post=round(dur*Fs); rel=-pre:post; tt=rel/Fs;
w_set = pre+round(settle_win(1)*Fs)+1 : pre+round(settle_win(2)*Fs);   % settled samples
w_ear = pre+round(early_win(1)*Fs)+1  : pre+round(early_win(2)*Fs);
onOL = local_onframes(sort(d_s.stimStarts(data.nc(:))), t_full, pre, post, nF);
onCL = local_onframes(sort(d_s.stimStarts(data.wc(:))), t_full, pre, post, nF);
fprintf('[SNC] usable onsets: OL %d | CL %d\n', numel(onOL), numel(onCL));

% per-node, per-trial settled dip (baseline-subtracted). resp[nG x nTrial]
[Rol, Dset_ol] = local_node_trials(Xdf, onOL, rel, pre, w_set);   % Rol: nG x nRel avg; Dset: nG x nTrial
[Rcl, Dset_cl] = local_node_trials(Xdf, onCL, rel, pre, w_set);

dip_ol = mean(Dset_ol,2,'omitnan');                     % nG x 1 mean settled dip (OL)
dip_cl = mean(Dset_cl,2,'omitnan');
sem_ol = std(Dset_ol,0,2,'omitnan')./sqrt(sum(isfinite(Dset_ol),2));
z_ol   = dip_ol./sem_ol;                                 % across-trial z per node (OL)
sig_ol = okNode & (z_ol < -sig_z);                       % significantly SUPPRESSED nodes

%% [SNC-GEOM] homotopic contra site + distance ----------------------------------
% Midline column at the laser row from the mask boundary (orientation-robust).
mids = nan(nY,1);
for r=1:nY
    cc = find(contra_mask(r,:)); ci = find(ipsi_mask(r,:));
    if isempty(cc)||isempty(ci); continue; end
    if mean(cc) < mean(ci); mids(r)=0.5*(max(cc)+min(ci)); else; mids(r)=0.5*(max(ci)+min(cc)); end
end
midcol = mids(min(max(px_prim,1),nY)); if ~isfinite(midcol); midcol = mean(mids,'omitnan'); end
homo_row = px_prim;  homo_col = 2*midcol - py_prim;      % laser site mirrored across midline
dist_px  = hypot(grR-homo_row, grC-homo_col);            % node distance from homotopic site (px)
d_focal  = 2*k_prim;                                     % focal (laser-box) radius as bleed scale
dist_fr  = dist_px / d_focal;                            % distance in focal radii
[~,iPeak]= min(dip_ol + 1e6*~okNode);                    % empirical peak-suppressed node

%% [SNC-STATS] focal vs distributed --------------------------------------------
near = okNode & dist_px <= d_focal;                      % within one focal box
far  = okNode & dist_px >  2*d_focal;                    % well beyond bleed scale
frac_sig      = nnz(sig_ol)/nnz(okNode);
frac_sig_far  = nnz(sig_ol & far)/max(1,nnz(far));
dip_near      = mean(dip_ol(near),'omitnan');
dip_far       = mean(dip_ol(far),'omitnan');
b_dist        = local_pslope(dist_fr(okNode), dip_ol(okNode));   % dip vs distance slope
fprintf('\n[SNC-STATS] distributed co-suppression (OL, settled %g-%g s)\n', settle_win);
fprintf('  significantly suppressed nodes: %d/%d (%.0f%% of grid)\n', nnz(sig_ol), nnz(okNode), 100*frac_sig);
fprintf('  ... of the FAR nodes (>%.0f px = 2 focal radii): %d/%d (%.0f%%) still suppressed\n', 2*d_focal, nnz(sig_ol&far), nnz(far), 100*frac_sig_far);
fprintf('  mean dip  near (<=%.0f px) %.3f  vs  far (>%.0f px) %.3f  %%dF/F  (far/near %.2f)\n', d_focal, dip_near, 2*d_focal, dip_far, dip_far/dip_near);
fprintf('  dip vs distance slope: %+.4f %%dF/F per focal-radius (flat => distributed)\n', b_dist);

%% [SNC-LATENCY] near vs far dip onset latency ----------------------------------
grpN = local_grpavg(Rol, near); grpF = local_grpavg(Rol, far);
lat_near = local_onset_latency(grpN, tt, pre);
lat_far  = local_onset_latency(grpF, tt, pre);
fprintf('  onset latency (10%% of settled dip): near %.0f ms | far %.0f ms  (>0 => not an instantaneous artifact)\n', 1e3*lat_near, 1e3*lat_far);

%% [SNC-FIG] --------------------------------------------------------------------
figS = figure('Color','w','Position',[40 60 1500 460]);
tl = tiledlayout(figS,1,3,'TileSpacing','compact','Padding','compact');

% (A1) spatial dip map
ax1 = nexttile(tl,1); hold(ax1,'on'); axis(ax1,'image','ij','off');
imagesc(ax1, mat2gray(mimg_cp)); colormap(ax1,gray);
cl = max(0.2, prctile(-dip_ol(okNode),95));             % symmetric-ish suppression scale
scatter(ax1, grC(okNode), grR(okNode), 34, dip_ol(okNode), 'filled', 'MarkerEdgeColor',[.2 .2 .2],'LineWidth',0.3);
sig_c = sig_ol; scatter(ax1, grC(sig_c), grR(sig_c), 60, 'o', 'MarkerEdgeColor',[0 0 0],'LineWidth',0.8);
plot(ax1, py_prim, px_prim, 'g+', 'MarkerSize',14,'LineWidth',2);        % laser (ipsi)
plot(ax1, homo_col, homo_row, 'o','Color',[0 0.7 0],'MarkerSize',12,'LineWidth',1.6); % homotopic (contra)
plot(ax1, grC(iPeak), grR(iPeak), 'mp','MarkerSize',12,'LineWidth',1.4); % peak-dip node
clim(ax1,[-cl cl]); cmap = local_bwr(); colormap(ax1,cmap);
cb=colorbar(ax1); cb.Label.String='settled dip (%\DeltaF/F)';
title(ax1,'(A1) stim-evoked contra dip (OL)','FontWeight','normal');

% (A2) dip vs distance
ax2 = nexttile(tl,2); hold(ax2,'on');
scatter(ax2, dist_fr(okNode&~sig_ol), dip_ol(okNode&~sig_ol), 16,[.6 .6 .6],'filled','MarkerFaceAlpha',0.5);
scatter(ax2, dist_fr(sig_ol), dip_ol(sig_ol), 20,[0.85 0.1 0.1],'filled','MarkerFaceAlpha',0.7);
[be,bm,bs] = local_bin(dist_fr(okNode), dip_ol(okNode), 8);
errorbar(ax2, be, bm, bs, '-o','Color','k','LineWidth',1.4,'MarkerFaceColor','k','CapSize',3);
yline(ax2,0,':','Color',[.5 .5 .5]); xline(ax2,1,'--','Color',[0 0.6 0],'Label','focal radius');
xlabel(ax2,'distance from homotopic site (focal radii)'); ylabel(ax2,'settled dip (%\DeltaF/F)');
title(ax2,sprintf('(A2) distance law  (slope %+.3f, flat=distributed)',b_dist),'FontWeight','normal');

% (A3) near vs far timecourse
ax3 = nexttile(tl,3); hold(ax3,'on');
local_shade(ax3, tt, grpN.m, grpN.e, [0.85 0.1 0.1]);
local_shade(ax3, tt, grpF.m, grpF.e, [0.1 0.3 0.85]);
plot(ax3, tt, grpN.m,'-','Color',[0.85 0.1 0.1],'LineWidth',1.6,'DisplayName',sprintf('near (<=%.0f px, n=%d)',d_focal,nnz(near)));
plot(ax3, tt, grpF.m,'-','Color',[0.1 0.3 0.85],'LineWidth',1.6,'DisplayName',sprintf('far (>%.0f px, n=%d)',2*d_focal,nnz(far)));
xline(ax3,0,':','Color',[.5 .5 .5]); yline(ax3,0,':','Color',[.5 .5 .5]);
patch(ax3,[settle_win(1) settle_win(2) settle_win(2) settle_win(1)],[min(ylim(ax3)) min(ylim(ax3)) max(ylim(ax3)) max(ylim(ax3))],[.4 .4 .4],'FaceAlpha',0.06,'EdgeColor','none','HandleVisibility','off');
xlabel(ax3,'time from stim (s)'); ylabel(ax3,'%\DeltaF/F'); xlim(ax3,[tt(1) tt(end)]);
title(ax3,sprintf('(A3) timecourse  (latency near %.0f / far %.0f ms)',1e3*lat_near,1e3*lat_far),'FontWeight','normal');
legend(ax3,'Location','southwest','Box','off');

sgtitle(figS, sprintf('[SNC] stim -> distributed contra co-suppression   %s   (%.0f%% of grid suppressed, %.0f%% of FAR nodes)', ...
    strrep(sess_tag,'_','\_'), 100*frac_sig, 100*frac_sig_far));
fig_png = fullfile(fig_dir, sprintf('SNC_%s.png', sess_tag));
exportgraphics(figS, fig_png, 'Resolution',300);
fprintf('[SNC] figure -> %s\n', fig_png);

%% [SNC-SAVE] -------------------------------------------------------------------
SNC = struct('sess_tag',sess_tag,'selField',selField,'settle_win',settle_win, ...
    'gridIdx',gridIdx,'grR',grR,'grC',grC,'nG',nG,'okNode',okNode, ...
    'dip_ol',dip_ol,'dip_cl',dip_cl,'sem_ol',sem_ol,'z_ol',z_ol,'sig_ol',sig_ol, ...
    'dist_px',dist_px,'dist_fr',dist_fr,'d_focal',d_focal,'homo_row',homo_row,'homo_col',homo_col, ...
    'frac_sig',frac_sig,'frac_sig_far',frac_sig_far,'dip_near',dip_near,'dip_far',dip_far, ...
    'b_dist',b_dist,'lat_near',lat_near,'lat_far',lat_far, ...
    'Rol',Rol,'Rcl',Rcl,'tt',tt,'px_prim',px_prim,'py_prim',py_prim,'k_prim',k_prim);
save(fullfile(dataDir, sprintf('stim_network_coupling_%s.mat', sess_tag)), 'SNC');
fprintf('[SNC] struct -> data/stim_network_coupling_%s.mat\n', sess_tag);

%% ===== local functions =======================================================
function onF = local_onframes(starts, t_full, pre, post, nF)
onF = zeros(numel(starts),1);
for j=1:numel(starts), [~,onF(j)] = min(abs(t_full-starts(j))); end
onF = onF(onF>pre & onF+post<=nF);
end

function [Ravg, Dset] = local_node_trials(Xdf, onF, rel, pre, w_set)
% Ravg: nG x nRel trial-averaged, baseline-subtracted node response.
% Dset: nG x nTrial per-trial settled dip (mean over w_set, baseline-subtracted).
nG=size(Xdf,1); nT=numel(onF); nR=numel(rel);
Dset=nan(nG,nT);
acc=zeros(nG,nR); cnt=zeros(nG,nR);
for j=1:nT
    seg=Xdf(:,onF(j)+rel);                          % nG x nRel
    seg=seg - mean(seg(:,1:pre),2,'omitnan');       % baseline-subtract per node
    Dset(:,j)=mean(seg(:,w_set),2,'omitnan');
    good=isfinite(seg); acc(good)=acc(good)+seg(good); cnt=cnt+good;
end
Ravg=acc./max(cnt,1); Ravg(cnt==0)=NaN;
end

function G = local_grpavg(R, sel)
m=mean(R(sel,:),1,'omitnan'); e=std(R(sel,:),0,1,'omitnan')./sqrt(max(1,nnz(sel)));
G=struct('m',m,'e',e);
end

function lat = local_onset_latency(G, tt, pre)
% time (s from stim) at which the group dip first reaches 10% of its settled depth
m=G.m; post=pre+1:numel(m); mp=m(post); tp=tt(post);
depth=min(mp); if ~isfinite(depth)||depth>=0; lat=NaN; return; end
thr=0.10*depth; hit=find(mp<=thr,1,'first');
if isempty(hit); lat=NaN; else; lat=tp(hit); end
end

function [be,bm,bs] = local_bin(x,y,nb)
x=x(:); y=y(:); ok=isfinite(x)&isfinite(y); x=x(ok); y=y(ok);
ed=linspace(min(x),max(x),nb+1); be=0.5*(ed(1:end-1)+ed(2:end)); bm=nan(1,nb); bs=nan(1,nb);
for i=1:nb
    m=x>=ed(i)&x<ed(i+1); if i==nb, m=x>=ed(i)&x<=ed(i+1); end
    if any(m), bm(i)=mean(y(m)); bs(i)=std(y(m))/sqrt(nnz(m)); end
end
end

function b=local_pslope(X,Y)
x=X(:); y=Y(:); ok=isfinite(x)&isfinite(y); x=x(ok); y=y(ok);
c=[ones(numel(x),1) x]\y; b=c(2);
end

function local_shade(ax,x,m,e,col)
x=x(:).'; m=m(:).'; e=e(:).'; ok=isfinite(m)&isfinite(e);
fill(ax,[x(ok) fliplr(x(ok))],[m(ok)+e(ok) fliplr(m(ok)-e(ok))],col,'FaceAlpha',0.12,'EdgeColor','none','HandleVisibility','off');
end

function cmap = local_bwr()
n=128; b=[linspace(0.1,1,n).' linspace(0.3,1,n).' linspace(0.85,1,n).'];
r=[linspace(1,0.85,n).' linspace(1,0.1,n).' linspace(1,0.1,n).'];
cmap=[b;r];
end

function [y, ok] = local_svd_rolling_dfk(Uflat, V, mimg, prow, pcol, k, horizon, nY, nX)
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
