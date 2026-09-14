%% f4_row2_stats.m -- Session-aware stats for the Fig-4 Row-2 OL/CL state-quartile panels (Nick).
% Companion to f4_row2_quartiles.m (panels f4_2A initdev / f4_2B motion / f4_2C delta).
% Pooling + LMM come from the SHARED helpers f4_row2_pool / f4_row2_fit, so the decoupling
% p reported here is IDENTICAL to the star printed on the panels (no drift possible).
%   outcome = disturbance-rejection RMSE ||dFk-ref|| over [+1,+3]s (raw);
%   states  = initdev, motion (MEAN z-motion over -2..+3s, no rectify), delta (rel 2-4Hz);
%   model   = RMSE ~ cond*state_wc + (1+cond|sess) + (1|mouse)  (state centered WITHIN session):
%             cond:state_wc interaction = does CL change the within-session state-slope (DECOUPLING);
%             cond main effect = OL-CL gap. Plus hierarchical bootstrap (mouse->session->trial)
%             of mean per-session (slope_CL - slope_OL).  SCRIPT: needs base mouse/fields.
% Writes f4_2S_stats.pdf/.png/.mat -> paper/images/figure4.
root='C:\Users\aditya\Documents\projects\brain_paper'; addpath(fullfile(root,'utils'));
outview=fullfile(root,'paper','images','figure4');
states={'initdev','motion','delta'};
[POOL,~]=f4_row2_pool(mouse,fields);

fprintf('\n================ SESSION-AWARE OL/CL STATE-DEPENDENCE STATS ================\n');
lab=struct('initdev','init-dev','motion','motion (mean, -2..+3s)','delta','rel 2-4Hz delta');
R=struct('name',{},'gap',{},'gapCI',{},'gapP',{},'dec',{},'decCI',{},'decP',{},'boot',{},'bootCI',{},'bootP',{});
for s=states, nm=s{1}; T=POOL.(nm);
  if isempty(T), fprintf('\n[%s] no data\n',nm); continue; end
  [Rf,T]=f4_row2_fit(T); us=unique(T.sess);
  fprintf('\n---- STATE: %s ----  (%d trials, %d sessions, %d mice)%s\n', lab.(nm), height(T), ...
      numel(us), numel(unique(T.mouse)), tern(Rf.randslope,'',' [random-intercept fallback]'));
  fprintf('   %-36s  b=%+.3f  95%%CI[%+.3f,%+.3f]  p=%.3g\n','OL-CL gap (CL vs OL, mean state)',Rf.gap,Rf.gapCI(1),Rf.gapCI(2),Rf.gapP);
  fprintf('   %-36s  b=%+.3f\n','state slope in OL (per SD)',Rf.slope);
  fprintf('   %-36s  b=%+.3f  95%%CI[%+.3f,%+.3f]  p=%.3g\n','CL change in slope (DECOUPLING)',Rf.dec,Rf.decCI(1),Rf.decCI(2),Rf.decP);
  bs=hboot(T,us,2000);
  fprintf('   hier-boot mean per-session (slope_CL - slope_OL): %+.3f  95%%CI[%+.3f,%+.3f]  p=%.3g\n', bs.est,bs.lo,bs.hi,bs.p2);
  R(end+1)=struct('name',lab.(nm),'gap',Rf.gap,'gapCI',Rf.gapCI,'gapP',Rf.gapP, ...
     'dec',Rf.dec,'decCI',Rf.decCI,'decP',Rf.decP, ...
     'boot',bs.est,'bootCI',[bs.lo bs.hi],'bootP',bs.p2); %#ok<SAGROW>
end
fprintf('\n============================================================================\n');
fprintf('cond:xw<0 with CI excluding 0 = CL FLATTENS state dependence.  cond_CL<0 = CL lower RMSE.\n');

%% ---- forest plot ----
nR=numel(R); yy=nR:-1:1;
f=figure('Color','w','Units','centimeters','Position',[2 2 20 7]);
tl=tiledlayout(f,1,2,'TileSpacing','compact','Padding','compact');
% (a) OL-CL gap
ax=nexttile(tl); hold(ax,'on'); xline(ax,0,'-','Color',[.6 .6 .6]);
for i=1:nR, plot(ax,[R(i).gapCI(1) R(i).gapCI(2)],[yy(i) yy(i)],'-','Color',[.15 .35 .7],'LineWidth',1.6);
  plot(ax,R(i).gap,yy(i),'o','MarkerFaceColor',[.15 .35 .7],'MarkerEdgeColor','none','MarkerSize',6);
  text(ax,R(i).gapCI(1)-0.03,yy(i)+0.28,sprintf('p=%.1g',R(i).gapP),'FontSize',7.5,'Color',[.3 .3 .3],'HorizontalAlignment','right'); end
set(ax,'YTick',yy(end:-1:1),'YTickLabel',{R(end:-1:1).name},'FontSize',9); ylim(ax,[.4 nR+.6]);
xlabel(ax,'OL \rightarrow CL change in RMSE  (%\DeltaF/F)','FontSize',9);
title(ax,'(a) CL vs OL gap  (negative = CL lower)','FontSize',10,'FontWeight','bold'); box(ax,'off'); set(ax,'TickDir','out');
% (b) decoupling interaction (LMM filled + bootstrap open)
ax=nexttile(tl); hold(ax,'on'); xline(ax,0,'-','Color',[.6 .6 .6]);
xtext=max([R.decCI R.bootCI])+0.06;
for i=1:nR
  plot(ax,R(i).decCI,[yy(i)+0.13 yy(i)+0.13],'-','Color',[.8 .25 .1],'LineWidth',1.6);
  plot(ax,R(i).dec,yy(i)+0.13,'o','MarkerFaceColor',[.8 .25 .1],'MarkerEdgeColor','none','MarkerSize',6);
  plot(ax,R(i).bootCI,[yy(i)-0.13 yy(i)-0.13],'-','Color',[.8 .25 .1],'LineWidth',1.2);
  plot(ax,R(i).boot,yy(i)-0.13,'o','MarkerFaceColor','w','MarkerEdgeColor',[.8 .25 .1],'MarkerSize',5,'LineWidth',1);
  text(ax,xtext,yy(i),sprintf('LMM p=%.2g\nboot p=%.2g',R(i).decP,R(i).bootP),'FontSize',7,'Color',[.3 .3 .3],'VerticalAlignment','middle');
end
set(ax,'YTick',yy(end:-1:1),'YTickLabel',{R(end:-1:1).name},'FontSize',9); ylim(ax,[.4 nR+.6]);
xlabel(ax,'CL change in state-slope  (RMSE per SD)','FontSize',9);
title(ax,'(b) Decoupling: does CL flatten state-dependence?','FontSize',10,'FontWeight','bold'); box(ax,'off'); set(ax,'TickDir','out');
xlim(ax,[min([R.decCI R.bootCI])-0.05, xtext+0.55]);
text(ax,xtext,0.62,'\bullet filled = LMM   \circ open = hier-boot','FontSize',6.5,'Color',[.5 .5 .5]);
title(tl,'Session-aware OL/CL stats: linear mixed model (session nested in mouse) + hierarchical bootstrap','FontSize',10,'FontWeight','bold');
exportgraphics(f,fullfile(outview,'f4_2S_stats.pdf'),'ContentType','vector');
exportgraphics(f,fullfile(outview,'f4_2S_stats.png'),'Resolution',220);
save(fullfile(outview,'f4_2S_stats.mat'),'R');
fprintf('wrote f4_2S_stats forest plot -> %s\n',outview);

%% ---- local functions ----
function s=tern(c,a,b); if c, s=a; else, s=b; end; end

function B=hboot(T,us,nB)
mice=unique(T.mouse); rng(11); est=local_sessdiff(T); bd=nan(nB,1);
for bI=1:nB
  mb=mice(randi(numel(mice),numel(mice),1)); rowsB=[];
  for mm=1:numel(mb)
    sm=us(ismember(us,unique(T.sess(T.mouse==mb(mm))))); if isempty(sm), continue; end
    sb=sm(randi(numel(sm),numel(sm),1));
    for ss=1:numel(sb)
      idx=find(T.sess==sb(ss)); if isempty(idx), continue; end
      rowsB=[rowsB; idx(randi(numel(idx),numel(idx),1))]; %#ok<AGROW>
    end
  end
  if ~isempty(rowsB), bd(bI)=local_sessdiff(T(rowsB,:)); end
end
bd=bd(isfinite(bd)); B.est=est; B.lo=prctile(bd,2.5); B.hi=prctile(bd,97.5); B.p2=2*min(mean(bd>=0),mean(bd<=0));
end

function md=local_sessdiff(T)
us=unique(T.sess); dv=nan(numel(us),1);
for i=1:numel(us)
  m=T.sess==us(i); yy=T.y(m); xx=T.xw(m); cc=T.cond(m); oo=cc=='OL'; ll=cc=='CL';
  if nnz(oo)<4||nnz(ll)<4, continue; end
  dv(i)=polyfit_safe(xx(ll),yy(ll))-polyfit_safe(xx(oo),yy(oo));
end
md=mean(dv,'omitnan');
end

function b=polyfit_safe(x,y)
if numel(x)<2||std(x)==0, b=0; return; end; p=polyfit(x,y,1); b=p(1);
end
