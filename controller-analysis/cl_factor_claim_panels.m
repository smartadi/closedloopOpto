% controller-analysis/cl_factor_claim_panels.m
% Claim-specific Fig-4 companion panels. Leaves cl_factor_olcl_panels.m untouched.
%
% Claim 2 -- "delta waves are harder to control":
%   the hard-to-control sub-band is RELATIVE 2-4 Hz (band 2-4 / total 0.4-10),
%   tested in the LATE (settled 1-3 s) window. (Low 1-2 Hz big slow waves are the
%   NULL control -- panel claim2lo.) Detection of discrete short bursts was
%   dropped from this analysis (bursts matter for the spirals work, not here).
%
% Claim 3 -- "initial deviation doesn't affect control":
%   window contrast -- init-dev drives the EARLY transient but not the settled LATE.
%
% Stats: per-session slope of RAW RMSE (%dF/F) on factor, Wilcoxon signed-rank
% (unit = session). Claim 2 additionally confirmed with a linear MIXED-EFFECTS
% model (trial-level, random effects for session and animal).
%
% Requires: load_sessions.m has run.
clc; close all;
PS = paperStyle(); setPaperDefaults();
if exist(fullfile('paper','images'),'dir'); paper_root='paper';
elseif exist(fullfile('..','paper','images'),'dir'); paper_root=fullfile('..','paper');
else; paper_root='paper'; warning('cannot locate paper/ -- exporting locally.'); end
outdir = fullfile(paper_root,'images','figure4');

Fs=35; c0=36; c0_l=106; nBins=4;
earlyC = c0 : c0+round(1*Fs);
lateC  = c0+round(1*Fs)+1 : c0+round(3*Fs);
sa=c0_l-round(2*Fs); sb=c0_l+round(3*Fs);
bp=@(seg,lo,hi) local_bp(seg,Fs,lo,hi);
% RAW RMSE, never z-scored (2026-08-13, project rule): RMSE is positive and its across-session
% spread is real signal. This was a pooled within-session z-score; now an identity, kept so every
% call site keeps its signature.
zwin=@(y1,y2) deal(y1, y2);
slp=@(x,y) local_slp(x,y);

% accumulators: HI = claim2 (2-4 Hz), LO = null control (1-2 Hz)
HI.rmO=cell(1,nBins);HI.rmC=cell(1,nBins);HI.zmO=cell(1,nBins);HI.zmC=cell(1,nBins);HI.sOL=[];HI.sCL=[];
LO.rmO=cell(1,nBins);LO.rmC=cell(1,nBins);LO.zmO=cell(1,nBins);LO.zmC=cell(1,nBins);LO.sOL=[];LO.sCL=[];
c3.reE=cell(1,nBins);c3.reL=cell(1,nBins);c3.zeE=cell(1,nBins);c3.zeL=cell(1,nBins);c3.sE=[];c3.sL=[];
% flat table for mixed-effects (CL trials)
LME.y=[]; LME.x=[]; LME.sess=[]; LME.animal={};

for k=1:numel(fields)
    s=mouse.(fields{k}); if isfield(s,'skip')&&s.skip;continue;end; if ~isfield(s,'data');continue;end
    dk=s.data; ref=s.d.ref; nc=dk.pncDfk_l; wc=dk.pwcDfk_l; an=s.mn;

    rEc=sqrt(mean((dk.wcDfk(:,earlyC)-ref).^2,2)); rLc=sqrt(mean((dk.wcDfk(:,lateC)-ref).^2,2));
    rLo=sqrt(mean((dk.ncDfk(:,lateC)-ref).^2,2));

    % relative sub-band power, -2 -> stim end
    rHo=arrayfun(@(t) bp(nc(t,sa:sb),2,4)/max(bp(nc(t,sa:sb),0.4,10),eps),(1:size(nc,1))');
    rHc=arrayfun(@(t) bp(wc(t,sa:sb),2,4)/max(bp(wc(t,sa:sb),0.4,10),eps),(1:size(wc,1))');
    rLo1=arrayfun(@(t) bp(nc(t,sa:sb),1,2)/max(bp(nc(t,sa:sb),0.4,10),eps),(1:size(nc,1))');
    rLc1=arrayfun(@(t) bp(wc(t,sa:sb),1,2)/max(bp(wc(t,sa:sb),0.4,10),eps),(1:size(wc,1))');

    HI=accum(HI,rHo,rHc,rLo,rLc,nBins,zwin,slp);
    LO=accum(LO,rLo1,rLc1,rLo,rLc,nBins,zwin,slp);

    % mixed-effects table (CL late RMSE ~ rel 2-4 Hz)
    LME.y=[LME.y; rLc]; LME.x=[LME.x; rHc];
    LME.sess=[LME.sess; repmat(k,numel(rLc),1)]; LME.animal=[LME.animal; repmat({an},numel(rLc),1)];

    % Claim 3: init-dev (CL), early vs late
    idC=abs(dk.wcDfk(:,c0)-ref);
    zEc=(rEc-mean(rEc))/std(rEc); zLcc=(rLc-mean(rLc))/std(rLc);
    c3.sE(end+1)=slp(idC,zEc); c3.sL(end+1)=slp(idC,zLcc);
    e3=quantile(idC,linspace(0,1,nBins+1)); e3(1)=-inf; e3(end)=inf; b3=discretize(idC,e3);
    for b=1:nBins
        c3.reE{b}=[c3.reE{b};rEc(b3==b)]; c3.reL{b}=[c3.reL{b};rLc(b3==b)];
        c3.zeE{b}=[c3.zeE{b};zEc(b3==b)]; c3.zeL{b}=[c3.zeL{b};zLcc(b3==b)];
    end
end

% ---- signed-rank stats ----
pHi=signrank(HI.sCL); pHiInt=signrank(HI.sOL,HI.sCL);
pLo=signrank(LO.sCL); pLoInt=signrank(LO.sOL,LO.sCL);
p3e=signrank(c3.sE); p3l=signrank(c3.sL);
fprintf('\nCLAIM 2  rel 2-4 Hz, LATE: CL slope %+.3f (p=%.4g) OL %+.3f int p=%.4g\n',median(HI.sCL),pHi,median(HI.sOL),pHiInt);
fprintf('CONTROL  rel 1-2 Hz, LATE: CL slope %+.3f (p=%.4g) OL %+.3f int p=%.4g\n',median(LO.sCL),pLo,median(LO.sOL),pLoInt);
fprintf('CLAIM 3  init-dev CL: EARLY %+.3f (p=%.4g) LATE %+.3f (p=%.4g)\n',median(c3.sE),p3e,median(c3.sL),p3l);

% ---- mixed-effects confirmation of claim 2 ----
try
    zx=(LME.x-mean(LME.x))/std(LME.x); zy=(LME.y-mean(LME.y))/std(LME.y);
    tb=table(zy,zx,categorical(LME.sess),categorical(LME.animal),'VariableNames',{'rmse','rel24','session','animal'});
    lme=fitlme(tb,'rmse ~ rel24 + (1 + rel24 | session) + (1 | animal)');
    ci=coefCI(lme); ir=strcmp(lme.CoefficientNames,'rel24');
    fprintf('\nMIXED-EFFECTS (rmse ~ rel24 + (1+rel24|session) + (1|animal)), n=%d trials, %d sessions, %d animals:\n', ...
        height(tb), numel(unique(LME.sess)), numel(unique(LME.animal)));
    fprintf('  rel24 fixed effect (standardized) = %+.3f  [%.3f, %.3f]  t=%.2f  p=%.4g\n', ...
        lme.Coefficients.Estimate(ir), ci(ir,1), ci(ir,2), lme.Coefficients.tStat(ir), lme.Coefficients.pValue(ir));
catch ME
    fprintf('\nMIXED-EFFECTS skipped: %s\n', ME.message);
end

% ---- panels ----
mk_ol_cl(HI, outdir,'claim2_delta_hi24_late','Relative 2-4 Hz quartile (low \rightarrow high)', sig_star(pHiInt), PS, nBins, true);
mk_ol_cl(LO, outdir,'claim2_delta_lo12_late','Relative 1-2 Hz quartile (low \rightarrow high)', sig_star(pLoInt), PS, nBins, true);
mk_earlylate(c3, outdir,'claim3_initdev_early_late', PS, nBins);

fprintf('\n[cl_factor_claim_panels] exported claim2_delta_hi24_late, claim2_delta_lo12_late, claim3_initdev_early_late (.png/.pdf, raw RMSE only)\n');

%% ---- helpers ----
function A=accum(A,xo,xc,yo,yc,nBins,zwin,slp)
    [zo,zc]=zwin(yo,yc);
    A.sOL(end+1)=slp(xo,zo); A.sCL(end+1)=slp(xc,zc);
    e=quantile([xo;xc],linspace(0,1,nBins+1)); e(1)=-inf; e(end)=inf;
    bo=discretize(xo,e); bc=discretize(xc,e);
    for b=1:nBins
        A.rmO{b}=[A.rmO{b};yo(bo==b)]; A.rmC{b}=[A.rmC{b};yc(bc==b)];
        A.zmO{b}=[A.zmO{b};zo(bo==b)]; A.zmC{b}=[A.zmC{b};zc(bc==b)];
    end
end
% Grouped bars replaced by utils/cl_quartile_line.m on 2026-08-13 (user: magnify the difference,
% cleaner neuroscience version). The mark type had to change before the axis could be cropped --
% see the header of that file for why a cropped BAR is not an option.
function mk_ol_cl(A,outdir,base,xlab,star,PS,nBins,~)
    sem = @(x) std(x)/sqrt(max(numel(x),1));
    o = struct('lab',{{'Open loop','Closed loop'}}, 'col',[PS.col_ol; PS.col_cl], ...
        'xlab',xlab, 'ylab','RMSE 1-3 s (%\DeltaF/F)', 'star',star, 'legend',true, ...
        'file',fullfile(outdir,base), 'pdf',true, 'xticks',{{}});
    cl_quartile_line(cellfun(@mean,A.rmO), cellfun(sem,A.rmO), ...
                     cellfun(@mean,A.rmC), cellfun(sem,A.rmC), o);
end
function mk_earlylate(c3,outdir,base,PS,nBins) %#ok<INUSD>
    sem = @(x) std(x)/sqrt(max(numel(x),1));
    o = struct('lab',{{'0-1 s (transient)','1-3 s (settled)'}}, ...
        'col',[0.45 0.75 0.50; 0.10 0.45 0.20], ...
        'xlab','Initial deviation quartile (low \rightarrow high)', 'ylab','RMSE (%\DeltaF/F)', ...
        'star','', 'legend',true, 'file',fullfile(outdir,base), 'pdf',true, 'xticks',{{}});
    cl_quartile_line(cellfun(@mean,c3.reE), cellfun(sem,c3.reE), ...
                     cellfun(@mean,c3.reL), cellfun(sem,c3.reL), o);
end
function s=sig_star(p)
    if p<1e-3; s='***'; elseif p<1e-2; s='**'; elseif p<0.05; s='*'; else; s='n.s.'; end
end
function b=local_slp(x,y); x=x(:);y=y(:);g=isfinite(x)&isfinite(y); B=polyfit(x(g),y(g),1); b=B(1); end
function p=local_bp(seg,Fs,lo,hi)
    seg=detrend(double(seg(:)).','linear'); N=numel(seg);
    w=hann(N).'; P=abs(fft(seg.*w)).^2; P=P(1:floor(N/2)+1);
    fr=(0:floor(N/2))*Fs/N; p=sum(P(fr>=lo & fr<hi));
end
