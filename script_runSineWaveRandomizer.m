%%
% s = daq.createSession('ni');
% daq.getDevices
% 
% %%c
% 
% dev = 'Dev3'; % 1 for rainier, 3 for baker
% s.addAnalogOutputChannel(dev, 'ao0', 'Voltage'); % laser
% s.addAnalogOutputChannel(dev, 'ao1', 'Voltage'); % galvo x
% s.addAnalogOutputChannel(dev, 'ao2', 'Voltage'); % galvo Y
% % s.IsContinuous = true;

clear all;
close all;
clc;


s.Rate = 100000;
%%
rate = s.Rate;
n_trials = 250;

max_amp = 2.5;
min_amp = 0.5;

max_dur = 2;
min_dur = 1;

galvoXPos = 0;
galvoYPos = 0;

rng(0);
ampRand = rand(n_trials, 1);

rng(1);
durRand = rand(n_trials, 1);

rng(2);
delayRand = rand(n_trials, 1);
laserAmps=[]
laserDurs=[]
for i = 1:n_trials
    % pick random parameters
    laserAmp = min_amp + (max_amp - min_amp)*ampRand(i);
    laserDurS = min_dur + (max_dur - min_dur)*durRand(i);
    rest = 9 * laserDurS;
    delayTimeS = 0.1 + (delayRand(i)*0.5);
    
    disp(['trial ', num2str(i), ', laser ', num2str(laserAmp), ', dur ', num2str(laserDurS)])
    
    trialTimeS = delayTimeS + laserDurS + rest;
%     convert into NI samples
    delayTimeSamps = round(delayTimeS*rate);
    trialTimeSamps = round(trialTimeS*rate);
    
%     create the waveforms for each component
    laser = genLaser(rate, laserAmp, laserDurS, trialTimeSamps, delayTimeSamps, 1);
    galvoX = genGalvo(galvoXPos, trialTimeSamps);
    galvoY = genGalvo(galvoYPos, trialTimeSamps);

    laserAmps = [laserAmps;laserAmp];
    laserDurs = [laserDurs;laserDurS];

%     s.queueOutputData([laser galvoX galvoY]);
%     s.startBackground();
%     s.wait();
%     s.stop();

end
save('rand_inputs.mat',"laserDurs","laserAmps");
%% 
function waveform = genLaser(rate, laserAmp, laserDur, trialTimeSamps, delayTimeSamps, laserFreq)
    laserDurSamps = laserDur * rate;
    waveform = zeros(trialTimeSamps, 1);
    if laserFreq == 0
        waveform(delayTimeSamps:delayTimeSamps+laserDurSamps) = laserAmp; 
    else
        swFreq = 40; % oscillation rate
        t = [1:laserDurSamps+1]/rate;
        raisedcos = laserAmp*(1+cos(pi+swFreq*2*pi*t));
        waveform(delayTimeSamps:delayTimeSamps+laserDurSamps) = raisedcos;
    end
end

function waveform = genGalvo(galvoPos, trialTimeSamps)
    waveform = zeros(trialTimeSamps, 1) + galvoPos;

end