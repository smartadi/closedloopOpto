% export_xsession_stats.m — lightweight cross-session summary for the talk video.
%
% Partial-loads ONLY the small `data` struct from each of the 13 controller
% caches (the SVD movie is never touched), and computes the per-session
% quantities behind Figure 3: per-trial tracking RMSE and across-trial variance,
% OL vs CL, split by window (pre / stim / post).
%
% RMSE is recomputed from the traces (sqrt(mean((y-ref)^2)) over the stim
% window) rather than read from er_*Dfk, because older caches store an
% UN-NORMALISED L2 (= RMSE*sqrt(N)); see RESEARCH.md 2026-07-24.
%
% Writes presentation/assets/xsession_stats.mat (v7, a few kB).
% Usage (from brain_paper/):  run('presentation/export_xsession_stats.m')

REF = -5; DUR = 3; FS = 35; PRE = 35;

% Resolve the repo root from THIS script's location. (run() sets cwd to the
% script folder, and exist(name,'dir') searches the MATLAB path, so neither
% cwd nor exist() can be trusted here.)
ROOT = fileparts(fileparts(mfilename('fullpath')));
if ~exist(fullfile(ROOT, 'data'), 'dir')
    error('cannot locate %s', fullfile(ROOT, 'data'));
end

S(1).key='m1';  S(1).mn='AL_0033'; S(1).td='2025-01-20'; S(1).en=3;
S(2).key='m2';  S(2).mn='AL_0033'; S(2).td='2025-02-12'; S(2).en=2;
S(3).key='m3';  S(3).mn='AL_0033'; S(3).td='2025-02-24'; S(3).en=2;
S(4).key='m4';  S(4).mn='AL_0033'; S(4).td='2025-02-26'; S(4).en=2;
S(5).key='m5';  S(5).mn='AL_0033'; S(5).td='2025-03-04'; S(5).en=1;
S(6).key='m6';  S(6).mn='AL_0033'; S(6).td='2025-03-05'; S(6).en=2;
S(7).key='m7';  S(7).mn='AL_0033'; S(7).td='2025-03-20'; S(7).en=4;
S(8).key='m8';  S(8).mn='AL_0033'; S(8).td='2025-04-15'; S(8).en=2;
S(9).key='m9';  S(9).mn='AL_0039'; S(9).td='2025-04-20'; S(9).en=1;
S(10).key='m10';S(10).mn='AL_0039';S(10).td='2025-04-19';S(10).en=1;
S(11).key='m11';S(11).mn='AL_0039';S(11).td='2025-04-30';S(11).en=3;
S(12).key='m12';S(12).mn='AL_0033';S(12).td='2025-04-19';S(12).en=1;
S(13).key='m13';S(13).mn='AL_0039';S(13).td='2025-04-20';S(13).en=2;

n = numel(S);
rmse_ol = nan(n,1); rmse_cl = nan(n,1);
var_ol  = nan(n,1); var_cl  = nan(n,1);
var_ol_pre = nan(n,1); var_cl_pre = nan(n,1);
var_ol_post= nan(n,1); var_cl_post= nan(n,1);
nOL = nan(n,1); nCL = nan(n,1);
keys = cell(n,1); mice = cell(n,1);

for k = 1:n
    td = S(k).td;
    f = fullfile(ROOT, 'data', sprintf('%sctrl%s%s%d.mat', S(k).mn, td(6:7), td(9:10), S(k).en));
    if ~exist(f, 'file'); fprintf('MISSING %s\n', f); continue; end
    L = load(f, 'data');  d = L.data;  clear L;      % small struct only

    Yo = d.ncDfk; Yc = d.wcDfk;                       % [trial x time]
    nt = size(Yo, 2);
    t  = ((0:nt-1) - PRE) / FS;
    stim = t >= 0 & t <= DUR;
    pre  = t < 0;
    post = t > DUR;

    rmse_ol(k) = mean(sqrt(mean((Yo(:,stim) - REF).^2, 2)));
    rmse_cl(k) = mean(sqrt(mean((Yc(:,stim) - REF).^2, 2)));
    var_ol(k)  = mean(var(Yo(:,stim), 0, 1));
    var_cl(k)  = mean(var(Yc(:,stim), 0, 1));
    var_ol_pre(k)  = mean(var(Yo(:,pre), 0, 1));
    var_cl_pre(k)  = mean(var(Yc(:,pre), 0, 1));
    if any(post)
        var_ol_post(k) = mean(var(Yo(:,post), 0, 1));
        var_cl_post(k) = mean(var(Yc(:,post), 0, 1));
    end
    nOL(k) = size(Yo,1); nCL(k) = size(Yc,1);
    keys{k} = S(k).key; mice{k} = S(k).mn;
    fprintf('%-4s %s  OL n=%3d rmse %.2f var %.2f | CL n=%3d rmse %.2f var %.2f\n', ...
        S(k).key, S(k).mn, nOL(k), rmse_ol(k), var_ol(k), nCL(k), rmse_cl(k), var_cl(k));
end

ok = ~isnan(rmse_ol);
fprintf('\n=== %d sessions, %d mice ===\n', sum(ok), numel(unique(mice(ok))));
fprintf('RMSE  : OL %.2f -> CL %.2f  (median per-session drop %.0f%%)\n', ...
    mean(rmse_ol(ok)), mean(rmse_cl(ok)), 100*median(1 - rmse_cl(ok)./rmse_ol(ok)));
fprintf('VAR   : OL %.2f -> CL %.2f  (median OL/CL ratio %.2f)\n', ...
    mean(var_ol(ok)), mean(var_cl(ok)), median(var_ol(ok)./var_cl(ok)));
fprintf('VAR ratio by window: pre %.2f | stim %.2f | post %.2f\n', ...
    median(var_ol_pre(ok)./var_cl_pre(ok)), median(var_ol(ok)./var_cl(ok)), ...
    median(var_ol_post(ok)./var_cl_post(ok), 'omitnan'));
try
    p_r = signrank(rmse_ol(ok), rmse_cl(ok));
    p_v = signrank(var_ol(ok),  var_cl(ok));
    fprintf('signed-rank: RMSE p=%.4g | variance p=%.4g\n', p_r, p_v);
catch
    p_r = NaN; p_v = NaN;
end

out = fullfile(ROOT, 'presentation', 'assets', 'xsession_stats.mat');
save(out, 'keys','mice','rmse_ol','rmse_cl','var_ol','var_cl', ...
     'var_ol_pre','var_cl_pre','var_ol_post','var_cl_post','nOL','nCL', ...
     'p_r','p_v','REF','DUR','-v7');
fprintf('wrote %s\n', out);
