%% package_grid_for_collab.m
% Collaborator-ready bundle for the AL_0046 grid-activation (photostim mapping) session.
%
% Ships:
%   widefield/ : canonical SVD  U[Y,X,nSV], V[nSV,nFrames], meanImage, frameTimes
%                CROPPED to the grid-experiment window (the recording also contains an
%                unrelated 638 nm block in window 1, which is excluded).
%   stim/      : full per-trial table (galvo X/Y, laser power, onset/offset, SVD frame)
%                + a unique-sites table.
%
% No face_proc.mat exists for this session, so no motion/face SVD is shipped.
% Re-saves U/V as single (first nSV comps) -> ~150x smaller than the raw session folder.

nSV = 500;  L = '594';
serverRoot = '\\sahale.biostr.washington.edu\data\Subjects\AL_0046\2026-02-22\1';
outDir     = 'C:\Users\aditya\Documents\projects\collab_export_AL0046_grid';
PAD = 1.0;   % seconds of frames to keep on each side of the grid window (baseline headroom)

thisDir = fileparts(mfilename('fullpath')); if isempty(thisDir), thisDir = pwd; end
addpath(genpath(fullfile(thisDir,'..','utils')));
for s = {'widefield','stim'}, mkdir(fullfile(outDir,s{1})); end

%% --- grid window ---------------------------------------------------------
ess = readNPY(fullfile(serverRoot,'expStartStopTimes.npy'));
gw  = ess(2,:);                       % [start stop] of the grid experiment (s)

%% --- widefield SVD, cropped to grid window -------------------------------
U    = readUfromNPY(fullfile(serverRoot,'blue','svdSpatialComponents.npy'), nSV);   % [Y X nSV]
V    = readVfromNPY(fullfile(serverRoot,'corr','svdTemporalComponents_corr.npy'), nSV); % [nSV T]
mimg = readNPY(fullfile(serverRoot,'blue','meanImage.npy'));
tAll = double(readNPY(fullfile(serverRoot,'corr','svdTemporalComponents_corr.timestamps.npy'))); tAll = tAll(:);

keep = find(tAll >= gw(1)-PAD & tAll <= gw(2)+PAD);
V = V(:, keep);  t = tAll(keep);
nF = numel(t);  fs = 1/median(diff(t));

writeNPY(single(U),    fullfile(outDir,'widefield','U_svdSpatial.npy'));
writeNPY(single(V),    fullfile(outDir,'widefield','V_svdTemporal_corr.npy'));
writeNPY(single(mimg), fullfile(outDir,'widefield','meanImage.npy'));
writeNPY(t,            fullfile(outDir,'widefield','frameTimes.npy'));
fprintf('widefield: U[%d %d %d] V[%d %d] @ %.2f Hz, cropped to %d/%d frames\n', ...
    size(U,1),size(U,2),size(U,3), size(V,1),size(V,2), fs, nF, numel(tAll));
clear U V mimg

%% --- stim trial table (grid window, 594 nm) ------------------------------
gx  = round(squeeze(readNPY(fullfile(serverRoot,'galvoXPositions_mm.npy')))*2)/2;  % round 0.5: timeline jitter fix
gy  = round(squeeze(readNPY(fullfile(serverRoot,'galvoYPositions_mm.npy')))*2)/2;
amp = round(squeeze(readNPY(fullfile(serverRoot,[L 'laserPowers_mW.npy'])))*2)/2;
onT  = squeeze(readNPY(fullfile(serverRoot,[L 'laserOnTimes.npy'])));
offT = squeeze(readNPY(fullfile(serverRoot,[L 'laserOffTimes.npy'])));
tr = find(onT>=gw(1) & onT<=gw(2));
gx=gx(tr); gy=gy(tr); amp=amp(tr); onT=onT(tr); offT=offT(tr);

svd_frame = round(interp1(t,(1:nF)', onT, 'nearest','extrap'));   % index into the (cropped) V
[sites,~,sid] = unique([gx gy], 'rows');
nPer = accumarray(sid, 1);

trials = table((1:numel(onT))', onT, offT, offT-onT, svd_frame, gx, gy, amp, sid, ...
    'VariableNames', {'trial','onset_time_s','offset_time_s','pulse_dur_s', ...
                      'svd_frame','galvo_x_mm','galvo_y_mm','laser_power_mW','site_id'});
sitesT = table((1:size(sites,1))', sites(:,1), sites(:,2), nPer, ...
    'VariableNames', {'site_id','galvo_x_mm','galvo_y_mm','n_trials'});

writetable(trials, fullfile(outDir,'stim','trials.csv'));
writetable(sitesT, fullfile(outDir,'stim','sites.csv'));
save(fullfile(outDir,'stim','stim.mat'), 'trials','sitesT','gw','fs','-v7');

%% --- report --------------------------------------------------------------
fl = dir(fullfile(outDir,'**','*')); tot = sum([fl(~[fl.isdir]).bytes]);
fprintf('grid bundle -> %s  (%.2f GB)\n', outDir, tot/1e9);
fprintf('trials=%d | sites=%d | powers=%s mW | grid window=[%.1f %.1f]s\n', ...
    height(trials), height(sitesT), num2str(unique(amp)'), gw(1), gw(2));
