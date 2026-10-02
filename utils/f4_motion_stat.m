function S = f4_motion_stat(segOL, segCL, motstat)
% F4_MOTION_STAT  The ONE Fig-4 per-trial motion statistic. Returns {OL, CL}.
%
%   S = f4_motion_stat(segOL, segCL)          % 'mean', the primary
%   S = f4_motion_stat(segOL, segCL, 'sq')    % mean square, the secondary
%
% segOL/segCL are trials-by-samples slices of the z-scored motion trace, already cut
% to the motion window. Shared by utils/f4_row2_pool.m (forest + panel stars) and
% controller-analysis/f4_row2_quartiles.m (the quartile bars), which carry duplicated
% pooling code and DIVERGED on 2026-10-01 -- the pool was switched to the mean square
% and the panel copy was not, so the bars binned trials by one ordering while the star
% printed above them tested another (59.2 % of trials changed quartile). One function
% now, so that cannot recur.
%
% PRIMARY = mean(z) (user, 2026-10-02), retracting the 2026-10-01 mean(z^2). The trace
% is the z-scored motion ENERGY (initialize_data.m: motEng = sum((frame-last).^2);
% min 237345, 0.00 % negative on AL_0033 2025-02-12/2), so averaging its z-score within
% a trial gives mean_win(z) = (mean_win(E) - mu_sess)/sigma_sess -- exactly MONOTONE in
% that trial's mean energy. mean(z^2) is a second moment, minimised when the trial sits
% AT the session mean, so it scores unusually STILL trials as high as active ones; the
% two order trials at only rho = 0.303. See RESEARCH 2026-10-02.
if nargin < 3 || isempty(motstat), motstat = 'mean'; end
switch validatestring(lower(motstat), {'mean','sq'}, mfilename, 'motstat')
    case 'sq',  S = {mean(segOL.^2, 2), mean(segCL.^2, 2)};   % SECONDARY
    otherwise,  S = {mean(segOL,    2), mean(segCL,    2)};   % PRIMARY
end
end
