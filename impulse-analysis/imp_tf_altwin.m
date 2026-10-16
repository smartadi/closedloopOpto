%% imp_tf_altwin.m -- EXPLORATORY alternative-window impulse TF fit (-0.5..+1.0 s). NOT Fig 2.
%
% Refits the impulse LTI models on a window that includes REAL pre-onset data and the post-dip
% rebound, so they can be compared with the current 0-0.5 s fits (imp_tf_run -> data/imp_tf_fits.mat).
% Uses the same engine (utils/imp_tf_fit_session) through its alternative-window knobs; the Fig-2
% path, its cache and the finals are never written from here.
%
% WHAT CHANGES vs imp_tf_run (and why)
%   preData_s 0.5     the 17 real pre-onset samples replace the synthetic zero lead-in.
%   tFit_s    1.0     the post window now includes the rebound (mostly gone by ~0.77 s).
%   refMode 'premean' each trial referenced to its own -0.5..0 s mean, not the onset frame.
%                     tfest assumes zero initial conditions; that is true on average for a
%                     pre-mean-referenced trial at steady baseline, and the ITI check
%                     (RESEARCH 2026-10-15) says the baseline is steady: the nearest preceding
%                     stim is >= 2.5 s before onset in every session.
%   ALT_OPT           selection/stability settings picked from the config sweep (RESEARCH 2026-10-15).
%
% USAGE
%   load_experiments                     % or ALT_DATA = '<mat with variable A>' for headless runs
%   imp_tf_altwin                        % fits all sessions -> data/imp_tf_fits_win_m0p5_1p0.mat
% Knobs: ALT_SESS (subset of session indices; writes a part file per session, merge with
%        ALT_MERGE = true), ALT_NBOOT (300), ALT_OPT (struct overriding the fit options).

here = fileparts(mfilename('fullpath'));
root = fileparts(here);
addpath(fullfile(root,'utils'));
if ~exist('allExperiments','var') || isempty(allExperiments)
    assert(exist('ALT_DATA','var') && ~isempty(ALT_DATA), '[ALTWIN] run load_experiments.m or set ALT_DATA.');
    L = load(ALT_DATA);  allExperiments = L.A;  clear L
end
if ~exist('ALT_NBOOT','var') || isempty(ALT_NBOOT), ALT_NBOOT = 300; end
if ~exist('ALT_MERGE','var') || isempty(ALT_MERGE), ALT_MERGE = false; end
fs = 35;  tWin = 3.0;
fitFile = fullfile(here,'data','imp_tf_fits_win_m0p5_1p0.mat');
assert(~strcmp(fitFile, fullfile(here,'data','imp_tf_fits.mat')), '[ALTWIN] refusing to touch the Fig-2 cache');

opt = struct('maxPoles',5,'maxZeros',4,'maxDelay',3,'tFit_s',1.0,'per_amp_fit',true, ...
             'verbose',true,'ampRange',[],'nBoot',ALT_NBOOT,'select','aic','minR2h',0.98, ...
             'seedOffset',false,'preData_s',0.5,'refMode','premean','refPre_s',0.5, ...
             'enforceStab',true);
if exist('ALT_OPT','var') && isstruct(ALT_OPT)
    f = fieldnames(ALT_OPT);  for i = 1:numel(f), opt.(f{i}) = ALT_OPT.(f{i}); end
end

nS = numel(allExperiments);
if ALT_MERGE
    Sprim = cell(nS,1);
    for k = 1:nS
        pf = strrep(fitFile, '.mat', sprintf('_part%d.mat', k));
        P = load(pf);  Sprim{k} = P.Sk;  sweepOpt = P.sweepOpt;
    end
    savedOn = now;                                                        %#ok<TNOW1>
    save(fitFile, 'Sprim', 'savedOn', 'sweepOpt', '-v7.3');
    fprintf('[ALTWIN] merged %d parts -> %s\n', nS, fitFile);
    for k = 1:nS, delete(strrep(fitFile, '.mat', sprintf('_part%d.mat', k))); end
    return
end

if ~exist('ALT_SESS','var') || isempty(ALT_SESS), ALT_SESS = 1:nS; end
rng(3,'twister');
sweepOpt = opt;
for k = ALT_SESS
    fprintf('\n[ALTWIN] session %d/%d ...\n', k, nS);
    Sk = imp_tf_fit_session(allExperiments(k), fs, tWin, opt);
    if numel(ALT_SESS) < nS
        save(strrep(fitFile, '.mat', sprintf('_part%d.mat', k)), 'Sk', 'sweepOpt', '-v7.3');
    else
        Sprim{k} = Sk;                                                    %#ok<SAGROW>
    end
end
if numel(ALT_SESS) == nS
    savedOn = now;                                                        %#ok<TNOW1>
    save(fitFile, 'Sprim', 'savedOn', 'sweepOpt', '-v7.3');
    fprintf('[ALTWIN] fits saved -> %s\n', fitFile);
end
