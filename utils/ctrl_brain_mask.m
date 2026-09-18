function [mask,bnd,mid] = ctrl_brain_mask(tag)
% ctrl_brain_mask  The hand-drawn brain ROI for a controller session (Fig-4 panels).
% One source of truth so every brain-image panel is clipped to the SAME brain the user
% actually DREW in cp_roi_masks.m (STEP 1: click the full-brain outline). Returns the
% smooth drawn polygon -- NOT the pipeline's intensity-floored raster mask (contra|ipsi),
% which is that polygon minus sub-brightness pixels (ragged edges, dark holes) and is
% used only for pixel selection, not display.
%
%   [mask,bnd,mid] = ctrl_brain_mask(tag)
%     mask : logical brain mask (image size) = interior of the drawn outline polygon
%     bnd  : [row col] boundary of the mask (caller plots bnd(:,2) vs bnd(:,1))
%     mid  : struct .x .y drawn-midline endpoints ready to plot(mid.x,mid.y), or []
%
% Coordinate note: cp_roi_masks stores bx/by and mx/my as NATIVE (row,col). poly2mask
% and plotting take (x=col,y=row), so the polygon mask is poly2mask(by,bx,...) and the
% midline plots as x=my (col), y=mx (row). Getting this backwards transposes the brain
% and lays the (vertical) midline down flat.
%
% Example (clip a grayscale brain to the drawn ROI, white outside, draw outline+midline):
%   [m,bnd,mid]=ctrl_brain_mask(tag);
%   g=mat2gray(brain); g=0.35+0.55*g; RGB=cat(3,g,g,g); RGB(repmat(~m,1,1,3))=1;
%   image(RGB); plot(bnd(:,2),bnd(:,1),'-'); if ~isempty(mid), plot(mid.x,mid.y,':'); end
root='C:\Users\aditya\Documents\projects\brain_paper';
dd=fullfile(root,'controller-analysis','data');
% image size (and raster-mask fallback) from Stage-1
S1=load(fullfile(dd,sprintf('ctrl_ols_spont_%s.mat',tag)),'contra_mask','ipsi_mask');
[nY,nX]=size(S1.contra_mask);
mid=[];
try
    R=load(fullfile(dd,sprintf('cp_roi2_ctrl_%s.mat',tag)),'bx','by','mx','my');
    mask=poly2mask(R.by,R.bx,nY,nX);          % drawn outline interior (native row=bx, col=by)
    mid.x=R.my(:); mid.y=R.mx(:);             % plot midline as x=col, y=row
catch
    mask=logical(S1.contra_mask)|logical(S1.ipsi_mask);   % fallback: pipeline raster mask
end
b=bwboundaries(mask); [~,i]=max(cellfun(@(c)size(c,1),b)); bnd=b{i};
end
