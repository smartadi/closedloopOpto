% ctrl_cl_poles.m -- does closed-loop feedback pull the dominant pole toward the
% origin, and does it shift the operating gain toward the reference?
%
% PURPOSE (user, 2026-10-03): this stream exists to SUPPORT A CONTROL-THEORETIC
% INTERPRETATION in the Discussion. It is not a hypothesis test and must not be
% written as one -- no pooled p-value, no star. Per-session numbers with honest
% uncertainty, and a tally of how the sessions fall.
%
% DESIGN CONSTRAINTS, all set by the user:
%   * NO TF-fit reuse. Nothing is inherited from imp_tf_fits.mat or any other
%     session. Conditions drift wildly across experiments, so every session is fit
%     independently from its own data.
%   * NO Kp/Ki/clamping model. Building the loop analytically would import the
%     boxcar "integral", the one-sided saturation and the anti-windup, each an
%     approximation. We learn the LTI from data instead.
%   * The reference is EXOGENOUS (a constant the experimenter sets, uncorrelated
%     with neural disturbance), so fitting reference->output is unbiased indirect
%     closed-loop identification. Fitting u->y would NOT be: in closed loop u is
%     correlated with the disturbance through the feedback path.
%
% WHAT IS IDENTIFIED. The two conditions identify DIFFERENT OPERATORS, which is
% the whole point but must be worded carefully in the text:
%     OL trials: input is the fixed feedforward command  -> the PLANT  P
%     CL trials: input is the fixed reference            -> the CLOSED LOOP  T
% So the statement is "closed-loop poles sit nearer the origin than open-loop
% PLANT poles", never "the same system's poles moved".
%
% WHY A DOMINANT-MODE EXPONENTIAL FIT AND NOT A HIGH-ORDER MODEL. The reference is
% constant, so each trial is ONE STEP. A single step is thin excitation: the
% dominant mode is identifiable, higher modes are not. Fitting 4 poles to a step
% would be fitting noise. We fit 1- and 2-exponential step responses, select by
% AIC, and report ONLY the dominant (slowest) mode.
%
% TWO RESULTS, DELIBERATELY SEPARATED. The gain claim and the pole claim would
% otherwise swallow each other -- a drive change moves the operating point, which
% could masquerade as a pole change:
%   (1) DC / GAIN  : mean drive and steady-state offset, in RAW units.
%   (2) DYNAMICS   : poles fit to responses NORMALIZED to their own steady state,
%                    so the comparison carries no gain information at all.
% If (2) survives normalization it is independent of (1). If it does not, only (1)
% stands -- and that is worth knowing before the Discussion is written.
%
% CAVEATS the output prints and the text must keep:
%   - trial-averaging suppresses disturbance as sqrt(N) ONLY if it is zero-mean;
%     a stimulus-locked disturbance biases both fits.
%   - thin sessions (m6 is 14 OL / 16 CL) give very wide bootstrap CIs.
%   - sessions whose normalized fit is poor are flagged and NOT interpreted.

% NOTE: `run` cd's into the script's own folder, so a relative
% 'controller-analysis/load_sessions.m' resolves to controller-analysis/
% controller-analysis/ and fails. Resolve against this file's location instead.
if ~exist('mouse','var') || ~exist('fields','var')
    CPL_here = fileparts(mfilename('fullpath'));
    if isempty(CPL_here), CPL_here = pwd; end
    r_ctrl = 1;  run(fullfile(CPL_here,'load_sessions.m'));
end

fs   = 35;  Ts = 1/fs;
iOn  = 35*3 + 1;             % pncDfk/pwcDfk start 3 s before onset
dur  = 3;                    % stimulation length, s
iEnd = iOn + dur*fs;         % t = +3 s
iSS  = (iOn + 1*fs) : iEnd;  % steady state read over t = [1, 3] s
iPre = (iOn - 1*fs) : (iOn - 1);
REF  = -5;
NB   = 500;                  % bootstrap draws
R2MIN = 0.80;                % below this the shape fit is not interpreted

t = (0:(iEnd-iOn)).' * Ts;

CP = struct([]);
fprintf('\n%-5s %-9s | %-25s | %-25s | drive (V)     | offset |y-ref|\n', ...
        'sess','mouse','OL  tau [CI]      |z|','CL  tau [CI]      |z|');
fprintf('%s\n', repmat('-',1,115));

for k = 1:numel(fields)
    f = fields{k};
    if ~isfield(mouse.(f),'data') || ~isfield(mouse.(f).data,'pncDfk_l'), continue; end
    D = mouse.(f).data;
    YOL = D.pncDfk_l;  YCL = D.pwcDfk_l;
    if isempty(YOL) || isempty(YCL), continue; end
    if size(YOL,2) < iEnd || size(YCL,2) < iEnd, continue; end

    [tauOL, zOL, r2OL, ciOL] = local_fit_boot(YOL, iOn, iEnd, iSS, iPre, t, Ts, NB);
    [tauCL, zCL, r2CL, ciCL] = local_fit_boot(YCL, iOn, iEnd, iSS, iPre, t, Ts, NB);

    % ---- DC / gain, in RAW units (no normalization) ----
    yssOL = mean(mean(YOL(:,iSS),2));   yssCL = mean(mean(YCL(:,iSS),2));
    uOL = NaN; uCL = NaN;
    if isfield(D,'ncInp') && ~isempty(D.ncInp), uOL = mean(D.ncInp(:)); end
    if isfield(D,'wcInp') && ~isempty(D.wcInp), uCL = mean(D.wcInp(:)); end

    flag = '';
    if r2OL < R2MIN || r2CL < R2MIN, flag = '  [LOW R2]'; end
    fprintf('%-5s %-9s | %5.3f [%5.3f %5.3f] %5.3f | %5.3f [%5.3f %5.3f] %5.3f | %5.3f->%5.3f | %5.2f->%5.2f%s\n', ...
        f, mouse.(f).mn, tauOL, ciOL(1), ciOL(2), zOL, tauCL, ciCL(1), ciCL(2), zCL, ...
        uOL, uCL, abs(yssOL-REF), abs(yssCL-REF), flag);

    CP(end+1).sess = f; %#ok<SAGROW>
    CP(end).mn=mouse.(f).mn; CP(end).tauOL=tauOL; CP(end).tauCL=tauCL;
    CP(end).zOL=zOL; CP(end).zCL=zCL; CP(end).ciOL=ciOL; CP(end).ciCL=ciCL;
    CP(end).r2OL=r2OL; CP(end).r2CL=r2CL; CP(end).uOL=uOL; CP(end).uCL=uCL;
    CP(end).offOL=abs(yssOL-REF); CP(end).offCL=abs(yssCL-REF);
    CP(end).nOL=size(YOL,1); CP(end).nCL=size(YCL,1);
end

good = arrayfun(@(c) c.r2OL>=R2MIN && c.r2CL>=R2MIN, CP);
zq   = arrayfun(@(c) c.zCL < c.zOL, CP);
offq = arrayfun(@(c) c.offCL < c.offOL, CP);
uq   = arrayfun(@(c) abs(c.uCL) > abs(c.uOL), CP);
fprintf('\n%s\n', repmat('=',1,72));
fprintf('sessions with interpretable shape fits : %d of %d\n', sum(good), numel(CP));
fprintf('|z_CL| < |z_OL|  (pole nearer origin)  : %d of %d  (%d of %d interpretable)\n', ...
        sum(zq), numel(CP), sum(zq & good), sum(good));
fprintf('steady-state offset smaller in CL      : %d of %d\n', sum(offq), numel(CP));
fprintf('mean |drive| larger in CL              : %d of %d\n', sum(uq), numel(CP));
fprintf('%s\n', repmat('=',1,72));
assignin('base','CP',CP);

% ---------------------------------------------------------------------------
function [tau, z, r2, ci] = local_fit_boot(Y, iOn, iEnd, iSS, iPre, t, Ts, NB)
    [tau, r2] = local_fit_one(mean(Y,1), iOn, iEnd, iSS, iPre, t);
    z = exp(-Ts/tau);
    n = size(Y,1);  bt = nan(NB,1);
    for b = 1:NB
        bt(b) = local_fit_one(mean(Y(randi(n,n,1),:),1), iOn, iEnd, iSS, iPre, t);
    end
    bt = bt(isfinite(bt));
    if isempty(bt), ci = [NaN NaN]; else, ci = prctile(bt,[2.5 97.5]); end
end

function [tau, r2] = local_fit_one(y, iOn, iEnd, iSS, iPre, t)
    tau = NaN; r2 = NaN;
    y0  = mean(y(iPre));
    yss = mean(y(iSS));
    den = yss - y0;
    if ~isfinite(den) || abs(den) < 1e-9, return; end
    yn  = (y(iOn:iEnd) - y0) / den;        % normalized step: 0 -> 1
    yn  = yn(:);
    opt = optimset('Display','off','TolX',1e-6,'TolFun',1e-9);
    f1 = @(p) sum((yn - (1 - exp(-t/exp(p(1))))).^2);
    p1 = fminsearch(f1, log(0.3), opt);   s1 = f1(p1);
    f2 = @(p) sum((yn - (1 - local_mix(p,t))).^2);
    p2 = fminsearch(f2, [log(0.15); log(0.6); 0], opt);   s2 = f2(p2);
    N  = numel(yn);
    aic1 = N*log(s1/N) + 2*2;   aic2 = N*log(s2/N) + 2*4;
    if aic2 < aic1
        tau = max(exp(p2(1)), exp(p2(2)));   % DOMINANT = slowest mode
        sse = s2;
    else
        tau = exp(p1(1));  sse = s1;
    end
    r2 = 1 - sse/sum((yn-mean(yn)).^2);
end

function m = local_mix(p, t)
    a = 1/(1+exp(-p(3)));
    m = a*exp(-t/exp(p(1))) + (1-a)*exp(-t/exp(p(2)));
end
