function d = initialize_data(mn,en,td)
    
    
    
    
    githubDir = "/home/nimbus/Documents/Brain/";
    
    
    % Script to analyze widefield/behavioral data from 
    addpath(genpath(fullfile(githubDir, 'widefield'))) % cortex-lab/widefield
    addpath(genpath(fullfile(githubDir, 'Pipelines'))) % SteinmetzLab/Pipelines
    addpath(genpath(fullfile(githubDir, 'npy-matlab'))) % kwikteam/npy-matlab
    
    
    serverRoot = expPath(mn, td, en);
    
    d = loadData(serverRoot,mn,td,en);
    
    %% Stim Times
    
    % mode = 0 % from stim search
    mode = 1; % from param data
    
    d = findStims(d,mode);
   
    
    %% motion

    % The server is READ-ONLY for us (user, 2026-10-11). Read motEngF/motEngProc from the
    % session folder when they exist; anything we compute goes to a LOCAL cache
    % (brain_paper/data/motion_cache/), never back into the server session folder.
    facefile  = fullfile(serverRoot, 'motEngF.npy');
    videofile = fullfile(serverRoot, 'face.mp4');
    mcDir     = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'data', 'motion_cache');
    mcTag     = sprintf('%s_%s_%s', char(mn), char(td), num2str(en));
    faceLocal = fullfile(mcDir, [mcTag '_motEngF.npy']);
    procLocal = fullfile(mcDir, [mcTag '_motEngProc.npy']);

    if isfile(facefile) || isfile(faceLocal) || isfile(videofile)
        if isfile(facefile)
            motEng = readNPY(facefile);
        elseif isfile(faceLocal)
            motEng = readNPY(faceLocal);
        else
            vr = VideoReader(videofile);
            nf = vr.NumFrames;
            motEng = zeros(1, nf-1);
            lastFrame = double(vr.readFrame()); lastFrame = lastFrame(:,:,1);
            for q = 1:nf-1
                thisFrame = double(vr.readFrame());
                thisFrame = thisFrame(:,:,1);
                motEng(q) = sum(sum((thisFrame - lastFrame).^2));
                lastFrame = thisFrame;
            end
            if ~exist(mcDir, 'dir'), mkdir(mcDir); end
            writeNPY(motEng, faceLocal);
        end

        % Downsample to match d.timeBlue (imaging runs at 2x camera, blue = every other frame)
        procfile = fullfile(serverRoot, 'motEngProc.npy');
        if isfile(procfile)
            motEngDS = readNPY(procfile);
        elseif isfile(procLocal)
            motEngDS = readNPY(procLocal);
        else
            motEngDS = downsample(double(motEng(:)), 2);
            motEngDS = medfilt1(motEngDS, 5);
            motEngDS = zscore(motEngDS);
            if ~exist(mcDir, 'dir'), mkdir(mcDir); end
            writeNPY(motEngDS, procLocal);
        end

        % Low-pass filter
        fs = 1 / mean(diff(d.timeBlue));
        cutoff = 10; % Hz
        [b, a] = butter(4, cutoff / (fs/2), 'low');
        d.motion     = filtfilt(b, a, motEngDS);
        d.has_motion = true;
    else
        d.motion     = zeros(size(d.timeBlue));
        d.has_motion = false;
    end

    %%

    % pixel frame
    pix = [d.params.pixel(1);d.params.pixel(1)];
    % offsetx = 40;
    % offsety = -75;

    offsetx = 20;
    offsety = -40;
    % 
    px = [200,300,150,200,300,350,100,200,300,400,100,200,300,400]+offsetx;
    py = [150,150,225,225,225,225,325,325,325,325,425,425,425,425]+offsety;
    % px=[];
    % py=[];
    
    frame = [double(d.params.pixel(1)),px;double(d.params.pixel(2)),py];
    d.params.pixels = frame';



expRoot = serverRoot;
movieSuffix = 'blue';
nSV = 2000;
if isfile(fullfile(expRoot, movieSuffix, 'svdSpatialComponents.npy')) && ...
   isfile(fullfile(expRoot, movieSuffix, 'meanImage.npy')) && ...
   isfile(fullfile(expRoot, movieSuffix, 'svdTemporalComponents.npy')) && ...
   isfile(fullfile(expRoot, movieSuffix, 'svdTemporalComponents.timestamps.npy'))
    U    = readUfromNPY(fullfile(expRoot, movieSuffix, 'svdSpatialComponents.npy'), nSV);
    mimg = readNPY(fullfile(expRoot, movieSuffix, 'meanImage.npy'));
    V    = readVfromNPY(fullfile(expRoot, movieSuffix, 'svdTemporalComponents.npy'), nSV);
    t    = readNPY(fullfile(expRoot, movieSuffix, 'svdTemporalComponents.timestamps.npy'));
    d.svd.U    = U;
    d.svd.V    = V;
    d.svd.t    = t;
    d.svd.nSV  = nSV;
    d.svd.mimg = mimg;
end

end