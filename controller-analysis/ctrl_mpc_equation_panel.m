function ctrl_mpc_equation_panel()
%CTRL_MPC_EQUATION_PANEL  Panel: the preview-MPC optimization problem solved every frame (ctrl_mpc_lqr).
%   Parameters printed are the ones used in the Fig-3-frame replay (P defaults of ctrl_mpc_lqr).
% OUT  paper/images/supp_mpc/mpc_0_problem.png
here = fileparts(mfilename('fullpath')); figDir = fullfile(here,'..','paper','images','supp_mpc');
addpath(fullfile(here,'..','utils')); St = jnStyle();
fig = jnFig(9.4, 4.0);   % 9.4 cm: the LaTeX first line overhung an 8.9 canvas
 ax = axes(fig, 'Position', [0 0 1 1]); axis(ax, 'off'); xlim(ax,[0 1]); ylim(ax,[0 1]);
fs = St.fs_annot + 1;
L = { ...
 '$\displaystyle \min_{u_t,\dots,u_{t+H-1}} \; \sum_{j=1}^{H} \big(\hat y_{t+j}-r\big)^2 \;+\; \rho \sum_{j=0}^{H-1} \big(u_{t+j}-u_{ss}\big)^2 \;+\; \lambda \sum_{j=0}^{H-1} \big(\Delta u_{t+j}\big)^2$', ...
 '$\mathrm{s.t.}\quad x_{k+1} = A\,x_k + B\,u_{k-\delta}, \qquad \hat y_k = C\,x_k + \hat d_k, \qquad 0 \le u_k \le u_{\max}$', ...
 '$\hat d_{t+j}$: disturbance preview (forecast) for $j \le L_p$, held at $\hat d_{t+L_p}$ beyond', ...
 '$H = 1\,\mathrm{s}\;(35)$, \ $\delta = 2$ frames $(57\,\mathrm{ms})$, \ $L_p = 200\,\mathrm{ms}$, \ $r=-5\%$, \ $\rho=10^{-3}$, \ $\lambda = 1$', ...
 'receding horizon: apply $u_t$, re-estimate $x_t, \hat d$ (Kalman), re-solve every frame (35 Hz)'};
y = [0.84 0.62 0.42 0.24 0.07];
for i = 1:numel(L)
    text(ax, 0.02, y(i), L{i}, 'Interpreter','latex', 'FontSize', fs + (i==1)*0.5, 'VerticalAlignment','middle');
end
ctrl_mpc_export(fig, fullfile(figDir, 'mpc_0_problem.png'));
end
