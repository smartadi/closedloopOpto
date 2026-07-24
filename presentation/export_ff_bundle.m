% export_ff_bundle.m — export the feedforward (sine-tracking) movie bundle for
% the FF-analysis demo video, from a loaded bilateral `sess` struct.
%
% Mirrors the m5/m13 controller-demo bundle (block-averaged SVD U + per-trial V
% windows), but for the AL_0048 dual-opsin FF sine-tracking experiment:
%   - right (inhibitory) hemisphere only
%   - 4 modes via ff_cond (input_params col 17): 2=OL 1=OL+prev 3=CL 0=CL+prev
%   - reference is the FIXED logged sine, sliced at each trial's onset:
%       Rj = ref0 + REF_SIGN * ref_raw(i0 : i0+n_win),  REF_SIGN=-1
%     (identical convention to bilateral/sine_ff_modes.m — validated)
%
% Assumes `sess` is already in the base workspace (load the bilateral cache first).
% Writes presentation/assets/ff_<tag>_bundle.mat.
%
% Usage (from brain_paper/):
%   S = load('data/AL_0048_bil_07211.mat'); sess = S.sess; clear S;
%   TAG = 'ff_0721'; run('presentation/export_ff_bundle.m')

if ~exist('sess', 'var'); error('load the bilateral cache into `sess` first'); end
if ~exist('TAG', 'var');  TAG = 'ff_0721'; end

SIDE     = 'right';
REF_SIGN = -1;
fs_img   = 35;            % samples/s used for windowing (matches sine_ff_modes)
PRE_S    = 2.0;          % pre-onset context (stim -2 s)
POST_PAD = 2.0;          % post-stim context (stim end +2 s)
n_pre    = round(PRE_S * fs_img);                      % 70 samples pre-onset (t=-2 s)
n_win    = round((sess.sine.dur + POST_PAD) * fs_img); % 210 samples (t=0..dur+2)
NWIN     = n_pre + n_win + 1;            % 281
ds       = 4;                            % block-average factor (560 -> 140)
K        = 200;                          % SVD components kept

d    = sess.d;
U    = d.svd.U;                          % 560 x 560 x 2000 (single)
Vall = d.svd.V;                          % 2000 x 150013 (single)
mimg = d.svd.mimg;                       % 560 x 560
dFoF = sess.(SIDE).dFoF;                 % 1 x 150013
tb   = d.timeBlue;                       % 150013 x 1 (Timeline seconds)
[ny, nx, ~] = size(U);
n  = ny / ds;                            % 140

% ---- block-average mimg + first K components of U to n x n ----------------
fprintf('block-averaging U(:,:,1:%d) and mimg to %dx%d ...\n', K, n, n);
mimg_ds = squeeze(mean(mean(reshape(mimg, ds, n, ds, n), 1), 3));   % n x n
U_ds = zeros(n, n, K, 'single');
for c = 1:K
    U_ds(:, :, c) = squeeze(mean(mean(reshape(U(:, :, c), ds, n, ds, n), 1), 3));
end

% ---- collect right-side FF trials in acquisition order --------------------
sideMask = strcmp({sess.trial_meta.side}, SIDE);
fc_all   = [sess.trial_meta.ff_cond];
isFF     = ismember(fc_all, [2 1 3 0]) & sideMask;
tmeta    = sess.trial_meta(isFF);
trials   = double([tmeta.trial_idx]);    % double: trial_idx stored as uint8 wraps >255
[trials, order] = sort(trials);          % acquisition order
tmeta    = tmeta(order);

Ntr = numel(trials);
Vwin    = zeros(K, NWIN, Ntr, 'single');
dFoFwin = zeros(Ntr, NWIN);
refwin  = nan(Ntr, n_win + 1);           % post-onset reference (t=0..dur)
inpwin  = zeros(Ntr, NWIN);              % laser command input (iputs), full window
ffcond  = zeros(Ntr, 1);
onset_t = zeros(Ntr, 1);                 % Timeline sec at onset (camera sync)
onset_i = zeros(Ntr, 1);                 % widefield frame index at onset
keep    = true(Ntr, 1);

for j = 1:Ntr
    ti = trials(j);
    i0 = sess.onset_idx(ti);
    if isnan(i0) || i0 - n_pre < 1 || i0 + n_win > numel(dFoF) || i0 + n_win > numel(sess.ref_raw)
        keep(j) = false; continue;
    end
    Vwin(:, :, j)  = Vall(1:K, i0 - n_pre : i0 + n_win);
    dFoFwin(j, :)  = dFoF(i0 - n_pre : i0 + n_win);
    refwin(j, :)   = sess.sine.ref0 + REF_SIGN * sess.ref_raw(i0 : i0 + n_win).';
    inpwin(j, :)   = sess.d.iputs(i0 - n_pre : i0 + n_win).';
    ffcond(j)      = tmeta(j).ff_cond;
    onset_i(j)     = i0;
    onset_t(j)     = tb(i0);
end

Vwin=Vwin(:,:,keep); dFoFwin=dFoFwin(keep,:); refwin=refwin(keep,:); inpwin=inpwin(keep,:);
ffcond=ffcond(keep); onset_t=onset_t(keep); onset_i=onset_i(keep); trials=trials(keep);
Ntr = sum(keep);

% mode code -> label lookup (for the Python side)
% 2=OL 1=OL+prev 3=CL 0=CL+prev
fprintf('kept %d/%d trials: OL=%d OL+prev=%d CL=%d CL+prev=%d\n', Ntr, numel(keep), ...
    sum(ffcond==2), sum(ffcond==1), sum(ffcond==3), sum(ffcond==0));

mouse = sess.mn; dt_str = sess.td; en = sess.en;
pixel = sess.right.pixel; ref0 = sess.sine.ref0; amp = sess.sine.amp;
hz = sess.sine.hz; dur = sess.sine.dur;

outdir = fullfile('presentation', 'assets');
if ~exist(outdir, 'dir'); outdir = fullfile('..', 'presentation', 'assets'); end
outpath = fullfile(outdir, [TAG '_bundle.mat']);
ffcond = double(ffcond); trials = double(trials);   % avoid integer-class surprises in Python
save(outpath, 'mimg_ds', 'U_ds', 'Vwin', 'dFoFwin', 'refwin', 'inpwin', 'ffcond', ...
     'onset_t', 'onset_i', 'trials', 'pixel', 'ds', 'ref0', 'amp', 'hz', 'dur', ...
     'fs_img', 'n_pre', 'n_win', 'NWIN', 'mouse', 'dt_str', 'en', '-v7');
fprintf('wrote %s  (%d trials, movie %dx%d K=%d)\n', outpath, Ntr, n, n, K);