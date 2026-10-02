% panelC_repro.m -- can Fig-4 panel C be reproduced from CURRENT caches?
% Replicates f4_error_decomp.m's pooling + unique-R^2 EXACTLY, except it applies the
% documented pick_pwc() fallback (legacy pwcDfk_l @col 106 -> current pwcDfk @col 351)
% that f4_partB_panels.m already has and f4_error_decomp.m does not.
% READ-ONLY: touches no project file, exports no figure.

root = 'C:\Users\aditya\Documents\projects\brain_paper';
cd(root); addpath(genpath('utils'));
L = load(fullfile(tempdir,'fig4_n_audit.mat'));   % A table from the audit
A = L.A;

R = { 'AL_0033','2025-01-20',3; 'AL_0033','2025-02-12',2; 'AL_0033','2025-02-24',2; ...
      'AL_0033','2025-02-26',2; 'AL_0033','2025-03-04',1; 'AL_0033','2025-03-05',2; ...
      'AL_0033','2025-03-20',4; 'AL_0033','2025-04-15',2; 'AL_0039','2025-04-20',1; ...
      'AL_0039','2025-04-19',1; 'AL_0039','2025-04-30',3; 'AL_0033','2025-04-19',1; ...
      'AL_0039','2025-04-20',2; 'AL_0048','2026-07-29',2; 'AL_0051','2026-07-29',2 };

% ---- constants, copied verbatim from f4_error_decomp.m ----
Fs=35; c0=36; c0_mot=71; c0_l=106; c0_p=351; mot_pre=2; spec_pre_s=2; spec_post_s=3;
delta_bnd=[1 4]; hi_bnd=[2 4]; tot_bnd=[0.4 10]; ref=-5; dur=3;
eE = c0 : c0+round(1*Fs);
lL = c0+round(1*Fs)+1 : c0+round(3*Fs);
fitR2 = @(Xp,yp) 1 - sum((yp - [ones(size(Xp,1),1),Xp]*([ones(size(Xp,1),1),Xp]\yp)).^2) / ...
                     max(sum((yp-mean(yp)).^2),eps);
bp = @(seg,lo,hi) local_bp(seg,Fs,lo,hi);

X1=[];X2=[];Xrel=[];Xdel=[]; YE=[];YL=[]; SESS=[];
fprintf('\n%-5s %-8s %7s %7s  %s\n','id','mouse','nCL','used','pwc field / note');
fprintf('%s\n',repmat('-',1,62));
for k=1:15
    if ~A.hasCache(k) || ~A.has_motion(k); continue; end
    mn=R{k,1}; td=R{k,2}; en=R{k,3};
    p = fullfile(root,'data', sprintf('%sctrl%s%s%d.mat', mn, td(6:7), td(9:10), en));
    S=load(p,'data'); dk=S.data; clear S
    if ~isfield(dk,'wcmotion'); fprintf('  %-5s skip: no wcmotion\n', A.id(k)); continue; end

    % --- pick_pwc fallback (the fix f4_error_decomp.m is missing) ---
    if isfield(dk,'pwcDfk_l') && ~isempty(dk.pwcDfk_l)
        P = dk.pwcDfk_l; cc = c0_l; src='pwcDfk_l (legacy)';
    elseif isfield(dk,'pwcDfk') && ~isempty(dk.pwcDfk)
        P = dk.pwcDfk;   cc = c0_p; src='pwcDfk (current)';
    else
        fprintf('  %-5s skip: no pwc field at all\n', A.id(k)); continue
    end

    nT = size(dk.wcDfk,1);
    x1 = abs(dk.wcDfk(:,c0)-ref);
    ws = max(1,c0_mot-round(mot_pre*Fs)); we = min(size(dk.wcmotion,2), c0_mot+round(dur*Fs)-1);
    x2 = mean(dk.wcmotion(1:nT,ws:we).^2,2);          % NOTE: SQUARED (f4_error_decomp)
    sa = cc-round(spec_pre_s*Fs); sb = cc+round(spec_post_s*Fs);
    if sa<1 || sb>size(P,2)
        fprintf('  %-5s skip: spectral window [%d %d] outside %s (%d cols)\n', ...
                A.id(k), sa, sb, src, size(P,2)); continue
    end
    [xrel,xdel]=deal(nan(nT,1));
    for t=1:nT
        seg=double(P(t,sa:sb));
        xdel(t)=bp(seg,delta_bnd(1),delta_bnd(2));
        xrel(t)=bp(seg,hi_bnd(1),hi_bnd(2))/max(bp(seg,tot_bnd(1),tot_bnd(2)),eps);
    end
    yE=sqrt(mean((dk.wcDfk(1:nT,eE)-ref).^2,2));
    yL=sqrt(mean((dk.wcDfk(1:nT,lL)-ref).^2,2));
    m=min([nT numel(x1) numel(x2) numel(xrel)]);
    X1=[X1;x1(1:m)]; X2=[X2;x2(1:m)]; Xrel=[Xrel;xrel(1:m)]; Xdel=[Xdel;xdel(1:m)];
    YE=[YE;yE(1:m)]; YL=[YL;yL(1:m)]; SESS=[SESS;repmat(k,m,1)];
    fprintf('  %-5s %-8s %7d %7d  %s\n', A.id(k), mn, nT, m, src);
end

ok = isfinite(X1)&isfinite(X2)&isfinite(Xrel)&isfinite(Xdel)&isfinite(YE)&isfinite(YL);
X1=X1(ok);X2=X2(ok);Xrel=Xrel(ok);Xdel=Xdel(ok);YE=YE(ok);YL=YL(ok);SESS=SESS(ok);
usess=unique(SESS);
fprintf('\nPOOL: %d CL trials / %d sessions  (%s)\n', numel(YE), numel(usess), ...
        strjoin(cellstr("m"+string(usess))',','));

X = [X1 X2 Xrel Xdel]; lbl = {'init-dev','motion','rel 2-4Hz','abs delta'};
fprintf('\n%-11s %10s %10s   (paper: early -> settled)\n','factor','early 0-1s','settled 1-3s');
for j=1:4
    for w=1:2
        y = (w==1)*0; if w==1, y=YE; else, y=YL; end
        full = fitR2(X,y); drop = fitR2(X(:,setdiff(1:4,j)),y);
        u(j,w) = full-drop;
    end
    fprintf('%-11s %10.3f %10.3f\n', lbl{j}, u(j,1), u(j,2));
end
fprintf('\nfull model R^2: early %.3f  settled %.3f\n', fitR2(X,YE), fitR2(X,YL));
fprintf('\nPaper claims: init 0.29->0.004 | motion <0.01 | rel 0.10->0.12 | abs 0.23->0.35\n');
fprintf('              over 397 CL trials / 7 sessions\n');

function p=local_bp(seg,Fs,lo,hi)
% VERBATIM copy of local_bandpow from controller-analysis/f4_error_decomp.m
    seg=detrend(double(seg(:)).','linear'); N=numel(seg);
    w=hannwin(N).'; P=abs(fft(seg.*w)).^2; P=P(1:floor(N/2)+1);
    fr=(0:floor(N/2))*Fs/N; p=sum(P(fr>=lo & fr<hi));
end
