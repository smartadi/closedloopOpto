   function d = loadData(serverRoot,mn,td,en)
%LOADDATA Summary of this function goes here
%   Detailed explanation goes here
% d.input_params = readmatrix(append(serverRoot,"/data/input_params.csv"));
% % % frames = readmatrix(append(serverRoot,"/frames.csv"));
% d.states = dlmread(append(serverRoot,"/data/states.csv"),' ');
% d.params = load(append(serverRoot,"/data/params.mat"));

d.input_params = readmatrix(append(serverRoot,"/input_params.csv"));
% frames = readmatrix(append(serverRoot,"/frames.csv"));
d.states = dlmread(append(serverRoot,"/states.csv"),' ');
d.params = load(append(serverRoot,"/params.mat"));
d.iputs = dlmread(append(serverRoot,"/input_amps.csv"),' ');
d.en = en;
d.mn = mn;
d.td = td;

%% Load Timeline Data

% Red laser (594 nm)
try
    [tt594, v594] = getTLanalog(mn, td, en, 'lightCommand594');
catch
    try
        [tt594, v594] = getTLanalog(mn, td, en, 'lightCommand');
    catch
        tt594 = []; v594 = [];
    end
end
d.inpTime594 = tt594;
d.inpVals594 = v594;

% Orange laser (638 nm)
try
    [tt638, v638] = getTLanalog(mn, td, en, 'lightCommand638');
catch
    tt638 = []; v638 = [];
end
d.inpTime638 = tt638;
d.inpVals638 = v638;

% Legacy fields — use 594 if available, else 638
if ~isempty(tt594)
    d.inpTime = tt594;  d.inpVals = v594;  tt = tt594;
else
    d.inpTime = tt638;  d.inpVals = v638;  tt = tt638;
end

try
    d.lightRaw594 = readNPY(append(serverRoot,'/lightCommand594.raw.npy'));
    d.lightTime594 = readNPY(append(serverRoot,'/lightCommand594.timestamps_Timeline.npy'));
catch
    d.lightRaw594 = []; d.lightTime594 = [];
end

try
    d.lightRaw638 = readNPY(append(serverRoot,'/lightCommand638.raw.npy'));
    d.lightTime638 = readNPY(append(serverRoot,'/lightCommand638.timestamps_Timeline.npy'));
catch
    d.lightRaw638 = []; d.lightTime638 = [];
end

% Legacy lightRaw/lightTime — prefer 594
if ~isempty(d.lightRaw594)
    d.lightRaw = d.lightRaw594;  d.lightTime = d.lightTime594;
else
    d.lightRaw = d.lightRaw638;  d.lightTime = d.lightTime638;
end
d.wfExp = readNPY(append(serverRoot,'/widefieldExposure.timestamps_Timeline.npy'));
d.wfTime = readNPY(append(serverRoot,'/widefieldExposure.raw.npy'));


wf_times = tt(d.wfTime(2:end)>1 & d.wfTime(1:end-1)<=1);
% t = wf_times(2:2:end);
d.timeBlue = wf_times(1:2:end);



%% load motion

try
    d.motion = load(append(serverRoot,'/face_proc.mat'));
    d.mv = d.motion.motSVD_0(1:2:end,1);
catch
end

end

