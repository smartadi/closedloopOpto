function d = initialize_data(mn,en,td)
    
    
    
    
    githubDir = "/home/nimbus/Documents/Brain/"
    
    
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
    d.motion = load(append(serverRoot,'/face_proc.mat'));


    % pixel frame
    pix = [d.params.pixel(1);d.params.pixel(1)]
    % offsetx = 40;
    % offsety = -75;

    offsetx = 20;
    offsety = -40;
    % 
    px = [200,300,150,200,300,350,100,200,300,400,100,200,300,400]+offsetx;
    py = [150,150,225,225,225,225,325,325,325,325,425,425,425,425]+offsety;
    % px=[];
    % py=[];
    
    frame = double([d.params.pixel(1),px;d.params.pixel(2),py]);
    d.params.pixels = frame';



expRoot = serverRoot;
movieSuffix = 'blue';
nSV = 2000;
U = readUfromNPY(fullfile(expRoot, movieSuffix, ['svdSpatialComponents.npy']), nSV);
mimg = readNPY(fullfile(expRoot, movieSuffix, ['meanImage.npy']));

%
    fprintf(1, 'corrected file not found; loading uncorrected temporal components\n');
    V = readVfromNPY(fullfile(expRoot, movieSuffix, ['svdTemporalComponents.npy']), nSV);
    t = readNPY(fullfile(expRoot, movieSuffix, ['svdTemporalComponents.timestamps.npy']));



d.svd.U = U;
d.svd.V = V;
d.svd.t = t;
d.svd.nSV = nSV;
d.svd.mimg = mimg;

end