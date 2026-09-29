% controller-analysis/f4_state_exemplars_supp.m
% SUPPLEMENTARY: the four state exemplars (high init-dev / motion / rel 2-4 Hz / abs delta)
% shown for EVERY motion session, so the reader can see the exemplar pattern is not specific to
% the one representative session used in main Fig 4A. Grid: rows = sessions, cols = 4 states.
% Best exemplar per state PER SESSION (max specificity, z within that session). Same colours as
% main Fig 4A. Requires full load_sessions.m (mouse, fields in base).
clc; close all;
PS=paperStyle(); setPaperDefaults();
root='C:\Users\aditya\Documents\projects\brain_paper';
outsupp=fullfile(root,'paper','images','supplementary'); if ~exist(outsupp,'dir'); mkdir(outsupp); end
outview=fullfile(root,'controller-analysis','_preview'); if ~exist(outview,'dir'); mkdir(outview); end
Fs=35; c0=36; c0_mot=71; c0_l=106; c1=71; c2=141; mot_pre=2; spec_pre_s=2; spec_post_s=3;
delta_bnd=[1 4]; hi_bnd=[2 4]; tot_bnd=[0.4 10];
bp=@(seg,lo,hi) local_bandpow(seg,Fs,lo,hi);
col=[0.20 0.40 0.75; 0.75 0.40 0.10; 0.35 0.55 0.30; 0.55 0.25 0.60];
lbl={'high initial deviation','high motion','high rel 2-4 Hz','high abs \delta'};

% ---- collect per-session exemplar picks ----
sessMn={}; picks={}; segs={}; mcount=containers.Map('KeyType','char','ValueType','double');
for k=1:numel(fields)
    s=mouse.(fields{k});
    if (isfield(s,'skip')&&s.skip)||~isfield(s,'data')||~s.has_motion; continue; end
    dk=s.data; if ~isfield(dk,'wcmotion')||~isfield(dk,'wcDfk')||isempty(dk.wcDfk)||~any(dk.wcmotion(:)); continue; end
    ref=s.d.ref; dur=s.d.params.dur; nT=size(dk.wcDfk,1);
    y=sqrt(mean((dk.wcDfk(:,c1:c2)-ref).^2,2));
    x1=abs(dk.wcDfk(:,c0)-ref);
    ws=max(1,c0_mot-round(mot_pre*Fs)); we=min(size(dk.wcmotion,2),c0_mot+round(dur*Fs)-1);
    x2=mean(dk.wcmotion(1:nT,ws:we).^2,2);
    sa=c0_l-round(spec_pre_s*Fs); sb=c0_l+round(spec_post_s*Fs);
    [xrel,xdel]=deal(nan(nT,1));
    for t=1:nT
        seg=double(dk.pwcDfk_l(t,sa:sb));
        xdel(t)=bp(seg,delta_bnd(1),delta_bnd(2));
        xrel(t)=bp(seg,hi_bnd(1),hi_bnd(2))/max(bp(seg,tot_bnd(1),tot_bnd(2)),eps);
    end
    ok=all(isfinite([x1 x2 xrel xdel y]),2)&xdel>0; idx=find(ok);
    if numel(idx)<8; continue; end
    Z=zscore([x1(idx) x2(idx) xrel(idx) log10(xdel(idx))]);
    pk=nan(1,4);
    for j=1:4
        others=setdiff(1:4,j); spec=Z(:,j)-max(Z(:,others),[],2); spec(Z(:,j)<1)=-inf;
        [mx,ii]=max(spec); if ~isfinite(mx); [~,ii]=max(Z(:,j)); end
        pk(j)=idx(ii);
    end
    if isKey(mcount,s.mn); mcount(s.mn)=mcount(s.mn)+1; else; mcount(s.mn)=1; end
    tag=sprintf('%s %c', s.mn, 'a'+mcount(s.mn)-1);   % e.g. AL_0033 a, AL_0033 b, ...
    sessMn{end+1}=tag; picks{end+1}=pk; segs{end+1}=dk; %#ok<SAGROW>
end
nS=numel(picks); fprintf('[f4_exemplars_supp] %d motion sessions.\n',nS);

% ---- grid: rows = sessions, cols = 4 states ----
fig=paperFig(16, 2.7*nS); tl=tiledlayout(fig,nS,4,'TileSpacing','compact','Padding','compact');
tv=(-spec_pre_s:1/Fs:spec_post_s).'; yl=[-16 10];
for r=1:nS
    dk=segs{r}; ref=-5; pk=picks{r};
    for j=1:4
        ax=nexttile(tl); tri=pk(j); hold(ax,'on');
        seg=dk.pwcDfk_l(tri, c0_l-spec_pre_s*Fs : c0_l+spec_post_s*Fs);
        patch(ax,[0 3 3 0],[yl(1) yl(1) yl(2) yl(2)],[.9 .9 .9],'EdgeColor','none','FaceAlpha',.5,'HandleVisibility','off');
        plot(ax,tv([1 end]),[ref ref],'--','Color',[.3 .3 .3],'LineWidth',PS.lw_ref,'HandleVisibility','off');
        xline(ax,0,':','Color',[.6 .6 .6],'HandleVisibility','off');
        plot(ax,tv,seg,'-','Color',col(j,:),'LineWidth',PS.lw_mean);
        xlim(ax,[-spec_pre_s spec_post_s]); ylim(ax,yl);
        if r==1; title(ax,lbl{j},'FontSize',PS.fs,'FontWeight',PS.fw,'Color',col(j,:)); end
        if j==1
            ylabel(ax,strrep(sessMn{r},'_','\_'),'FontSize',PS.fs,'FontWeight',PS.fw);
            shortCornerAxes_plot(ax,'Corner','bl','XLength',1,'YLength',5,'XLabel','1 s','YLabel','5%', ...
                'LineWidth',PS.sca_lw,'LabelGap',PS.sca_gap,'FontSize',PS.fs,'FontWeight',PS.fw);
        else
            shortCornerAxes_plot(ax,'Corner','bl','XLength',1,'YLength',0,'XLabel','1 s', ...
                'LineWidth',PS.sca_lw,'LabelGap',PS.sca_gap,'FontSize',PS.fs,'FontWeight',PS.fw);
        end
    end
end
exportgraphics(fig,fullfile(outsupp,'f4_exemplars_sessions.pdf'),'ContentType','vector');
exportgraphics(fig,fullfile(outview,'f4_exemplars_sessions.png'),'Resolution',180);
fprintf('[f4_exemplars_supp] wrote %d-session exemplar grid -> %s\n',nS,outsupp);

function p=local_bandpow(seg,Fs,lo,hi)
    seg=detrend(double(seg(:)).','linear'); N=numel(seg); w=hann(N).';
    P=abs(fft(seg.*w)).^2; P=P(1:floor(N/2)+1); fr=(0:floor(N/2))*Fs/N; p=sum(P(fr>=lo&fr<hi));
end
