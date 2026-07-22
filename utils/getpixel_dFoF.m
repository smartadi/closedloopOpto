function [data, dFk] = getpixel_dFoF(d, mode, pixel, r)
% GETPIXEL_DFOF  Single-pixel dF/F via SVD reconstruction (mode=1) or raw
% frames (mode=0).  Results are cached to data/<mouse>pixel<MMDD><en>.mat.
%
%   mode : 0 = raw frame images, 1 = SVD reconstruction (default)
%   r    : 0 = force recompute, 1 = use cache if available (default)

if nargin < 2 || isempty(mode); mode = 1; end
if nargin < 4 || isempty(r);    r    = 1; end
pixel = double(pixel);

serverRoot = expPath(d.mn, d.td, d.en);

if ~exist('data', 'dir'); mkdir('data'); end
% Cache key MUST include the pixel: a session can request more than one pixel
% (e.g. bilateral left+right in one load). Keying only on session caused the
% second pixel to load the first pixel's cached trace (2026-07-22 bug: s3 right
% side served the left-hemisphere trace). Old session-only caches are orphaned
% and harmless; they simply recompute once under the new per-pixel name.
pathData = fullfile('data', append(d.mn, 'pixel', d.td(6:7), d.td(9:10), int2str(d.en), ...
    '_', int2str(round(pixel(1,1))), '_', int2str(round(pixel(1,2))), '.mat'));
dFk = [];

if exist(pathData, 'file') && r == 1
    data = load(pathData);
    if isfield(data, 'dFk')
        dFk = data.dFk;
        return;
    end
    F = data.F;
else
    % ---- Compute raw fluorescence trace F ----
    try
        k = double(d.params.kernel);
    catch
        k = 10;
    end
    disp('computing pixel val')
    j = 1;  % single pixel

    if mode == 0
        source_dir = fullfile('C:\Users\aditya\Documents\projects\data', d.mn, d.td, num2str(d.en));
        frames = dir(fullfile(source_dir, '*'));
        nFrames = numel(frames) - 2;
        F = zeros(1, ceil(nFrames / 2));
        fi = 0;
        for i = 1:2:nFrames
            fi = fi + 1;
            pathim = fullfile(source_dir, sprintf('frame-%d', i-1));
            fileID = fopen(pathim, 'r');
            A = fread(fileID, [560, 560], 'uint16')';
            fclose(fileID);
            F(fi) = mean(A(pixel(j,2)-k:pixel(j,2)+k, pixel(j,1)-k:pixel(j,1)+k), 'all');
        end
    else
        expRoot    = serverRoot;
        movieSuffix = 'blue';
        nSV = 2000;
        U    = readUfromNPY(fullfile(expRoot, movieSuffix, 'svdSpatialComponents.npy'), nSV);
        mimg = readNPY(fullfile(expRoot, movieSuffix, 'meanImage.npy'));
        fprintf(1, 'corrected file not found; loading uncorrected temporal components\n');
        V = readVfromNPY(fullfile(expRoot, movieSuffix, 'svdTemporalComponents.npy'), nSV);

        % Vectorised: extract spatial weights once, then project all frames
        imkernel = U(pixel(j,2)-k:pixel(j,2)+k, pixel(j,1)-k:pixel(j,1)+k, :);
        imstack  = reshape(mean(imkernel, [1,2]), [1, nSV]);  % 1 x nSV
        F = imstack * V;                                       % 1 x T

        % Mean image value for normalisation (constant per pixel)
        mI = mean(mimg(pixel(j,2)-k:pixel(j,2)+k, pixel(j,1)-k:pixel(j,1)+k), 'all');
    end
    data.F = F;
    save(pathData, '-struct', 'data');
end

% ---- Compute dF/F ----
disp('computing dF/F')

if mode == 0
    % Rolling-mean baseline via cumulative sum (O(T) instead of O(T·W))
    try
        w = double(d.params.horizon) - 1;
    catch
        w = 40*35 - 1;
    end
    Fk = [ones(1, w), F];
    T  = numel(F);
    cs = [0, cumsum(Fk)];
    i  = 1:T;
    Fkmean = (cs(i + w + 1) - cs(i)) / (w + 1);
    dFk    = (F - Fkmean) ./ Fkmean * 100;
else
    % SVD mode: normalise by mean image value (already computed above)
    if ~exist('mI', 'var')
        % Loaded from cache — recompute mI from mimg if needed
        expRoot = serverRoot;
        mimg = readNPY(fullfile(expRoot, 'blue', 'meanImage.npy'));
        try; k = double(d.params.kernel); catch; k = 10; end
        j = 1;
        mI = mean(mimg(pixel(j,2)-k:pixel(j,2)+k, pixel(j,1)-k:pixel(j,1)+k), 'all');
    end
    dFk = F / mI * 100;
end

data.dFk = dFk;
save(pathData, '-struct', 'data');
end
