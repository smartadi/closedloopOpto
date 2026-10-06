function R = ctrl_mpc_forecasters(sess)
%CTRL_MPC_FORECASTERS  Forecaster bake-off on the replayed CL-trial disturbances (Fig-3 frame), using
%   model families from Lu et al. 2025 (Ziyu) that run locally. 5-fold CV ACROSS TRIALS.
%   Signal: dep_k = d_k - mean_k(d_k), d_k = recorded CL output - plant model(recorded command), with
%   the 1 s pre-stim history. Origin t = 1..N (stim samples); forecast dep(pre+t+1 .. pre+t+Hp) from
%   dep(1 .. pre+t). Output tensors plug straight into ctrl_mpc_lqr('fcstFile',...,'fcstModel',...).
%   Models: naive (persistence), average (climatology), ar (AR(19) iterated), arma (ARMA(4,2),
%   Econometrics arima), theta (SES + half drift), dlinear (direct ridge map, last W -> next Hp; the
%   DLinear decomposition is linear so this spans it), mlp (TiDE-like dense net), lstm (DeepAR-family).
% OUT  data/ctrl_mpc_forecasters_<sess>.mat  (F.<model> = [N x Hp x nT], skill table)
if nargin < 1, sess = 'AL_0033_0226_e2'; end
here = fileparts(mfilename('fullpath')); dataDir = fullfile(here,'data'); addpath(genpath(fullfile(here,'..','utils')));
F3 = load(fullfile(dataDir, sprintf('ctrl_mpc_lqr_%s_fig3.mat', sess)));      % plant + recorded trials
Hp = 35; W = 35; p = 19; pre = 35; nFold = 5; rng(7);

% rebuild the departures WITH the pre-stim second (recorded traces from the raw cache)
Z = load(fullfile(here,'..','data',F3.P.rawFile)); dz = Z.d; Dz = Z.data;
[uAmp,~] = cp_laser_amplitude(dz.inpVals, dz.inpTime); tb = dz.timeBlue(:); yfull = Dz.dFk(:);
N = 105; rel = -pre:N; on = arrayfun(@(t) find(tb >= t, 1), dz.stimStarts(:)); wc = Dz.wc(:);
md = ss(F3.A, F3.B, F3.C, 0, 1/35); nT = numel(wc); Dk = zeros(nT, numel(rel));
for k = 1:nT
    yk = yfull(on(wc(k))+rel); uk = interp1(dz.inpTime, uAmp, tb(on(wc(k))+rel), 'linear', 0);
    Dk(k,:) = yk.' - lsim(md, uk).';
end
DEP = Dk - mean(Dk,1);  fold = mod(randperm(nT), nFold) + 1;   % same fold rule as ctrl_mpc_lqr
names = {'naive','average','ar','arma','theta','dlinear','mlp','lstm'};
for m = names, F.(m{1}) = nan(N, Hp, nT); end

for f = 1:nFold
    tr = find(fold ~= f); te = find(fold == f); Xtr = DEP(tr,:);
    fprintf('[FCST] fold %d/%d (%d train / %d test)\n', f, nFold, numel(tr), numel(te));
    % --- fits on training trials
    a   = fitAR(Xtr, p);
    Mar = estimate(arima(4,0,2), reshape(Xtr.',[],1), 'Display','off');           % concatenated trials
    [Xw, Yw] = windows(Xtr, W, Hp);                                               % origins with full targets
    lam = 1e-1*trace(Xw.'*Xw)/size(Xw,1);                                         % ridge (DLinear-style)
    Bd =([Xw ones(size(Xw,1),1)].'*[Xw ones(size(Xw,1),1)] + lam*blkdiag(eye(W),0)) \ ([Xw ones(size(Xw,1),1)].'*Yw);
    alphaT = fitTheta(Xtr, W, Hp);
    netM = trainNet(Xw, Yw, 'mlp');  netL = trainNet(Xw, Yw, 'lstm');
    % --- forecasts on test trials, every stim origin
    for k = te
        x = DEP(k,:).';
        for t = 1:N
            g = pre + t; h = x(1:g);
            F.naive(t,:,k)   = h(end);
            F.average(t,:,k) = 0;
            F.ar(t,:,k)      = arIter(h, a, Hp);
            F.arma(t,:,k)    = forecast(Mar, Hp, 'Y0', h(max(1,end-60):end)).';
            F.theta(t,:,k)   = thetaF(h, alphaT, W, Hp);
            F.dlinear(t,:,k) = [h(end-W+1:end).' 1] * Bd;
        end
        Xk = cell2mat(arrayfun(@(t) x(pre+t-W+1:pre+t).', (1:N).', 'uni', 0));
        F.mlp(:,:,k)  = predict(netM, Xk);
        F.lstm(:,:,k) = predict(netL, num2cell(Xk, 2).');
    end
end

% --- skill: RMSE / climatology RMSE at leads, targets inside the stim window
leads = [1 2 3 5 7 10 17 35]; S = nan(numel(names), numel(leads));
for il = 1:numel(leads)
    L = leads(il); t = 1:N-L; tgt = zeros(numel(t), nT);
    for k = 1:nT, tgt(:,k) = DEP(k, pre+t+L).'; end
    for im = 1:numel(names)
        fc = squeeze(F.(names{im})(t, L, :));
        S(im,il) = sqrt(mean((tgt - fc).^2, 'all')) / sqrt(mean(tgt.^2, 'all'));
    end
end
T = array2table(round(S,3), 'RowNames', names, 'VariableNames', compose('L%dms', round(leads*1000/35)));
disp(T);
R = struct('F',F,'names',{names},'skill',S,'leads_ms',leads*1000/35,'DEP',DEP,'fold',fold,'W',W,'Hp',Hp);
save(fullfile(dataDir, sprintf('ctrl_mpc_forecasters_%s.mat', sess)), '-struct','R','-v7.3');
end

% ---- helpers --------------------------------------------------------------------------------
function [Xw, Yw] = windows(X, W, Hp)
Xw = []; Yw = [];
for k = 1:size(X,1)
    x = X(k,:); n = numel(x);
    for g = W:n-Hp, Xw(end+1,:) = x(g-W+1:g); Yw(end+1,:) = x(g+1:g+Hp); end %#ok<AGROW>
end
end

function net = trainNet(Xw, Yw, kind)
opts = trainingOptions('adam','MaxEpochs',40,'MiniBatchSize',256,'InitialLearnRate',2e-3, ...
    'Shuffle','every-epoch','Verbose',false,'L2Regularization',1e-3);
Hp = size(Yw,2); W = size(Xw,2);
switch kind
    case 'mlp'
        layers = [featureInputLayer(W) fullyConnectedLayer(64) reluLayer fullyConnectedLayer(64) reluLayer ...
                  fullyConnectedLayer(Hp) regressionLayer];
        net = trainNetwork(Xw, Yw, layers, opts);
    case 'lstm'
        layers = [sequenceInputLayer(1) lstmLayer(32,'OutputMode','last') fullyConnectedLayer(Hp) regressionLayer];
        net = trainNetwork(num2cell(Xw, 2).', Yw, layers, opts);
end
end

function a = fitAR(X, p)
n = size(X,2); Z = zeros(size(X,1)*(n-p), p); y = zeros(size(Z,1),1); r = 0;
for k = 1:size(X,1)
    x = X(k,:).'; idx = r + (1:n-p);
    for j = 1:p, Z(idx,j) = x(p+1-j:n-j); end
    y(idx) = x(p+1:n); r = idx(end);
end
a = (Z.'*Z + 1e-6*eye(p)) \ (Z.'*y);
end

function f = arIter(h, a, L)
p = numel(a); hh = h(end:-1:end-p+1).'; f = zeros(1,L);
for s = 1:L, nx = hh*a; f(s) = nx; hh = [nx hh(1:end-1)]; end
end

function al = fitTheta(X, W, Hp)
% pick the SES smoothing constant by in-sample multi-lead error
grid = 0.05:0.05:0.95; e = zeros(size(grid));
[Xw, Yw] = windows(X(:, :), W, Hp); idx = 1:5:size(Xw,1);
for i = 1:numel(grid)
    Fh = cell2mat(arrayfun(@(r) thetaF(Xw(r,:).', grid(i), W, Hp), idx.', 'uni', 0));
    e(i) = mean((Yw(idx,:) - Fh).^2, 'all');
end
[~, j] = min(e); al = grid(j);
end

function f = thetaF(h, al, W, Hp)
w = h(end-W+1:end); l = w(1);
for i = 2:W, l = al*w(i) + (1-al)*l; end              % SES level
b = polyfit((1:W).', w, 1); b = b(1);                  % linear-trend slope
f = l + 0.5*b*(1:Hp);                                  % theta(2) forecast
end
