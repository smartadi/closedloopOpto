%% ana analysis


clc;
close all;
clear all;

%%
% mn = 'AL_0041'; td = '2026-02-17'; 
% en = 1;
% 
% 
% mn = 'AL_0041'; td = '2026-04-07'; 
% en = 4;


mn = 'AL_0041'; td = '2026-04-13'; 
en = 5;
% %%

    % sigName = 'lightCommand638';
    sigName = 'lightCommand594';
    [tt, v] = getTLanalog(mn, td, en, sigName);
    serverRoot = expPath(mn, td, en);

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




input_params = readmatrix(append(serverRoot,"/input_params.csv"));
% frames = readmatrix(append(serverRoot,"/frames.csv"));
states = dlmread(append(serverRoot,"/states.csv"),' ');
params = load(append(serverRoot,"/params.mat"));
inputs = dlmread(append(serverRoot,"/input_amps.csv"),' ');

%% find ids from input params

xy = input_params(:, end-1:end);           % last two columns: x, y

[unique_xy, ~, grp] = unique(xy, 'rows', 'stable');  % unique pairs, grp(i) = which pair row i belongs to

n_pairs = size(unique_xy, 1);
pair_idx = cell(n_pairs, 1);               % pair_idx{k} = row indices for k-th unique (x,y)
for k = 1:n_pairs
    pair_idx{k} = find(grp == k);
end

% unique_xy(k,:) is the k-th (x,y) pair
% pair_idx{k}   are its row indices in input_params

%% Run Movie





%%

expRoot = serverRoot;
movieSuffix = 'blue';
% nSV = 2000;
% U = readUfromNPY(fullfile(expRoot, movieSuffix, ['svdSpatialComponents.npy']), nSV);
% mimg = readNPY(fullfile(expRoot, movieSuffix, ['meanImage.npy']));
% 
% 
% V = readVfromNPY(fullfile(expRoot, movieSuffix, ['svdTemporalComponents.npy']), nSV);
% t = readNPY(fullfile(expRoot, movieSuffix, ['svdTemporalComponents.timestamps.npy']));


mimg = readNPY(fullfile(expRoot, movieSuffix, ['meanImage.npy']));


%%

% movieWithTracesSVD(U, V, t, traces, [], []);


%%

figure()
plot(tt,v)

%% Find stim locations from v and tt
stimTimes = tt(v(2:end) > 0.1 & v(1:end-1) <= 0.1);
ds = find(diff([0; stimTimes]) > 2);
stimStarts = stimTimes(ds);

%%



horizon = 40;
dur = params.dur;



    a1 = input_params(:,2);% - double(horizon)*ones(length(input_params),1);
    a2 = input_params(:,2)+double(dur)*35;% - double(horizon) + double(dur)*35;

nn =100;

trials = ones(nn,1);
trials = [zeros(length(input_params)-nn,1);trials];
nc = find(input_params(:,3)==0 & trials == 1);
wc = find(input_params(:,3)==1 & trials == 1);


 stimStarts = t(a1);
 stimEnds = t(a2);



% %%
% path = append(serverRoot,'\594laserOnTimes.npy')
% lstart = readNPY(path);
% 
% 
% path = append(serverRoot,'\galvoXPositions_mm.npy')
% gx = readNPY(path);
% 
% path = append(serverRoot,'\galvoYPositions_mm.npy')
% gy = readNPY(path);
% 
% pos = [gx,gy];
% [uniquePos, ~, posID] = unique(pos, 'rows', 'stable');
% %%
% i=4
% posTrials = arrayfun(@(i) find(posID == i), 1:size(uniquePos,1), 'UniformOutput', false);
% firstPosTrials = posTrials{i};
%%
% close all;
% 
% pixelTuningCurveViewerSVD(U, V(:,1:end-1), t, lstart(firstPosTrials), ones(size(lstart(firstPosTrials))), [-2 3])
% 


%%
close all;
k =  1
coordinate= unique_xy(k,:)
idx = pair_idx{k};
pixelTuningCurveViewerSVD(U, V(:,1:end-1), t, stimStarts(nc), ones(size(stimStarts(nc))), [-2 3])

%%

ii = zeros(size(stimStarts)); 
for q = 1:4
    ii(pair_idx{q}) = q;
end


pixelTuningCurveViewerSVD(U, V(:,1:end-1), t, stimStarts, ii, [-2 3])


%%
% %% display image
% % if image has been extracted on the local PC
% % displayFrame(mn, td, en, d, d.params.pixels);
% 
% %% Load or save from image data
% 
% %mode = 0  % from binary image
% mode = 1 ; % from SVD
% %
% % r = 0; % dont read file
% r = 1; % read file
% 
% svdImage = mimg;
% [clickData, mmData, clickPixelCoords, bregmaOffset] = openSVDImageClick(svdImage, 0.0173);
% d.params.selected_pixels = clickPixelCoords;
% if ~isempty(bregm=--aOffset)
%     d.params.pix_inv = bregmaOffset;
%     fprintf('Saved bregma offset from first click -> x=%d, y=%d\n', d.params.pix_inv(1), d.params.pix_inv(2));
% end
% if mmData.isValid
%     d.params.pixel = [mmData.col, mmData.row];
%     fprintf('MM-selected pixel -> x=%d, y=%d, value=%g\n', mmData.col, mmData.row, mmData.value);
% elseif ~isempty(clickData)
%     d.params.pixel = [clickData(1,2), clickData(1,1)];
%     fprintf('Selected pixel -> x=%d, y=%d, value=%g\n', clickData(1,2), clickData(1,1), clickData(1,3));
% end
% 
% % [pixelCoordsMM, pixelValuesMM, mmPositionsMM] = getPixelValuesFromMMPositionsImage(svdImage, d.params.pix_inv, [], 0.0173);
% % d.params.mm_positions = mmPositionsMM;
% % d.params.mm_pixel_coords = pixelCoordsMM;
% % d.params.mm_pixel_values = pixelValuesMM;
% % mmTable = table((1:size(mmPositionsMM,1))', mmPositionsMM(:,1), mmPositionsMM(:,2), ...
% %     pixelCoordsMM(:,1), pixelCoordsMM(:,2), pixelValuesMM, ...
% %     'VariableNames', {'idx','x_mm','y_mm','x_pix','y_pix','pixel_value'});
% % disp(mmTable)
% 
% 
% 
% 
% %%
% 
% % Convert unique [x_mm y_mm] to pixel [x_pix y_pix] before saving
% if ~isempty(d.unique_xy) && isfield(d.params, 'pix_inv') && numel(d.params.pix_inv) == 2
%     d.params.pixels = convertXYmmToPixels(d.unique_xy, d.params.pix_inv, 0.0173);
% else
%     d.params.pixels = d.unique_xy;
%     warning('Could not convert unique_xy to pixels; using d.unique_xy directly.');
% end
% %%
% d.params.pixels
% 
% d.inpTime =tt;
% d.inpVals = v;
% % data_trace = getpixels_trace(d);
% % F = data_trace.F;
% % 
% % 
% % 
% % 
% % d.iputs = d.iputs(1:length(d.timeBlue));
% % 
% % 
% % windowSec = d.params.horizon/35;
% % [dFkpix, FmeanPix, windowSamples] = compute_dFoF_window(F, data_trace.t, windowSec);
% % data_trace.dFoverF = dFkpix;
% % data_trace.Fmean = FmeanPix;
% % data_trace.windowSec = windowSec;
% % data_trace.windowSamples = windowSamples;
% %%
% 
% r=0
% [data,dFk_temp] = getpixel_dFoF(d,mode,d.params.pixels,r);
% % %%
% % data.dFk = dFkpix;
% dFk = data.dFk;
% %%
% % dFk = d.states(1:length(d.timeBlue))';
% %
% 
% 
% % 
% % %%
% % dFk = data2.dFk;
% %% Trial Samples
% % d.mv = d.motion.motion_1;
% % d.mv = d.motion.motion_1(1:2:end,1);
% 
% 
% dur = d.params.dur;
% t = d.timeBlue;
% close all
% j=20;
% 
% [a i] = min(abs(t - d.stimStarts(j)));
% [a i2] = min(abs(t - d.stimEnds(j)));
% 
% 
% % tt = d.inpTime;
% % v = d.inpVals;
% 
% [a k] = min(abs(tt - d.stimStarts(j)));
% [a k2] = min(abs(tt - d.stimEnds(j)));
% 
% 
% 
% % Tin = 0:0.0005:stimDur(j);
% Tout = -3:0.0285:dur+3;
% close all
% figure()
% subplot(3,1,1)
% plot(Tout,dFk((i-(3*35)):(i+35*(dur+3))));hold on
% plot(Tout,-2*ones(1,length(Tout)))
% xlim([-3,6])
% xline(0)
% xline(3)
% ylabel('dF/F trace')
% 
% subplot(3,1,2)
% % plot(tt(k:k2)-tt(k),v(k:k2));
% plot(tt(k:k2)-tt(k),v(k:k2))
% xlim([-3,6])
% xline(0)
% xline(3)
% ylabel('Input Values');
% 
% 
% % subplot(3,1,3)
% % plot(Tout,d.mv((i-(3*35)):(i+35*(dur+3))));hold on
% % plot(Tout,5*ones(1,length(Tout)))
% % xlim([-3,6])
% % xline(0)
% % xline(3)
% % ylabel('motion')
% % xlabel('Time (s)');
% % sgtitle('trial sample')
% 
% %% calibration
% 
% d.input_params(10:59,3) = 2;
% 
% % d.input_params(2:32,3) = 2;
% 
% 
% 
% cal = find(d.input_params(:,3)==2);
% 
% t=150
% trials = ones(t,1);
% trials = [zeros(length(d.input_params)-t,1);trials];
% 
% nc = find(d.input_params(:,3)==0 & trials == 1);
% wc = find(d.input_params(:,3)==1 & trials == 1);
% nc_opt = find(d.input_params(:,3)==0.5 & trials == 1);
% %%
% 
% pixelTuningCurveViewerSVD(U, V, d.timeBlue, d.stimStarts(nc), ones(size(d.stimStarts(nc))), [-1 4])
% 
% 
% 
% 
% %% data analysis
% 
% 
% ti = d.inpTime;
% 
% dur=3;
% 
% 
% calDfk=[];
% calInp=[];
% for j = 1: length(nc)
%     [a i] = min(abs(d.timeBlue - d.stimStarts(nc(j))));
%     calDfk = [calDfk; dFk(i-3*35:i+35*(d.params.dur+3))];
%     [a i2] = min(abs(ti - d.stimStarts(nc(j))));
%     calInp = [calInp; d.inpVals(i2:i2+dur*2000)'];
% 
% end
% 
% 
% 
% ncDfk=[];
% ncInp=[];
% for j = 1: length(nc)
%     [a i] = min(abs(d.timeBlue - d.stimStarts(nc(j))));
%     ncDfk = [ncDfk; dFk(i-3*35:i+35*(d.params.dur+3))];
%     [a i2] = min(abs(ti - d.stimStarts(nc(j))));
%     ncInp = [ncInp; d.inpVals(i2:i2+dur*2000)'];
% 
% end
% 
% 
% wcDfk=[];
% wcInp=[];
% for j = 1: length(wc)
%     [a i] = min(abs(d.timeBlue - d.stimStarts(wc(j))));
%     wcDfk = [wcDfk; dFk(i-35*3:i+35*(d.params.dur+3))];
%     [a i2] = min(abs(ti - d.stimStarts(wc(j))));
%     wcInp = [wcInp; d.inpVals(i2:i2+dur*2000)'];
% 
% end
% 
% 
% ncoDfk=[];
% ncoInp=[];
% for j = 1: length(nc_opt)
%     [a i] = min(abs(d.timeBlue - d.stimStarts(nc_opt(j))));
%     ncoDfk = [ncoDfk; dFk(i-35*3:i+35*(d.params.dur+3))];
%     [a i2] = min(abs(ti - d.stimStarts(nc_opt(j))));
%     ncoInp = [ncoInp; d.inpVals(i2:i2+dur*2000)'];
% 
% end
% 
% 
% calDfk=[];
% calInp=[];
% for j = 1: length(cal)
%     [a i] = min(abs(d.timeBlue - d.stimStarts(cal(j))));
%     calDfk = [calDfk; dFk(i-35*3:i+35*(d.params.dur+3))];
%     [a i2] = min(abs(ti - d.stimStarts(cal(j))));
%     calInp = [calInp; d.inpVals(i2:i2+dur*2000)'];
% 
% end
% 
% 
% 
% 
% nc_avg = mean(ncDfk,1);
% wc_avg = mean(wcDfk,1);
% nco_avg = mean(ncoDfk,1);
% 
% 
% %% Compute H2 performance per trial sum(||e||)
% dur = d.params.dur;
% 
% d.ref = -2;
% 
% er_ncDfk=[];
% vr_ncDfk=[];
% for j = 1: length(nc)
%     [a i] = min(abs(d.timeBlue - d.stimStarts(nc(j))));
%     er_ncDfk = [er_ncDfk; norm(dFk(i:i+35*(dur))-d.ref)];
%     vr_ncDfk = [vr_ncDfk; var(dFk(i:i+35*(dur)))];
% end
% 
% er_wcDfk=[];
% vr_wcDfk=[];
% for j = 1: length(wc)
%     [a i] = min(abs(d.timeBlue - d.stimStarts(wc(j))));
%     er_wcDfk = [er_wcDfk; norm(dFk(i:i+35*(dur))-d.ref)];
%     vr_wcDfk = [vr_wcDfk; var(dFk(i:i+35*(dur)))];
% end
% 
% er_ncoDfk=[];
% vr_ncoDfk=[];
% for j = 1: length(nc_opt)
%     [a i] = min(abs(d.timeBlue - d.stimStarts(nc_opt(j))));
%     er_ncoDfk = [er_ncoDfk; norm(dFk(i:i+35*(dur))-d.ref)];
%     vr_ncoDfk = [vr_ncoDfk; var(dFk(i:i+35*(dur)))];
% end
% 
% 
% er_calDfk=[];
% vr_calDfk=[];
% for j = 1: length(cal)
%     [a i] = min(abs(d.timeBlue - d.stimStarts(cal(j))));
%     er_calDfk = [er_calDfk; norm(dFk(i:i+35*(dur))-d.ref)];
%     vr_calDfk = [vr_calDfk; var(dFk(i:i+35*(dur)))];
% end
% display('analysis done')
% 
% data.nc = nc;
% data.wc = wc; 
% data.dFk = dFk;
% 
% %%
% 
% 
% dur = d.params.dur;
% 
% dFk = data.dFk;
% nc = data.nc;
% wc = data.wc;
% t = d.timeBlue;
% trial=6;
% 
% % j = nc(trial)
% % [a i] = min(abs(t - d.stimStarts(j)));
% % [a i2] = min(abs(t - d.stimEnds(j)));
% % 
% % 
% % tt = d.inpTime;
% % v = d.inpVals;
% % 
% % [a k] = min(abs(tt - d.stimStarts(j)));
% % [a k2] = min(abs(tt - d.stimEnds(j)));
% % 
% % 
% % 
% % % Tin = 0:0.0005:stimDur(j);
% % Tout = -3:0.0285:dur+3;
% % Tref = 0:0.0285:dur;
% % figure()
% % ax1 = subplot(1,2,1)
% % hA = plot(Tout,dFk((i-(3*35)):(i+35*(dur+3))),'r','LineWidth',3);hold on
% % hB = plot(Tref,-5*ones(1,length(Tref)),'--k','LineWidth',2)
% % hC = plot(tt(k:k2)-tt(k),2*v(k:k2),'b','LineWidth',3)
% % % shortCornerAxes(gca, 'XLabel','Time(s)', 'YLabel','\DeltaF/F', 'Frac',0.10,'LineWidth',5);
% % 
% % 
% % ylim([-10 10])
% % xlim([-3,6])
% % xline(0)
% % xline(3)
% % % ylabel('dF/F','FontSize',12,'FontWeight','bold')
% % % xlabel('time(secs)','FontSize',12,'FontWeight','bold')
% % yl = ylim;   % current y-limits
% % x1 = 0;
% % x2 = 3;
% % patch([x1 x2 x2 x1], ...
% %       [yl(1) yl(1) yl(2) yl(2)], ...
% %       [0.9 0.9 0.9], ...
% %       'FaceAlpha', 0.3, ...
% %       'EdgeColor', 'none');
% % shortCornerAxes_plot(gca,'Frac',0.10,'XLabel','Time (s)','YLabel','\DeltaF/F','LineWidth',5)
% % 
% % % Keep data on top
% % uistack(findobj(gca,'Type','line'),'top')
% % hold off
% % box off
% % xticklabels([])
% % yticklabels([])
% % 
% % 
% % 
% % j = wc(trial)
% % [a i] = min(abs(t - d.stimStarts(j)));
% % [a i2] = min(abs(t - d.stimEnds(j)));
% % 
% % 
% % tt = d.inpTime;
% % v = d.inpVals;
% % 
% % [a k] = min(abs(tt - d.stimStarts(j)));
% % [a k2] = min(abs(tt - d.stimEnds(j)));
% % 
% % 
% % 
% % ax2 = subplot(1,2,2)
% % hD = plot(Tout,dFk((i-(3*35)):(i+35*(dur+3))),'Color',[0,0.5,0],'LineWidth',3);hold on
% % plot(Tref,-5*ones(1,length(Tref)),'--k','LineWidth',2)
% % plot(tt(k:k2)-tt(k),2*v(k:k2),'b','LineWidth',3)
% % % shortCornerAxes(gca, 'XLabel','', 'YLabel','', 'Frac',0.0,'LineWidth',0);
% % ylim([-10 10])
% % xlim([-3,6])
% % xline(0)
% % xline(3)
% % yl = ylim;   % current y-limits
% % x1 = 0;
% % x2 = 3;
% % patch([x1 x2 x2 x1], ...
% %       [yl(1) yl(1) yl(2) yl(2)], ...
% %       [0.9 0.9 0.9], ...
% %       'FaceAlpha', 0.3, ...
% %       'EdgeColor', 'none');
% % 
% % uistack(findobj(gca,'Type','line'),'top')
% % hold off
% % box off
% % xticklabels([])
% % yticklabels([])
% % set(gca, ...
% %     'Box','off', ...
% %     'XColor','none', ...
% %     'YColor','none', ...
% %     'TickDir','out', ...
% %     'XTick',[], ...
% %     'YTick',[], ...
% %     'Color','none');
% % 
% % 
% % legend(ax2, [hA hD hC hB], {'Closed Loop', 'Open Loop','Stim', 'Ref'}, ...
% %     'Location','northeast', ...
% %     'Box','off', FontSize=12, FontWeight='bold')
% % %%%%%%%%%%%%%%%%%%%%%
% % % set([ax1 ax2], 'Units','normalized');
% % % 
% % % leftMargin   = 0.08;
% % % rightMargin  = 0.03;
% % % bottomMargin = 0.18;
% % % topMargin    = 0.08;
% % % gap          = 0.05;
% % % 
% % % axW = (1 - leftMargin - rightMargin - gap)/2;
% % % axH = 1 - bottomMargin - topMargin;
% % % 
% % % ax1.Position = [leftMargin,              bottomMargin, axW, axH];
% % % ax2.Position = [leftMargin + axW + gap,  bottomMargin, axW, axH];
% % 
% % %%%%%%%%%%%%%%%%%%%%%
% % 
% % %%%%%%%%%%%%%%%%%
% % dur = d.params.dur;
% % ncDfk = data.ncDfk;
% % wcDfk = data.wcDfk;
% % 
% % pncDfk = data.pncDfk(:,246:end);
% % pwcDfk = data.pwcDfk(:,246:end);
% % nc_avg = mean(pncDfk,1);
% % wc_avg = mean(pwcDfk,1);
% % T= -3:0.0285:(dur+3);
% % Tin = 0:0.0005:dur;
% % Tout = 0:0.0285:dur;
% 
% %% full experiment
% 
% 
% 
% 
% figure()
% 
% % Column (vertical band) to shade
% x1 = 0;
% x2 = dur;
% T= -3:0.0285:(dur+3);
% Tin = 0:0.0005:dur;
% Tout = 0:0.0285:dur;
% size(T)
% % size(pncDfk)
% ref = [zeros(1,35*3), d.ref*ones(1,dur*35),zeros(1,35*dur+3)];
% Tref = 0:1/35:dur;
% ax1 = subplot(1,3,1)
% plot(T,ncDfk,'Color', [1 0 0 0.1],'LineWidth',0.5);hold on
% plot(T,zeros(1,length(T)),'k')
% % plot(T,d.ref*ones(1,length(T)),'--k','Linewidth',3);hold on
% % plot(T,ref,'--k','Linewidth',3);hold on
% plot(Tref,d.ref*ones(3*35+1),'--k','Linewidth',3);hold on
% plot(T,nc_avg,'r','Linewidth',3);
% plot(Tin,ncInp,'b','Linewidth',3);
% xline(0)
% xline(dur)
% shortCornerAxes_plot(gca,'Frac',0.10,'XLabel','Time (s)','YLabel','\DeltaF/F','LineWidth',5)
% 
% % shortCornerAxes(gca, 'XLabel','Time(s)', 'YLabel','\DeltaF/F', 'Frac',0.10,'LineWidth',5);
% % xlabel('time(sec)','FontSize',12,'FontWeight','bold')
% % ylabel('dF/F %','FontSize',12,'FontWeight','bold')
% ylim([-10 10])
% xlim([-3,6])
% yl = ylim;   % current y-limits
% 
% patch([x1 x2 x2 x1], ...
%       [yl(1) yl(1) yl(2) yl(2)], ...
%       [0.9 0.9 0.9], ...
%       'FaceAlpha', 0.3, ...
%       'EdgeColor', 'none');
% 
% % Keep data on top
% uistack(findobj(gca,'Type','line'),'top')
% hold off
% % yticklabels([])
% 
% % title('Open Loop')
% % ax = gca;
% % ax.FontWeight = 'bold';
% ax2 = subplot(1,3,2)
% 
% plot(T,wcDfk,'Color', [0 0.5 0 0.1],'LineWidth',0.5);hold on
% plot(T,zeros(1,length(T)),'k')
% plot(Tref,d.ref*ones(3*35+1),'--k','Linewidth',3);hold on
% plot(T,wc_avg,'Color', [0 0.5 0],'Linewidth',3);
% plot(Tin,mean(wcInp),'b','Linewidth',3);
% xline(0)
% xline(dur)
% ylim([-10 10])
% xlim([-3,6])
% % xlabel('time(sec)','FontSize',12,'FontWeight','bold')
% 
% yl = ylim;   % current y-limits
% 
% patch([x1 x2 x2 x1], ...
%       [yl(1) yl(1) yl(2) yl(2)], ...
%       [0.9 0.9 0.9], ...
%       'FaceAlpha', 0.3, ...
%       'EdgeColor', 'none');
% xticklabels([])
% yticklabels([])
% 
% 
% ax3 = subplot(1,3,3)
% plot(T,ncoDfk,'Color', [1 0.5 0 0.1],'LineWidth',0.5);hold on
% plot(T,zeros(1,length(T)),'k')
% % plot(T,d.ref*ones(1,length(T)),'--k','Linewidth',3);hold on
% % plot(T,ref,'--k','Linewidth',3);hold on
% plot(Tref,d.ref*ones(3*35+1),'--k','Linewidth',3);hold on
% plot(T,nco_avg,'Color', [1 0.5 0],'Linewidth',3);
% plot(Tin,ncoInp,'b','Linewidth',3);
% xline(0)
% xline(dur)
% % shortCornerAxes_plot(gca,'Frac',0.10,'XLabel','Time (s)','YLabel','\DeltaF/F','LineWidth',5)
% 
% % shortCornerAxes(gca, 'XLabel','Time(s)', 'YLabel','\DeltaF/F', 'Frac',0.10,'LineWidth',5);
% % xlabel('time(sec)','FontSize',12,'FontWeight','bold')
% % ylabel('dF/F %','FontSize',12,'FontWeight','bold')
% ylim([-10 10])
% xlim([-3,6])
% yl = ylim;   % current y-limits
% 
% patch([x1 x2 x2 x1], ...
%       [yl(1) yl(1) yl(2) yl(2)], ...
%       [0.9 0.9 0.9], ...
%       'FaceAlpha', 0.3, ...
%       'EdgeColor', 'none');
% 
% % Keep data on top
% uistack(findobj(gca,'Type','line'),'top')
% hold off
% % yticklabels([])
% 
% % title('Open Loop')
% % ax = gca;
% % ax.FontWeight = 'bold';
% 
% 
% 
% 
% xticklabels([])
% yticklabels([])
% set(gca, ...
%     'Box','off', ...
%     'XColor','none', ...
%     'YColor','none', ...
%     'TickDir','out', ...
%     'XTick',[], ...
%     'YTick',[], ...
%     'Color','none');
% 
% %%
% 
% 
% % set([ax1 ax2], 'Units','normalized');
% % 
% % leftMargin   = 0.08;
% % rightMargin  = 0.03;
% % bottomMargin = 0.18;
% % topMargin    = 0.08;
% % gap          = 0.05;
% % 
% % axW = (1 - leftMargin - rightMargin - gap)/2;
% % axH = 1 - bottomMargin - topMargin;
% % 
% % ax1.Position = [leftMargin,              bottomMargin, axW, axH];
% % ax2.Position = [leftMargin + axW + gap,  bottomMargin, axW, axH];
% % % Keep data on top
% % uistack(findobj(gca,'Type','line'),'top')
% % hold off
% % yticklabels([])
% % ax = gca;
% % ax.FontWeight = 'bold';
% % title('Closed Loop')
% % figure_property.Width= '16'; % Figure width on canvas
% % figure_property.Height= '9'; % Figure height on canvas
% % if a == 1
% %     hgexport(gcf,append('images/comp_controllers',mn,td,num2str(en),'.pdf'),figure_property); %Set desired file name
% % end
% % % exportgraphics(gcf,'P1.png','Resolution',1500)
% % uiwait(k)
% 
% %% var analysis
% 
% % nc_var = var(ncDfk - nc_avg);
% % wc_var = var(wcDfk - wc_avg);
% 
% 
% nc_var = var(ncDfk);
% wc_var = var(wcDfk);
% nco_var = var(ncoDfk);
% % wc_var = mean(wcDfk);
% 
% 
% % close all;
% figure()
% plot(T,nc_var,'r','LineWidth',2);hold on
% plot(T,wc_var,'Color', [0 0.5 0],'LineWidth',2);
% plot(T,nco_var,'Color', [1 0.5 0],'LineWidth',2);
% xline(0,'LineWidth',1.5)
% xline(dur,'LineWidth',1.5)
% ylim([-2,20])
% 
% % shortCornerAxes(gca, 'XLabel','Time(s)', 'YLabel','Variance', 'Frac',0.10,'LineWidth',5);
% % xlabel('time(sec)','FontSize',12,'FontWeight','bold')
% % ylabel('variance','FontSize',12,'FontWeight','bold')
% % legend('Open Loop', 'Closed loop')
% yl = ylim;   % current y-limits
% 
% patch([x1 x2 x2 x1], ...
%       [yl(1) yl(1) yl(2) yl(2)], ...
%       [0.9 0.9 0.9], ...
%       'FaceAlpha', 0.3, ...
%       'EdgeColor', 'none');
% shortCornerAxes_plot(gca,'Frac',0.10,'XLabel','Time (s)','YLabel','Variance','LineWidth',5)
% 
% % Keep data on top
% uistack(findobj(gca,'Type','line'),'top')
% hold off
% 
% 
% % % title('Variance Comparision')
% % figure_property.Width= '16'; % Figure width on canvas
% % figure_property.Height= '9'; % Figure height on canvas
% % if a == 1
% % hgexport(gcf,append('images/comp_var',mn,td,num2str(en),'.pdf'),figure_property); %Set desired file name
% % end
% % exportgraphics(gcf,'P2.png','Resolution',1500)
% % uiwait(k)
% 
% 
% 
% 
% 
% 
% %%
% 
% figure(); hold on;
% subplot(1,3,1);hold on;
% halfWidth = 0.3;
% alphaFill = 0.5;
% 
% 
% k=1
% colA = [1 0 0];
% colB = [0  0.5 0];
% 
% 
%     [fA, yA] = ksdensity(er_ncDfk);
%     fA = fA / max(fA) * halfWidth;
% 
%     fill([k - fA, k*ones(size(fA))], ...
%          [yA,      fliplr(yA)], ...
%          colA, 'FaceAlpha', alphaFill, 'EdgeColor','none');
% 
%     % Mean line A
%     muA = mean(er_ncDfk);
%     plot([ k - 0.1], [ muA], 'r*', 'LineWidth', 1.5);
% 
%     % -------- Distribution B (right) --------
%     [fB, yB] = ksdensity(er_wcDfk);
%     fB = fB / max(fB) * halfWidth;
% 
%     fill([k + fB, k*ones(size(fB))], ...
%          [yB,      fliplr(yB)], ...
%          colB, 'FaceAlpha', alphaFill, 'EdgeColor','none');
% 
%     % Mean line B
%     muB = mean(er_wcDfk);
%     plot([k+0.1], [ muB], 'g*', 'LineWidth', 5);
% ax.FontSize = 16
% xticks([])
% 
% 
% 
% 
% subplot(1,3,2);hold on;
% halfWidth = 0.3;
% alphaFill = 0.5;
% 
% k=1
% colA = [1 0.5 0];
% colB = [0  0.5 0];
% 
% 
%     [fA, yA] = ksdensity(er_ncoDfk);
%     fA = fA / max(fA) * halfWidth;
% 
%     fill([k - fA, k*ones(size(fA))], ...
%          [yA,      fliplr(yA)], ...
%          colA, 'FaceAlpha', alphaFill, 'EdgeColor','none');
% 
%     % Mean line A
%     muA = mean(er_ncoDfk);
%     plot([ k - 0.1], [ muA], 'r*', 'LineWidth', 1.5);
% 
%     % -------- Distribution B (right) --------
%     [fB, yB] = ksdensity(er_wcDfk);
%     fB = fB / max(fB) * halfWidth;
% 
%     fill([k + fB, k*ones(size(fB))], ...
%          [yB,      fliplr(yB)], ...
%          colB, 'FaceAlpha', alphaFill, 'EdgeColor','none');
% 
%     % Mean line B
%     muB = mean(er_wcDfk);
%     plot([k+0.1], [ muB], 'g*', 'LineWidth', 5);
% ax.FontSize = 16
% xticks([])
% 
% shortCornerAxes_plot(gca,'Frac',0.10,'XLabel','MSE','YLabel','Trials','LineWidth',5)
% 
% 
% subplot(1,3,3);hold on;
% halfWidth = 0.3;
% alphaFill = 0.5;
% 
% 
% k=1
% colA = [1 0 0];
% colB = [1  0.5 0];
% 
% 
%     [fA, yA] = ksdensity(er_ncDfk);
%     fA = fA / max(fA) * halfWidth;
% 
%     fill([k - fA, k*ones(size(fA))], ...
%          [yA,      fliplr(yA)], ...
%          colA, 'FaceAlpha', alphaFill, 'EdgeColor','none');
% 
%     % Mean line A
%     muA = mean(er_ncDfk);
%     plot([ k - 0.1], [ muA], 'r*', 'LineWidth', 1.5);
% 
%     % -------- Distribution B (right) --------
%     [fB, yB] = ksdensity(er_ncoDfk);
%     fB = fB / max(fB) * halfWidth;
% 
%     fill([k + fB, k*ones(size(fB))], ...
%          [yB,      fliplr(yB)], ...
%          colB, 'FaceAlpha', alphaFill, 'EdgeColor','none');
% 
%     % Mean line B
%     muB = mean(er_ncoDfk);
%     plot([k+0.1], [ muB], 'r*', 'LineWidth', 5);
% ax.FontSize = 16
% xticks([])
% 
% shortCornerAxes_plot(gca,'Frac',0.10,'XLabel','MSE','YLabel','Trials','LineWidth',5)
% 
% 
% %%
% figure()
% plot(er_ncDfk,'ro');hold on;
% plot(er_wcDfk,'go');
% plot(er_ncoDfk,'bo');
% 
% 
% %%
% 
% dFk_imp=[];
% for j = 1:length(d.stimStarts)
%     [a i] = min(abs(d.timeBlue - d.stimStarts(j)));
%     dFk_imp = [dFk_imp;dFk(i-10:i+10)];
% end
% 
% 
% figure()
% plot(dFk_imp');hold on;
% plot(mean(dFk_imp),'LineWidth',4)
% 
% 
% dFk_imp=[];
% for j = 1:length(d.stimEnds)
%     [a i] = min(abs(d.timeBlue - d.stimEnds(j)));
%     dFk_imp = [dFk_imp;dFk(i-10:i+10)];
% end
% 
% figure()
% plot(dFk_imp');hold on;
% plot(mean(dFk_imp),'LineWidth',4)
% 
% 
% 
% 
% dFk_imp=[];
% for j = 1:length(d.stimStarts)
%     [a i] = min(abs(d.timeBlue - d.stimStarts(j)));
%     dFk_imp = [dFk_imp;dFk2(i-10:i+10)];
% end
% 
% 
% figure()
% plot(dFk_imp');hold on;
% plot(mean(dFk_imp),'LineWidth',4)
% 
% 
% dFk_imp=[];
% for j = 1:length(d.stimEnds)
%     [a i] = min(abs(d.timeBlue - d.stimEnds(j)));
%     dFk_imp = [dFk_imp;dFk2(i-10:i+10)];
% end
% 
% figure()
% plot(dFk_imp');hold on;
% plot(mean(dFk_imp),'LineWidth',4)
% 
% 
% 
% %%
% 
% dFk2 = d.states(1:length(d.timeBlue))';
% 
% 
% 
% figure()
% plot(d.timeBlue,dFk,'r');hold on;
% plot(d.timeBlue,dFk2,'k');hold on;
% plot(tt,v,'b');hold on;
% xline(d.stimStarts)
% 
% 
% %% blue vs violet investigation:::
% % generate 8 points on a unit circle (x,y)
% theta = (0:5)' * (2*pi/6);  % 8 angles equally spaced
% r = 20;                      % radius
% pts = [r*cos(theta), r*sin(theta)];  % 8x2 matrix [x y]
% 
% r = 30
% 
% pts = [pts;r*cos(theta), r*sin(theta)]
% 
% 
% pts = (d.params.pixels) + pts
% % plot the points for visualization (optional but consistent with surrounding plotting)
% figure()
% 
% hold on
% plot(pts(:,1), pts(:,2), 'go', 'MarkerFaceColor','k', 'MarkerSize',8)
% axis equal
% %%
% dFkpix=[];
%     F = [];
% 
%     k=double(d.params.kernel);
%     display('computing pixel val')
% 
%         pixels = (d.params.pixels)+pts;
%         % source_dir ='/mnt/data/brain/';
%         source_dir = 'C:\Users\aditya\Documents\projects\data\';
%         source_dir = append(source_dir,d.mn,'\',d.td,'\',num2str(d.en));
%         a=dir([source_dir '\*'])
%         out=size(a,1);
% 
%         out=out-2;
%         path = append(source_dir,'\frame-');
% 
% % Pre-allocate F matrix: rows = pixels, cols = frames
% nPix = length(pixels);
% F = zeros(nPix, out);
% 
% for i = 1:2:out
%     pathim = append(path, num2str(i-1));
%     fileID = fopen(pathim, 'r');
%     A = fread(fileID, [560,560], 'uint16')';
%     fclose(fileID);
%     i
%     for s = 1:nPix
%         px = double(pixels(s,:));
%         px = max(k+1, min(560-k, px));
%         F(s,i) = mean(A(px(2)-k:px(2)+k, px(1)-k:px(1)+k), 'all');
%     end
% end
% 
% display('computing df/F')
% w = d.params.horizon-1;
% for s = 1:nPix
%     F  = F(s,:);
%     % Fv = F(2:2:end);
% 
%     Fkb = [ones(1,w), Fb];
%     % Fkv = [ones(1,w), Fv];
% 
%     dFkb = zeros(1, length(Fv));
%     % dFkv = zeros(1, length(Fv));
%     Fkmeanb = zeros(1, length(Fv));
%     % Fkmeanv = zeros(1, length(Fv));
% 
%     for i = 1:length(Fb)
%         Fkmeanb(i) = mean(Fkb(i:i+w));
%         dFkb(i)    = (Fkb(i+w) - Fkmeanb(i)) / Fkmeanb(i) * 100;
% 
%         % Fkmeanv(i) = mean(Fkv(i:i+w));
%         % dFkv(i)    = (Fkv(i+w) - Fkmeanv(i)) / Fkmeanv(i) * 100;
%     end
% 
%     dFkpix = [dFkpix; dFkb];
% end
% 
% %%
% 
% 
% 
% close all
% 
% figure()
% plot(Fb,'b','LineWidth',3); hold on
% plot(Fv,'k','LineWidth',3)
% 
% 
% 
% figure()
% plot(d.timeBlue(2:end),dFkb,'b','LineWidth',3); hold on
% plot(d.timeBlue(2:end),dFkv,'k','LineWidth',3)
% xline(d.stimStarts,'r')
% xline(d.stimEnds,'g')
% %%
% close all;
% i = 3
% dFkb = dFkpix(i,:);
% 
% %
% ncdFk=[];
% for i =1:length(nc)
%     [a,k] = min(abs(d.timeBlue - d.stimStarts(nc(i))))
% 
%     ncdFk = [ncdFk;dFkb(k-3*35:k+(dur+3)*35)];
% end
% 
% 
% 
% wcdFk=[];
% for i =1:length(wc)
%     [a,k] = min(abs(d.timeBlue - d.stimStarts(wc(i))))
% 
%     wcdFk = [wcdFk;dFkb(k-3*35:k+(dur+3)*35)];
% end
% 
% 
% ncodFk=[];
% for i =1:length(nc_opt)
%     [a,k] = min(abs(d.timeBlue - d.stimStarts(nc_opt(i))))
% 
%     ncodFk = [ncodFk;dFkb(k-3*35:k+(dur+3)*35)];
% end
% 
% %
% t = -3:1/35:6;
% tr=0:1/35:3;
% r = -2*ones(1,length(tr));
% 
% figure()
% subplot(1,3,1)
% plot(t,ncdFk,'Color',[1,0,0,0.1]);hold on;
% plot(t,mean(ncdFk),'Color',[1,0,0],'LineWidth',4);hold on;
% plot(tr,r,'--k','LineWidth',2)
% xline(0);
% xline(3)
% 
% 
% subplot(1,3,2)
% plot(t,wcdFk,'Color',[0,0.5,0,0.1]);hold on;
% plot(t,mean(wcdFk),'Color',[0,0.5,0],'LineWidth',4);hold on;
% plot(tr,r,'--k','LineWidth',2)
% xline(0);
% xline(3)
% 
% subplot(1,3,3)
% plot(t,ncodFk,'Color',[0,0,0.1,0.1]);hold on;
% plot(t,mean(ncodFk),'Color',[0,0,1],'LineWidth',4);hold on;
% plot(tr,r,'--k','LineWidth',2)
% xline(0);
% xline(3)
% 
% 
% %
% 
% t = -3:1/35:6;
% tr=0:1/35:3;
% r = -2*ones(1,length(tr));
% 
% 
% figure()
% plot(t,var(ncdFk),'Color',[1,0,0]);hold on;
% plot(t,var(wcdFk),'Color',[0,0.5,0]);hold on;
% plot(t,var(ncodFk),'Color',[0,0,0.1]);hold on;
% xline(0);
% xline(3)
% 
% 
% %%
% 
% 
% %%
% close all;
% i = 3
% dFkb = dFk;
% 
% %
% ncdFk=[];
% for i =1:10
%     [a,k] = min(abs(d.timeBlue - d.stimStarts(nc(i))))
% 
%     ncdFk = [ncdFk;dFkb(k-3*35:k+(dur+3)*35)];
% end
% 
% 
% 
% wcdFk=[];
% for i =1:10
%     [a,k] = min(abs(d.timeBlue - d.stimStarts(wc(i))))
% 
%     wcdFk = [wcdFk;dFkb(k-3*35:k+(dur+3)*35)];
% end
% 
% 
% ncodFk=[];
% for i =1:10
%     [a,k] = min(abs(d.timeBlue - d.stimStarts(nc_opt(i))))
% 
%     ncodFk = [ncodFk;dFkb(k-3*35:k+(dur+3)*35)];
% end
% 
% caldFk=[];
% for i =1:10
%     [a,k] = min(abs(d.timeBlue - d.stimStarts(cal(i))))
% 
%     caldFk = [caldFk;dFkb(k-3*35:k+(dur+3)*35)];
% end
% 
% %
% t = -3:1/35:6;
% tr=0:1/35:3;
% r = -2*ones(1,length(tr));
% 
% figure()
% subplot(1,4,1)
% plot(t,caldFk,'Color',[1,1,0,0.1]);hold on;
% plot(t,mean(caldFk),'Color',[1,1,0],'LineWidth',4);hold on;
% plot(tr,r,'--k','LineWidth',2)
% xline(0);
% xline(3)
% 
% 
% subplot(1,4,2)
% plot(t,ncdFk,'Color',[1,0,0,0.1]);hold on;
% plot(t,mean(ncdFk),'Color',[1,0,0],'LineWidth',4);hold on;
% plot(tr,r,'--k','LineWidth',2)
% xline(0);
% xline(3)
% 
% 
% subplot(1,4,3)
% plot(t,wcdFk,'Color',[0,0.5,0,0.1]);hold on;
% plot(t,mean(wcdFk),'Color',[0,0.5,0],'LineWidth',4);hold on;
% plot(tr,r,'--k','LineWidth',2)
% xline(0);
% xline(3)
% 
% subplot(1,4,4)
% plot(t,ncodFk,'Color',[0,0,0.1,0.1]);hold on;
% plot(t,mean(ncodFk),'Color',[0,0,1],'LineWidth',4);hold on;
% plot(tr,r,'--k','LineWidth',2)
% xline(0);
% xline(3)
% 
% 
% %
% 
% t = -3:1/35:6;
% tr=0:1/35:3;
% r = -2*ones(1,length(tr));
% 
% 
% figure()
% plot(t,var(ncdFk),'Color',[1,0,0]);hold on;
% plot(t,var(wcdFk),'Color',[0,0.5,0]);hold on;
% plot(t,var(ncodFk),'Color',[0,0,0.1]);hold on;
% xline(0);
% xline(3)
% 
