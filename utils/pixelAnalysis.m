function dataPixel = pixelAnalysis(d,data,dFkp)
Fs=35;
wc=data.wc;
nc=data.nc;
tt = d.inpTime;
v = d.inpVals;

er_wcDfk = data.er_wcDfk;
er_ncDfk = data.er_ncDfk;

pwcDfk = data.pwcDfk;
pncDfk = data.pncDfk;

er = sort(er_wcDfk);
ner = sort(er_ncDfk);
dur = d.params.dur;
t = d.timeBlue;
dFk = data.dFk;


Wcpix=[];
Ncpix=[];

for k = 1:length(d.params.pixels)
    wcpix = [];    
    for j =1:length(wc)
        [a i] = min(abs(t - d.stimStarts(wc(j))));
        
        wcpix = [wcpix,dFkp(k,i-35*10:i+(dur+2)*35)];
    end
    Wcpix(:,:, end+1) = wcpix;


    ncpix = [];    
    for j =1:length(nc)
        [a i] = min(abs(t - d.stimStarts(nc(j))));
        
        cpix = [ncpix,dFkp(k,i-35*10:i+(dur+2)*35)];
    end
    Ncpix(:,:, end+1) = ncpix;

end

dataPixel.wcPix = Wcpix;
dataPixel.ncPix = Ncpix;
%% Variance based segregation
x1 = dFk;
x2 = dFk;  % Phase-shifted
win_len_sec=3;
frechet = frechet_distance_sliding(x1, x2, Fs, win_len_sec);


%% Get band power across pixels at stim start ::
tfb = d.stimStarts(wc);
tff = d.stimStarts(nc);
win_len_sec = 3;
bands = compute_bandpower_at_times(dFkp,d.timeBlue, Fs, win_len_sec, tfb, tff);


%
bpfb = bands.BandPower_Vec1;  % [n × length(tvec1) × 3]
[n, k, ~] = size(bpfb);
close all;
figure;
band_labels = {'1–3 Hz', '3–6 Hz', '6+ Hz'};

for b = 1:3
    subplot(3,1,b);
    hold on;
    
    for i = 1:n
        plot(er_wcDfk, squeeze(bpfb(i,:,b)),'o' ,'LineWidth', 1);
    end
    plot(er_wcDfk, squeeze(bpfb(1,:,b)),'ko' ,'LineWidth', 3);
    title(['Band ', num2str(b), ' (', band_labels{b}, ')']);
    xlabel('tracking MSE');
    ylabel('Band Power');
    grid on;
end
sgtitle('Band Power per region pre Stim (FB)');


bpfF = bands.BandPower_Vec2;  % [n × length(tvec1) × 3]

figure;
band_labels = {'1–3 Hz', '3–6 Hz', '6+ Hz'};
for b = 1:3
    subplot(3,1,b);
    hold on;

    for i = 1:n
        plot(er_ncDfk, squeeze(bpfF(i,:,b)),'o' ,'LineWidth', 1);
    end
        plot(er_ncDfk, squeeze(bpfF(1,:,b)),'ko' ,'LineWidth', 3);
    title(['Band ', num2str(b), ' (', band_labels{b}, ')']);
    xlabel('tracking MSE');
    ylabel('Band Power');
    grid on;
end
sgtitle('Band Power per region pre Stim (FF)');


%% Get band power across pixels during stim ::
tfb = d.stimEnds(wc);
tff = d.stimEnds(nc);
win_len_sec = 3;
bands = compute_bandpower_at_times(dFkp,d.timeBlue, Fs, win_len_sec, tfb, tff);


%
bpfb = bands.BandPower_Vec1;  % [n × length(tvec1) × 3]
[n, k, ~] = size(bpfb);
close all;
figure;
band_labels = {'1–3 Hz', '3–6 Hz', '6+ Hz'};

for b = 1:3
    subplot(3,1,b);
    hold on;
    
    for i = 1:n
        plot(er_wcDfk, squeeze(bpfb(i,:,b)),'o' ,'LineWidth', 1);
    end
    plot(er_wcDfk, squeeze(bpfb(1,:,b)),'ko' ,'LineWidth', 3);
    title(['Band ', num2str(b), ' (', band_labels{b}, ')']);
    xlabel('tracking MSE');
    ylabel('Band Power');
    grid on;
end
sgtitle('Band Power per region during Stim (FB)');


bpfF = bands.BandPower_Vec2;  % [n × length(tvec1) × 3]

figure;
band_labels = {'1–3 Hz', '3–6 Hz', '6+ Hz'};
for b = 1:3
    subplot(3,1,b);
    hold on;

    for i = 1:n
        plot(er_ncDfk, squeeze(bpfF(i,:,b)),'o' ,'LineWidth', 1);
    end
        plot(er_ncDfk, squeeze(bpfF(1,:,b)),'ko' ,'LineWidth', 3);
    title(['Band ', num2str(b), ' (', band_labels{b}, ')']);
    xlabel('tracking MSE');
    ylabel('Band Power');
    grid on;
end
sgtitle('Band Power per region during Stim (FF)');

%% Frechet distance before stim ::
dfk_temp = repmat(dFk, 15, 1);  % n x t
win_len_sec = 3;
Fs=35;
tfb = d.stimStarts(wc);
tff = d.stimStarts(nc);

frechet_dists_fb = compute_frechet_distance_at_times(dfk_temp, dFkp, d.timeBlue, Fs, win_len_sec, tfb);
frechet_dists_ff = compute_frechet_distance_at_times(dfk_temp, dFkp, d.timeBlue, Fs, win_len_sec, tff);


%%
n=15;
close all;
figure()

    hold on;

    for i = 1:n
        plot(er_wcDfk, frechet_dists_fb(i,:),'o' ,'LineWidth', 1);
    end
    plot(er_wcDfk, frechet_dists_fb(1,:),'ko' ,'LineWidth', 3);
    title('Frechet dist FB(prestim)');
    xlabel('tracking MSE');
    ylabel('f');
    grid on;


    n=15;
figure()

    hold on;

    for i = 1:n
        plot(er_ncDfk, frechet_dists_ff(i,:),'o' ,'LineWidth', 1);
    end
    plot(er_ncDfk, frechet_dists_ff(1,:),'ko' ,'LineWidth', 3);
    title('Frechet dist FF(prestim)');
    xlabel('tracking MSE');
    ylabel('f');
    grid on;
%% Frechet distance during stim ::
dfk_temp = repmat(dFk, 15, 1);  % n x t
win_len_sec = 3;
Fs=35;
tfb = d.stimEnds(wc);
tff = d.stimEnds(nc);

frechet_dists_fb = compute_frechet_distance_at_times(dfk_temp, dFkp, d.timeBlue, Fs, win_len_sec, tfb);
frechet_dists_ff = compute_frechet_distance_at_times(dfk_temp, dFkp, d.timeBlue, Fs, win_len_sec, tff);


%
n=15;
close all;
figure()

    hold on;

    for i = 1:n
        plot(er_wcDfk, frechet_dists_fb(i,:),'o' ,'LineWidth', 1);
    end
    plot(er_wcDfk, frechet_dists_fb(1,:),'ko' ,'LineWidth', 3);
    title('Frechet dist FB');
    xlabel('tracking MSE');
    ylabel('f');
    grid on;


    n=15;
figure()

    hold on;

    for i = 1:n
        plot(er_ncDfk, frechet_dists_ff(i,:),'o' ,'LineWidth', 1);
    end
    plot(er_ncDfk, frechet_dists_ff(1,:),'ko' ,'LineWidth', 3);
    title('Frechet dist FF');
    xlabel('tracking MSE');
    ylabel('f');
    grid on;
%% Variance Pre stim
win_len_sec=3;

tfb = d.stimStarts(wc);
tff = d.stimStarts(nc);

var_fb = compute_variance_at_times(dFkp, d.timeBlue, Fs, win_len_sec, tfb);  % [n × length(tvec)]
var_ff = compute_variance_at_times(dFkp, d.timeBlue, Fs, win_len_sec, tff);  % [n × length(tvec)]
%

n=15;
close all;
figure()

    hold on;

    for i = 1:n
        plot(er_wcDfk, var_fb(i,:),'o' ,'LineWidth', 1);
    end
    plot(er_wcDfk, var_fb(1,:),'ko' ,'LineWidth', 3);
    title('var FB prestim');
    xlabel('tracking MSE');
    ylabel('f');
    grid on;


    n=15;
figure()

    hold on;

    for i = 1:n
        plot(er_ncDfk, var_ff(i,:),'o' ,'LineWidth', 1);
    end
    plot(er_ncDfk, var_ff(1,:),'ko' ,'LineWidth', 3);
    title('var FF prestim');
    xlabel('tracking MSE');
    ylabel('f');
    grid on;
% Variance during Stim

    win_len_sec=3;

tfb = d.stimEnds(wc);
tff = d.stimEnds(nc);

var_fb = compute_variance_at_times(dFkp, d.timeBlue, Fs, win_len_sec, tfb);  % [n × length(tvec)]
var_ff = compute_variance_at_times(dFkp, d.timeBlue, Fs, win_len_sec, tff);  % [n × length(tvec)]


n=15;
% close all;
figure()

    hold on;

    for i = 1:n
        plot(er_wcDfk, var_fb(i,:),'o' ,'LineWidth', 1);
    end
    plot(er_wcDfk, var_fb(1,:),'ko' ,'LineWidth', 3);
    title('var FB during stim');
    xlabel('tracking MSE');
    ylabel('f');
    grid on;


    n=15;
figure()

    hold on;

    for i = 1:n
        plot(er_ncDfk, var_ff(i,:),'o' ,'LineWidth', 1);
    end
    plot(er_ncDfk, var_ff(1,:),'ko' ,'LineWidth', 3);
    title('var FF during stim');
    xlabel('tracking MSE');
    ylabel('f');
    grid on;
%% Sample without computing full data::::



%% Correlation Coeficiant


win_len_sec=3;

tfb = d.stimStarts(wc);
tff = d.stimStarts(nc);



c_fb = (compute_corr_relative(dFkp, d.timeBlue, tfb, win_len_sec));  % [n × length(tvec)]
c_ff = (compute_corr_relative(dFkp, d.timeBlue, tff, win_len_sec));  % [n × length(tvec)]
%


n=15;
close all;
figure()

    hold on;

    for i = 1:n-1
        plot(er_wcDfk, c_fb(:,i),'o' ,'LineWidth', 1);
    end
    title('var FB prestim');
    xlabel('tracking MSE');
    ylabel('f');
    grid on;


    n=15;
figure()

    hold on;

    for i = 1:n-1
        plot(er_ncDfk, c_ff(:,i),'o' ,'LineWidth', 1);
    end
    title('var FF prestim');
    xlabel('tracking MSE');
    ylabel('f');
    grid on;



win_len_sec=3;

tfb = d.stimEnds(wc);
tff = d.stimEnds(nc);



c_fb = compute_corr_relative(dFkp, d.timeBlue, tfb, win_len_sec);  % [n × length(tvec)]
c_ff = compute_corr_relative(dFkp, d.timeBlue, tff, win_len_sec);  % [n × length(tvec)]
%


n=15;
% close all;
figure()

    hold on;

    for i = 1:n-1
        plot(er_wcDfk, c_fb(:,i),'o' ,'LineWidth', 1);
    end
    title('var FB during stim');
    xlabel('tracking MSE');
    ylabel('f');
    grid on;


    n=15;
figure()

    hold on;

    for i = 1:n-1
        plot(er_ncDfk, c_ff(:,i),'o' ,'LineWidth', 1);
    end
    title('var FF during stim');
    xlabel('tracking MSE');
    ylabel('f');
    grid on;

%%


%%
end