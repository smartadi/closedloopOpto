function data = getpixels_trace(d, serverRoot)
% GETPIXELS_TRACE Compute raw pixel traces (no dF/F normalization)

if nargin < 2 || isempty(serverRoot)
    serverRoot = expPath(d.mn, d.td, d.en);
end

pathData = append(d.mn, 'pixelsTrace', d.td(6:7), d.td(9:10), int2str(d.en), '.mat');

if exist(pathData, 'file')
    data = load(pathData);
    return;
end

k = d.params.kernel;
pixel = d.params.pixels;

expRoot = serverRoot;
movieSuffix = 'blue';
nSV = 2000;

U = readUfromNPY(fullfile(expRoot, movieSuffix, ['svdSpatialComponents.npy']), nSV);
mimg = readNPY(fullfile(expRoot, movieSuffix, ['meanImage.npy']));

fprintf(1, 'corrected file not found; loading uncorrected temporal components\n');
V = readVfromNPY(fullfile(expRoot, movieSuffix, ['svdTemporalComponents.npy']), nSV);
t = readNPY(fullfile(expRoot, movieSuffix, ['svdTemporalComponents.timestamps.npy']));

nPixels = size(pixel, 1);
nFrames = size(V, 2);
F = zeros(nPixels, nFrames);

for j = 1:nPixels
    mimg_kernel = mimg(pixel(j,2)-k:pixel(j,2)+k, pixel(j,1)-k:pixel(j,1)+k);
    mI = mean(mimg_kernel, 'all');

    imkernel = U(pixel(j,2)-k:pixel(j,2)+k, pixel(j,1)-k:pixel(j,1)+k, :);
    imstack = squeeze(mean(imkernel, [1,2]))';
    Fsvd = imstack * V;

    F(j, :) = Fsvd + mI;
end

data.F = F;
data.pixel = pixel;
data.t = t;

save(pathData, '-struct', 'data');
end
