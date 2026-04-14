function pixels = convertXYmmToPixels(xy_mm, bregmaPixel, mmPerPixel)
% CONVERTXYMMTOPIXELS Convert [x_mm y_mm] offsets to [x_pix y_pix].
%   pixels = convertXYmmToPixels(xy_mm, bregmaPixel)
%   pixels = convertXYmmToPixels(xy_mm, bregmaPixel, mmPerPixel)
%
%   xy_mm       : Nx2 matrix [x_mm y_mm]
%   bregmaPixel : 1x2 [x_pix y_pix]
%   mmPerPixel  : scalar conversion (default 0.0173 mm/pixel)

if nargin < 3 || isempty(mmPerPixel)
    mmPerPixel = 0.0173;
end

if isempty(xy_mm)
    pixels = [];
    return;
end

if size(xy_mm, 2) ~= 2
    error('xy_mm must be an Nx2 matrix [x_mm y_mm].');
end

if isempty(bregmaPixel) || numel(bregmaPixel) ~= 2
    error('bregmaPixel must be [x y].');
end

xPix = round(bregmaPixel(1) + xy_mm(:,1) ./ mmPerPixel);
yPix = round(bregmaPixel(2) - xy_mm(:,2) ./ mmPerPixel);

pixels = [xPix, yPix];
end
