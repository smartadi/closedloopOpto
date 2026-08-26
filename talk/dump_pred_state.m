%% dump_pred_state.m -- open-loop PREDICTION error vs pre-stimulus state (motion, variance)
% Aim-1 companion to state_quartile_panels.m, but the metric is a drive-only
% PREDICTION error, not a control error. For the constant-reference open-loop
% trials the simplest predictor knows only the laser command and predicts the
% session-mean evoked response; the per-trial prediction error is the residual
% of the trial's evoked scalar (mean dF/F over the 0..3 s evoked window) from
% that mean, POOLED WITHIN session (so a bin is not "more uncertain" merely
% because it holds a harder session). We report the pooled within-session SD of
% that residual by quartile of two pre-stimulus state markers:
%   motion    mean z-motion, (onset-2 s .. trial end)      -- power-independent
%   prevar    var(dF/F) over [-2,0) s                       -- POWER CONFOUND (caveat)
% Matches paper Fig 2J/2K methodology; motion-clean subset for the variance panel
% (its own threshold would make the motion panel circular, so motion uses all trials).
% Writes JSON; no figure windows.

cd('C:\Users\aditya\Documents\projects\brain_paper');
addpath(genpath(fullfile(pwd,'utils')));
addpath(fullfile(pwd,'controller-analysis'));

r_lean = 1;
load_sessions;

root  = 'C:\Users\aditya\Documents\projects\brain_paper';
Fs=35; dur=3; NKEEP=13; motThresh=1.5; PRE_S=2; nBins=4;
c0_l = 3*Fs + 1; preA = c0_l - round(PRE_S*Fs); preB = c0_l - 1;
evA = c0_l; evB = c0_l + dur*Fs;                 % 0..3 s evoked window in pncDfk_l

fields = fields(1:min(NKEEP,numel(fields)));
nS = numel(fields);

MOT=[]; PVv=[]; RESID=[]; SESS=[]; KEEP=false(0,1);
for k = 1:nS
    mn = mouse.(fields{k}).mn; td = mouse.(fields{k}).td; en = mouse.(fields{k}).en;
    pc = fullfile(root,'data', sprintf('%sctrl%s%s%d.mat', mn, td(6:7), td(9:10), en));
    if ~isfile(pc); continue; end
    T = load(pc,'data'); D = T.data; clear T
    if ~isfield(D,'ncmotion') || ~any(D.ncmotion(:)); clear D; continue; end

    pnc = D.pncDfk(:, 246:end);          % OL trials, 3 s pre .. dur+3 s
    nmc = size(D.ncmotion,2); ons = nmc - Fs*dur;
    wa = max(1, ons - round(2*Fs)); wb = min(nmc, ons + dur*Fs);
    mo = mean(D.ncmotion(:, wa:wb), 2);

    no = min([size(pnc,1) numel(mo)]);
    pnc = pnc(1:no,:); mo = mo(1:no);
    so  = pnc(:, preA:preB);                    % pre-stim segment
    ev  = mean(pnc(:, evA:evB), 2);             % per-trial evoked scalar (dF/F)
    pv  = var(so, 0, 2);

    g = isfinite(ev) & isfinite(mo) & all(isfinite(so),2);
    if sum(g) < 12; clear D pnc so; continue; end
    ev = ev(g); mo = mo(g); pv = pv(g);
    e  = ev - mean(ev);                          % drive-only prediction residual

    MOT=[MOT; mo]; PVv=[PVv; pv]; RESID=[RESID; e];
    SESS=[SESS; k*ones(numel(e),1)]; KEEP=[KEEP; abs(mo)<=motThresh];
    clear D pnc so
end
fprintf('[pred] sessions pooled, trials=%d\n', numel(RESID));

function [pe,se] = pooled_sd(resid, sess, bin, nB)
    pe=nan(1,nB); se=nan(1,nB);
    for b=1:nB
        num=0; den=0; vals=[];
        for c=unique(sess(bin==b)).'
            v=resid(bin==b & sess==c); v=v(isfinite(v));
            if numel(v)<3; continue; end
            num=num+(numel(v)-1)*var(v); den=den+(numel(v)-1); vals=[vals; v];
        end
        pe(b)=sqrt(num/max(den,eps));
        se(b)=pe(b)/sqrt(2*max(den,1));          % approx SE of an SD
    end
end

function b = wsq(state, sess, nB)
    b=nan(size(state));
    for c=unique(sess).'
        m=sess==c; e=quantile(state(m), linspace(0,1,nB+1));
        t=discretize(state(m), e); t(isnan(t))=nB; b(m)=t;
    end
end

% motion: all trials ; variance: motion-clean
bm = wsq(MOT, SESS, nBins);
[pm, sm] = pooled_sd(RESID, SESS, bm, nBins);
kv = KEEP;
bv = nan(size(PVv)); bv(kv) = wsq(PVv(kv), SESS(kv), nBins);
[pv2, sv2] = pooled_sd(RESID(kv), SESS(kv), bv(kv), nBins);

out = struct();
out.motion   = struct('pe',pm,'se',sm,'nOL',numel(RESID));
out.variance = struct('pe',pv2,'se',sv2,'nOL',sum(kv));
jf = 'C:\Users\aditya\AppData\Local\Temp\claude\C--Users-aditya-Documents-projects-brain-paper\69483c53-45a2-45f3-9e5d-0965ff7a6be0\scratchpad\pred_state.json';
fid=fopen(jf,'w'); fprintf(fid,'%s',jsonencode(out)); fclose(fid);
fprintf('[pred] motion  Q1->Q4 %.3f -> %.3f\n', pm(1), pm(end));
fprintf('[pred] variance Q1->Q4 %.3f -> %.3f\n', pv2(1), pv2(end));
fprintf('[pred] wrote %s\n', jf);
