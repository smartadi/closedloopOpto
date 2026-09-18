% controller-analysis/f4_kernel_map.m
% Fig-4 contra->ipsi prediction KERNEL MAP (idea #1). Shows, on the mean brain image,
% how much each contralateral grid pixel contributes to predicting the ipsilateral
% target site -- i.e. the spatial weights of the stim-blind Global predictor. The
% contralateral HOMOLOG of the ipsi site should carry the strongest weight
% ("the ipsi site is predicted from its mirror in the other hemisphere").
% Replaces the abstract 3x3 grid cue on f4_decomp_schematic.
%
% Data (no SVD load needed): Stage-1 (grid coords, ipsi site, masks), Stage-2 ridge
% weights b (one per grid pixel), and the mean brain image from cp_stim_site cache.
% Exemplar: AL_0033_0415_e2 (ridge predictor).
clc; close all;
root='C:\Users\aditya\Documents\projects\brain_paper'; addpath(fullfile(root,'utils'));
dd=fullfile(root,'controller-analysis','data');
outfig=fullfile(root,'paper','images','figure4');
outview=fullfile(root,'controller-analysis','_preview');
if ~exist(outview,'dir'); mkdir(outview); end
tag='AL_0033_0415_e2';

S1=load(fullfile(dd,sprintf('ctrl_ols_spont_%s.mat',tag)));
[sfx,pmode]=ctrl_pred_tag(); assert(strcmp(pmode,'ridge'),'need ridge predictor');
S2=load(fullfile(dd,sprintf('ctrl_ols_ol_stimblind%s_%s.mat',sfx,tag)));
C =load(fullfile(dd,sprintf('cp_stim_site_ctrl_%s.mat',tag)));   % site rowcol (C.brain is BINARY)

b   = S2.b(:);                 % per grid-pixel weight (Su = 1..nGrid)
grR = S1.grR(:); grC = S1.grC(:);
brain = ctrl_mean_img(tag);    % ACTUAL mean SVD image (560x560, native frame)
[nY,nX]=size(brain);
% ipsi target site (col=px, row=py); cross-check with cp_stim_site rowcol
sx = S1.px_prim; sy = S1.py_prim;
if isfield(C,'rowcol') && numel(C.rowcol)>=2, sy=C.rowcol(1); sx=C.rowcol(2); end
fprintf('[f4_kernel_map] %d grid px | b range [%.3f %.3f] | ipsi site (col %d,row %d)\n', ...
    numel(b), min(b),max(b), round(sx),round(sy));

% ---- USER-DEFINED brain mask (the ROI drawn during contra-model setup) ----
% Clip to the user's defined brain mask via ctrl_brain_mask (one source of truth
% across all Fig-4 brain panels): the drawn ROI rasterized by Stage-1 (contra|ipsi),
% its boundary as the outline (outline == clip edge), and the drawn midline.
[brainMask,bnd,mid] = ctrl_brain_mask(tag);
haveROI = ~isempty(mid);

% ---- background: the actual mean brain image, contrast-stretched over in-ROI pixels ----
lo=prctile(brain(brainMask),1); hi=prctile(brain(brainMask),99);   % anatomy contrast
g=min(max((brain-lo)/max(hi-lo,eps),0),1);           % real grayscale brain (full range)
g=0.12+0.85*g;                                        % keep near-black off pure black
RGBbrain=cat(3,g,g,g);
mk3=repmat(~brainMask,1,1,3);                         % outside-ROI -> white
RGBbrain(mk3)=1;

% ---- per-pixel DOT weight map (each contra grid pixel = one dot, colored by weight) ----
f=paperFig(7.2,6.6); ax=axes(f); hold(ax,'on');
image(ax, RGBbrain);                             % masked gray brain (ignores colormap)
bmax=prctile(abs(b),99);                          % robust symmetric colour range
scatter(ax, grC, grR, 22, b, 'filled', 'MarkerEdgeColor','none', 'MarkerFaceAlpha',0.95);
% diverging blue-white-red colormap
cmap=interp1([0 .5 1],[0.16 0.34 0.66; 1 1 1; 0.78 0.16 0.12], linspace(0,1,256));
colormap(ax,cmap); clim(ax,[-bmax bmax]);
% brain-mask boundary (outline = clip) + the drawn midline
plot(ax,bnd(:,2),bnd(:,1),'-','Color',[.2 .2 .2],'LineWidth',0.9);
if haveROI
    plot(ax,mid.x,mid.y,':','Color',[.35 .35 .35],'LineWidth',0.8);
end
% ipsi target marker: plain green dot
plot(ax, sx, sy, 'o', 'MarkerSize',8, 'MarkerFaceColor',[0.15 0.65 0.20], 'MarkerEdgeColor','none');

axis(ax,'image'); set(ax,'YDir','reverse'); axis(ax,'off');
% crop to the drawn-ROI bounding box (tight framing on the brain)
[ry,rx]=find(brainMask); pad=12;
xlim(ax,[max(1,min(rx)-pad) min(nX,max(rx)+pad)]);
ylim(ax,[max(1,min(ry)-pad) min(nY,max(ry)+pad)]);
title(ax,{'Stim site linear predictor kernel weights', ...
    sprintf('%s, R^2_{te}=%.2f', strrep(tag,'_','\_'), S2.R2_te)}, ...
    'FontSize',PS_fs(),'FontWeight','bold');
cb=colorbar(ax); cb.Label.String='pixel weight (predicts ipsi)'; cb.FontSize=6; cb.Label.FontSize=6;
% label below the green dot
text(ax, double(sx), double(sy)+16, 'stimulation site', 'Color',[0.15 0.55 0.20],'FontSize',6,'FontWeight','bold', ...
    'HorizontalAlignment','center','VerticalAlignment','top');

paperExport(f, fullfile(outfig,'f4_kernel_map.pdf'));
paperExport(f, fullfile(outview,'f4_kernel_map.png'));
fprintf('[f4_kernel_map] wrote kernel map -> %s\n', outfig);

function s=PS_fs(); ps=paperStyle(); s=ps.fs; end
