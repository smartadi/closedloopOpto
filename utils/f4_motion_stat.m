function S = f4_motion_stat(varargin)
% F4_MOTION_STAT  The ONE Fig-4 per-trial motion statistic.
%
%   x = f4_motion_stat(seg)                   % ONE condition -> column vector
%   x = f4_motion_stat(seg, 'sq')
%   S = f4_motion_stat(segOL, segCL)          % TWO conditions -> {OL, CL}
%   S = f4_motion_stat(segOL, segCL, 'sq')
%
% Each seg is a trials-by-samples slice of the z-scored motion trace, already cut to the
% motion window. Used by EVERY Fig-4 motion site, Row 1 and Row 2:
%   Row 2  utils/f4_row2_pool.m, controller-analysis/f4_row2_quartiles.m   (two-arg)
%   Row 1  f4_error_decomp.m, cl_rmse_factor_windows.m, cl_factor_decomp_panel.m,
%          f4_state_exemplars.m, f4_state_exemplars_supp.m                (one-arg)
% Row 2's two copies DIVERGED on 2026-10-01 -- the pool was switched to the mean square
% and the duplicated panel block was not, so the bars binned trials by one ordering while
% the star printed above them tested another (59.2 % of trials changed quartile). Row 1
% then sat on the mean square while Row 2 was reverted, so one figure defined motion two
% ways. Reconciled 2026-10-02 (user): one function, one statistic, and the WINDOW was
% already identical -- Row 1 computes it per session from params.dur and Row 2 hardcodes
% dur=3, but all 15 sessions are dur=3 with 176 motion columns, so both are cols 1:175
% (-2.000 to +2.971 s). Verified session by session, not assumed.
%
% PRIMARY = mean(z) (user, 2026-10-02), retracting the 2026-10-01 mean(z^2). The trace
% is the z-scored motion ENERGY (initialize_data.m: motEng = sum((frame-last).^2);
% min 237345, 0.00 % negative on AL_0033 2025-02-12/2), so averaging its z-score within
% a trial gives mean_win(z) = (mean_win(E) - mu_sess)/sigma_sess -- exactly MONOTONE in
% that trial's mean energy. mean(z^2) is a second moment, minimised when the trial sits
% AT the session mean, so it scores unusually STILL trials as high as active ones; the
% two order trials at only rho = 0.303. See RESEARCH 2026-10-02.
% ---- parse: trailing char is the statistic; 1 or 2 numeric segments ----------------------
segs = varargin;  motstat = 'mean';
if ~isempty(segs) && (ischar(segs{end}) || isstring(segs{end}))
    motstat = char(segs{end});  segs(end) = [];
end
assert(numel(segs) == 1 || numel(segs) == 2, ...
    'f4_motion_stat: expected one or two motion segments, got %d', numel(segs));
switch validatestring(lower(motstat), {'mean','sq'}, mfilename, 'motstat')
    case 'sq',  f = @(g) mean(g.^2, 2);   % SECONDARY
    otherwise,  f = @(g) mean(g,    2);   % PRIMARY
end
if numel(segs) == 1, S = f(segs{1});                    % one condition -> vector
else,                S = {f(segs{1}), f(segs{2})};      % two conditions -> {OL, CL}
end
end
