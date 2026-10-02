function onset_m1m2_diagnostic(sessList)
%ONSET_M1M2_DIAGNOSTIC  Are m1/m2's extra 4.4 samples latency, or misalignment?
%
% m1 (2025-01-20) and m2 (2025-02-12) sit ~4.4 samples (126 ms) further from
% their laser onset than every later session (onset_provenance_audit.m). Two
% explanations, with opposite consequences:
%
%   LATENCY    the rig really was slower then. The laser fired late relative to
%              the controller's decision, the cortex responded to the laser, and
%              the data are correct -- the metadata simply timestamps a
%              different event. Nothing to fix beyond documenting it.
%   MISALIGNED the column-2 convention differs for those sessions, so the stored
%              onsets point at the wrong frame and every window in m1/m2 is
%              shifted. Must be corrected before anything is rebuilt.
%
% THE DISCRIMINATING TEST. The cortex responds to the LASER, not to the
% metadata. So realign each trial to its own laser onset and re-average:
%   - if m1/m2's response was already in step with the other sessions and only
%     the metadata was offset, realignment leaves them unchanged and they were
%     mis-timestamped (MISALIGNED is about the metadata, data fine).
%   - if m1/m2's response is late under metadata alignment and snaps into line
%     under laser alignment, the stored onsets are the wrong zero (fix needed).
%   - if they stay late even under laser alignment, the difference is biology or
%     optics in those sessions, not timing at all.
%
% Uses pncDfk (561 cols, onset col 351, -10..+6 s) so there is room to shift.
% READ-ONLY apart from the exported PNG.

if nargin < 1 || isempty(sessList), sessList = {'m1','m2','m9','m12'}; end
mouse  = evalin('base','mouse');
Fs = 35; C0 = 351;                     % pncDfk onset column
win = round(-0.5*Fs) : round(1.5*Fs);  % -0.5 .. +1.5 s around onset (integer samples)
tt  = win / Fs;

figure('Color','w','Position',[80 80 980 420]);
cols = lines(numel(sessList));
ttl = {'Aligned to metadata onset (as stored)', 'Aligned to recorded laser onset'};

for mode = 1:2
    subplot(1,2,mode); hold on;
    for s = 1:numel(sessList)
        M = mouse.(sessList{s}); d = M.d; dk = M.data;
        if ~isfield(dk,'pncDfk') || isempty(dk.pncDfk), continue; end

        % laser onsets from whichever channel carries signal
        best=''; bn=0;
        for c = {'inpVals594','inpVals638','inpVals'}
            if ~isfield(d,c{1}) || isempty(d.(c{1})), continue; end
            v=double(d.(c{1})); n=sum(v(2:end)>0.1 & v(1:end-1)<=0.1);
            if n>bn, bn=n; best=c{1}; end
        end
        v=double(d.(best)); ti=d.inpTime(:);
        up=find(v(2:end)>0.1 & v(1:end-1)<=0.1)+1;
        tL=ti(up); tL=tL([true; diff(tL)>2]);

        % The per-session offset is near-deterministic (IQR 0.02-0.5 samples),
        % so apply ONE median shift per session rather than pairing each
        % pncDfk row to a stimStart -- the row order of pncDfk is the OL-trial
        % order, not the stimStarts order, so per-trial pairing would be wrong.
        t_meta = d.stimStarts(:);
        sg = nan(numel(t_meta),1);
        for j = 1:numel(t_meta)
            [~,ix] = min(abs(tL - t_meta(j)));
            sg(j) = (t_meta(j) - tL(ix)) * Fs;
        end
        shift = 0;
        if mode == 2, shift = round(median(sg,'omitnan')); end
        if ~isfinite(shift), continue; end

        idx = C0 + win - shift;
        if idx(1) < 1 || idx(end) > size(dk.pncDfk,2), continue; end
        acc = dk.pncDfk(:, idx);
        if isempty(acc), continue; end
        m = mean(acc,1,'omitnan');
        m = m - mean(m(tt < -0.2));                     % baseline to pre-onset
        plot(tt, m, 'LineWidth', 1.6, 'Color', cols(s,:), ...
             'DisplayName', sprintf('%s (%s)', sessList{s}, d.td));
    end
    xline(0,'k--','HandleVisibility','off');
    xlabel('time from onset (s)'); ylabel('\DeltaF/F (baselined)');
    title(ttl{mode}); legend('Location','southeast','Box','off'); grid on;
    xlim([tt(1) tt(end)]);
end

out = fullfile(fileparts(mfilename('fullpath')), '..', 'paper', 'images', ...
               'onset_m1m2_diagnostic.png');
exportgraphics(gcf, out, 'Resolution', 200);
fprintf('wrote %s\n', out);
end
