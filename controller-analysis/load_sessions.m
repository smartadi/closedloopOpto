% controller-analysis -- extracted from plottingScript.m
% Run from brain_paper/ root directory.

%% 
%% plotting across sessions


clc;
close all;
% `clear all` was here. Changed 2026-08-10 to `clearvars -except r_lean` so the
% registry-only knob set by the caller (`r_lean = 1; load_sessions;`) survives to
% the LEAN block below -- `clear all` wiped it, which silently made the flag a
% no-op. Still a clean workspace; it just no longer also flushes cached FUNCTIONS.
% If you need that (edited a .m while a GUI held it), use the targeted form:
%   clear <fnname>; rehash
%
% RUN_* added 2026-08-12: a launcher that RUNS this script (run_fig4.m) shares this
% workspace, so anything it set is destroyed here -- its own config included, and the
% failure lands several steps later as "Unrecognized function or variable". Launcher
% state is namespaced RUN_* and preserved; nothing else in the project uses that prefix.
clearvars -except r_lean RUN_* XD_* RB_*;

% If launched via run() from controller-analysis/, step up to project root
% so that relative paths (data/, utils/) resolve correctly.
% Check for controller-analysis/ as a subdirectory — only true at brain_paper/ level.
if ~isfolder('controller-analysis') && isfolder(fullfile('..', 'controller-analysis'))
    cd('..');
end

%% get data
pathString = genpath('utils');
    addpath(pathString);




%%  save data as npy

mouse.m1.mn = 'AL_0033'; mouse.m1.td = '2025-01-20'; 
mouse.m1.en = 3;
mouse.m1.trials = 120;

mouse.m2.mn = 'AL_0033'; mouse.m2.td = '2025-02-12'; 
mouse.m2.en = 2;
mouse.m2.trials = 200;

mouse.m3.mn = 'AL_0033'; mouse.m3.td = '2025-02-24'; 
mouse.m3.en = 2;
mouse.m3.trials = 200;

mouse.m4.mn = 'AL_0033'; mouse.m4.td = '2025-02-26'; 
mouse.m4.en = 2;
mouse.m4.trials = 200;

mouse.m5.mn = 'AL_0033'; mouse.m5.td = '2025-03-04'; 
mouse.m5.en = 1;
mouse.m5.trials = 60;


mouse.m6.mn = 'AL_0033'; mouse.m6.td = '2025-03-05'; 
mouse.m6.en = 2;
mouse.m6.trials = 30;

mouse.m7.mn = 'AL_0033'; mouse.m7.td = '2025-03-20'; 
mouse.m7.en = 4;
mouse.m7.trials = 100;

mouse.m8.mn = 'AL_0033'; mouse.m8.td = '2025-04-15'; 
mouse.m8.en = 2;
mouse.m8.trials = 60;


mouse.m9.mn = 'AL_0039'; mouse.m9.td = '2025-04-20'; 
mouse.m9.en = 1;
mouse.m9.trials = 100;


mouse.m10.mn = 'AL_0039'; mouse.m10.td = '2025-04-19'; 
mouse.m10.en = 1;
mouse.m10.trials = 100;

mouse.m11.mn = 'AL_0039'; mouse.m11.td = '2025-04-30'; 
mouse.m11.en = 3;
mouse.m11.trials = 100;


mouse.m12.mn = 'AL_0033'; mouse.m12.td = '2025-04-19'; 
mouse.m12.en = 1;
mouse.m12.trials = 100;

mouse.m13.mn = 'AL_0039'; mouse.m13.td = '2025-04-20';
mouse.m13.en = 2;
mouse.m13.trials = 100;

% New static-reference controller mice (2026-07-29). 17-col rig build: onset =
% timeBlue(col2)-dur (col2 = trial-END abs index, no horizon), SVD-mode pixel,
% ref -5. Only the LAST 100 trials (Kp LOCKED) are the OL/CL block; earlier
% trials are the Kp tuning sweep. AL_0050 excluded (poor stim). See
% project_new_controller_mice memory. newbuild flag drives the loop branch.
mouse.m14.mn = 'AL_0048'; mouse.m14.td = '2026-07-29';
mouse.m14.en = 2;
mouse.m14.trials = 100;
mouse.m14.newbuild = true;

mouse.m15.mn = 'AL_0051'; mouse.m15.td = '2026-07-29';
mouse.m15.en = 2;
mouse.m15.trials = 100;
mouse.m15.newbuild = true;



%% Feedforward vs Feedback

% r_ctrl = 0: recompute and overwrite cache (use after changing controllerData.m)
% r_ctrl = 1: load from cache if available
r_ctrl = 1;

% ---------------------------------------------------------------------------
% r_lean = 1: REGISTRY ONLY -- build `mouse`/`fields` (mn/td/en/trials/newbuild
%             + the cache path and whether it exists) and load NO `d`/`data`.
%
% Why this exists: each controller cache is 1-3.5 GB because `d` holds the full
% 2000-component SVD, so loading all 15 is ~40 GB and OOMs partway (fails at m13,
% RESEARCH 2026-07-30). Every cross-session batch script -- ctrl_roi_build_all.m,
% imp_reject_across_sessions.m, ctrl_ols_xsess.m -- already lazy-loads each
% session and frees it again, so they need the REGISTRY, not the data. Before
% this flag the only way to run them was an ad-hoc hand-edited stand-in copy of
% this file (RESEARCH 2026-08-02), which is how the registry drifts.
%
% Set it BEFORE calling this script:   r_lean = 1; load_sessions;
% Leave it unset for the normal full load -- default behaviour is unchanged.
% ---------------------------------------------------------------------------
if ~exist('r_lean','var') || isempty(r_lean); r_lean = 0; end

fields = fieldnames(mouse);
if r_lean
    fprintf('[LEAN] registry-only load -- no d/data held in memory.\n');
end
for k = 1:length(fields)
    try
        if r_lean
            mn_k = mouse.(fields{k}).mn;
            td_k = mouse.(fields{k}).td;
            en_k = mouse.(fields{k}).en;
            pathCtrl = fullfile('data', sprintf('%sctrl%s%s%d.mat', mn_k, td_k(6:7), td_k(9:10), en_k));
            mouse.(fields{k}).pathCtrl = pathCtrl;
            mouse.(fields{k}).hasCache = exist(pathCtrl, 'file') == 2;
            fprintf('[LEAN] %-5s %-8s %s e%d  cache:%s\n', fields{k}, mn_k, td_k, en_k, ...
                string(mouse.(fields{k}).hasCache));
            continue
        end
        mn_k = mouse.(fields{k}).mn;
        td_k = mouse.(fields{k}).td;
        en_k = mouse.(fields{k}).en;

        pathCtrl = fullfile('data', sprintf('%sctrl%s%s%d.mat', mn_k, td_k(6:7), td_k(9:10), en_k));

        if exist(pathCtrl, 'file') && r_ctrl == 1
            tmp = load(pathCtrl);
            mouse.(fields{k}).data = tmp.data;
            if isfield(tmp, 'd')
                mouse.(fields{k}).d = tmp.d;
            else
                mouse.(fields{k}).d = initialize_data(mn_k, en_k, td_k);
                mouse.(fields{k}).d.ref = -5;
                d    = mouse.(fields{k}).d;
                data = mouse.(fields{k}).data;
                save(pathCtrl, 'd', 'data', '-v7.3');
                fprintf('Re-saved cache with d: %s\n', fields{k});
            end
            if ~isfield(mouse.(fields{k}).d, 'ref')
                mouse.(fields{k}).d.ref = -5;
            end
            % Backfill has_motion for caches saved before the flag existed.
            if ~isfield(mouse.(fields{k}).d, 'has_motion')
                mouse.(fields{k}).d.has_motion = any(mouse.(fields{k}).d.motion ~= 0);
            end
            mouse.(fields{k}).has_motion = mouse.(fields{k}).d.has_motion;
            fprintf('Loaded cache: %s\n', fields{k});
        else
            mouse.(fields{k}).d = initialize_data(mn_k, en_k, td_k);

            isNew = isfield(mouse.(fields{k}), 'newbuild') && mouse.(fields{k}).newbuild;
            if isNew
                % 17-col build: input_params col2 (kk) = ABSOLUTE sample index at
                % the trial END, no params.horizon -> findStims mode1 is ~40 s off.
                % Correct onset = timeBlue(kk) - dur. (Verified 2026-07-30.)
                kk = round(mouse.(fields{k}).d.input_params(:,2));
                mouse.(fields{k}).d.stimStarts = mouse.(fields{k}).d.timeBlue(kk) - mouse.(fields{k}).d.params.dur;
                mouse.(fields{k}).d.stimEnds   = mouse.(fields{k}).d.timeBlue(kk);
            end

            mode = 0;  % from binary image
            if isNew; mode = 1; end   % new build has no local raw frames -> SVD recon
            r    = 1;  % use dFk cache
            mouse.(fields{k}).data = getpixel_dFoF(mouse.(fields{k}).d, mode, mouse.(fields{k}).d.params.pixel, r);

            mouse.(fields{k}).d.ref = -5;
            mouse.(fields{k}).has_motion = mouse.(fields{k}).d.has_motion;
            mouse.(fields{k}).data = controllerData(mouse.(fields{k}).data, mouse.(fields{k}).d, mouse.(fields{k}).trials);

            d    = mouse.(fields{k}).d;
            data = mouse.(fields{k}).data;
            if ~exist('data', 'dir'); mkdir('data'); end
            save(pathCtrl, 'd', 'data', '-v7.3');
            fprintf('Saved cache: %s\n', fields{k});
        end
    catch ME
        fprintf('Skipping %s: %s\n', fields{k}, ME.message);
        mouse.(fields{k}).skip = true;
    end
end


%%
% LEAN GUARD: everything below aggregates across `mouse.<f>.data` / `.d`, which
% registry-only mode deliberately does not hold. The cross-session batch scripts
% (ctrl_roi_build_all / imp_reject_across_sessions / ctrl_ols_xsess) lazy-load
% each session themselves and never touch these arrays, so stopping here is the
% whole point -- it is what keeps the 15-session run inside memory.
if r_lean
    fprintf(['[LEAN] registry built for %d sessions; skipping the variance aggregation.\n' ...
             '[LEAN] Ready for: ctrl_roi_build_all.m | imp_reject_across_sessions.m | ctrl_ols_xsess.m\n' ...
             '[LEAN] For the Fig-3 pooled panels use pooled_new_mice.m (also lean).\n'], numel(fields));
    return
end

Mvarnc = [];
Mvarwc = [];
for k = 1:length(fields)
    % mouse.(fields{k}).d = initialize_data(mouse.(fields{k}).mn, mouse.(fields{k}).en, mouse.(fields{k}).td);
    
    %
    
nc =  mouse.(fields{k}).data.nc;
wc =  mouse.(fields{k}).data.wc;

    dFk = mouse.(fields{k}).data.dFk;
dur =3;
er_ncDfk=[];
vr_ncDfk=[];
pncDfk = [];
error_nc = [];
ncInp=[];

error_NC = [];


spont_dFk = []

d = mouse.(fields{k}).d;
ti = mouse.(fields{k}).d.inpTime;

t = mouse.(fields{k}).d.timeBlue;
for j = 1: length(nc)
    [a i] = min(abs(t - mouse.(fields{k}).d.stimStarts(nc(j))));
    er_ncDfk = [er_ncDfk; norm(dFk(i:i+35*(dur))+5)];
    
    pncDfk = [pncDfk; dFk(i-35*3:i+35*(dur+3))];


    error_nc = [error_nc;dFk(i:i+35*(dur))+5];

    spont_dFk = [spont_dFk;dFk(i-(6*35):i-1)];


    [a i2] = min(abs(ti - d.stimStarts(nc(j))));
    
    
    ncInp = [ncInp; d.inpVals(i2:i2+dur*2000)'];

end


wcInp=[];

er_wcDfk=[];
vr_wcDfk=[];
pwcDfk = [];
error_wc = [];
for j = 1: length(wc)
    [a i] = min(abs(t - mouse.(fields{k}).d.stimStarts(wc(j))));
    er_wcDfk = [er_wcDfk; norm(dFk(i:i+35*(dur))+5)];
    
    pwcDfk = [pwcDfk; dFk(i-35*3:i+35*(dur+3))];

    error_wc = [error_wc;dFk(i:i+35*(dur))+5];

    spont_dFk = [spont_dFk;dFk(i-(6*35):i-1)];

    [a i2] = min(abs(ti - d.stimStarts(wc(j))));
    
    
    wcInp = [wcInp; d.inpVals(i2:i2+dur*2000)'];
end

mouse.(fields{k}).data.er_wcDfk_l = er_wcDfk;
mouse.(fields{k}).data.er_ncDfk_l = er_ncDfk;
mouse.(fields{k}).data.pwcDfk_l = pwcDfk;

mouse.(fields{k}).data.error_nc = error_nc;

mouse.(fields{k}).data.vr_wcDfk_l = var(pwcDfk);
mouse.(fields{k}).data.vr_ncDfk_l = var(pncDfk);
mouse.(fields{k}).data.pncDfk_l = pncDfk;

mouse.(fields{k}).data.error_wc = error_wc;


mouse.(fields{k}).data.ncInp = ncInp;
mouse.(fields{k}).data.wcInp = wcInp;

mouse.(fields{k}).data.spont_dFk = spont_dFk;

Mvarnc = [Mvarnc;mouse.(fields{k}).data.vr_ncDfk_l];
Mvarwc = [Mvarwc;mouse.(fields{k}).data.vr_wcDfk_l];
end



%% analysisPlots_combined -> single session
selField = 10;   % <-- change to target session index

analysisPlots_combined(mouse.(fields{selField}).data, mouse.(fields{selField}).d);

%% SVD frame -- single session  (3 cm by 3 cm, high-res PDF)
d_sel        = mouse.(fields{selField}).d;
svdData.U    = d_sel.svd.U;
svdData.V    = d_sel.svd.V;
svdData.mimg = d_sel.svd.mimg;

displayFrame(mouse.(fields{selField}).mn, ...
             mouse.(fields{selField}).td, ...
             mouse.(fields{selField}).en, ...
             d_sel, d_sel.params.pixels, svdData);

fig_frame = gcf;
ax_frame  = gca;
colorbar('off');
set(ax_frame, 'XTick',[], 'YTick',[], 'DataAspectRatio',[1 1 1], 'Position',[0 0 1 1]);
set(fig_frame, 'Units','centimeters', 'Position',[0 0 3 3]);
exportgraphics(fig_frame, ...
    sprintf('paper/images/figure1/svd_frame_%s_%s.pdf', mouse.(fields{selField}).mn, mouse.(fields{selField}).td), ...
    'ContentType','image', 'Resolution',600, 'Padding','tight');

%%


%%
Mean_var_wc = mean(Mvarwc);
Mean_var_nc = mean(Mvarnc);
tp = (-3*35 : 35*(dur+3)) / 35;   % -3s to dur+3s, guaranteed 35*(dur+6)+1 pts



