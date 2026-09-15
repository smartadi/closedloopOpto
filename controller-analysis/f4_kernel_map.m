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
C =load(fullfile(dd,sprintf('cp_stim_site_ctrl_%s.mat',tag)));   % brain image + site

b   = S2.b(:);                 % per grid-pixel weight (Su = 1..nGrid)
grR = S1.grR(:); grC = S1.grC(:);
brain = double(C.brain);       % mean image (560x560)
[nY,nX]=size(brain);
% ipsi target site (col=px, row=py); cross-check with cp_stim_site rowcol
sx = S1.px_prim; sy = S1.py_prim;
if isfield(C,'rowcol') && numel(C.rowcol)>=2, sy=C.rowcol(1); sx=C.rowcol(2); end
fprintf('[f4_kernel_map] %d grid px | b range [%.3f %.3f] | ipsi site (col %d,row %d)\n', ...
    numel(b), min(b),max(b), round(sx),round(sy));

% ---- background: grayscale brain as RGB (ignores colormap) ----
g = mat2gray(brain); g = 0.35 + 0.55*g;              % lighten for overlay contrast
RGBbrain = cat(3,g,g,g);

% ---- interpolate + smooth the per-pixel weights into a contra heatmap ----
[XX,YY]=meshgrid(1:nX,1:nY);
F=scatteredInterpolant(grC,grR,b,'natural','none'); W0=F(XX,YY);
cmask = logical(S1.contra_mask); W0(isnan(W0))=0;
Ws=imgaussfilt(W0,5); Ws(~cmask)=NaN;
bmax=prctile(abs(Ws(cmask)),99);

f=paperFig(7.2,6.6); ax=axes(f); hold(ax,'on');
image(ax, RGBbrain);                             % gray brain (ignores colormap)
hW=imagesc(ax, Ws); set(hW,'AlphaData', 0.82*double(cmask));   % weight heatmap over contra
% diverging blue-white-red colormap
cmap=interp1([0 .5 1],[0.16 0.34 0.66; 1 1 1; 0.78 0.16 0.12], linspace(0,1,256));
colormap(ax,cmap); clim(ax,[-bmax bmax]);
% ipsi target marker
plot(ax, sx, sy, 'p', 'MarkerSize',12, 'MarkerFaceColor',[1 .85 .1], 'MarkerEdgeColor','k','LineWidth',0.6);
% arrow from contra weight centroid -> ipsi site (in-axes, data coords)
wpos=max(b,0); wc_c=sum(grC.*wpos)/sum(wpos); wc_r=sum(grR.*wpos)/sum(wpos);
quiver(ax, wc_c, wc_r, sx-wc_c, sy-wc_r, 0, 'Color',[.1 .1 .1], 'LineWidth',1.3, 'MaxHeadSize',0.4);
% midline (if available)
try
    R=load(fullfile(dd,sprintf('cp_roi2_ctrl_%s.mat',tag)));
    fn=fieldnames(R);
    for i=1:numel(fn), v=R.(fn{i});
        if isnumeric(v)&&ismatrix(v)&&size(v,1)==2&&size(v,2)==2
            plot(ax, v(:,1), v(:,2), ':', 'Color',[.35 .35 .35],'LineWidth',0.8); break; end
    end
catch; end

axis(ax,'image'); set(ax,'YDir','reverse'); axis(ax,'off');
xlim(ax,[1 nX]); ylim(ax,[1 nY]);
title(ax,sprintf('Contra\\rightarrowipsi prediction kernel (%s, R^2_{te}=%.2f)', ...
    strrep(tag,'_','\_'), S2.R2_te),'FontSize',PS_fs(),'FontWeight','bold');
cb=colorbar(ax); cb.Label.String='pixel weight (predicts ipsi)'; cb.FontSize=6; cb.Label.FontSize=6;
% legend-ish text
text(ax, double(sx)+10, double(sy), 'ipsi target', 'Color',[.15 .15 .15],'FontSize',6,'FontWeight','bold');

paperExport(f, fullfile(outfig,'f4_kernel_map.pdf'));
paperExport(f, fullfile(outview,'f4_kernel_map.png'));
fprintf('[f4_kernel_map] wrote kernel map -> %s\n', outfig);

function s=PS_fs(); ps=paperStyle(); s=ps.fs; end
