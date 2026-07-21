% controller-analysis/cl_factor_olcl_panels.m
% Figure-4 individual panels: each error factor vs tracking RMSE, OPEN vs CLOSED loop.
% Exports one vector PDF per factor (Illustrator-assembled into Fig 4).
%
% Three factors, each binned into per-session quartiles (edges pooled over OL+CL
% within a session), then pooled across sessions -- IDENTICAL design to the
% existing motion panel (motion_analysis.m figQp) so the three form one family:
%   initial deviation  |dF/F(onset) - ref|            [POSITIVE CONTROL: onset
%                                                       sample is inside the RMSE
%                                                       window -> intentional]
%   motion energy      mean z-motion^2, -2 -> stim end
%   delta power        log10 band power 1-4 Hz, -2 -> stim end
%
% Visual = pooled quartile mean RMSE +/- SEM, OL (red) vs CL (green).
% Stat   = per-session standardized slope (within-session Pearson r of RMSE on
%          the factor), OL vs CL, Wilcoxon signed-rank across sessions -- the
%          same session-level test the manuscript motion paragraph reports, so
%          it is not trial-level pseudoreplicated.
%
% Requires: load_sessions.m has run (mouse, fields in workspace).
clc; close all;

PS = paperStyle();
setPaperDefaults();

if exist(fullfile('paper','images'), 'dir'); paper_root = 'paper';
elseif exist(fullfile('..','paper','images'), 'dir'); paper_root = fullfile('..','paper');
else; paper_root = 'paper'; warning('cannot locate paper/ -- exporting locally.'); end

colOL = [1 0 0]; colCL = [0 0.5 0];
if isfield(PS,'col_ol'); colOL = PS.col_ol; end
if isfield(PS,'col_cl'); colCL = PS.col_cl; end

Fs=35; c0=36; c0_mot=71; c0_l=106; nBins=4;
bandpow = @(seg,lo,hi) local_bandpow(seg,Fs,lo,hi);

% ---- factor specs: extractor returns per-trial x for OL (nc) and CL (wc) ----
F(1).name='Initial deviation';  F(1).file='factor_olcl_initdev.pdf';
F(1).xlab='Initial deviation quartile'; F(1).need_mot=false; F(1).posctrl=true;
F(1).get=@(dk,ref,dur) deal(abs(dk.ncDfk(:,c0)-ref), abs(dk.wcDfk(:,c0)-ref));

F(2).name='Motion energy';      F(2).file='factor_olcl_motion.pdf';
F(2).xlab='Motion-energy quartile'; F(2).need_mot=true;  F(2).posctrl=false;
F(2).get=@(dk,ref,dur) motion_energy(dk,dur,Fs,c0_mot);

F(3).name='Delta power';        F(3).file='factor_olcl_delta.pdf';
F(3).xlab='Delta-power quartile (log_{10})'; F(3).need_mot=false; F(3).posctrl=false;
F(3).get=@(dk,ref,dur) delta_power(dk,c0_l,Fs,bandpow);

for fi = 1:numel(F)
    binNC = cell(1,nBins); binCL = cell(1,nBins);
    rNC=[]; rCL=[]; nTr=0; nSess=0;

    for k = 1:numel(fields)
        s = mouse.(fields{k});
        if isfield(s,'skip') && s.skip; continue; end
        if ~isfield(s,'data');          continue; end
        if F(fi).need_mot && ~s.has_motion; continue; end
        dk = s.data; ref = s.d.ref; dur = s.d.params.dur;
        if F(fi).need_mot && ~isfield(dk,'wcmotion'); continue; end

        [xnc, xcl] = F(fi).get(dk, ref, dur);
        ync = dk.er_ncDfk(:); ycl = dk.er_wcDfk(:);
        m_nc = min(numel(xnc),numel(ync)); m_cl = min(numel(xcl),numel(ycl));
        xnc=xnc(1:m_nc); ync=ync(1:m_nc); xcl=xcl(1:m_cl); ycl=ycl(1:m_cl);

        gnc = isfinite(xnc)&isfinite(ync); gcl = isfinite(xcl)&isfinite(ycl);
        xnc=xnc(gnc); ync=ync(gnc); xcl=xcl(gcl); ycl=ycl(gcl);
        if numel(xnc)<5 || numel(xcl)<5; continue; end

        % per-session standardized slope = within-session Pearson r
        rNC(end+1) = corr(xnc,ync); %#ok<*AGROW>
        rCL(end+1) = corr(xcl,ycl);

        % per-session quartile edges from pooled OL+CL, then bin each condition
        edges = quantile([xnc;xcl], linspace(0,1,nBins+1));
        edges(1)=-inf; edges(end)=inf;
        bnc = discretize(xnc, edges); bcl = discretize(xcl, edges);
        for b=1:nBins
            binNC{b} = [binNC{b}; ync(bnc==b)];
            binCL{b} = [binCL{b}; ycl(bcl==b)];
        end
        nTr = nTr + numel(xnc) + numel(xcl); nSess = nSess + 1;
    end

    % signed-rank OL vs CL slopes across sessions
    [p_sr,~] = signrank(rNC(:), rCL(:));
    fprintf('\n[%s] %d sessions, %d trials\n', F(fi).name, nSess, nTr);
    fprintf('  median within-session r: OL %+.3f | CL %+.3f | signrank p=%.4g (n=%d)\n', ...
        median(rNC), median(rCL), p_sr, nSess);

    m_nc = cellfun(@mean, binNC); e_nc = cellfun(@(x) std(x)/sqrt(max(numel(x),1)), binNC);
    m_cl = cellfun(@mean, binCL); e_cl = cellfun(@(x) std(x)/sqrt(max(numel(x),1)), binCL);
    xb = 1:nBins;

    fig = paperFig(6,4); ax = axes(fig); hold(ax,'on');
    errorbar(ax, xb-0.1, m_nc, e_nc, 'o-', 'Color',colOL, 'LineWidth',PS.lw_mean, ...
        'MarkerSize',3,'MarkerFaceColor',colOL,'CapSize',3,'DisplayName','Open loop');
    errorbar(ax, xb+0.1, m_cl, e_cl, 'o-', 'Color',colCL, 'LineWidth',PS.lw_mean, ...
        'MarkerSize',3,'MarkerFaceColor',colCL,'CapSize',3,'DisplayName','Closed loop');
    xlim(ax,[0.5 nBins+0.5]); xticks(ax,xb);
    xticklabels(ax,{'Q1','Q2','Q3','Q4'});
    xlabel(ax, F(fi).xlab, 'FontWeight','bold','FontSize',6);
    ylabel(ax, 'RMSE (%\DeltaF/F), 0-3 s', 'FontWeight','bold','FontSize',6);
    set(ax,'Box','off','TickDir','out','FontSize',6,'FontWeight','bold');
    lg = legend(ax,'Box','off','Location','northwest','FontSize',5); lg.ItemTokenSize=[6 6];
    ttl = F(fi).name;
    if F(fi).posctrl; ttl = [ttl ' (positive control)']; end
    title(ax, ttl, 'FontSize',6,'FontWeight','bold');

    yl = ylim(ax);
    text(ax, 0.55, yl(1)+0.06*range(yl), ...
        sprintf('slope OL %+.2f / CL %+.2f  p=%.3g  n=%d/%d', ...
                median(rNC), median(rCL), p_sr, nSess, nTr), ...
        'FontSize',4.5,'FontWeight','bold','Color',[0.2 0.2 0.2]);
    hold(ax,'off');

    paperExport(fig, fullfile(paper_root,'images','figure4',F(fi).file));
    fprintf('  exported %s\n', F(fi).file);
end

%% ---- helpers ----
function [xnc,xcl] = motion_energy(dk,dur,Fs,c0_mot)
    nc=dk.ncmotion; wc=dk.wcmotion; ncol=size(nc,2);
    onset = ncol - Fs*dur;                 % robust to stored window
    if onset<1; onset=c0_mot; end
    ws=max(1,onset-round(2*Fs)); we=min(ncol,onset+round(dur*Fs)-1);
    xnc=mean(nc(:,ws:we).^2,2); xcl=mean(wc(:,ws:we).^2,2);
end
function [xnc,xcl] = delta_power(dk,c0_l,Fs,bandpow)
    sa=c0_l-round(2*Fs); sb=c0_l+round(3*Fs);
    nc=dk.pncDfk_l; wc=dk.pwcDfk_l;
    xnc=nan(size(nc,1),1); xcl=nan(size(wc,1),1);
    for t=1:size(nc,1); xnc(t)=log10(max(bandpow(nc(t,sa:sb),1,4),eps)); end
    for t=1:size(wc,1); xcl(t)=log10(max(bandpow(wc(t,sa:sb),1,4),eps)); end
end
function p = local_bandpow(seg,Fs,lo,hi)
    seg=detrend(double(seg(:)).','linear'); N=numel(seg);
    w=hann(N).'; P=abs(fft(seg.*w)).^2; P=P(1:floor(N/2)+1);
    fr=(0:floor(N/2))*Fs/N; p=sum(P(fr>=lo & fr<hi));
end
