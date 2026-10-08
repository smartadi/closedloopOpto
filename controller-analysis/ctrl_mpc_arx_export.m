function ctrl_mpc_arx_export(sess)
%CTRL_MPC_ARX_EXPORT  Hand the CONTINUOUS session to the Python AR/ARX forecaster (mpc_arx_forecaster.py).
%   d_full = recorded online dF/F (data.dFk, Fig-3 frame) minus the identified plant's response to the
%   recorded laser command, over the WHOLE session (138k frames, ~66 min incl. ITIs and OL trials) --
%   the same disturbance definition ctrl_mpc_lqr replays, just not cut into trials. Python fits the
%   Lu et al. 2025 AR (lag order by validation MWQL) on it, with / without laser-command lags.
%   Also passes the CL-trial onsets, the trial folds of ctrl_mpc_forecasters (so the MPC comparison is
%   paired fold-for-fold) and the per-time mean Dmean that ctrl_mpc_lqr subtracts (DEP = D - Dmean).
%   v7 MAT (no HDF5) so scipy.io reads it without h5py.
% OUT  data/ctrl_mpc_arx_in_<sess>.mat
if nargin < 1, sess = 'AL_0033_0226_e2'; end
here = fileparts(mfilename('fullpath')); dataDir = fullfile(here,'data'); addpath(genpath(fullfile(here,'..','utils')));
F3 = load(fullfile(dataDir, sprintf('ctrl_mpc_lqr_%s_fig3.mat', sess)), 'A','B','C','P');
FC = load(fullfile(dataDir, sprintf('ctrl_mpc_forecasters_%s.mat', sess)), 'fold','DEP');
Z = load(fullfile(here,'..','data',F3.P.rawFile)); dz = Z.d; Dz = Z.data;
[uAmp,~] = cp_laser_amplitude(dz.inpVals, dz.inpTime);
tb = dz.timeBlue(:); y = double(Dz.dFk(:));
u = interp1(dz.inpTime, uAmp, tb, 'linear', 0); u(isnan(u)) = 0;
md = ss(F3.A, F3.B, F3.C, 0, 1/F3.P.Fs);
d = y - lsim(md, u);
pre = 35; N = 105; Hp = F3.P.Hp; rel = -pre:N;
on = arrayfun(@(t) find(tb >= t, 1), dz.stimStarts(:));
onCL = on(Dz.wc(:)); onOL = on(Dz.nc(:));
Dk = cell2mat(arrayfun(@(o) d(o+rel).', onCL, 'uni', 0));
Dmean = mean(Dk, 1);
chk = max(abs(Dk - Dmean - FC.DEP), [], 'all');          % must reproduce the MATLAB forecasters' DEP
fprintf('[ARX-EXP] %d frames (%.1f min) | %d CL / %d OL trials | DEP check max|diff| = %.2g\n', ...
    numel(d), numel(d)/F3.P.Fs/60, numel(onCL), numel(onOL), chk);
% Not exact (measured 0.032 vs sd(DEP) ~2.7): the trial version starts lsim from zero state at -1 s,
% the continuous one carries the previous stimulus's tail through the ITI. Negligible; gate on 0.1.
assert(chk < 0.1, 'continuous d does not reproduce the trial DEP used by ctrl_mpc_lqr');
% The rig's online dF/F uses a trailing baseline of `horizon` frames (1400 = 40 s): the first
% horizon-1 frames are warm-up garbage (up to 5.8e4 %dF/F on this session). Found 2026-10-07 after it
% had contaminated the first Python AR/ARX fits. Every consumer must AND this into its usable mask.
valid = (1:numel(y)).' >= double(dz.params.horizon) & isfinite(y);
fprintf('[ARX-EXP] warm-up: first %d frames invalid (first trial onset at frame %d)\n', ...
    find(valid,1)-1, min([onCL; onOL]));
mot = zeros(size(y)); if isfield(dz,'motion') && numel(dz.motion) == numel(y), mot = double(dz.motion(:)); end
S = struct('d',d,'u',u,'y',y,'motion',mot,'valid',double(valid),'onCL',onCL,'onOL',onOL,'fold',FC.fold(:),'Dmean',Dmean(:), ...
           'pre',pre,'N',N,'Hp',Hp,'Fs',F3.P.Fs,'sess',sess);
save(fullfile(dataDir, sprintf('ctrl_mpc_arx_in_%s.mat', sess)), '-struct','S', '-v7');
end
