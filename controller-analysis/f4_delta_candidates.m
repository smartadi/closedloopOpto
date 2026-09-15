% controller-analysis/f4_delta_candidates.m
% SELECTION AID (not a paper panel): confirm that "high abs delta (1-4 Hz power)" and
% "high relative 2-4 Hz" pick out DIFFERENT trial profiles. Shows (1) the abs-vs-rel
% scatter across all CL trials with their correlation, (2) candidate trials that
% DISSOCIATE the two (high-abs/low-rel vs high-rel/low-abs), with traces + spectra.
% Requires full load_sessions.m (mouse, fields, .data in base).
clc; close all;
PS = paperStyle();
root='C:\Users\aditya\Documents\projects\brain_paper';
outview=fullfile(root,'controller-analysis','_preview'); if ~exist(outview,'dir'); mkdir(outview); end
Fs=35; c0=36; c0_l=106; spec_pre_s=2; spec_post_s=3;
delta_bnd=[1 4]; hi_bnd=[2 4]; tot_bnd=[0.4 10];
bp=@(seg,lo,hi) local_bandpow(seg,Fs,lo,hi);

% ---- pool (keep session + trial refs) ----
Xdel=[];Xrel=[];SESS=[];TRI=[];
for k=1:numel(fields)
    s=mouse.(fields{k});
    if (isfield(s,'skip')&&s.skip)||~isfield(s,'data')||~s.has_motion; continue; end
    dk=s.data; if ~isfield(dk,'wcmotion'); continue; end
    nT=size(dk.wcDfk,1); sa=c0_l-round(spec_pre_s*Fs); sb=c0_l+round(spec_post_s*Fs);
    [xdel,xrel]=deal(nan(nT,1));
    for t=1:nT
        seg=double(dk.pwcDfk_l(t,sa:sb));
        xdel(t)=bp(seg,delta_bnd(1),delta_bnd(2));
        xrel(t)=bp(seg,hi_bnd(1),hi_bnd(2))/max(bp(seg,tot_bnd(1),tot_bnd(2)),eps);
    end
    Xdel=[Xdel;xdel];Xrel=[Xrel;xrel];SESS=[SESS;repmat(k,nT,1)];TRI=[TRI;(1:nT)']; %#ok<*AGROW>
end
ok=isfinite(Xdel)&isfinite(Xrel)&Xdel>0; Xdel=Xdel(ok);Xrel=Xrel(ok);SESS=SESS(ok);TRI=TRI(ok);
La=log10(Xdel); za=zscore(La); zr=zscore(Xrel);
r_pear=corr(La,Xrel); r_spear=corr(La,Xrel,'type','Spearman');
fprintf('[f4_delta_candidates] %d trials | corr(log abs-delta, rel 2-4Hz): Pearson %.2f, Spearman %.2f\n',numel(La),r_pear,r_spear);

% ---- dissociating candidates ----
nC=3;
absScore=za-zr; absScore(za<0.5)=-inf; [~,ia]=sort(absScore,'descend'); iA=ia(1:nC);   % high abs, low rel
relScore=zr-za; relScore(zr<0.5)=-inf; [~,ir]=sort(relScore,'descend'); iR=ir(1:nC);   % high rel, low abs
fprintf('abs-profile trials (za,zr): '); for i=iA', fprintf('[%.1f,%.1f] ',za(i),zr(i)); end; fprintf('\n');
fprintf('rel-profile trials (za,zr): '); for i=iR', fprintf('[%.1f,%.1f] ',za(i),zr(i)); end; fprintf('\n');

% ---- figure: scatter + spectra + trace gallery ----
cA=[0.75 0.20 0.15]; cR=[0.15 0.35 0.75];
fig=figure('Color','w','Units','centimeters','Position',[2 2 24 12]);
tl=tiledlayout(fig,2,4,'TileSpacing','compact','Padding','compact');

% (1) scatter
ax=nexttile(tl); hold(ax,'on');
scatter(ax,La,Xrel,6,[.7 .7 .7],'filled','MarkerFaceAlpha',.4);
scatter(ax,La(iA),Xrel(iA),26,cA,'filled');
scatter(ax,La(iR),Xrel(iR),26,cR,'filled');
xlabel(ax,'log_{10} abs \delta (1-4 Hz power)'); ylabel(ax,'rel 2-4 Hz');
title(ax,sprintf('abs vs rel  (r=%.2f, \\rho=%.2f)',r_pear,r_spear),'FontSize',8);
set(ax,'Box','off','TickDir','out','FontSize',7);

% (2) spectra comparison (mean over candidates)
ax=nexttile(tl); hold(ax,'on');
[Sa,fx]=cand_spec(mouse,fields,SESS,TRI,iA,c0_l,spec_pre_s,spec_post_s,Fs);
[Sr,~ ]=cand_spec(mouse,fields,SESS,TRI,iR,c0_l,spec_pre_s,spec_post_s,Fs);
plot(ax,fx,10*log10(mean(Sa,1)+eps),'-','Color',cA,'LineWidth',1.6);
plot(ax,fx,10*log10(mean(Sr,1)+eps),'-','Color',cR,'LineWidth',1.6);
yl=ylim(ax);
patch(ax,[hi_bnd fliplr(hi_bnd)],[yl(1) yl(1) yl(2) yl(2)],[.2 .3 .7],'FaceAlpha',.08,'EdgeColor','none');
xlim(ax,[0 8]); xlabel(ax,'Hz'); ylabel(ax,'power (dB)');
title(ax,'mean spectra (2-4 Hz shaded)','FontSize',8); set(ax,'Box','off','TickDir','out','FontSize',7);
text(ax,4.2,yl(1)+0.9*range(yl),'abs \delta','Color',cA,'FontSize',7,'FontWeight','bold');
text(ax,4.2,yl(1)+0.78*range(yl),'rel 2-4','Color',cR,'FontSize',7,'FontWeight','bold');

% (3) two spare top tiles -> use for first abs & first rel trace
plot_tr(nexttile(tl),mouse,fields,SESS,TRI,iA(1),c0_l,spec_pre_s,spec_post_s,Fs,cA,za,zr,'abs');
plot_tr(nexttile(tl),mouse,fields,SESS,TRI,iR(1),c0_l,spec_pre_s,spec_post_s,Fs,cR,za,zr,'rel');
% row 2: remaining candidate traces (2 abs, 2 rel)
plot_tr(nexttile(tl),mouse,fields,SESS,TRI,iA(2),c0_l,spec_pre_s,spec_post_s,Fs,cA,za,zr,'abs');
plot_tr(nexttile(tl),mouse,fields,SESS,TRI,iA(3),c0_l,spec_pre_s,spec_post_s,Fs,cA,za,zr,'abs');
plot_tr(nexttile(tl),mouse,fields,SESS,TRI,iR(2),c0_l,spec_pre_s,spec_post_s,Fs,cR,za,zr,'rel');
plot_tr(nexttile(tl),mouse,fields,SESS,TRI,iR(3),c0_l,spec_pre_s,spec_post_s,Fs,cR,za,zr,'rel');
title(tl,sprintf('Delta profiles: abs \\delta (red) vs rel 2-4 Hz (blue)  |  corr r=%.2f',r_pear),'FontSize',9,'FontWeight','bold');
exportgraphics(fig,fullfile(outview,'f4_delta_candidates.png'),'Resolution',220);
fprintf('[f4_delta_candidates] wrote gallery -> %s\n',outview);

%% helpers
function [S,fx]=cand_spec(mouse,fields,SESS,TRI,idx,c0_l,pre,post,Fs)
    S=[]; for i=idx(:)'
        dk=mouse.(fields{SESS(i)}).data; seg=double(dk.pwcDfk_l(TRI(i),c0_l-pre*Fs:c0_l+post*Fs));
        [P,fx]=local_psd(seg,Fs); S=[S;P]; end %#ok<AGROW>
end
function plot_tr(ax,mouse,fields,SESS,TRI,i,c0_l,pre,post,Fs,cc,za,zr,tag)
    dk=mouse.(fields{SESS(i)}).data; ref=mouse.(fields{SESS(i)}).d.ref;
    tv=(-pre:1/Fs:post).'; seg=dk.pwcDfk_l(TRI(i),c0_l-pre*Fs:c0_l+post*Fs);
    hold(ax,'on'); patch(ax,[0 3 3 0],[-16 -16 10 10],[.85 .85 .85],'EdgeColor','none','FaceAlpha',.4);
    plot(ax,tv([1 end]),[ref ref],'--','Color',[.3 .3 .3]); plot(ax,tv,seg,'-','Color',cc,'LineWidth',1.2);
    xlim(ax,[-pre post]); ylim(ax,[-16 10]); set(ax,'Box','off','TickDir','out','FontSize',6.5);
    xlabel(ax,'t (s)'); ylabel(ax,'\DeltaF/F (%)');
    title(ax,sprintf('%s: z_{abs}=%.1f z_{rel}=%.1f',tag,za(i),zr(i)),'FontSize',7);
end
function p=local_bandpow(seg,Fs,lo,hi)
    seg=detrend(double(seg(:)).','linear'); N=numel(seg); w=hann(N).';
    P=abs(fft(seg.*w)).^2; P=P(1:floor(N/2)+1); fr=(0:floor(N/2))*Fs/N; p=sum(P(fr>=lo&fr<hi));
end
function [P,fr]=local_psd(seg,Fs)
    seg=detrend(double(seg(:)).','linear'); N=numel(seg); w=hann(N).';
    P=abs(fft(seg.*w)).^2; P=P(1:floor(N/2)+1); fr=(0:floor(N/2))*Fs/N;
end
