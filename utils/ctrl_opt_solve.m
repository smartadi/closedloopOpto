function O = ctrl_opt_solve(L, d, r, u_max, opts)
%CTRL_OPT_SOLVE  Best-possible constrained control against a KNOWN disturbance.
%
% SINGLE SOURCE OF TRUTH for the Stage-4b optimal-control solve. Both the single-session
% workbench (controller-analysis/ctrl_optimal_control.m) and the cross-session batch
% (ctrl_optimal_xsess.m) call this, so a per-session number and a population number can
% never come from two different QPs.
%
%   O = ctrl_opt_solve(L, d, r, u_max)
%   O = ctrl_opt_solve(L, d, r, u_max, opts)
%
% THE PROBLEM
%   The plant is the identified laser->ipsi LTI:  y = H*u + d, where H is the lower-triangular
%   Markov/Toeplitz convolution matrix built from L and d is the disturbance the controller is
%   there to fight (adaptation drift + ongoing network state + whatever the plant model misses).
%   Two controllers are solved against the SAME plant, the SAME disturbance realization and the
%   SAME actuator ceiling -- only the information available to them differs:
%
%   NON-CAUSAL (clairvoyant, the absolute ceiling): knows all of d up front,
%       min_u ||H*u + d - r||^2 + lam*||u||^2     s.t.  0 <= u <= u_max
%   CAUSAL (realizable): receding-horizon MPC that knows d only up to the current sample and
%       predicts it as constant over the horizon (standard output-disturbance model).
%
% WHY IT IS A QP AND NOT LEAST SQUARES
%   The laser can only INHIBIT. u >= 0 is a hard physical constraint, not a regularizer: wherever
%   d already sits below the reference the optimal move is u = 0 and the error is IRREDUCIBLE --
%   no controller of any design can push the signal back up. O.frac_u0 reports how much of the
%   horizon falls in that regime, which is the honest denominator for "how much better could a
%   controller do".
%
% INPUTS
%   L      Stage-4a plant struct (ctrl_lti_<tag>.mat): fields A,B,C,D,Ts,nk
%   d      N x 1 disturbance over the horizon, in the same units as r (absolute %dF/F)
%   r      N x 1 setpoint (or scalar, expanded)
%   u_max  scalar actuator ceiling, same units as the identified input
%   opts   optional struct:
%            .lam     input regularization, conditioning only          (default 1e-4)
%            .Hp      causal MPC prediction horizon in samples         (default 35 = 1 s)
%            .u_init  warm start for the non-causal QP                 (default [])
%            .u_check input sequence for the plant sanity check        (default [])
%            .causal  false = skip the MPC loop (fast ceiling-only)    (default true)
%
% OUTPUT O
%   .h .H              Markov parameters and convolution matrix
%   .u_nc .y_nc        non-causal optimum and its output
%   .u_ca .y_ca        causal MPC command and its output (NaN if opts.causal=false)
%   .frac_u0           fraction of the horizon where the non-causal optimum chooses u = 0
%   .plant_err         max|H*u_check - lsim(u_check)|, NaN if no u_check given (should be ~0)
%   .exitflag_nc       quadprog exit flag for the non-causal solve

if nargin < 5 || isempty(opts); opts = struct(); end
if ~isfield(opts,'lam');     opts.lam     = 1e-4;  end
if ~isfield(opts,'Hp');      opts.Hp      = 35;    end
if ~isfield(opts,'u_init');  opts.u_init  = [];    end
if ~isfield(opts,'u_check'); opts.u_check = [];    end
if ~isfield(opts,'causal');  opts.causal  = true;  end

d = d(:);  N = numel(d);
if isscalar(r); r = r*ones(N,1); else; r = r(:); end
assert(numel(r)==N, 'ctrl_opt_solve: r must be scalar or match numel(d)=%d.', N);
assert(isscalar(u_max) && isfinite(u_max) && u_max > 0, ...
    'ctrl_opt_solve: u_max must be a positive finite scalar (got %g).', u_max);

%% plant -> Markov parameters -> convolution matrix ------------------------------
[h, H, md] = ctrl_plant_markov(L, N);        % y = H*u from rest (delay absorbed into states)
[A,B,C,D] = ssdata(md);

O = struct('h',h,'H',H,'N',N,'lam',opts.lam,'Hp',opts.Hp,'u_max',u_max);
O.plant_err = NaN;
if ~isempty(opts.u_check)
    uc = opts.u_check(:);  uc = uc(1:min(N,numel(uc)));
    tc = (0:numel(uc)-1).'*L.Ts;
    yc = lsim(md, uc, tc);
    O.plant_err = max(abs(H(1:numel(uc),1:numel(uc))*uc - yc(:)));
end

%% NON-CAUSAL: clairvoyant best possible ----------------------------------------
Qq = 2*(H.'*H + opts.lam*eye(N));  Qq = (Qq+Qq.')/2;
fq = 2*H.'*(d - r);
qopt = optimoptions('quadprog','Display','off');
u0 = [];
if ~isempty(opts.u_init); u0 = max(min(opts.u_init(:),u_max),0); end
[u_nc, ~, O.exitflag_nc] = quadprog(Qq, fq, [],[],[],[], zeros(N,1), u_max*ones(N,1), u0, qopt);
O.u_nc = u_nc;  O.y_nc = H*u_nc + d;
% "nothing to do" regime: u=0 is optimal because d already sits past the reference.
O.frac_u0 = mean(u_nc <= 1e-9*max(1,u_max));

%% CAUSAL: receding-horizon MPC -------------------------------------------------
if ~opts.causal
    O.u_ca = nan(N,1);  O.y_ca = nan(N,1);  return
end
u_ca = zeros(N,1);  y_ca = zeros(N,1);  x = zeros(size(A,1),1);
for k = 1:N
    p = min(opts.Hp, N-k+1);                       % shrinking horizon at the end
    Psi = zeros(p,1);  Ai = eye(size(A));
    for i = 1:p, Psi(i) = C*Ai*x;  Ai = Ai*A; end  % free response from the current state
    dk = d(k);                                     % last measured disturbance, held constant
    Hk = tril(toeplitz(h(1:p)));
    Qk = 2*(Hk.'*Hk + opts.lam*eye(p));  Qk = (Qk+Qk.')/2;
    fk = 2*Hk.'*(Psi + dk - r(k:k+p-1));
    uk = quadprog(Qk, fk, [],[],[],[], zeros(p,1), u_max*ones(p,1), [], qopt);
    u_ca(k) = uk(1);                               % apply the first move only
    y_ca(k) = C*x + D*u_ca(k) + d(k);
    x = A*x + B*u_ca(k);                           % propagate the true plant state
end
O.u_ca = u_ca;  O.y_ca = y_ca;
end
