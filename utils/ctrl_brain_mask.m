function [mask,bnd,mid] = ctrl_brain_mask(tag)
% ctrl_brain_mask  Canonical Fig-4 brain mask for a controller session.
% One source of truth so every brain-image panel is clipped to the SAME drawn/defined
% brain (the ROI drawn in ctrl_roi_draw_all, rasterized by Stage-1). Use this instead
% of the raw camera-frame image (cp_stim_site .brain).
%
%   [mask,bnd,mid] = ctrl_brain_mask(tag)
%     mask : logical brain mask (image size) = Stage-1 contra_mask | ipsi_mask
%     bnd  : [row col] boundary of the largest mask component (outline == clip edge)
%     mid  : struct .x .y drawn-midline endpoints (from cp_roi2), or [] if absent
%
% Example (clip a grayscale brain to the ROI, white outside, draw outline+midline):
%   [m,bnd,mid]=ctrl_brain_mask(tag);
%   g=mat2gray(brain); g=0.35+0.55*g; RGB=cat(3,g,g,g); RGB(repmat(~m,1,1,3))=1;
%   image(RGB); plot(bnd(:,2),bnd(:,1),'-'); if ~isempty(mid), plot(mid.x,mid.y,':'); end
root='C:\Users\aditya\Documents\projects\brain_paper';
dd=fullfile(root,'controller-analysis','data');
S1=load(fullfile(dd,sprintf('ctrl_ols_spont_%s.mat',tag)),'contra_mask','ipsi_mask');
mask=logical(S1.contra_mask)|logical(S1.ipsi_mask);
b=bwboundaries(mask); [~,i]=max(cellfun(@(c)size(c,1),b)); bnd=b{i};
mid=[];
try
    R=load(fullfile(dd,sprintf('cp_roi2_ctrl_%s.mat',tag)),'mx','my');
    mid.x=R.mx(:); mid.y=R.my(:);
catch
end
end
