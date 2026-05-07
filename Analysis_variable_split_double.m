%% Data analysis Script
% add pixel configuration


clc;
close all;
clear all;

%% experiment name

mn = 'AL_0041'; td = '2026-03-06'; 
en = 2;


% mn = 'AL_0041'; td = '2026-03-10'; 
% en = 4;

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

if isfield(d, 'input_params') && size(d.input_params, 2) >= 13
    d.unique_xy = unique(d.input_params(:, [13 14]), 'rows');
    disp('Unique [x y] coordinates from d.input_params columns 13 and 14:');
    disp(d.unique_xy);

    % Group input_params indices by pixel and condition (nc: col3==0, wc: col3==1)
    % Split each condition by trajectory/step mode using col9 (0=step, 1=traj).
    d.pixel_groups = struct('xy', {}, 'nc_step', {}, 'nc_traj', {}, 'wc_step', {}, 'wc_traj', {});
    for i = 1:size(d.unique_xy, 1)
        xy = d.unique_xy(i, :);
        pix_mask = d.input_params(:, 13) == xy(1) & d.input_params(:, 14) == xy(2);
        nc_step_idx = find(pix_mask & d.input_params(:, 3) == 0 & d.input_params(:, 9) == 0);
        nc_traj_idx = find(pix_mask & d.input_params(:, 3) == 0 & d.input_params(:, 9) == 1);
        wc_step_idx = find(pix_mask & d.input_params(:, 3) == 1 & d.input_params(:, 9) == 0);
        wc_traj_idx = find(pix_mask & d.input_params(:, 3) == 1 & d.input_params(:, 9) == 1);
        d.pixel_groups(i).xy = xy;
        d.pixel_groups(i).nc_step = nc_step_idx;
        d.pixel_groups(i).nc_traj = nc_traj_idx;
        d.pixel_groups(i).wc_step = wc_step_idx;
        d.pixel_groups(i).wc_traj = wc_traj_idx;
    end

    d.stim_groups_by_pixel = splitStimStartsByPixelAndMode(d.stimStarts, d.input_params, [13 14], 9, 1);
    d.stim_groups_by_pixel_step = arrayfun(@(s) s.stimStarts_step, d.stim_groups_by_pixel, 'UniformOutput', false);
    d.stim_groups_by_pixel_traj = arrayfun(@(s) s.stimStarts_traj, d.stim_groups_by_pixel, 'UniformOutput', false);
else
    warning('d.input_params is missing or does not include columns 13 and 14.');
    d.unique_xy = [];
    d.pixel_groups = struct('xy', {}, 'nc_step', {}, 'nc_traj', {}, 'wc_step', {}, 'wc_traj', {});
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

%mode = 0  % from binary image
mode = 1 ; % from SVD
%
% r = 0; % dont read file
r = 1; % read file

svdImage = mimg;
[clickData, mmData, clickPixelCoords, bregmaOffset] = openSVDImageClick(svdImage, 0.0173);
d.params.selected_pixels = clickPixelCoords;
if ~isempty(bregmaOffset)
    d.params.pix_inv = bregmaOffset;
    fprintf('Saved bregma offset from first click -> x=%d, y=%d\n', d.params.pix_inv(1), d.params.pix_inv(2));
end
if mmData.isValid
    d.params.pixel = [mmData.col, mmData.row];
    fprintf('MM-selected pixel -> x=%d, y=%d, value=%g\n', mmData.col, mmData.row, mmData.value);
elseif ~isempty(clickData)
    d.params.pixel = [clickData(1,2), clickData(1,1)];
    fprintf('Selected pixel -> x=%d, y=%d, value=%g\n', clickData(1,2), clickData(1,1), clickData(1,3));
end

% [pixelCoordsMM, pixelValuesMM, mmPositionsMM] = getPixelValuesFromMMPositionsImage(svdImage, d.params.pix_inv, [], 0.0173);
% d.params.mm_positions = mmPositionsMM;
% d.params.mm_pixel_coords = pixelCoordsMM;
% d.params.mm_pixel_values = pixelValuesMM;
% mmTable = table((1:size(mmPositionsMM,1))', mmPositionsMM(:,1), mmPositionsMM(:,2), ...
%     pixelCoordsMM(:,1), pixelCoordsMM(:,2), pixelValuesMM, ...
%     'VariableNames', {'idx','x_mm','y_mm','x_pix','y_pix','pixel_value'});
% disp(mmTable)





%%

% Convert unique [x_mm y_mm] to pixel [x_pix y_pix] before saving
if ~isempty(d.unique_xy) && isfield(d.params, 'pix_inv') && numel(d.params.pix_inv) == 2
    d.params.pixels = convertXYmmToPixels(d.unique_xy, d.params.pix_inv, 0.0173);
else
    d.params.pixels = d.unique_xy;
    warning('Could not convert unique_xy to pixels; using d.unique_xy directly.');
end

%%
% data_pix = getpixels_dFoF(d);
% dFkp = data_pix.dFk;

data_trace = getpixels_trace(d);
F = data_trace.F;


%%

d.iputs = d.iputs(1:length(d.timeBlue));
%%

windowSec = d.params.horizon/35;
[dFkpix, FmeanPix, windowSamples] = compute_dFoF_window(F, data_trace.t, windowSec);
data_trace.dFoverF = dFkpix;
data_trace.Fmean = FmeanPix;
data_trace.windowSec = windowSec;
data_trace.windowSamples = windowSamples;

% [data,dFk_temp] = getpixel_dFoF(d,mode,d.params.pixel,r);
%%
data.dFk = dFkpix;
%%


dFk = data.dFk;

%% Feedforward vs Feedback 
close all;
for s = 2:2
dFk = data.dFk(2,:);
    nc = d.pixel_groups(1).nc_step;
    wc = d.pixel_groups(1).wc_step;

    dur = d.params.dur
    t = d.timeBlue;
    ti = d.inpTime;

    
    tBlue_ = d.timeBlue(:)';
    ti_    = d.inpTime(:)';
    dt_b   = tBlue_(2) - tBlue_(1);
    dt_i   = ti_(2)    - ti_(1);

    W_dfk_ = 3*35 + 35*(dur+3) + 1;
    W_inp_ = dur*2000 + 1;
    W_inp2 = 1*2000 + (dur+1)*2000 + 1;

    nNc_ = numel(nc);  nWc_ = numel(wc);

    ncIdx_   = max(1, min(numel(tBlue_), round((d.stimStarts(nc)  - tBlue_(1)) / dt_b) + 1));
    wcIdx_   = max(1, min(numel(tBlue_), round((d.stimStarts(wc)  - tBlue_(1)) / dt_b) + 1));
    ncIdxIn_ = max(1, min(numel(ti_),    round((d.stimStarts(nc)  - ti_(1))    / dt_i) + 1));
    wcIdxIn_ = max(1, min(numel(ti_),    round((d.stimStarts(wc)  - ti_(1))    / dt_i) + 1));

    pncDfk  = zeros(nNc_, W_dfk_);  ncInp  = zeros(nNc_, W_inp_);  inps_nc = zeros(nNc_, W_inp2);
    pwcDfk  = zeros(nWc_, W_dfk_);  wcInp  = zeros(nWc_, W_inp_);  inps_wc = zeros(nWc_, W_inp2);
    er_ncDfk = zeros(nNc_,1);  vr_ncDfk = zeros(nNc_,1);
    er_wcDfk = zeros(nWc_,1);  vr_wcDfk = zeros(nWc_,1);

    for j = 1:nNc_
        i  = ncIdx_(j);   i2 = ncIdxIn_(j);
        pncDfk(j,:)  = dFk(i-105 : i+35*(dur+3));
        ncInp(j,:)   = d.inpVals(i2 : i2+dur*2000)';
        inps_nc(j,:) = d.inpVals(i2-1*2000 : i2+(dur+1)*2000);
        seg = dFk(i : i+35*dur);
        er_ncDfk(j) = norm(seg + 2);  vr_ncDfk(j) = var(seg);
    end

    for j = 1:nWc_
        i  = wcIdx_(j);   i2 = wcIdxIn_(j);
        pwcDfk(j,:)  = dFk(i-105 : i+35*(dur+3));
        wcInp(j,:)   = d.inpVals(i2 : i2+dur*2000)';
        inps_wc(j,:) = d.inpVals(i2-1*2000 : i2+(dur+1)*2000);
        seg = dFk(i : i+35*dur);
        er_wcDfk(j) = norm(seg + 2);  vr_wcDfk(j) = var(seg);
    end

    nc_avg = mean(pncDfk, 1);
    wc_avg = mean(pwcDfk, 1);

% end







trial=15;

j = nc(trial)
[a i] = min(abs(t - d.stimStarts(j)));
[a i2] = min(abs(t - d.stimEnds(j)));

[a k] = min(abs(tt - d.stimStarts(j)));
[a k2] = min(abs(tt - d.stimEnds(j)));




Ref=[];
j = nc(1)
    [a i] = min(abs(d.timeBlue - d.stimStarts(j)));
    % Ref = [Ref;(-5)*d.iputs(i:i+35*(d.params.dur))'];


rref = -2*ones(dur*35+1,1);


% Tin = 0:0.0005:stimDur(j);
Tout = -3:0.0285:dur+3;
Tref = 0:0.0285:dur;
figure()
ax1 = subplot(1,2,1)
hA = plot(Tout,dFk((i-(3*35)):(i+35*(dur+3))),'r','LineWidth',3);hold on
hB = plot(Tref,rref,'--k','LineWidth',2)
hC = plot(tt(k:k2)-tt(k),2*v(k:k2),'b','LineWidth',3)
% shortCornerAxes(gca, 'XLabel','Time(s)', 'YLabel','\DeltaF/F', 'Frac',0.10,'LineWidth',5);


ylim([-10 10])
xlim([-3,6])
xline(0)
xline(3)
% ylabel('dF/F','FontSize',12,'FontWeight','bold')
% xlabel('time(secs)','FontSize',12,'FontWeight','bold')
yl = ylim;   % current y-limits
x1 = 0;
x2 = 3;
patch([x1 x2 x2 x1], ...
      [yl(1) yl(1) yl(2) yl(2)], ...
      [0.9 0.9 0.9], ...
      'FaceAlpha', 0.3, ...
      'EdgeColor', 'none');
shortCornerAxes_plot(gca,'Frac',0.10,'XLabel','Time (s)','YLabel','\DeltaF/F','LineWidth',5)

% Keep data on top
uistack(findobj(gca,'Type','line'),'top')
hold off
box off
xticklabels([])
yticklabels([])



j = wc(trial)
[a i] = min(abs(t - d.stimStarts(j)));
[a i2] = min(abs(t - d.stimEnds(j)));


tt = d.inpTime;
v = d.inpVals;

[a k] = min(abs(tt - d.stimStarts(j)));
[a k2] = min(abs(tt - d.stimEnds(j)));



ax2 = subplot(1,2,2)
hD = plot(Tout,dFk((i-(3*35)):(i+35*(dur+3))),'Color',[0,0.5,0],'LineWidth',3);hold on
hB = plot(Tref,rref,'--k','LineWidth',2)
plot(tt(k:k2)-tt(k),2*v(k:k2),'b','LineWidth',3)
% shortCornerAxes(gca, 'XLabel','', 'YLabel','', 'Frac',0.0,'LineWidth',0);
ylim([-10 10])
xlim([-3,6])
xline(0)
xline(3)
yl = ylim;   % current y-limits
x1 = 0;
x2 = 3;
patch([x1 x2 x2 x1], ...
      [yl(1) yl(1) yl(2) yl(2)], ...
      [0.9 0.9 0.9], ...
      'FaceAlpha', 0.3, ...
      'EdgeColor', 'none');

uistack(findobj(gca,'Type','line'),'top')
hold off
box off
xticklabels([])
yticklabels([])
set(gca, ...
    'Box','off', ...
    'XColor','none', ...
    'YColor','none', ...
    'TickDir','out', ...
    'XTick',[], ...
    'YTick',[], ...
    'Color','none');


legend(ax2, [hA hD hC hB], {'Closed Loop', 'Open Loop','Stim', 'Ref'}, ...
    'Location','northeast', ...
    'Box','off', FontSize=12, FontWeight='bold')





T = -3:1/35:3+dur;
figure()

% Column (vertical band) to shade
x1 = 0;
x2 = (dur);

% ref = [zeros(1,35*3), d.ref*ones(1,3*35),zeros(1,35*3+1)];
Tref = 0:1/35:dur;
ax1 = subplot(1,2,1)
plot(T,pncDfk,'Color', [1 0 0 0.1],'LineWidth',0.5);hold on
% plot(T,d.ref*ones(1,length(T)),'--k','Linewidth',3);hold on
% plot(T,ref,'--k','Linewidth',3);hold
% 
plot(Tref,rref,'--k','LineWidth',2)

% plot(Tref,d.ref*ones(3*35+1),'--k','Linewidth',3);hold on
plot(T,nc_avg,'r','Linewidth',3);
xline(0)
xline(dur)
shortCornerAxes_plot(gca,'Frac',0.10,'XLabel','Time (s)','YLabel','\DeltaF/F','LineWidth',5)

% shortCornerAxes(gca, 'XLabel','Time(s)', 'YLabel','\DeltaF/F', 'Frac',0.10,'LineWidth',5);
% xlabel('time(sec)','FontSize',12,'FontWeight','bold')
% ylabel('dF/F %','FontSize',12,'FontWeight','bold')
ylim([-10 10])
xlim([-3,6])
yl = ylim;   % current y-limits

patch([x1 x2 x2 x1], ...
      [yl(1) yl(1) yl(2) yl(2)], ...
      [0.9 0.9 0.9], ...
      'FaceAlpha', 0.3, ...
      'EdgeColor', 'none');

% Keep data on top
uistack(findobj(gca,'Type','line'),'top')
hold off
% yticklabels([])

% title('Open Loop')
% ax = gca;
% ax.FontWeight = 'bold';
ax2 = subplot(1,2,2)
plot(T,pwcDfk,'Color', [0 0.5 0 0.1],'LineWidth',0.5);hold on
plot(Tref,rref,'--k','LineWidth',2)
% plot(Tref,d.ref*ones(3*35+1),'--k','Linewidth',3);hold on
plot(T,wc_avg,'Color', [0 0.5 0],'Linewidth',3);
xline(0)
xline(dur)
ylim([-10 10])
xlim([-3,6])
% xlabel('time(sec)','FontSize',12,'FontWeight','bold')

yl = ylim;   % current y-limits

patch([x1 x2 x2 x1], ...
      [yl(1) yl(1) yl(2) yl(2)], ...
      [0.9 0.9 0.9], ...
      'FaceAlpha', 0.3, ...
      'EdgeColor', 'none');

xticklabels([])
yticklabels([])
set(gca, ...
    'Box','off', ...
    'XColor','none', ...
    'YColor','none', ...
    'TickDir','out', ...
    'XTick',[], ...
    'YTick',[], ...
    'Color','none');


nc_var = var(pncDfk,1,1);
wc_var = var(pwcDfk,1,1);


display('var size')
size(nc_var)

% close all;
figure()
plot(T,nc_var,'r','LineWidth',2);hold on
plot(T,wc_var,'Color', [0 0.5 0],'LineWidth',2);
xline(0,'LineWidth',1.5)
xline(dur,'LineWidth',1.5)
ylim([-2,12])

yl = ylim;   % current y-limits

patch([x1 x2 x2 x1], ...
      [yl(1) yl(1) yl(2) yl(2)], ...
      [0.9 0.9 0.9], ...
      'FaceAlpha', 0.3, ...
      'EdgeColor', 'none');
shortCornerAxes_plot(gca,'Frac',0.10,'XLabel','Time (s)','YLabel','Variance','LineWidth',5)

% Keep data on top
uistack(findobj(gca,'Type','line'),'top')
hold off



%
figure(); hold on;

halfWidth = 0.3;
alphaFill = 0.5;


k=1
colA = [1 0 0];
colB = [0  0.5 0];


    [fA, yA] = ksdensity(er_ncDfk);
    fA = fA / max(fA) * halfWidth;

    fill([k - fA, k*ones(size(fA))], ...
         [yA,      fliplr(yA)], ...
         colA, 'FaceAlpha', alphaFill, 'EdgeColor','none');

    % Mean line A
    muA = mean(er_ncDfk);
    plot([ k - 0.1], [ muA], 'r*', 'LineWidth', 1.5);

    % -------- Distribution B (right) --------
    [fB, yB] = ksdensity(er_wcDfk);
    fB = fB / max(fB) * halfWidth;

    fill([k + fB, k*ones(size(fB))], ...
         [yB,      fliplr(yB)], ...
         colB, 'FaceAlpha', alphaFill, 'EdgeColor','none');

    % Mean line B
    muB = mean(er_wcDfk);
    plot([k+0.1], [ muB], 'g*', 'LineWidth', 1.5);

ax.FontSize = 16
xticks([])

shortCornerAxes_plot(gca,'Frac',0.10,'XLabel','MSE','YLabel','Trials','LineWidth',5)




end


%%
close all;
analysisPlots_var(data,d,0);

%%

Ref=[];
for j = 1: length(d.stimStarts)
    [a i] = min(abs(d.timeBlue - d.stimStarts((j))));
    Ref = [Ref; d.ref_var(i:i+35*(d.params.dur))'];
end



Ref = Ref(end-99:100,:);

%% get trail stamps
nc = data.nc;
wc = data.wc;
%% Invariance tests
invarianceAnalysis(data,d);
%%


features = feature_analysis(data,d);

mf = features.mf;
v1 = features.v1;
v2 = features.v2;
v3 = features.v3;

%% Classify initial condition

X0_wc = zeros(length(wc), 1); % Preallocate for efficiency
for j = 1:length(wc)
    [~, i] = min(abs(t - d.stimStarts(wc(j))));
    X0_wc(j) = dFk(i);
end

X0_nc = zeros(length(nc), 1); % Preallocate for efficiency
for j = 1:length(nc)
    [~, i] = min(abs(t - d.stimStarts(nc(j))));
    X0_nc(j) = dFk(i);
end

X0 = zeros(length(d.stimStarts), 1); % Preallocate for efficiency
for j = 1:length(d.stimStarts)
    [~, i] = min(abs(t - d.stimStarts(j)));
    X0(j) = dFk(i);
end



%% Analysis based on H2 
pixel_test(d,data,dFkp);
%%
dataPixel = pixelAnalysis(d,data,dFkp);
%%
close all;

er_wcDfk = data.er_wcDfk;
er_ncDfk = data.er_ncDfk;

pwcDfk = data.pwcDfk;
pncDfk = data.pncDfk;

er = sort(er_wcDfk);
ner = sort(er_ncDfk);

%% Analyzer
close all;
i = 10;
motionPlotter(i,d,data)

%%



%%

ncmotion_pre = sum(data.ncmotion(:,1:35*1),2);
wcmotion_pre = sum(data.wcmotion(:,1:35*1),2);


ncmotion_during = sum(data.ncmotion(:,35:(dur)*35),2);
wcmotion_during = sum(data.wcmotion(:,35:(dur)*35),2);



%% Thresholding
close all
figure()
subplot(1,2,1)
s = scatter3(X0_wc,wcmotion_pre,er_wcDfk,[],er_wcDfk,'filled','g');hold on
s = scatter3(X0_nc,ncmotion_pre,er_ncDfk,[],er_ncDfk,'filled','r');
xlabel('x_0 df/F')
ylabel('motion')
zlabel('Tracking error norm')
% xlim([-10 10])
% ylim([0 20])
% zlim([0 50])
% % colorbar
% % zlim([0,100])
% % clim([0,80])
title('regularizability dependece on motion pre trial')


threshold = 30; 

xp = get(gca,'Xlim');
yp = get(gca,'Ylim');
% Use the axes x and Y limits to find the co-ordinates for the patch
x1 = [ xp(1) xp(2) xp(2) xp(1)];
y1 = [ yp(1) yp(1) yp(2) yp(2)];
z1 = ones(1,numel(y1))* threshold; 
v = patch(x1,y1,z1, 'g');
set(v,'facealpha',0.1);
set(v,'edgealpha',0.5);
set(gcf,'renderer','opengl') ;
hold on;
% 
subplot(1,2,2)
s = scatter3(X0_wc,wcmotion_during,er_wcDfk,[],er_wcDfk,'filled','g');hold on
s = scatter3(X0_nc,ncmotion_during,er_ncDfk,[],er_ncDfk,'filled','r');
xlabel('x_0 df/F')
ylabel('motion')
zlabel('Tracking error norm')
% xlim([-10 10])
% ylim([0 20])
% zlim([0 50])
% colorbar
% zlim([0,100])
% clim([0,80])
title('regularizability dependece on motion during trial')


threshold = 30; 

xp = get(gca,'Xlim');
yp = get(gca,'Ylim');
% Use the axes x and Y limits to find the co-ordinates for the patch
x1 = [ xp(1) xp(2) xp(2) xp(1)];
y1 = [ yp(1) yp(1) yp(2) yp(2)];
z1 = ones(1,numel(y1))* threshold; 
v = patch(x1,y1,z1, 'g');
set(v,'facealpha',0.1);
set(v,'edgealpha',0.5);
set(gcf,'renderer','opengl') ;
hold on;

%%
dur = d.params.dur
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
title('analysis')

subplot(3,1,2)
% plot(tt(k:k2)-tt(k),v(k:k2));
plot(tt(k:k2)-tt(k),v(k:k2))
xlim([-3,6])
xline(0)
xline(3)

subplot(3,1,3)
plot(Tout,d.mv((i-(3*35)):(i+35*(dur+3))));hold on
plot(Tout,5*ones(1,length(Tout)))
xlim([-3,6])
xline(0)
xline(3)
title('analysis')


%%

rref = Ref(end,:);


figure()
ax =gca;
plot(rref,'LineWidth',4);
shortCornerAxes_plot(ax,'Frac',0.1,'XLabel','time(secs)','YLabel','Ref','LineWidth',5)

%% input_params table with column names
if isfield(d, 'input_params') && ~isempty(d.input_params)
    d.input_params_table = array2table(d.input_params);
    nCols = size(d.input_params, 2);
    varNames = arrayfun(@(k) sprintf('col%d', k), 1:nCols, 'UniformOutput', false);
    if nCols >= 11, varNames{11} = 'amp'; end
    if nCols >= 12, varNames{12} = 'freq'; end
    if nCols >= 13, varNames{13} = 'x'; end
    if nCols >= 14, varNames{14} = 'y'; end
    d.input_params_table.Properties.VariableNames = matlab.lang.makeUniqueStrings(varNames);
    disp('Created d.input_params_table with named columns.');
end




%%
% close all;
figure()

plot(data.ncInp','r');hold on
plot(data.wcInp','g');hold on
plot(mean(data.wcInp,1),'LineWidth',5)
ylim([0,5])
