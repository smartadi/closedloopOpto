function data = getpixels_dFoF(d, serverRoot)
% GETPIXELS_DFOF  Multi-pixel dF/F via rolling-mean baseline normalization.
% Results cached to data/<mouse>pixels<MMDD><en>.mat.

if nargin < 2 || isempty(serverRoot)
    serverRoot = expPath(d.mn, d.td, d.en);
end

if ~exist('data', 'dir'); mkdir('data'); end
pathData = fullfile('data', append(d.mn, 'pixels', d.td(6:7), d.td(9:10), int2str(d.en), '.mat'));

if exist(pathData, 'file')
    data = load(pathData);
    return;
end

k      = d.params.kernel;
w      = d.params.horizon - 1;
pixel  = d.params.pixels;
nPixels = size(pixel, 1);

expRoot     = serverRoot;
movieSuffix = 'blue';
nSV = 2000;

U    = readUfromNPY(fullfile(expRoot, movieSuffix, 'svdSpatialComponents.npy'), nSV);
mimg = readNPY(fullfile(expRoot, movieSuffix, 'meanImage.npy'));
fprintf(1, 'corrected file not found; loading uncorrected temporal components\n');
V = readVfromNPY(fullfile(expRoot, movieSuffix, 'svdTemporalComponents.npy'), nSV);

nFrames = size(V, 2);
F   = zeros(nPixels, nFrames);
dFk = zeros(nPixels, nFrames);

for j = 1:nPixels
    % Mean image value for this patch (scalar baseline)
    mI = mean(mimg(pixel(j,2)-k:pixel(j,2)+k, pixel(j,1)-k:pixel(j,1)+k), 'all');

    % Vectorised SVD projection: extract spatial weights once, multiply all frames
    imkernel = U(pixel(j,2)-k:pixel(j,2)+k, pixel(j,1)-k:pixel(j,1)+k, :);
    imstack  = reshape(mean(imkernel, [1,2]), [1, nSV]);  % 1 x nSV
    Fsvd     = imstack * V;                               % 1 x nFrames

    F(j,:) = Fsvd + mI;

    % Rolling-mean dF/F via cumulative sum (O(nFrames) instead of O(nFrames·w))
    Frow = F(j,:);
    Fk   = [ones(1, w) * mI, Frow];   % prepend w samples at mean level
    T    = nFrames;
    cs   = [0, cumsum(Fk)];
    idx  = 1:T;
    Fkmean    = (cs(idx + w + 1) - cs(idx)) / (w + 1);
    dFk(j,:)  = (Frow - Fkmean) ./ Fkmean * 100;
end

data.dFk   = dFk;
data.F     = F;

save(pathData, '-struct', 'data');
end
