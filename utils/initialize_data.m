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

    facefile  = fullfile(serverRoot, 'motEngF.npy');
    videofile = fullfile(serverRoot, 'face.mp4');

    if isfile(facefile) || isfile(videofile)
        if isfile(facefile)
            motEng = readNPY(facefile);
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
            writeNPY(motEng, facefile);
        end

        % Downsample to match d.timeBlue (imaging runs at 2x camera, blue = every other frame)
        procfile = fullfile(serverRoot, 'motEngProc.npy');
        if isfile(procfile)
            motEngDS = readNPY(procfile);
        else
            motEngDS = downsample(double(motEng(:)), 2);
            motEngDS = medfilt1(motEngDS, 5);
            motEngDS = zscore(motEngDS);
            writeNPY(motEngDS, procfile);
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