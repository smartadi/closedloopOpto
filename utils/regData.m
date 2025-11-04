function reg = regData(reg,d,data)
%CONTROLLERDATA Summary of this function goes here
%   Detailed explanation goes here





dFk = reg.dFk;
nc = data.nc;
wc = data.wc;
dur = d.params.dur
t = d.timeBlue;
ti = d.inpTime;
% Trial Average

% mv1 = d.motion.motSVD_0(1:2:end,1);
ncDfk=[];
ncInp=[];
ncmotion=[];
pncDfk=[];

for j = 1: length(nc)
    [a i] = min(abs(d.timeBlue - d.stimStarts(nc(j))));
    ncDfk = [ncDfk; dFk(i-35:i+35*(d.params.dur+1))];

    [a i2] = min(abs(ti - d.stimStarts(nc(j))));
    
    ncInp = [ncInp; d.inpVals(i2:i2+dur*2000)'];


end


wcmotion=[];
wcDfk=[];
wcInp=[];
pwcDfk=[];
for j = 1: length(wc)
    [a i] = min(abs(d.timeBlue - d.stimStarts(wc(j))));
    wcDfk = [wcDfk; dFk(i-35:i+35*(d.params.dur+1))];
    


    [a i2] = min(abs(ti - d.stimStarts(wc(j))));
    
    wcInp = [wcInp; d.inpVals(i2:i2+dur*2000)'];


end


reg.ncInp = ncInp;
reg.wcInp = wcInp;

nc_avg = mean(ncDfk,1);
wc_avg = mean(wcDfk,1);
T= -1:0.0285:(d.params.dur+1);
Tin = 0:0.0005:d.params.dur;
Tout = 0:0.0285:d.params.dur;
reg.wc=wc;
reg.nc=nc;
reg.ncDfk = ncDfk;
reg.wcDfk = wcDfk;



%% Compute H2 performance per trial sum(||e||)

Tout = 0:0.0285:dur;

er_ncDfk=[];
vr_ncDfk=[];
for j = 1: length(nc)
    [a i] = min(abs(t - d.stimStarts(nc(j))));
    er_ncDfk = [er_ncDfk; norm(dFk(i:i+35*(dur))'-data.dFk(i:i+35*(dur)))];
end




er_wcDfk=[];
vr_wcDfk=[];
for j = 1: length(wc)
    [a i] = min(abs(t - d.stimStarts(wc(j))));
    er_wcDfk = [er_wcDfk; norm(dFk(i:i+35*(dur))'-data.dFk(i:i+35*(dur)))];
end

reg.er_wcDfk = er_wcDfk;
reg.er_ncDfk = er_ncDfk;

reg.vr_wcDfk = vr_wcDfk;
reg.vr_ncDfk = vr_ncDfk;

display('analysis done')
end

