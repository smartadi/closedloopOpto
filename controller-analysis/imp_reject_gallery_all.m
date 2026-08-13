%% imp_reject_gallery_all.m   [RGALL]  -- the IMP rejection gallery + summary, for EVERY session
%
% WHAT THIS IS. `internal_model_principle.m` produces two per-session figures that no aggregate can
% replace -- `internal_model_principle_reject_gallery_<sess>.png` and `..._reject_summary_<sess>.png`
% -- but it is hardwired to one session (selField = 4, AL_0033_0226_e2). This runs the same two
% figures across all sessions that have the caches, with the same file names, into the same folder,
% so the existing 0226 pair is simply joined by the rest.
%
% NOTHING IS REIMPLEMENTED. Trials come from `imp_build_session` (the shared front end) and the
% metrics from `imp_reject_core` (the shared kernel), which is what the cross-session batch already
% uses -- so every number here is the same number that appears in the paired plots. The trial panel
% itself was lifted out of internal_model_principle.m into `utils/imp_reject_panel_plot.m` and both
% callers now draw through it, rather than the batch keeping a private copy that drifts.
%
% THE TWO FIGURES.
%   GALLERY   4 OL trials over 4 CL trials, drawn at transmission percentiles 10/30/50/70/90-ish so
%             the strip spans each session's range instead of showing only its best trials. Each
%             panel: D = Global (grey) = the disturbance; A raw (light dashed) -- before the laser
%             A and D sit together near zero, which is the visual proof the reference is effectively
%             zero pre-stim; E = A - ref (colour) = the metric's numerator. Shading = the 1-3 s
%             rejection window.
%   SUMMARY   (a) transmission in the 0-1 s transient, (b) in the 1-3 s settled window, OL vs CL as
%             jittered per-trial points with the median, (c) transmission against disturbance SIZE,
%             which is the panel that answers "does it only work when the disturbance is small?".
%
% METRICS. ER = ||A-ref||^2/||G-ref||^2 over 0-3 s is the reporting metric (1 = no work, <1 = gain).
% The legacy transmission rho = ||A-ref||/||G|| over 1-3 s is what the gallery and summary are drawn
% in, because that is what those two figures have always shown -- both come from imp_reject_core and
% must not be mixed in text.
%
% NEEDS THE SVD SHARE (imp_build_session reads it). If \\sahale... is down this cannot run; there is
% no cache-only path, because the gallery needs ABSOLUTE %dF/F for the reference line to mean
% anything and the caches only store response-domain traces.
%
% PREREQS: load_sessions.m has run; Stage-1 + Stage-2 caches for the predictor mode in force.
% SECTIONS: [RGALL-CFG] [RGALL-LOOP] [RGALL-TABLE]

clc; close all;
assert(exist('mouse','var') && exist('fields','var'), '[RGALL] run load_sessions.m first.');

%% [RGALL-CFG] --------------------------------------------------------------------
CFG  = struct('nSV_load',500, 'Fs',35, 'pre_s',1.0, 'resp_s',3.0);   % pre_s matches IMP's own
GA_SESS = [];              % [] = every session; else indices into `fields`
GA_NCOL = 4;               % trials per row in the gallery

PS = paperStyle(); col_ol = PS.col_ol; col_cl = PS.col_cl;
[~, pred_mode] = ctrl_pred_tag();
ga_here = fileparts(mfilename('fullpath'));
if isempty(ga_here) || contains(ga_here,tempdir,'IgnoreCase',true) || contains(ga_here,'Editor_','IgnoreCase',true)
    ga_here = 'C:\Users\aditya\Documents\projects\brain_paper\controller-analysis';
end
ga_data = fullfile(ga_here,'data');
ga_out  = fullfile(ga_here,'..','paper','images','predictor_saga');
if ~exist(ga_out,'dir'); mkdir(ga_out); end
if isempty(GA_SESS); GA_SESS = 1:numel(fields); end

%% [RGALL-LOOP] -------------------------------------------------------------------
fprintf('\n[RGALL] predictor = %s | %d candidate sessions -> %s\n', pred_mode, numel(GA_SESS), ga_out);
T = struct('tag',{},'nOL',{},'nCL',{},'er_ol',{},'er_cl',{},'p_er',{}, ...
           'rho_ol',{},'rho_cl',{},'p_rho',{},'R2',{},'frac_ol',{},'frac_cl',{});
skipped = {};
for s = GA_SESS(:).'
    try
        B = imp_build_session(mouse, fields, s, ga_data, CFG);
    catch ME
        skipped{end+1} = sprintf('%s (load: %s)', fields{s}, ME.message); %#ok<SAGROW>
        fprintf('  %-22s SKIP (load failed)\n', fields{s});  continue;
    end
    if ~B.ok
        skipped{end+1} = sprintf('%s (%s)', B.sess_tag, B.msg); %#ok<SAGROW>
        fprintf('  %-22s SKIP (%s)\n', B.sess_tag, B.msg);  continue;
    end
    R  = imp_reject_core(B.Aol, B.Gol, B.Acl, B.Gcl, B.pre, B.Fs, CFG.resp_s, B.ref);
    tt = B.tt;  nOL = B.nOL;  nCL = B.nCL;  ref = B.ref;

    % ---- gallery: trials spanning each session's transmission range ----
    gsel = @(n) max(1,min(n,round(linspace(0.10,0.90,GA_NCOL)*n)));
    [~,so] = sort(R.rho_ol);  idxO = so(gsel(nOL));
    [~,sc] = sort(R.rho_cl);  idxC = sc(gsel(nCL));
    figr = figure('Color','w','Position',[40 60 1500 620]);
    tlr  = tiledlayout(figr,2,GA_NCOL,'TileSpacing','compact','Padding','compact');
    rowspec = {B.Aol,B.Gol,idxO,R.rho_ol,col_ol,'OL'; B.Acl,B.Gcl,idxC,R.rho_cl,col_cl,'CL'};
    for rr = 1:2
        A=rowspec{rr,1}; G=rowspec{rr,2}; idx=rowspec{rr,3};
        rhov=rowspec{rr,4}; col=rowspec{rr,5}; nm=rowspec{rr,6};
        for cc = 1:GA_NCOL
            ax = nexttile(tlr,(rr-1)*GA_NCOL+cc);  k = idx(cc);
            h = imp_reject_panel_plot(ax, tt, G(k,:), A(k,:), ref, col, CFG.resp_s);
            title(ax,sprintf('%s trial %d   ||E||/||D||=%.2f',nm,k,rhov(k)),'FontWeight','normal');
            if cc==1; ylabel(ax,'%\DeltaF/F'); end
            if rr==2; xlabel(ax,'time from stim (s)'); end
            if rr==1 && cc==1; legend(ax,[h.D h.A h.E],'Location','northwest','Box','off'); end
        end
    end
    sgtitle(figr,sprintf(['[IMP-REJECT] rejection gallery  %s  ' ...
        '(D=contra disturbance, E=A-ref; shaded = 1-3 s rejection window)'], strrep(B.sess_tag,'_','\_')));
    exportgraphics(figr, fullfile(ga_out, ...
        sprintf('internal_model_principle_reject_gallery_%s.png',B.sess_tag)), 'Resolution',300);
    close(figr);

    % ---- summary: transmission distributions + transmission vs disturbance size ----
    FS = 14;
    figs = figure('Color','w','Position',[50 80 1500 480]);
    tls  = tiledlayout(figs,1,3,'TileSpacing','compact','Padding','compact');
    for pp = 1:2
        if pp==1; ro=R.rho_ol_tr; rc=R.rho_cl_tr; ttl='(a) 0–1 s transient';
        else;     ro=R.rho_ol;    rc=R.rho_cl;    ttl='(b) 1–3 s settled'; end
        ax = nexttile(tls,pp); hold(ax,'on');
        scatter(ax,1+0.09*randn(nOL,1),ro,22,col_ol,'filled','MarkerFaceAlpha',.5);
        scatter(ax,2+0.09*randn(nCL,1),rc,22,col_cl,'filled','MarkerFaceAlpha',.5);
        plot(ax,[0.72 1.28],[median(ro) median(ro)],'-','Color',col_ol,'LineWidth',2.8);
        plot(ax,[1.72 2.28],[median(rc) median(rc)],'-','Color',col_cl,'LineWidth',2.8);
        yline(ax,1,'--','Color',[.7 .7 .7],'HandleVisibility','off');   % 1 = disturbance passes
        yline(ax,0,':','Color',[.5 .5 .5],'HandleVisibility','off');
        set(ax,'XTick',[1 2],'XTickLabel',{'OL','CL'},'Box','off','TickDir','out','FontSize',FS);
        xlim(ax,[0.5 2.5]);
        if pp==1; ylabel(ax,'transmission  ||E|| / ||D||','FontSize',FS+1); end
        title(ax,ttl,'FontWeight','normal','FontSize',FS+2);
    end
    axc = nexttile(tls,3); hold(axc,'on');
    scatter(axc,R.Dmag_ol,R.rho_ol,24,col_ol,'filled','MarkerFaceAlpha',.55,'DisplayName','OL');
    scatter(axc,R.Dmag_cl,R.rho_cl,24,col_cl,'filled','MarkerFaceAlpha',.55,'DisplayName','CL');
    yline(axc,1,'--','Color',[.7 .7 .7],'HandleVisibility','off');
    yline(axc,0,':','Color',[.5 .5 .5],'HandleVisibility','off');
    xlabel(axc,'disturbance ||G|| (RMS %\DeltaF/F)','FontSize',FS+1);
    ylabel(axc,'transmission  ||E|| / ||D||','FontSize',FS+1);
    set(axc,'Box','off','TickDir','out','FontSize',FS);
    title(axc,'(c) vs disturbance size','FontWeight','normal','FontSize',FS+2);
    legend(axc,'Location','southeast','Box','off','FontSize',FS);
    sgtitle(figs,sprintf('disturbance rejection   %s   (ER med OL %.2f \\rightarrow CL %.2f)', ...
        strrep(B.sess_tag,'_','\_'), R.er_med_ol, R.er_med_cl),'FontSize',FS+3,'FontWeight','bold');
    exportgraphics(figs, fullfile(ga_out, ...
        sprintf('internal_model_principle_reject_summary_%s.png',B.sess_tag)), 'Resolution',300);
    close(figs);

    T(end+1) = struct('tag',B.sess_tag,'nOL',nOL,'nCL',nCL, ...
        'er_ol',R.er_med_ol,'er_cl',R.er_med_cl,'p_er',R.p_er, ...
        'rho_ol',median(R.rho_ol),'rho_cl',median(R.rho_cl),'p_rho',R.p_rho, ...
        'R2',B.R2_te,'frac_ol',R.er_frac_ol,'frac_cl',R.er_frac_cl); %#ok<SAGROW>
    fprintf('  %-22s OL %3d / CL %3d | ER %.2f->%.2f (p=%.3g) | rho %.2f->%.2f | R^2 %.3f\n', ...
        B.sess_tag,nOL,nCL,R.er_med_ol,R.er_med_cl,R.p_er,median(R.rho_ol),median(R.rho_cl),B.R2_te);
end
assert(~isempty(T), '[RGALL] no session produced figures (SVD share down?).');

%% [RGALL-TABLE] ------------------------------------------------------------------
fprintf('\n[RGALL] %d sessions  --  ER = ||A-ref||^2/||G-ref||^2 (0-3 s), rho = ||A-ref||/||G|| (1-3 s)\n', numel(T));
fprintf('  %-22s %5s %5s %7s %7s %10s %7s %7s %7s\n', ...
    'session','nOL','nCL','ER OL','ER CL','ranksum p','rho OL','rho CL','R^2');
for i = 1:numel(T)
    fprintf('  %-22s %5d %5d %7.3f %7.3f %10.3g %7.3f %7.3f %7.3f\n', ...
        T(i).tag,T(i).nOL,T(i).nCL,T(i).er_ol,T(i).er_cl,T(i).p_er,T(i).rho_ol,T(i).rho_cl,T(i).R2);
end
eo=[T.er_ol].'; ec=[T.er_cl].';
fprintf('  %-22s %5s %5s %7.3f %7.3f %10.3g %7.3f %7.3f\n','MEDIAN','','', ...
    median(eo),median(ec),signrank(eo,ec),median([T.rho_ol]),median([T.rho_cl]));
fprintf('  CL better (ER) in %d/%d sessions | signrank p = %.4g\n', nnz(ec<eo), numel(T), signrank(eo,ec));
if ~isempty(skipped); fprintf('  skipped: %s\n', strjoin(skipped,' | ')); end
save(fullfile(ga_data,'imp_reject_gallery_all.mat'),'T','CFG','pred_mode');
fprintf('[RGALL] figures -> %s\n', ga_out);
