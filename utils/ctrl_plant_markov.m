function [h, H, md] = ctrl_plant_markov(L, N)
%CTRL_PLANT_MARKOV  Markov parameters + convolution matrix of the Stage-4a laser->ipsi plant.
%
%   [h, H, md] = ctrl_plant_markov(L, N)
%
% ONE PLACE. Three callers need the same H: ctrl_opt_solve (to solve for u), and both
% ctrl_optimal_control.m and ctrl_optimal_xsess.m (to recover the disturbance as
% d = y_PI - H*u_PI). Building it three times is three chances for the delay handling to
% differ, and a mismatched H silently changes what "the disturbance" means.
%
% absorbDelay folds the identified input delay L.nk into the states, so H alone carries the
% full input->output map -- no separate delay bookkeeping anywhere downstream.
%
% L  Stage-4a plant struct (data/ctrl_lti_<tag>.mat): A,B,C,D,Ts,nk
% N  horizon length in samples
%
% h   N x 1 Markov parameters h_0..h_{N-1}
% H   N x N lower-triangular Toeplitz convolution matrix, y = H*u from rest
% md  the delay-absorbed discrete state-space model

md = ss(L.A, L.B, L.C, L.D, L.Ts);
md.InputDelay = L.nk;
md = absorbDelay(md);
[A,B,C,D] = ssdata(md);

h = zeros(N,1);  h(1) = D;
Ak = eye(size(A));
for k = 2:N
    h(k) = C*Ak*B;
    Ak = Ak*A;
end
H = tril(toeplitz(h));
end
