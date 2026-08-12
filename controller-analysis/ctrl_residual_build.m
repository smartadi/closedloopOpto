%% ctrl_residual_build.m   [XRES]  -- PHASE B: the residual, ONE SESSION AT A TIME.
%
% For each session in turn: decide which contra pixels the laser touches, drop them, refit the
% Global predictor on what is left, and deploy it on the OL trials to get
%     Actual = Global + Local,   Local = Actual - Global  (the residual = the local laser effect).
%
% This is the judgement-call half of the pipeline and is deliberately separated from the drawing
% (PHASE A, ctrl_roi_draw_all.m). It will not start until every eligible session owns an ROI and
% a Stage-1 cache -- tuning a detector on session 3 while session 7 has not been drawn means the
% threshold gets chosen against a partial view of the data.
%
% SELECTION IS AUTOMATIC SINCE 2026-08-10 -- the default mode is unattended
%   Contralateral co-suppression is real and distributed: the MEDIAN contra pixel dips 1-4
%   pre-window SDs, so an absolute "unaffected" cut deleted 70-99% of the grid and only 1 of 13
%   sessions cleared ctrl_r2_floor(). The rule is now RANK-based -- keep the K LEAST-affected
%   pixels -- with K chosen per session by utils/ctrl_select_k.m as the SMALLEST K still clearing
%   the floor, i.e. the most stim-blind predictor that is still usable. There is no threshold left
%   to tune, so RB.mode='auto' is the default and the GUI is for inspection.
%
% WHAT MUST BE REPORTED WITH EVERY RESULT
%   You cannot get pixels that are unaffected in absolute terms, so the residual bleed is measured
%   instead of assumed away. Two numbers travel with every Local share:
%     bleed_kept  median dip score of the KEPT pixels (how blind the predictor really is)
%     leak%       how much the Global trace itself dips through the stim (the consequence)
%   Global dipping ==> Local UNDER-reports the local effect. And in the other direction, a Global
%   below the floor hands its own prediction error to Local ==> Local OVER-reports. The gate stops
%   the second; bleed_kept/leak quantify the first.
%
% THE THING YOU CAN STILL CHANGE
%   utils/ctrl_affected_detect.m is the ONE place the affected/kept call is made. The GUI
%   (ctrl_affected_gui.m) and the builder (ctrl_ols_ol_stimblind.m) both call it, so what you see
%   is what gets built. To change the ALGORITHM, edit that file (or ask Claude to) and re-run this
%   script for the affected sessions. RB.detect passes straight through as the detector's opts, so
%   a whole-run override (method, keep_n, max_bleed, ...) needs no file edit at all.
%
% PER SESSION
%   1. (RB.mode='tune' only) ctrl_affected_gui.m opens for inspection: deflection map + contra grid
%      coloured by the detector, K slider starting at the automatic K*, "R^2 vs K" sweep,
%      click-a-pixel inspector, ipsi trial browser. "Build predictor" commits a hand-picked K.
%      Press Enter here when done. In 'auto' (the default) this step is skipped entirely.
%   2. ctrl_ols_ol_stimblind.m runs -> ctrl_ols_ol_stimblind_<tag>.mat.
%   3. Numbers printed; you choose [n]ext / [r]etry this session / [s]kip / [q]uit
%      (set RB.confirm=false to run the whole set without stopping).
%
% ITERATING ON THE ALGORITHM. Quit ('q'), change ctrl_affected_detect.m (or RB.detect), then
% re-run with RB.sess = <that session index> and RB.rebuild = true. Nothing else is disturbed.
%
% Run:  load_sessions.m  ->  ctrl_roi_draw_all.m (all sessions)  ->  ctrl_residual_build.m
%       then: ctrl_ols_xsess.m / internal_model_principle.m
%
% SECTIONS: [XRES-CFG] [XRES-PRECHECK] [XRES-LOOP] [XRES-REPORT]

%% [XRES-CFG] --------------------------------------------------------------------
clear RB; RB = struct();
RB.sess        = [];        % [] = every eligible session, in order. Or explicit indices, e.g. [4 9].
RB.mode        = 'auto';    % 'auto' = no GUI; K chosen per session by ctrl_select_k (DEFAULT)
                            % 'tune' = stop in the GUI for inspection before each build
RB.detect      = struct();  % detector opts passed to ctrl_affected_detect (BATCH_detect), e.g.
                            %   struct('keep_n',180)                  <- pin K, skip the selector
                            %   struct('max_bleed',3.0)               <- never keep a px past -3 SD
                            %   struct('method','dip','thr',1.33)     <- the old absolute rule
RB.rebuild     = false;     % true = redo sessions that already have a Stage-2 cache
RB.require_all = true;      % refuse to start until PHASE A is complete for every eligible session
RB.confirm     = true;      % ask next/retry/skip/quit after each session
RB.attempts    = 4;         % max retries per session
% CALLER OVERRIDES. This block opens with `clear RB`, so an RB set before the run is wiped --
% these let a one-line unattended rebuild be launched without editing the file (same idiom as
% XB_SESS in imp_xsess_build.m). Typical full rebuild:
%   r_lean = 1; load_sessions; RB_REBUILD = true; RB_CONFIRM = false; ctrl_residual_build
if exist('RB_SESS','var')    && ~isempty(RB_SESS);    RB.sess    = RB_SESS;    end
if exist('RB_REBUILD','var') && ~isempty(RB_REBUILD); RB.rebuild = RB_REBUILD; end
if exist('RB_CONFIRM','var') && ~isempty(RB_CONFIRM); RB.confirm = RB_CONFIRM; end
if exist('RB_MODE','var')    && ~isempty(RB_MODE);    RB.mode    = RB_MODE;    end
RB.root        = fileparts(fileparts(mfilename('fullpath')));
if isempty(RB.root) || ~exist(fullfile(RB.root,'controller-analysis'),'dir')
    RB.root = 'C:\Users\aditya\Documents\projects\brain_paper';
end
RB.here    = fullfile(RB.root,'controller-analysis');
RB.dataDir = fullfile(RB.here,'data');

assert(exist('mouse','var') && exist('fields','var'), '[XRES] run load_sessions.m first.');

%% [XRES-PRECHECK] PHASE A must be finished ---------------------------------------
% Checked against DISK, not against a log: the only thing that makes a session usable here is a
% cp_roi2_ctrl_*.mat that was drawn on its own mean image plus a ctrl_ols_spont_*.mat fitted
% through it.
RS = struct('idx',{},'fld',{},'tag',{},'elig',{},'roi',{},'s1',{},'s2',{},'geokey',{});
for rb_s = 1:numel(fields)
    rb_f  = fields{rb_s};
    rb_mn = mouse.(rb_f).mn;  rb_td = mouse.(rb_f).td;  rb_en = mouse.(rb_f).en;
    rb_tg = sprintf('%s_%s%s_e%d', rb_mn, rb_td(6:7), rb_td(9:10), rb_en);
    e = struct('idx',rb_s,'fld',rb_f,'tag',rb_tg,'elig',false,'roi',false,'s1',false,'s2',false,'geokey','');
    hasCtrl = exist(fullfile(RB.root,'data', ...
        sprintf('%sctrl%s%s%d.mat', rb_mn, rb_td(6:7), rb_td(9:10), rb_en)),'file') > 0;
    hasSVD = false;
    try
        rb_root = expPath(rb_mn, rb_td, rb_en);
        hasSVD = exist(fullfile(rb_root,'corr','svdTemporalComponents_corr.npy'),'file') > 0 || ...
                 exist(fullfile(rb_root,'blue','svdSpatialComponents.npy'),'file') > 0;
    catch
    end
    e.elig = hasCtrl && hasSVD;
    rb_roi = fullfile(RB.dataDir, sprintf('cp_roi2_ctrl_%s.mat', rb_tg));
    e.roi  = exist(rb_roi,'file') > 0;
    if e.roi
        g = load(rb_roi,'bx','by','mx','my');
        e.geokey = sprintf('%d|%.4f|%.4f|%s|%s', numel(g.bx), sum(g.bx), sum(g.by), ...
                           mat2str(round(g.mx(:).',3)), mat2str(round(g.my(:).',3)));
    end
    e.s1 = exist(fullfile(RB.dataDir,sprintf('ctrl_ols_spont_%s.mat',rb_tg)),'file') > 0;
    e.s2 = exist(fullfile(RB.dataDir,sprintf('ctrl_ols_ol_stimblind%s_%s.mat', ctrl_pred_tag(), rb_tg)),'file') > 0;
    RS(end+1) = e; %#ok<SAGROW>
end
% donor-seeded geometry counts as NOT drawn (see ctrl_roi_draw_all.m)
rb_keys = {RS.geokey};
for rb_i = 1:numel(RS)
    if isempty(RS(rb_i).geokey), continue; end
    if numel(find(strcmp(rb_keys, RS(rb_i).geokey))) > 1, RS(rb_i).roi = false; end
end

rb_missing = {RS([RS.elig] & ~([RS.roi] & [RS.s1])).tag};
fprintf('\n[XRES] PHASE B -- residual / affected-pixel build\n');
fprintf('  eligible sessions: %d | Phase A complete: %d | Stage-2 already built: %d\n', ...
    nnz([RS.elig]), nnz([RS.elig] & [RS.roi] & [RS.s1]), nnz([RS.elig] & [RS.s2]));
if ~isempty(rb_missing)
    fprintf(2,'  PHASE A INCOMPLETE for: %s\n', strjoin(rb_missing,', '));
    if RB.require_all
        error(['[XRES] %d eligible session(s) still lack an own-drawn ROI + Stage-1 fit. ' ...
               'Run ctrl_roi_draw_all.m until its gate is clear, or set RB.require_all=false ' ...
               'to work on the drawn ones only (the cross-session numbers will then be partial).'], ...
               numel(rb_missing));
    end
    fprintf('  RB.require_all=false -> continuing with the drawn sessions only.\n');
end

% --- the work list ---------------------------------------------------------------
rb_ready = [RS.elig] & [RS.roi] & [RS.s1];
if isempty(RB.sess)
    rb_todo = [RS(rb_ready).idx];
else
    rb_todo = RB.sess(:).';
    rb_bad  = setdiff(rb_todo, [RS(rb_ready).idx]);
    if ~isempty(rb_bad)
        error('[XRES] requested session(s) %s are not Phase-A ready.', mat2str(rb_bad));
    end
end
if ~RB.rebuild
    rb_have = [RS([RS.s2]).idx];
    rb_skip = intersect(rb_todo, rb_have);
    rb_todo = setdiff(rb_todo, rb_have, 'stable');
    if ~isempty(rb_skip)
        fprintf('  already built (RB.rebuild=false, skipping): %s\n', mat2str(rb_skip));
    end
end
fprintf('  to build now: %s   [mode ''%s'']\n', mat2str(rb_todo), RB.mode);
if isempty(rb_todo)
    fprintf('[XRES] nothing to do. Set RB.rebuild=true to redo, or RB.sess to target a session.\n');
    return
end
if ~isempty(fieldnames(RB.detect))
    fprintf('  detector override: %s\n', local_struct2str(RB.detect));
end

RB.log = struct('idx',{},'tag',{},'status',{},'msg',{},'method',{},'K',{},'nAff',{},'nUnaff',{}, ...
                'R2',{},'ceil',{},'reach',{},'bleed',{},'leak',{},'gate',{}, ...
                'capt_tran',{},'capt_sus',{},'nAtt',{});

%% [XRES-LOOP] one session at a time -----------------------------------------------
rb_quit = false;
for rb_k = 1:numel(rb_todo)
    if rb_quit, break; end
    rb_s   = rb_todo(rb_k);
    rb_fld = fields{rb_s};
    rb_e   = RS([RS.idx]==rb_s);
    rb_tag = rb_e.tag;
    rec = struct('idx',rb_s,'tag',rb_tag,'status','','msg','','method','','K',NaN, ...
                 'nAff',NaN,'nUnaff',NaN,'R2',NaN,'ceil',NaN,'reach',true,'bleed',NaN,'leak',NaN, ...
                 'gate',false,'capt_tran',NaN,'capt_sus',NaN,'nAtt',0);

    fprintf('\n================ [XRES %d/%d] %s (%s) ================\n', ...
        rb_k, numel(rb_todo), rb_fld, rb_tag);

    % --- session data on demand (each `d` carries the SVD; 1-3.5 GB) --------------
    rb_loaded = false;
    if ~isfield(mouse.(rb_fld),'d') || isempty(mouse.(rb_fld).d)
        rb_mn = mouse.(rb_fld).mn;  rb_td = mouse.(rb_fld).td;  rb_en = mouse.(rb_fld).en;
        rb_p = fullfile(RB.root,'data', sprintf('%sctrl%s%s%d.mat', rb_mn, rb_td(6:7), rb_td(9:10), rb_en));
        rb_tmp = load(rb_p);
        if ~isfield(rb_tmp,'d')
            rec.status='skip'; rec.msg='controller cache has no d';
            fprintf(2,'[XRES] SKIP: %s\n', rec.msg);  clear rb_tmp;  RB.log(end+1)=rec;  continue;
        end
        mouse.(rb_fld).data = rb_tmp.data;  mouse.(rb_fld).d = rb_tmp.d;  clear rb_tmp;
        if ~isfield(mouse.(rb_fld).d,'ref'); mouse.(rb_fld).d.ref = -5; end
        rb_loaded = true;
        fprintf('[XRES] loaded session cache\n');
    end

    % --- tune -> build, retryable ------------------------------------------------
    rb_att = 0;  rb_ok = false;
    while rb_att < RB.attempts
        rb_att = rb_att + 1;  rec.nAtt = rb_att;
        BATCH_selField = rb_s;        %#ok<NASGU>
        BATCH_detect   = RB.detect;   %#ok<NASGU>
        try
            if strcmpi(RB.mode,'tune')
                fprintf(['\n  >>> TUNE %s (attempt %d/%d) -- the detector GUI is opening.\n' ...
                         '      - browse the ipsi trial responses BEFORE trusting the session\n' ...
                         '      - "R^2 vs threshold" shows which cuts clear the %.2f floor\n' ...
                         '      - click contra pixels near the midline: those are the ones the\n' ...
                         '        threshold decides, and the ones that matter\n' ...
                         '      - then "Build predictor" to COMMIT the threshold\n\n'], ...
                        rb_tag, rb_att, RB.attempts, ctrl_r2_floor());
                run(fullfile(RB.here,'ctrl_affected_gui.m'));
                input('    press Enter once the threshold is committed (or to accept the saved/default) ... ','s');
            end
            run(fullfile(RB.here,'ctrl_ols_ol_stimblind.m'));
            if exist('DET','var')
                rec.method = DET.method;  rec.bleed = DET.bleed_kept;
                rec.nAff = nnz(DET.affected);  rec.nUnaff = DET.nKept;
            end
            if exist('KSEL','var')
                rec.K = KSEL.K_star;  rec.ceil = KSEL.R2_ceiling;  rec.reach = KSEL.reachable;
            end
            if exist('R2_te','var');     rec.R2   = R2_te;     end
            if exist('gate_pass','var'); rec.gate = gate_pass; end
            if exist('leak','var') && exist('swin','var'); rec.leak = leak(swin); end
            if exist('capt','var') && exist('twin','var')
                rec.capt_tran = capt(twin);  rec.capt_sus = capt(swin);
            end
            rb_ok = exist(fullfile(RB.dataDir,sprintf('ctrl_ols_ol_stimblind%s_%s.mat', ctrl_pred_tag(), rb_tag)),'file') > 0;
        catch rb_ME
            rec.msg = sprintf('ERROR: %s', rb_ME.message);
            fprintf(2,'[XRES] %s failed: %s\n', rb_tag, rb_ME.message);
            rb_ok = false;
        end

        % --- what the residual came out as ---------------------------------------
        fprintf('\n  --- %s residual ---------------------------------------------\n', rb_tag);
        fprintf('    selection     : %s, K=%d  ->  %d dropped / %d kept\n', ...
            rec.method, rec.K, rec.nAff, rec.nUnaff);
        fprintf('    Global R^2    : %.3f   (ceiling %.3f, floor %.2f) -> %s\n', ...
            rec.R2, rec.ceil, ctrl_r2_floor(), ...
            tern_xres(rec.gate,'PASS','FAIL  (Local is inflated by prediction error)'));
        if ~rec.reach
            fprintf(2,'                    the full-grid CEILING is below the floor -- no K can pass here\n');
        end
        fprintf('    residual bleed: median kept score %+.2f | Global leak %.0f%% of Actual (sustained)\n', ...
            rec.bleed, rec.leak);
        fprintf('    Local share   : %.0f%% transient / %.0f%% sustained  (under-reported by the leak above)\n', ...
            rec.capt_tran, rec.capt_sus);
        if ~rb_ok
            fprintf(2,'    !! no Stage-2 cache was written\n');
        end
        if ~RB.confirm, break; end
        rb_ans = lower(strtrim(input('    [n]ext / [r]etry this session / [s]kip / [q]uit ? ','s')));
        if isempty(rb_ans); rb_ans = 'n'; end
        switch rb_ans(1)
            case 'n', break
            case 's', rec.status='skip'; if isempty(rec.msg); rec.msg='skipped by user'; end
                      rb_ok=false; break
            case 'q', rec.status='quit'; rec.msg='user quit'; rb_quit=true; break
            otherwise, close all;      % 'r' -- retune and rebuild this same session
        end
    end

    if isempty(rec.status)
        if rb_ok && rec.gate
            rec.status='built';  if isempty(rec.msg); rec.msg='ok'; end
        elseif rb_ok
            % The cache is written so the session stays inspectable, but a Global below the floor
            % must not enter a pooled statistic -- ctrl_ols_xsess.m drops it on the same test.
            rec.status='lowR2';
            rec.msg=sprintf('R^2 %.3f < floor %.2f -- loosen the threshold (keep more px)', ...
                            rec.R2, ctrl_r2_floor());
        else
            rec.status='fail';   if isempty(rec.msg); rec.msg='did not complete'; end
        end
    end
    RB.log(end+1) = rec;

    if rb_loaded
        mouse.(rb_fld) = rmfield(mouse.(rb_fld), {'d','data'});   % free the 1-3.5 GB
    end
    clear BATCH_selField BATCH_detect;
    close all;
end

%% [XRES-REPORT] -------------------------------------------------------------------
fprintf('\n[XRES] PHASE B summary  (R^2 floor %.2f)\n', ctrl_r2_floor());
fprintf('  %-22s %-7s %-5s %-6s %-6s %-6s %-6s %-6s %-7s %-7s %s\n', ...
    'tag','status','K','nKept','R2','ceil','bleed','leak%','Loc_tr%','Loc_su%','msg');
for rb_i = 1:numel(RB.log)
    L = RB.log(rb_i);
    fprintf('  %-22s %-7s %-5d %-6d %-6.3f %-6.3f %-+6.2f %-6.0f %-7.0f %-7.0f %s\n', ...
        L.tag, L.status, L.K, L.nUnaff, L.R2, L.ceil, L.bleed, L.leak, L.capt_tran, L.capt_sus, L.msg);
end
rb_unreach = {RB.log(~[RB.log.reach]).tag};
if ~isempty(rb_unreach)
    fprintf(['  CEILING BELOW FLOOR (no pixel set can pass; a session property, not a tuning failure):\n' ...
             '    %s\n'], strjoin(rb_unreach, ', '));
end
fprintf('\n[XRES] %d built / %d attempted (%d below the R^2 floor).\n', ...
    nnz(strcmp({RB.log.status},'built')), numel(RB.log), nnz(strcmp({RB.log.status},'lowR2')));
if any(strcmp({RB.log.status},'lowR2'))
    fprintf(['  Below-floor sessions are cached but will be DROPPED by ctrl_ols_xsess.m. Re-run this\n' ...
             '  script with RB.sess = <those indices>, RB.rebuild = true and a looser threshold.\n']);
end
fprintf('  Next: ctrl_ols_xsess.m (combined model statistics), then internal_model_principle.m\n');

%% ---- local functions -------------------------------------------------------------
function s = tern_xres(c, a, b)
if c, s = a; else, s = b; end
end

function s = local_struct2str(S)
f = fieldnames(S);  parts = cell(1,numel(f));
for i = 1:numel(f)
    v = S.(f{i});
    if ischar(v), parts{i} = sprintf('%s=%s', f{i}, v);
    elseif isnumeric(v) && isscalar(v), parts{i} = sprintf('%s=%g', f{i}, v);
    else, parts{i} = sprintf('%s=<%s>', f{i}, class(v));
    end
end
s = strjoin(parts, ', ');
end
