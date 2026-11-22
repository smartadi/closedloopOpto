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
outfig=fullfile(root,'paper','images','figure4');   % working copy; final panel via paper_final_mirror
outview=fullfile(root,'controller-analysis','_preview');
if ~exist(outview,'dir'); mkdir(outview); end
tag='AL_0033_0415_e2';

% 2026-11-22 (research-hub #100, L-2026-11-22-e): the panel shows the LASSO weights. Aditya approved the
% lasso as the contra->ipsi predictor for Fig 4F-4H on 2026-11-21 (L-2026-11-21-b) and this switch on
% 2026-11-22 ("Approve"). The weights come from ctrl_sparse_kernel.m (R.b_lasso, same 408 grid pixels and
% predictors as the ridge b). pred = 'ridge' draws the Stage-2 ridge weights as before.
pred='lasso';
S1=load(fullfile(dd,sprintf('ctrl_ols_spont_%s.mat',tag)));
C =load(fullfile(dd,sprintf('cp_stim_site_ctrl_%s.mat',tag)));   % site rowcol (C.brain is BINARY)
if strcmp(pred,'lasso')
    K=load(fullfile(dd,sprintf('ctrl_sparse_kernel_%s.mat',tag))); K=K.R;
    assert(isequal(K.grR(:),S1.grR(:)) && isequal(K.grC(:),S1.grC(:)), 'f4_kernel_map:grid', 'lasso grid differs from Stage 1');
    b = K.b_lasso(:);          % per grid-pixel weight (Su = 1..nGrid); zero where the lasso drops the pixel
else
    [sfx,pmode]=ctrl_pred_tag(); assert(strcmp(pmode,'ridge'),'need ridge predictor');
    S2=load(fullfile(dd,sprintf('ctrl_ols_ol_stimblind%s_%s.mat',sfx,tag)));
    b = S2.b(:);               % per grid-pixel weight (Su = 1..nGrid)
end
grR = S1.grR(:); grC = S1.grC(:);
brain = ctrl_mean_img(tag);    % ACTUAL mean SVD image (560x560, native frame)
[nY,nX]=size(brain);
% ipsi target site (col=px, row=py); cross-check with cp_stim_site rowcol
sx = S1.px_prim; sy = S1.py_prim;
if isfield(C,'rowcol') && numel(C.rowcol)>=2, sy=C.rowcol(1); sx=C.rowcol(2); end
fprintf('[f4_kernel_map] %s: %d grid px, %d nonzero | b range [%.3f %.3f] | ipsi site (col %d,row %d)\n', ...
    pred, numel(b), nnz(b), min(b),max(b), round(sx),round(sy));

% ---- USER-DEFINED brain mask (the ROI drawn during contra-model setup) ----
% Clip to the user's defined brain mask via ctrl_brain_mask (one source of truth
% across all Fig-4 brain panels): the drawn ROI rasterized by Stage-1 (contra|ipsi),
% its boundary as the outline (outline == clip edge), and the drawn midline.
[brainMask,bnd,mid] = ctrl_brain_mask(tag);
haveROI = ~isempty(mid);

% ---- background: the actual mean brain image, contrast-stretched over in-ROI pixels ----
lo=prctile(brain(brainMask),1); hi=prctile(brain(brainMask),99);   % anatomy contrast
g=min(max((brain-lo)/max(hi-lo,eps),0),1);           % real grayscale brain (full range)
g=0.40+0.55*g;                                        % lighter anatomy so the weights read first (2026-11-19; was 0.12+0.85*g)
RGBbrain=cat(3,g,g,g);
mk3=repmat(~brainMask,1,1,3);                         % outside-ROI -> white
RGBbrain(mk3)=1;

% ---- per-pixel DOT weight map (each contra grid pixel = one dot, colored by weight) ----
f=jnFig(5.6,3.8); ax=axes(f); hold(ax,'on');   % JN Fig 4 row 3 left (2026-11-19: 5.6 x 3.8 to fill the row; was 4.5 x 3.3)
image(ax, RGBbrain);                             % masked gray brain (ignores colormap)
bmax=prctile(abs(b),99);                          % robust symmetric colour range
% one square per grid pixel, edge to edge (Aditya 2026-11-19: "F kernel representation looks too
% crowded"; the 408 dots overlapped by about 2x). Display only: the same weights b, no smoothing.
ur=unique(grR); uc=unique(grC);
assert(all(diff(ur)==13) && all(diff(uc)==13), 'f4_kernel_map:grid', 'grid step is not 13 px');
Wm=nan(numel(ur),numel(uc)); [~,ir]=ismember(grR,ur); [~,ic]=ismember(grC,uc);
Wm(sub2ind(size(Wm),ir,ic))=b;
hW=imagesc(ax, uc([1 end]), ur([1 end]), Wm); set(hW,'AlphaData',~isnan(Wm));
% diverging blue-white-red colormap
cmap=interp1([0 .5 1],[0.16 0.34 0.66; 1 1 1; 0.78 0.16 0.12], linspace(0,1,256));
colormap(ax,cmap); clim(ax,[-bmax bmax]);
% brain-mask boundary (outline = clip) + the drawn midline
plot(ax,bnd(:,2),bnd(:,1),'-','Color',[.2 .2 .2],'LineWidth',0.9);
if haveROI
    plot(ax,mid.x,mid.y,':','Color',[.35 .35 .35],'LineWidth',0.8);
end
% stimulation-site marker: plain black dot
plot(ax, sx, sy, 'o', 'MarkerSize',8, 'MarkerFaceColor','k', 'MarkerEdgeColor','none');

axis(ax,'image'); set(ax,'YDir','reverse'); axis(ax,'off');
% crop to the drawn-ROI bounding box (tight framing on the brain)
[ry,rx]=find(brainMask); pad=12;
xlim(ax,[max(1,min(rx)-pad) min(nX,max(rx)+pad)]);
ylim(ax,[max(1,min(ry)-pad) min(nY,max(ry)+pad)]);
title(ax,'Predictor kernel weights','FontSize',PS_fs()+1,'FontWeight','bold');   % 7 pt like every panel title (2026-11-19)
cb=colorbar(ax); cb.FontSize=6;                    % no label; only extreme ticks
cb.Ticks=[-bmax bmax]; cb.TickLabels={sprintf('%+.2f',-bmax),sprintf('%+.2f',bmax)};
cb.TickLength=0;
drawnow; ap=ax.Position; p=cb.Position;
cb.Position=[p(1) p(2)+0.15*p(4) 0.5*p(3) 0.7*p(4)];   % slimmer, shorter bar (2026-11-19)
ax.Position=ap;                                         % keep the map clear of the bar
% label below the green dot
text(ax, double(sx), double(sy)+16, {'stimulation','site'}, 'Color','k','FontSize',6,'FontWeight','bold', ...   % 2 lines: clear of the dots (2026-11-19)
    'HorizontalAlignment','center','VerticalAlignment','top');

paperExport(f, fullfile(outfig,'f4_kernel_map.pdf'));
paperExport(f, fullfile(outview,'f4_kernel_map.png'));
fprintf('[f4_kernel_map] wrote kernel map -> %s\n', outfig);

function s=PS_fs(); ps=paperStyle(); s=ps.fs; end
