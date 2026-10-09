function ctrl_mpc_wb2s_example(sess, trials, extra, suffix, mdl)
%CTRL_MPC_WB2S_EXAMPLE  Example CL trials: recorded CL (PI on the rig), PI replay, MPC with the AR forecast
%   (our earlier MPC), MPC with the whole-brain forecast (wbbest, mpc_arx_wb2s.py), perfect preview.
%   Rows: (1) dF/F with the -5 reference, (2) laser command, (3) the 86 ms-ahead disturbance forecasts
%   fed to the MPC vs the disturbance that actually came. Default trials: the 25th / 50th / 75th
%   percentile of the per-trial MPC improvement (whole-brain vs AR). Simulation -> descriptive.
% OUT  paper/images/mpc_arx/wb2s_mpc_example_<sess>.png
if nargin < 1 || isempty(sess), sess = 'AL_0033_0226_e2'; end
if nargin < 3, extra = {}; end            % extra ctrl_mpc_lqr args, e.g. {'rd',0,'r',1e-6} (aggressive)
if nargin < 4, suffix = ''; end
if nargin < 5 || isempty(mdl), mdl = {'wbbest','ctrl_mpc_wb2s_out_%s.mat','whole-brain'}; end   % {fcstModel, fcstFile, label}; e.g. {'varx','ctrl_mpc_varx_out_%s.mat','VARX'}
here = fileparts(mfilename('fullpath')); dataDir = fullfile(here,'data'); addpath(genpath(fullfile(here,'..','utils')));
figDir = fullfile(here,'..','paper','images','mpc_arx');
args = [{'frame','fig3','Lp',7,'xGrid',[1 0],'KpGrid',0.10,'KiGrid',1.5,'tag','_ex'}, extra];
evalc('Ta = ctrl_mpc_lqr(args{:}, ''fcstModel'',''ar'', ''fcstFile'',''ctrl_mpc_forecasters_%s.mat'');');
evalc('Tw = ctrl_mpc_lqr(args{:}, ''fcstModel'',mdl{1}, ''fcstFile'',mdl{2});');
delete(fullfile(dataDir, sprintf('ctrl_mpc_lqr_%s_ex.mat', sess)));
i1 = strcmp(Ta.modes,'x1.00'); i0 = strcmp(Ta.modes,'x0.00');
FF = load(fullfile(dataDir, sprintf('ctrl_mpc_forecasters_%s.mat', sess)), 'F','DEP');
FW = load(fullfile(dataDir, sprintf(mdl{2}, sess)), 'F');
pre = 35; N = size(Ta.Y{1},1); t = Ta.tt(:); ref = Ta.P.ref;
gain = Tw.rM(:,i1) - Ta.rM(:,i1);                                 % < 0 = whole-brain MPC better
if nargin < 2 || isempty(trials)
    [~, o] = sort(gain); nT = numel(o); trials = o(round([0.25 0.5 0.75]*nT)).';
end
PS = paperStyle();
cP = [0 0.40 0.85]; cA = [0.20 0.45 0.75]*0.6+0.4*[0.6 0.6 0.6]; cW = [0.82 0.29 0.36]; cS = [0.80 0.65 0.90];
fig = figure('Color','w','Position',[60 60 1500 780]);
L = 3;                                                            % 86 ms lead
for c = 1:numel(trials)
    k = trials(c);
    ax = subplot(3, numel(trials), c); hold(ax,'on');
    plot(ax, t, Ta.recCL(:,k), '-', 'Color', cP, 'LineWidth', 1.3);
    plot(ax, t, Ta.yPI(:,k), ':', 'Color', [.45 .45 .45], 'LineWidth', 1);
    plot(ax, t, Ta.Y{i1}(:,k), '-', 'Color', cA, 'LineWidth', 1.2);
    plot(ax, t, Tw.Y{i1}(:,k), '-', 'Color', cW, 'LineWidth', 1.4);
    plot(ax, t, Ta.Y{i0}(:,k), '-', 'Color', cS, 'LineWidth', 1);
    yline(ax, ref, 'k--');
    title(ax, sprintf(['CL trial %d | RMSE: rec CL %.2f, PI %.2f, MPC-AR %.2f, MPC-' mdl{3} ' %.2f'], k, ...
        Ta.realCL(k), Ta.rPI(k), Ta.rM(k,i1), Tw.rM(k,i1)), 'FontSize', 8);
    ylabel(ax, '\DeltaF/F (%)'); xlim(ax, [0 3]);
    if c == 1
        legend(ax, {'recorded CL (PI on rig)','PI replay','MPC, AR forecast (earlier)', ...
            ['MPC, ' mdl{3} ' forecast'],'MPC, perfect preview','reference'}, 'Box','off','FontSize',7,'Location','southeast');
    end
    ax = subplot(3, numel(trials), numel(trials)+c); hold(ax,'on');
    plot(ax, t, Ta.recUCL(:,k), '-', 'Color', cP, 'LineWidth', 1.2);
    plot(ax, t, Ta.U{i1}(:,k), '-', 'Color', cA, 'LineWidth', 1.1);
    plot(ax, t, Tw.U{i1}(:,k), '-', 'Color', cW, 'LineWidth', 1.3);
    ylabel(ax, 'laser command'); xlim(ax, [0 3]);
    ax = subplot(3, numel(trials), 2*numel(trials)+c); hold(ax,'on');
    tf = (1:N-L).'; tt = t(tf + L - 1);                            % forecast plotted at its target time
    plot(ax, t, FF.DEP(k, pre+(1:N)).', 'k-', 'LineWidth', 1.2);
    plot(ax, tt, double(FF.F.ar(tf, L, k)), '-', 'Color', cA, 'LineWidth', 1);
    plot(ax, tt, double(FW.F.(mdl{1})(tf, L, k)), '-', 'Color', cW, 'LineWidth', 1.1);
    xlabel(ax, 'time from onset (s)'); ylabel(ax, 'disturbance departure'); xlim(ax, [0 3]);
    if c == 1
        legend(ax, {'actual disturbance','86 ms-ahead forecast: AR',['86 ms-ahead forecast: ' mdl{3}]}, ...
            'Box','off','FontSize',7,'Location','southeast');
    end
end
sgtitle(fig, sprintf([strrep(suffix,'_','') ' MPC replay on recorded CL trials (25th / 50th / 75th pct of ' mdl{3} ' vs AR gain); ' ...
    'session median MPC/PI: AR %.3f, ' mdl{3} ' %.3f'], median(Ta.rM(:,i1)./Ta.rPI), median(Tw.rM(:,i1)./Tw.rPI)), 'FontSize', 10);
exportgraphics(fig, fullfile(figDir, sprintf('wb2s_mpc_example_%s%s.png', sess, suffix)), 'Resolution', 170);
fprintf('[WB2S-EX] trials %s | per-trial RMSE gain (brain - AR) %s\n', mat2str(trials), mat2str(round(gain(trials).',3)));
end
