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
    psO=[]; psC=[]; psMu=[];                      % per-session bin means + session level

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

        % STAT: per-session slope on RAW RMSE (%dF/F). Was z-scored within session (pooled OL+CL)
        % until 2026-08-13 -- removed on the project rule that RMSE is a positive quantity whose
        % across-session spread is real signal and must not be normalized away. OL and CL are in
        % the same units, so the interaction test is unaffected by the missing rescale.
        bo=polyfit(xnc,ync,1); slopeOL(k)=bo(1);
        bc=polyfit(xcl,ycl,1); slopeCL(k)=bc(1);

        % VISUAL: RAW RMSE (%dF/F) per quartile
        edges=quantile([xnc;xcl],linspace(0,1,nBins+1)); edges(1)=-inf; edges(end)=inf;
        bnc=discretize(xnc,edges); bcl=discretize(xcl,edges);
        rowO=nan(1,nBins); rowC=nan(1,nBins);
        for b=1:nBins
            rbinOL{b}=[rbinOL{b}; ync(bnc==b)]; rbinCL{b}=[rbinCL{b}; ycl(bcl==b)];
            if any(bnc==b); rowO(b)=mean(ync(bnc==b)); end
            if any(bcl==b); rowC(b)=mean(ycl(bcl==b)); end
        end
        psO(end+1,:)=rowO; psC(end+1,:)=rowC; psMu(end+1,1)=mean([ync;ycl]); %#ok<AGROW>
    end

    v=isfinite(slopeOL)&isfinite(slopeCL);
    p_diff=signrank(slopeOL(v),slopeCL(v));
    star = sig_star(p_diff);
    fprintf('[%s] n=%d sess | slope OL %+.3f CL %+.3f | interaction signrank p=%.4g -> %s\n', ...
        F(fi).key, sum(v), median(slopeOL(v)), median(slopeCL(v)), p_diff, star);

    [~,base]=fileparts(F(fi).file);
    % ONE y-axis version: raw RMSE (%dF/F). The '_z' within-session z-scored variant was dropped
    % 2026-08-13 -- it plotted the same panel in normalized units, which is the thing the project
    % rule forbids, and keeping both invited the wrong one into the figure.
    % Grouped bars replaced by utils/cl_quartile_line.m on 2026-08-13 (user: magnify the
    % difference, cleaner neuroscience version). Points encode position, not length from zero,
    % which is what makes cropping the y-axis to the data range legitimate -- a cropped BAR
    % misstates every ratio on the panel. See that file's header.
    % WITHIN-SESSION normalization (2026-08-13): subtract each session's own level (its OL+CL
    % trials together, so the OL-CL gap survives), add the grand mean back so the axis stays in
    % %dF/F, and take SEM across SESSIONS -- the unit the signed-rank test uses. Pooling raw
    % trials let session difficulty leak into the quartile means by a different amount per factor.
    grand = mean(vertcat(rbinOL{:},rbinCL{:}));
    cO = psO - psMu + grand;   cC = psC - psMu + grand;
    sm = @(C) std(C,0,1,'omitnan') ./ sqrt(max(sum(isfinite(C),1),1));
    o = struct('lab',{{'Open loop','Closed loop'}}, 'col',[PS.col_ol; PS.col_cl], ...
        'xlab',F(fi).xlab, 'ylab','RMSE (%\DeltaF/F)', 'star',star, ...
        'legend',strcmp(F(fi).key,LEGEND_ON), ...
        'file',fullfile(paper_root,'images','figure4',base), 'pdf',true, 'xticks',{{}});
    cl_quartile_line(mean(cO,1,'omitnan'), sm(cO), mean(cC,1,'omitnan'), sm(cC), o);
    fprintf('  exported %s(.png/.pdf)   [point-and-line, cropped y-axis]\n', base);
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
