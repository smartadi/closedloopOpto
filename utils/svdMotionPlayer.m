function svdMotionPlayer(U, V, t_svd, mimg, motion, varargin)
% svdMotionPlayer  Play SVD-reconstructed widefield video with a synchronized
%                  motion trace below. Use MATLAB zoom toolbar on the motion
%                  axes to zoom in on any region.
%
% Usage:
%   svdMotionPlayer(U, V, t_svd, mimg, motion)
%   svdMotionPlayer(U, V, t_svd, mimg, motion, 'fps', 15, 't_motion', t_mot)
%
% Inputs:
%   U        [H x W x nSV] or [nPix x nSV]  spatial SVD components
%   V        [nSV x nTime] or [nTime x nSV]  temporal SVD components
%   t_svd    [nTime x 1]   frame timestamps (seconds)
%   mimg     [H x W]       mean image
%   motion   [1 x M]       motion timeseries (resampled internally if needed)
%
% Optional:
%   't_motion'  time vector for motion signal
%   'fps'       playback speed (default 15)
%   'clim'      [lo hi] video color limits (default: auto)

p = inputParser;
addParameter(p, 't_motion', [], @isnumeric);
addParameter(p, 'fps',      15, @isnumeric);
addParameter(p, 'clim',     [], @isnumeric);
parse(p, varargin{:});

fps  = p.Results.fps;
clim = p.Results.clim;

% ---- Normalize U to [nPix x nSV] ----
[H, W] = size(mimg);
if ndims(U) == 3
    nSV  = size(U, 3);
    Umat = reshape(U, H*W, nSV);
else
    Umat = double(U);
    nSV  = size(Umat, 2);
end

% ---- Normalize V to [nSV x nTime] ----
if ndims(V) > 2
    V = reshape(V, nSV, []);
elseif size(V, 1) ~= nSV
    V = V';
end
V = double(V);

% ---- Time and motion ----
t_svd  = double(t_svd(:)');
nTime  = size(V, 2);
motion = double(motion(:)');

if isempty(p.Results.t_motion)
    t_motion = linspace(t_svd(1), t_svd(end), numel(motion));
else
    t_motion = double(p.Results.t_motion(:)');
end
if numel(motion) ~= nTime
    motion = interp1(t_motion, motion, t_svd, 'linear', 'extrap');
end

mimg_flat = double(mimg(:));

% ---- Auto color limits ----
frame1 = reshape(mimg_flat + Umat * V(:,1), H, W);
if isempty(clim)
    clim = [min(frame1(:)), max(frame1(:))];
end

% =========================================================
% State — declared BEFORE any nested function call
% =========================================================
state.frame   = 1;
state.playing = false;
state.alive   = true;
tmr           = [];   % pre-declare so closures see it before timer is created

% =========================================================
% Figure layout  (video top, motion trace bottom)
% =========================================================
fig = figure('Name', 'SVD Motion Player', 'NumberTitle', 'off', ...
             'Color', [0.12 0.12 0.12], 'Units', 'normalized', ...
             'Position', [0.05 0.05 0.6 0.88], ...
             'KeyPressFcn',     @keyHandler, ...
             'CloseRequestFcn', @onClose);

ax_vid = subplot(3, 1, [1 2], 'Parent', fig);
ax_mot = subplot(3, 1, 3,     'Parent', fig);
styleAx(ax_vid);
styleAx(ax_mot);

% Video pane
him = imagesc(ax_vid, frame1);
ax_vid.CLim = clim;
colormap(ax_vid, gray);
axis(ax_vid, 'image', 'off');
htitle = title(ax_vid, sprintf('t = %.3f s  [1 / %d]', t_svd(1), nTime), ...
               'Color', 'w', 'FontSize', 10);

% Motion trace (full session; use MATLAB zoom toolbar to zoom in)
plot(ax_mot, t_svd, motion, 'Color', [0.7 0.85 1], 'LineWidth', 0.9);
hold(ax_mot, 'on');
hcur = xline(ax_mot, t_svd(1), 'r-', 'LineWidth', 1.5);
xlim(ax_mot, [t_svd(1), t_svd(end)]);
ylabel(ax_mot, 'Motion', 'Color', 'w', 'FontSize', 9);
xlabel(ax_mot, 'Time (s)', 'Color', 'w', 'FontSize', 9);
title(ax_mot, 'Motion  |  use scroll/zoom toolbar to zoom  |  arrows or slider to scrub', ...
      'Color', [0.6 0.6 0.6], 'FontSize', 8);

% Enable zoom on motion axis only (toolbar zoom, x-axis constrained)
z = zoom(fig);
setAllowAxesZoom(z, ax_vid, false);   % disable zoom on video
setAllowAxesZoom(z, ax_mot, true);

% =========================================================
% Controls
% =========================================================
ctrlBg = [0.18 0.18 0.18];

uicontrol('Style', 'text', 'String', 'Frame', ...
    'Units', 'normalized', 'Position', [0.01 0.012 0.06 0.02], ...
    'BackgroundColor', ctrlBg, 'ForegroundColor', 'w', 'FontSize', 8);
sld_frame = uicontrol('Style', 'slider', ...
    'Units', 'normalized', 'Position', [0.08 0.012 0.60 0.022], ...
    'Min', 1, 'Max', nTime, 'Value', 1, ...
    'SliderStep', [1/(nTime-1), 50/(nTime-1)], ...
    'Callback', @frameScrub);

uicontrol('Style', 'pushbutton', 'String', 'Play/Pause [space]', ...
    'Units', 'normalized', 'Position', [0.72 0.010 0.14 0.028], ...
    'Callback', @togglePlay, 'FontSize', 8);
uicontrol('Style', 'pushbutton', 'String', 'Reset', ...
    'Units', 'normalized', 'Position', [0.87 0.010 0.06 0.028], ...
    'Callback', @resetPlayer, 'FontSize', 8);

% =========================================================
% Timer — created last so variable is visible to closures
% =========================================================
tmr = timer('ExecutionMode', 'fixedRate', ...
            'Period',        max(0.01, 1/fps), ...
            'TimerFcn',      @timerStep, ...
            'ErrorFcn',      @(~,~) stopTimer());

% =========================================================
% Nested callbacks
% =========================================================
    function timerStep(~, ~)
        if ~state.alive || ~ishandle(fig)
            stopTimer(); return;
        end
        if state.frame >= nTime
            stopTimer(); state.playing = false; return;
        end
        state.frame = state.frame + 1;
        renderFrame(state.frame);
    end

    function togglePlay(~, ~)
        if state.playing
            stopTimer();
        else
            if state.frame >= nTime, state.frame = 1; end
            state.playing = true;
            start(tmr);
        end
    end

    function resetPlayer(~, ~)
        stopTimer();
        state.frame = 1;
        renderFrame(1);
    end

    function frameScrub(src, ~)
        stopTimer();
        state.frame = round(src.Value);
        renderFrame(state.frame);
    end

    function keyHandler(~, evt)
        switch evt.Key
            case 'space',      togglePlay([], []);
            case 'rightarrow', stopTimer(); state.frame = min(nTime, state.frame+1); renderFrame(state.frame);
            case 'leftarrow',  stopTimer(); state.frame = max(1,     state.frame-1); renderFrame(state.frame);
        end
    end

    function onClose(~, ~)
        state.alive = false;
        stopTimer();
        delete(fig);
    end

    function renderFrame(idx)
        if ~ishandle(fig), return; end
        frame = reshape(mimg_flat + Umat * V(:, idx), H, W);
        him.CData     = frame;
        tc            = t_svd(idx);
        htitle.String = sprintf('t = %.3f s  [%d / %d]', tc, idx, nTime);
        hcur.Value    = tc;
        sld_frame.Value = idx;
        drawnow limitrate;
    end

    function stopTimer()
        state.playing = false;
        if ~isempty(tmr) && isvalid(tmr) && strcmp(tmr.Running, 'on')
            stop(tmr);
        end
    end

end % svdMotionPlayer

% =========================================================
function styleAx(ax)
    ax.Color    = [0.08 0.08 0.08];
    ax.XColor   = [0.7  0.7  0.7 ];
    ax.YColor   = [0.7  0.7  0.7 ];
    ax.FontSize = 8;
end
