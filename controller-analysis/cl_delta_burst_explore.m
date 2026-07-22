% controller-analysis/cl_delta_burst_explore.m
% EXPLORATORY: find short (~1 s) delta-band bursts in CL trials and plot them.
%
% Motivation (AL): slow-wave activity seems to come in two flavours --
%   (i) large-amplitude SUSTAINED slow waves, and
%   (ii) short (~1 s) BURSTS of delta oscillation,
% and both may be hard to control. Before adding "burst" as a model factor we
% first need to FIND them and eyeball trials that contain them.
%
% Method (suggested, tunable):
%   1. band-limited analytic envelope of the 1-4 Hz component (FFT Hilbert,
%      no toolbox) -> E(t) = instantaneous delta amplitude.
%   2. event = contiguous run where E(t) > threshold
%        thr = max( per-trial median+K*MAD , pooled amplitude floor )
%      (adaptive part separates bursts from a trial's own baseline; pooled floor
%       kills trivially-small wiggles).
%   3. classify each event by DURATION:
%        BURST     = 0.4-1.5 s   (a transient packet that comes and goes)
%        SUSTAINED = > 2.5 s     (a persistent large slow wave)
%   4. per-trial: n_burst, burst peak, sustained fraction, low/high sub-band.
%
% Requires: load_sessions.m has run.
clc; close all;
PS = paperStyle(); setPaperDefaults();
if exist(fullfile('paper','images'),'dir'); paper_root='paper';
elseif exist(fullfile('..','paper','images'),'dir'); paper_root=fullfile('..','paper');
else; paper_root='paper'; end
outdir = fullfile(paper_root,'images','figure4');

Fs=35; c0_l=106;
sa=c0_l-round(2*Fs); sb=c0_l+round(5*Fs);       % display+detect window: -2 -> +5 s
tvec=((sa:sb)-c0_l)/Fs;
K_mad   = 2.5;                                   % adaptive threshold multiplier
burst_s = [0.4 1.5];                            % burst duration band (s)
sust_s  = 2.5;                                   % sustained if run > this (s)

% ---- pass 1: pool envelopes to set the amplitude floor ----
Eall=[]; T=struct('E',{},'dfk',{},'sess',{},'tr',{});
for k=1:numel(fields)
    s=mouse.(fields{k}); if isfield(s,'skip')&&s.skip;continue;end; if ~isfield(s,'data');continue;end
    wc=s.data.pwcDfk_l;
    for t=1:size(wc,1)
        seg=double(wc(t,sa:sb));
        E=delta_env(seg,Fs,1,4);
        T(end+1)=struct('E',E,'dfk',seg,'sess',k,'tr',t); %#ok<SAGROW>
        Eall=[Eall E]; %#ok<AGROW>
    end
end
floorE = prctile(Eall, 70);                     % pooled amplitude floor
fprintf('[burst] %d CL trials | pooled envelope floor (70th pct) = %.2f %%dF/F\n', numel(T), floorE);

% ---- pass 2: detect events per trial ----
nB=zeros(1,numel(T)); pk=zeros(1,numel(T)); sf=zeros(1,numel(T)); bursts=cell(1,numel(T));
lo_rel=zeros(1,numel(T)); hi_rel=zeros(1,numel(T));
for i=1:numel(T)
    E=T(i).E; thr=max(median(E)+K_mad*mad(E,1), floorE);
    above=E>thr; d=diff([0 above 0]); on=find(d==1); off=find(d==-1)-1;
    binfo=[]; sustSamp=0;
    for e=1:numel(on)
        dur=(off(e)-on(e)+1)/Fs; ep=max(E(on(e):off(e)));
        if dur>=burst_s(1) && dur<=burst_s(2) && ep>=floorE
            binfo(end+1,:)=[on(e) off(e) ep]; %#ok<AGROW>
        end
        if dur>sust_s; sustSamp=sustSamp+(off(e)-on(e)+1); end
    end
    nB(i)=size(binfo,1); if nB(i)>0; pk(i)=max(binfo(:,3)); end
    sf(i)=sustSamp/numel(E); bursts{i}=binfo;
    % frequency sub-bands (relative), same window
    seg=T(i).dfk; lo_rel(i)=bp(seg,Fs,1,2)/max(bp(seg,Fs,0.4,10),eps);
    hi_rel(i)=bp(seg,Fs,2,4)/max(bp(seg,Fs,0.4,10),eps);
end

fprintf('[burst] trials with >=1 short burst: %d/%d (%.0f%%)\n', sum(nB>=1), numel(T), 100*mean(nB>=1));
fprintf('[burst] median bursts/trial (burst trials): %g | max %d\n', median(nB(nB>=1)), max(nB));
fprintf('[burst] sub-band relative power: low 1-2 Hz median %.2f | high 2-4 Hz median %.2f | corr(low,high)=%.2f\n', ...
    median(lo_rel), median(hi_rel), corr(lo_rel(:),hi_rel(:)));

% ---- gallery: burst-dominated trials (>=1 burst, NOT sustained) ----
cand=find(nB>=1 & sf<0.35);
[~,ord]=sort(pk(cand),'descend'); sel=cand(ord(1:min(9,numel(cand))));

fig=paperFig(19,12); tl=tiledlayout(fig,3,3,'TileSpacing','compact','Padding','compact');
for i=sel
    ax=nexttile(tl); hold(ax,'on');
    seg=T(i).dfk; [db,E]=delta_band(seg,Fs,1,4);
    yl=[min(seg)-1 max(seg)+1];
    % shade detected bursts
    for e=1:size(bursts{i},1)
        x1=tvec(bursts{i}(e,1)); x2=tvec(bursts{i}(e,2));
        patch(ax,[x1 x2 x2 x1],[yl(1) yl(1) yl(2) yl(2)],[1 0.55 0.55], ...
            'EdgeColor','none','FaceAlpha',0.35);
    end
    plot(ax,tvec,seg,'-','Color',[0.55 0.55 0.55],'LineWidth',0.7);          % raw dF/F
    plot(ax,tvec,db+mean(seg),'-','Color',[0.20 0.30 0.75],'LineWidth',1.0); % delta component
    plot(ax,tvec([1 end]),[mouse.(fields{T(i).sess}).d.ref mouse.(fields{T(i).sess}).d.ref], ...
        '--','Color',[.3 .3 .3],'LineWidth',0.7);
    xlim(ax,[tvec(1) tvec(end)]); ylim(ax,yl);
    set(ax,'Box','off','TickDir','out','FontSize',5,'FontWeight','bold');
    text(ax,0.02,0.95,sprintf('%s tr%d  bursts=%d',fields{T(i).sess},T(i).tr,nB(i)), ...
        'Units','normalized','FontSize',5,'FontWeight','bold','Color',[0.15 0.15 0.15]);
    if i==sel(end); xlabel(ax,'time from onset (s)','FontSize',6,'FontWeight','bold'); end
end
title(tl,sprintf(['CL trials with short (%.1f-%.1f s) delta bursts  (%d/%d trials have >=1;  ' ...
    'grey=\\DeltaF/F, blue=1-4 Hz component, red=detected burst)'], burst_s(1),burst_s(2),sum(nB>=1),numel(T)), ...
    'FontSize',7,'FontWeight','bold');
paperExport(fig,fullfile(outdir,'delta_burst_gallery.png'));
fprintf('[burst] exported delta_burst_gallery.png\n');

%% ---- helpers ----
function E = delta_env(seg,Fs,lo,hi)
    seg=detrend(double(seg(:)).','linear'); N=numel(seg);
    F=fft(seg); f=(0:N-1)*Fs/N; H=zeros(1,N);
    pos=f>=lo & f<=hi; H(pos)=2*F(pos); a=ifft(H); E=abs(a);
end
function [db,E] = delta_band(seg,Fs,lo,hi)
    seg=detrend(double(seg(:)).','linear'); N=numel(seg);
    F=fft(seg); f=(0:N-1)*Fs/N; H=zeros(1,N);
    pos=f>=lo & f<=hi; H(pos)=2*F(pos); a=ifft(H); db=real(a); E=abs(a);
end
function p = bp(seg,Fs,lo,hi)
    seg=detrend(double(seg(:)).','linear'); N=numel(seg);
    w=hann(N).'; P=abs(fft(seg.*w)).^2; P=P(1:floor(N/2)+1);
    fr=(0:floor(N/2))*Fs/N; p=sum(P(fr>=lo & fr<hi));
end
