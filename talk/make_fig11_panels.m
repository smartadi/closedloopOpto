%% make_fig11_panels.m -- split grant Fig 11 (cl_controller) into 6 per-panel PNGs.
% Individual high-res panels for LaTeX assembly (no baked panel letters / row names).
% Row 1 = constant target -> cl_c_{resp,var,rmse}.png
% Row 2 = sine target + preview -> cl_s_{resp,var,rmse}.png
% Reuses the two cached scratchpad dumps + paperStyle (no heavy recompute).
clc; close all;
addpath('C:\Users\aditya\Documents\projects\brain_paper\utils');
PS=paperStyle();
SP='C:\Users\aditya\AppData\Local\Temp\claude\C--Users-aditya-Documents-projects-brain-paper\69483c53-45a2-45f3-9e5d-0965ff7a6be0\scratchpad\';
S=load([SP 'const_fig11.mat']); Q=load([SP 'sine_fig11.mat']);

% ---------------------------------------------------------------------------
% Set GRANT=true before running to export at the EXACT widths these panels are
% printed at in the R01 (frontmatter_updated.tex fig:pid):
%   resp     0.38 x 0.73 x 0.45 x 7.5in = 67.4pt = 2.377 cm
%   var/rmse 0.29 x 0.73 x 0.45 x 7.5in = 51.4pt = 1.814 cm
% so the LaTeX scale factor is 1.0 and the font sizes below ARE the sizes on the
% page. The default 4.8 cm canvas shown at 1.81 cm is a 0.38x reduction, which
% put 6pt labels and a 5pt legend on the page at 2.3pt and 1.9pt.
% Labels are shortened because a ROTATED y-label is bounded by the plot-box
% HEIGHT (~30pt here): 'Across-trial variance' at 8pt is ~84pt and would clip.
% ---------------------------------------------------------------------------
if ~exist('GRANT','var'); GRANT=false; end
if GRANT
    OUTDIR=fullfile(fileparts(mfilename('fullpath')),'grant_pid',filesep);
    if ~exist(OUTDIR,'dir'); mkdir(OUTDIR); end
    fs=11; fsLeg=10; fsTick=6;    % bold; 14/10 too big, then ticks 8 -> 6 (user 2026-09-30)
    % Printed widths inside the draft's fig:pid wrapfigure, which is FIXED at
    % 0.55\textwidth = 297pt:
    %   resp     0.38 x 0.73 x 297pt = 82.4pt = 2.906 cm
    %   var/rmse 0.29 x 0.73 x 297pt = 62.9pt = 2.218 cm
    % At 2.2cm an 8pt y-label is nearly all the height available, so the paired
    % panels keep a SHORT y-label and drop the in-panel n, which the caption
    % carries. The axes rectangle is set explicitly below, because MATLAB
    % otherwise lets labels overflow a small canvas and exportgraphics then
    % crops to the text instead of the canvas.
    W_RESP=2.906; W_PAIR=2.218;            % target printed widths, cm
    % The two paired panels MUST carry a y-label. Blanking them (as this did at first)
    % leaves two near-identical OL-vs-CL dot plots side by side with nothing saying
    % which is which -- the caption names both quantities but not their order
    % (user 2026-09-30: "rmse and var lost their title no one knows what they are").
    % A ROTATED label is bounded by the PLOT-BOX HEIGHT, ~33pt here, so at 11pt it has
    % to be <=5 characters: 'RMSE' is ~30pt and fits, 'Across-trial variance' is ~130pt
    % and cannot. Units go in the caption.
    % 'CL' on BOTH rows, not 'CL+pv': the direct key sits in the one empty corner of
    % the trace panel (t < 0, below baseline), which is ~18pt wide, and 5 characters
    % at 8pt is ~30pt and ran straight into the sine traces. The LaTeX row title
    % already reads "B Moving reference + preview", so the panel need not repeat it.
    ylVar='Var.'; ylRmse='RMSE'; clLab={'CL','CL'};
else
    OUTDIR='C:\Users\aditya\Documents\projects\draft\latest\grant_2026_10_YazdanSteinmetz (2)\figs2\pid\';
    fs=PS.fs; fsLeg=5; fsTick=PS.fs;
    W_RESP=4.8; W_PAIR=4.8;
    ylVar='Across-trial variance'; ylRmse='Trial RMSE (%\DeltaF/F)'; clLab={'CL','CL+preview'};
end
cOL=PS.col_ol; cCL=PS.col_cl;
rows={S,Q}; tag={'c','s'};
AR=4.2/4.8;                       % keep the original aspect: the figure block
SZR=[1 1 W_RESP W_RESP*AR];       % height inside the wrapfigure is unchanged
SZP=[1 1 W_PAIR W_PAIR*AR];

for r=1:2
    D=rows{r};
    % ---------- P1: CL vs OL trace comparison (best session) ----------
    fig=figure('Color','w','Units','centimeters','Position',SZR); ax=axes(fig); hold(ax,'on');
    yl=[min([D.ol_mean-D.ol_sem, D.cl_mean-D.cl_sem]) max([D.ol_mean+D.ol_sem, D.cl_mean+D.cl_sem])];
    yl=yl+[-.08 .08]*range(yl);
    patch(ax,[D.laser(1) D.laser(2) D.laser(2) D.laser(1)],[yl(1) yl(1) yl(2) yl(2)], ...
        [0.92 0.92 0.92],'EdgeColor','none');
    band(ax,D.t,D.ol_mean,D.ol_sem,cOL); band(ax,D.t,D.cl_mean,D.cl_sem,cCL);
    hOL=plot(ax,D.t,D.ol_mean,'Color',cOL,'LineWidth',PS.lw_mean);
    hCL=plot(ax,D.t,D.cl_mean,'Color',cCL,'LineWidth',PS.lw_mean);
    if r==1; plot(ax,D.laser,[D.ref D.ref],'k--','LineWidth',PS.lw_ref);
    else;    plot(ax,D.tref,D.ref,'k--','LineWidth',PS.lw_ref); end
    hold(ax,'off'); xlim(ax,[D.t(1) D.t(end)]); ylim(ax,yl);
    if ~GRANT; xlabel(ax,'Time (s)','FontSize',fs,'FontWeight','bold'); end
    ylabel(ax,tern2(GRANT,'%','\DeltaF/F (%)'),'FontSize',fs,'FontWeight','bold');
    stylize(ax,fs,fsTick);
    if GRANT; set(ax,'Position',[0.30 0.22 0.67 0.74]); end
    if GRANT
        % DIRECT LABELS instead of a legend box (user 2026-09-30: "they also lost OL
        % and cl legends"). A legend BOX at this width sits on the traces and runs
        % past the axes, which the exact-page print then clips -- but dropping the key
        % altogether leaves a red and a blue trace with nothing naming them. Coloured
        % text in the lower-left corner costs no box, no border and no token: both
        % rows sit near baseline for t < 0, so that corner is empty in each.
        text(ax,0.02,0.34,'OL',      'Units','normalized','Color',cOL, ...
             'FontSize',fsLeg-2,'FontWeight','bold','VerticalAlignment','middle');
        text(ax,0.02,0.20,clLab{r},  'Units','normalized','Color',cCL, ...
             'FontSize',fsLeg-2,'FontWeight','bold','VerticalAlignment','middle');
    else
        lg=legend([hOL hCL],{'OL',clLab{r}},'Location','southeast');
        set(lg,'Box','off','FontSize',fsLeg);
    end
    exportAtWidth(fig,[OUTDIR 'cl_' tag{r} '_resp.png'],W_RESP,GRANT); close(fig);

    % ---------- P2: variance reduction across sessions ----------
    fig=figure('Color','w','Units','centimeters','Position',SZP); ax=axes(fig);
    paired(ax,D.varOL,D.varCL,cOL,cCL,clLab{r},fs,fsTick);
    ylabel(ax,ylVar,'FontSize',fs,'FontWeight','bold');
    if GRANT; ttl=pstr(D.pVar); else; ttl=sprintf('n=%d, %s',numel(D.varOL),pstr(D.pVar)); end
    title(ax,ttl,'FontSize',fsTick,'FontWeight','bold');
    % Left margin must hold the 6pt y-ticks (~8pt) AND the 11pt rotated label (~11pt)
    % on a 63pt canvas: 0.26 was sized for no label at all and would clip it.
    if GRANT; set(ax,'Position',[0.44 0.26 0.53 0.58]); end
    exportAtWidth(fig,[OUTDIR 'cl_' tag{r} '_var.png'],W_PAIR,GRANT); close(fig);

    % ---------- P3: RMSE improvement across sessions ----------
    fig=figure('Color','w','Units','centimeters','Position',SZP); ax=axes(fig);
    if isfield(D,'medOL'); paired(ax,D.medOL,D.medCL,cOL,cCL,clLab{r},fs,fsTick); nR=numel(D.medOL);
    else;                  paired(ax,D.rmseOL,D.rmseCL,cOL,cCL,clLab{r},fs,fsTick); nR=numel(D.rmseOL); end
    ylabel(ax,ylRmse,'FontSize',fs,'FontWeight','bold');
    if GRANT; ttl=pstr(D.pRMSE); else; ttl=sprintf('n=%d, %s',nR,pstr(D.pRMSE)); end
    title(ax,ttl,'FontSize',fsTick,'FontWeight','bold');
    % Left margin must hold the 6pt y-ticks (~8pt) AND the 11pt rotated label (~11pt)
    % on a 63pt canvas: 0.26 was sized for no label at all and would clip it.
    if GRANT; set(ax,'Position',[0.44 0.26 0.53 0.58]); end
    exportAtWidth(fig,[OUTDIR 'cl_' tag{r} '_rmse.png'],W_PAIR,GRANT); close(fig);
end
fprintf('[fig11 panels] wrote 6 PNGs to %s\n',OUTDIR);

% ---- helpers (from make_fig11_grid.m) ----
function band(ax,t,m,e,c); fill(ax,[t fliplr(t)],[m+e fliplr(m-e)],c,'FaceAlpha',0.18,'EdgeColor','none'); end
function stylize(ax,fs,fsTick); set(ax,'Box','off','TickDir','out','FontSize',fsTick,'FontWeight','bold');
  set(get(ax,'XLabel'),'FontSize',fs); set(get(ax,'YLabel'),'FontSize',fs); end

function exportAtWidth(fig,path,targetCm,doFit)
% EXPORTATWIDTH  Export a PNG whose final width is EXACTLY the printed width.
% exportgraphics always tight-crops to the content bbox, and that crop margin is
% roughly constant, so shrinking the canvas to chase a target width oscillates
% instead of converging. print() with an exact paper size writes the whole
% canvas instead, which makes saved width == printed width == scale 1.0, so the
% font sizes set above are the font sizes on the page. This is only safe because
% every axes Position is set explicitly, so nothing overhangs the canvas and
% there is nothing for an exact page to clip.
  if ~doFit
      exportgraphics(fig,path,'Resolution',600); return
  end
  dpi=1200;
  p=get(fig,'Position');                 % [x y w h] in centimeters
  set(fig,'PaperUnits','centimeters','PaperSize',[targetCm p(4)], ...
          'PaperPosition',[0 0 targetCm p(4)],'PaperPositionMode','manual', ...
          'Units','centimeters','Position',[p(1) p(2) targetCm p(4)]);
  print(fig,'-dpng',sprintf('-r%d',dpi),path);
  info=imfinfo(path); gotCm=info.Width/dpi*2.54;
  fprintf('  %s -> %.3f cm (target %.3f, scale %.3f)\n', ...
          path,gotCm,targetCm,targetCm/gotCm);
end
function v=tern2(c,a,b); if c; v=a; else; v=b; end; end
function s=pstr(p)
  if isnan(p), s='n.s.'; elseif p<1e-3, s=sprintf('p=%.0e',p); else, s=sprintf('p=%.3g',p); end
end
function paired(ax,a,b,cOL,cCL,clLab,fs,fsTick)
  hold(ax,'on'); a=a(:); b=b(:);
  for i=1:numel(a); plot(ax,[1 2],[a(i) b(i)],'-','Color',[0.7 0.7 0.7],'LineWidth',0.4); end
  plot(ax,ones(size(a)),a,'o','MarkerFaceColor',cOL,'MarkerEdgeColor','none','MarkerSize',3.5);
  plot(ax,2*ones(size(b)),b,'o','MarkerFaceColor',cCL,'MarkerEdgeColor','none','MarkerSize',3.5);
  plot(ax,[0.82 1.18],[median(a) median(a)],'-','Color',cOL,'LineWidth',2);
  plot(ax,[1.82 2.18],[median(b) median(b)],'-','Color',cCL,'LineWidth',2);
  hold(ax,'off'); xlim(ax,[0.5 2.5]);
  set(ax,'XTick',[1 2],'XTickLabel',{'OL',clLab},'Box','off','TickDir','out','FontSize',fsTick,'FontWeight','bold');
  yl=ylim(ax); ylim(ax,[min(0,yl(1)) yl(2)+0.05*range(yl)]);
  % Two y ticks only: at 2.2cm the y-tick labels set the left margin, and that
  % margin is what stops the canvas shrinking to the printed width.
  if fsTick < 6.5
      yl=ylim(ax); set(ax,'YTick',[yl(1) yl(2)]);
      set(ax,'YTickLabel',compose('%.2g',get(ax,'YTick')));
      % 'OL' / 'CL' are CONDITION NAMES, not numbers, so they should not shrink with
      % the numeric ticks. MATLAB has one tick font size per axes, so draw them as
      % text instead: bigger, and coloured to match their own dots, which makes the
      % key unmistakable without a legend box (user 2026-09-30).
      set(ax,'XTickLabel',{'',''});
      xl=get(ax,'XTick'); cc={cOL,cCL}; ss={'OL',clLab};
      for k=1:2
          text(ax,xl(k),yl(1)-0.05*range(yl),ss{k},'Color',cc{k}, ...
               'FontSize',fsTick+2,'FontWeight','bold','HorizontalAlignment','center', ...
               'VerticalAlignment','top','Clipping','off');
      end
  end
end
