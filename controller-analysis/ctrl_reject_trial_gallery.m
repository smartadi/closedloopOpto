%% ctrl_reject_trial_gallery.m   [RGAL]  -- single-trial examples: prediction, and rejection
%
% WHAT THIS SHOWS, AND WHY IT IS WORTH A PANEL. Every Part-2 number is a ratio of energies, and a
% ratio hides whether the two traces it came from look like anything. Each tile here is ONE trial:
%
%   grey   G = Global -- the stim-blind contra->ipsi prediction. Before the laser it is a plain
%          prediction of the ipsi site; after the laser it is the DISTURBANCE, i.e. the
%          counterfactual "what this site would have been doing with no stimulation".
%   red/blue  A = Actual measured ipsi (red = open loop, blue = closed loop).
%   dashed    the reference, -5 %dF/F.
%
% Read each tile in two halves:
%   BEFORE onset  A and G should lie on top of each other. That is the predictor being right, on a
%                 single trial, with no averaging to hide behind -- and it is the part that makes
%                 the disturbance estimate credible at all.
%   AFTER onset   they separate. The separation IS the local effect: laser in OL, laser plus the
%                 controller's own action in CL. In OL, A drops and then follows G's excursions --
%                 the disturbance passes straight through. In CL, A should sit on the reference
%                 while G wanders, because the controller is cancelling it.
%
% TRIAL CHOICE IS NOT RANDOM. Trials are drawn at ER percentiles (default 10/30/50/70/90) so the
% strip spans the range instead of flattering it -- the leftmost tile is among this session's best
% rejection, the rightmost among its worst. ER is printed on every tile and comes from
% imp_reject_core, the same function that produces the headline statistic, so a tile labelled
% ER = 0.31 is one of the points inside the paired plot.
%
% ER = ||A-ref||^2 / ||G-ref||^2 over 0-3 s. <1 = the controller removed disturbance energy;
% =1 = it did nothing (holds identically when A == G); >1 = it made things worse.
%
% SUPPLEMENTARY (user, 2026-08-13): PNG only, into figure4/supp/.
%
% PREREQS: load_sessions.m has run; Stage-1 + Stage-2 caches in the predictor mode in force.
% SECTIONS: [RGAL-CFG] [RGAL-LOOP] [RGAL-FIG]

clc; close all;
assert(exist('mouse','var') && exist('fields','var'), '[RGAL] run load_sessions.m first.');

%% [RGAL-CFG] ---------------------------------------------------------------------
RG_SESS = [4 9 15];                 % m4 AL_0033_0226 | m9 AL_0039_0420 | m15 AL_0051 -- 3 mice
RG_PCT  = [10 30 50 70 90];         % ER percentiles to sample (best -> worst rejection)
CFG     = struct('nSV_load',500, 'Fs',35, 'pre_s',3.0, 'resp_s',3.0);

% SOURCE. 'svd' rebuilds the trials from the raw SVD, which gives ABSOLUTE %dF/F and therefore a
% drawable reference line and true ER -- but it needs the network share. 'cache' reads the per-trial
% A_tr/G_tr already stored in the Stage-2 and CL-deploy caches: no network, but those are stored
% RESPONSE-domain (each trial baseline-subtracted over the pre window), so there is no ref line and
% ER is not computable -- trials are then ranked by per-trial TRANSMISSION instead (see below).
% 'auto' tries the share and falls back. The share went down mid-session on 2026-08-13, which is
% why this fallback exists at all.
RG_SOURCE = 'auto';                 % 'svd' | 'cache' | 'auto'
if exist('RG_SRC','var') && ~isempty(RG_SRC); RG_SOURCE = lower(char(RG_SRC)); end   % caller override

PS = paperStyle(); setPaperDefaults(); %#ok<NASGU>
[~, pred_mode] = ctrl_pred_tag();
rg_here = fileparts(mfilename('fullpath'));
if isempty(rg_here) || contains(rg_here,tempdir,'IgnoreCase',true) || contains(rg_here,'Editor_','IgnoreCase',true)
    rg_here = 'C:\Users\aditya\Documents\projects\brain_paper\controller-analysis';
end
rg_data = fullfile(rg_here,'data');
rg_out  = fullfile(rg_here,'..','paper','images','figure4','supp');
if ~exist(rg_out,'dir'); mkdir(rg_out); end

col = struct('ol',[0.85 0.10 0.10], 'cl',[0.00 0.40 0.85], 'G',[0.45 0.45 0.45]);

%% [RGAL-LOOP] --------------------------------------------------------------------
fprintf('\n[RGAL] predictor = %s | source = %s | trials at percentiles %s\n', ...
    pred_mode, RG_SOURCE, mat2str(RG_PCT));

% In cache mode a session needs BOTH the Stage-2 (OL) and the CL-deploy cache, so the session list
% is discovered rather than assumed.
if strcmpi(RG_SOURCE,'cache')
    RG_SESS = local_cached_sessions(rg_data, mouse, fields);
    fprintf('  cache mode: %d session(s) carry both an OL and a CL cache\n', numel(RG_SESS));
end

for s = RG_SESS(:).'
    B = [];
    if ~strcmpi(RG_SOURCE,'cache')
        % The SVD lives on a network share; a read failure should cost one session, not the whole
        % gallery -- and in 'auto' it should fall through to the caches rather than give up.
        try
            B = imp_build_session(mouse, fields, s, rg_data, CFG);
            if ~B.ok; fprintf('  %-22s (%s)\n', B.sess_tag, B.msg); B = []; end
        catch ME
            fprintf('  %-22s SVD unavailable (%s)\n', fields{s}, ME.message);  B = [];
        end
        if isempty(B) && strcmpi(RG_SOURCE,'svd'); continue; end
    end
    if isempty(B); B = local_from_cache(rg_data, mouse, fields, s, CFG); end
    if isempty(B); fprintf('  %-22s SKIP (no usable source)\n', fields{s}); continue; end

    tt = B.tt;  nC = numel(RG_PCT);
    if B.absolute
        % ER, from the same function that makes the headline statistic, so a tile labelled
        % ER = 0.31 is literally one of the points inside the paired plot.
        R = imp_reject_core(B.Aol, B.Gol, B.Acl, B.Gcl, B.pre, B.Fs, CFG.resp_s, B.ref);
        sOL = R.er_ol;  sCL = R.er_cl;  slab = 'ER';
        hdr = sprintf('OL median ER %.2f  |  CL median ER %.2f', R.er_med_ol, R.er_med_cl);
    else
        % Response domain: no ref, so no ER. Rank by TRANSMISSION instead -- the per-trial
        % regression slope of Actual on Global over the stim window. beta ~ 1 = the disturbance
        % passes straight through; beta ~ 0 = it was rejected. Same direction of merit as ER.
        w = B.pre + (1:round(CFG.resp_s*B.Fs));
        sOL = local_beta(B.Aol, B.Gol, w);  sCL = local_beta(B.Acl, B.Gcl, w);  slab = '\beta';
        hdr = sprintf('OL median \\beta %.2f  |  CL median \\beta %.2f', median(sOL), median(sCL));
    end
    pick = @(v) arrayfun(@(p) local_nearest(v, prctile(v,p)), RG_PCT);
    iOL = pick(sOL);  iCL = pick(sCL);

    figG = figure('Color','w','Position',[25 45 min(320*nC,1700) 620]);
    tl = tiledlayout(figG, 2, nC, 'TileSpacing','compact','Padding','compact');
    for c = 1:nC
        local_tile(nexttile(tl,c),    tt, B.Aol(iOL(c),:), B.Gol(iOL(c),:), B.ref, col.ol, col.G, ...
            CFG.resp_s, sprintf('OL  trial %d   %s = %.2f', iOL(c), slab, sOL(iOL(c))), c==1);
        local_tile(nexttile(tl,nC+c), tt, B.Acl(iCL(c),:), B.Gcl(iCL(c),:), B.ref, col.cl, col.G, ...
            CFG.resp_s, sprintf('CL  trial %d   %s = %.2f', iCL(c), slab, sCL(iCL(c))), c==1);
    end
    xlabel(tl, 'time from laser onset (s)', 'FontWeight','bold');
    if B.absolute; ylabel(tl,'\DeltaF/F (%)','FontWeight','bold');
    else;          ylabel(tl,'\DeltaF/F change from pre-stim baseline (%)','FontWeight','bold'); end
    if B.absolute; refstr = sprintf('| dashed = ref %g', B.ref);
    else;          refstr = '| RESPONSE domain (cache source: no ref line)'; end
    sgtitle(figG, sprintf(['[RGAL] %s  --  grey = Global (prediction before onset, DISTURBANCE after) ' ...
        '| colour = Actual %s\n%s   (tiles ordered best \\rightarrow worst rejection; predictor R^2 = %.3f)'], ...
        strrep(B.sess_tag,'_','\_'), refstr, hdr, B.R2_te), 'FontWeight','bold','FontSize',10);

    exportgraphics(figG, fullfile(rg_out, sprintf('f4supp_trials_%s.png', B.sess_tag)), 'Resolution',300);
    close(figG);
    fprintf('  %-22s OL %3d / CL %3d trials | %s med OL %.2f CL %.2f | R^2 %.3f\n', ...
        B.sess_tag, size(B.Aol,1), size(B.Acl,1), strrep(slab,'\',''), median(sOL), median(sCL), B.R2_te);
end
fprintf('[RGAL] galleries -> %s\n', rg_out);

%% ---- helpers ----
function i = local_nearest(v, target)
[~,i] = min(abs(v(:) - target));
end
function b = local_beta(A, G, w)
%LOCAL_BETA  per-trial transmission: slope of Actual on Global over the stim window.
%   1 = the disturbance passes through untouched, 0 = fully rejected.
n = size(A,1);  b = nan(n,1);
for i = 1:n
    g = G(i,w).';  a = A(i,w).';
    g = g - mean(g); a = a - mean(a);
    d = g.'*g;  if d > eps; b(i) = (g.'*a)/d; end
end
end
function idx = local_cached_sessions(dataDir, mouse, fields)
%LOCAL_CACHED_SESSIONS  sessions carrying BOTH an OL Stage-2 and a CL-deploy cache.
sfx = ctrl_pred_tag();  idx = [];
for k = 1:numel(fields)
    s = mouse.(fields{k});
    if ~isfield(s,'mn'); continue; end
    tg = sprintf('%s_%s%s_e%d', s.mn, s.td(6:7), s.td(9:10), s.en);
    a = exist(fullfile(dataDir, sprintf('ctrl_ols_ol_stimblind%s_%s.mat', sfx, tg)),'file');
    b = exist(fullfile(dataDir, sprintf('ctrl_ols_cl_deploy_%s.mat', tg)),'file');
    if a>0 && b>0; idx(end+1) = k; end %#ok<AGROW>
end
end
function B = local_from_cache(dataDir, mouse, fields, k, CFG)
%LOCAL_FROM_CACHE  per-trial traces straight from the Stage-2 (OL) and CL-deploy caches.
%   No SVD and no network. These store A_tr/G_tr RESPONSE-domain (baseline removed over the pre
%   window), so B.absolute = false and callers must not draw a reference line or compute ER.
B = [];
s = mouse.(fields{k});  if ~isfield(s,'mn'); return; end
tg  = sprintf('%s_%s%s_e%d', s.mn, s.td(6:7), s.td(9:10), s.en);
sfx = ctrl_pred_tag();
f2 = fullfile(dataDir, sprintf('ctrl_ols_ol_stimblind%s_%s.mat', sfx, tg));
fc = fullfile(dataDir, sprintf('ctrl_ols_cl_deploy_%s.mat', tg));
if ~(exist(f2,'file') && exist(fc,'file')); return; end
S2 = load(f2, 'A_tr','G_tr','rel','pre','Fs','R2_te');
CD = load(fc, 'A_tr','G_tr');
if size(S2.A_tr,2) ~= size(CD.A_tr,2); return; end     % different trial windows -> not comparable
B = struct('sess_tag',tg, 'absolute',false, 'ref',[], 'pre',S2.pre, 'Fs',S2.Fs, ...
           'tt',S2.rel/S2.Fs, 'Aol',S2.A_tr, 'Gol',S2.G_tr, 'Acl',CD.A_tr, 'Gcl',CD.G_tr, ...
           'R2_te',S2.R2_te);
end
function local_tile(ax, tt, A, G, ref, cA, cG, dur, ttl, showY)
hold(ax,'on');
% y-limits from the TRACES first; the laser patch is then drawn to them. A patch with hardcoded
% corners hijacks the axis and flattens the data (learned the hard way twice, 2026-08-13).
allv = [A(:); G(:); ref(:)];
lo = min(allv); hi = max(allv); pad = 0.08*max(hi-lo, eps);
yl = [lo-pad, hi+pad];
patch(ax, [0 dur dur 0], yl([1 1 2 2]), [0.90 0.93 1.0], ...
    'EdgeColor','none','FaceAlpha',0.55,'HandleVisibility','off');
if ~isempty(ref)
    yline(ax, ref, '--', 'Color',[0.25 0.25 0.25], 'LineWidth',0.9, 'HandleVisibility','off');
else
    yline(ax, 0, '--', 'Color',[0.55 0.55 0.55], 'LineWidth',0.8, 'HandleVisibility','off');
end
xline(ax, 0, '-', 'Color',[0.7 0.7 0.7], 'LineWidth',0.6, 'HandleVisibility','off');
plot(ax, tt, G, '-', 'Color',cG, 'LineWidth',1.0, 'DisplayName','Global (disturbance)');
plot(ax, tt, A, '-', 'Color',cA, 'LineWidth',1.3, 'DisplayName','Actual');
ylim(ax, yl); xlim(ax, [tt(1) tt(end)]);
set(ax,'Box','off','TickDir','out','FontSize',7);
if ~showY; set(ax,'YTickLabel',[]); end
title(ax, ttl, 'FontSize',8, 'FontWeight','bold');
end
