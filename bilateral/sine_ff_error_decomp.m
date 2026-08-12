% bilateral/sine_ff_error_decomp.m
% ============================================================================
% PARKED 2026-08-12 (user: "table this for now"). Nothing here is a registered
% paper panel. Kept so the analysis can be picked up without re-deriving it.
% Run after bilateral/load_bilateral.m (needs `sessions` with s1/s2/s3).
% ============================================================================
%
% THE QUESTION IT ANSWERS
%   "How tightly does each controller force the reference sine, and which mode
%    is best?" Eight framings were tested (2026-08-12). Every SHAPE-NORMALISED
%   one -- correlation with the reference, max cross-correlation, coherence,
%   |1-T|, error power at f0, leave-one-out template match, dispersion of the
%   z-scored trace -- names **OL+preview**, in 3/3 sessions. That is structural,
%   not a fluke: "shape" means dividing out offset and amplitude, and the OFFSET
%   term is exactly where CL+preview's advantage lives (lowest DC error 3/3,
%   and 40-65% of total error power sits there). A shape metric cannot show a
%   feedback benefit by construction. Do not re-run the shape family expecting
%   a different answer; see RESEARCH.md 2026-08-12 for the full table.
%
% WHAT IS COMPUTED HERE (three sections, each independently useful)
%   [DECOMP]  Error-power decomposition. The stim window holds exactly 4 cycles
%             of the 1 Hz drive, so 1 Hz lands on an FFT bin and Parseval splits
%             per-trial squared error EXACTLY into offset (DC) + at-f0 + broadband.
%             Total bar height = mean per-trial RMSE^2, i.e. the same quantity
%             as panel 5G, taken apart. Preview shrinks the f0 term ~3x in 6/6
%             comparisons; feedback shrinks the broadband term in 3/3.
%   [TRK]     |1 - T(jw0)| per trial, T = Y(f0)/R(f0). Zero = perfect tracking in
%             amplitude AND phase. Pooled: OL 0.974 -> OL+p 0.408 (p=6.8e-24),
%             CL 0.673 -> CL+p 0.563 (p=0.0038), OL+p vs CL+p p=4.1e-5.
%   [TRADE]   The trade-off plane: x = |1-T| (preview moves a mode LEFT),
%             y = across-trial variance (feedback moves it DOWN). This is the
%             one panel that supports the intended claim honestly:
%             **CL+preview dominates plain CL on BOTH axes, OL is dominated by
%             both closed-loop modes, and only OL+p and CL+p are non-dominated
%             -- in all 3 sessions.** It does NOT claim CL+preview is best on
%             any single axis, because it is not.
%
% IF PICKED UP AGAIN
%   - [TRADE] is the panel to promote; 5.4 x 5.0, and 5H's 4.2 x 5.4 slot is the
%     natural home if 5H is dropped.
%   - The [DECOMP] draft drew dots = per-session TOTALS, which is ambiguous next
%     to a stacked bar. Drop them or split them per segment.
%   - Results/Discussion currently say "the only mode to engage both mechanisms";
%     that would be upgraded to the dominance statement.

SIDE = 'right'; fs = 35;
TAGS = {'s1','s2','s3'};
MODE_CODES = [2 1 3 0]; MODE_SHORT = {'OL','OL+p','CL','CL+p'};

nS = numel(TAGS); nM = numel(MODE_CODES);
DC = nan(nS,nM); F0 = nan(nS,nM); BB = nan(nS,nM);   % error power, per (sess,mode)
FID = nan(nS,nM); VARr = nan(nS,nM);                 % median |1-T| ; across-trial var
TRK = cell(nS,nM);                                   % per-trial |1-T|

for ti = 1:nS
    s = sessions.(TAGS{ti});
    N = round(s.sine.dur*fs);            % EXACTLY dur seconds -> f0 on a bin
    nPre = round(2*fs);
    k0 = round(s.sine.hz*N/fs) + 1;      % 1-based index of the drive bin
    nH = floor(N/2) + 1;
    dF = s.(SIDE).dFoF(:).'; rr = s.ref_raw(:).'; ref0 = s.sine.ref0;
    sideMask = strcmp({s.trial_meta.side}, SIDE); fc = [s.trial_meta.ff_cond];
    % one-sided power; sum(pw) == mean(x.^2) exactly (Parseval)
    pw = @(X) [abs(X(1))^2, 2*abs(X(2:nH-1)).^2, abs(X(nH))^2];
    for m = 1:nM
        acc = zeros(1,3); e = []; Y = []; nn = 0;
        for j = [s.trial_meta((fc==MODE_CODES(m)) & sideMask).trial_idx]
            i0 = s.onset_idx(j);
            if isnan(i0) || i0-nPre < 1 || i0+N > numel(dF) || i0+N > numel(rr); continue; end
            y = dF(i0:i0+N-1); r = ref0 - rr(i0:i0+N-1);
            Fy = fft(y)/N; Fr = fft(r)/N; Pe = pw(fft(y-r)/N);
            acc = acc + [Pe(1), Pe(k0), sum(Pe)-Pe(1)-Pe(k0)];
            e(end+1) = abs(1 - Fy(k0)/Fr(k0));   %#ok<AGROW>
            Y = [Y; y]; nn = nn + 1;             %#ok<AGROW>
        end
        if nn == 0; continue; end
        DC(ti,m)=acc(1)/nn; F0(ti,m)=acc(2)/nn; BB(ti,m)=acc(3)/nn;
        TRK{ti,m} = e; FID(ti,m) = median(e); VARr(ti,m) = mean(var(Y,0,1));
    end
end

%% [DECOMP] -----------------------------------------------------------------
fprintf('\n[DECOMP] mean error power over %d sessions, (%% dF/F)^2\n', nS);
fprintf('%-6s %8s %8s %8s %8s\n','mode','offset','@1Hz','broad','TOTAL');
for m = 1:nM
    fprintf('%-6s %8.2f %8.2f %8.2f %8.2f\n', MODE_SHORT{m}, mean(DC(:,m)), ...
        mean(F0(:,m)), mean(BB(:,m)), mean(DC(:,m)+F0(:,m)+BB(:,m)));
end
lbl = {'offset',DC; '@1Hz',F0; 'broad',BB; 'TOTAL',DC+F0+BB};
for c = 1:4
    [~,ix] = min(lbl{c,2},[],2);
    fprintf('  best per session (%-6s): %s\n', lbl{c,1}, ...
        strjoin(MODE_SHORT(ix), ' '));
end

%% [TRK] --------------------------------------------------------------------
P = cell(1,nM); for m = 1:nM; P{m} = [TRK{:,m}]; end
fprintf('\n[TRK] pooled per-trial |1-T| at the drive frequency\n');
for m = 1:nM
    fprintf('  %-5s n=%3d  median %.3f  IQR %.3f\n', MODE_SHORT{m}, numel(P{m}), ...
        median(P{m}), diff(prctile(P{m},[25 75])));
end
prs = {[1 2],'OL vs OL+p'; [3 4],'CL vs CL+p'; [1 3],'OL vs CL'; [2 4],'OL+p vs CL+p'};
for k = 1:size(prs,1)
    a = P{prs{k,1}(1)}; b = P{prs{k,1}(2)};
    fprintf('  %-14s p=%.3g\n', prs{k,2}, ranksum(a,b));
end

%% [TRADE] ------------------------------------------------------------------
fx = mean(FID,1); fy = mean(VARr,1);
fprintf('\n[TRADE] mode means:   |1-T|    variance\n');
for m = 1:nM; fprintf('  %-5s %10.3f %10.2f\n', MODE_SHORT{m}, fx(m), fy(m)); end
fprintf('  dominance (b beats a on BOTH axes):\n');
for a = 1:nM
    dom = MODE_SHORT(arrayfun(@(b) b~=a && fx(b)<fx(a) && fy(b)<fy(a), 1:nM));
    if isempty(dom); fprintf('    %-5s NON-DOMINATED\n', MODE_SHORT{a});
    else; fprintf('    %-5s dominated by %s\n', MODE_SHORT{a}, strjoin(dom,', ')); end
end
