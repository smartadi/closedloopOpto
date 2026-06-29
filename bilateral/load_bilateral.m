% bilateral/load_bilateral.m
% Loads and caches sessions for AL_0048 bilateral dual-opsin experiments.
% Run from brain_paper/ root directory.
% After this runs, all downstream scripts consume the `sessions` struct.
%
% Each session produces sess.trial_meta — a struct array (one entry per trial):
%   .trial_idx   — index into d.stimStarts
%   .side        — 'left' | 'right' | 'unknown'
%   .stim_type   — 'impulse' | 'step' | 'cl_const' | 'cl_tune' | 'sinewave' | 'unknown'
%   .amplitude   — numeric amplitude value from input_params
%
% Downstream scripts filter trial_meta instead of checking sess.exp_type.

%% Workspace
clc; close all; clear all;

if ~isfolder('bilateral') && isfolder(fullfile('..', 'bilateral'))
    cd('..');
end
addpath(genpath('utils'));

%% ---- Switchable top-level knobs ----------------------------------------
STIM_MODE    = 'A';   % 'A' = input_params timestamps | 'B' = timeline trace | 'C' = both

% input_params column map (confirmed from explore.m on 2026-06-06):
%   col 1: trial_idx
%   col 2: kk_start
%   col 3: trial_type    ← stim type code
%   col 4: hemisphere    ← +1 = left (excitatory), -1 = right (inhibitory) — verify sign
%   col 5: amplitude
%   col 6: trial_dur
%   col 7: iti
%   col 8: galvo_x_mm   ← bregma X, cross-check for hemisphere
%   col 9: galvo_y_mm
HEMISPHERE_COL = 4;   % use hemisphere col directly for side assignment
GALVO_X_COL    = 8;   % galvo_x_mm — cross-check / future use
STIM_TYPE_COL  = 3;   % trial_type numeric code
AMP_COL        = 5;   % amplitude

% Stim type code map — fill in once trial_type codes are confirmed from data:
STIM_TYPE_MAP = containers.Map('KeyType','char','ValueType','double');
% STIM_TYPE_MAP('impulse')  = <code>;
% STIM_TYPE_MAP('step')     = <code>;
% STIM_TYPE_MAP('cl_const') = <code>;
% STIM_TYPE_MAP('cl_tune')  = <code>;
% STIM_TYPE_MAP('sinewave') = <code>;

SIGN_L     = +1;      % polarity: left hemisphere (excitatory) — flip to -1 if inverted
SIGN_R     = -1;      % polarity: right hemisphere (inhibitory) — flip to +1 if inverted
REF_L      = +5;      % default reference level, left side (% dF/F)
REF_R      = -5;      % default reference level, right side (% dF/F)
r_bil      = 1;       % 1 = load cache | 0 = recompute and overwrite
% -------------------------------------------------------------------------

%% ---- Session registry --------------------------------------------------
% Columns: mouse name, date (YYYY-MM-DD), experiment number, trial count,
%          pixel_L [row col], pixel_R [row col]
%
% exp_type is NO LONGER a session-level field — it is read per-trial from
% input_params via STIM_TYPE_COL. Leave pixel_L / pixel_R as [NaN NaN]
% until confirmed from SVD frame inspection.

sessions_def = {
%   mn          td             en  trials   pixel_L      pixel_R
  'AL_0048', '2026-06-05',    2,  100,   [NaN NaN],   [NaN NaN];
};
% -------------------------------------------------------------------------

%% ---- Load / cache loop -------------------------------------------------
nSess = size(sessions_def, 1);
sessions = struct();

for k = 1:nSess
    mn      = sessions_def{k,1};
    td      = sessions_def{k,2};
    en      = sessions_def{k,3};
    nTrials = sessions_def{k,4};
    pix_L   = sessions_def{k,5};
    pix_R   = sessions_def{k,6};

    tag       = sprintf('s%d', k);
    cachePath = fullfile('data', sprintf('%s_bil_%s%s%d.mat', mn, td(6:7), td(9:10), en));

    try
        if exist(cachePath, 'file') && r_bil == 1
            tmp = load(cachePath);
            sessions.(tag) = tmp.sess;
            fprintf('Loaded cache: %s\n', tag);
        else
            d = initialize_data(mn, en, td);

            %% Stim detection
            switch STIM_MODE
                case 'A'
                    fprintf('[%s] Stim mode A: using initialize_data default\n', tag);

                case 'B'
                    % Threshold-crossing on timeline input trace.
                    % TODO: implement once timeline column is known.
                    %   thresh  = 0.5;
                    %   inp_col = NaN;
                    %   d = findStims_timeline(d, inp_col, thresh);
                    error('STIM_MODE B not yet implemented.');

                case 'C'
                    error('STIM_MODE C not yet implemented.');
            end

            nStims = length(d.stimStarts);

            %% Build trial_meta from input_params
            trial_meta(nStims) = struct('trial_idx', 0, 'side', '', ...
                                        'stim_type', '', 'amplitude', NaN);

            for j = 1:nStims
                trial_meta(j).trial_idx = j;

                % --- Side from hemisphere column (col 4); galvo_x_mm (col 8) as cross-check ---
                hemi = d.input_params(j, HEMISPHERE_COL);
                if hemi * SIGN_L > 0
                    trial_meta(j).side = 'left';
                elseif hemi * SIGN_L < 0
                    trial_meta(j).side = 'right';
                else
                    trial_meta(j).side = 'unknown';
                end

                % --- Stim type from trial_type column ---
                if isempty(STIM_TYPE_MAP)
                    trial_meta(j).stim_type = 'unknown';
                else
                    code = d.input_params(j, STIM_TYPE_COL);
                    type_keys = keys(STIM_TYPE_MAP);
                    matched = '';
                    for ki = 1:length(type_keys)
                        if STIM_TYPE_MAP(type_keys{ki}) == code
                            matched = type_keys{ki};
                            break;
                        end
                    end
                    trial_meta(j).stim_type = matched;
                    if isempty(matched)
                        trial_meta(j).stim_type = sprintf('code_%d', code);
                    end
                end

                % --- Amplitude ---
                trial_meta(j).amplitude = d.input_params(j, AMP_COL);
            end

            %% Per-side pixel dF/F (loaded once per side if pixel known)
            left_trials  = find(strcmp({trial_meta.side}, 'left'));
            right_trials = find(strcmp({trial_meta.side}, 'right'));

            sess.mn         = mn;
            sess.td         = td;
            sess.en         = en;
            sess.nTrials    = nTrials;
            sess.d          = d;
            sess.stim_mode  = STIM_MODE;
            sess.trial_meta = trial_meta;

            if ~isempty(left_trials) && ~any(isnan(pix_L))
                dFoF_L    = getpixel_dFoF(d, 0, pix_L, 1);
                sess.left = struct('dFoF', dFoF_L, 'ref', REF_L * SIGN_L, ...
                                   'pixel', pix_L, 'opsin', 'excitatory');
            else
                sess.left = struct('dFoF', [], 'ref', REF_L * SIGN_L, ...
                                   'pixel', pix_L, 'opsin', 'excitatory');
            end

            if ~isempty(right_trials) && ~any(isnan(pix_R))
                dFoF_R     = getpixel_dFoF(d, 0, pix_R, 1);
                sess.right = struct('dFoF', dFoF_R, 'ref', REF_R * SIGN_R, ...
                                    'pixel', pix_R, 'opsin', 'inhibitory');
            else
                sess.right = struct('dFoF', [], 'ref', REF_R * SIGN_R, ...
                                    'pixel', pix_R, 'opsin', 'inhibitory');
            end

            %% Print trial_meta summary
            types_found = unique({trial_meta.stim_type});
            sides_found = unique({trial_meta.side});
            amps_found  = unique([trial_meta.amplitude]);
            fprintf('[%s] %d trials | sides: %s | types: %s | amps: %s\n', ...
                tag, nStims, strjoin(sides_found,','), strjoin(types_found,','), ...
                mat2str(amps_found));

            if ~exist('data', 'dir'); mkdir('data'); end
            save(cachePath, 'sess', '-v7.3');
            sessions.(tag) = sess;
            fprintf('Saved cache: %s\n', tag);
        end

    catch ME
        fprintf('Skipping %s: %s\n', tag, ME.message);
        sessions.(tag).skip = true;
    end
end

fprintf('\nload_bilateral.m complete — %d session(s) loaded.\n', nSess);
fprintf('Downstream scripts: ol_characterization.m, cl_constant_ref.m, cl_tuning.m, cl_sinewave.m\n');
