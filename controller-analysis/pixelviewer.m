% pixelviewer.m — launch pixelTuningCurveViewerSVD for a controller session
%
% Requires load_sessions.m to have run (mouse, fields in workspace).
% Set selField to the session index you want to inspect.
%
% Conditions: 'OL' (no-controller) and 'CL' (with-controller) trials.
% calcWin: [-1 4] s relative to stim onset.

%% -- config --
selField = 10;          % session index into fields{}
calcWin  = [-1 4];      % peri-event window (s)

% Extra session to load (set mn/td/en, leave empty to skip)
extra.mn = 'AL_0033';
extra.td = '2026-02-24';
extra.en = 1;




extra.mn = 'AL_0041';
extra.td = '2025-02-21';
extra.en = 4;
%% -- load extra session if needed --
extraKey = sprintf('extra_%s_%s_%d', extra.mn, extra.td, extra.en);
extraPath = fullfile('data', sprintf('%sctrl%s%s%d.mat', extra.mn, extra.td(6:7), extra.td(9:10), extra.en));
if exist(extraPath, 'file')
    tmp = load(extraPath);
    extra.d    = tmp.d;
    extra.data = tmp.data;
    fprintf('Loaded extra session: %s %s exp%d\n', extra.mn, extra.td, extra.en);
else
    extra.d    = initialize_data(extra.mn, extra.en, extra.td);
    extra.d.ref = -5;
    extra.data = getpixel_dFoF(extra.d, 0, extra.d.params.pixel, 1);
    extra.data = controllerData(extra.data, extra.d, []);
    fprintf('Initialised extra session: %s %s exp%d\n', extra.mn, extra.td, extra.en);
end

%% -- extract session --
d    = mouse.(fields{selField}).d;
data = mouse.(fields{selField}).data;

U = d.svd.U;          % Ypix x Xpix x nSV
V = d.svd.V;          % nSV  x nTimePoints
t = d.timeBlue(:)';   % 1    x nTimePoints

%% -- build event list (OL then CL) --
nc_times = d.stimStarts(data.nc(:))';   % OL trial onsets
wc_times = d.stimStarts(data.wc(:))';   % CL trial onsets

eventTimes  = [nc_times,  wc_times];
eventLabels = [repmat({'OL'}, 1, numel(nc_times)), ...
               repmat({'CL'}, 1, numel(wc_times))];

eventTimes  = [nc_times];
eventLabels = [repmat({'OL'}, 1, numel(nc_times))];




%% -- launch viewer --
fprintf('Session %s  %s  exp%d  |  %d OL  %d CL trials\n', ...
    mouse.(fields{selField}).mn, mouse.(fields{selField}).td, ...
    mouse.(fields{selField}).en, numel(nc_times), numel(wc_times));

pixelTuningCurveViewerSVD(U, V, t, eventTimes, eventLabels, calcWin);




