%% Data analysis Script
% add pixel configuration


clc;
close all;
clear all;

%% experiment name

% mn = 'AL_0041'; td = '2026-02-28'; 
% en = 4;

% % feedforward 60 trials
% mn = 'AL_0041'; td = '2026-04-13';   
% en = 2;
% 

% % feedforward 100 trials
% mn = 'AL_0041'; td = '2026-04-13';   
% en = 4;


% % Good Trial 
% mn = 'AL_0041'; td = '2026-04-13';   
% en = 5;


% Good Trial 
mn = 'AL_0041'; td = '2026-04-13';   
en = 6;

% ? Trial 
% mn = 'AL_0041'; td = '2026-04-13';   
% en = 7;

% mn = 'AL_0041'; td = '2026-04-13';   
% en = 2;

% mn = 'AL_0041'; td = '2026-02-07'; 
% en = 2;

% mn = 'AL_0041'; td = '2026-02-09'; 
% en = 3;

% mn = 'AL_0041'; td = '2026-02-10'; 
% en = 2;

% mn = 'AL_0041'; td = '2026-02-10'; 
% en = 2;

% mn = 'AL_0041'; td = '2026-02-21'; 
% en = 3;

% mn = 'AL_0041'; td = '2026-02-21'; 
% en = 4;
%% get data
pathString = genpath('utils');
    addpath(pathString);
    % %%
    % addpath('utils')
d = initialize_data(mn,en,td);


%%

if isfield(d, 'input_params') && size(d.input_params, 2) >= 16
    d.unique_xy = unique(d.input_params(:, [15 16]), 'rows');
    disp('Unique [x y] coordinates from d.input_params columns 13 and 14:');
    disp(d.unique_xy);
else
    warning('d.input_params is missing or does not include columns 13 and 14.');
    d.unique_xy = [];
end



%% Run Movie



try 
    sigName = 'lightCommand594';
    [tt, v] = getTLanalog(mn, td, en, sigName);
    serverRoot = expPath(mn, td, en);
catch
    sigName = 'lightCommand';
    [tt, v] = getTLanalog(mn, td, en, sigName);
    serverRoot = expPath(mn, td, en);
end
tInd = 1;
traces(tInd).t = tt;
traces(tInd).v = v;
traces(tInd).name = sigName;
traces(tInd).lims = [0 5];

% tInd = 2;
% traces(tInd).t = tt;
% traces(tInd).v = vel;
% traces(tInd).name = 'wheelVelocity';
% traces(tInd).lims = [-3000 3000];
nSV = 500;

[U, V, t, mimg] = loadUVt(serverRoot, nSV);
%%

% movieWithTracesSVD(U, V, t, traces, [], []);

%% display image
% if image has been extracted on the local PC
% displayFrame(mn, td, en, d, d.params.pixels);

%% Load or save from image data

mode = 0  % from binary image
% mode = 1 ; % from SVD
%
% r = 0; % dont read file
r = 1; % read file

svdImage = mimg;

initBregma = [];


[clickData, mmData, clickPixelCoords, bregmaOffset] = openSVDImageClick(svdImage, initBregma, 0.0173);
d.params.selected_pixels = clickPixelCoords;

if ~isempty(bregmaOffset)
    d.params.pix_inv = bregmaOffset;
    fprintf('Saved bregma offset from first click -> x=%d, y=%d\n', d.params.pix_inv(1), d.params.pix_inv(2));
end

if mmData.isValid
    d.params.pixel = [mmData.col, mmData.row];
    d.params.pixel_value = mmData.value;
    fprintf('MM-selected pixel -> x=%d, y=%d, value=%g\n', d.params.pixel(1), d.params.pixel(2), d.params.pixel_value);
elseif ~isempty(clickData)
    d.params.pixel = [clickData(1,2), clickData(1,1)];
    d.params.pixel_value = clickData(1,3);
    fprintf('Selected pixel -> x=%d, y=%d, value=%g\n', d.params.pixel(1), d.params.pixel(2), d.params.pixel_value);
elseif isfield(d.params, 'pixel') && numel(d.params.pixel) == 2
    d.params.pixel_value = svdImage(d.params.pixel(2), d.params.pixel(1));
    fprintf('Using existing d.params.pixel -> x=%d, y=%d, value=%g\n', d.params.pixel(1), d.params.pixel(2), d.params.pixel_value);
end



%%
% Convert unique [x_mm y_mm] to pixel [x_pix y_pix] before saving
if ~isempty(d.unique_xy) && isfield(d.params, 'pix_inv') && numel(d.params.pix_inv) == 2
    d.params.pixels = convertXYmmToPixels(d.unique_xy, d.params.pix_inv, 0.0173);
else
    d.params.pixels = d.unique_xy;
    warning('Could not convert unique_xy to pixels; using d.unique_xy directly.');
end


%%




figure()
imagesc(mimg);hold on;
plot(d.params.pixels(1,1),d.params.pixels(1,2),'ok','LineWidth',5)
%%

[data,dFk_temp] = getpixel_dFoF(d,mode,d.params.pixels,r);
dFk = data.dFk;

%% Trial Samples
% d.mv = d.motion.motion_1;
% d.mv = d.motion.motion_1(1:2:end,1);
 d.stimStarts = d.stimStarts - 2;
%%
dur = d.params.dur;
t = d.timeBlue;
close all
j=50;
[a i] = min(abs(t - d.stimStarts(j)));
[a i2] = min(abs(t - d.stimEnds(j)));


tt = d.inpTime;
v = d.inpVals;

[a k] = min(abs(tt - d.stimStarts(j)));
[a k2] = min(abs(tt - d.stimEnds(j)));



% Tin = 0:0.0005:stimDur(j);
Tout = -3:0.0285:dur+3;
close all
figure()
subplot(3,1,1)
plot(Tout,dFk((i-(3*35)):(i+35*(dur+3))));hold on
plot(Tout,-5*ones(1,length(Tout)))
xlim([-3,6])
xline(0)
xline(3)
ylabel('dF/F trace')

subplot(3,1,2)
% plot(tt(k:k2)-tt(k),v(k:k2));
plot(tt(k:k2)-tt(k),v(k:k2))
xlim([-3,6])
xline(0)
xline(3)
ylabel('Input Values');


% subplot(3,1,3)
% plot(Tout,d.mv((i-(3*35)):(i+35*(dur+3))));hold on
% plot(Tout,5*ones(1,length(Tout)))
% xlim([-3,6])
% xline(0)
% xline(3)
% ylabel('motion')
% xlabel('Time (s)');
% sgtitle('trial sample')

%%

try
    d.ref_var = dlmread(append(serverRoot,"/reference.csv"),' ');
catch
end



%% Feedforward vs Feedback

% d.stimStarts = d.stimStarts + 2;
%%


trials = 60;

% d.ref=-2;

% data = controllerData(data,d,trials);

d.dur = 2
data = controllerData_var(data,d,trials);

%%
close all;
% analysisPlots_var(data,d,0);


analysisPlots_var_paper(data,d,0)
%%

nc = data.nc;
wc = data.wc;

pixelTuningCurveViewerSVD(U, V, t, d.stimStarts(wc), ones(size(d.stimStarts(wc))), [-2 3])
%%
pixelTuningCurveViewerSVD(U, V, t, d.stimStarts(nc), ones(size(d.stimStarts(nc))), [-2 3])



%%

