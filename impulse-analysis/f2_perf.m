function [M, D, P] = f2_perf(sessIdx, knobs)
%F2_PERF  Show ONE impulse session's predictor performance. The simple entry point.
%
%   f2_perf                 % LIST the sessions with their index numbers
%   f2_perf(3)              % show AL_0033's performance (default = current op-point)
%   f2_perf(1, KNOBS)       % show session 1 with a tuned op-point (see below)
%
% It pops the performance figure (held-out spontaneous fit + R^2 on top, predictor-weight map in the
% middle, per-amp Actual/Global/Local + catch on the bottom) and prints a one-line summary:
%       spont R^2 | capture % | leak % | catch % | shift-null
% Read it as: R^2 high = good prediction; capture near 100 & leak near 0 = clean decomposition;
% |catch| <= 15% = the residual is a real stim effect; shift-null ~0 = genuine zero-lag coupling.
%
% KNOBS (optional struct) to try a different operating point:
%   struct('select_mode','frontier','r2_floor',0.93)      % AL_0048's tuned point (less blind)
%   struct('select_mode','subspace','nu',0.90)            % AL_0041 e1's tuned point (deflation)
% Anything you omit uses the default. Default op-point = frontier, R^2-floor 0.85 (what "current" was).
%
% NEEDS: run `load_experiments` ONCE first (it puts `allExperiments` in the workspace). The FIRST
% call on a session loads its SVD (~30 s); LATER calls on the SAME session reuse a cached design
% (~2 s) so you can flip knobs in a tight loop. Switching sessions replaces the cache; f2_perf('clear')
% frees it.
% -------------------------------------------------------------------------------------------------
here = fileparts(mfilename('fullpath'));
if isempty(here), here = 'C:\Users\aditya\Documents\projects\brain_paper\impulse-analysis'; end
addpath(here); addpath(genpath(fullfile(here,'..','utils')));
dataDir = fullfile(here,'data');

% ONE-session design cache. The SVD load is the only slow part; f2_model refits are ~1 s. Caching the
% last session's P/A lets you flip knobs and re-click WITHOUT reloading -- i.e. tune + investigate in a
% tight loop. Only one session is held at a time (switching sessions replaces it). `f2_perf('clear')`
% frees it.
persistent CK
if nargin>=1 && (ischar(sessIdx) || isstring(sessIdx)) && strcmpi(sessIdx,'clear')
    CK = [];  fprintf('f2_perf: session design cache cleared.\n');  return
end

if evalin('base','~exist(''allExperiments'',''var'')')
    error('f2_perf: run  load_experiments  first (it loads allExperiments).');
end
ae_all = evalin('base','allExperiments');

% ---- no argument: just list the sessions so you know which number is which -----------------------
if nargin < 1 || isempty(sessIdx)
    fprintf('\nSessions (use the number as f2_perf(n)):\n');
    for i = 1:numel(ae_all)
        tag = ''; if isfield(ae_all(i),'site') && ~isempty(ae_all(i).site), tag = sprintf(' [%s]', ae_all(i).site); end
        fprintf('   %d   %s  %s  e%d%s\n', i, ae_all(i).mn, ae_all(i).td, ae_all(i).en, tag);
    end
    fprintf('\ne.g.  f2_perf(3)   or   f2_perf(1, struct(''select_mode'',''subspace'',''nu'',0.90))\n\n');
    return
end
assert(sessIdx>=1 && sessIdx<=numel(ae_all), 'f2_perf: sessIdx must be 1..%d', numel(ae_all));

% ---- default op-point = what "current" was (frontier, floor 0.85) --------------------------------
if nargin < 2 || isempty(knobs), knobs = struct(); end
if ~isfield(knobs,'select_mode'), knobs.select_mode = 'frontier'; end
if ~isfield(knobs,'r2_floor'),    knobs.r2_floor    = 0.85; end
knobs.use_motion = false;   % contra-only (the headline variant)
knobs.verbose    = false;   % silence the ridge/frontier sweep tables -- just show the figure + summary

% ---- load (or reuse cached) design, then refit at the current knobs -----------------------------
if ~isempty(CK) && isequal(CK.idx, sessIdx)
    P = CK.P;  A = CK.A;
    fprintf('[cache] reusing %s design (no reload) — flip knobs / re-click freely\n', P.label);
else
    P = f2_prep(ae_all(sessIdx), struct('dataDir',dataDir,'verbose',true));
    A = f2_affected(P, struct('plot',false));
    CK = struct('idx',sessIdx, 'P',P, 'A',A);
end
M = f2_model(P, A, knobs);
D = f2_decomp(P, M, struct('verbose',false));
f2_fitfig(P, A, M, D, struct());

opline = sprintf('select_mode=%s', knobs.select_mode);
if strcmpi(knobs.select_mode,'frontier'), opline = sprintf('%s, r2_floor=%.2f', opline, knobs.r2_floor); end
if strcmpi(knobs.select_mode,'subspace'),  opline = sprintf('%s, nu=%.2f', opline, local_get(knobs,'nu',0.90)); end
fprintf('\n=====================================================================\n');
fprintf('  %s\n', P.label);
fprintf('  spont R^2 %.3f  |  capture %.0f%%  |  leak %.0f%%  |  catch %+.0f%%  |  shift %.2f\n', ...
        M.r2_spont, D.capMed, D.leakMed, 100*D.catch.ratio, M.r2_shift);
fprintf('  (op-point: %s)\n', opline);
fprintf('=====================================================================\n');
if abs(D.catch.ratio) > 0.15
    fprintf(2,'  ** catch FAILS (|%.0f%%|>15) -> this op-point manufactures residual, do not trust capture **\n', 100*D.catch.ratio);
end
end

function v = local_get(s,f,d)
if isfield(s,f) && ~isempty(s.(f)), v = s.(f); else, v = d; end
end
