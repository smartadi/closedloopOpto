%% f4_row2_stats.m -- Session-aware stats for the Fig-4 Row-2 OL/CL state-quartile panels (Nick).
% Companion to f4_row2_quartiles.m (panels f4_2A initdev / f4_2B motion / f4_2C delta).
% Outcome = disturbance-rejection RMSE (||dFk-ref|| over [+1,+3]s), same as ctrl_distrej_quartiles.m.
% States: initdev |dFk_0-ref|, motion (MEAN z-motion over full -2..+3s window), delta (cl_reldelta 2-4Hz).
% LMM  RMSE ~ cond*state_wc + (1+cond|sess) + (1|mouse)  (state centered WITHIN session):
%   cond:state_wc interaction = does CL change the within-session state-slope (DECOUPLING);
%   cond main effect = OL-CL gap. Plus hierarchical bootstrap (mouse->session->trial) of mean
%   per-session (slope_CL - slope_OL).  SCRIPT: needs base mouse/fields (load_sessions).
% Writes f4_2S_stats.pdf/.png/.mat -> paper/images/figure4.
root='C:\Users\aditya\Documents\projects\brain_paper'; addpath(fullfile(root,'utils'));
outview=fullfile(root,'paper','images','figure4');
ref=-5; c0=36; c1=71; c2=141; dur=3; DOPT=struct('pre',2,'post',3);
states={'initdev','motion','delta'};
POOL=struct(); for s=states, POOL.(s{1})=table(); end

for k=1:numel(fields)
  M=mouse.(fields{k}); if ~isfield(M,'data'), continue; end; d=M.data;
  if ~isfield(d,'ncDfk')||isempty(d.ncDfk), continue; end
  yOL=sqrt(mean((d.ncDfk(:,c1:c2)-ref).^2,2)); yCL=sqrt(mean((d.wcDfk(:,c1:c2)-ref).^2,2));
  S=struct();
  S.initdev={abs(d.ncDfk(:,c0)-ref), abs(d.wcDfk(:,c0)-ref)};
  if isfield(M,'has_motion')&&M.has_motion&&isfield(d,'ncmotion')&&any(d.ncmotion(:))
    S.motion={mean(d.ncmotion,2), mean(d.wcmotion,2)};   % MEAN motion over full -2..+3s window (user)
  else, S.motion={nan(numel(yOL),1),nan(numel(yCL),1)}; end
  if isfield(d,'pncDfk_l')&&~isempty(d.pncDfk_l)&&isfield(d,'pwcDfk_l')&&~isempty(d.pwcDfk_l)
    S.delta={cl_reldelta(d.pncDfk_l,106,35,DOPT), cl_reldelta(d.pwcDfk_l,106,35,DOPT)};
  else, S.delta={nan(numel(yOL),1),nan(numel(yCL),1)}; end
  for s=states, nm=s{1};
    xO=S.(nm){1}; xC=S.(nm){2};
    if all(isnan(xO))||all(isnan(xC)), continue; end
    y=[yOL;yCL]; x=[xO;xC]; cond=[zeros(numel(yOL),1);ones(numel(yCL),1)];
    ok=isfinite(y)&isfinite(x); if nnz(ok)<16, continue; end
    t=table(y(ok),categorical(cond(ok),[0 1],{'OL','CL'}),x(ok), ...
        repmat(k,nnz(ok),1), repmat(string(M.mn),nnz(ok),1), 'VariableNames',{'y','cond','x','sess','mouse'});
    POOL.(nm)=[POOL.(nm); t];
  end
end

fprintf('\n================ SESSION-AWARE OL/CL STATE-DEPENDENCE STATS ================\n');
lab=struct('initdev','init-dev','motion','motion (mean, -2..+3s)','delta','rel 2-4Hz delta');
R=struct('name',{},'gap',{},'gapCI',{},'gapP',{},'dec',{},'decCI',{},'decP',{},'boot',{},'bootCI',{},'bootP',{});
for s=states, nm=s{1}; T=POOL.(nm);
  if isempty(T), fprintf('\n[%s] no data\n',nm); continue; end
  T.xw=zeros(height(T),1); us=unique(T.sess);
  for i=1:numel(us), m=T.sess==us(i); T.xw(m)=T.x(m)-mean(T.x(m)); end
  T.xw=T.xw/std(T.xw);
  fprintf('\n---- STATE: %s ----  (%d trials, %d sessions, %d mice)\n', lab.(nm), height(T), numel(us), numel(unique(T.mouse)));
  T.cond=reordercats(T.cond,{'OL','CL'});
  try   lme=fitlme(T,'y ~ cond*xw + (1+cond|sess) + (1|mouse)');
  catch, lme=fitlme(T,'y ~ cond*xw + (1|sess) + (1|mouse)'); fprintf('   (random-slope failed -> random intercept)\n'); end
  C=lme.Coefficients; nm2=cellstr(C.Name); getc=@(w) find(strcmp(nm2,w),1);
  rows={'cond_CL','OL-CL gap (CL vs OL, mean state)'; 'xw','state slope in OL (per SD)'; 'cond_CL:xw','CL change in slope (DECOUPLING)'};
  for r=1:size(rows,1)
    ci=getc(rows{r,1}); if isempty(ci), continue; end
    fprintf('   %-36s  b=%+.3f  95%%CI[%+.3f,%+.3f]  p=%.3g\n', rows{r,2}, C.Estimate(ci), C.Lower(ci), C.Upper(ci), C.pValue(ci));
  end
  bs=hboot(T,us,2000);
  fprintf('   hier-boot mean per-session (slope_CL - slope_OL): %+.3f  95%%CI[%+.3f,%+.3f]  p=%.3g\n', bs.est,bs.lo,bs.hi,bs.p2);
  gi=getc('cond_CL'); di=getc('cond_CL:xw');
  R(end+1)=struct('name',lab.(nm),'gap',C.Estimate(gi),'gapCI',[C.Lower(gi) C.Upper(gi)],'gapP',C.pValue(gi), ...
     'dec',C.Estimate(di),'decCI',[C.Lower(di) C.Upper(di)],'decP',C.pValue(di), ...
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
