% controller-analysis/f4_1B_equation.m
% Fig-4 ROW-1 middle panel -- the representative error-decomposition MODEL EQUATION.
% Restores (and extends to FOUR state terms) the old f4_1B_ols equation panel that the
% 2026-09-21 rework dropped. Equation only, no axes/title/other text -- the predictors are
% named by the state-colored exemplar titles (f4_state_exemplars) and the state-colored
% R^2-explained bars (f4_error_decomp 'sep'), which use the SAME four colours:
%   X1 initial deviation (blue)  X2 motion (orange)  X3 rel 2-4 Hz (green)  X4 abs delta (purple)
% RMSE ~ b0 + b1 X1 + b2 X2 + b3 X3 + b4 X4  (per-trial CL tracking error, settled window).
% Vector PDF, tight canvas, for the Illustrator assembly. No data needed.
clc; close all;
root = 'C:\Users\aditya\Documents\projects\brain_paper'; addpath(fullfile(root,'utils'));
PS = paperStyle();
outfig  = fullfile(root,'paper','figures_v2','figure4');   % jn* v2 output
outview = fullfile(root,'controller-analysis','_preview'); if ~exist(outview,'dir'); mkdir(outview); end

% ---- canonical 4-state palette (SAME as f4_state_exemplars / f4_error_decomp) ----
cInit=[0.20 0.40 0.75]; cMot=[0.75 0.40 0.10]; cRel=[0.35 0.55 0.30]; cAbs=[0.55 0.25 0.60];
rgb=@(c) sprintf('\\color[rgb]{%.3f,%.3f,%.3f}',c(1),c(2),c(3));
blk='\color[rgb]{0.10,0.10,0.10}'; gry='\color[rgb]{0.45,0.45,0.45}';

f = paperFig(3.0, 2.4); ax = axes(f,'Position',[0 0 1 1]); hold(ax,'on');   % tight-crop export -> PDF crops to eqn content (~3.14 x 1.87)
axis(ax,[0 1 0 1]); axis(ax,'off');
fs = 11;   % equation type size (panel is small; scaled up so it reads at figure size)
% Line 1: RMSE ~
text(ax,0.5,0.80,[blk 'RMSE \approx'],'Interpreter','tex','HorizontalAlignment','center', ...
    'FontName','Arial','FontSize',fs,'FontWeight','bold');
% Line 2: b0 + b1X1 + b2X2 +
l2 = [gry '\beta_0 ' blk '+ ' rgb(cInit) '\beta_1X_1 ' blk '+ ' rgb(cMot) '\beta_2X_2 ' blk '+'];
text(ax,0.5,0.50,l2,'Interpreter','tex','HorizontalAlignment','center', ...
    'FontName','Arial','FontSize',fs-1,'FontWeight','bold');
% Line 3: b3X3 + b4X4
l3 = [rgb(cRel) '\beta_3X_3 ' blk '+ ' rgb(cAbs) '\beta_4X_4'];
text(ax,0.5,0.22,l3,'Interpreter','tex','HorizontalAlignment','center', ...
    'FontName','Arial','FontSize',fs-1,'FontWeight','bold');

paperExport(f,fullfile(outfig,'f4_1B_equation.pdf'));
paperExport(f,fullfile(outview,'f4_1B_equation.png'));
fprintf('[f4_1B_equation] wrote 4-term state-colored equation panel -> %s\n',outfig);
