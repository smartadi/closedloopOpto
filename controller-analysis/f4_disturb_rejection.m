%% f4_disturb_rejection.m -- Fig-4 Row-3 disturbance-rejection panels (SELECTED build).
% Promotes the 2026-09-11 scratchpad panels (f4_disturb_stimblind / f4_decomp_schematic /
% f4_reject_newmetric) into ONE permanent, reproducible controller-analysis script.
%
% METRIC (user-selected 2026-09-11):  RR = ||A-ref||^2 / ||G||^2
%   response energy (A vs setpoint ref) over disturbance energy (G vs ZERO, the
%   counterfactual no-laser level). Defined once in imp_reject_core.m (R.rr_*). On the
%   settled window RR == rho^2, so it reuses the per-trial rho already stored in the cache.
%   RR<1 = disturbance energy suppressed (active rejection); RR>1 = response >= disturbance.
% WINDOW : settled t=+1..+3 s (locked disturbance-rejection window; skips the inhibitory
%   onset transient that otherwise dominates 0-3 s).
% PREDICTOR: ridge (regularized) -- the selected deployed predictor (ctrl_pred_tag == 'ridge').
% EXEMPLAR : AL_0033_0415_e2 (most stim-blind, leak 0.17) -- the model-example session.
%
% PANELS -> paper/images/figure4/ (PDF paper panels) + PNG preview to scratchpad:
%   f4_disturb_ol_response.pdf       OL: disturbance vs subdued response (trial mean +/- SEM)
%   f4_disturb_cl_response.pdf       CL: disturbance vs subdued response
%   f4_decomp_schematic.pdf          Actual = Global + Stim-only (residual), OL means
%   f4_disturb_pertrial.pdf          per-trial RR, exemplar OL vs CL trials (ranksum p)
%   f4_disturb_rejection_paired.pdf  per-session RR, OL->CL paired (signrank p, n win)
%
% DATA: per-session + exemplar per-trial RR from imp_reject_across_sessions_ridge.mat
%   (per-trial rho stored per session; RR_settled = rho^2). Exemplar TRACES are rebuilt
%   from the single session via imp_build_session (lazy 1-session load -- no OOM).
%
% Run:  r_lean = 1; load_sessions;   % registry only (mn/td/en), no heavy data
%       f4_disturb_rejection
% (If mouse/fields are absent it builds the lean registry itself.)

root = 'C:\Users\aditya\Documents\projects\brain_paper';
addpath(fullfile(root,'utils')); addpath(fullfile(root,'controller-analysis'));

% --- session registry (skeleton only if not already loaded) --------------------
if ~exist('mouse','var') || ~exist('fields','var')
    r_lean = 1; load_sessions;   %#ok<*NASGU>  clears all except r_lean, builds mouse/fields
    root = 'C:\Users\aditya\Documents\projects\brain_paper';
    addpath(fullfile(root,'utils')); addpath(fullfile(root,'controller-analysis'));
end

dd      = fullfile(root,'controller-analysis','data');           % Stage-1/2 + reject caches
outfig  = fullfile(root,'paper','images','figure4');             % paper panels (PDF)
outview = fullfile(root,'controller-analysis','_preview');       % PNG previews (git-ignored)
if ~exist(outfig,'dir');  mkdir(outfig);  end
if ~exist(outview,'dir'); mkdir(outview); end
EXTAG = 'AL_0033_0415_e2';   % most stim-blind model-example session
CFG   = struct('nSV_load',500,'Fs',35,'pre_s',1.0,'resp_s',3.0);

[~, pmode] = ctrl_pred_tag();
assert(strcmp(pmode,'ridge'), ...
    'f4_disturb_rejection: deployed predictor is ''%s'', expected ''ridge'' (the selected one).', pmode);

PS = paperStyle(); setPaperDefaults();
col_ol = PS.col_ol; col_cl = PS.col_cl; grey = [.45 .45 .45];
W = 6; H = 4.5;   % paper panel size (cm)

%% ---- build the exemplar session (single-session lazy load) -------------------
selField = [];
for k = 1:numel(fields)
    M = mouse.(fields{k});
    if strcmp(sprintf('%s_%s%s_e%d',M.mn,M.td(6:7),M.td(9:10),M.en), EXTAG); selField = k; break; end
end
assert(~isempty(selField), 'exemplar %s not found in registry', EXTAG);
fld = fields{selField}; M = mouse.(fld);
if ~isfield(mouse.(fld),'d') || isempty(mouse.(fld).d)
    pth = fullfile(root,'data', sprintf('%sctrl%s%s%d.mat', M.mn, M.td(6:7), M.td(9:10), M.en));
    assert(exist(pth,'file')==2, 'exemplar raw cache missing: %s', pth);
    tmp = load(pth); mouse.(fld).d = tmp.d; mouse.(fld).data = tmp.data; clear tmp;
    if ~isfield(mouse.(fld).d,'ref'); mouse.(fld).d.ref = -5; end
end
b = imp_build_session(mouse, fields, selField, dd, CFG);
assert(b.ok, 'exemplar build failed: %s', b.msg);
Rex = imp_reject_core(b.Aol, b.Gol, b.Acl, b.Gcl, b.pre, b.Fs, b.resp_s, b.ref);
ref = b.ref;
fprintf('exemplar %s: nOL=%d nCL=%d | RR med OL %.2f -> CL %.2f | ranksum p=%.2e\n', ...
    EXTAG, Rex.n_ol, Rex.n_cl, Rex.rr_med_ol, Rex.rr_med_cl, Rex.p_rr);

%% ===== PANELS 1-2 : OL / CL response (disturbance vs subdued response) =========
tt = b.tt; iwin = tt>=-1 & tt<=b.resp_s; T = tt(iwin);
msem = @(X) deal(mean(X(:,iwin),1), std(X(:,iwin),0,1)./sqrt(size(X,1)));
CE = {'open loop', b.Aol, b.Gol, col_ol, 'f4_disturb_ol_response'; ...
      'closed loop',b.Acl, b.Gcl, col_cl, 'f4_disturb_cl_response'};
for c = 1:2
    [Am,Ae] = msem(CE{c,2}); [Gm,Ge] = msem(CE{c,3}); cc = CE{c,4};
    f = paperFig(W,H); ax = axes(f); hold(ax,'on');
    yl = [min([Gm-Ge Am-Ae ref])-0.6, max([Gm+Ge Am+Ae])+0.6];
    patch(ax,[1 b.resp_s b.resp_s 1],[yl(1) yl(1) yl(2) yl(2)],[.93 .93 .93],'EdgeColor','none','HandleVisibility','off');
    yline(ax,ref,'--','Color',[.3 .3 .3],'LineWidth',PS.lw_ref,'HandleVisibility','off');
    xline(ax,0,':','Color',[.6 .6 .6],'LineWidth',PS.lw_zero,'HandleVisibility','off');
    fill(ax,[T fliplr(T)],[Gm+Ge fliplr(Gm-Ge)],grey,'FaceAlpha',PS.fa,'EdgeColor','none','HandleVisibility','off');
    fill(ax,[T fliplr(T)],[Am+Ae fliplr(Am-Ae)],cc,'FaceAlpha',PS.fa,'EdgeColor','none','HandleVisibility','off');
    hD = plot(ax,T,Gm,'-','Color',grey,'LineWidth',PS.lw_fit);
    hA = plot(ax,T,Am,'-','Color',cc,'LineWidth',PS.lw_mean);
    xlim(ax,[-1 b.resp_s]); ylim(ax,yl);
    xlabel(ax,'time from stim (s)','FontSize',PS.fs,'FontWeight',PS.fw);
    ylabel(ax,'\DeltaF/F (%)','FontSize',PS.fs,'FontWeight',PS.fw);
    set(ax,'FontSize',PS.fs,'FontWeight',PS.fw);
    rr = (c==1)*Rex.rr_med_ol + (c==2)*Rex.rr_med_cl;
    title(ax,sprintf('%s   RR = %.2f',CE{c,1},rr),'FontSize',PS.fs,'FontWeight',PS.fw);
    if c==1
        lg = legend(ax,[hD hA],{'disturbance','subdued response'},'Location','southeast','Box','off');
        lg.ItemTokenSize = PS.lgd_token; lg.FontSize = PS.fs;
    end
    cleanAxes(ax);
    paperExport(f, fullfile(outfig,[CE{c,5} '.pdf']));
    paperExport(f, fullfile(outview,[CE{c,5} '.png']));
end

%% ===== PANEL 3 : decomposition schematic  Actual = Global + Stim-only ==========
A = mean(b.Aol(:,iwin),1); G = mean(b.Gol(:,iwin),1); Lr = A - G;   % Actual, Global, Stim-only residual
cA = [.15 .15 .15]; cG = [.45 .45 .45]; cL = [.85 .35 .1];
yl = [min([A G Lr])-0.6, max([A G Lr])+0.6];
f = figure('Color','w','Units','centimeters','Position',[2 2 18 5.8]);
pos = {[0.055 0.14 0.235 0.46],[0.395 0.14 0.235 0.46],[0.735 0.14 0.235 0.46]};
dat = {A,cA,'Actual  (measured ipsi)'; G,cG,'Global  (disturbance)'; Lr,cL,'Stim-only  (residual)'};
for i = 1:3
    ax = axes('Position',pos{i}); hold(ax,'on');
    patch(ax,[1 b.resp_s b.resp_s 1],[yl(1) yl(1) yl(2) yl(2)],[.93 .93 .93],'EdgeColor','none');
    yline(ax,0,':','Color',[.7 .7 .7]); xline(ax,0,':','Color',[.7 .7 .7]);
    plot(ax,T,dat{i,1},'-','Color',dat{i,2},'LineWidth',1.8);
    xlim(ax,[-1 b.resp_s]); ylim(ax,yl); box(ax,'off'); set(ax,'TickDir','out','FontSize',7.5);
    xlabel(ax,'time (s)','FontSize',7.5);
    if i==1, ylabel(ax,'\DeltaF/F (%)','FontSize',7.5); else, set(ax,'YTickLabel',[]); end
    title(ax,dat{i,3},'FontSize',9.5,'FontWeight','bold','Color',dat{i,2});
end
annotation(f,'textbox',[0.305 0.30 0.06 0.2],'String','=','FontSize',26,'EdgeColor','none','HorizontalAlignment','center','VerticalAlignment','middle');
annotation(f,'textbox',[0.645 0.30 0.06 0.2],'String','+','FontSize',26,'EdgeColor','none','HorizontalAlignment','center','VerticalAlignment','middle');
axg = axes('Position',[0.478 0.715 0.066 0.10]); hold(axg,'on'); axis(axg,'off'); xlim(axg,[-0.1 3.1]); ylim(axg,[-0.1 3.1]);
for r=0:2, for c=0:2, rectangle(axg,'Position',[c r 0.82 0.82],'Curvature',0.15,'FaceColor',[.78 .84 .93],'EdgeColor',[.42 .52 .72],'LineWidth',0.6); end; end
annotation(f,'textbox',[0.36 0.825 0.30 0.045],'String','predicted from contralateral pixels','FontSize',8,'Color',[.30 .40 .62],'EdgeColor','none','HorizontalAlignment','center','FontWeight','bold');
annotation(f,'arrow',[0.511 0.511],[0.700 0.665],'Color',[.42 .52 .72],'LineWidth',1.3,'HeadLength',7,'HeadWidth',7);
annotation(f,'textbox',[0 0.905 1 0.08],'String','Actual  =  Global  +  Stim-only (residual)','FontSize',12.5,'FontWeight','bold','EdgeColor','none','HorizontalAlignment','center');
exportgraphics(f, fullfile(outfig,'f4_decomp_schematic.pdf'),'ContentType','vector');
exportgraphics(f, fullfile(outview,'f4_decomp_schematic.png'),'Resolution',220);

%% ===== PANEL 4 : per-trial disturbance rejection (exemplar, OL vs CL) ==========
eo = Rex.rr_ol(isfinite(Rex.rr_ol) & Rex.rr_ol>0);
ec = Rex.rr_cl(isfinite(Rex.rr_cl) & Rex.rr_cl>0);
p_ex = ranksum(eo,ec);
rng(3,'twister'); jx = @(n) (rand(n,1)-0.5)*0.28;
f = paperFig(W,H); ax = axes(f); hold(ax,'on');
yline(ax,1,'--','Color',[.55 .55 .55],'LineWidth',1,'HandleVisibility','off');
scatter(ax,1+jx(numel(eo)),eo,7,col_ol,'filled','MarkerFaceAlpha',.55,'MarkerEdgeColor','none');
scatter(ax,2+jx(numel(ec)),ec,7,col_cl,'filled','MarkerFaceAlpha',.55,'MarkerEdgeColor','none');
plot(ax,[0.72 1.28],[median(eo) median(eo)],'-','Color',col_ol*0.6,'LineWidth',2);
plot(ax,[1.72 2.28],[median(ec) median(ec)],'-','Color',col_cl*0.6,'LineWidth',2);
set(ax,'YScale','log');
set(ax,'XTick',[1 2],'XTickLabel',{sprintf('OL (n=%d)',numel(eo)),sprintf('CL (n=%d)',numel(ec))});
xlim(ax,[.6 2.4]);
ylabel(ax,'RR = ||A-ref||^2 / ||G||^2','FontSize',PS.fs,'FontWeight',PS.fw);
set(ax,'FontSize',PS.fs,'FontWeight',PS.fw);
title(ax,sprintf('per-trial rejection  (ranksum p = %s)', pstr(p_ex)),'FontSize',PS.fs,'FontWeight',PS.fw);
text(ax,2.36,1,'1','FontSize',PS.fs,'Color',[.5 .5 .5],'HorizontalAlignment','left','VerticalAlignment','middle');
cleanAxes(ax);
paperExport(f, fullfile(outfig,'f4_disturb_pertrial.pdf'));
paperExport(f, fullfile(outview,'f4_disturb_pertrial.png'));

%% ===== PANEL 5 : per-session disturbance rejection (all sessions, paired) ======
L = load(fullfile(dd,'imp_reject_across_sessions_ridge.mat')); XS = L.XSr; Q = XS.Q; nS = numel(Q);
rr_ol = arrayfun(@(q) median(q.rho_ol.^2), Q).';   % RR settled = rho^2, per session median
rr_cl = arrayfun(@(q) median(q.rho_cl.^2), Q).';
p_sess = signrank(rr_ol, rr_cl); nwin = nnz(rr_ol > rr_cl);
fprintf('per-session RR: median OL %.3f -> CL %.3f | CL<OL %d/%d | signrank p=%.2e\n', ...
    median(rr_ol), median(rr_cl), nwin, nS, p_sess);
f = paperFig(W,H); ax = axes(f); hold(ax,'on');
for k=1:nS, plot(ax,[1 2],[rr_ol(k) rr_cl(k)],'-','Color',[.75 .75 .75],'LineWidth',0.5,'HandleVisibility','off'); end
yline(ax,1,'--','Color',[.55 .55 .55],'LineWidth',1,'HandleVisibility','off');
scatter(ax,ones(nS,1),rr_ol,9,col_ol,'filled','MarkerFaceAlpha',.85);
scatter(ax,2*ones(nS,1),rr_cl,9,col_cl,'filled','MarkerFaceAlpha',.85);
plot(ax,[1 2],[median(rr_ol) median(rr_cl)],'-k','LineWidth',1.6);
set(ax,'YScale','log');
set(ax,'XTick',[1 2],'XTickLabel',{'open loop','closed loop'}); xlim(ax,[.7 2.3]);
ylim(ax,[min([rr_ol;rr_cl])*0.8, max([rr_ol;rr_cl])*1.25]);
ylabel(ax,'RR = ||A-ref||^2 / ||G||^2','FontSize',PS.fs,'FontWeight',PS.fw);
set(ax,'FontSize',PS.fs,'FontWeight',PS.fw);
title(ax,sprintf('n=%d, %d/%d CL<OL, signrank p=%s',nS,nwin,nS,pstr(p_sess)),'FontSize',PS.fs,'FontWeight',PS.fw);
text(ax,2.36,1,'1','FontSize',PS.fs,'Color',[.5 .5 .5],'HorizontalAlignment','left','VerticalAlignment','middle');
cleanAxes(ax);
paperExport(f, fullfile(outfig,'f4_disturb_rejection_paired.pdf'));
paperExport(f, fullfile(outview,'f4_disturb_rejection_paired.png'));

fprintf('\n[f4_disturb_rejection] wrote 5 panels -> %s\n', outfig);

% ---- local: compact p-value string --------------------------------------------
function s = pstr(p)
    if p < 1e-3, s = sprintf('%.1e',p); else, s = sprintf('%.3f',p); end
end
