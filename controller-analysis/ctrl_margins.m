% ctrl_margins.m -- closed-loop stability margins for the Methods "Closed-loop
% stability" paragraph (methods_rewrite.tex, the \textbf{n} placeholders at the
% gain/phase-margin sentence).
%
% MODEL, exactly as the Methods describes it:
%   plant   P(s)  = the fitted impulse TF (imp_tf_fits.mat), discretized ZOH at 35 Hz
%   delay   z^-d  with d = round(0.047*fs) samples for the 47 ms loop latency
%   control C(z)  = Kp + (Ki/fs) * sum_{j=0}^{M-1} z^-j,  M = 105   <-- eq:integral
%
% ⚠ THE "INTEGRAL" IS A TRAILING BOXCAR, NOT AN INTEGRATOR. eq:integral defines
%   ebar_t = (1/fs) * sum_{k=t-M+1}^{t} e_k, a FINITE window. Its transfer function
%   (1 - z^-M)/(1 - z^-1) has a zero at z = 1 that cancels the pole at z = 1, so the
%   loop contains NO free integrator and therefore has a nonzero steady-state error by
%   construction. Do not model this as Ki/(1 - z^-1): that would add an integrator the
%   rig never had and would report margins for a different controller.
%
% SIGN. The laser only inhibits, so the plant DC gain is negative, and the rig forms
% u from (y - ref) rather than (ref - y). The loop gain with the standard 1 + L
% convention is therefore L = -C*P*z^-d; with P < 0 this has positive DC gain.
%
% Output: per-session margins for every gain row, plus the range to quote.

root = 'C:\Users\aditya\Documents\projects\brain_paper';
F  = load(fullfile(root,'impulse-analysis','data','imp_tf_fits.mat'));
S  = F.Sprim;
fs = 35;  Ts = 1/fs;
d  = round(0.047*fs);                 % dead-time samples for the 47 ms latency
M  = 105;                             % boxcar length, 3 s at 35 Hz

% Gains: Table tab:gains. m4 interleaved three Kp values -> take the range endpoints.
G = [ ...
  1  0.175 0.100 0.100
  2  0.250 0.100 0.250
  3  0.220 0.075 0.010
  4  0.160 0.100 0.002        % m4 low end
  4  0.170 0.200 0.005        % m4 high end
  5  0.180 0.125 0.075
  6  0.150 0.150 0.100
  7  0.150 0.060 0.010
  8  0.150 0.050 0.100
  9  0.070 0.050 0.100
 10  0.100 0.070 0.100
 11  0.050 0.050 0.200
 12  0.100 0.050 0.100
 13  0.070 0.070 0.100
 14  0.050 0.075 0.010
 15  0.075 0.100 0.050 ];

% Controller C(z): proportional + boxcar "integral"
zz   = tf('z', Ts);
Cbox = tf((1/fs)*ones(1,M), [1 zeros(1,M-1)], Ts);   % (1/fs)*sum z^-j, j=0..M-1

fprintf('\nd = %d samples dead time (%.1f ms at %g Hz)\n', d, d*Ts*1000, fs);
fprintf('boxcar M = %d samples (%.2f s)\n\n', M, M*Ts);

for k = 1:numel(S)
    s = S{k};
    Pd = c2d(tf(s.sys.Numerator, s.sys.Denominator), Ts, 'zoh');
    fprintf('==== plant %d: %s   (DC gain %+.3f) ====\n', k, string(s.label), s.dcgain);
    gm = nan(size(G,1),1); pm = nan(size(G,1),1); stab = false(size(G,1),1);
    for i = 1:size(G,1)
        Kp = G(i,3);  Ki = G(i,4);
        C  = Kp + Ki*Cbox;
        L  = -C * Pd / zz^d;                 % sign: see header
        [Gm, Pm] = margin(L);
        gm(i) = 20*log10(Gm);  pm(i) = Pm;
        stab(i) = isstable(feedback(L, 1));
        fprintf('  m%-3d Kp=%.3f Ki=%.3f | GM %6.2f dB | PM %6.1f deg | CL stable: %d\n', ...
                G(i,1), Kp, Ki, gm(i), pm(i), stab(i));
    end
    fprintf('  --> GM %.1f-%.1f dB, PM %.0f-%.0f deg, %d/%d gain sets stable\n\n', ...
            min(gm), max(gm), min(pm), max(pm), sum(stab), numel(stab));
    R(k).label = string(s.label); R(k).gm = gm; R(k).pm = pm; R(k).stab = stab; %#ok<SAGROW>
end
assignin('base','MARG',R);
