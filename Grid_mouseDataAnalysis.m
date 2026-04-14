%% Data analysis Script
% add var and fft to a function


clc;
close all;
clear all;
githubDir = "/home/nimbus/Documents/Brain/"

% Script to analyze widefield/behavioral data from 

addpath(genpath(fullfile(githubDir, 'widefield'))) % cortex-lab/widefield
addpath(genpath(fullfile(githubDir, 'Pipelines'))) % SteinmetzLab/Pipelines
addpath(genpath(fullfile(githubDir, 'npy-matlab'))) % kwikteam/npy-matlab
addpath('utils')

%% experiment name
% mn = 'AL_0033'; td = '2025-03-03'; 
% en = 2;


% mn = 'AL_0033'; td = '2025-04-15'; 
% en = 2;

mn = 'AL_0041'; td = '2026-02-10'; 
en = 1;
%%%%%%%%% with rewards %%%%%%%%%%%%%
% mn = 'AL_0033'; td = '2025-03-05'; 
% en = 1;

% mn = 'AL_0033'; td = '2025-03-18'; 
% en = 1;

%% get data
pathString = genpath('utils');
    addpath(pathString);
    % %%
    % addpath('utils')
d = initialize_data(mn,en,td);

d.params.pix_ids = [2,4,5,8,9,12,13];
d.params.pix_inv = [170,320];
% get inputs
sigName = 'lightCommand638';
% sigName = 'lightCommand';
[tt, v] = getTLanalog(mn, td, en, sigName);
    serverRoot = expPath(mn, td, en);

tInd = 1;
traces(tInd).t = tt;
traces(tInd).v = v;
traces(tInd).name = sigName;
traces(tInd).lims = [0 5];
%% Load or save from image data

mode = 0  % from binary image
% mode = 1 ; % from SVD
%
% r = 0; % dont read file
r = 1; % read file
[data,dFk_temp] = getpixel_dFoF(d,mode,d.params.pixel,r);
dFk = data.dFk;

%% Trial Samples
% d.mv = d.motion.motion_1;
% d.mv = d.motion.motion_1(1:2:end,1);


dur = d.params.dur;
t = d.timeBlue;
close all
j=6;
[a i] = min(abs(t - d.stimStarts(j)));
[a i2] = min(abs(t - d.stimEnds(j)));


tt = d.inpTime;
v = d.inpVals;

[a k] = min(abs(tt - d.stimStarts(j)));
[a k2] = min(abs(tt - d.stimEnds(j)));



% Tin = 0:0.0005:stimDur(j);
Tout = -3:0.0285:dur+3;
close all
figure()
subplot(3,1,1)
plot(Tout,dFk((i-(3*35)):(i+35*(dur+3))));hold on
plot(Tout,-5*ones(1,length(Tout)))
xlim([-3,6])
xline(0)
xline(3)
ylabel('dF/F trace')

subplot(3,1,2)
% plot(tt(k:k2)-tt(k),v(k:k2));
plot(tt(k:k2)-tt(k),v(k:k2))
xlim([-3,6])
xline(0)
xline(3)
ylabel('Input Values');


% subplot(3,1,3)
% plot(Tout,d.mv((i-(3*35)):(i+35*(dur+3))));hold on
% plot(Tout,5*ones(1,length(Tout)))
% xlim([-3,6])
% xline(0)
% xline(3)
% ylabel('motion')
% xlabel('Time (s)');
% sgtitle('trial sample')



%% Grid Experiment
close all;
dur = d.params.dur;
% gc = find(d.input_params(:,3)==2);

[C,ia,ic] = unique(d.input_params(:,5:6),'rows')

J_val =zeros(length(C),1);


K_plot=[];
K_val=[];
K_fft=[];

for i = 1:length(C)
    K_val.("K"+num2str(i)) = [];
    K_plot.("K"+num2str(i)) = [];
    K_fft.("K"+num2str(i)) = [];
end
fk = fieldnames(K_val);

Er_k = [];
pcDfk=[];
ts = -0.5:1/35:3.5;
L = 106;
L = 35*3;
Fs = 35;            % Sampling frequency                    
T = 1/Fs;             % Sampling period       
tf = (0:L-1)*T;        % Time vector
ff = Fs/L*(0:(L/2));



figure()
for j =1:length(ic)
    k = numel(find(ic==ic(j)));
    [a i] = min(abs(t - d.stimStarts(j)));
    %i = d.input_params(j,2) - d.params.horizon;

    
    
    


    % pcDfk = [pcDfk;  dFk((i-35*(5)): (i+35*(5)) )];
    traj = norm(dFk(i:(i+35*(dur)))+2)/k;
    Er_k = [Er_k,traj];
    J_val(ic(j)) = J_val(ic(j)) + traj;

    if abs(dFk(i)) < 2
        
        pcDfk = [pcDfk;  dFk((i-35*(5)): (i+35*(5)) )];
        K_plot.(fk{ic(j)}) = [K_plot.(fk{ic(j)});dFk((i-35*(0.5)): (i+35*(3.5)) )];

        K_val.(fk{ic(j)}) = [K_val.(fk{ic(j)});dFk(i: i+35*3) ];
        

        X = dFk(i: i+35*3);
        Y = fft(X);

        P2 = abs(Y/L);
        P1 = P2(1:L/2+1);
        P1(2:end-1) = 2*P1(2:end-1);
        
        
        K_fft.(fk{ic(j)}) = [K_fft.(fk{ic(j)}); P1];
    


    
 
    subplot(2,9,ic(j))
    % plot(ts,dFk((i-35*(5)): (i+35*(5)) ));hold on
    plot(ts,dFk((i-35*(0.5)): (i+35*(3.5)) ));hold on
    title(append('(',num2str(C(ic(j),1)),',',num2str(C(ic(j),2)),')', 'J = ',num2str(J_val(ic(j)))))
    xline(0,'LineWidth',3)
    xline(3,'LineWidth',3)
    xlim([-0.5 3.5])
    ylim([-6 6])
    yline(-2,'--r','LineWidth',3)

    end

end
Km=[];
Kmm=[];
Kv=[];
Kvv=[];
KFF = [];
for j = 1:length(C)

    Km = [Km;norm(mean(K_val.(fk{j}),1)+2)];
    
    Kmm = [Kmm;mean(vecnorm(K_val.(fk{j})+2,2,2))];


    Kvv = [Kvv;vecnorm(K_val.(fk{j})+2,2,2)];
    
    Kv = [Kv;var(K_plot.(fk{j}))];
    subplot(2,9,j)
    plot(ts,mean(K_plot.(fk{j}),1),'--k','LineWidth',2)




end
%%
close all;
figure()
for j=1:length(C)
subplot(2,9,j)
plot(ts,Kv(j,:),'g','LineWidth',2);hold on
plot(ts,Kv(1,:),'r','LineWidth',2);hold on
    xline(0,'LineWidth',3)
    xline(3,'LineWidth',3)
ylabel('var')
xlabel('time')
title('variance')
end
legend('feedback','feedforward')
%
figure()
% plot3(C(:,1),C(:,2),J_val,'or','LineWidth',2)
plot3(C(:,1),C(:,2),Kmm,'or','LineWidth',2);
xlabel('Kp')
ylabel('Ki')
grid on


%


% f = fit([C(:,1) C(:,2)],J_val,'linearinterp');
f = fit([C(:,1) C(:,2)],Kmm,'linearinterp');
% close all;
figure()
% plot(f,[C(:,1),C(:,2)],J_val);hold on;
plot(f,[C(:,1),C(:,2)],Kmm);hold on;
colorbar
plot3(C(:,1),C(:,2),40*ones(1,length(C)),'r*','LineWidth',2)
xlabel('Kp')
ylabel('Ki')
zlabel('MSE')
title('Cost function J(Kp,Ki)')
p = gca;
p.View = [0,90];
figure_property.Width= '16'; % Figure width on canvas
figure_property.Height= '9'; % Figure height on canvas
% hgexport(gcf,'images/contour.pdf',figure_property); %Set desired file name


figure()
for i = 1:length(C)
    subplot(2,9,i)
    plot(ff,K_fft.(fk{i}));hold on
    ylim([0,7])
    xlabel('freq')
    ylabel('freq abs val')
end

%





%
f = fit([C(:,1) C(:,2)],Kmm,'linearinterp');

% close all;
figure()
plot(f,[C(:,1),C(:,2)],Kmm)
colorbar
xlabel('Kp')
ylabel('Ki')
zlabel('MSE')
title('Cost function J(Kp,Ki)')
%


%%
gc = find(d.input_params(:,3)==2);
tt = d.inpTime;
v = d.inpVals;
%
m=30;
j = gc(m);
% [a i] = min(abs(t - d.stimStarts(j)));
% [a i2] = min(abs(t - d.stimEnds(j)));

[a k] = min(abs(tt - d.stimStarts(j)));
[a k2] = min(abs(tt - d.stimEnds(j)));

i = d.input_params(j,2)

% Tin = 0:0.0005:stimDur(j);
Tout = 0:0.0285:dur;
close all
figure()
subplot(2,2,1)
plot(Tout,-dFk(i:i+35*dur));hold on
plot(Tout,5*ones(1,length(Tout)))
xlim([0,dur])
title('wc')

subplot(2,2,3)
plot(tt(k:k2)-tt(k),v(k:k2))
xlim([0,dur])
ylim([0,5])
%% Variability analysis

% Classify x0
X0=[];
for j = 1: length(wc)
    [a i] = min(abs(t - d.stimStarts(wc(j))));
    X0 = [X0; dFk(i)];
end



%% no stim data 10 seconds before every stim

nostim=[];
L = 35*10;
Fs = 35;            % Sampling frequency                    
T = 1/Fs;             % Sampling period       
tf = (0:L-1)*T;        % Time vector
ff = Fs/L*(0:(L/2));
tns = -10:1/35:0;


nostimfft= [];
for k = 1:length(d.stimStarts)
    [a i] = min(abs(t - d.stimStarts(k)));

    nostim = [nostim;dFk(i-10*35:i)];

    X = dFk(i-10*35:i);
    Y = fft(X);

        P2 = abs(Y/L);
        P1 = P2(1:L/2+1);
        P1(2:end-1) = 2*P1(2:end-1);

        nostimfft= [nostimfft;P1];

end





%%
j = 100
X = nostim(j,:);
    Y = fft(X);

        P2 = abs(Y/L);
        P1 = P2(1:L/2+1);
        P1(2:end-1) = 2*P1(2:end-1);


close all

nno_stim = reshape(nostim.',1,[]);
nv = var(nno_stim);

maxn = max(nostim);
minn = min(nostim);


figure()
plot(tns,nostim,'LineWidth',0.3,'HandleVisibility','off');hold on;
plot(tns,mean(nostim,1),'--k','LineWidth',3.5);
plot(tns,maxn,'k','LineWidth',2,'HandleVisibility','off');
plot(tns,minn,'k','LineWidth',2);
plot(tns,sqrt(nv)*ones(1,length(tns))+mean(nostim,1),'--k','LineWidth',2);
plot(tns,-sqrt(nv)*ones(1,length(tns))+mean(nostim,1),'--k','LineWidth',2,'HandleVisibility','off');
legend('trail average','min-max','std dev')
title('dF/F traces pre stim')



% figure()
% plot(ff,nostimfft)
% 
% 
% 
% figure()
% plot(ff,P1)

%%
Xp = nostim(:,2:9*35);
Xm = nostim(:,1:9*35-1);


j = 101
nn = 6

l=1
max_order = 10;
p = 2*(max_order)/l;
% p = 10

AUX=[];

D=[];
Ds=[];

for j = 1:length(d.stimStarts)
[A,du1,C,du2,K,R,AUX] = subid(Xm(j,:),[],p,nn,[],[],1);
A = logm(A)*35;
D = [D,eig(A)];

[As,du1s,Cs,du2s,Ks,Rs] = subid_stable(Xm(j,:),[],p,nn,AUX,'sv');
As = logm(As)*35;
Ds = [Ds,eig(As)];

end

close all;

figure()
plot(D,'or');hold on
% plot(Ds,'ob')
%%

y = Xm(j,:);

[A,du1,C,du2,K,R,AUX] = subid(y,[],p);


[yp,erp] = predic(y,[],A,[],C,[],K);


figure()

    plot([y(1:300);yp(1:300)']')
    title('Real (yellow) and predicted (purple) output')

    %%
i=p;
nn=20
        [A,du1,C,du2,K,R,AUX] = subid(y,[],i,2,[],[],1);
    era = [];
    for n = 1:nn
      [A,B,C,D,K,R] = subid(y,[],i,n,AUX,[],1);
      [yp,erp] = predic(y,[],A,[],C,[],K);
      era(n,:) = erp;
    end
    
%   Hit any key
pause
clc
%           
%   We have now determined the prediction errors for all systems 
%   from order 1 through 6.
%   Plotting these often gives a clearer indication of the order:
%   
    figure()
    bar([1:nn],era);title('Prediction error');
    xlabel('System order');
    %%


        [ersa,erpa] = allord(y,[],i,[1:20],AUX);