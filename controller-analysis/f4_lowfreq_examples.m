% controller-analysis/f4_lowfreq_examples.m
% SUPPLEMENTARY (Fig S:lowfreq_examples) -- representative single CL trials that
% illustrate the low-frequency (2-4 Hz) disturbance the controller cannot reject.
% Shows the SAME contrast two ways, per the paper's power-INDEPENDENT claim:
%   Row 1  sorted by RELATIVE 2-4 Hz power  = P(2-4)/P(0.4-10)   (the state used in text)
%   Row 2  sorted by ABSOLUTE 2-4 Hz power  = P(2-4)             (raw band power)
% For each: a LOW-state and a HIGH-state exemplar, each shown as pre-stim+trial
% trace (left) + pre-stim power spectrum with the 2-4 Hz band shaded (right).
% Each exemplar is annotated with its CL tracking error (RMSE, 0-3 s) so the reader
% sees that the RELATIVE measure tracks error while the ABSOLUTE measure does not.
% Requires load_sessions.m has run (uses mouse/fields in base workspace).
clc; close all;
PS=paperStyle(); setPaperDefaults();
root='C:\Users\aditya\Documents\projects\brain_paper'; addpath(fullfile(root,'utils'));
outview=fullfile(root,'controller-analysis','_preview'); if ~exist(outview,'dir'); mkdir(outview); end

Fs=35; c0=106;                          % onset sample in pwcDfk_l
preN=c0-1;                              % pre-stim samples (3 s)
sa=c0-round(2*Fs); sb=c0+round(3*Fs);  % display window -2 -> +3 s
tvec=((sa:sb)-c0)/Fs;
motThresh=1.5;                          % z-motion exclusion (project default)

% ---- pool motion-clean CL trials across the motion sessions ------------------
P=struct('seg',{},'pre',{},'err',{},'rel',{},'abs',{},'sess',{},'tr',{});
for k=1:numel(fields)
    s=mouse.(fields{k}); if isfield(s,'skip')&&s.skip; continue; end
    if ~isfield(s,'data'); continue; end; d=s.data;
    if ~isfield(d,'pwcDfk_l')||~isfield(d,'er_wcDfk'); continue; end
    wc=double(d.pwcDfk_l); er=d.er_wcDfk(:);
    hasMot=isfield(d,'wcmotion')&&~isempty(d.wcmotion);
    if hasMot; mz=zscore(double(d.wcmotion(:))); end
    n=size(wc,1);
    for t=1:n
        if hasMot && t<=numel(mz) && mz(t)>motThresh; continue; end   % motion-clean only
        if size(wc,2)<sb; continue; end
        pre=wc(t,1:preN); pre=pre-mean(pre);
        p24=bandpow(pre,Fs,2,4); ptot=bandpow(pre,Fs,0.4,10);
        P(end+1)=struct('seg',wc(t,sa:sb),'pre',wc(t,1:preN), ...
            'err',er(min(t,numel(er))),'rel',p24/max(ptot,eps),'abs',p24, ...
            'sess',k,'tr',t); %#ok<SAGROW>
    end
end
fprintf('[lowfreq] %d motion-clean CL trials pooled\n',numel(P));
err=[P.err]; rel=[P.rel]; ab=[P.abs];

% ---- pick low / high exemplars for each metric (10th vs 90th pctile) ---------
pick=@(v,q) find(v>=prctile(v,q),1,'first');       % first trial at/above quantile
[~,ord_r]=sort(rel); [~,ord_a]=sort(ab);
i_rl=ord_r(max(1,round(0.10*end)));  i_rh=ord_r(round(0.90*end));   % rel low/high
i_al=ord_a(max(1,round(0.10*end)));  i_ah=ord_a(round(0.90*end));   % abs low/high
ex={i_rl,i_rh,i_al,i_ah};
rowlab={'relative 2-4 Hz','absolute 2-4 Hz'};
colcol=[PS.col_cl; 0.78 0.16 0.12];   % low=blue, high=red

f=paperFig(18,9);
lay=tiledlayout(f,2,4,'TileSpacing','compact','Padding','compact');
title(lay,'Low-frequency (2-4 Hz) disturbance: representative CL trials','FontSize',PS.fs+1,'FontWeight','bold');
band=[2 4];
for r=1:2
    if r==1; lo=i_rl; hi=i_rh; else; lo=i_al; hi=i_ah; end
    for cc=1:2                         % cc=1 low, cc=2 high
        E=P(ternary(cc==1,lo,hi)); col=colcol(cc,:);
        % --- trace ---
        ax=nexttile(lay,(r-1)*4+(cc-1)*2+1); hold(ax,'on');
        patch(ax,[0 3 3 0],[-60 -60 60 60],[.93 .90 .82],'EdgeColor','none','FaceAlpha',.5,'HandleVisibility','off');
        plot(ax,tvec,E.seg,'-','Color',col,'LineWidth',1.0);
        yline(ax,E.err*0-5,'--','Color',[.6 .6 .6],'LineWidth',PS.lw_ref);  % ref -5
        xline(ax,0,':','Color',[.55 .55 .55]);
        xlim(ax,[tvec(1) tvec(end)]); ylim(ax,[min(-8,min(E.seg)*1.1) max(6,max(E.seg)*1.1)]);
        set(ax,'Box','off','TickDir','out','FontSize',PS.fs,'FontWeight',PS.fw);
        if cc==1; ylabel(ax,sprintf('%s\n\\DeltaF/F (%%)',rowlab{r}),'FontSize',PS.fs,'FontWeight','bold'); end
        if r==2; xlabel(ax,'time from stim (s)','FontSize',PS.fs,'FontWeight',PS.fw); end
        title(ax,sprintf('%s  |  RMSE=%.2f',ternary(cc==1,'LOW','HIGH'),E.err),'FontSize',PS.fs,'FontWeight','bold','Color',col);
        % --- spectrum (pre-stim) ---
        axS=nexttile(lay,(r-1)*4+(cc-1)*2+2); hold(axS,'on');
        [pxx,fx]=psd1(E.pre-mean(E.pre),Fs);
        ib=fx>=0.4 & fx<=10;
        yb=[0 max(pxx(ib))*1.15+eps];
        patch(axS,[band(1) band(2) band(2) band(1)],[yb(1) yb(1) yb(2) yb(2)],[.85 .88 .95],'EdgeColor','none','FaceAlpha',.7,'HandleVisibility','off');
        plot(axS,fx(ib),pxx(ib),'-','Color',col,'LineWidth',1.1);
        xlim(axS,[0.4 10]); ylim(axS,yb);
        set(axS,'Box','off','TickDir','out','FontSize',PS.fs,'FontWeight',PS.fw);
        if r==2; xlabel(axS,'frequency (Hz)','FontSize',PS.fs,'FontWeight',PS.fw); end
        ylabel(axS,'power (%\DeltaF/F)^2/Hz','FontSize',PS.fs,'FontWeight',PS.fw);
        text(axS,0.96,0.92,sprintf('rel 2-4Hz = %.2f\nabs 2-4Hz = %.2f',E.rel,E.abs), ...
            'Units','normalized','HorizontalAlignment','right','VerticalAlignment','top', ...
            'FontSize',PS.fs,'FontWeight','bold','Color',col);
    end
end
exportgraphics(f,fullfile(outview,'f4_lowfreq_examples.png'),'Resolution',300);
fprintf('[lowfreq] rel: LOW rmse=%.2f (rel=%.2f) | HIGH rmse=%.2f (rel=%.2f)\n', ...
    P(i_rl).err,P(i_rl).rel,P(i_rh).err,P(i_rh).rel);
fprintf('[lowfreq] abs: LOW rmse=%.2f (abs=%.2f) | HIGH rmse=%.2f (abs=%.2f)\n', ...
    P(i_al).err,P(i_al).abs,P(i_ah).err,P(i_ah).abs);
% group medians: does error rise with each metric across the pool?
qc=@(v) prctile(v,[25 75]);
loR=err(rel<=median(rel)); hiR=err(rel>median(rel));
loA=err(ab<=median(ab));  hiA=err(ab>median(ab));
fprintf('[lowfreq] median RMSE  rel: lo=%.2f hi=%.2f (p=%.3g) | abs: lo=%.2f hi=%.2f (p=%.3g)\n', ...
    median(loR),median(hiR),ranksum(loR,hiR), median(loA),median(hiA),ranksum(loA,hiA));

% ---- helpers ----------------------------------------------------------------
function p=bandpow(x,Fs,f1,f2)
    x=x(:)-mean(x); n=numel(x); w=hannw(n); X=fft(x.*w); P=abs(X(1:floor(n/2)+1)).^2;
    fr=(0:floor(n/2))'*Fs/n; df=Fs/n; m=fr>=f1&fr<=f2; p=sum(P(m))*df/(sum(w.^2));
end
function [pxx,fx]=psd1(x,Fs)
    x=x(:); n=numel(x); w=hannw(n); X=fft(x.*w); P=abs(X(1:floor(n/2)+1)).^2;
    P=P/(Fs*sum(w.^2)); P(2:end-1)=2*P(2:end-1); pxx=P; fx=(0:floor(n/2))'*Fs/n;
end
function w=hannw(n)
    w=0.5*(1-cos(2*pi*(0:n-1)'/(n-1)));
end
function o=ternary(c,a,b); if c; o=a; else; o=b; end; end
