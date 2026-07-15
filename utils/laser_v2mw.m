function [mW, info] = laser_v2mw(V, sessionDate, wavelength, calibDir)
% LASER_V2MW  Convert a laser modulation command (Volts) to power (mW).
%
%   mW = laser_v2mw(V, sessionDate)                    % 638 nm, default rig calib dir
%   mW = laser_v2mw(V, sessionDate, 594)
%   [mW, info] = laser_v2mw(V, '2026-07-14', 638, calibDir)
%
% Picks the rig calibration file whose date is the NEWEST one that does not
% postdate sessionDate, i.e. the calibration in force when the session ran.
% Undated files (laserModCalib638.mat) are ignored: they are a rolling copy of
% the latest calibration and are wrong for any earlier session.
%
% The calibration stores a measured curve (cmdVals in Volts -> mWmed in mW) plus
% a linear fit (calibSlope/calibIntercept). We interpolate the measured curve
% rather than use the fit: the fit returns negative power near 0 V because the
% laser has a turn-on toe it cannot capture (R2 ~ 0.998, but the residual sits
% exactly in the low-command range the sine reference spends most of its time in).
% Commands outside the calibrated range are clamped to its endpoints.
%
% info fields: .file .date .cmdVals .mWmed .calibSlope .calibIntercept

if nargin < 3 || isempty(wavelength); wavelength = 638; end
if nargin < 4 || isempty(calibDir)
    calibDir = '\\sahale.biostr.washington.edu\data\Code\Rigging\optoGalvo\calib\laserModCalib';
end

if isnumeric(sessionDate); sessionDate = datestr(sessionDate, 'yyyy-mm-dd'); end
sessNum = datenum(sessionDate, 'yyyy-mm-dd');

pat = sprintf('laserModCalib%d_*.mat', wavelength);
dd  = dir(fullfile(calibDir, pat));
if isempty(dd)
    error('laser_v2mw:noCalib', 'No %s files found in %s', pat, calibDir);
end

% Date comes from the filename, not the file's mtime (files get touched/copied).
tok  = regexp({dd.name}, '_(\d{4}-\d{2}-\d{2})\.mat$', 'tokens', 'once');
ok   = ~cellfun(@isempty, tok);
dd   = dd(ok);
cNum = cellfun(@(t) datenum(t{1}, 'yyyy-mm-dd'), tok(ok));

elig = find(cNum <= sessNum);
if isempty(elig)
    error('laser_v2mw:noPrior', ...
        'No %d nm calibration on or before %s (earliest is %s).', ...
        wavelength, sessionDate, datestr(min(cNum), 'yyyy-mm-dd'));
end
[~, jj] = max(cNum(elig));
pick    = elig(jj);

S = load(fullfile(calibDir, dd(pick).name));
c = S.cmdVals(:);
m = S.mWmed(:);

[c, iu] = unique(c, 'stable');
m = m(iu);
[c, is] = sort(c);
m = m(is);

mW = interp1(c, m, min(max(V, c(1)), c(end)), 'linear');
mW = reshape(mW, size(V));

if nargout > 1
    info = struct('file', fullfile(calibDir, dd(pick).name), ...
                  'date', datestr(cNum(pick), 'yyyy-mm-dd'), ...
                  'cmdVals', c, 'mWmed', m, ...
                  'calibSlope', S.calibSlope, 'calibIntercept', S.calibIntercept);
end
end
