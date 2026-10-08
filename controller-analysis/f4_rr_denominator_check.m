function RRD = f4_rr_denominator_check(mouse, fields)
% F4_RR_DENOMINATOR_CHECK  Why is a session's RR high: small denominator, or bad control?
%
% RR = ||A-r||^2 / ||D||^2 is a ratio, so a session can sit above 1 for three
% different reasons, and the headline number cannot tell them apart:
%   (a) SMALL DENOMINATOR -- the contra-predicted disturbance D is weak in that
%       session (e.g. a poor Stage-2 predictor shrinks its predictions toward the
%       mean), so even ordinary residual error divides into a large ratio;
%   (b) STANDING OFFSET  -- the controller never settled at the reference, so the
%       numerator is dominated by a constant bias rather than by unrejected
%       fluctuation (this is what the reach gate is meant to catch);
%   (c) GENUINE FAILURE  -- the loop really did not reject the disturbance.
%
% This function separates them with four measurements per session, and reports
% the open-loop comparator that NUMBERS.md flags as missing. Falsifiable
% predictions of the small-denominator hypothesis for a suspect session:
%   1. msD is low relative to the other sessions.
%   2. the numerator is NOT elevated.
%   3. RR_OL is high too -- both conditions divide by the same D. This is the
%      decisive one: it separates a scale artifact (RR_OL high, RR_CL < RR_OL,
%      so feedback still helped) from a control failure (RR_OL ~ 1 < RR_CL).
%   4. across sessions, low predictor R2_te goes with low msD.
%
% Per-trial quantities, settled window [+1,+3] s, same construction as
% f4_cl_reject_lmm.m (D leak-corrected by the session-mean OL dip):
%   msErr = mean((A-ref)^2) = (mean(A)-ref)^2 + var(A)  -> bias2 + fluct
%   msD   = mean(D^2)
%   RR    = msErr/msD        RR_fluct = fluct/msD   (RR with the offset removed)
% Call as f4_rr_denominator_check(mouse, fields) after load_sessions.m, or with no
% arguments to take them from the base workspace. Pass them explicitly when the base
% workspace may have been cleared (impulse-analysis/load_experiments.m does `clear all`).
% Reads caches only; writes data/f4_rr_denominator_check.mat. Changes nothing.
if nargin < 2 || isempty(mouse) || isempty(fields)
    assert(evalin('base','exist(''mouse'',''var'') && exist(''fields'',''var'')'), ...
        'run load_sessions.m first, or pass (mouse, fields)');
    mouse  = evalin('base','mouse');  fields = evalin('base','fields');
end
here = fileparts(mfilename('fullpath')); dataDir = fullfile(here,'data');
bpData = fullfile(fileparts(here),'data');
CFG.nSV_load=500; CFG.Fs=35; CFG.pre_s=1.0; CFG.resp_s=3.0; REF=-5; REACH_TOL=1.5;

RRD = struct('tag',{},'mn',{},'nOL',{},'nCL',{},'R2te',{},'Aset',{},'reach',{}, ...
    'msD_cl',{},'msD_ol',{},'msErr_cl',{},'msErr_ol',{},'bias2_cl',{},'fluct_cl',{},'bias2_ol',{},'fluct_ol',{}, ...
    'RR_cl',{},'RR_ol',{},'RRfluct_cl',{},'RRfluct_ol',{},'Doffset',{});

for s = 1:numel(fields)
    fld = fields{s}; M = mouse.(fld); freeAfter=false;
    if ~isfield(M,'d') || isempty(M.d)
        pth = fullfile(bpData, sprintf('%sctrl%s%s%d.mat', M.mn, M.td(6:7), M.td(9:10), M.en));
        if ~exist(pth,'file'); continue; end
        tmp=load(pth); if ~isfield(tmp,'d'); clear tmp; continue; end
        mouse.(fld).d=tmp.d; mouse.(fld).data=tmp.data; clear tmp;
        if ~isfield(mouse.(fld).d,'ref'); mouse.(fld).d.ref=-5; end
        freeAfter=true;
    end
    S = imp_build_session(mouse, fields, s, dataDir, CFG);
    if freeAfter; mouse.(fld)=rmfield(mouse.(fld),{'d','data'}); end
    if ~S.ok; continue; end

    pre=S.pre; Fs=S.Fs; ref=S.ref; bwin=1:pre;
    wr = pre+round(1*Fs)+1 : pre+round(CFG.resp_s*Fs);

    % --- disturbance, exactly as f4_cl_reject_lmm builds it -----------------
    Gr_ol = S.Gol - mean(S.Gol(:,bwin),2);
    gdipOL = mean(mean(Gr_ol(:,wr),2));          % session-mean OL dip = laser leak
    Gr_cl = S.Gcl - mean(S.Gcl(:,bwin),2);
    D_cl  = Gr_cl - gdipOL;
    % OL comparator: the SAME leak correction applied to the OL trials. Its
    % across-trial mean in the window is 0 by construction, so this is the
    % per-trial disturbance fluctuation; Doffset below records how much mean
    % the CL disturbance carries on top, i.e. how asymmetric the comparison is.
    D_ol  = Gr_ol - gdipOL;

    msD_cl = mean(D_cl(:,wr).^2, 2);  msD_ol = mean(D_ol(:,wr).^2, 2);

    % --- numerator, split into standing offset and fluctuation --------------
    [msE_cl, b2_cl, fl_cl] = err_split(S.Acl(:,wr), ref);
    [msE_ol, b2_ol, fl_ol] = err_split(S.Aol(:,wr), ref);

    ok_cl = isfinite(msE_cl) & isfinite(msD_cl) & msD_cl>0;
    ok_ol = isfinite(msE_ol) & isfinite(msD_ol) & msD_ol>0;

    Aset = mean(mean(S.Acl(:,wr),2));
    RRD(end+1) = struct('tag',S.sess_tag,'mn',S.mn,'nOL',nnz(ok_ol),'nCL',nnz(ok_cl), ...
        'R2te',S.R2_te,'Aset',Aset,'reach',abs(Aset-REF)<=REACH_TOL, ...
        'msD_cl',median(msD_cl(ok_cl)),'msD_ol',median(msD_ol(ok_ol)), ...
        'msErr_cl',median(msE_cl(ok_cl)),'msErr_ol',median(msE_ol(ok_ol)), ...
        'bias2_cl',median(b2_cl(ok_cl)),'fluct_cl',median(fl_cl(ok_cl)), ...
        'bias2_ol',median(b2_ol(ok_ol)),'fluct_ol',median(fl_ol(ok_ol)), ...
        'RR_cl',median(msE_cl(ok_cl)./msD_cl(ok_cl)), ...
        'RR_ol',median(msE_ol(ok_ol)./msD_ol(ok_ol)), ...
        'RRfluct_cl',median(fl_cl(ok_cl)./msD_cl(ok_cl)), ...
        'RRfluct_ol',median(fl_ol(ok_ol)./msD_ol(ok_ol)), ...
        'Doffset',mean(mean(D_cl(:,wr),2))); %#ok<AGROW>
end

% ------------------------------- report ----------------------------------
fprintf('\n===== RR diagnostics, settled 1-3 s (medians over trials) =====\n');
fprintf('%-22s %5s %6s %7s %8s %8s %8s %7s %7s %8s %8s\n', ...
    'session','R2te','Aset','msD_CL','msErr_CL','bias2_CL','fluct_CL','RR_CL','RR_OL','RRfl_CL','RRfl_OL');
[~,ord] = sort([RRD.RR_cl]);
for i = ord
    r = RRD(i);
    fprintf('%-22s %5.2f %6.2f %7.3f %8.3f %8.3f %8.3f %7.2f %7.2f %8.2f %8.2f\n', ...
        r.tag, r.R2te, r.Aset, r.msD_cl, r.msErr_cl, r.bias2_cl, r.fluct_cl, ...
        r.RR_cl, r.RR_ol, r.RRfluct_cl, r.RRfluct_ol);
end

rr=[RRD.RR_cl].'; msd=[RRD.msD_cl].'; r2=[RRD.R2te].'; rrol=[RRD.RR_ol].';
fprintf('\nPrediction 4 (poor predictor -> small D): Spearman rho(R2te, msD_CL) = %+.2f (p=%.3g, n=%d)\n', ...
    corr(r2,msd,'type','Spearman'), spearman_p(r2,msd), numel(r2));
fprintf('Denominator drives RR?          Spearman rho(msD_CL, RR_CL) = %+.2f (p=%.3g)\n', ...
    corr(msd,rr,'type','Spearman'), spearman_p(msd,rr));
fprintf('Numerator drives RR?            Spearman rho(msErr_CL, RR_CL) = %+.2f (p=%.3g)\n', ...
    corr([RRD.msErr_cl].',rr,'type','Spearman'), spearman_p([RRD.msErr_cl].',rr));
fprintf('Prediction 3 (OL comparator):   CL below OL in %d of %d sessions; median RR_OL = %.2f vs RR_CL = %.2f\n', ...
    sum(rr<rrol), numel(rr), median(rrol), median(rr));
for i = 1:numel(RRD)
    if RRD(i).RR_cl > 1
        r = RRD(i);
        fprintf('\n-- %s has RR_CL = %.2f --\n', r.tag, r.RR_cl);
        fprintf('   msD_CL  %.3f = %+.2f SD of the cohort  -> prediction 1 %s\n', ...
            r.msD_cl, zs(r.msD_cl,msd), tern(zs(r.msD_cl,msd)<-1,'SUPPORTED','NOT supported'));
        fprintf('   msErr_CL %.3f = %+.2f SD of the cohort -> prediction 2 %s\n', ...
            r.msErr_cl, zs(r.msErr_cl,[RRD.msErr_cl].'), tern(zs(r.msErr_cl,[RRD.msErr_cl].')<1,'SUPPORTED','NOT supported'));
        fprintf('   RR_OL   %.2f                          -> prediction 3 %s\n', r.RR_ol, ...
            tern(r.RR_ol>r.RR_cl,'SUPPORTED (feedback still helped)','NOT supported (CL worse than OL)'));
        fprintf('   standing offset accounts for %.0f%% of the numerator (bias2 %.3f of msErr %.3f)\n', ...
            100*r.bias2_cl/r.msErr_cl, r.bias2_cl, r.msErr_cl);
        fprintf('   RR with the offset removed: %.2f\n', r.RRfluct_cl);
    end
end

fl_ol=[RRD.RRfluct_ol].'; fl_cl=[RRD.RRfluct_cl].';
fprintf('\nMECHANISM -- fluctuation energy as a fraction of the disturbance it faces:\n');
fprintf('  open loop  median %.2f (passes the disturbance through if ~1)\n', median(fl_ol));
fprintf('  closed loop median %.2f, lower in %d of %d sessions, signrank p=%.3g\n', ...
    median(fl_cl), sum(fl_cl<fl_ol), numel(fl_cl), signrank(log(fl_ol),log(fl_cl),'tail','right'));

save(fullfile(dataDir,'f4_rr_denominator_check.mat'),'RRD');
fprintf('\nsaved -> %s\n', fullfile(dataDir,'f4_rr_denominator_check.mat'));
end

function [ms, bias2, fluct] = err_split(A, ref)
% mean((A-ref)^2) over the window = (trial mean - ref)^2 + within-window variance
mA    = mean(A, 2);
bias2 = (mA - ref).^2;
fluct = mean((A - mA).^2, 2);
ms    = bias2 + fluct;
end
function z = zs(v, all), z = (v - mean(all)) / std(all); end
function p = spearman_p(a, b), [~, p] = corr(a, b, 'type', 'Spearman'); end
function s = tern(c, a, b), if c, s = a; else, s = b; end, end
