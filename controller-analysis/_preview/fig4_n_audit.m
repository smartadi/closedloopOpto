% fig4_n_audit.m -- READ-ONLY audit of every Fig-4 pool gate, per session.
% Loads ONLY `data` from each cache (12 MB each) + d.motion via h5read, so no SVD.
% Answers: which sessions enter panel C (decomp), panel D (row-2 LMM), and why 7 vs 8.
% Writes nothing except a .mat of the table into the scratchpad.

root = 'C:\Users\aditya\Documents\projects\brain_paper';
cd(root); addpath(genpath('utils'));

% --- registry, transcribed from controller-analysis/load_sessions.m (m1-m15) ---
R = { 'AL_0033','2025-01-20',3,120; 'AL_0033','2025-02-12',2,200; ...
      'AL_0033','2025-02-24',2,200; 'AL_0033','2025-02-26',2,200; ...
      'AL_0033','2025-03-04',1, 60; 'AL_0033','2025-03-05',2, 30; ...
      'AL_0033','2025-03-20',4,100; 'AL_0033','2025-04-15',2, 60; ...
      'AL_0039','2025-04-20',1,100; 'AL_0039','2025-04-19',1,100; ...
      'AL_0039','2025-04-30',3,100; 'AL_0033','2025-04-19',1,100; ...
      'AL_0039','2025-04-20',2,100; 'AL_0048','2026-07-29',2,100; ...
      'AL_0051','2026-07-29',2,100 };

nS = size(R,1);
mouse = struct(); fields = cell(nS,1);
A = table('Size',[nS 12], ...
    'VariableTypes',{'string','string','double','logical','double','double','logical','logical','logical','double','double','string'}, ...
    'VariableNames',{'id','mn','trials','hasCache','nOL','nCL','has_motion','has_pwc_l','has_pwc','nCL_fin','nOL_fin','note'});

fprintf('\n%-5s %-8s %-11s %6s %5s %5s %4s %6s %5s  %s\n', ...
        'id','mouse','date','cache','nOL','nCL','mot','pwc_l','pwc','note');
fprintf('%s\n', repmat('-',1,86));

for k = 1:nS
    mn = R{k,1}; td = R{k,2}; en = R{k,3};
    f = sprintf('m%d',k); fields{k} = f;
    p = fullfile(root,'data', sprintf('%sctrl%s%s%d.mat', mn, td(6:7), td(9:10), en));
    A.id(k) = f; A.mn(k) = mn; A.trials(k) = R{k,4};
    A.hasCache(k) = exist(p,'file')==2;
    note = "";
    if ~A.hasCache(k)
        A.note(k) = "NO CACHE";
        fprintf('%-5s %-8s %-11s %6s\n', f, mn, td, 'MISSING'); continue
    end

    S = load(p,'data'); d = S.data; clear S

    % motion: read d.motion straight out of the HDF5 without loading d
    hm = false;
    try
        mo = h5read(p,'/d/motion'); hm = any(mo(:)~=0);
    catch ME
        note = note + "h5read d/motion failed: " + string(ME.identifier) + "; ";
        if isfield(d,'ncmotion'); hm = any(d.ncmotion(:)~=0); end
    end

    A.has_motion(k) = hm;
    A.has_pwc_l(k)  = isfield(d,'pwcDfk_l') && ~isempty(d.pwcDfk_l);
    A.has_pwc(k)    = isfield(d,'pwcDfk')   && ~isempty(d.pwcDfk);
    if isfield(d,'ncDfk'); A.nOL(k) = size(d.ncDfk,1); end
    if isfield(d,'wcDfk'); A.nCL(k) = size(d.wcDfk,1); end

    % build the mouse struct f4_row2_pool expects
    mouse.(f).mn = mn; mouse.(f).td = td; mouse.(f).en = en;
    mouse.(f).data = d; mouse.(f).has_motion = hm;
    mouse.(f).d = struct('ref',-5,'has_motion',hm,'params',struct('dur',3));

    A.note(k) = note;
    fprintf('%-5s %-8s %-11s %6d %5d %5d %4d %6d %5d  %s\n', ...
        f, mn, td, A.hasCache(k), A.nOL(k), A.nCL(k), hm, A.has_pwc_l(k), A.has_pwc(k), note);
end

%% ---- GATE 1: panel C (f4_error_decomp.m) ------------------------------------
% Its loop: skip unless has_motion AND wcmotion present; then INDEXES dk.pwcDfk_l
fprintf('\n=== PANEL C gate (f4_error_decomp.m) ===\n');
gC = false(nS,1);
for k = 1:nS
    if ~A.hasCache(k); continue; end
    d = mouse.(fields{k}).data;
    pass = A.has_motion(k) && isfield(d,'wcmotion');
    why = '';
    if ~A.has_motion(k); why = 'no motion';
    elseif ~isfield(d,'wcmotion'); why = 'no wcmotion field';
    elseif ~A.has_pwc_l(k); why = 'LACKS pwcDfk_l -> script would ERROR/skip'; pass = false;
    end
    gC(k) = pass;
    fprintf('  %-5s %-8s  %s  %s\n', fields{k}, A.mn(k), string(pass), why);
end
fprintf('  -> panel C sessions: %d  (%s)\n', nnz(gC), strjoin(cellstr(A.id(gC))',','));

%% ---- GATE 2: panel D (utils/f4_row2_pool.m) --------------------------------
fprintf('\n=== PANEL D pool (utils/f4_row2_pool.m) ===\n');
[POOL, ~] = f4_row2_pool(mouse, fields);
st = fieldnames(POOL);
fprintf('\n%-10s %8s %8s %6s   %s\n','state','nTrials','nCLtr','nSess','sessions');
for i = 1:numel(st)
    T = POOL.(st{i});
    if isempty(T); fprintf('%-10s  EMPTY\n', st{i}); continue; end
    us = unique(T.sess); um = unique(T.mouse);
    nCLt = nnz(T.cond=='CL');
    fprintf('%-10s %8d %8d %6d   %s  | %d mice: %s\n', st{i}, height(T), nCLt, numel(us), ...
        strjoin(cellstr("m"+string(us))',','), numel(um), strjoin(cellstr(um)',','));
end

save(fullfile(tempdir,'fig4_n_audit.mat'),'A','gC','POOL');
fprintf('\nDONE. Table saved to %s\n', fullfile(tempdir,'fig4_n_audit.mat'));
