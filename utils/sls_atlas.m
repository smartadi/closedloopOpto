function A = sls_atlas(varargin)
% SLS_ATLAS  Dorsal cortex outlines (Allen CCF) and the lab's 52-target opto grid, in mm
% from bregma. MATLAB port of steinmetzlab_style.atlas; reads that package's data files.
%
%   A = sls_atlas()                      % Allen CCF nominal bregma (AP 5.40 mm in atlas)
%   A = sls_atlas('BregmaAP', 5.20)      % match other work (LiMatveevEtAl2027 used 5.20)
%
%   A.outlines   cell of (n x 2) [ML AP] mm; ML positive right, AP positive anterior
%   A.grid       (52 x 2) [ML AP] mm stimulation targets (1 mm lattice trimmed to cortex)
%   A.bregma_atlas_mm  [5.70 AP] bregma in atlas mm
%
% Outlines are area boundaries seen from above, from the cortex-lab allenCCF repo.
% Bregma varies about 0.2 mm in AP between subjects: treat any overlay as accurate to
% about +/-0.2 mm in AP. Never draw an outline by hand. To draw: SLS_DRAW_CORTEX.
%
% See also SLS_DRAW_CORTEX, SLS_ROOT.

p = inputParser;
p.addParameter('BregmaAP', 5.40);
p.parse(varargin{:});
bAP = p.Results.BregmaAP;
bML = 5.70;

persistent raw grid
if isempty(raw)
    d = fullfile(sls_root(), 'src', 'steinmetzlab_style', 'data');
    z = read_npz(fullfile(d, 'dorsal_cortex_outlines.npz'));
    xy = z.xy_atlas_units / double(z.units_per_mm);
    len = double(z.segment_lengths(:));
    raw = mat2cell(xy, len, 2);
    grid = read_npy(fullfile(d, 'opto_grid_mm.npy'));
end

% atlas AP increases posteriorly; flip so anterior is positive
A.outlines = cellfun(@(s) [s(:,1) - bML, bAP - s(:,2)], raw, 'UniformOutput', false);
A.grid = grid;
A.bregma_atlas_mm = [bML bAP];
end

% ---------------------------------------------------------------------------------------
function S = read_npz(f)
% An .npz is a zip of .npy files; unpack to a temp folder and read each.
% (No onCleanup: its destructors crash MATLAB under the MCP bridge; clean up explicitly.)
tmp = tempname; mkdir(tmp);
try
    files = unzip(f, tmp);
    S = struct();
    for k = 1:numel(files)
        [~, nm] = fileparts(files{k});
        S.(matlab.lang.makeValidName(nm)) = read_npy(files{k});
    end
catch err
    rmdir(tmp, 's');
    rethrow(err);
end
rmdir(tmp, 's');
end

function x = read_npy(f)
% Minimal .npy reader: little-endian float64/float32/int64/int32, C or Fortran order,
% any shape including 0-d. Enough for the style package's data files.
fid = fopen(f, 'r', 'l');
try
    x = read_npy_body(fid, f);
catch err
    fclose(fid);
    rethrow(err);
end
fclose(fid);
end

function x = read_npy_body(fid, f)
magic = fread(fid, 6, 'uint8=>char')';
assert(strcmp(magic(2:6), 'NUMPY'), 'sls_atlas:npy', '%s is not a .npy file', f);
ver = fread(fid, 2, 'uint8');
if ver(1) == 1, hlen = fread(fid, 1, 'uint16'); else, hlen = fread(fid, 1, 'uint32'); end
hdr = fread(fid, hlen, 'uint8=>char')';
descr = regexp(hdr, '''descr''\s*:\s*''([^'']+)''', 'tokens', 'once'); descr = descr{1};
fort = ~isempty(regexp(hdr, '''fortran_order''\s*:\s*True', 'once'));
shp = regexp(hdr, '''shape''\s*:\s*\(([^)]*)\)', 'tokens', 'once');
dims = str2double(strsplit(strtrim(shp{1}), ','));
dims = dims(~isnan(dims));
switch descr
    case '<f8', prec = 'float64';
    case '<f4', prec = 'float32';
    case '<i8', prec = 'int64';
    case '<i4', prec = 'int32';
    otherwise, error('sls_atlas:npy', 'Unsupported dtype %s in %s', descr, f);
end
n = prod(dims);                       % prod([]) = 1 for a 0-d scalar
x = fread(fid, n, [prec '=>' prec]);
if isempty(dims)
    return                            % scalar
elseif isscalar(dims)
    x = x(:);
elseif fort
    x = reshape(x, dims);
else
    x = permute(reshape(x, fliplr(dims)), numel(dims):-1:1);
end
x = double(x);
end
