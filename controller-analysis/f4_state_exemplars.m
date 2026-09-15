% controller-analysis/f4_state_exemplars.m
% Fig-4 BLOCK 1 -- exemplar CL trials for the four pre-stimulus state factors.
% One representative trial per state (high init-dev / high motion / high rel 2-4 Hz /
% high abs delta), picked to be SPECIFIC to that state (high in it, low in the others).
% Each panel: the CL readout trace (dF/F, -2 -> +3 s) with reference + stim window; the
% motion panel also overlays the concurrent z-motion trace (the state you can't see in dF/F).
% Requires full load_sessions.m (mouse, fields, .data in base).
clc; close all;
PS=paperStyle(); setPaperDefaults();
root='C:\Users\aditya\Documents\projects\brain_paper';
outfig=fullfile(root,'paper','images','figure4');
outview=fullfile(root,'controller-analysis','_preview'); if ~exist(outview,'dir'); mkdir(outview); end
Fs=35; c0=36; c0_mot=71; c0_l=106; mot_pre=2; spec_pre_s=2; spec_post_s=3;
delta_bnd=[1 4]; hi_bnd=[2 4]; tot_bnd=[0.4 10];
bp=@(seg,lo,hi) local_bandpow(seg,Fs,lo,hi);

% ---- pool the 4 states (keep session+trial refs) ----
X1=[];X2=[];Xrel=[];Xdel=[];SESS=[];TRI=[];
for k=1:numel(fields)
    s=mouse.(fields{k});
    if (isfield(s,'skip')&&s.skip)||~isfield(s,'data')||~s.has_motion; continue; end
    dk=s.data; if ~isfield(dk,'wcmotion'); continue; end
    ref=s.d.ref; dur=s.d.params.dur; nT=size(dk.wcDfk,1);
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
    X1=[X1;x1];X2=[X2;x2];Xrel=[Xrel;xrel];Xdel=[Xdel;xdel]; %#ok<*AGROW>
    SESS=[SESS;repmat(k,nT,1)];TRI=[TRI;(1:nT)'];
end
ok=all(isfinite([X1 X2 Xrel Xdel]),2)&Xdel>0; f=@(v)v(ok);
[X1,X2,Xrel,Xdel,SESS,TRI]=deal(f(X1),f(X2),f(Xrel),f(Xdel),f(SESS),f(TRI));
Z=zscore([X1 X2 Xrel log10(Xdel)]);            % z of the 4 states
lbl={'high initial deviation','high motion','high rel 2-4 Hz','high abs \delta'};
col=[0.20 0.40 0.75; 0.75 0.40 0.10; 0.35 0.55 0.30; 0.55 0.25 0.60];

% ---- pick a SPECIFIC exemplar per state: max (z_target - max other z), z_target>1 ----
pick=nan(1,4);
for j=1:4
    others=setdiff(1:4,j); spec=Z(:,j)-max(Z(:,others),[],2); spec(Z(:,j)<1)=-inf;
    [~,pick(j)]=max(spec);
end
fprintf('[f4_state_exemplars] picks (session tr | z1 z2 z3 z4):\n');
for j=1:4, i=pick(j); fprintf('  %-20s %s tr%d | %+.1f %+.1f %+.1f %+.1f\n', ...
        lbl{j}, fields{SESS(i)}, TRI(i), Z(i,1),Z(i,2),Z(i,3),Z(i,4)); end

% ---- figure: 1x4 exemplar traces ----
fig=paperFig(18,4.6); tl=tiledlayout(fig,1,4,'TileSpacing','compact','Padding','compact');
tv=(-spec_pre_s:1/Fs:spec_post_s).';
for j=1:4
    ax=nexttile(tl); i=pick(j); dk=mouse.(fields{SESS(i)}).data; ref=mouse.(fields{SESS(i)}).d.ref;
    seg=dk.pwcDfk_l(TRI(i), c0_l-spec_pre_s*Fs : c0_l+spec_post_s*Fs);
    hold(ax,'on');
    patch(ax,[0 3 3 0],[-16 -16 10 10],[.9 .9 .9],'EdgeColor','none','FaceAlpha',.5,'HandleVisibility','off');
    plot(ax,tv([1 end]),[ref ref],'--','Color',[.3 .3 .3],'LineWidth',PS.lw_ref,'HandleVisibility','off');
    xline(ax,0,':','Color',[.6 .6 .6],'HandleVisibility','off');
    % motion overlay for the motion exemplar (z-motion, scaled into view)
    if j==2 && isfield(dk,'wcmotion')
        wm=dk.wcmotion(TRI(i), c0_mot-mot_pre*Fs : min(size(dk.wcmotion,2),c0_mot+spec_post_s*Fs));
        tvm=(-mot_pre:1/Fs:spec_post_s).'; tvm=tvm(1:numel(wm));
        wmz=(wm-mean(wm))/max(std(wm),eps); wmz=wmz*2 - 11;      % scale + offset to lower part
        plot(ax,tvm,wmz,'-','Color',[.55 .55 .55],'LineWidth',0.8);
        text(ax,-1.9,-8,'z-motion','Color',[.5 .5 .5],'FontSize',PS.fs-1,'FontWeight',PS.fw);
    end
    plot(ax,tv,seg,'-','Color',col(j,:),'LineWidth',PS.lw_mean);
    xlim(ax,[-spec_pre_s spec_post_s]); ylim(ax,[-16 10]);
    set(ax,'Box','off','TickDir','out','FontSize',PS.fs,'FontWeight',PS.fw);
    xlabel(ax,'time from stim (s)','FontSize',PS.fs,'FontWeight',PS.fw);
    if j==1, ylabel(ax,'\DeltaF/F (%)','FontSize',PS.fs,'FontWeight',PS.fw); end
    title(ax,lbl{j},'FontSize',PS.fs,'FontWeight',PS.fw,'Color',col(j,:));
end
title(tl,'Exemplar closed-loop trials by pre-stimulus state','FontSize',PS.fs+1,'FontWeight','bold');
exportgraphics(fig,fullfile(outfig,'f4_state_exemplars.pdf'),'ContentType','vector');
exportgraphics(fig,fullfile(outview,'f4_state_exemplars.png'),'Resolution',220);
fprintf('[f4_state_exemplars] wrote 4-state exemplar row -> %s\n',outfig);

function p=local_bandpow(seg,Fs,lo,hi)
    seg=detrend(double(seg(:)).','linear'); N=numel(seg); w=hann(N).';
    P=abs(fft(seg.*w)).^2; P=P(1:floor(N/2)+1); fr=(0:floor(N/2))*Fs/N; p=sum(P(fr>=lo&fr<hi));
end
