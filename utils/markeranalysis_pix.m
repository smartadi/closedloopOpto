function m = markeranalysis(d,data)
%MARKERANALYSIS Summary of this function goes here




Fs = 35;            % Sampling frequency       
T = 1/Fs;           % Sampling period       
% L = 2*35;


L = 35;           % Length of signal
ti = (0:L-1)*T;     % Time vector
N = L+1;
dFk = data.dFk;


% w = 5000;
% X = dFk(w:w+L);
% Y = fft(X);
% P2 = abs(Y/L);
% P1 = P2(1:L/2+1);
% P1(2:end-1) = 2*P1(2:end-1);
% f = Fs/L*(0:(L/2));

[m1,m2] = size(dFk);

fft1=zeros(m1,L);
fft2=zeros(m1,L);
fft3=zeros(m1,L);
fft4=zeros(m1,L);

N1 = 35;
N2 = 2*35;
N3 = 3*35;

Rv1=zeros(m1,N1);
Rv2=zeros(m1,N2);
Rv3=zeros(m1,N3);

F1=[];
F2=[];
F3=[];
F4=[];

RRv1=[];
RRv2=[];
RRv3=[];


for j = 1:m1
    j
for i = N:length(dFk)
    Y = fft(dFk(j,(i-L):i));
    P2 = abs(Y/L);
    P1 = P2(1:L/2+1);
    P1(2:end-1) = 2*P1(2:end-1);



    % fft1 = [fft1,sum(P1(1:7))/sum(P1)];
    % fft2 = [fft2,sum(P1(8:13))/sum(P1)];
    % fft3 = [fft3,sum(P1(1:13))/sum(P1)];


    fft1 = [fft1,sum(P1(1:7))];
    fft2 = [fft2,sum(P1(8:13))];
    fft3 = [fft3,sum(P1(1:13))];
    fft4 = [fft4,sum(P1(14:end))];
end

F1 = [F1;fft1];
F2 = [F1;fft2];
F3 = [F1;fft3];
F4 = [F1;fft4];

% Running Variance



for i = N1:length(dFk)
    V = dFk(i-N1+1:i);
    Rv1=[Rv1,var(V)];
end

for i = N2:length(dFk)
    V = dFk(i-N2+1:i);
    Rv2=[Rv2,var(V)];
end

for i = N3:length(dFk)
    V = dFk(i-N3+1:i);
    Rv3=[Rv3,var(V)];
end

RRv1=[RRv1;Rv1];
RRv2=[RRv2;Rv2];
RRv3=[RRv3;Rv3];

end


m.Rv1=RRv1;
m.Rv2=RRv2;
m.Rv3=RRv3;

m.fft1=F1;
m.fft2=F2;
m.fft3=F3;
m.fft4=F4;

end

