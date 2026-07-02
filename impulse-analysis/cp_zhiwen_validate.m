%% cp_zhiwen_validate.m — positive-control the contra->ipsi HEMI predictor on Ye/Zhiwen data
%
% GOAL. Our contra_prediction.m [CP-HEMI] pooled ipsi-hemisphere R^2 on AL_0033 plateaus at
% ~0.925 @rank10, ~0.065 short of Ye et al. 2023's ~0.99. Is that gap in our CODE/METHOD, or in
% our DATA (a less bilaterally-coherent, lower-SNR prep)? Answer it by running the SAME primitives
% (our vendored redoSVD / CanonCor2 / sseExplainedCal) on ONE of Zhiwen's OWN spontaneous
% sessions, in two arms:
%
%   Arm A  "his exact"     : atlas-registered SENSORY areas per hemisphere (faithful port of
%                            spirals_mirror/preprocessing/getReducedRankRegressionHEMI.m).
%                            Expected ~0.99 -> proves our ported primitives reproduce his number,
%                            i.e. the code is NOT the problem, and fixes the ceiling THIS data reaches.
%   Arm B  "whole-hemi"    : ALL cortical pixels per hemisphere, midline split, NO sensory
%                            restriction. This is the exact analogue of our AL_0033 [CP-HEMI]
%                            (pooled 0.925). Apples-to-apples on METHOD, run on HIS data.
%
% READOUT (all three share K=50 modes, train 1:40000 / test 40001:60000, rank sweep 1:50,
% pooled sseExplainedCal over predicted-hemi pixels x test time):
%   Arm A (his sensory, his data)    -> expect ~0.99   [CODE check + data ceiling]
%   Arm B (whole-hemi,   his data)   -> X              [METHOD on good data]
%   our  (whole-hemi,    AL_0033)    -> 0.925          [known, from contra_prediction.m CP-HEMI]
% Logic:  Arm A~0.99 => code faithful.  Then  Arm B >> 0.925 => AL_0033 gap is DATA;
%         Arm B ~ 0.925 => gap is METHOD (sensory restriction is what buys 0.99).
%         Arm A vs Arm B on the SAME data isolates the sensory-restriction contribution alone.
%
% Spontaneous data -> NO trial/stim splitting (contiguous early-train / late-test, as Zhiwen does).
% Run as a script (section by section or whole). Standalone: adds the Ye repo utils + our utils.

clear; clc;

% ---- paths -----------------------------------------------------------------------------------
YE   = 'C:\Users\aditya\Documents\projects\YE-et-al-2023-spirals';
BP   = 'C:\Users\aditya\Documents\projects\brain_paper';
addpath(genpath(fullfile(YE,'spirals','utils')));          % select_area, loadUVt1, loadStructureTree, get_cortex_atlas_path
addpath(fullfile(BP,'utils'));                             % OUR vendored redoSVD, CanonCor2, sseExplainedCal, paperFig
addpath(fullfile(BP,'utils','npy-matlab','npy-matlab'));   % readNPY

data_folder = fullfile(YE,'data');
fname       = 'AB_0004_20210330_1';
ses_root    = fullfile(data_folder,'spirals','svd',fname);
out_root    = fullfile(BP,'impulse-analysis','data');      % results + fig go here
if ~exist(out_root,'dir'); mkdir(out_root); end

K        = 50;           % SVD modes per hemisphere (Zhiwen: 50)
ranks    = 1:K;          % rank sweep
tr_idx   = 1:40000;      % contiguous early frames -> train  (Zhiwen: 1:40000)
te_idx   = 40001:60000;  % late frames -> test               (Zhiwen: 40001:60000)
svd_span = 1:58000;      % frames fed to per-hemi redoSVD     (Zhiwen: V(:,1:58000))
scale    = 8;            % atlas downsample (Zhiwen: 8)
armB_maxPix = 4000;      % cap whole-hemi scoring pixels/hemi (memory); pooled R^2 ~invariant

%% ---- load SVD + atlas + warp -----------------------------------------------------------------
fprintf('=== loading %s ===\n', fname);
[U,V,t,mimg] = loadUVt1(ses_root);                          % U 512x512x200, V 200xnT
Fs = 1/median(diff(t));
fprintf('nT=%d  Fs=%.2f Hz  dur=%.1f s\n', size(V,2), Fs, t(end)-t(1));
U = U(:,:,1:K);  V = double(V(1:K,:));

atl = load(fullfile(data_folder,'tables','isocortex_horizontal_projection_outline.mat')); % projectedAtlas1/Template1/coords
[~,st] = get_cortex_atlas_path(data_folder);
spath  = string(st.structure_id_path);
projA  = atl.projectedAtlas1;  projT = atl.projectedTemplate1;  coords = atl.coords;

tf = load(fullfile(data_folder,'spirals','rf_tform',[fname '_tform.mat']));   % tform (camera->atlas)
Utr = imwarp(U, tf.tform, 'OutputView', imref2d(size(projT)));                % 1320x1140x50
fprintf('warped U -> %s\n', mat2str(size(Utr)));

% sensory-area Allen paths (verbatim from getReducedRankRegressionHEMI.m)
areaPath(1)  = "/997/8/567/688/695/315/453/";            % SS
areaPath(2)  = "/997/8/567/688/695/315/247/";            % AUD
areaPath(3)  = "/997/8/567/688/695/315/669/";            % VIS
areaPath(4)  = "/997/8/567/688/695/315/254/";            % RSP
areaPath(5)  = "/997/8/567/688/695/315/22/312782546/";   % VISa
areaPath(6)  = "/997/8/567/688/695/315/22/417/";         % VISrl
areaPath(7)  = "/997/8/567/688/695/315/541/";            % TEa
areaPath(9)  = "/997/8/567/688/695/315/677/";            % VISC
areaPath(10) = "/997/8/567/688/695/1089/";               % HPF
areaPath(11) = "/997/8/567/688/695/315/677/";            % CTXsp
sensoryArea = strcat(areaPath(:));

% ============================================================================================
% shared HEMI regression: predict RIGHT-hemi pixel field from z-scored LEFT-hemi modes.
% idxR/idxL are linear indices into the scale-downsampled atlas frame; UselR/UselL = [P x K].
%   returns poolR2(1:K) = pooled sseExplainedCal over predicted pixels x test time vs rank.
% Faithful to getReducedRankRegressionHEMI.m (CanonCor2 rank-sweep variant).
% ============================================================================================
run_hemi = @(UselR,UselL) local_hemi(UselR,UselL,V,tr_idx,te_idx,svd_span,K);

%% ================= Arm A — HIS EXACT (atlas sensory areas) =====================================
fprintf('\n=== Arm A: sensory-restricted (his exact method) ===\n');
[idxR_s, UselR_s] = select_area(sensoryArea,spath,st,coords,Utr,projA,projT,'right',scale);
[idxL_s, UselL_s] = select_area(sensoryArea,spath,st,coords,Utr,projA,projT,'left', scale);
fprintf('sensory px: right=%d  left=%d\n', numel(idxR_s), numel(idxL_s));
poolR2_A = run_hemi(UselR_s, UselL_s);

%% ================= Arm B — WHOLE HEMISPHERE (all cortex, midline split) ========================
fprintf('\n=== Arm B: whole-hemisphere (our method analogue) ===\n');
[idxR_w, UselR_w] = select_wholehemi(Utr, projA, 'right', scale, armB_maxPix);
[idxL_w, UselL_w] = select_wholehemi(Utr, projA, 'left',  scale, armB_maxPix);
fprintf('whole-cortex px: right=%d  left=%d (cap %d/hemi)\n', numel(idxR_w), numel(idxL_w), armB_maxPix);
poolR2_B = run_hemi(UselR_w, UselL_w);

%% ================= report + figure =============================================================
rmk = 10;
[pkA,ipA] = max(poolR2_A);  [pkB,ipB] = max(poolR2_B);
fprintf('\n================ ZHIWEN VALIDATION (%s) ================\n', fname);
fprintf('Arm A  sensory (his exact) : rank%d=%.3f | peak=%.3f@rank%d   (Zhiwen ~0.99)\n', rmk, poolR2_A(rmk), pkA, ipA);
fprintf('Arm B  whole-hemi          : rank%d=%.3f | peak=%.3f@rank%d\n', rmk, poolR2_B(rmk), pkB, ipB);
fprintf('our    AL_0033 whole-hemi  : rank%d=0.925 (reference, from contra_prediction.m [CP-HEMI])\n', rmk);
fprintf('=========================================================\n');

save(fullfile(out_root, 'cp_zhiwen_validate.mat'), 'poolR2_A','poolR2_B','fname','ranks','tr_idx','te_idx','Fs');

fig = paperFig(9,7); ax = axes(fig,'Position',[0.15 0.16 0.80 0.76]); hold(ax,'on');
plot(ax, ranks, poolR2_A, '-o','Color',[0.10 0.50 0.80],'MarkerSize',3,'LineWidth',1.5,'DisplayName','Arm A: his sensory (his data)');
plot(ax, ranks, poolR2_B, '-s','Color',[0.85 0.30 0.10],'MarkerSize',3,'LineWidth',1.5,'DisplayName','Arm B: whole-hemi (his data)');
yline(ax, 0.925,'--','Color',[0.35 0.35 0.35],'LineWidth',1.0,'HandleVisibility','off');       % our AL_0033
text(ax, K, 0.925,'  our AL\_0033 (0.925)','FontSize',5,'VerticalAlignment','bottom','HorizontalAlignment','right');
yline(ax, 0.99,'k:','LineWidth',1.0,'HandleVisibility','off');
xline(ax, rmk, ':','Color',[0.6 0.6 0.6],'HandleVisibility','off');
xlabel(ax,'rank (# components)','FontWeight','bold','FontSize',6);
ylabel(ax,'held-out pooled R^2','FontWeight','bold','FontSize',6);
ylim(ax,[0 1]); xlim(ax,[1 K]);
lg = legend(ax,'Location','southeast','FontSize',5); lg.ItemTokenSize=[6 6];
title(ax, sprintf('Contra\\rightarrowipsi prediction — Ye/Zhiwen %s', fname),'FontSize',6,'FontWeight','bold','Interpreter','tex');
exportgraphics(fig, fullfile(out_root,'cp_zhiwen_validate.png'), 'Resolution',300);
fprintf('exported %s\n', fullfile(out_root,'cp_zhiwen_validate.png'));


%% ============================== local helpers =================================================
function poolR2 = local_hemi(UselR, UselL, V, tr_idx, te_idx, svd_span, K)
% Faithful port of getReducedRankRegressionHEMI.m rank-sweep, our vendored CanonCor2/sseExplainedCal.
UselR = double(UselR);  UselL = double(UselL);
[Unew_R, Vnew_R] = redoSVD(UselR, V(:,svd_span));   Uright = double(Unew_R(:,1:K));  Vright = double(Vnew_R(1:K,:));
[Unew_L, Vnew_L] = redoSVD(UselL, V(:,svd_span));   Vleft  = double(Vnew_L(1:K,:));  Unew_L = double(Unew_L);

% --- train: regressor = z-scored left modes; signal = right-hemi field ---
regressor = zscore(Vleft(:,tr_idx), [], 2);          % [K x nTr]
signal1   = Uright * Vright(:, tr_idx);              % [P x nTr] right-hemi pixel field (train)
[a, b, ~] = CanonCor2({signal1'}, {regressor'});     % Y = X b a' ; a:[P x K] b:[K x K]

% --- test: rebuild left regressor from redoSVD basis on the raw test data ---
data          = UselL * V(:, te_idx);
data          = data - mean(data,2);
regressor_te  = Unew_L' * data;                      % re-project onto left redoSVD basis
regressor_te  = zscore(regressor_te, [], 2);         % [>=K x nTe]
Xte           = regressor_te(1:K,:)';                % [nTe x K]
traceR_te     = UselR * V(:, te_idx);                % [P x nTe] actual right-hemi field (test)

% --- pooled held-out R^2 vs rank ---
poolR2 = nan(K,1);
for n = 1:K
    pred = (Xte * b(:,1:n) * a(:,1:n)')';            % [P x nTe]
    poolR2(n) = sseExplainedCal(traceR_te(:)', pred(:)');
end
end

function [index, Uselected] = select_wholehemi(Utransformed, projectedAtlas1, hemi, scale, maxPix)
% Whole-cortex hemisphere selection: select_area minus the sensory startsWith() filter.
% Keeps ALL atlas cortical pixels on one side of the vertical midline (analogue of our
% AL_0033 [CP-HEMI] whole-hemi split), downsampled by `scale`, capped at maxPix via stride.
A = projectedAtlas1;                                 % nonzero = cortical pixel
if strcmp(hemi,'right')
    A(:, 1:size(A,2)/2) = 0;
else
    A(:, size(A,2)/2+1:end) = 0;
end
A2    = A(1:scale:end, 1:scale:end);
index = find(A2);
if numel(index) > maxPix                              % even-stride downsample for memory
    index = index(1:ceil(numel(index)/maxPix):end);
end
Ud    = Utransformed(1:scale:end, 1:scale:end, :);
Ud    = reshape(Ud, size(Ud,1)*size(Ud,2), size(Ud,3));
Uselected = Ud(index, :);
end
