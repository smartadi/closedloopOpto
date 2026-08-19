%% ctrl_site_diag.m   [SITEDIAG]  -- is the readout pixel where we think it is?
%
% Stage 1 reports corr(Actual, data.dFk) -- how well the trace we rebuild from the SVD at the
% DETECTED laser site tracks the paper's regulated trace. On AL_0033 it runs 0.82-0.96. On
% AL_0039 (x3) it is 0.617 / 0.617 / 0.700 and on AL_0051_0729 it is 0.550, all below the 0.7 that
% Stage 1 warns at. Systematic across ALL THREE AL_0039 sessions, so it looks mouse-specific
% rather than random, and therefore probably fixable.
%
% WHY IT MATTERS. The site sets the ipsi/contra split, the grid, and everything the decomposition
% is about. Stage 2 regresses onto data.dFk whatever the site is, so a bad site does not throw --
% it quietly builds a predictor aimed at the wrong place. Before four sessions are either dropped
% or pooled, the question "where IS the regulated pixel" has to be answered with a number.
%
% WHAT THIS DOES -- no refitting, no cache writes
%   Rebuilds the Actual trace at several CANDIDATE pixels through the identical recipe Stage 1
%   uses (SVD raw-kernel box + rolling baseline, getpixel_dFoF mode-0 match) and reports
%   corr(candidate, data.dFk) for each:
%     (1) DETECTED   the cached cp_find_stim_site laser spot            <- what Stage 1 used
%     (2) PARAMS     d.params.pixel as (row,col) = (pixel(2), pixel(1)) <- the rig's own answer
%     (3) PARAMS_T   the transpose of (2)                              <- catches an x<->y flip
%     (4) BEST       argmax over a coarse whole-brain search            <- where it actually is
%   (4) is the diagnostic that settles it: if BEST lands on top of DETECTED, the site is right and
%   the session simply has a weak SVD reconstruction (a data-quality problem, not a geometry one).
%   If BEST lands somewhere else entirely, the site is recoverable and Stage 1 should be rerun
%   against it.
%
% PREREQS: load_sessions.m; Stage 1 cache for the session (for the grid/kernel/horizon).
% Run:  SD.sess = [9 10 11 14];  ctrl_site_diag        (or leave SD.sess empty for all low-corr)
%
% SECTIONS: [SITEDIAG-CFG] [SITEDIAG-LOOP] [SITEDIAG-FIG] [SITEDIAG-REPORT]

%% [SITEDIAG-CFG] ----------------------------------------------------------------
if ~exist('SD','var') || ~isstruct(SD); SD = struct(); end
if ~isfield(SD,'sess');     SD.sess = [];    end   % [] = every session whose Stage-1 r_match < thr
if ~isfield(SD,'r_thr');    SD.r_thr = 0.70;  end  % the Stage-1 warning level
if ~isfield(SD,'nSV_load'); SD.nSV_load = 500; end
if ~isfield(SD,'Fs');       SD.Fs = 35;       end
if ~isfield(SD,'searchStep'); SD.searchStep = 6; end   % coarse whole-brain search lattice (px)
if ~isfield(SD,'searchMap');  SD.searchMap = true; end % false = candidates only (~1 s vs ~50 s/session)
if ~isfield(SD,'plot');     SD.plot = true;   end
% AMPLITUDE GUARD on the whole-brain search (added after the first run, 2026-08-10).
% Pearson r is scale-free, so a NEAR-FLAT trace can out-correlate the true one: on
% AL_0039_0419_e1 the unguarded argmax picked a rim pixel at r=0.797 whose amplitude was ~10x too
% small, while the detected site (r=0.617) visibly tracked every excursion of data.dFk. Ranking on
% r alone would have repointed the site onto a vessel/edge artefact. A candidate must therefore
% also be the same SIZE of signal, and sit on tissue bright enough to trust.
if ~isfield(SD,'scale_lo');  SD.scale_lo = 0.5;  end   % min std(candidate)/std(data.dFk)
if ~isfield(SD,'scale_hi');  SD.scale_hi = 2.0;  end   % max ditto
if ~isfield(SD,'vesselThr'); SD.vesselThr = 0.18; end  % mimg > thr*max(mimg), as cp_find_stim_site

SD.root = fileparts(fileparts(mfilename('fullpath')));
if isempty(SD.root) || ~exist(fullfile(SD.root,'controller-analysis'),'dir')
    SD.root = 'C:\Users\aditya\Documents\projects\brain_paper';
end
SD.here    = fullfile(SD.root,'controller-analysis');
SD.dataDir = fullfile(SD.here,'data');
SD.figDir  = fullfile(SD.here,'..','paper','images','predictor_saga');
if ~exist(SD.figDir,'dir'); mkdir(SD.figDir); end

assert(exist('mouse','var') && exist('fields','var'), '[SITEDIAG] run load_sessions.m first.');

% default target list = whatever Stage 1 already flagged
if isempty(SD.sess)
    for sd_s = 1:numel(fields)
        sd_f = fields{sd_s};
        sd_tg = sprintf('%s_%s%s_e%d', mouse.(sd_f).mn, mouse.(sd_f).td(6:7), ...
                        mouse.(sd_f).td(9:10), mouse.(sd_f).en);
        sd_p = fullfile(SD.dataDir, sprintf('ctrl_ols_spont_%s.mat', sd_tg));
        if ~exist(sd_p,'file'); continue; end
        q = load(sd_p,'r_match');
        if isfield(q,'r_match') && q.r_match < SD.r_thr; SD.sess(end+1) = sd_s; end
    end
    fprintf('[SITEDIAG] auto-selected %d session(s) with Stage-1 r_match < %.2f\n', ...
        numel(SD.sess), SD.r_thr);
end
SD.log = struct('fld',{},'tag',{},'r_det',{},'s_det',{},'r_par',{},'r_parT',{}, ...
                'r_best',{},'s_best',{},'det_rc',{},'par_rc',{},'best_rc',{}, ...
                'r_raw',{},'s_raw',{},'raw_rc',{},'nOkAmp',{},'d_best_det',{},'verdict',{});

%% [SITEDIAG-LOOP] ---------------------------------------------------------------
for sd_i = 1:numel(SD.sess)
    sd_s   = SD.sess(sd_i);
    sd_fld = fields{sd_s};
    mn = mouse.(sd_fld).mn;  td = mouse.(sd_fld).td;  en = mouse.(sd_fld).en;
    sd_tag = sprintf('%s_%s%s_e%d', mn, td(6:7), td(9:10), en);
    fprintf('\n================ [SITEDIAG %d/%d] %s (%s) ================\n', ...
        sd_i, numel(SD.sess), sd_fld, sd_tag);

    s1p = fullfile(SD.dataDir, sprintf('ctrl_ols_spont_%s.mat', sd_tag));
    if ~exist(s1p,'file')
        fprintf(2,'[SITEDIAG] no Stage-1 cache -- skipping\n'); continue;
    end
    S1 = load(s1p,'px_prim','py_prim','k_prim','horizon','w_warm','r_match','Torient', ...
                  'contra_mask','ipsi_mask');

    % --- session data on demand ------------------------------------------------
    sd_freed = false;
    if ~isfield(mouse.(sd_fld),'d') || isempty(mouse.(sd_fld).d)
        sd_p = fullfile(SD.root,'data', sprintf('%sctrl%s%s%d.mat', mn, td(6:7), td(9:10), en));
        sd_t = load(sd_p);
        if ~isfield(sd_t,'d'); fprintf(2,'[SITEDIAG] cache has no d\n'); clear sd_t; continue; end
        mouse.(sd_fld).d = sd_t.d;  mouse.(sd_fld).data = sd_t.data;  clear sd_t;
        sd_freed = true;
    end
    d_s = mouse.(sd_fld).d;  data = mouse.(sd_fld).data;

    [U_cp,V_cp,~,mimg_cp] = cp_loadUVt(expPath(mn,td,en), SD.nSV_load, d_s.timeBlue);
    V_cp = double(V_cp);  [nY,nX] = size(mimg_cp);
    Uflat = reshape(U_cp, nY*nX, size(U_cp,3));
    k_prim = S1.k_prim;  horizon = S1.horizon;  w_warm = S1.w_warm;
    dfk = data.dFk(:);

    sd_dfk = std(dfk((w_warm+1):end),'omitnan');
    rc_of = @(r,c) [r c];
    cand = struct('name',{},'rc',{},'r',{},'scale',{});
    cand(end+1) = struct('name','DETECTED','rc',rc_of(S1.px_prim,S1.py_prim),'r',NaN,'scale',NaN);
    if isfield(d_s.params,'pixel') && numel(d_s.params.pixel) >= 2
        pr = double(d_s.params.pixel(2));  pc = double(d_s.params.pixel(1));
        cand(end+1) = struct('name','PARAMS',  'rc',rc_of(pr,pc),'r',NaN,'scale',NaN); %#ok<SAGROW>
        cand(end+1) = struct('name','PARAMS_T','rc',rc_of(pc,pr),'r',NaN,'scale',NaN); %#ok<SAGROW>
    end
    for c = 1:numel(cand)
        [cand(c).r, cand(c).scale] = local_match_at(Uflat, V_cp, mimg_cp, cand(c).rc, ...
                                                    k_prim, horizon, nY, nX, dfk, w_warm, sd_dfk);
    end

    % --- coarse whole-brain search: where does dFk ACTUALLY live? ---------------
    % Candidates must sit on trustworthy tissue AND carry a comparable signal AMPLITUDE. See the
    % AMPLITUDE GUARD note in [SITEDIAG-CFG]: Pearson r is scale-free, so an almost-flat rim pixel
    % can out-correlate the true site. Both the raw and the guarded argmax are reported so the
    % guard's effect stays visible rather than being taken on trust.
    brain = (S1.contra_mask | S1.ipsi_mask) & (mimg_cp > SD.vesselThr*max(mimg_cp(:)));
    st = SD.searchStep;
    [gr, gc] = ndgrid(1+k_prim : st : nY-k_prim, 1+k_prim : st : nX-k_prim);
    gr = gr(:); gc = gc(:);
    inb = brain(sub2ind([nY nX], gr, gc));
    gr = gr(inb); gc = gc(inb);
    rmap = nan(numel(gr),1);  smap = nan(numel(gr),1);
    for q = 1:numel(gr)
        [rmap(q), smap(q)] = local_match_at(Uflat, V_cp, mimg_cp, [gr(q) gc(q)], ...
                                            k_prim, horizon, nY, nX, dfk, w_warm, sd_dfk);
    end
    okAmp = smap >= SD.scale_lo & smap <= SD.scale_hi;
    rmapG = rmap;  rmapG(~okAmp) = NaN;
    if any(okAmp)
        [r_best, bi] = max(rmapG);
    else
        [r_best, bi] = max(rmap);                 % nothing passed the guard; report the raw argmax
    end
    best_rc = [gr(bi) gc(bi)];  s_best = smap(bi);
    [r_raw, bir] = max(rmap);  raw_rc = [gr(bir) gc(bir)];  s_raw = smap(bir);
    d_best_det = hypot(best_rc(1)-S1.px_prim, best_rc(2)-S1.py_prim);

    % --- verdict ----------------------------------------------------------------
    % Ranked on correlation AMONG amplitude-plausible pixels only. BEST on top of DETECTED means
    % the geometry is right and this session simply reconstructs poorly from the SVD -- no site
    % change helps. BEST far away AND clearly better means the regulated pixel is elsewhere.
    r_det = cand(1).r;  s_det = cand(1).scale;
    if ~any(okAmp)
        verdict = 'no amplitude-plausible pixel anywhere -- reconstruction, not geometry';
    elseif r_best - r_det < 0.05
        verdict = 'site OK, weak SVD reconstruction (no site change helps)';
    elseif d_best_det <= 25
        verdict = 'site nearly right (small offset)';
    else
        verdict = sprintf('RECOVERABLE: better px %.0f away (+%.3f corr, scale %.2f)', ...
            d_best_det, r_best-r_det, s_best);
    end

    rec = struct('fld',sd_fld,'tag',sd_tag,'r_det',r_det,'s_det',s_det, ...
                 'r_par',  local_get(cand,'PARAMS','r'), ...
                 'r_parT', local_get(cand,'PARAMS_T','r'), ...
                 'r_best',r_best,'s_best',s_best,'det_rc',cand(1).rc, ...
                 'par_rc',local_getrc(cand,'PARAMS'),'best_rc',best_rc, ...
                 'r_raw',r_raw,'s_raw',s_raw,'raw_rc',raw_rc,'nOkAmp',nnz(okAmp), ...
                 'd_best_det',d_best_det,'verdict',verdict);
    SD.log(end+1) = rec;

    fprintf('[SITEDIAG] Stage-1 cached r_match %.3f | recomputed here %.3f\n', S1.r_match, r_det);
    fprintf('   %-9s %-18s %-8s %s\n','candidate','[row col]','corr','amp scale (want ~1)');
    for c = 1:numel(cand)
        fprintf('   %-9s [row %3d col %3d]  %-8.3f %.2f\n', ...
            cand(c).name, cand(c).rc(1), cand(c).rc(2), cand(c).r, cand(c).scale);
    end
    fprintf('   %-9s [row %3d col %3d]  %-8.3f %.2f   (%.0f px from DETECTED; %d/%d px passed the amplitude guard)\n', ...
        'BEST', best_rc(1), best_rc(2), r_best, s_best, d_best_det, nnz(okAmp), numel(gr));
    fprintf('   %-9s [row %3d col %3d]  %-8.3f %.2f   <- what an UNGUARDED argmax would pick\n', ...
        'raw max', raw_rc(1), raw_rc(2), r_raw, s_raw);
    fprintf('   VERDICT: %s\n', verdict);

    % --- figure ------------------------------------------------------------------
    if SD.plot
        T = [];  if isfield(S1,'Torient'); T = S1.Torient; end
        figS = figure('Color','w','Position',[40 60 1620 470], ...
            'Name',sprintf('site diag %s',sd_tag));
        tl = tiledlayout(figS,1,2,'TileSpacing','compact','Padding','compact');

        tl.GridSize = [1 3];
        gg = mat2gray(cp_orient_img(T, mimg_cp));

        % (1) GUARDED correlation surface -- only amplitude-plausible pixels are coloured, which
        % is exactly the set BEST is drawn from.
        ax = nexttile(tl,1); hold(ax,'on');
        Cm = nan(nY,nX);  Cm(sub2ind([nY nX], gr(okAmp), gc(okAmp))) = rmap(okAmp);
        Cd = cp_orient_img(T, Cm);
        image(ax, repmat(gg,1,1,3)); axis(ax,'image','ij','off');
        him = imagesc(ax, Cd); set(him,'AlphaData', 0.85*double(~isnan(Cd)));
        colormap(ax, parula); cb = colorbar(ax); cb.Label.String = 'corr(rebuilt, data.dFk)';
        for c = 1:numel(cand)
            [dr,dc] = cp_orient_fwd(T, cand(c).rc(1), cand(c).rc(2));
            plot(ax, dc, dr, 'w+', 'MarkerSize',12,'LineWidth',2);
            text(ax, dc+4, dr, cand(c).name, 'Color','w','FontSize',7,'FontWeight','bold');
        end
        [br,bc] = cp_orient_fwd(T, best_rc(1), best_rc(2));
        plot(ax, bc, br, 'ro','MarkerSize',12,'LineWidth',2);
        text(ax, bc+4, br, 'BEST', 'Color','r','FontSize',7,'FontWeight','bold');
        title(ax, sprintf('corr, amplitude-plausible px only (max %.3f)', r_best),'FontWeight','normal');

        % (2) the AMPLITUDE map that does the guarding -- this is what stops a flat rim pixel
        % from being crowned. The raw (unguarded) argmax is marked so the difference is visible.
        ax = nexttile(tl,2); hold(ax,'on');
        Sm = nan(nY,nX);  Sm(sub2ind([nY nX], gr, gc)) = smap;
        Sd = cp_orient_img(T, Sm);
        image(ax, repmat(gg,1,1,3)); axis(ax,'image','ij','off');
        him = imagesc(ax, Sd, [0 2]); set(him,'AlphaData', 0.85*double(~isnan(Sd)));
        colormap(ax, parula); cb = colorbar(ax); cb.Label.String = 'std(rebuilt)/std(data.dFk)';
        [rr,rcc] = cp_orient_fwd(T, raw_rc(1), raw_rc(2));
        plot(ax, rcc, rr, 'mo','MarkerSize',12,'LineWidth',2);
        text(ax, rcc+4, rr, sprintf('raw max (scale %.2f)',s_raw),'Color','m','FontSize',7,'FontWeight','bold');
        plot(ax, bc, br, 'ro','MarkerSize',12,'LineWidth',2);
        title(ax, sprintf('amplitude scale (%d/%d px in [%.1f, %.1f])', ...
            nnz(okAmp), numel(gr), SD.scale_lo, SD.scale_hi),'FontWeight','normal');

        % (3) the traces. A low r with matching excursions = right place, weak reconstruction.
        ax = nexttile(tl,3); hold(ax,'on'); box(ax,'on');
        y_det  = local_trace_at(Uflat,V_cp,mimg_cp,cand(1).rc,k_prim,horizon,nY,nX);
        y_best = local_trace_at(Uflat,V_cp,mimg_cp,best_rc,   k_prim,horizon,nY,nX);
        y_raw  = local_trace_at(Uflat,V_cp,mimg_cp,raw_rc,    k_prim,horizon,nY,nX);
        i0 = w_warm+1;  i1 = min([i0+round(60*SD.Fs), numel(dfk), numel(y_det)]);
        tt = (0:(i1-i0))/SD.Fs;
        plot(ax, tt, dfk(i0:i1),   'k-','LineWidth',1.2);
        plot(ax, tt, y_det(i0:i1), '-','Color',[0.85 0.33 0.10],'LineWidth',1.0);
        plot(ax, tt, y_best(i0:i1),'-','Color',[0.10 0.45 0.85],'LineWidth',1.0);
        plot(ax, tt, y_raw(i0:i1), ':','Color',[0.7 0.2 0.7],'LineWidth',1.0);
        xlabel(ax,'time (s, after warm-up)'); ylabel(ax,'\DeltaF/F (%)');
        legend(ax, {'data.dFk (paper)', sprintf('DETECTED r=%.2f s=%.2f',r_det,s_det), ...
                    sprintf('BEST r=%.2f s=%.2f',r_best,s_best), ...
                    sprintf('raw max r=%.2f s=%.2f',r_raw,s_raw)}, ...
                   'Box','off','Location','best','FontSize',6);
        title(ax, 'the same 60 s at each candidate','FontWeight','normal');

        sgtitle(figS, sprintf('[SITEDIAG] %s  --  %s', strrep(sd_tag,'_','\_'), verdict));
        pngf = fullfile(SD.figDir, sprintf('ctrl_site_diag_%s.png', sd_tag));
        exportgraphics(figS, pngf, 'Resolution',300);
        fprintf('[SITEDIAG] figure -> %s\n', pngf);
    end

    if sd_freed; mouse.(sd_fld) = rmfield(mouse.(sd_fld), {'d','data'}); end
    clear U_cp V_cp Uflat
end

%% [SITEDIAG-REPORT] -------------------------------------------------------------
fprintf('\n[SITEDIAG] summary   (s = amplitude scale, std(rebuilt)/std(data.dFk); want ~1)\n');
fprintf('  %-22s %-7s %-6s %-7s %-7s %-7s %-6s %-6s %s\n', ...
    'tag','r_det','s_det','r_par','r_parT','r_best','s_best','dist','verdict');
for sd_i = 1:numel(SD.log)
    L = SD.log(sd_i);
    fprintf('  %-22s %-7.3f %-6.2f %-7.3f %-7.3f %-7.3f %-6.2f %-6.0f %s\n', ...
        L.tag, L.r_det, L.s_det, L.r_par, L.r_parT, L.r_best, L.s_best, L.d_best_det, L.verdict);
end
save(fullfile(SD.dataDir,'ctrl_site_diag.mat'),'SD');
fprintf('\n[SITEDIAG] -> data/ctrl_site_diag.mat\n');
fprintf(['  Reading it: BEST on top of DETECTED = the geometry is right and this session simply\n' ...
         '  reconstructs poorly from the SVD (no site change helps -- decide include/exclude on\n' ...
         '  data quality). BEST far away with a clearly higher corr = the regulated pixel is\n' ...
         '  elsewhere; repoint the cached cp_stim_site_ctrl_<tag>.mat and rerun Stage 1.\n']);

%% ---- local functions -------------------------------------------------------------
function [r, scale] = local_match_at(Uflat, V, mimg, rc, k, horizon, nY, nX, dfk, w_warm, sd_dfk)
% TWO numbers, because one is not enough. `r` says the trace has the same SHAPE as data.dFk;
% `scale` = std(candidate)/std(data.dFk) says it has the same SIZE. A near-flat vessel/rim pixel
% can score a high r and a scale of ~0.1 -- shape without signal. Both are needed to claim a
% candidate IS the regulated readout.
y = local_trace_at(Uflat, V, mimg, rc, k, horizon, nY, nX);
if isempty(y); r = NaN; scale = NaN; return; end
vv = (w_warm+1):min(numel(y), numel(dfk));
r = corr(y(vv), dfk(vv), 'rows','complete');
scale = std(y(vv),'omitnan') / max(sd_dfk, eps);
end

function y = local_trace_at(Uflat, V, mimg, rc, k, horizon, nY, nX)
% IDENTICAL recipe to ctrl_ols_spont.m's local_svd_rolling_dfk: SVD-reconstructed RAW kernel
% fluorescence through the same trailing rolling baseline getpixel_dFoF mode=0 uses. Any change
% here breaks the comparison with Stage 1, which is the whole point of the diagnostic.
prow = rc(1); pcol = rc(2);  y = [];
if prow < 1 || prow > nY || pcol < 1 || pcol > nX; return; end
kr = max(1,prow-k):min(nY,prow+k);
kc = max(1,pcol-k):min(nX,pcol+k);
[KR,KC] = ndgrid(kr,kc);
kidx = sub2ind([nY,nX], KR(:), KC(:));
mI = mean(mimg(kr,kc),'all');
if ~isfinite(mI) || abs(mI) < eps; return; end
Fsvd = mean(double(Uflat(kidx,:)),1) * V;
Fraw = mI + Fsvd(:);
w = max(1, round(horizon)-1);
T = numel(Fraw);  ii = (1:T).';
cs = [0; cumsum(Fraw)];  lo = max(ii-w,1);
base = (cs(ii+1)-cs(lo))./(ii-lo+1);
y = (Fraw - base)./base*100;
y(1:w) = NaN;
end

function v = local_get(cand, name, fld)
i = find(strcmp({cand.name}, name), 1);
if isempty(i), v = NaN; else, v = cand(i).(fld); end
end

function v = local_getrc(cand, name)
i = find(strcmp({cand.name}, name), 1);
if isempty(i), v = [NaN NaN]; else, v = cand(i).rc; end
end
