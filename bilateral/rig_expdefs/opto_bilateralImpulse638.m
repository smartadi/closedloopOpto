function opto_bilateralImpulse638(t, evts, p, vs, inputs, outputs, audio, varargin)
% opto_bilateralImpulse638  Bilateral single-frame impulse dose-response (638 nm).
% opto_pulses638 with the option vectors edited: single widefield-frame impulse,
% 6 amps, two mirrored spots (left/right hemisphere), numRepeats trials each.
% Side convention (load_bilateral.m): galvoX<0 = left/excit, galvoX>0 = right/inhib.

%% Opto laser
laserDelay = p.laserDur.map(@getDelay);     % fixed pre-onset delay: galvo settle + baseline
laserPostDelay = p.laserDur.map(@getITI);   % randomized gap after impulse (see getITI)
trialLen = p.laserDur + laserDelay + laserPostDelay;

thisTrialParams = mapn( ...
    p.laserAmp, p.laserDur, laserDelay, p.galvoXPos, p.galvoYPos, laserPostDelay, ...
    @(amp, dur, delay, x, y, endDelay) struct( ...
        'amplitude', amp, ...
        'duration', dur, ...
        'delay', delay, ...
        'galvoX', x, ...
        'galvoY', y, ...
        'endDelay', endDelay));
outputs.opto638 = thisTrialParams.at(evts.newTrial);

%% misc
trialEnd = evts.newTrial.delay(trialLen);
evts.endTrial = trialEnd;

try
    numRepeats = 100;                        % trials per condition

    laserAmpOpts = [0 0.5 1.0 1.5];          % 4 amps (0 = sham) -- CALIBRATE per opsin
    laserDurOpts = [1/35];                   % single widefield frame (~28.6 ms @ 35 Hz)
    galvoXPosOpts = [-2.5 2.5];              % two spots: left (x<0), right (x>0) -- SET
    galvoYPosOpts = [-3.0];                  % shared Y (both spots same AP); keep single-
                                             % valued or CombVec makes an X-by-Y grid

    expOpts = CombVec(laserAmpOpts, laserDurOpts, galvoXPosOpts, galvoYPosOpts);
    p.laserAmp = expOpts(1, :);
    p.laserDur = expOpts(2, :);
    p.galvoXPos = expOpts(3, :);
    p.galvoYPos = expOpts(4, :);

    p.numRepeats = repmat(numRepeats, 1, size(expOpts, 2));

catch
end

end

function thisDelay = getDelay(dur)
    % Pre-onset delay: fixed so the galvo settles at the new spot before the
    % impulse (consecutive trials can jump between the left and right spots).
    thisDelay = 0.5;
end

function thisDelay = getITI(dur)
    % Gap after each impulse: 3 s + up to 2 s jitter (3-5 s) so impulses are not
    % periodic and the response fully decays before the next trial.
    thisDelay = 3 + (rand*2);
end
