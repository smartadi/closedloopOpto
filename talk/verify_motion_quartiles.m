%% verify_motion_quartiles.m -- audit the motion definition/window/binning against the
%% canonical panel in controller-analysis/motion_analysis.m ('combined' mode).
%
% Written because talk/state_quartile_panels.m produced a Q1<Q2 spike the published motion
% panel does not have. Checks, per session and then pooled:
%   1. dur  -- the motion window depends on it; state_quartile_panels hardcoded dur = 3.
%              Recovered from the stored window widths, which are fixed by controllerData:
%                 size(ncmotion,2) = 35*(dur+2)+1     size(ncDfk,2) = 35*(dur+2)+1
%                 size(pncDfk,2)   = 35*(dur+13)+1
%   2. window -- onset_col = ncols - 35*dur; combined mode = [onset-2 s, onset+dur].
%   3. binning -- motion_analysis computes quantile EDGES INSIDE THE SESSION LOOP, i.e.
%              quartiles are WITHIN-SESSION and only the resulting bins are pooled.
%              state_quartile_panels used one global edge set across all pooled trials.
%   4. y scale -- old figures read ~30 because er_*Dfk was un-normalised norm(); since
%              2026-07-16 it is RMSE = norm/sqrt(N). Printed both ways so the numbers can
%              be compared against the pre-2026-07-16 panel directly.
%
% Read-only: prints, exports nothing.

cd('C:\Users\aditya\Documents\projects\brain_paper');
addpath(genpath(fullfile(pwd,'utils')));
addpath(fullfile(pwd,'controller-analysis'));

r_lean = 1;
load_sessions;

root  = 'C:\Users\aditya\Documents\projects\brain_paper';
Fs    = 35;  NKEEP = 13;  nBins = 4;
fields = fields(1:min(NKEEP,numel(fields)));

Mg=[]; Yg=[]; Lg=[]; Bw=[]; Sg=[];      % pooled motion, RMSE, OL/CL label, within-sess bin
fprintf('\n%-5s %-8s %-11s %4s %5s %5s %6s | %-28s | %s\n', 'sess','mouse','date', ...
        'dur','nMot','nDfk','nTr','motion  min   med   max','within-session quartile edges');
for k = 1:numel(fields)
    mn = mouse.(fields{k}).mn; td = mouse.(fields{k}).td; en = mouse.(fields{k}).en;
    pc = fullfile(root,'data', sprintf('%sctrl%s%s%d.mat', mn, td(6:7), td(9:10), en));
    if ~isfile(pc); continue; end
    T = load(pc,'data'); D = T.data; clear T
    if ~isfield(D,'ncmotion') || ~any(D.ncmotion(:)); clear D; continue; end

    nmc  = size(D.ncmotion,2);
    dur  = (nmc-1)/Fs - 2;                       % from controllerData's W_mot
    durD = (size(D.ncDfk,2)-1)/Fs - 2;           % cross-check from W_dfk
    durP = (size(D.pncDfk,2)-1)/Fs - 13;         % cross-check from W_pdfk
    if ~isequal(dur,durD,durP)
        fprintf(2,'  !! %s dur mismatch: mot %.3g  dfk %.3g  pdfk %.3g\n', fields{k}, dur, durD, durP);
    end

    ons = nmc - Fs*dur;
    wa  = max(1, ons - round(2*Fs));  wb = min(nmc, ons + dur*Fs);
    mo  = mean(D.ncmotion(:, wa:wb), 2);   mc = mean(D.wcmotion(:, wa:wb), 2);
    yo  = D.er_ncDfk(:);                   yc = D.er_wcDfk(:);
    no  = min(numel(mo),numel(yo));  nc = min(numel(mc),numel(yc));
    mo=mo(1:no); yo=yo(1:no); mc=mc(1:nc); yc=yc(1:nc);

    aM = [mo; mc];  aY = [yo; yc];  aL = [zeros(no,1); ones(nc,1)];
    e  = quantile(aM, [0 .25 .5 .75 1]);
    b  = discretize(aM, e);  b(isnan(b)) = nBins;

    fprintf('%-5s %-8s %-11s %4g %5d %5d %6d | %+6.2f %+6.2f %+6.2f        | %s\n', ...
        fields{k}, mn, td, dur, nmc, size(D.ncDfk,2), no+nc, min(aM), median(aM), max(aM), ...
        strjoin(compose('%+.2f', e), ' '));

    Mg=[Mg; aM]; Yg=[Yg; aY]; Lg=[Lg; aL]; Bw=[Bw; b]; Sg=[Sg; k*ones(no+nc,1)]; %#ok<AGROW>
    clear D
end

eg = quantile(Mg, [0 .25 .5 .75 1]);
Bg = discretize(Mg, eg);  Bg(isnan(Bg)) = nBins;

fprintf('\npooled %d trials (OL %d / CL %d) from %d sessions\n', ...
        numel(Yg), sum(Lg==0), sum(Lg==1), numel(unique(Sg)));
fprintf('GLOBAL edges: %s\n\n', strjoin(compose('%+.3f', eg), ' '));

show('WITHIN-SESSION quartiles  (what motion_analysis.m does)', Bw, Lg, Yg, nBins, Sg);
show('GLOBAL quartiles          (what state_quartile_panels.m did)', Bg, Lg, Yg, nBins, Sg);

function show(ttl, B, L, Y, nBins, S)
    fprintf('== %s ==\n', ttl);
    fprintf('   %-4s %8s %8s %8s | %8s %8s | %s\n', 'bin','n OL','n CL','', ...
            'OL RMSE','CL RMSE','OL/CL as old un-normalised norm');
    for b = 1:nBins
        io = B==b & L==0;  ic = B==b & L==1;
        fprintf('   Q%-3d %8d %8d %8s | %8.2f %8.2f | %7.1f %7.1f\n', b, sum(io), sum(ic), '', ...
            mean(Y(io)), mean(Y(ic)), mean(Y(io))*sqrt(106), mean(Y(ic))*sqrt(106));
    end
    % how many sessions actually contribute to each bin -- a bin fed by one session is
    % reporting that session's difficulty, not a motion effect
    fprintf('   sessions per bin:');
    for b = 1:nBins; fprintf(' Q%d=%d', b, numel(unique(S(B==b)))); end
    fprintf('\n\n');
end
