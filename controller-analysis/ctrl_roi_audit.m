%% ctrl_roi_audit.m   [ROIAUD]  -- is each session's ROI geometry actually right?
%
% READ-ONLY. Runs off the caches on disk (cp_roi2_ctrl_*.mat + ctrl_ols_spont_*.mat), so it
% needs no session load and no SVD -- press Run and read the verdicts.
%
% WHY THIS EXISTS (2026-08-12). AL_0033_0212_e2 shipped a midline drawn HORIZONTALLY:
% (row 282, col 158) -> (row 282, col 352). cp_roi_masks bisects by the signed cross product of
% the midline direction, so that midline split the brain ANTERIOR/POSTERIOR and its "contra"
% mask was the front half of the whole brain -- ipsi-hemisphere pixels included. The stim-blind
% predictor was therefore partly predicting the site from its own hemisphere, and it scored
% held-out R^2 = 0.855, one of only three sessions clearing the floor. Every number downstream
% looked healthy. Nothing numeric could catch it; it took drawing the brain.
%
% So the geometry gets audited explicitly, on five independent checks:
%   MIDLINE ANGLE   the midline must run along ROWS (native), i.e. separate LEFT from RIGHT.
%                   Reported as degrees off that axis; > 30 deg is the 0212 failure mode.
%   SITE IN IPSI    the primary pixel must land inside ipsi_mask. It defines which side is
%                   ipsi, so if it falls outside the brain mask entirely the split is untrusted.
%   GRID IN CONTRA  every contra-grid pixel must be inside contra_mask. Anything less means
%                   the predictor reads pixels the mask calls ipsi.
%   BALANCE         nIpsi/nContra. Far from 1 means the midline is off-centre, which does not
%                   invalidate the split but does bias how much cortex each side gets.
%   SHARED GEOMETRY byte-identical outline+midline to another session = donor-seeded from a
%                   different day's field of view, i.e. never drawn on this session's image.
%
% A session can fail the angle check and still look perfect in every downstream number. That is
% the entire point.
%
% SECTIONS: [ROIAUD-CFG] [ROIAUD-CHECK] [ROIAUD-SHEET] [ROIAUD-REPORT]

%% [ROIAUD-CFG] ------------------------------------------------------------------
RA_ANG_TOL  = 30;      % deg off the row axis before the midline is called rotated
RA_BAL_TOL  = 1.35;    % nIpsi/nContra (or its reciprocal) above this is flagged lopsided
RA_SHEET    = true;    % draw the all-sessions contact sheet
RA_EXPORT   = true;

ra_here = fileparts(mfilename('fullpath'));
if isempty(ra_here) || contains(ra_here,tempdir,'IgnoreCase',true) || contains(ra_here,'Editor_','IgnoreCase',true)
    ra_here = fullfile(pwd,'controller-analysis');  if ~exist(ra_here,'dir'); ra_here = pwd; end
end
ra_dataDir = fullfile(ra_here,'data');
ra_outDir  = fullfile(ra_here,'..','paper','images','predictor_saga','roi_audit');
if RA_EXPORT && ~exist(ra_outDir,'dir'); mkdir(ra_outDir); end

% Session set = the union of what has an ROI and what has a Stage-1 fit. A session with one and
% not the other is itself worth seeing, so neither list is allowed to hide the other.
ra_r = dir(fullfile(ra_dataDir,'cp_roi2_ctrl_*.mat'));
ra_s = dir(fullfile(ra_dataDir,'ctrl_ols_spont_*.mat'));
ra_tags = unique([ erase(erase({ra_r.name},'cp_roi2_ctrl_'),'.mat'), ...
                   erase(erase({ra_s.name},'ctrl_ols_spont_'),'.mat') ]);
assert(~isempty(ra_tags), '[ROIAUD] no ROI or Stage-1 caches in %s', ra_dataDir);
fprintf('\n[ROIAUD] %d sessions with geometry on disk\n', numel(ra_tags));

%% [ROIAUD-CHECK] ----------------------------------------------------------------
RA = struct([]);
for ra_i = 1:numel(ra_tags)
    tg = ra_tags{ra_i};
    A = struct('tag',tg,'hasROI',false,'hasS1',false,'ang',NaN,'siteIn',NaN,'gridIn',NaN, ...
               'bal',NaN,'nI',NaN,'nC',NaN,'geokey','','shared',false,'verdict','','why',{{}});

    ra_rf = fullfile(ra_dataDir, sprintf('cp_roi2_ctrl_%s.mat', tg));
    if exist(ra_rf,'file')
        A.hasROI = true;
        G = load(ra_rf,'bx','by','mx','my');
        % bx/mx are native ROW, by/my native COLUMN (cp_roi_masks stores native row/col).
        % A left/right midline therefore runs along ROWS: large d_row, near-zero d_col.
        ra_dr = G.mx(2)-G.mx(1);  ra_dc = G.my(2)-G.my(1);
        A.ang = atan2d(abs(ra_dc), abs(ra_dr));
        A.geokey = sprintf('%d|%.4f|%.4f|%s|%s', numel(G.bx), sum(G.bx), sum(G.by), ...
                           mat2str(round(G.mx(:).',3)), mat2str(round(G.my(:).',3)));
        A.G = G;
    end

    ra_sf = fullfile(ra_dataDir, sprintf('ctrl_ols_spont_%s.mat', tg));
    if exist(ra_sf,'file')
        A.hasS1 = true;
        S = load(ra_sf,'ipsi_mask','contra_mask','px_prim','py_prim','grR','grC');
        A.nI = nnz(S.ipsi_mask);  A.nC = nnz(S.contra_mask);
        A.bal = A.nI / max(A.nC,1);
        % px_prim = ROW, py_prim = COLUMN (ctrl_ols_ol_stimblind passes them to
        % cp_orient_fwd(Tor,row,col) in that order).
        if S.px_prim >= 1 && S.px_prim <= size(S.ipsi_mask,1) && ...
           S.py_prim >= 1 && S.py_prim <= size(S.ipsi_mask,2)
            A.siteIn = double(S.ipsi_mask(round(S.px_prim), round(S.py_prim)));
        else
            A.siteIn = 0;
        end
        ra_lin = sub2ind(size(S.contra_mask), round(S.grR), round(S.grC));
        A.gridIn = mean(S.contra_mask(ra_lin));
        A.S = S;
    end
    if isempty(RA); RA = A; else; RA(end+1) = A; end %#ok<SAGROW>
end

% donor-seeded geometry: identical points cannot both have been clicked on their own mean image
ra_keys = {RA.geokey};
for ra_i = 1:numel(RA)
    if ~isempty(RA(ra_i).geokey) && nnz(strcmp(ra_keys, RA(ra_i).geokey)) > 1
        RA(ra_i).shared = true;
    end
end

% verdicts
for ra_i = 1:numel(RA)
    w = {};
    if ~RA(ra_i).hasROI;                      w{end+1} = 'no ROI drawn'; end %#ok<SAGROW>
    if ~RA(ra_i).hasS1;                       w{end+1} = 'no Stage-1 fit'; end %#ok<SAGROW>
    if RA(ra_i).shared;                       w{end+1} = 'SHARED geometry (another day''s FOV)'; end %#ok<SAGROW>
    if RA(ra_i).ang > RA_ANG_TOL;             w{end+1} = sprintf('midline %.0f deg off the row axis -- splits A/P, not L/R', RA(ra_i).ang); end %#ok<SAGROW>
    if RA(ra_i).siteIn == 0;                  w{end+1} = 'site is NOT inside ipsi_mask'; end %#ok<SAGROW>
    if RA(ra_i).gridIn < 1 && ~isnan(RA(ra_i).gridIn)
                                              w{end+1} = sprintf('%.1f%% of the grid is outside contra_mask', 100*(1-RA(ra_i).gridIn)); end %#ok<SAGROW>
    ra_b = RA(ra_i).bal;
    if ~isnan(ra_b) && max(ra_b, 1/max(ra_b,eps)) > RA_BAL_TOL
                                              w{end+1} = sprintf('lopsided masks (ipsi/contra = %.2f)', ra_b); end %#ok<SAGROW>
    RA(ra_i).why = w;
    if isempty(w); RA(ra_i).verdict = 'OK'; else; RA(ra_i).verdict = 'REDRAW'; end
end

%% [ROIAUD-SHEET] contact sheet: every session's anatomy in one picture -----------
% The numbers above are necessary but not sufficient -- a midline can pass every threshold and
% still sit visibly wrong on the anatomy. Look at the sheet before deciding what to redraw.
if RA_SHEET
    ra_n  = numel(RA);
    ra_nc = 5;  ra_nr = ceil(ra_n/ra_nc);
    figA = figure('Color','w','Position',[30 40 1750 340*ra_nr]);
    tlA = tiledlayout(figA, ra_nr, ra_nc, 'TileSpacing','compact','Padding','compact');
    for ra_i = 1:ra_n
        ax = nexttile(tlA, ra_i); hold(ax,'on');
        A = RA(ra_i);
        if A.hasS1
            bg = ones([size(A.S.ipsi_mask) 3]);
            bg = local_paint(bg, A.S.contra_mask, [0.87 0.90 0.95]);   % predictor INPUT half
            bg = local_paint(bg, A.S.ipsi_mask,   [0.96 0.93 0.88]);   % half holding the site
            image(ax, bg);
            plot(ax, A.S.grC, A.S.grR, '.', 'Color',[0.45 0.55 0.75], 'MarkerSize',3);
            plot(ax, A.S.py_prim, A.S.px_prim, 'kp','MarkerSize',12,'MarkerFaceColor',[1 1 0.2]);
            ra_bb = local_bb(A.S.ipsi_mask | A.S.contra_mask, 15);
            xlim(ax, ra_bb(3:4));  ylim(ax, ra_bb(1:2));
        end
        if A.hasROI
            plot(ax, A.G.by, A.G.bx, '-', 'Color',[0.5 0.5 0.5], 'LineWidth',0.8);
            plot(ax, A.G.my, A.G.mx, '--','Color',[0.85 0.10 0.10], 'LineWidth',1.8);
        end
        set(ax,'YDir','reverse'); axis(ax,'image'); set(ax,'XTick',[],'YTick',[]);
        if strcmp(A.verdict,'OK'); ra_col = [0 0.45 0]; else; ra_col = [0.80 0 0]; end
        title(ax, sprintf('%s\n%s  (%.0f\\circ)', strrep(A.tag,'_','\_'), A.verdict, A.ang), ...
            'Color', ra_col, 'FontSize',8);
    end
    title(tlA, sprintf('[ROIAUD] red dashed = midline. It must run TOP-TO-BOTTOM (%d\\circ tol).', RA_ANG_TOL));
    if RA_EXPORT
        exportgraphics(figA, fullfile(ra_outDir,'ctrl_roi_audit_sheet.png'), 'Resolution',300);
    end
end

%% [ROIAUD-REPORT] ---------------------------------------------------------------
fprintf('\n  %-20s %-8s %6s %6s %7s %7s  %s\n', ...
    'session','verdict','ang','siteIn','gridIn','bal','why');
for ra_i = 1:numel(RA)
    A = RA(ra_i);
    fprintf('  %-20s %-8s %5.0f%s %6.0f %6.0f%% %7.2f  %s\n', A.tag, A.verdict, A.ang, char(176), ...
        A.siteIn, 100*A.gridIn, A.bal, strjoin(A.why,'; '));
end
ra_bad = find(~strcmp({RA.verdict},'OK'));
fprintf('\n[ROIAUD] %d/%d sessions need attention\n', numel(ra_bad), numel(RA));
if ~isempty(ra_bad)
    fprintf('  redraw list: %s\n', strjoin({RA(ra_bad).tag}, ', '));
    fprintf(['  -> load_sessions.m, then set XD.redraw = ''all'' and XD.sess to those sessions'' ' ...
             'indices in ctrl_roi_draw_all.m\n']);
end
save(fullfile(ra_dataDir,'ctrl_roi_audit.mat'), 'RA');
if RA_EXPORT; fprintf('[ROIAUD] sheet -> %s\n', ra_outDir); end

%% ---- local functions (must sit at EOF in a script) ---------------------------
function bg = local_paint(bg, mask, rgb)
for c = 1:3
    ch = bg(:,:,c);  ch(mask) = rgb(c);  bg(:,:,c) = ch;
end
end

function bb = local_bb(mask, pad)
[rr,cc] = find(mask);
bb = [max(1,min(rr)-pad), max(rr)+pad, max(1,min(cc)-pad), max(cc)+pad];
end
