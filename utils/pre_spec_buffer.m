function [P, c0p, nm] = pre_spec_buffer(dk, cond)
% PRE_SPEC_BUFFER  Resolve the long pre-stimulus buffer used for Fig-4 spectral states.
%
%   [P, c0p, nm] = pre_spec_buffer(dk, 'wc')   % closed loop
%   [P, c0p, nm] = pre_spec_buffer(dk, 'nc')   % open loop
%
% Returns the trials-by-samples buffer P, its ONSET COLUMN c0p, and the field name used.
% Callers keep their own `c0p - round(pre*Fs) : c0p + round(post*Fs)` arithmetic, so the
% window in SECONDS is identical whichever buffer is present.
%
% WHY THIS EXISTS (2026-10-02). controllerData/load_sessions used to store a short
% `p<cond>Dfk_l` with onset at column 106; current caches store the long `p<cond>Dfk`,
% 561 columns, onset at column 351. utils/f4_row2_pool.m and controller-analysis/
% f4_row2_quartiles.m already fall back between the two. The five Fig-4 ROW-1 scripts did
% NOT, and NO cache in data/ still carries a `_l` buffer (checked all 15), so they were all
% dead on the current cache set:
%   f4_error_decomp.m, cl_rmse_factor_windows.m, f4_state_exemplars.m,
%   f4_state_exemplars_supp.m   -> errored "Unrecognized field name pwcDfk_l"
%   cl_factor_decomp_panel.m    -> WORSE: `continue`d past every session, so it produced an
%                                  empty panel with no error at all.
% This resolver ERRORS when neither buffer exists rather than skipping or clamping, so a
% missing buffer can never again be mistaken for "no data".
arguments
    dk   struct
    cond {mustBeMember(cond,{'wc','nc'})}
end
short = sprintf('p%sDfk_l', cond);     % legacy, onset col 106
long  = sprintf('p%sDfk',   cond);     % current, onset col 351
if isfield(dk, short) && ~isempty(dk.(short))
    P = dk.(short); c0p = 106; nm = short;
elseif isfield(dk, long) && ~isempty(dk.(long))
    P = dk.(long);  c0p = 351; nm = long;
else
    error('pre_spec_buffer:missing', ...
        'neither %s nor %s is present/non-empty in this session''s data struct', short, long);
end
assert(c0p >= 1 && c0p <= size(P,2), 'pre_spec_buffer:badOnset', ...
    'onset col %d outside %s (%d cols)', c0p, nm, size(P,2));
end
