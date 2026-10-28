% CTRL_APPLY_ONSET_FIX  One-off, idempotent: bring every controller cache up to the 2026-10-27 fixes.
%
% For each session: load its cache, apply utils/ctrl_onset_fix.m (corrected onsets m1-m8, AL_0048
% dF/F alignment), and re-run controllerData, which now also reads the laser channel that fired
% (utils/ctrl_laser_cmd.m; AL_0048 = 638 nm). Sessions with nothing to change are left untouched.
% Each changed cache is copied to data/_pre_onset_fix/ before it is overwritten.
% Run from brain_paper/:  ctrl_apply_onset_fix
r_lean = 1; load_sessions;            % registry only (fields, mn/td/en, trials, pathCtrl)
bak = fullfile('data', '_pre_onset_fix');
if ~exist(bak, 'dir'), mkdir(bak); end
for k = 1:numel(fields)
    f = fields{k};
    p = mouse.(f).pathCtrl;
    S = load(p);
    [d, data, ofx] = ctrl_onset_fix(S.d, S.data, f);
    [~, ~, chan] = ctrl_laser_cmd(d);
    if ~ofx.changed && strcmp(chan, 'inpVals')
        fprintf('[ONSETFIX] %-4s unchanged (%s)\n', f, chan);
        continue
    end
    data = controllerData(data, d, mouse.(f).trials);
    d = ctrl_cache_stamp(d, data, 'onset fix 2026-10-27');
    [~, nm, ext] = fileparts(p);
    if ~exist(fullfile(bak, [nm ext]), 'file'), copyfile(p, fullfile(bak, [nm ext])); end
    save(p, 'd', 'data', '-v7.3');
    fprintf('[ONSETFIX] %-4s shifted %3d onsets, dFk lead %2d, laser %s -> saved\n', ...
        f, ofx.n_shifted, ofx.dfk_lead, chan);
    clear S d data
end
