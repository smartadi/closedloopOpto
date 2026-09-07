function info = cp_pixel_overlay(ax, MAP, T, opts)
%CP_PIXEL_OVERLAY  Draw the stim-blind pixel view for ONE session under a display view T.
%
% ONE renderer, shared by the orientation checker (ctrl_orient_checker, where T is being tuned by
% eye) and the session tuner (ctrl_softblind_session_tuner, where T is the FINALIZED saved view).
% Whatever you orient in the checker is pixel-for-pixel what every other tool shows, because both
% call this and this routes every layer through cp_orient_img/cp_orient_fwd with the same T.
%
% Layers (all through T): mean brain image (RGB gray, immune to clim) ; contra grid pixels colored
% by dip score (turbo) ; affected pixels (dip < -dipThr) ringed red ; data-derived laser-effect
% contours (yellow) ; laser spot (green +) ; controller output pixel d.params.pixel (magenta x) ;
% the anatomical midline (cyan dashed) plus a fixed vertical reference (grey) -- align the cyan to
% vertical and you have midline-vertical.
%
% MAP must carry NATIVE geometry for T to do anything live:
%   .mimg_native [nY x nX]  .gRn .gCn (native grid r,c)  .dip (per-px, orientation-free)
%   .dipMap_native [nY x nX] (optional)  .laserRn .laserCn (optional)  .ppRn .ppCn (optional)
%   .Tor (the view baked at cache-build; used only to seed T if T is [])
% Legacy caches without native fields fall back to the pre-oriented .img/.gR/.gC/... and IGNORE T
% (info.can_reorient=false), so the checker can tell the user a re-run is needed to re-orient them.
%
% opts .dipThr(1.33)  .show_midline(true)  .show_ref(true)  .title(true)
% info .nAff .nPx .dPP (output-px<->laser spot, NATIVE px, orientation-invariant) .can_reorient

if nargin < 4, opts = struct(); end
gv = @(f,d) local_get(opts,f,d);
dipThr = gv('dipThr',1.33); showMid = gv('show_midline',true);
showRef = gv('show_ref',true); doTitle = gv('title',true);

cla(ax); info = struct('nAff',NaN,'nPx',NaN,'dPP',NaN,'can_reorient',false);
native = isfield(MAP,'mimg_native') && ~isempty(MAP.mimg_native);

if native
    if isempty(T), if isfield(MAP,'Tor'), T = MAP.Tor; else, T = []; end; end
    info.can_reorient = true;
    bg = double(cp_orient_img(T, MAP.mimg_native));
    [gR,gC] = cp_orient_fwd(T, MAP.gRn(:), MAP.gCn(:));
    dip = MAP.dip(:);
    Dd = []; if isfield(MAP,'dipMap_native') && ~isempty(MAP.dipMap_native); Dd = double(cp_orient_img(T, MAP.dipMap_native)); end
    lR=NaN;lC=NaN; if isfield(MAP,'laserRn')&&isfinite(MAP.laserRn); [lR,lC]=cp_orient_fwd(T,MAP.laserRn,MAP.laserCn); end
    pR=NaN;pC=NaN; if isfield(MAP,'ppRn')&&isfinite(MAP.ppRn); [pR,pC]=cp_orient_fwd(T,MAP.ppRn,MAP.ppCn); end
    [Hd,Wd] = size(bg);
else                                                       % legacy: already-oriented, T ignored
    bg = double(MAP.img); dip = MAP.dip(:);
    gR = MAP.gR(:); gC = MAP.gC(:);
    Dd = []; if isfield(MAP,'dipMap'); Dd = double(MAP.dipMap); end
    lR=NaN;lC=NaN; if isfield(MAP,'laserR'); lR=MAP.laserR; lC=MAP.laserC; end
    pR=NaN;pC=NaN; if isfield(MAP,'ppR')&&isfinite(MAP.ppR); pR=MAP.ppR; pC=MAP.ppC; end
    [Hd,Wd] = size(bg);
end

q = quantile(bg(bg>0),[0.02 0.99]);                        % contrast stretch for clarity
bg = min(max((bg-q(1))/max(q(2)-q(1),eps),0),1);
image(ax, repmat(bg,[1 1 3])); axis(ax,'image','off'); hold(ax,'on');
colormap(ax, turbo);

aff = dip < -dipThr; info.nAff = nnz(aff); info.nPx = numel(dip);
scatter(ax,gC(~aff),gR(~aff),16,dip(~aff),'filled','MarkerFaceAlpha',0.85);
if info.nAff>0; scatter(ax,gC(aff),gR(aff),26,dip(aff),'filled','MarkerEdgeColor',[1 0 0],'LineWidth',0.8); end
try; clim(ax,[min(dip) 0]); catch; end

if ~isempty(Dd)
    dep = min(Dd(:),[],'omitnan');
    if isfinite(dep) && dep<0
        lv = unique(sort([0.35 0.55 0.80]*dep)); if numel(lv)<2; lv=[lv lv]; end
        contour(ax,Dd,lv,'LineWidth',1.2,'Color',[1 0.85 0.2]);
    end
end
if showRef; xline(ax,(Wd+1)/2,'-','Color',[0.7 0.7 0.7 0.6],'LineWidth',1.0); end
% cyan midline only when T is a REAL resolved cp_orient view (carries sym_native); a synthesized
% identity view has no known anatomical midline, so drawing one on the centre would be misleading.
if showMid && native && isfield(T,'mid_disp_col') && isfield(T,'sym_native')
    mc = T.mid_disp_col;
    [m1r,m1c] = local_rotpt(1, mc, T, Hd, Wd);
    [m2r,m2c] = local_rotpt(Hd, mc, T, Hd, Wd);
    plot(ax,[m1c m2c],[m1r m2r],'--','Color',[0.1 0.85 0.95],'LineWidth',1.4);
end
if isfinite(lR); plot(ax,lC,lR,'+','Color',[0.1 1 0.1],'MarkerSize',15,'LineWidth',2.6); end
if isfinite(pR)
    plot(ax,pC,pR,'x','Color',[1 0.2 1],'MarkerSize',13,'LineWidth',2.4);
    if native && isfield(MAP,'laserRn') && isfinite(MAP.laserRn)
        info.dPP = hypot(double(MAP.ppRn)-double(MAP.laserRn), double(MAP.ppCn)-double(MAP.laserCn));
    elseif ~native && isfinite(lR)
        info.dPP = hypot(double(pR)-double(lR), double(pC)-double(lC));
    end
end
if doTitle
    ttl = sprintf('affected (dip<-%.2f): %d/%d px', dipThr, info.nAff, info.nPx);
    if isfinite(info.dPP); ttl = sprintf('%s  |  output px %.0f px from laser spot', ttl, info.dPP); end
    if ~info.can_reorient; ttl = [ttl '   [legacy cache: re-run to re-orient]']; end
    title(ax, ttl);
end
hold(ax,'off');
end

% -- rotation-only point transform (mid_disp_col lives in the post-dihedral, pre-rotation frame) --
function [r2,c2] = local_rotpt(r, c, T, Hd, Wd)
if ~isfield(T,'rot') || T.rot==0, r2=r; c2=c; return; end
r0=(Hd+1)/2; c0=(Wd+1)/2; ph=T.rot*pi/180;
x=c-c0; y=r0-r; xr=x*cos(ph)-y*sin(ph); yr=x*sin(ph)+y*cos(ph);
c2=c0+xr; r2=r0-yr;
end
function v = local_get(s,f,d); if isfield(s,f)&&~isempty(s.(f)); v=s.(f); else; v=d; end; end
