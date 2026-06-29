%% compute_face_motion_AL0046.m
% Compute face motion energy from the raw face.mp4 (no face_proc.mat exists) and
% add it to the grid-activation collaborator bundle, aligned to the imaging frames.
%
% Motion energy = mean over ROI pixels of |frame(t) - frame(t-1)| (gray levels),
% within the lab's saved face ROI. Computed only over the grid window, then
% interpolated onto the bundle's imaging frame times.

d   = '\\sahale.biostr.washington.edu\data\Subjects\AL_0046\2026-02-22\1';
out = 'C:\Users\aditya\Documents\projects\collab_export_AL0046_grid';
ckpt= 'C:\Users\aditya\Documents\projects\brain_paper\scratch_grid\face_me_ckpt.mat';
thisDir=fileparts(mfilename('fullpath')); if isempty(thisDir),thisDir=pwd;end
addpath(genpath(fullfile(thisDir,'..','utils')));
roi = [488 136 752 590];                 % [x1 y1 x2 y2] from face_ROI.mat
rr  = roi(2):roi(4);  cc = roi(1):roi(3);

ftt = double(readNPY(fullfile(d,'frameTimes.timestamps.npy')));   % face frame times (s)
ess = readNPY(fullfile(d,'expStartStopTimes.npy')); gw = ess(2,:);
gi  = find(ftt>=gw(1)-1 & ftt<=gw(2)+1); startF=gi(1); endF=gi(end);
N   = endF-startF+1;
v   = VideoReader(fullfile(d,'face.mp4'));

ME = nan(N,1);                            % motion energy per face frame, ME(1)=frame startF
seed = startF-1;                          % predecessor for the first real frame
batch = 4000; prev = []; k = seed;
fprintf('Face motion energy: %d frames, %.1f..%.1f s, ROI %dx%d\n',N,ftt(startF),ftt(endF),numel(rr),numel(cc));
tic;
while k <= endF
    b2 = min(k+batch-1, endF);
    M  = read(v,[k b2]);
    Gr = squeeze(mean(single(M),3));      % HxWxn gray
    Gr = Gr(rr,cc,:);                      % ROI
    if isempty(prev)
        blk = Gr;  fr = (k+1):b2;          % first batch: seed at idx1, diffs -> startF..b2
    else
        blk = cat(3, prev, Gr);  fr = k:b2;
    end
    dme = squeeze(mean(mean(abs(diff(blk,1,3)),1),2));
    ME(fr-startF+1) = dme;
    prev = Gr(:,:,end);  k = b2+1;
    if mod(k-startF, 40000) < batch
        fprintf('  %d/%d (%.0f%%) %.0fs elapsed\n', k-startF, N, 100*(k-startF)/N, toc);
        save(ckpt,'ME','startF','endF','ftt','-v7');   % checkpoint
    end
end
ME(1) = ME(min(2,N));                     % seed frame: copy neighbor (no true predecessor used)
fprintf('decode done in %.0f s\n', toc);

%% align to the bundle's imaging frames + write into the share
face_t = ftt(startF:endF);
t_img  = double(readNPY(fullfile(out,'widefield','frameTimes.npy')));
motion_energy = interp1(face_t, ME, t_img, 'linear','extrap');
mkdir(fullfile(out,'aligned'));
writeNPY(motion_energy, fullfile(out,'aligned','motion_energy.npy'));        % imaging-frame grid
writeNPY(single(ME),    fullfile(out,'aligned','face_motion_raw.npy'));      % face-frame grid
writeNPY(face_t,        fullfile(out,'aligned','face_frame_times.npy'));
writematrix([t_img motion_energy], fullfile(out,'aligned','motion_aligned.csv'));  % frame_time_s, motion_energy
save(fullfile(out,'aligned','motion.mat'),'motion_energy','t_img','ME','face_t','roi','-v7');
fprintf('SHIPPED motion_energy: %d imaging frames | face raw %d frames | ROI=[%d %d %d %d]\n', ...
    numel(motion_energy), numel(ME), roi);
fprintf('motion_energy stats: min %.2f median %.2f max %.2f\n', min(motion_energy),median(motion_energy),max(motion_energy));
