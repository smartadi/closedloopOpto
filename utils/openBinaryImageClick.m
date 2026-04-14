function [img, clicks, mmResult, pixelCoords, bregmaPixelUsed] = openBinaryImageClick(filePath, imageSize, dataType, byteOrder, bregmaPixel, mmPerPixel)
if nargin < 2 || isempty(imageSize)
    imageSize = [560, 560];
end
if nargin < 3 || isempty(dataType)
    dataType = 'int16';
end
if nargin < 4 || isempty(byteOrder)
    byteOrder = 'n';
end
if nargin < 5
    bregmaPixel = [];
end
if nargin < 6 || isempty(mmPerPixel)
    mmPerPixel = 0.0173;
end

fid = fopen(filePath, 'r', byteOrder);
if fid == -1
    error('Could not open file: %s', filePath);
end

raw = fread(fid, prod(imageSize), ['*' dataType]);
fclose(fid);

if numel(raw) ~= prod(imageSize)
    error('File size does not match imageSize for %s', filePath);
end

img = reshape(raw, imageSize(1), imageSize(2))';

figure('Name', 'Binary Image Pixel Picker');
imagesc(img);
axis image;
colormap(gray);
colorbar;
title('Left click to pick pixels, press Enter to finish (mm query after)');
xlabel('X (column)');
ylabel('Y (row)');
hold on;

clicks = [];
mmResult = struct('x_mm', [], 'y_mm', [], 'row', [], 'col', [], 'value', [], 'isValid', false);
pixelCoords = [];
bregmaPixelUsed = bregmaPixel;

if ~isempty(bregmaPixel) && numel(bregmaPixel) == 2
    plot(bregmaPixel(1), bregmaPixel(2), 'go', 'MarkerSize', 8, 'LineWidth', 1.3);
    text(bregmaPixel(1) + 3, bregmaPixel(2), 'bregma', 'Color', 'g', 'FontSize', 8);
end

while true
    [x, y, button] = ginput(1);
    if isempty(button)
        break;
    end

    col = round(x);
    row = round(y);
    if row < 1 || row > size(img, 1) || col < 1 || col > size(img, 2)
        continue;
    end

    pixelValue = img(row, col);
    clicks(end+1, :) = [row, col, pixelValue];
    pixelCoords(end+1, :) = [col, row];
    plot(col, row, 'r+', 'MarkerSize', 10, 'LineWidth', 1.2);
    text(col + 3, row, num2str(pixelValue), 'Color', 'y', 'FontSize', 8);
    fprintf('Click %d -> row=%d, col=%d, value=%g\n', size(clicks, 1), row, col, pixelValue);
end

if ~isempty(clicks)
    bregmaPixelUsed = [clicks(1,2), clicks(1,1)];
    plot(bregmaPixelUsed(1), bregmaPixelUsed(2), 'go', 'MarkerSize', 10, 'LineWidth', 1.5);
    text(bregmaPixelUsed(1) + 3, bregmaPixelUsed(2), 'bregma(first click)', 'Color', 'g', 'FontSize', 8);
    fprintf('Bregma set from first click -> x=%d, y=%d\n', bregmaPixelUsed(1), bregmaPixelUsed(2));
end

mmInput = input('Enter [x_mm y_mm] offset from bregma (empty to skip): ', 's');
if ~isempty(strtrim(mmInput))
    mmVals = str2num(mmInput); %#ok<ST2NM>
    if numel(mmVals) ~= 2
        warning('Expected two numbers for [x_mm y_mm]. Skipping mm-based lookup.');
        return;
    end

    if isempty(bregmaPixelUsed) || numel(bregmaPixelUsed) ~= 2
        bregmaPixelUsed = input('Enter bregma pixel as [x y]: ');
        if isempty(bregmaPixelUsed) || numel(bregmaPixelUsed) ~= 2
            warning('Invalid bregma pixel input. Skipping mm-based lookup.');
            return;
        end
    end

    x_mm = mmVals(1);
    y_mm = mmVals(2);
    colFromMM = round(bregmaPixelUsed(1) + x_mm / mmPerPixel);
    rowFromMM = round(bregmaPixelUsed(2) - y_mm / mmPerPixel);

    if rowFromMM < 1 || rowFromMM > size(img, 1) || colFromMM < 1 || colFromMM > size(img, 2)
        warning('Converted mm coordinate is outside image bounds.');
        return;
    end

    valueFromMM = img(rowFromMM, colFromMM);
    mmResult.x_mm = x_mm;
    mmResult.y_mm = y_mm;
    mmResult.row = rowFromMM;
    mmResult.col = colFromMM;
    mmResult.value = valueFromMM;
    mmResult.isValid = true;
    mmResult.pixelCoord = [colFromMM, rowFromMM];
    mmResult.bregmaPixel = bregmaPixelUsed;

    plot(colFromMM, rowFromMM, 'cs', 'MarkerSize', 8, 'LineWidth', 1.3);
    text(colFromMM + 3, rowFromMM, sprintf('mm:%g', valueFromMM), 'Color', 'c', 'FontSize', 8);
    fprintf('MM query -> x_mm=%g, y_mm=%g => row=%d, col=%d, value=%g (0.0173 mm/pixel)\n', ...
        x_mm, y_mm, rowFromMM, colFromMM, valueFromMM);
end
end
