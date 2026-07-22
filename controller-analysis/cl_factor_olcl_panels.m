% controller-analysis/cl_factor_olcl_panels.m
% Figure-4 individual panels: each error factor vs tracking error, OL vs CL.
% One vector PDF per factor, matched to the canonical motion panel
% (motion_mse_significance.m) so the three assemble as one figure in Illustrator.
%
% Style (neuroscience convention):
%   - title = the claim
%   - quartile bars of within-session z-scored trial RMSE, OL (red) vs CL (green)
%   - a single significance star = OL-vs-CL SLOPE INTERACTION (per-session
%     polyfit slope of z-RMSE on the factor, Wilcoxon signed-rank OL vs CL) --
%     i.e. "does feedback change this factor's effect on error", the panel's claim
%   - no verbose stats text; y-axis just 'RMSE (z)'
%   - legend drawn ONCE (motion panel only)
%
% Factors:
%   init-dev  |dF/F(onset)-ref|              [POSITIVE CONTROL]
%   motion    mean z-motion, onset->trial end [canonical, matches manuscript p]
%   delta     log10 band power 1-4 Hz, -2 s -> stim end
%
% Requires: load_sessions.m has run (mouse, fields in workspace).
clc; close all;
PS = paperStyle(); setPaperDefaults();

if exist(fullfile('paper','images'),'dir'); paper_root='paper';
elseif exist(fullfile('..','paper','images'),'dir'); paper_root=fullfile('..','paper');
else; paper_root='paper'; warning('cannot locate paper/ -- exporting locally.'); end

Fs=35; c0=36; c0_l=106; nBins=4;
LEGEND_ON = 'motion';          % which single panel carries the OL/CL legend
bandpow = @(seg,lo,hi) local_bandpow(seg,Fs,lo,hi);

F(1).key='initdev'; F(1).file='factor_olcl_initdev.pdf'; F(1).need_mot=false;
F(1).title='Initial deviation affects both loops equally';   % positive control (n.s. interaction expected)
F(1).xlab='Initial deviation quartile';
F(1).get=@(dk,ref,dur) deal(abs(dk.ncDfk(:,c0)-ref), abs(dk.wcDfk(:,c0)-ref));

F(2).key='motion'; F(2).file='factor_olcl_motion.pdf'; F(2).need_mot=true;
F(2).title='Closed loop rejects motion disturbance';
F(2).xlab='Motion quartile (low \rightarrow high)';
F(2).get=@(dk,ref,dur) motion_meas(dk,dur,Fs);

F(3).key='delta'; F(3).file='factor_olcl_delta.pdf'; F(3).need_mot=false;
F(3).title='Closed loop does not reject delta-band disturbance';
F(3).xlab='Relative 2-4 Hz quartile (low \rightarrow high)';
F(3).get=@(dk,ref,dur) delta_meas(dk,c0_l,Fs,bandpow);

for fi = 1:numel(F)
    slopeOL=nan(numel(fields),1); slopeCL=nan(numel(fields),1);
    rbinOL=cell(1,nBins); rbinCL=cell(1,nBins);   % RAW RMSE per quartile
    zbinOL=cell(1,nBins); zbinCL=cell(1,nBins);   % z-scored RMSE per quartile

    for k = 1:numel(fields)
        s = mouse.(fields{k});
        if isfield(s,'skip') && s.skip; continue; end
        if ~isfield(s,'data');          continue; end
        if F(fi).need_mot && ~s.has_motion; continue; end
        dk=s.data; ref=s.d.ref; dur=s.d.params.dur;
        if F(fi).need_mot && ~isfield(dk,'wcmotion'); continue; end

        [xnc,xcl] = F(fi).get(dk,ref,dur);
        ync=dk.er_ncDfk(:); ycl=dk.er_wcDfk(:);
        m1=min(numel(xnc),numel(ync)); m2=min(numel(xcl),numel(ycl));
        xnc=xnc(1:m1); ync=ync(1:m1); xcl=xcl(1:m2); ycl=ycl(1:m2);
        g1=isfinite(xnc)&isfinite(ync); g2=isfinite(xcl)&isfinite(ycl);
        xnc=xnc(g1); ync=ync(g1); xcl=xcl(g2); ycl=ycl(g2);
        if numel(ync)<10 || numel(ycl)<10; continue; end

        % STAT: per-session slope on z-scored RMSE (within-session, pooled OL+CL)
        % -- kept z-scored so the interaction test matches the manuscript method.
        mu=mean([ync;ycl]); sg=std([ync;ycl]);
        znc=(ync-mu)/sg; zcl=(ycl-mu)/sg;
        bo=polyfit(xnc,znc,1); slopeOL(k)=bo(1);
        bc=polyfit(xcl,zcl,1); slopeCL(k)=bc(1);

        % VISUAL: RAW RMSE (%dF/F) per quartile (z-score confused NL)
        edges=quantile([xnc;xcl],linspace(0,1,nBins+1)); edges(1)=-inf; edges(end)=inf;
        bnc=discretize(xnc,edges); bcl=discretize(xcl,edges);
        for b=1:nBins
            rbinOL{b}=[rbinOL{b}; ync(bnc==b)]; rbinCL{b}=[rbinCL{b}; ycl(bcl==b)];
            zbinOL{b}=[zbinOL{b}; znc(bnc==b)]; zbinCL{b}=[zbinCL{b}; zcl(bcl==b)];
        end
    end

    v=isfinite(slopeOL)&isfinite(slopeCL);
    p_diff=signrank(slopeOL(v),slopeCL(v));
    star = sig_star(p_diff);
    fprintf('[%s] n=%d sess | slope OL %+.3f CL %+.3f | interaction signrank p=%.4g -> %s\n', ...
        F(fi).key, sum(v), median(slopeOL(v)), median(slopeCL(v)), p_diff, star);

    [~,base]=fileparts(F(fi).file);
    % two y-axis versions: raw RMSE (%dF/F) and within-session z-scored
    MODE(1)=struct('bO',{rbinOL},'bC',{rbinCL},'ylab','RMSE (%\DeltaF/F)','suf','');
    MODE(2)=struct('bO',{zbinOL},'bC',{zbinCL},'ylab','RMSE (z)','suf','_z');
    for mi=1:2
        mO=cellfun(@mean,MODE(mi).bO); eO=cellfun(@(x)std(x)/sqrt(max(numel(x),1)),MODE(mi).bO);
        mC=cellfun(@mean,MODE(mi).bC); eC=cellfun(@(x)std(x)/sqrt(max(numel(x),1)),MODE(mi).bC);

        fig=paperFig(6,4); ax=gca; hold(ax,'on'); xq=1:nBins; w=0.35;
        bar(ax,xq-w/2,mO,w,'FaceColor',PS.col_ol,'EdgeColor','none','DisplayName','Open loop');
        bar(ax,xq+w/2,mC,w,'FaceColor',PS.col_cl,'EdgeColor','none','DisplayName','Closed loop');
        errorbar(ax,xq-w/2,mO,eO,'k','LineStyle','none','LineWidth',0.6,'CapSize',2,'HandleVisibility','off');
        errorbar(ax,xq+w/2,mC,eC,'k','LineStyle','none','LineWidth',0.6,'CapSize',2,'HandleVisibility','off');
        set(ax,'XTick',1:nBins,'XTickLabel',{'Q1','Q2','Q3','Q4'}, ...
            'Box','off','TickDir','out','FontSize',6,'FontWeight','bold');
        xlabel(ax,F(fi).xlab,'FontSize',6,'FontWeight','bold');
        ylabel(ax,MODE(mi).ylab,'FontSize',6,'FontWeight','bold');

        % single interaction star, top-centre (no title -- claim goes in caption)
        yl=ylim(ax); ys=yl(2);
        text(ax,mean([1 nBins]),ys,star,'HorizontalAlignment','center', ...
            'VerticalAlignment','top','FontSize',8,'FontWeight','bold');
        ylim(ax,[yl(1) ys+0.10*range(yl)]);

        if strcmp(F(fi).key,LEGEND_ON)
            lg=legend(ax,'Location','northwest'); paperLegend(lg);
        end

        paperExport(fig, fullfile(paper_root,'images','figure4',[base MODE(mi).suf '.png']));
        paperExport(fig, fullfile(paper_root,'images','figure4',[base MODE(mi).suf '.pdf']));
        close(fig);
    end
    fprintf('  exported %s(.png/.pdf) + %s_z(.png/.pdf)\n', base, base);
end

%% ---- helpers ----
function [xnc,xcl]=motion_meas(dk,dur,Fs)
    nc=dk.ncmotion; wc=dk.wcmotion; ncol=size(nc,2);
    onset=ncol-Fs*dur; ws=max(1,onset); we=min(ncol,onset+dur*Fs);   % during-trial
    xnc=mean(nc(:,ws:we),2); xcl=mean(wc(:,ws:we),2);
end
function [xnc,xcl]=delta_meas(dk,c0_l,Fs,bandpow)
    % RELATIVE 2-4 Hz (the hard-to-control sub-band): band 2-4 Hz / total 0.4-10 Hz
    sa=c0_l-round(2*Fs); sb=c0_l+round(3*Fs); nc=dk.pncDfk_l; wc=dk.pwcDfk_l;
    xnc=nan(size(nc,1),1); xcl=nan(size(wc,1),1);
    for t=1:size(nc,1); xnc(t)=bandpow(nc(t,sa:sb),2,4)/max(bandpow(nc(t,sa:sb),0.4,10),eps); end
    for t=1:size(wc,1); xcl(t)=bandpow(wc(t,sa:sb),2,4)/max(bandpow(wc(t,sa:sb),0.4,10),eps); end
end
function s=sig_star(p)
    if p<1e-3; s='***'; elseif p<1e-2; s='**'; elseif p<0.05; s='*'; else; s='n.s.'; end
end
function p=local_bandpow(seg,Fs,lo,hi)
    seg=detrend(double(seg(:)).','linear'); N=numel(seg);
    w=hann(N).'; P=abs(fft(seg.*w)).^2; P=P(1:floor(N/2)+1);
    fr=(0:floor(N/2))*Fs/N; p=sum(P(fr>=lo & fr<hi));
end
