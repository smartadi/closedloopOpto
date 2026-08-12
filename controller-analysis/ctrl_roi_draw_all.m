%% ctrl_roi_draw_all.m   [XDRAW]  -- PHASE A: draw EVERY session's ROI, then stop.
%
% Walk every controller session, draw its brain outline + midline ON TOP OF THAT SESSION'S OWN
% LASER-EFFECT MAP, fit the Stage-1 spontaneous predictor, and move on. Nothing about the
% residual / affected-pixel decomposition happens here -- that is PHASE B
% (ctrl_residual_build.m), and this script refuses to hand over until every eligible session
% has its own ROI.
%
% WHY TWO PHASES (user, 2026-08-10)
%   The old ctrl_roi_build_all.m interleaved drawing with the affected-pixel tuning, so a
%   sitting was half clicking and half judgement calls about detector thresholds, and the
%   detector was being tuned on some sessions before others had even been drawn. Split:
%     PHASE A (here)                 mechanical, one skill: draw the anatomy. All sessions.
%     PHASE B ctrl_residual_build.m  one session at a time, with the detector open to iteration.
%   The gate at the bottom is the whole point -- Phase B checks the same condition and will not
%   start early.
%
% WHAT YOU SEE WHILE DRAWING (new 2026-08-10)
%   The draw window carries the DATA-DERIVED laser effect: contours of the trial-averaged
%   peri-stim inhibition map (cp_find_stim_site) at 35/55/80% of its depth, a green + on the
%   detected laser site, and a magenta x on d.params.pixel. The midline you click is what
%   assigns contra (predictor) vs ipsi (target), so the spot MUST be visible while you click --
%   a midline drawn on the wrong side of it silently puts the stimulated hemisphere into the
%   "stim-blind" predictor. If the green + and the contours disagree, stop and say so; if the
%   magenta x sits far from the green +, that is expected (params.pixel is rim-prone, see
%   RESEARCH 2026-07-19) and the green + is the one that matters.
%
%   STEP 1: click round the FULL-BRAIN outline (many points, then Enter)
%   STEP 2: click 2 MIDLINE points (then Enter)
%
% WHAT ELSE RUNS, AND WHY IT IS NOT "MOVING FORWARD"
%   After each draw the script completes Stage 1 (ctrl_ols_spont.m: spontaneous contra->ipsi
%   OLS). That is unattended, commits no tunable choice, and produces the ONE number that says
%   whether the ROI is any good -- the held-out spontaneous R^2. It also runs while the 500-
%   component SVD for that session is still in RAM, which is the expensive part; deferring it to
%   Phase B would pay that load twice per session for nothing.
%
% RESUMABLE. Sessions that already own an ROI are skipped unless XD.redraw='all'. Sessions whose
% ROI geometry is byte-identical to another session's are flagged SHARED (donor-seeded by
% imp_xsess_build, i.e. a different day's field of view) and are treated as NOT drawn.
%
% Run:  load_sessions.m  ->  ctrl_roi_draw_all.m  ->  ctrl_residual_build.m
%
% SECTIONS: [XDRAW-CFG] [XDRAW-AUDIT] [XDRAW-LOOP] [XDRAW-GATE]

%% [XDRAW-CFG] -------------------------------------------------------------------
clear XD; XD = struct();
XD.sess     = 1:15;        % candidate session indices into `fields` (clipped to what exists)
XD.redraw   = 'missing';   % 'missing' = only sessions with no ROI of their own (SHARED counts as none)
% (overrides applied after the defaults below -- see [XDRAW-OVERRIDE])
                           % 'all'     = redraw every session in XD.sess
                           % 'shared'  = only the donor-seeded ones
XD.confirm  = true;        % accept/redraw/skip prompt after each session (needs you at the keyboard)
XD.attempts = 3;           % max draw attempts per session
XD.root     = fileparts(fileparts(mfilename('fullpath')));
if isempty(XD.root) || ~exist(fullfile(XD.root,'controller-analysis'),'dir')
    XD.root = 'C:\Users\aditya\Documents\projects\brain_paper';
end
XD.here    = fullfile(XD.root,'controller-analysis');
XD.dataDir = fullfile(XD.here,'data');
if ~exist(XD.dataDir,'dir'); mkdir(XD.dataDir); end

%% [XDRAW-OVERRIDE] set these in the base workspace to redraw without editing this file --------
% Same convention as ctrl_residual_build.m's RB_* overrides. `clear XD` above wipes any pre-set
% XD struct, so the overrides are read from separate XD_* variables and applied here instead.
%   XD_SESS = 2;  XD_REDRAW = 'all';   ->  redraw session m2 only
if exist('XD_SESS','var')   && ~isempty(XD_SESS);   XD.sess    = XD_SESS;   end
if exist('XD_REDRAW','var') && ~isempty(XD_REDRAW); XD.redraw  = XD_REDRAW; end
if exist('XD_CONFIRM','var')&& ~isempty(XD_CONFIRM);XD.confirm = XD_CONFIRM;end
fprintf('[XDRAW] sess = %s | redraw = ''%s''\n', mat2str(XD.sess), XD.redraw);

assert(exist('mouse','var') && exist('fields','var'), '[XDRAW] run load_sessions.m first.');
XD.sess = XD.sess(XD.sess >= 1 & XD.sess <= numel(fields));
XD.log  = struct('fld',{},'tag',{},'status',{},'msg',{},'R2',{},'r_match',{},'nContra',{},'nIpsi',{},'nAtt',{});

%% [XDRAW-AUDIT] what exists right now --------------------------------------------
fprintf('\n[XDRAW] PHASE A -- ROI + midline for %d candidate sessions\n', numel(XD.sess));
XD.aud = struct('fld',{},'tag',{},'hasCtrl',{},'hasSVD',{},'roi',{},'geokey',{},'s1',{});
for xd_i = 1:numel(XD.sess)
    xd_s  = XD.sess(xd_i);
    xd_f  = fields{xd_s};
    xd_mn = mouse.(xd_f).mn;  xd_td = mouse.(xd_f).td;  xd_en = mouse.(xd_f).en;
    xd_tg = sprintf('%s_%s%s_e%d', xd_mn, xd_td(6:7), xd_td(9:10), xd_en);
    a = struct('fld',xd_f,'tag',xd_tg,'hasCtrl',false,'hasSVD',false,'roi','none','geokey','','s1',false);
    a.hasCtrl = exist(fullfile(XD.root,'data', ...
        sprintf('%sctrl%s%s%d.mat', xd_mn, xd_td(6:7), xd_td(9:10), xd_en)),'file') > 0;
    try
        xd_root = expPath(xd_mn, xd_td, xd_en);
        a.hasSVD = exist(fullfile(xd_root,'corr','svdTemporalComponents_corr.npy'),'file') > 0 || ...
                   exist(fullfile(xd_root,'blue','svdSpatialComponents.npy'),'file') > 0;
    catch
        a.hasSVD = false;
    end
    xd_roi = fullfile(XD.dataDir, sprintf('cp_roi2_ctrl_%s.mat', xd_tg));
    if exist(xd_roi,'file')
        a.roi = 'own';
        g = load(xd_roi,'bx','by','mx','my');
        a.geokey = sprintf('%d|%.4f|%.4f|%s|%s', numel(g.bx), sum(g.bx), sum(g.by), ...
                           mat2str(round(g.mx(:).',3)), mat2str(round(g.my(:).',3)));
    end
    a.s1 = exist(fullfile(XD.dataDir,sprintf('ctrl_ols_spont_%s.mat',xd_tg)),'file') > 0;
    XD.aud(end+1) = a;
end
% Two sessions with byte-identical outline+midline points cannot both have been drawn on their
% own mean image -- one was seeded from the other, i.e. it carries a different day's geometry.
xd_keys = {XD.aud.geokey};
for xd_i = 1:numel(XD.aud)
    if isempty(XD.aud(xd_i).geokey), continue; end
    if numel(find(strcmp(xd_keys, XD.aud(xd_i).geokey))) > 1
        XD.aud(xd_i).roi = 'SHARED';
    end
end
fprintf('  %-5s %-22s %-5s %-5s %-7s %-3s\n','fld','tag','ctrl','svd','roi','S1');
for xd_i = 1:numel(XD.aud)
    a = XD.aud(xd_i);
    fprintf('  %-5s %-22s %-5s %-5s %-7s %-3s\n', a.fld, a.tag, yn_xd(a.hasCtrl), yn_xd(a.hasSVD), a.roi, yn_xd(a.s1));
end
xd_nShared = nnz(strcmp({XD.aud.roi},'SHARED'));
if xd_nShared > 0
    fprintf(['  NOTE: %d sessions share identical ROI geometry (donor-seeded from another day''s ' ...
             'field of view). They count as NOT drawn.\n'], xd_nShared);
end

%% [XDRAW-LOOP] per session: draw -> Stage 1 --------------------------------------
for xd_i = 1:numel(XD.sess)
    xd_s   = XD.sess(xd_i);
    xd_fld = fields{xd_s};
    xd_a   = XD.aud(xd_i);
    xd_tag = xd_a.tag;
    xd_mn  = mouse.(xd_fld).mn;  xd_td = mouse.(xd_fld).td;  xd_en = mouse.(xd_fld).en;
    rec = struct('fld',xd_fld,'tag',xd_tag,'status','','msg','','R2',NaN,'r_match',NaN, ...
                 'nContra',NaN,'nIpsi',NaN,'nAtt',0);

    fprintf('\n================ [XDRAW %d/%d] %s (%s) ================\n', ...
        xd_i, numel(XD.sess), xd_fld, xd_tag);

    % --- eligibility ----------------------------------------------------------
    if ~xd_a.hasCtrl
        rec.status='skip'; rec.msg='no controller cache';
        fprintf('[XDRAW] SKIP: %s\n', rec.msg);  XD.log(end+1)=rec;  continue;
    end
    if ~xd_a.hasSVD
        rec.status='skip'; rec.msg='no widefield SVD on the server (nothing to build a contra grid from)';
        fprintf('[XDRAW] SKIP: %s\n', rec.msg);  XD.log(end+1)=rec;  continue;
    end

    % --- does this session need drawing? --------------------------------------
    switch lower(XD.redraw)
        case 'all',    xd_need = true;
        case 'shared', xd_need = strcmp(xd_a.roi,'SHARED') || strcmp(xd_a.roi,'none');
        otherwise,     xd_need = ~strcmp(xd_a.roi,'own');            % 'missing'
    end
    if ~xd_need && xd_a.s1
        rec.status='done'; rec.msg='own ROI + Stage 1 already built';
        fprintf('[XDRAW] nothing to do -- %s\n', rec.msg);  XD.log(end+1)=rec;  continue;
    end
    if ~xd_need && ~xd_a.s1
        fprintf('[XDRAW] ROI exists; Stage 1 missing -> fitting without redrawing.\n');
    end

    % --- session data on demand (each `d` carries the SVD; 1-3.5 GB) ----------
    xd_loaded = false;
    if ~isfield(mouse.(xd_fld),'d') || isempty(mouse.(xd_fld).d)
        xd_p = fullfile(XD.root,'data', sprintf('%sctrl%s%s%d.mat', xd_mn, xd_td(6:7), xd_td(9:10), xd_en));
        xd_tmp = load(xd_p);
        if ~isfield(xd_tmp,'d')
            rec.status='skip'; rec.msg='controller cache has no d';
            fprintf('[XDRAW] SKIP: %s\n', rec.msg);  clear xd_tmp;  XD.log(end+1)=rec;  continue;
        end
        mouse.(xd_fld).data = xd_tmp.data;  mouse.(xd_fld).d = xd_tmp.d;  clear xd_tmp;
        if ~isfield(mouse.(xd_fld).d,'ref'); mouse.(xd_fld).d.ref = -5; end
        xd_loaded = true;
        fprintf('[XDRAW] loaded session cache\n');
    end

    % --- draw (+ Stage 1) with up to XD.attempts tries -------------------------
    xd_ok = false;  xd_att = 0;  xd_drawNow = xd_need;
    while xd_att < XD.attempts
        xd_att = xd_att + 1;  rec.nAtt = xd_att;
        if xd_drawNow
            fprintf(['\n  >>> DRAW %s (attempt %d/%d). The window opens after the SVD load and the\n' ...
                     '      laser-site detection, and shows the laser-effect contours + green + site.\n' ...
                     '      STEP 1: FULL-BRAIN outline (many points, Enter)\n' ...
                     '      STEP 2: 2 MIDLINE points (Enter)  <- keep the green + on the IPSI side\n\n'], ...
                     xd_tag, xd_att, XD.attempts);
        end
        % ctrl_ols_spont.m reads these from the shared workspace (the Code Analyzer cannot see
        % that, hence NASGU). Stage 1 only -- no affected-pixel work happens in Phase A.
        BATCH_selField     = xd_s;        %#ok<NASGU>
        BATCH_redefine_roi = xd_drawNow;  %#ok<NASGU>
        try
            run(fullfile(XD.here,'ctrl_ols_spont.m'));
            if exist('R2_te','var');   rec.R2      = R2_te;   end
            if exist('r_match','var'); rec.r_match = r_match; end
            if exist('contra_mask','var'); rec.nContra = nnz(contra_mask); end
            if exist('ipsi_mask','var');   rec.nIpsi   = nnz(ipsi_mask);   end
            xd_ok = exist(fullfile(XD.dataDir,sprintf('ctrl_ols_spont_%s.mat',xd_tag)),'file') > 0;
        catch xd_ME
            rec.msg = sprintf('ERROR: %s', xd_ME.message);
            fprintf(2,'[XDRAW] %s failed: %s\n', xd_tag, xd_ME.message);
            xd_ok = false;
        end

        % --- the three numbers that expose a bad ROI ---------------------------
        if ~XD.confirm, break; end
        fprintf('\n  --- %s check ------------------------------------------------\n', xd_tag);
        fprintf('    corr(Actual, data.dFk) = %.3f   (expect ~0.9; low = site/kernel/orientation wrong)\n', rec.r_match);
        fprintf('    held-out spontaneous R^2 (full contra grid) = %.3f   (m4 reference: 0.87)\n', rec.R2);
        fprintf('    mask split: contra %d px | ipsi %d px  (lopsided = midline off)\n', rec.nContra, rec.nIpsi);
        if ~xd_ok
            fprintf(2,'    !! this attempt did not write a Stage-1 cache\n');
        end
        xd_ans = lower(strtrim(input('    [a]ccept / [r]edraw / [s]kip session ? ','s')));
        if isempty(xd_ans); xd_ans = 'a'; end
        if xd_ans(1)=='a'
            break
        elseif xd_ans(1)=='s'
            rec.status='skip'; if isempty(rec.msg); rec.msg='skipped by user'; end
            xd_ok = false;  break
        else
            xd_drawNow = true;  close all;      % redraw and refit
        end
    end

    if isempty(rec.status)
        if xd_ok
            rec.status='drawn';  if isempty(rec.msg); rec.msg='ok'; end
        else
            rec.status='fail';   if isempty(rec.msg); rec.msg='did not complete'; end
        end
    end
    XD.log(end+1) = rec;

    if xd_loaded
        mouse.(xd_fld) = rmfield(mouse.(xd_fld), {'d','data'});    % free the 1-3.5 GB
    end
    clear BATCH_selField BATCH_redefine_roi;
    close all;
end

%% [XDRAW-GATE] all drawn? ---------------------------------------------------------
fprintf('\n[XDRAW] PHASE A summary\n  %-5s %-22s %-7s %-8s %-9s %-8s %-8s %s\n', ...
    'fld','tag','status','R2spont','corr_dFk','nContra','nIpsi','msg');
for xd_i = 1:numel(XD.log)
    L = XD.log(xd_i);
    fprintf('  %-5s %-22s %-7s %-8.3f %-9.3f %-8d %-8d %s\n', ...
        L.fld, L.tag, L.status, L.R2, L.r_match, L.nContra, L.nIpsi, L.msg);
end

% Re-audit from disk (not from XD.log) so an accepted-but-unwritten session cannot pass the gate.
XD.pending = {};
for xd_i = 1:numel(XD.aud)
    a = XD.aud(xd_i);
    if ~a.hasCtrl || ~a.hasSVD, continue; end        % not eligible; not a blocker
    roi_ok = exist(fullfile(XD.dataDir,sprintf('cp_roi2_ctrl_%s.mat',a.tag)),'file') > 0;
    s1_ok  = exist(fullfile(XD.dataDir,sprintf('ctrl_ols_spont_%s.mat',a.tag)),'file') > 0;
    if ~(roi_ok && s1_ok); XD.pending{end+1} = a.tag; end
end
XD.eligible = nnz([XD.aud.hasCtrl] & [XD.aud.hasSVD]);
fprintf('\n[XDRAW] %d/%d eligible sessions have an ROI + Stage-1 cache.\n', ...
    XD.eligible - numel(XD.pending), XD.eligible);
if isempty(XD.pending)
    fprintf(['[XDRAW] PHASE A COMPLETE -- every eligible session was drawn on its own mean image.\n' ...
             '        Next: ctrl_residual_build.m (PHASE B, one session at a time, detector open\n' ...
             '        to iteration). It re-checks this same condition before it starts.\n']);
else
    fprintf(2,['[XDRAW] PHASE A INCOMPLETE -- %d session(s) still need drawing:\n          %s\n' ...
               '        Re-run this script (XD.redraw=''missing'') until the list is empty.\n' ...
               '        ctrl_residual_build.m will refuse to start before then.\n'], ...
        numel(XD.pending), strjoin(XD.pending, ', '));
end

%% ---- local functions -------------------------------------------------------------
function s = yn_xd(tf)
if tf, s = 'yes'; else, s = '-'; end
end
