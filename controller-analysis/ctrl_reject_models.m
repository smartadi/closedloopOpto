%% ctrl_reject_models.m   [REJMOD]  -- does the rejection result depend on the disturbance model?
%
% THE QUESTION. Disturbance rejection is scored as ER = ||A-ref||^2 / ||G-ref||^2, so the
% DENOMINATOR is the disturbance and G is whatever the contra predictor says the site would have
% done with no laser. Two predictors give two different G, and therefore two different
% disturbances -- so the honest thing to ask before quoting any rejection number is which parts of
% the answer are properties of the controller and which are properties of the predictor.
%
%   ridge    G still dips during the stim (median leak 23%). A dipping G is CLOSER to ref, so the
%            disturbance is understated and rejection is UNDER-reported.
%   deflate  G is constrained flat, so the disturbance is the full ref offset. This is the
%            counterfactual the metric actually wants -- but flatness is imposed, not measured
%            (see ctrl_deflate_check.m), so it is a ceiling, not a fact.
%
% WHAT SHOULD MOVE, AND WHAT SHOULD NOT. The leak sits in the denominator, which OL and CL SHARE.
% So it should scale both ER values together and largely cancel in the CL/OL ratio. If the ratio
% moves as little as the algebra predicts, the OL-vs-CL conclusion is model-independent and the
% absolute rejection level is not -- which is exactly the claim worth making, because it is the
% contrast the paper rests on.
%
% READS the two saved aggregates. Build them with:
%   CTRL_PRED='ridge';   imp_reject_across_sessions; XSr=XS; save data/imp_reject_across_sessions_ridge.mat XSr
%   CTRL_PRED='deflate'; imp_reject_across_sessions; XSd=XS; save data/imp_reject_across_sessions_deflate.mat XSd
%
% SECTIONS: [REJMOD-LOAD] [REJMOD-FIG] [REJMOD-REPORT]

%% [REJMOD-LOAD] -----------------------------------------------------------------
RM_EXPORT = true;  RM_FMT = {'png'};
rm_here = fileparts(mfilename('fullpath'));
if isempty(rm_here) || contains(rm_here,tempdir,'IgnoreCase',true) || contains(rm_here,'Editor_','IgnoreCase',true)
    rm_here = 'C:\Users\aditya\Documents\projects\brain_paper\controller-analysis';
end
rm_data = fullfile(rm_here,'data');
rm_out  = fullfile(rm_here,'..','paper','images','predictor_saga');
if RM_EXPORT && ~exist(rm_out,'dir'); mkdir(rm_out); end

rm_fr = fullfile(rm_data,'imp_reject_across_sessions_ridge.mat');
rm_fd = fullfile(rm_data,'imp_reject_across_sessions_deflate.mat');
assert(exist(rm_fr,'file')>0 && exist(rm_fd,'file')>0, ...
    '[REJMOD] need both _ridge and _deflate aggregates -- see the header for how to build them.');
Lr = load(rm_fr);  XSr = Lr.XSr;
Ld = load(rm_fd);  XSd = Ld.XSd;

% Match sessions by tag -- the two runs can differ in which sessions have caches.
tg_r = {XSr.Q.sess_tag};  tg_d = {XSd.Q.sess_tag};
[tags, ir, id] = intersect(tg_r, tg_d, 'stable');
nS = numel(tags);
assert(nS >= 3, '[REJMOD] only %d sessions common to both models.', nS);
ol_r = XSr.er_med_ol(ir);  cl_r = XSr.er_med_cl(ir);
ol_d = XSd.er_med_ol(id);  cl_d = XSd.er_med_cl(id);
rat_r = cl_r ./ ol_r;      rat_d = cl_d ./ ol_d;     % CL/OL: the model-robust contrast
lbl = strrep(tags,'_','\_');

%% [REJMOD-FIG] ------------------------------------------------------------------
figR = figure('Color','w','Position',[40 60 1500 460]);
tl = tiledlayout(figR,1,3,'TileSpacing','compact','Padding','compact');

% (a) absolute ER moves with the model
ax1 = nexttile(tl,1); hold(ax1,'on');
for i=1:nS
    plot(ax1,[1 2],[ol_r(i) ol_d(i)],'-','Color',[0.85 0.6 0.6],'HandleVisibility','off');
    plot(ax1,[3 4],[cl_r(i) cl_d(i)],'-','Color',[0.6 0.7 0.9],'HandleVisibility','off');
end
plot(ax1,ones(1,nS),ol_r,'o','Color',[0.75 0.2 0.2],'MarkerFaceColor',[0.75 0.2 0.2],'MarkerSize',5,'DisplayName','OL');
plot(ax1,2*ones(1,nS),ol_d,'o','Color',[0.75 0.2 0.2],'MarkerFaceColor','w','MarkerSize',5,'HandleVisibility','off');
plot(ax1,3*ones(1,nS),cl_r,'s','Color',[0.2 0.4 0.75],'MarkerFaceColor',[0.2 0.4 0.75],'MarkerSize',5,'DisplayName','CL');
plot(ax1,4*ones(1,nS),cl_d,'s','Color',[0.2 0.4 0.75],'MarkerFaceColor','w','MarkerSize',5,'HandleVisibility','off');
set(ax1,'XTick',1:4,'XTickLabel',{'ridge','deflate','ridge','deflate'},'FontSize',8);
ylabel(ax1,'energy ratio ER (lower = more rejection)');
legend(ax1,'Box','off','Location','northeast','FontSize',8);
title(ax1, sprintf('(a) ABSOLUTE level is model-dependent\nOL %.3f\\rightarrow%.3f, CL %.3f\\rightarrow%.3f (median)', ...
    median(ol_r), median(ol_d), median(cl_r), median(cl_d)));

% (b) the CL/OL contrast barely moves -- the leak is in the shared denominator
ax2 = nexttile(tl,2); hold(ax2,'on');
plot(ax2,[0 1.2],[0 1.2],'-','Color',[0.7 0.7 0.7],'HandleVisibility','off');
scatter(ax2, rat_r, rat_d, 46, [0.25 0.45 0.35], 'filled');
for i=1:nS; text(ax2, rat_r(i), rat_d(i), ['  ' lbl{i}], 'FontSize',6, 'Color',[0.35 0.35 0.35]); end
[rm_p,~,rm_st] = signrank(rat_r, rat_d);
xlabel(ax2,'CL/OL energy ratio -- ridge');  ylabel(ax2,'CL/OL -- deflate');
axis(ax2,'square');  xlim(ax2,[0 1.2]); ylim(ax2,[0 1.2]);
title(ax2, sprintf('(b) the CONTRAST is model-robust\nmedian %.3f vs %.3f, signrank p = %.3f', ...
    median(rat_r), median(rat_d), rm_p));

% (c) how much rejection the leak was hiding, per session
ax3 = nexttile(tl,3); hold(ax3,'on');
gain_hidden = (ol_r - ol_d) ./ ol_r * 100;      % OL ER inflation attributable to the leak
[~,o3] = sort(gain_hidden,'descend');
bar(ax3, gain_hidden(o3), 0.7, 'FaceColor',[0.45 0.55 0.75], 'EdgeColor','none');
set(ax3,'XTick',1:nS,'XTickLabel',lbl(o3),'XTickLabelRotation',45,'FontSize',7);
ylabel(ax3,'OL rejection hidden by the leak (%)');
yline(ax3, median(gain_hidden), '-', 'Color',[0.2 0.3 0.6], 'LineWidth',1.2, ...
    'Label', sprintf('median %.0f%%', median(gain_hidden)));
title(ax3, '(c) how much the dipping Global was under-reporting');

sgtitle(figR, ['[REJMOD] the leak lives in the SHARED denominator: it moves the absolute rejection ' ...
               'level, not the OL-vs-CL contrast'], 'FontWeight','bold');
if RM_EXPORT
    for k=1:numel(RM_FMT)
        exportgraphics(figR, fullfile(rm_out,['ctrl_reject_models.' RM_FMT{k}]), 'Resolution',300);
    end
end

%% [REJMOD-REPORT] ---------------------------------------------------------------
fprintf('\n[REJMOD] %d sessions common to both disturbance models\n', nS);
fprintf('  %-20s %16s %16s %14s\n','session','ER OL (r->d)','ER CL (r->d)','CL/OL (r->d)');
for i=1:nS
    fprintf('  %-20s %7.3f ->%7.3f %7.3f ->%7.3f %6.3f ->%6.3f\n', tags{i}, ...
        ol_r(i), ol_d(i), cl_r(i), cl_d(i), rat_r(i), rat_d(i));
end
fprintf('\n  ABSOLUTE ER  : OL %.3f -> %.3f | CL %.3f -> %.3f  (median, ridge -> deflate)\n', ...
    median(ol_r), median(ol_d), median(cl_r), median(cl_d));
fprintf('  CL/OL RATIO  : %.3f -> %.3f  (median), signrank p = %.3f  <- the model-robust contrast\n', ...
    median(rat_r), median(rat_d), rm_p);
fprintf('  leak hid     : median %.0f%% of the OL rejection (range %.0f-%.0f%%)\n', ...
    median(gain_hidden), min(gain_hidden), max(gain_hidden));
fprintf('  CL better in : ridge %d/%d | deflate %d/%d sessions\n', ...
    nnz(cl_r<ol_r), nS, nnz(cl_d<ol_d), nS);
fprintf('[REJMOD] figure -> %s\n', rm_out);
