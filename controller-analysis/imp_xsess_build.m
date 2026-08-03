%% imp_xsess_build.m   [IMP-XBUILD] -- build the per-session predictor caches the
% cross-session rejection batch needs.
%
% imp_reject_across_sessions.m ("Stream 2") auto-skips any session without BOTH
%   data/ctrl_ols_spont_<tag>.mat        (Stage 1, spontaneous contra->ipsi OLS)
%   data/ctrl_ols_ol_stimblind_<tag>.mat (Stage 2, stim-blind unaffected-pixel refit)
% As of 2026-08-02 only m4 had them, so the "population" result was n=1. This script
% builds the missing pairs unattended.
%
% THE ONE INTERACTIVE STEP, AND HOW IT IS AVOIDED
%   Stage 1 needs a hand-drawn ROI (brain outline + 2 midline points) per session via
%   cp_roi_masks' ginput GUI. Everything else is data-derived (the laser site comes from
%   cp_find_stim_site on that session's own OL dips). The ROI cache is nothing but the
%   geometry {bx,by,mx,my} in the 560x560 transposed frame, so for sessions of the SAME
%   MOUSE -- same headplate, same rig, same FOV -- we SEED it by copying a donor session's
%   geometry instead of redrawing. Guardrails, all logged per session:
%     * frame size must match the donor exactly;
%     * corr(meanImage, donor meanImage) >= XB.mimg_corr_min (FOV-drift check);
%     * Stage 1 prints its own corr(Actual, data.dFk) and held-out R^2 -- a bad ROI shows there.
%   CROSS-MOUSE SEEDING IS REFUSED (AL_0033 vs AL_0039 mean images correlate only ~0.56).
%   Each new mouse needs exactly ONE drawn ROI: run ctrl_ols_spont.m interactively for one of
%   its sessions, add that session to XB.donor, and this script propagates it to the rest.
%
% NOTE ON aff_dip_thr (Stage 2): m4's threshold was hand-tuned in ctrl_affected_gui.m and
% cached as ctrl_aff_thr_<tag>.mat. Sessions without a cached value fall back to the script
% default (1.33). That is a FIXED hyperparameter across the population, not a per-session
% fit -- report it that way; do not silently re-tune per session.
%
% Run: load_sessions.m (or a lean equivalent) -> imp_xsess_build -> imp_reject_across_sessions
% ---------------------------------------------------------------------------------

%% [XBUILD-CFG] -----------------------------------------------------------------
clear XB; XB = struct();
XB.sess          = [2 3 5 6 7 8 12];   % session indices to build. Default = the remaining AL_0033
                                       % set (m1 has no SVD; m4 is already built; the AL_0039
                                       % sessions [9 10 11 13] need their own donor ROI first).
if exist('XB_SESS','var') && ~isempty(XB_SESS); XB.sess = XB_SESS; end   % caller override (single-session trial run)
XB.donor.AL_0033 = struct('tag','AL_0033_0226_e2','mn','AL_0033','td','2025-02-26','en',2);
XB.mimg_corr_min = 0.70;               % FOV-drift floor for accepting a seeded ROI
XB.force         = false;              % true = rebuild even if both caches already exist
XB.root          = fileparts(fileparts(mfilename('fullpath')));
if isempty(XB.root) || ~exist(fullfile(XB.root,'controller-analysis'),'dir')
    XB.root = 'C:\Users\aditya\Documents\projects\brain_paper';
end
XB.here    = fullfile(XB.root,'controller-analysis');
XB.dataDir = fullfile(XB.here,'data');

assert(exist('mouse','var') && exist('fields','var'), '[XBUILD] need `mouse`,`fields` (load_sessions).');
XB.log = struct('fld',{},'tag',{},'ok',{},'msg',{},'R2_te',{},'nUnaff',{},'mimgCorr',{});

%% [XBUILD-LOOP] ----------------------------------------------------------------
for xb_i = 1:numel(XB.sess)
    xb_s   = XB.sess(xb_i);
    xb_fld = fields{xb_s};
    xb_mn  = mouse.(xb_fld).mn;  xb_td = mouse.(xb_fld).td;  xb_en = mouse.(xb_fld).en;
    xb_tag = sprintf('%s_%s%s_e%d', xb_mn, xb_td(6:7), xb_td(9:10), xb_en);
    rec = struct('fld',xb_fld,'tag',xb_tag,'ok',false,'msg','','R2_te',NaN,'nUnaff',NaN,'mimgCorr',NaN);
    fprintf('\n================ [XBUILD %d/%d] %s (%s) ================\n', xb_i, numel(XB.sess), xb_fld, xb_tag);

    xb_f1 = fullfile(XB.dataDir, sprintf('ctrl_ols_spont_%s.mat', xb_tag));
    xb_f2 = fullfile(XB.dataDir, sprintf('ctrl_ols_ol_stimblind_%s.mat', xb_tag));
    if exist(xb_f1,'file') && exist(xb_f2,'file') && ~XB.force
        rec.ok = true; rec.msg = 'already built';
        fprintf('[XBUILD] both caches present -- skipping (set XB.force=true to rebuild).\n');
        XB.log(end+1) = rec; continue;
    end

    % --- ROI: seed from the same-mouse donor if this session has none ----------
    xb_roi = fullfile(XB.dataDir, sprintf('cp_roi2_ctrl_%s.mat', xb_tag));
    xb_skip = false;
    if ~exist(xb_roi,'file')
        if ~isfield(XB.donor, xb_mn)
            rec.msg = sprintf('no ROI and no donor for %s -- draw one ROI for this mouse first', xb_mn);
            xb_skip = true;
        else
            xb_dn  = XB.donor.(xb_mn);
            xb_droi = fullfile(XB.dataDir, sprintf('cp_roi2_ctrl_%s.mat', xb_dn.tag));
            if ~exist(xb_droi,'file')
                rec.msg = sprintf('donor ROI missing (%s)', xb_dn.tag);  xb_skip = true;
            else
                xb_mis = readNPY(fullfile(expPath(xb_mn,xb_td,xb_en),'blue','meanImage.npy'));
                xb_mid = readNPY(fullfile(expPath(xb_dn.mn,xb_dn.td,xb_dn.en),'blue','meanImage.npy'));
                if ~isequal(size(xb_mis), size(xb_mid))
                    rec.msg = sprintf('frame %s != donor %s', mat2str(size(xb_mis)), mat2str(size(xb_mid)));
                    xb_skip = true;
                else
                    rec.mimgCorr = corr(double(xb_mis(:)), double(xb_mid(:)));
                    if rec.mimgCorr < XB.mimg_corr_min
                        rec.msg = sprintf('meanImage corr %.3f < %.2f -- FOV drifted, draw this session''s ROI', ...
                            rec.mimgCorr, XB.mimg_corr_min);
                        xb_skip = true;
                    else
                        copyfile(xb_droi, xb_roi);
                        fprintf('[XBUILD] seeded ROI from %s (meanImage corr %.3f)\n', xb_dn.tag, rec.mimgCorr);
                    end
                end
            end
        end
    end
    if xb_skip
        fprintf('[XBUILD] SKIP: %s\n', rec.msg);  XB.log(end+1) = rec;  continue;
    end

    % --- session data: load on demand, drop after (each `d` is 1-3.5 GB) -------
    xb_loaded = false;
    if ~isfield(mouse.(xb_fld),'d') || isempty(mouse.(xb_fld).d)
        xb_p = fullfile(XB.root,'data', sprintf('%sctrl%s%s%d.mat', xb_mn, xb_td(6:7), xb_td(9:10), xb_en));
        if ~exist(xb_p,'file')
            rec.msg = 'no controller cache';  fprintf('[XBUILD] SKIP: %s\n', rec.msg);
            XB.log(end+1) = rec;  continue;
        end
        xb_tmp = load(xb_p);
        mouse.(xb_fld).data = xb_tmp.data;  mouse.(xb_fld).d = xb_tmp.d;  clear xb_tmp;
        if ~isfield(mouse.(xb_fld).d,'ref'); mouse.(xb_fld).d.ref = -5; end
        xb_loaded = true;
        fprintf('[XBUILD] loaded session cache (%s)\n', xb_p);
    end

    % --- Stage 1 -> Stage 2 ----------------------------------------------------
    BATCH_selField = xb_s;
    try
        run(fullfile(XB.here,'ctrl_ols_spont.m'));
        run(fullfile(XB.here,'ctrl_ols_ol_stimblind.m'));
        rec.ok = exist(xb_f1,'file')>0 && exist(xb_f2,'file')>0;
        if rec.ok
            xb_q = load(xb_f2);
            if isfield(xb_q,'R2_te'); rec.R2_te = xb_q.R2_te; end
            if isfield(xb_q,'Su');    rec.nUnaff = nnz(xb_q.Su); end
            clear xb_q;  rec.msg = 'built';
        else
            rec.msg = 'ran but a cache is missing';
        end
    catch xb_ME
        rec.msg = sprintf('ERROR: %s', xb_ME.message);
        fprintf(2,'[XBUILD] %s failed: %s\n', xb_tag, xb_ME.message);
    end
    XB.log(end+1) = rec;

    if xb_loaded
        mouse.(xb_fld) = rmfield(mouse.(xb_fld), {'d','data'});   % free the 1-3.5 GB
    end
    clear BATCH_selField; close all;
end

%% [XBUILD-REPORT] --------------------------------------------------------------
fprintf('\n[XBUILD] summary\n  %-5s %-22s %-6s %-8s %-7s %s\n','fld','tag','ok','R2_te','nUnaff','msg');
for xb_i = 1:numel(XB.log)
    fprintf('  %-5s %-22s %-6d %-8.3f %-7d %s\n', XB.log(xb_i).fld, XB.log(xb_i).tag, ...
        XB.log(xb_i).ok, XB.log(xb_i).R2_te, XB.log(xb_i).nUnaff, XB.log(xb_i).msg);
end
fprintf('[XBUILD] %d/%d sessions now have Stage-1+2 caches. Next: imp_reject_across_sessions.m\n', ...
    nnz([XB.log.ok]), numel(XB.log));
