function ctrl_mpc_svd_export(sess, nSV)
%CTRL_MPC_SVD_EXPORT  Whole-brain SVD temporal components on the controller's frame clock, as an
%   alternative forecaster input to the 100 spots (ctrl_mpc_wb_export). Same SVD source (cp_loadUVt,
%   hemo-corrected V when present), same interpolation onto d.timeBlue (= data.dFk frames).
%   Components are kept in SVD order (variance-ranked) and NOT rescaled here (the Python side z-scores).
% OUT  data/ctrl_mpc_svd_in_<sess>_k<nSV>.mat (v7): V [T x nSV] on timeBlue, s [nSV x 1] (U column norms)
if nargin < 1, sess = 'AL_0033_0226_e2'; end
if nargin < 2, nSV = 200; end
here = fileparts(mfilename('fullpath')); dataDir = fullfile(here,'data'); addpath(genpath(fullfile(here,'..','utils')));
F3 = load(fullfile(dataDir, sprintf('ctrl_mpc_lqr_%s_fig3.mat', sess)), 'P');
Z = load(fullfile(here,'..','data',F3.P.rawFile), 'd'); dz = Z.d;
tk = regexp(sess, '(AL_\d+)_(\d\d)(\d\d)_e(\d+)', 'tokens', 'once');
sr = expPath(tk{1}, sprintf('2025-%s-%s', tk{2}, tk{3}), str2double(tk{4}));
[U, V, tsvd] = cp_loadUVt(sr, nSV, dz.timeBlue);
V = double(V); s = sqrt(squeeze(sum(sum(double(U).^2, 1), 2)));
tb = dz.timeBlue(:); tsvd = tsvd(:); n = min(numel(tsvd), size(V,2));
Vt = interp1(tsvd(1:n), V(:,1:n).', tb, 'linear', 'extrap');      % [T x nSV] on the dFk frame clock
fprintf('[SVD-EXP] %s | %d SV | %d svd frames -> %d timeBlue frames\n', sess, size(V,1), n, numel(tb));
S = struct('V', Vt, 's', s(:), 'nSV', size(V,1), 'sess', sess);
save(fullfile(dataDir, sprintf('ctrl_mpc_svd_in_%s_k%d.mat', sess, nSV)), '-struct', 'S', '-v7');
end
