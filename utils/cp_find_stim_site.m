function site = cp_find_stim_site(U, V, mimg, onsetFrames, varargin)
%CP_FIND_STIM_SITE  Data-derived photostim site = deepest focal inhibition pixel.
%
%   site = CP_FIND_STIM_SITE(U, V, mimg, onsetFrames) localises the laser spot
%   purely from the data, independent of params.pixel (which the load/save
%   schemes flip x<->y). It mirrors pixelTuningCurveViewerSVD: trial-average the
%   peri-stim widefield response in SVD space, reconstruct the full frame, and
%   take the most-inhibited pixel. Everything is in the NATIVE frame
%   (imagesc(mimg), pixel = [row col]) -- the same orientation as
%   pixelTuningCurveViewerSVD and loadUVt (no transpose).
%
%   INPUTS
%     U           [Ny x Nx x nSV]  spatial SVD components (native, from loadUVt)
%     V           [nSV x nFrames]  temporal SVD components
%     mimg        [Ny x Nx]        mean fluorescence image (native)
%     onsetFrames [nTrial x 1]     stim-onset frame indices into V (strongest
%                                  amplitude(s) give the cleanest blob)
%
%   OPTIONS (name/value)
%     'fs'        sampling rate (Hz)            default 35
%     'baseWin'   pre-onset baseline window (s) default 0.5   (-500..0 ms)
%     'peakWin'   post-onset response window (s)default 0.2   (0..200 ms, the
%                                               locked inhibition-energy window)
%     'smoothSig' Gaussian smoothing sigma (px) default 3
%     'brainThr'  brain mask = mimg > thr*max   default 0.10
%     'normalize' divide by local mimg -> %dF/F default true  (matches getpixel)
%     'vesselThr' extra fluor floor for the ARGMIN only (drops dim vessels that
%                 blow up the ratio); mask = mimg > vesselThr*max  default 0.18
%
%   OUTPUT (struct)
%     site.rowcol    [row col] native, the most-inhibited (laser) pixel
%     site.centroid  [row col] intensity-weighted centroid of the deepest 0.5%
%     site.depth     %dF/F (or raw) at site.rowcol
%     site.map       the displayed inhibition map (NaN outside brain)
%     site.M         raw reconstructed response frame (peak-base), full
%     site.brain     brain mask
%     site.opts      the resolved options
%
%   The interactive cross-check (cp_kernel_explorer / pixelTuningCurveViewerSVD):
%   clicking site.rowcol should give a focal homotopic contra hot-spot; its
%   transpose gives a diffuse map -> confirms the orientation.

p = inputParser;
p.addParameter('fs', 35);
p.addParameter('baseWin', 0.5);
p.addParameter('peakWin', 0.2);
p.addParameter('smoothSig', 3);
p.addParameter('brainThr', 0.10);
p.addParameter('normalize', true);
p.addParameter('vesselThr', 0.18);
p.parse(varargin{:});
o = p.Results;

[Ny, Nx, ~] = size(U);
nF = size(V, 2);

iBase = (-round(o.baseWin*o.fs)):(-1);
iPeak = 1:round(o.peakWin*o.fs);

b = onsetFrames(:);
b = b(b + min(iBase) >= 1 & b + max(iPeak) <= nF);
if isempty(b)
    error('cp_find_stim_site: no onset frames survive the window bounds.');
end

Vb = mean(V(:, reshape(b + iBase, [], 1)), 2);   % baseline mean (SVD space)
Vp = mean(V(:, reshape(b + iPeak, [], 1)), 2);   % response mean
M  = svdFrameReconstruct(U, Vp - Vb);            % [Ny x Nx] raw response

brain = mimg > o.brainThr * max(mimg(:));
if o.normalize
    map = M ./ mimg * 100;                       % %dF/F (matches getpixel_dFoF)
else
    map = M;
end
map(~brain) = NaN;

% --- argmin on a smoothed, vessel-floored copy (robust to single hot pixels) ---
amask = brain & (mimg > o.vesselThr * max(mimg(:)));
Ms = imgaussfilt(map, o.smoothSig);
Ms(~amask) = NaN;
[depth, im] = min(Ms(:));
[r, c] = ind2sub([Ny, Nx], im);

% --- intensity-weighted centroid of the deepest 0.5% (sanity / robustness) -----
th  = prctile(map(amask), 0.5);
sel = amask & (map <= th);
[rr, cc] = find(sel);
w = -(map(sel));                                 % deeper = larger weight
centroid = [sum(rr.*w)/sum(w), sum(cc.*w)/sum(w)];

site = struct();
site.rowcol   = [r, c];
site.centroid = centroid;
site.depth    = depth;
site.map      = map;
site.M        = M;
site.brain    = brain;
site.opts     = o;
end
