function data = controllerData(data,d,t)
%CONTROLLERDATA Summary of this function goes here
%   Detailed explanation goes here

trials = ones(t,1);
trials = [zeros(length(d.input_params)-t,1);trials];



dFk = data.dFk;
nc = find(d.input_params(:,3)==0 & trials == 1);
wc = find(d.input_params(:,3)==1 & trials == 1);
dur = d.params.dur
t = d.timeBlue;
ti = d.inpTime;
% Trial Average

mv1 = d.motion.motSVD_0(1:2:end,1);
ncDfk=[];
ncInp=[];
ncmotion=[];
pncDfk=[];

for j = 1: length(nc)
    [a i] = min(abs(d.timeBlue - d.stimStarts(nc(j))));
    ncDfk = [ncDfk; dFk(i-35:i+35*(d.params.dur+1))];
    pncDfk = [pncDfk; dFk(i-35*10:i+35*(dur+3))];


    [a i2] = min(abs(ti - d.stimStarts(nc(j))));
    [a i3] = min(abs(ti - d.stimEnds(nc(j))));
    
    ncInp = [ncInp; d.inpVals(i2:i2+dur*2000)'];

    % ncmotion = [ncmotion; mv1(i-(35*5):i+35*(d.params.dur+2))'];
    ncmotion = [ncmotion; mv1(i-(35*10):i+35*(d.params.dur+2))'];

    
end


wcmotion=[];
wcDfk=[];
wcInp=[];
pwcDfk=[];
for j = 1: length(wc)
    [a i] = min(abs(d.timeBlue - d.stimStarts(wc(j))));
    wcDfk = [wcDfk; dFk(i-35:i+35*(d.params.dur+1))];
    
    pwcDfk = [pwcDfk; dFk(i-35*10:i+35*(dur+3))];


    [a i2] = min(abs(ti - d.stimStarts(wc(j))));
    [a i3] = min(abs(ti - d.stimEnds(wc(j))));
    
    wcInp = [wcInp; d.inpVals(i2:i2+dur*2000)'];

    % wcmotion = [wcmotion;  mv1(i-(35*5):i+35*(d.params.dur+2))'];
    wcmotion = [wcmotion;  mv1(i-(35*10):i+35*(d.params.dur+2))'];
end


data.ncInp = ncInp;
data.wcInp = wcInp;

nc_avg = mean(ncDfk,1);
wc_avg = mean(wcDfk,1);
T= -1:0.0285:(d.params.dur+1);
Tin = 0:0.0005:d.params.dur;
Tout = 0:0.0285:d.params.dur;
data.wc=wc;
data.nc=nc;
data.ncDfk = ncDfk;
data.wcDfk = wcDfk;

data.ncmotion = ncmotion;
data.wcmotion = wcmotion;



dur = d.params.dur;


data.pncDfk = pncDfk;
data.pwcDfk = pwcDfk;

%% Compute H2 performance per trial sum(||e||)

Tout = 0:0.0285:dur;

er_ncDfk=[];
vr_ncDfk=[];
for j = 1: length(nc)
    [a i] = min(abs(t - d.stimStarts(nc(j))));
    er_ncDfk = [er_ncDfk; norm(dFk(i:i+35*(dur))+5)];
    vr_ncDfk = [vr_ncDfk; var(dFk(i:i+35*(dur)))];
end




er_wcDfk=[];
vr_wcDfk=[];
for j = 1: length(wc)
    [a i] = min(abs(t - d.stimStarts(wc(j))));
    er_wcDfk = [er_wcDfk; norm(dFk(i:i+35*(dur))+5)];
    vr_wcDfk = [vr_wcDfk; var(dFk(i:i+35*(dur)))];
end

data.er_wcDfk = er_wcDfk;
data.er_ncDfk = er_ncDfk;

data.vr_wcDfk = vr_wcDfk;
data.vr_ncDfk = vr_ncDfk;

display('analysis done')
end

