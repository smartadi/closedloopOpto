% impulse-analysis -- TF fit comparison across all 3 impulse sessions.
% Run from impulse-analysis/ after load_experiments.m (needs allExperiments, fs, tWin).
%
% Purpose: Nick 2026-05-08 request -- fit the same low-order LTI model to every
% impulse session and tabulate poles / time constants / R^2 so we can state
% whether the dynamics agree across sessions (validates the LTI assumption).
%
% Methodology mirrors tf_fit.m exactly:
%   amplitude^2-weighted normalised impulse response h_norm -> tfest sweep
%   (np 1..maxPoles, nz 0..np-1, nd 0..maxDelay) -> AIC selection.
% Time constants are read from the continuous-time poles of the AIC-best model.

maxPoles = 3;        % sweep 1..maxPoles
maxZeros = 3;        % sweep 0..min(np-1, maxZeros)
maxDelay = 0;        % sweep 0..maxDelay samples (0 = no input delay, matches tf_fit.m)
tFit_s   = 0.5;      % post-stim fit window end (s)

nExp   = numel(allExperiments);
Ts     = 1/fs;
t_full = -tWin : 1/fs : tWin;
iPost  = find(t_full >= 0 & t_full <= tFit_s);
tPost  = t_full(iPost)';
tfOpt  = tfestOptions('EnforceStability', false, 'Display', 'off');

S = struct('mn',{},'td',{},'np',{},'nz',{},'nd',{},'R2pool',{}, ...
           'poles',{},'tau_ms',{},'fd_hz',{},'zeta',{},'dcgain',{});

for e = 1:nExp
    DF_s   = allExperiments(e).DF_imp;
    uA_s   = allExperiments(e).uAmp(:);
    nAmp_s = numel(uA_s);

    validAmp = uA_s > 0;
    w_amp    = uA_s(validAmp).^2;  w_amp = w_amp / sum(w_amp);
    h_rows   = bsxfun(@rdivide, DF_s(validAmp, iPost), uA_s(validAmp));
    h_norm   = sum(bsxfun(@times, h_rows, w_amp), 1, 'omitnan')';
    validT_h = isfinite(h_norm);
    nT_h     = sum(validT_h);

    nPre   = maxPoles + maxZeros + 2;
    u_fit  = [zeros(nPre,1); 1; zeros(nT_h-1, 1)];
    y_fit  = [zeros(nPre,1); h_norm(validT_h)];
    data_fit = iddata(y_fit, u_fit, Ts);
    data_fit.Tstart = -nPre * Ts;

    % --- order sweep, AIC selection ---
    res = struct('np',{},'nz',{},'nd',{},'AIC',{},'sys',{}); ri = 0;
    for nd = 0:maxDelay
        for np = 1:maxPoles
            for nz = 0:min(np-1, maxZeros)
                try
                    sys_i = tfest(data_fit, np, nz, tfOpt, 'InputDelay', nd*Ts);
                    ri = ri+1;
                    res(ri).np=np; res(ri).nz=nz; res(ri).nd=nd;
                    res(ri).AIC=aic(sys_i); res(ri).sys=sys_i;
                catch
                end
            end
        end
    end
    [~, iBest] = min([res.AIC]);
    best_sys = res(iBest).sys;

    % --- pooled R^2 across all amplitudes (scaled unit-impulse sim) ---
    y_pool = []; yp_pool = [];
    for iAmp = 1:nAmp_s
        y_i = DF_s(iAmp, iPost)'; vT = ~isnan(y_i);
        if sum(vT) < 5, continue; end
        u_unit = [zeros(nPre,1); 1; zeros(sum(vT)-1, 1)];
        yp_obj = sim(best_sys, iddata([], u_unit, Ts));
        yp_i   = uA_s(iAmp) * yp_obj.OutputData(nPre+1:end);
        y_pool = [y_pool;  y_i(vT)]; %#ok<AGROW>
        yp_pool= [yp_pool; yp_i];    %#ok<AGROW>
    end
    R2pool = 1 - sum((y_pool - yp_pool).^2) / sum((y_pool - mean(y_pool)).^2);

    % --- poles -> time constants ---
    p      = pole(best_sys);                 % continuous-time (rad/s)
    tau_ms = -1000 ./ real(p);               % envelope time constant (ms)
    fd_hz  = abs(imag(p)) / (2*pi);          % damped oscillation freq (Hz)
    zeta   = -real(p) ./ abs(p);             % damping ratio

    S(e).mn=allExperiments(e).mn; S(e).td=allExperiments(e).td;
    S(e).np=res(iBest).np; S(e).nz=res(iBest).nz; S(e).nd=res(iBest).nd;
    S(e).R2pool=R2pool; S(e).poles=p; S(e).tau_ms=tau_ms;
    S(e).fd_hz=fd_hz; S(e).zeta=zeta; S(e).dcgain=dcgain(best_sys);
end

% ---- comparison table ----
fprintf('\n================ TF fit comparison across impulse sessions ================\n');
fprintf('%-22s %-7s %-7s  %-9s  %-24s  %-18s\n', ...
    'Session','order','R2pool','dcgain','time const tau (ms)','damped f (Hz)');
fprintf('%s\n', repmat('-',1,100));
for e = 1:nExp
    ordStr = sprintf('%dp%dz%dd', S(e).np, S(e).nz, S(e).nd);
    tauStr = strjoin(compose('%.0f', sort(S(e).tau_ms,'descend')'), ', ');
    fdU    = unique(round(S(e).fd_hz(S(e).fd_hz>1e-6),2));
    fdStr  = isempty(fdU)*0; if isempty(fdU), fdStr='(real)'; else, fdStr=strjoin(compose('%.2f',fdU'),', '); end
    fprintf('%-22s %-7s %-7.3f  %-9.3f  %-24s  %-18s\n', ...
        sprintf('%s %s', S(e).mn, S(e).td), ordStr, S(e).R2pool, S(e).dcgain, tauStr, fdStr);
end
fprintf('%s\n', repmat('-',1,100));
fprintf('tau = -1/Re(pole); slowest (dominant) constant governs ~settling time.\n');
