function ctrl_mpc_supp_montage()
%CTRL_MPC_SUPP_MONTAGE  Draft layout preview of the supplementary MPC figure (user selection 2026-10-07).
%   Rough PNG assembly for reviewing story/order only; final assembly is in Illustrator.
%   HELD (not in the figure): mpc_F_smooth_tradeoff, mpc_N_lambda_roughness, mpc_J_kalman_bias_noise.
% OUT  paper/images/supp_mpc/_draft_supp_mpc_layout.png
here = fileparts(mfilename('fullpath')); d = fullfile(here,'..','paper','images','supp_mpc');
rows = { {'mpc_0_problem','mpc_A_plant_fit'}, ...
         {'f3s_A_single_trial','f3s_B_trial_average'}, ...
         {'f3s_C_stimulation','f3s_D_variance','f3s_E_rmse_violin'}, ...
         {'f3s_F_variance_ratio','f3s_G_rmse_ratio','mpc_E_preview_window'}, ...
         {'mpc_H_forecast_skill_models','mpc_I_mpc_by_forecaster'}, ...
         {'mpc_K_uncertainty_sweep','mpc_L_uncertainty_common_axis','mpc_M_lambda_error'} };
W = 3000; gap = 30; out = {}; k = 0; lab = 'a':'z';
for r = 1:numel(rows)
    ims = cellfun(@(n) imread(fullfile(d,[n '.png'])), rows{r}, 'uni', 0);
    ims = cellfun(@(I) toRGB(I), ims, 'uni', 0);
    h = 600; ims = cellfun(@(I) imresize(I, [h NaN]), ims, 'uni', 0);
    tot = sum(cellfun(@(I) size(I,2), ims)) + gap*(numel(ims)-1);
    if tot > W, s = (W - gap*(numel(ims)-1)) / (tot - gap*(numel(ims)-1)); ims = cellfun(@(I) imresize(I, s), ims, 'uni', 0); end
    h = max(cellfun(@(I) size(I,1), ims)); row = 255*ones(h+gap, W, 3, 'uint8'); x = 1;
    for i = 1:numel(ims)
        I = ims{i}; k = k+1;
        I = insertText(I, [5 5], lab(k), 'FontSize', 48, 'BoxOpacity', 0, 'Font', 'Arial Bold');
        row(1:size(I,1), x:x+size(I,2)-1, :) = I; x = x + size(I,2) + gap;
    end
    out{end+1} = row(:, 1:W, :); %#ok<AGROW>   % imresize rounding can overrun W by a pixel or two
end
imwrite(cat(1, out{:}), fullfile(d, '_draft_supp_mpc_layout.png'));
fprintf('[MONT] %d panels -> _draft_supp_mpc_layout.png\n', k);
end
function I = toRGB(I)
if size(I,3) == 1, I = repmat(I,[1 1 3]); end
if ~isa(I,'uint8'), I = im2uint8(I); end
end
