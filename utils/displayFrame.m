function displayFrame(mn, td, en, d, frame, svdData)
% displayFrame  Show a single brain frame with pixel locations overlaid.
%
%   displayFrame(mn, td, en, d, frame)
%       Reads frame 5003 from the raw binary files on disk.
%
%   displayFrame(mn, td, en, d, frame, svdData)
%       Reconstructs the frame from SVD components instead.
%       svdData must have fields: U  (ny x nx x nSV)
%                                 V  (nSV   x time)
%                                 mimg (ny x nx)
%       Optional field:           frameIdx (default 5003)

    frameIdx = 5003;

    if nargin >= 6 && ~isempty(svdData)
        % --- SVD reconstruction ---
        U    = svdData.U;
        V    = svdData.V;
        mimg = svdData.mimg;
        if isfield(svdData, 'frameIdx')
            frameIdx = svdData.frameIdx;
        end
        % U is (ny x nx x nSV); broadcast V coefficients across spatial dims
        V_col = reshape(V(:, frameIdx), 1, 1, []);
        A = mimg + sum(U .* V_col, 3);
    else
        % --- Direct binary frame read ---
        source_dir = 'C:\Users\aditya\Documents\projects\data\';
        source_dir = append(source_dir, mn, '\', td, '\', num2str(en));
        pathim = append(source_dir, '\frame-', num2str(frameIdx - 1));
        fileID = fopen(pathim, 'r');
        A = fread(fileID, [560, 560], 'uint16')';
        fclose(fileID);
    end

    close all;
    figure();
    imagesc(A); hold on;
    % plot(frame(:, 1), frame(:, 2)', 'ok', 'LineWidth', 2);
    colormap(gray);
    clim([0 2000]);
    colorbar;
    impixelinfo;
end

