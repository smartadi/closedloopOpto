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

% Laser-channel selection (2026-10-01). This used to prefer 594 whenever a 594
% file existed, which is wrong for the dual-opsin mouse: AL_0048 was stimulated
% at 638 nm and its 594 channel is recorded but flat (-0.046..0.016 V, zero
% threshold crossings), so d.inpVals/d.lightRaw silently pointed at an empty
% trace and the session looked as though it had no laser record at all.
% AL_0051, same day, is the mirror case. Select by SIGNAL, not by preference:
% count threshold crossings on each channel and take the one that fired. Both
% per-wavelength fields are left untouched for anything that needs them.
n594 = laser_crossings(v594);
n638 = laser_crossings(v638);
if n638 > n594
    d.inpTime = tt638;  d.inpVals = v638;  tt = tt638;  d.laser_nm = 638;
else
    d.inpTime = tt594;  d.inpVals = v594;  tt = tt594;  d.laser_nm = 594;
end
d.laser_crossings = [n594 n638];

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

% lightRaw/lightTime — follow the same signal-based choice as inpVals above,
% so the two can never disagree about which laser the session used.
if d.laser_nm == 638 && ~isempty(d.lightRaw638)
    d.lightRaw = d.lightRaw638;  d.lightTime = d.lightTime638;
elseif ~isempty(d.lightRaw594)
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


function n = laser_crossings(v)
%LASER_CROSSINGS  Count rising threshold crossings on a light-command trace.
% Returns 0 for an empty or flat channel, which is how a recorded-but-unused
% laser presents itself.
if isempty(v), n = 0; return; end
v = double(v(:));
n = sum(v(2:end) > 0.1 & v(1:end-1) <= 0.1);
end
