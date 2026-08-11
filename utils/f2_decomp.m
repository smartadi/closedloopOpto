function D = f2_decomp(P, M, opt)
%F2_DECOMP  Fig-2 stream, STAGE 4: deploy the predictor -> Actual / Global / Local, + the CATCH control.
%
%   Actual  the measured ipsi trace at the stim site
%   Global  the prediction from stim-UNAFFECTED contra pixels = the ongoing network activity that
%           would have flowed into the ipsi kernel with no stim
%   Local   Actual - Global = the residual, i.e. the LOCAL stim effect, exactly and by construction
%
% *** THE CATCH CONTROL IS THE POINT OF THIS FILE ***
% Everything upstream can look healthy and still be manufacturing a residual: any predictor that
% systematically under-shoots around an event produces a "Local dip" whether or not a stim happened.
% So the identical decomposition is run on the session's 0 V catch trials (or, where the session has
% none, the pseudo-catch windows sampled from spontaneous gaps). Those windows contain NO stim.
%       Local dip on catch ~ 0            -> the residual on stim trials is a stim effect
%       Local dip on catch ~ stim trials  -> the pipeline manufactures residual; every capture
%                                            number is void and the OLS model IS broken
% It costs one extra deployment and it is the cheapest decisive test available. Report it always.
%
% INPUT   P from f2_prep | M from f2_model
%         opt .wantTraces(true) per-trial traces (needed by the state stage) | .verbose(true)
% OUTPUT  D  .amps .Adip .Gdip .Ldip [nA]        per-amp trial-averaged dips
%            .capPct .leakPct [nA]               Local / Global as % of Actual
%            .trA .trG .trL {nA}[Wb x 1]         trial-averaged traces
%            .catch  .Adip .Gdip .Ldip .ratio    the no-stim control
%            .ST                                 per-trial DVs + state markers (imp_statedep_trials)
% -------------------------------------------------------------------------------------------------
if nargin < 3, opt = struct(); end
if ~isfield(opt,'wantTraces') || isempty(opt.wantTraces), opt.wantTraces = true; end
if ~isfield(opt,'verbose')    || isempty(opt.verbose),    opt.verbose    = true; end
vb = opt.verbose;  nA = P.nA;  nG = P.nG;  preN = P.preN;  Wb = P.Wb;
b = M.b;  use_mot = M.use_motion;  bPix = b(1:nG);

%% ---- (a) per-amp trial-averaged decomposition -------------------------------------------------
Adip=nan(nA,1); Gdip=nan(nA,1); Ldip=nan(nA,1);
Areb=nan(nA,1); Greb=nan(nA,1); Lreb=nan(nA,1);
trA=cell(nA,1); trG=cell(nA,1); trL=cell(nA,1);
for ai = 1:nA
    if isempty(P.evZc{ai}), continue; end
    aA = P.aAc{ai};  dc = P.dcc{ai};  rc = P.rcc{ai};
    yg = (bPix.'*P.evZc{ai}).';
    if use_mot, yg = yg + b(M.nP)*P.evMot(:,ai); end
    yg = yg - mean(yg(1:preN));
    rL = aA - yg;
    Adip(ai)=mean(aA(dc));  Gdip(ai)=mean(yg(dc));  Ldip(ai)=mean(rL(dc));
    if ~isempty(rc), Areb(ai)=mean(aA(rc)); Greb(ai)=mean(yg(rc)); Lreb(ai)=mean(rL(rc)); end
    trA{ai}=aA(:);  trG{ai}=yg(:);  trL{ai}=rL(:);
end
capPct  = 100*Ldip./Adip;
leakPct = 100*Gdip./Adip;

%% ---- (b) CATCH CONTROL: the same decomposition on windows with NO stim ------------------------
% Built from the SAME operators (mu_p/sd_p z-scoring, same weights, same baselining, same dip
% window) as the stim trials -- if any step of that chain generates a spurious dip, it shows up here.
dcRef = P.dcc{find(~cellfun(@isempty,P.dcc),1)};
if isempty(dcRef), dcRef = P.dipCols; end
onF0 = P.onF0(:);  nT0 = numel(onF0);
idx0 = onF0.' + P.rel(:);
Z0 = (P.Ug*double(P.V(:,idx0(:))) - P.mu_p)./P.sd_p;  Z0 = reshape(Z0, nG, Wb, nT0);
ev0 = mean(Z0,3);  ev0 = ev0 - mean(ev0(:,1:preN),2);
a0  = mean(reshape(double(P.y_full(idx0(:))), Wb, nT0), 2);  a0 = a0 - mean(a0(1:preN));
g0  = (bPix.'*ev0).';
if use_mot && P.haveMot
    m0v = local_fill((P.motz(min(max(idx0(:),1),numel(P.motz))) - P.motNorm.mu)/P.motNorm.sd);
    em0 = mean(reshape(m0v, Wb, nT0), 2);  em0 = em0 - mean(em0(1:preN));
    g0  = g0 + b(M.nP)*em0;
end
g0 = g0 - mean(g0(1:preN));
r0 = a0 - g0;
% SINGLE-TRIAL catch dips give the NOISE SCALE of a dip measurement in this session with no stim.
% That scale is what decides, below, whether an amplitude produced a real response at all.
a0tr = reshape(double(P.y_full(idx0(:))), Wb, nT0);
a0tr = a0tr - mean(a0tr(1:preN,:), 1);
sd_trial = std(mean(a0tr(dcRef,:), 1), 0, 2, 'omitnan');
clear Z0 a0tr

%% ---- (b2) which amplitudes actually produced a response ---------------------------------------
% capture% = Local/Actual is a RATIO, so at an amplitude with no dip its denominator is noise and
% the ratio is meaningless -- on AL_0033 the 0.5 V row reads -93% purely because Actual is +0.076.
% Including such rows in the median corrupts the headline. An amp counts only if its trial-averaged
% Actual dip beats 2x the no-stim standard error at that trial count. All rows are still PRINTED;
% only the summary medians are restricted.
sem = sd_trial ./ sqrt(max(P.nT_amp(:),1));
ampOK = Adip(:) < -2*sem;
if ~any(ampOK)
    ampOK = isfinite(Adip(:));                      % degenerate session: do not silently return NaN
end

% Ratio against the MEDIAN stim-trial Local dip over the RESPONDING amps. Anything above ~0.15
% means a meaningful part of the "stim effect" is an event-locked artefact of the decomposition.
LdipMed = median(Ldip(ampOK),'omitnan');
D_catch = struct('kind',P.catch_kind, 'nT',nT0, 'Adip',mean(a0(dcRef)), 'Gdip',mean(g0(dcRef)), ...
                 'Ldip',mean(r0(dcRef)), 'trA',a0(:), 'trG',g0(:), 'trL',r0(:), ...
                 'sd_trial',sd_trial, 'ratio', mean(r0(dcRef))/local_nz(LdipMed));

%% ---- (c) per-trial DVs + state markers --------------------------------------------------------
% Reuses utils/imp_statedep_trials.m verbatim: the state-window constants (motion [-2,+0.5] s,
% var/delta [-1,+0.5] s, pre-control [-0.2,0] s) are LOCKED project decisions and must have exactly
% one definition in the repo. Uflat/gridIdx are passed as the grid-only shim (see f2_prep memory note).
bUse = repmat({bPix}, nA, 1);            % ONE pooled weight vector, identical at every amplitude
ST = imp_statedep_trials(struct('Uflat',P.Ug, 'gridIdx',1:nG, 'V',P.V, 'mu_p',P.mu_p, 'sd_p',P.sd_p, ...
        'y_full',P.y_full, 'nF',P.nF, 'onFcell',{P.onFcell}, 'bUse',{bUse}, 'dipCols',{P.dcc}, ...
        'rel',P.rel, 'preN',preN, 'Wb',Wb, 'Fs',P.Fs, 'amps',P.amps, 'motz',P.motz, ...
        'wantTraces',opt.wantTraces));

D = struct('label',P.label, 'caveat',P.caveat, 'amps',P.amps, 'nT_amp',P.nT_amp, ...
           'Adip',Adip, 'Gdip',Gdip, 'Ldip',Ldip, 'Areb',Areb, 'Greb',Greb, 'Lreb',Lreb, ...
           'capPct',capPct, 'leakPct',leakPct, 'trA',{trA}, 'trG',{trG}, 'trL',{trL}, ...
           'catch',D_catch, 'ST',ST, 'rel',P.rel, 'Fs',P.Fs, 'preN',preN, ...
           'dcc',{P.dcc}, 'use_motion',use_mot, 'ampOK',ampOK, ...
           'capMed',median(capPct(ampOK),'omitnan'), 'leakMed',median(leakPct(ampOK),'omitnan'));

if vb
    fprintf('\n[F2-DECOMP] %s\n', P.label);
    fprintf('   %-8s %5s | %9s %9s %9s | %8s %8s  %s\n', ...
            'amp(V)','nTr','Actual','Global','Local','cap%','leak%','responded?');
    for ai = 1:nA
        fprintf('   %-8.2f %5d | %9.3f %9.3f %9.3f | %8.0f %8.0f  %s\n', ...
            P.amps(ai), P.nT_amp(ai), Adip(ai), Gdip(ai), Ldip(ai), capPct(ai), leakPct(ai), ...
            local_tern(ampOK(ai),'yes','NO  <- ratio meaningless, excluded from the median'));
    end
    fprintf('   --> median over the %d RESPONDING amps: capture %.0f%% (leak %.0f%%)\n', ...
            nnz(ampOK), median(capPct(ampOK),'omitnan'), median(leakPct(ampOK),'omitnan'));
    fprintf('   [CATCH %s, n=%d]  Actual %.3f | Global %.3f | Local %.3f  ->  %.0f%% of the median stim Local dip\n', ...
            D_catch.kind, nT0, D_catch.Adip, D_catch.Gdip, D_catch.Ldip, 100*D_catch.ratio);
    if abs(D_catch.ratio) > 0.15
        fprintf(2,['   ** CATCH FAILS: a no-stim window produces %.0f%% of the "stim" Local dip. The\n' ...
                   '      decomposition is manufacturing residual -- do NOT quote the capture numbers. **\n'], ...
                   100*D_catch.ratio);
    else
        fprintf('   catch is clean (|%.0f%%| <= 15%%) -> the residual on stim trials is a stim effect\n', ...
                100*D_catch.ratio);
    end
end
end

% -------------------------------------------------------------------------------------------------
function v = local_fill(v)
v = v(:);  v(~isfinite(v)) = 0;
end

function x = local_nz(x)
if ~isfinite(x) || x == 0, x = eps; end
end

function s = local_tern(c,a,b)
if c, s = a; else, s = b; end
end
