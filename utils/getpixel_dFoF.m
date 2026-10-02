function [data, dFk] = getpixel_dFoF(d, mode, pixel, r)
% GETPIXEL_DFOF  Single-pixel dF/F from raw frames or SVD reconstruction.
% Results are cached to data/<mouse>pixel<MMDD><en>_<x>_<y>.mat.
%
%   mode : 0 = raw frame images,  rolling-baseline dF/F
%          1 = SVD reconstruction, dF/F = F/meanImage*100  (NO rolling baseline)
%          2 = SVD reconstruction, rolling-baseline dF/F   (matches mode 0)
%   r    : 0 = force recompute, 1 = use cache if available (default)
%
% WHICH MODE PRODUCES WHICH QUANTITY (2026-10-01). Modes 0 and 1 are NOT the
% same measurement and must not be pooled without thought:
%
%   mode 0/2 : (F - trailing 40 s mean) / trailing mean * 100
%              drift-free by construction; baseline is local in time.
%   mode 1   : F / meanImage * 100
%              baseline is the whole-session mean image, so slow drift REMAINS.
%
% This mattered: load_sessions.m used mode 0 for the thirteen original
% controller sessions and mode 1 for the two new ones (m14 AL_0048, m15
% AL_0051), so one figure mixed two definitions. Measured 60 s drift was
% 0.27-1.11 %dF/F for the thirteen but 2.02 and 3.18 for the two. Mode 2
% exists to put SVD-derived sessions on the mode-0 definition: it adds the
% mean image value back (SVD temporal components reconstruct the MEAN-
% SUBTRACTED movie, so F is dF, not F) and then applies the same rolling
% baseline. Mode 1 is left exactly as it was, because the bilateral/Fig-5
% analyses are built on it and must not shift underneath.
%
% See also: dff_rolling (the shared baseline estimator).

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
    % A cache must not serve a dF/F trace computed by a DIFFERENT method than
    % the caller asked for. This hole is not hypothetical: m2's cached dFk was
    % found (2026-10-01) to have been produced by a different code version
    % from its twelve mode-0 peers -- it alone lacks the corrupted lead-in --
    % and nothing recorded or detected that. Caches now carry their method.
    if isfield(data, 'dFk')
        if isfield(data, 'dff_mode') && ~isequal(data.dff_mode, mode)
            fprintf(2, ['getpixel_dFoF: cache %s holds mode %d but mode %d was ' ...
                        'requested; recomputing dF/F from cached F.\n'], ...
                        pathData, data.dff_mode, mode);
            data = rmfield(data, 'dFk');
        else
            if ~isfield(data, 'dff_mode')
                fprintf(2, ['getpixel_dFoF: cache %s predates method tagging; ' ...
                            'assuming it is mode %d. Rebuild with r=0 to be sure.\n'], ...
                            pathData, mode);
            end
            dFk = data.dFk;
            return;
        end
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

% Baseline length, shared by modes 0 and 2.
try
    w = double(d.params.horizon);
catch
    w = 40*35;   % silent fallback -- see findStims notes
end

if mode == 0
    % Raw frames give ABSOLUTE fluorescence, so the rolling baseline applies
    % directly. Previously inlined here with a `[ones(1,w), F]` pad, i.e.
    % padding with the literal 1.0 against fluorescence in the thousands,
    % which drove dF/F to ~74,000 % over the first w samples. dff_rolling
    % pads with F(1) instead. INSIDE the analysis region (sample > w) the two
    % are the same estimator, so no published number moves.
    dFk = dff_rolling(F, w);
elseif mode == 2
    % SVD reconstruction + rolling baseline. V reconstructs the MEAN-
    % SUBTRACTED movie, so F here is dF and the mean image value must be
    % added back before a ratio baseline means anything.
    if ~exist('mI', 'var')
        mimg = readNPY(fullfile(serverRoot, 'blue', 'meanImage.npy'));
        try, k = double(d.params.kernel); catch, k = 10; end
        mI = mean(mimg(pixel(1,2)-k:pixel(1,2)+k, pixel(1,1)-k:pixel(1,1)+k), 'all');
    end
    dFk = dff_rolling(double(F) + double(mI), w);
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

data.dFk      = dFk;
data.dff_mode = mode;          % which method produced dFk (see header)
data.dff_w    = w;             % baseline length in samples (modes 0 and 2)
save(pathData, '-struct', 'data');
end
