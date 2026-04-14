function [pixelCoords, pixelValues, mmPositions] = getPixelValuesFromMMPositionsImage(img, bregmaPixel, mmPositions, mmPerPixel)
if nargin < 4 || isempty(mmPerPixel)
    mmPerPixel = 0.0173;
end

if nargin < 2 || isempty(bregmaPixel) || numel(bregmaPixel) ~= 2
    error('bregmaPixel must be provided as [x y].');
end

if isempty(img) || ndims(img) ~= 2
    error('img must be a non-empty 2D matrix.');
end

if nargin < 3 || isempty(mmPositions)
    n = input('Enter number of mm positions (n): ');
    if isempty(n) || n < 1 || mod(n,1) ~= 0
        error('n must be a positive integer.');
    end

    mmPositions = zeros(n, 2);
    for k = 1:n
        mmPos = input(sprintf('Enter [x_mm y_mm] for position %d: ', k));
        if isempty(mmPos) || numel(mmPos) ~= 2
            error('Each position must be [x_mm y_mm].');
        end
        mmPositions(k, :) = mmPos;
    end
end

if size(mmPositions, 2) ~= 2
    error('mmPositions must be an Nx2 matrix of [x_mm y_mm].');
end

nPos = size(mmPositions, 1);
pixelCoords = nan(nPos, 2);
pixelValues = nan(nPos, 1);

for k = 1:nPos
    x_mm = mmPositions(k, 1);
    y_mm = mmPositions(k, 2);

    col = round(bregmaPixel(1) + x_mm / mmPerPixel);
    row = round(bregmaPixel(2) - y_mm / mmPerPixel);

    pixelCoords(k, :) = [col, row];

    if row >= 1 && row <= size(img, 1) && col >= 1 && col <= size(img, 2)
        pixelValues(k) = img(row, col);
    else
        warning('Position %d is outside image bounds. Returning NaN for value.', k);
    end
end

fprintf('Returned pixelCoords as Nx2 [x y] and pixelValues as Nx1.\n');
end
