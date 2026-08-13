%% ctrl_sensitivity_freq.m   [SENS]  -- Fig 4 Part 2: rejection resolved in FREQUENCY
%
% WHY. Part 2 currently scores rejection as ER = ||A-ref||^2/||G-ref||^2, one number over 0-3 s.
% That number cannot tell "rejects everything by 30%" apart from "rejects DC perfectly and
% AMPLIFIES 3 Hz" -- and for an Internal Model Principle argument that distinction IS the result.
%
% THE ARGUMENT. The loop is PI (an integrator = an internal model of a CONSTANT) driving the opto
% actuator into cortex, holding a fixed reference. It contains no oscillatory mode, so it holds no
% model of any 1-4 Hz disturbance component. Francis-Wonham then predicts: near-perfect rejection
% of slow/DC disturbance, none in the delta band -- and Bode's integral adds that the low-frequency
% suppression must be PAID FOR by amplification somewhere. Part 1 already smells of this: OL error
% falls with relative 2-4 Hz power (slope -0.474) while CL error RISES (+0.847). A loop that merely
% lacked a model there would leave the OL slope alone; a sign flip means feedback is making that
% band worse. This script tests it directly.
%
% WHAT IS COMPUTED. Per trial, over the response window, with the measured contra-derived Global as
% the disturbance:
%     E = error trace (Actual),  D = disturbance trace (Global)
%     T(f) = <|E(f)|^2> / <|D(f)|^2>      transmission disturbance -> error, per condition
%     S(f) = T_CL(f) / T_OL(f)            what FEEDBACK changed  <- the panel
% S < 1 = feedback suppresses that band. S > 1 = feedback AMPLIFIES it (the waterbed).
% Ratios of AVERAGE power, not averages of ratios (the standard estimator).
%
% BAND. 1-10 Hz only. Below 1 Hz a 3 s window holds under 3 cycles, and the user has ruled that
% range out of the claim (2026-08-13). Everything is detrended, so DC and linear drift are gone
% before any spectrum is taken -- E is therefore the error FLUCTUATION; the DC part of the story is
% carried separately by the steady-state offset panel, which is where an integrator's claim belongs.
%
% THREE CONTROLS, because the headline is a ratio of ratios and those are easy to fool:
%   [SENS-NULL]  the same estimator on the PRE-STIM window (laser off in both conditions).
%                S_pre(f) must be flat at 1. If it is not, the estimator itself is the effect.
%   [SENS-DIST]  the disturbance spectra <|D|^2> for OL and CL, overlaid. S is a ratio, so anything
%                shared by both conditions cancels -- but only if the disturbance really is shared.
%   [SENS-LEAK]  where the Global's leak lives in frequency. The Global dips during stim because
%                contra pixels are co-suppressed (median leak 23%), so D carries a copy of the
%                laser response. That copy is SLOW, so it inflates <|D|^2> mostly below ~1 Hz,
%                which is exactly why the claim is restricted to >=1 Hz. Panel (e) shows the
%                stim-locked (trial-averaged) Global spectrum against the total, i.e. how much of D
%                at each frequency is leak rather than ongoing activity.
%
% THE LEAK'S DIRECTION OF BIAS, stated plainly because it is NOT the usual one:
%   Extra (leak) power in D shrinks T = |E|^2/|D|^2. If CL leaks MORE than OL -- plausible, the
%   controller often commands more light -- then T_CL shrinks more, so S = T_CL/T_OL is biased
%   DOWN. Downward bias FLATTERS a suppression claim and WORKS AGAINST an amplification claim.
%   So: any S < 1 at low frequency is the anti-conservative direction and must be bounded
%   (rerun with CTRL_PRED='deflate', whose Global is constrained flat over the stim window);
%   any S > 1 in the delta band is the conservative direction and is safe as-is.
%
% SUPPLEMENTARY UNTIL APPROVED (user, 2026-08-13): exports PNG only, to figure4/supp/.
%
% PREREQS: load_sessions.m has run; Stage-1 + Stage-2 caches for the predictor mode in force.
% SECTIONS: [SENS-CFG] [SENS-LOOP] [SENS-STATS] [SENS-SHEET] [SENS-PANELS]

clc; close all;
assert(exist('mouse','var') && exist('fields','var'), '[SENS] run load_sessions.m first.');

%% [SENS-CFG] ---------------------------------------------------------------------
CFG = struct('nSV_load',500, 'Fs',35, 'pre_s',3.0, 'resp_s',3.0);
SF_FMIN = 1;  SF_FMAX = 10;        % claim band (user: below 1 Hz is out of scope)
SF_BANDS = [1 2; 2 4; 4 10];       % summary bands
SF_SS    = [2 3];                  % steady-state window (s) for the DC panel

PS = paperStyle(); setPaperDefaults();
[pred_suffix, pred_mode] = ctrl_pred_tag(); %#ok<ASGLU>
sf_here = fileparts(mfilename('fullpath'));
if isempty(sf_here) || contains(sf_here,tempdir,'IgnoreCase',true) || contains(sf_here,'Editor_','IgnoreCase',true)
    sf_here = 'C:\Users\aditya\Documents\projects\brain_paper\controller-analysis';
end
sf_data = fullfile(sf_here,'data');
sf_out  = fullfile(sf_here,'..','paper','images','figure4','supp');
if ~exist(sf_out,'dir'); mkdir(sf_out); end
sf_tag = '';  if ~strcmpi(pred_mode,'ridge'); sf_tag = ['_' pred_mode]; end

%% [SENS-LOOP] --------------------------------------------------------------------
Q = struct('tag',{},'S',{},'Spre',{},'Tol',{},'Tcl',{},'Dol',{},'Dcl',{}, ...
           'Gleak',{},'Gtot',{},'ss_ol',{},'ss_cl',{},'nOL',{},'nCL',{});
ff = [];  skipped = {};
fprintf('\n[SENS] predictor mode = %s | band %g-%g Hz\n', pred_mode, SF_FMIN, SF_FMAX);
for s = 1:numel(fields)
    B = imp_build_session(mouse, fields, s, sf_data, CFG);
    if ~B.ok; skipped{end+1} = sprintf('%s (%s)', B.sess_tag, B.msg); continue; end %#ok<SAGROW>

    tt = B.tt;
    iR = tt >  0 & tt <= CFG.resp_s;          % response window
    iP = tt >= -CFG.resp_s & tt < 0;          % matched pre-stim window (laser off)
    nR = nnz(iR);
    if nR < round(2*B.Fs) || nnz(iP) < nR; skipped{end+1} = [B.sess_tag ' (window)']; continue; end %#ok<SAGROW>
    iP = find(iP, nR, 'last');                % exactly the same length as the response window

    [Peo,ff] = sf_psd(B.Aol, iR, B.Fs);   Pdo = sf_psd(B.Gol, iR, B.Fs);
    Pec      = sf_psd(B.Acl, iR, B.Fs);   Pdc = sf_psd(B.Gcl, iR, B.Fs);
    Peo_p    = sf_psd(B.Aol, iP, B.Fs);   Pdo_p = sf_psd(B.Gol, iP, B.Fs);
    Pec_p    = sf_psd(B.Acl, iP, B.Fs);   Pdc_p = sf_psd(B.Gcl, iP, B.Fs);

    a = struct();
    a.tag  = B.sess_tag;  a.nOL = B.nOL;  a.nCL = B.nCL;
    a.Tol  = Peo ./ max(Pdo,eps);   a.Tcl = Pec ./ max(Pdc,eps);
    a.S    = a.Tcl ./ max(a.Tol,eps);
    a.Spre = (Pec_p./max(Pdc_p,eps)) ./ max(Peo_p./max(Pdo_p,eps), eps);
    a.Dol  = Pdo;  a.Dcl = Pdc;
    % leak footprint: spectrum of the STIM-LOCKED (trial-averaged) Global vs the mean trial
    % spectrum. Trial averaging keeps what is time-locked to the laser and cancels ongoing
    % activity, so the first curve is the leak and the ratio is the leak's share of D at each f.
    a.Gleak = sf_psd(mean(B.Gcl,1), iR, B.Fs);
    a.Gtot  = Pdc;
    % steady-state offset: the integrator's own claim, in the time domain
    iS = tt >= SF_SS(1) & tt <= SF_SS(2);
    a.ss_ol = median(mean(B.Aol(:,iS),2) - B.ref);
    a.ss_cl = median(mean(B.Acl(:,iS),2) - B.ref);
    Q(end+1) = a; %#ok<SAGROW>
    fprintf('  %-22s  OL %3d / CL %3d trials\n', a.tag, a.nOL, a.nCL);
end
assert(~isempty(Q), '[SENS] no session produced a spectrum.');
nS = numel(Q);
if ~isempty(skipped); fprintf('  skipped: %s\n', strjoin(skipped,' | ')); end

kb = ff >= SF_FMIN & ff <= SF_FMAX;
fb = ff(kb);
% each a.S(kb) is a ROW; the transpose goes on the CELL array so cell2mat stacks rows -> nS x nf.
% (Transposing the contents instead silently produced one long column and an out-of-bounds index.)
Smat    = cell2mat(arrayfun(@(a) a.S(kb),    Q, 'UniformOutput',false).');   % nS x nf
Spremat = cell2mat(arrayfun(@(a) a.Spre(kb), Q, 'UniformOutput',false).');

%% [SENS-STATS] -------------------------------------------------------------------
Smed = median(Smat,1);  Spmed = median(Spremat,1);
fprintf('\n[SENS] %d sessions | S(f) = T_CL/T_OL   (<1 feedback suppresses, >1 feedback AMPLIFIES)\n', nS);
fprintf('  %-10s %10s %10s %12s %10s\n','band (Hz)','median S','pre-stim S','signrank p','n S>1');
BS = nan(size(SF_BANDS,1),4);
for b = 1:size(SF_BANDS,1)
    m = fb >= SF_BANDS(b,1) & fb < SF_BANDS(b,2);
    sess_S  = exp(mean(log(max(Smat(:,m),eps)),2));      % geometric mean in band, per session
    sess_Sp = exp(mean(log(max(Spremat(:,m),eps)),2));
    p = signrank(log(sess_S));                            % vs S = 1
    BS(b,:) = [median(sess_S), median(sess_Sp), p, nnz(sess_S>1)];
    fprintf('  %-10s %10.3f %10.3f %12.4g %6d/%d\n', ...
        sprintf('%g-%g',SF_BANDS(b,1),SF_BANDS(b,2)), BS(b,1), BS(b,2), p, BS(b,4), nS);
end
% Bode/waterbed bookkeeping over the measured band
wb = trapz(fb, log(max(Smed,eps)));
fprintf('  waterbed  : int log S df over %g-%g Hz = %+.3f  (0 = suppression exactly paid for)\n', ...
    SF_FMIN, SF_FMAX, wb);
ss_ol = [Q.ss_ol].';  ss_cl = [Q.ss_cl].';
fprintf('  steady-state offset from ref (%g-%g s): OL %+.2f | CL %+.2f %%dF/F, signrank p = %.4g\n', ...
    SF_SS(1), SF_SS(2), median(ss_ol), median(ss_cl), signrank(abs(ss_ol),abs(ss_cl)));
fprintf('  |offset| smaller in CL for %d/%d sessions\n', nnz(abs(ss_cl)<abs(ss_ol)), nS);

%% [SENS-SHEET] -------------------------------------------------------------------
figS = figure('Color','w','Position',[30 40 1500 760]);
tl = tiledlayout(figS,2,3,'TileSpacing','compact','Padding','compact');
% The band shading must be drawn to the limits the DATA sets, never the other way round -- a patch
% with hardcoded y corners hijacks the axis and flattens every curve on it (hit once already in
% ctrl_fit_figs, 2026-08-13). sf_shade reads the current ylim and restores it.

ax1 = nexttile(tl,1); hold(ax1,'on');
plot(ax1, fb, Smat.', '-', 'Color',[0.78 0.78 0.78], 'LineWidth',0.4, 'HandleVisibility','off');
plot(ax1, fb, Smed, '-', 'Color',[0.10 0.25 0.55], 'LineWidth',1.8, 'DisplayName','median');
yline(ax1,1,'--','Color',[0.3 0.3 0.3],'LineWidth',1,'HandleVisibility','off');
set(ax1,'YScale','log','XScale','log','FontSize',8); xlim(ax1,[SF_FMIN SF_FMAX]);
ylim(ax1, sf_lim(Smat));  sf_shade(ax1,2,4);
xlabel(ax1,'frequency (Hz)'); ylabel(ax1,'S(f) = T_{CL}/T_{OL}');
legend(ax1,'Box','off','Location','northwest','FontSize',7);
title(ax1,{'(a) what FEEDBACK changed','<1 suppressed | >1 AMPLIFIED (waterbed)'});

ax2 = nexttile(tl,2); hold(ax2,'on');
Tol_m = median(cell2mat(arrayfun(@(a) a.Tol(kb),Q,'UniformOutput',false).'),1);
Tcl_m = median(cell2mat(arrayfun(@(a) a.Tcl(kb),Q,'UniformOutput',false).'),1);
plot(ax2, fb, Tol_m, '-','Color',PS.col_ol,'LineWidth',1.6,'DisplayName','open loop');
plot(ax2, fb, Tcl_m, '-','Color',PS.col_cl,'LineWidth',1.6,'DisplayName','closed loop');
set(ax2,'YScale','log','XScale','log','FontSize',8); xlim(ax2,[SF_FMIN SF_FMAX]);
ylim(ax2, sf_lim([Tol_m;Tcl_m]));  sf_shade(ax2,2,4);
xlabel(ax2,'frequency (Hz)'); ylabel(ax2,'T(f) = <|E|^2>/<|D|^2>');
legend(ax2,'Box','off','Location','northwest','FontSize',7);
title(ax2,'(b) transmission disturbance \rightarrow error');

ax3 = nexttile(tl,3); hold(ax3,'on');
Dol_m = median(cell2mat(arrayfun(@(a) a.Dol(kb),Q,'UniformOutput',false).'),1);
Dcl_m = median(cell2mat(arrayfun(@(a) a.Dcl(kb),Q,'UniformOutput',false).'),1);
plot(ax3, fb, Dol_m, '-','Color',PS.col_ol,'LineWidth',1.6,'DisplayName','OL disturbance');
plot(ax3, fb, Dcl_m, '-','Color',PS.col_cl,'LineWidth',1.6,'DisplayName','CL disturbance');
set(ax3,'YScale','log','XScale','log','FontSize',8); xlim(ax3,[SF_FMIN SF_FMAX]);
ylim(ax3, sf_lim([Dol_m;Dcl_m]));  sf_shade(ax3,2,4);
xlabel(ax3,'frequency (Hz)'); ylabel(ax3,'<|D(f)|^2>');
legend(ax3,'Box','off','Location','southwest','FontSize',7);
title(ax3,{'(c) [SENS-DIST] control: the two conditions','must see the SAME disturbance for S to be a ratio'});

ax4 = nexttile(tl,4); hold(ax4,'on');
plot(ax4, fb, Spremat.', '-','Color',[0.82 0.82 0.82],'LineWidth',0.4,'HandleVisibility','off');
plot(ax4, fb, Spmed, '-','Color',[0.45 0.30 0.55],'LineWidth',1.8,'DisplayName','pre-stim median');
plot(ax4, fb, Smed,  '-','Color',[0.10 0.25 0.55],'LineWidth',1.0,'LineStyle',':','DisplayName','stim (a)');
yline(ax4,1,'--','Color',[0.3 0.3 0.3],'LineWidth',1,'HandleVisibility','off');
set(ax4,'YScale','log','XScale','log','FontSize',8); xlim(ax4,[SF_FMIN SF_FMAX]);
ylim(ax4, sf_lim([Spremat; Smed]));  sf_shade(ax4,2,4);
xlabel(ax4,'frequency (Hz)'); ylabel(ax4,'S_{pre}(f)');
legend(ax4,'Box','off','Location','northwest','FontSize',7);
title(ax4,{'(d) [SENS-NULL] laser OFF in both conditions','must be flat at 1'});

ax5 = nexttile(tl,5); hold(ax5,'on');
Gl = median(cell2mat(arrayfun(@(a) a.Gleak(kb),Q,'UniformOutput',false).'),1);
Gt = median(cell2mat(arrayfun(@(a) a.Gtot(kb), Q,'UniformOutput',false).'),1);
lk = 100*Gl./max(Gt,eps);
plot(ax5, fb, lk, '-','Color',[0.75 0.35 0.10],'LineWidth',1.6);
set(ax5,'XScale','log','FontSize',8); xlim(ax5,[SF_FMIN SF_FMAX]);
ylim(ax5,[0 max(1.15*max(lk),1)]);  sf_shade(ax5,2,4);
xlabel(ax5,'frequency (Hz)'); ylabel(ax5,'leak share of <|D|^2> (%)');
title(ax5,{'(e) [SENS-LEAK] stim-locked share of the disturbance','leak is SLOW -- this is why the claim starts at 1 Hz'});

ax6 = nexttile(tl,6); hold(ax6,'on');
for i=1:nS; plot(ax6,[1 2],[ss_ol(i) ss_cl(i)],'-','Color',[0.75 0.75 0.75],'LineWidth',0.5); end
plot(ax6,ones(nS,1),ss_ol,'o','MarkerFaceColor',PS.col_ol,'MarkerEdgeColor','none','MarkerSize',5);
plot(ax6,2*ones(nS,1),ss_cl,'o','MarkerFaceColor',PS.col_cl,'MarkerEdgeColor','none','MarkerSize',5);
yline(ax6,0,'-','Color',[0.3 0.3 0.3],'LineWidth',1);
set(ax6,'XTick',[1 2],'XTickLabel',{'OL','CL'},'FontSize',8); xlim(ax6,[0.6 2.4]);
ylabel(ax6,'steady-state offset from ref (%\DeltaF/F)');
title(ax6,{'(f) the integrator''s own claim: DC','internal model of a constant \Rightarrow offset \rightarrow 0'});

sgtitle(figS, sprintf(['[SENS] disturbance rejection resolved in frequency  --  %d sessions, predictor = %s  ' ...
    '(SUPPLEMENTARY, not approved for the main figure)'], nS, pred_mode), 'FontWeight','bold');
exportgraphics(figS, fullfile(sf_out,['f4supp_sensitivity_sheet' sf_tag '.png']), 'Resolution',300);
close(figS);

%% [SENS-PANELS] ------------------------------------------------------------------
% paper-sized versions of the two that could become main panels
fig = paperFig(6,4); ax = gca; hold(ax,'on');
plot(ax, fb, Smat.', '-','Color',[0.80 0.80 0.80],'LineWidth',0.3,'HandleVisibility','off');
plot(ax, fb, Smed, '-','Color',[0.10 0.25 0.55],'LineWidth',1.5,'HandleVisibility','off');
yline(ax,1,'--','Color',[0.3 0.3 0.3],'LineWidth',0.8,'HandleVisibility','off');
set(ax,'YScale','log','XScale','log','Box','off','TickDir','out','FontSize',6,'FontWeight','bold');
xlim(ax,[SF_FMIN SF_FMAX]);  ylim(ax, sf_lim(Smat));  sf_shade(ax,2,4);
xlabel(ax,'Frequency (Hz)','FontSize',6,'FontWeight','bold');
ylabel(ax,'Sensitivity S(f)','FontSize',6,'FontWeight','bold');
paperExport(fig, fullfile(sf_out,['f4supp_sensitivity' sf_tag '.png'])); close(fig);

fig = paperFig(6,4); ax = gca; hold(ax,'on');
for i=1:nS; plot(ax,[1 2],[ss_ol(i) ss_cl(i)],'-','Color',[0.78 0.78 0.78],'LineWidth',0.4); end
plot(ax,ones(nS,1),ss_ol,'o','MarkerFaceColor',PS.col_ol,'MarkerEdgeColor','none','MarkerSize',3);
plot(ax,2*ones(nS,1),ss_cl,'o','MarkerFaceColor',PS.col_cl,'MarkerEdgeColor','none','MarkerSize',3);
yline(ax,0,'-','Color',[0.4 0.4 0.4],'LineWidth',0.8);
set(ax,'XTick',[1 2],'XTickLabel',{'OL','CL'},'Box','off','TickDir','out','FontSize',6,'FontWeight','bold');
xlim(ax,[0.6 2.4]);
ylabel(ax,'Steady-state offset (%\DeltaF/F)','FontSize',6,'FontWeight','bold');
paperExport(fig, fullfile(sf_out,['f4supp_dc_offset' sf_tag '.png'])); close(fig);

save(fullfile(sf_data,['ctrl_sensitivity_freq' sf_tag '.mat']), 'Q','fb','Smat','Spremat','BS','wb','ss_ol','ss_cl','CFG','SF_BANDS','-v7.3');
fprintf('\n[SENS] panels -> %s\n', sf_out);

%% ---- helpers ----
function sf_shade(ax, x1, x2)
%SF_SHADE  band shading drawn to the limits the DATA already set, then limits restored.
yl = ylim(ax);
patch(ax, [x1 x2 x2 x1], yl([1 1 2 2]), [0.95 0.90 0.55], ...
    'EdgeColor','none','FaceAlpha',0.30,'HandleVisibility','off');
uistack(findobj(ax,'Type','patch'),'bottom');
ylim(ax, yl);
end
function L = sf_lim(V)
%SF_LIM  tight log-friendly limits from the data. The effects here are tens of percent, so an
%        auto axis spanning decades would render every curve as a flat line.
v = V(isfinite(V) & V>0);
if isempty(v); L = [0.5 2]; return; end
lo = prctile(v(:),1); hi = prctile(v(:),99);
if ~(hi>lo); lo = 0.9*min(v(:)); hi = 1.1*max(v(:)); end
r = (hi/lo)^0.08;                       % 8% log-padding
L = [lo/r, hi*r];
end
function [P, f] = sf_psd(M, idx, Fs)
%SF_PSD  mean one-sided PSD across trials, linear-detrended + Hann. DC/drift removed by design.
X = double(M(:, idx));
X = detrend(X.', 'linear').';           % per trial
N = size(X,2);  w = hann(N).';
X = X .* w;
F = abs(fft(X, [], 2)).^2 / (Fs * sum(w.^2));
nf = floor(N/2)+1;
F = F(:,1:nf);  F(:,2:end-1) = 2*F(:,2:end-1);
P = mean(F, 1);
f = (0:nf-1) * (Fs/N);
end
