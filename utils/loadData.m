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

try
sigName = 'lightCommand';
[tt, v] = getTLanalog(mn, td, en, sigName);
    
catch 
sigName = 'lightCommand594';
[tt, v] = getTLanalog(mn, td, en, sigName);    
end

d.inpTime = tt;
d.inpVals  = v;

try
d.lightRaw = readNPY(append(serverRoot,'/lightCommand.raw.npy'));
d.lightTime = readNPY(append(serverRoot,'/lightCommand.timestamps_Timeline.npy'));
catch
d.lightRaw = readNPY(append(serverRoot,'/lightCommand638.raw.npy'));
d.lightTime = readNPY(append(serverRoot,'/lightCommand638.timestamps_Timeline.npy'));
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

