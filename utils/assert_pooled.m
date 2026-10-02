function assert_pooled(n, what, howmany)
% ASSERT_POOLED  Fail loudly when a pooling loop collected nothing.
%
%   assert_pooled(numel(Y), 'f4_error_decomp CL trials')
%   assert_pooled(nSess, 'f4_error_decomp sessions', 2)   % require at least 2
%
% WHY THIS EXISTS (2026-10-02). Twice in one day a figure script ran to completion, printed
% no error, and exported a panel built from ZERO sessions:
%   cl_factor_decomp_panel.m:69  `if ~isfield(dk,'pwcDfk_l'); continue; end`  -> empty panel
%   trial_state_mse.m:61         the same idiom                               -> 0 of 15 passed
% In both cases a field-presence test was being used as a data-availability test, so a schema
% change turned into silent empty output rather than a crash. A pooling loop that collects
% nothing is ALWAYS a bug -- there is no legitimate figure built from no trials -- so it should
% stop, not export. One line per loop buys that.
%
% Prefer this over a bare assert so the message names the loop and states the real cause,
% which is nearly always "every session was skipped by a guard above", not "no data exists".
if nargin < 3 || isempty(howmany), howmany = 1; end
if ~isscalar(n) || ~isnumeric(n) || ~isfinite(n)
    error('assert_pooled:badCount', 'count for "%s" is not a finite scalar', what);
end
if n < howmany
    error('assert_pooled:empty', ...
        ['POOLED NOTHING: %s collected %d (need >= %d). A guard above this point skipped ' ...
         'every session -- check the isfield()/continue tests, not the data. Exporting a ' ...
         'figure from an empty pool is never correct.'], what, n, howmany);
end
end
