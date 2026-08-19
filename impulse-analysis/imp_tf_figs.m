%% imp_tf_figs.m -- REDRAW the TF panels from fits that already exist. NO refitting.
%
% =====================================================================================
% WHY THIS IS A SEPARATE SCRIPT
% =====================================================================================
% `imp_tf_run` does two jobs that have wildly different costs: it FITS (slow -- an order
% sweep plus a 300-draw trial bootstrap per session, on top of load_experiments reading
% SVDs off the lab share) and it DRAWS (instant). Every formatting change was therefore
% paying the fitting cost again, which is both slow and, worse, a reason not to iterate
% on the figure at all.
%
% This script does the drawing job only. It takes the fits from wherever they already
% are -- the live workspace, or the on-disk cache `imp_tf_run` now writes -- and emits
% the panels. Change a colour, re-run this, done.
%
% USAGE
%   imp_tf_figs                        % after imp_tf_run, or in a fresh session
%
% Knobs (set before running; all optional):
%   FIG_PANELS   which panels to emit                 [default {'shape','swap','tau','poles'}]
%                'shape' 2C-i normalised measured-vs-fit overlay
%                'swap'  TF-D cross-session model-swap grid
%                'tau'   TF-A tau_slow forest with bootstrap CI
%                'poles' TF-E every time constant, log axis   <- new 2026-08-10
%                'var'   TF-B between/within SD bars     (off by default)
%                'amp'   TF-C tau vs drive              (off by default)
%   FIG_EXPORT   write the PDFs                                        [default true]
%   FIG_SRC      explicit fits: a cell array of imp_tf_fit_session outputs [default auto]
%
% SESSION ORDER IS THE COLOUR KEY. Panels label sessions "Session 1..n" (user,
% 2026-08-10) and colour them on the blue ramp by that index, so the index must mean the
% same thing in every panel. It is simply the order of the fits in the cell array, which
% is the order `load_experiments` registered them. This script PRINTS the mapping every
% time -- that table is what the caption has to carry, and it is the one thing that
% cannot be recovered from the PDFs.
% =====================================================================================

here = fileparts(mfilename('fullpath'));
root = fileparts(here);
addpath(fullfile(root,'utils'));
outDir   = fullfile(root,'paper','images','figure2');
cacheFil = fullfile(here,'data','imp_tf_fits.mat');

if ~exist('FIG_PANELS','var') || isempty(FIG_PANELS)
    FIG_PANELS = {'shape','swap','tau','poles'};
end
if ~exist('FIG_EXPORT','var') || isempty(FIG_EXPORT), FIG_EXPORT = true; end
want = @(c) any(strcmpi(FIG_PANELS, c));

%% ---- (1) find the fits, in order of freshness -------------------------------------------
% Explicit > live workspace > disk. Which one was used is stated, never inferred: redrawing
% a stale cache while believing you are looking at this morning's fit is the failure mode
% this whole script could otherwise introduce.
if exist('FIG_SRC','var') && ~isempty(FIG_SRC)
    Sfit = FIG_SRC;                                   srcTag = 'FIG_SRC (explicit)';
elseif exist('TFRUN','var') && isstruct(TFRUN) && isfield(TFRUN,'Sprim')
    Sfit = TFRUN.Sprim;                               srcTag = 'TFRUN.Sprim (live workspace)';
elseif exist('Sprim','var') && iscell(Sprim)
    Sfit = Sprim;                                     srcTag = 'Sprim (live workspace)';
elseif exist(cacheFil,'file')
    L = load(cacheFil);
    assert(isfield(L,'Sprim'), '[TFFIGS] %s has no Sprim.', cacheFil);
    Sfit = L.Sprim;
    srcTag = sprintf('%s (saved %s)', cacheFil, datestr(L.savedOn));    %#ok<DATST>
else
    error(['[TFFIGS] no fits found.\n' ...
           '  Looked for: FIG_SRC, TFRUN.Sprim, Sprim, and\n  %s\n' ...
           '  Run load_experiments -> imp_tf_run once; it now writes that cache, and\n' ...
           '  every later formatting pass can come straight here.'], cacheFil);
end
fprintf('[TFFIGS] fits from %s\n', srcTag);

okF  = cellfun(@(s) isstruct(s) && isfield(s,'ok') && s.ok, Sfit);
Sfit = Sfit(okF);
n    = numel(Sfit);
assert(n >= 1, '[TFFIGS] no session in the source produced a usable fit.');

%% ---- (2) the index -> session mapping the caption needs ----------------------------------
fprintf('\n=================== [TFFIGS] SESSION INDEX (this IS the colour key) ===================\n');
fprintf('%-10s %-26s %-9s %8s %8s %8s\n','panel','session','order','tau_slow','R2h','R2pool');
for k = 1:n
    s = Sfit{k};
    r2h = NaN;  if isfield(s,'R2_h'), r2h = s.R2_h; end
    t1  = NaN;  if isfield(s,'tau') && ~isempty(s.tau), t1 = s.tau(1); end
    fprintf('Session %-2d %-26s %2dp%dz%dd %8.3f %8.3f %8.3f\n', ...
        k, s.label, s.np, s.nz, s.nd, t1, r2h, s.R2_pool);
end
np = cellfun(@(s) s.np, Sfit);
fprintf('---------------------------------------------------------------------------------------\n');
fprintf('model orders learned: np = %s | nz = %s | delay(samples) = %s\n', ...
    mat2str(np), mat2str(cellfun(@(s) s.nz, Sfit)), mat2str(cellfun(@(s) s.nd, Sfit)));
if numel(unique(np)) > 1
    fprintf(2,['NOTE: order is NOT shared across sessions. The text must say "2-4 poles"\n' ...
               '      (or whatever the range is), not "a 3-pole model".\n']);
end

%% ---- (3) draw ---------------------------------------------------------------------------
FIGS = struct();
if want('shape')
    FIGS.shape = imp_tf_paper_fig(Sfit, outDir, ...
        struct('tag','','export',FIG_EXPORT,'tmax_s',0.5));
end
rbPanels = {};
if want('tau'), rbPanels{end+1} = 'A'; end
if want('var'), rbPanels{end+1} = 'B'; end
if want('amp'), rbPanels{end+1} = 'C'; end
if want('swap'), rbPanels{end+1} = 'D'; end
if ~isempty(rbPanels)
    FIGS.robust = imp_tf_robust_fig(Sfit, outDir, ...
        struct('tag','','export',FIG_EXPORT,'amp_norm',true,'panels',{rbPanels}));
end
if want('poles')
    FIGS.poles = imp_tf_poles_fig(Sfit, outDir, struct('tag','','export',FIG_EXPORT));
end

fprintf('\n[TFFIGS] %d panel group(s) drawn -> %s\n', numel(fieldnames(FIGS)), outDir);
