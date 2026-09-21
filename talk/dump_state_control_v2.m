%% dump_state_control_v2.m -- per-trial RMSE + within-session state quartile
% Richer dump than dump_state_control.m: keeps every trial's RMSE and its
% within-session state quartile (1-4) for OL and CL, for two states:
%   motion  (ALL trials)           -> control error vs movement
%   prevar  (motion-clean trials)  -> control error vs pre-stim variability
% Feeds a self-explanatory violin figure (make_state_control_v2.py). Headless.

cd('C:\Users\aditya\Documents\projects\brain_paper');
addpath(genpath(fullfile(pwd,'utils')));
addpath(fullfile(pwd,'controller-analysis'));

r_lean = 1;
load_sessions;

root  = 'C:\Users\aditya\Documents\projects\brain_paper';
Fs=35; dur=3; NKEEP=13; motThresh=1.5; PRE_S=2; nBins=4;
c0_l = 3*Fs + 1; preA = c0_l - round(PRE_S*Fs); preB = c0_l - 1;

fields = fields(1:min(NKEEP,numel(fields)));
nS = numel(fields);

Xo=[]; Xc=[]; Ko=false(0,1); Kc=false(0,1); Yo=[]; Yc=[]; So=[]; Sc=[];
for k = 1:nS
    mn = mouse.(fields{k}).mn; td = mouse.(fields{k}).td; en = mouse.(fields{k}).en;
    pc = fullfile(root,'data', sprintf('%sctrl%s%s%d.mat', mn, td(6:7), td(9:10), en));
    if ~isfile(pc); continue; end
    T = load(pc,'data'); D = T.data; clear T
    if ~isfield(D,'ncmotion') || ~any(D.ncmotion(:)); clear D; continue; end

    pnc = D.pncDfk(:, 246:end);   pwc = D.pwcDfk(:, 246:end);
    yo  = D.er_ncDfk(:);          yc  = D.er_wcDfk(:);
    nmc = size(D.ncmotion,2); ons = nmc - Fs*dur;
    wa = max(1, ons - round(2*Fs)); wb = min(nmc, ons + dur*Fs);
    mo = mean(D.ncmotion(:, wa:wb), 2);   mc = mean(D.wcmotion(:, wa:wb), 2);

    no = min([size(pnc,1) numel(yo) numel(mo)]);
    nc = min([size(pwc,1) numel(yc) numel(mc)]);
    pnc=pnc(1:no,:); yo=yo(1:no); mo=mo(1:no);
    pwc=pwc(1:nc,:); yc=yc(1:nc); mc=mc(1:nc);

    ko = abs(mo) <= motThresh;   kc = abs(mc) <= motThresh;
    so = pnc(:, preA:preB);      sc = pwc(:, preA:preB);
    xo_k = [mo, var(so,0,2)];    xc_k = [mc, var(sc,0,2)];

    g_o = all(isfinite(xo_k),2) & isfinite(yo);
    g_c = all(isfinite(xc_k),2) & isfinite(yc);
    if sum(g_o) < 10 || sum(g_c) < 10; clear D pnc pwc so sc; continue; end

    Xo=[Xo; xo_k(g_o,:)]; Xc=[Xc; xc_k(g_c,:)];
    Yo=[Yo; yo(g_o)];     Yc=[Yc; yc(g_c)];
    So=[So; k*ones(sum(g_o),1)]; Sc=[Sc; k*ones(sum(g_c),1)];
    Ko=[Ko; ko(g_o)];     Kc=[Kc; kc(g_c)];
    clear D pnc pwc so sc
end

specs = struct('key',{'motion','prevar'}, 'si',{1,2}, 'clean',{false,true});
out = struct();
for s = 1:numel(specs)
    si = specs(s).si;
    if specs(s).clean; mo_=Ko; mc_=Kc; else; mo_=true(size(Ko)); mc_=true(size(Kc)); end
    xo=Xo(mo_,si); xc=Xc(mc_,si); yo_=Yo(mo_); yc_=Yc(mc_);
    So_=So(mo_); Sc_=Sc(mc_); ss=unique([So_;Sc_]).';
    bo=nan(size(xo)); bc=nan(size(xc));
    for i=1:numel(ss)
        io=So_==ss(i); ic=Sc_==ss(i);
        e=quantile([xo(io);xc(ic)], linspace(0,1,nBins+1));
        t=discretize(xo(io),e); t(isnan(t))=nBins; bo(io)=t;
        t=discretize(xc(ic),e); t(isnan(t))=nBins; bc(ic)=t;
    end
    g=isfinite(bo)&isfinite(yo_); bo=bo(g); yo_=yo_(g);
    g=isfinite(bc)&isfinite(yc_); bc=bc(g); yc_=yc_(g);
    out.(specs(s).key) = struct('q_ol',bo(:).','y_ol',yo_(:).', ...
                                'q_cl',bc(:).','y_cl',yc_(:).', ...
                                'nSess',numel(ss),'nOL',numel(yo_),'nCL',numel(yc_));
end

jf = 'C:\Users\aditya\AppData\Local\Temp\claude\C--Users-aditya-Documents-projects-brain-paper\69483c53-45a2-45f3-9e5d-0965ff7a6be0\scratchpad\state_control_v2.json';
fid=fopen(jf,'w'); fprintf(fid,'%s',jsonencode(out)); fclose(fid);
fprintf('[dump v2] wrote %s\n', jf);
for s=1:numel(specs)
  o=out.(specs(s).key);
  fprintf('  %s: nSess=%d nOL=%d nCL=%d\n', specs(s).key, o.nSess, o.nOL, o.nCL);
end
