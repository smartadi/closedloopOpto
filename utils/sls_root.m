function root = sls_root()
% SLS_ROOT  Folder of the Steinmetz Lab style repo (SteinmetzLab/steinmetzlab-style).
%
% The repo is Anna's lab-wide figure and writing style: a Claude Code skill, a Python
% package (steinmetzlab_style) and the data files the MATLAB bridge reads (sls_cmap,
% sls_atlas). It is a separate clone, kept current by the hub's sync.py (REPOS.md row,
% push = pull), never edited from here.
%
% Lookup order:
%   1. environment variable SLS_ROOT, if set
%   2. <projects>/steinmetzlab-style, the sibling of this repo
%
% If it is missing on this PC:
%   cd C:\Users\aditya\Documents\projects
%   gh repo clone SteinmetzLab/steinmetzlab-style

persistent cached
if ~isempty(cached) && isfolder(cached)
    root = cached;
    return
end

cands = {};
env = getenv('SLS_ROOT');
if ~isempty(env)
    cands{end+1} = env;
end
here = fileparts(mfilename('fullpath'));        % .../brain_paper/utils
repo = fileparts(here);                         % .../brain_paper
cands{end+1} = fullfile(fileparts(repo), 'steinmetzlab-style');

for k = 1:numel(cands)
    if isfolder(fullfile(cands{k}, 'src', 'steinmetzlab_style'))
        cached = cands{k};
        root = cached;
        return
    end
end
error('sls_root:missing', ['Steinmetz Lab style repo not found (looked in: %s).\n' ...
    'Clone it next to brain_paper:  gh repo clone SteinmetzLab/steinmetzlab-style\n' ...
    'or set the SLS_ROOT environment variable.'], strjoin(cands, ', '));
end
