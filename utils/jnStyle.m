function S = jnStyle()
% JNSTYLE  Journal of Neuroscience figure conventions (see paper/FIGURE_RULEBOOK.md).
% One source of truth for the jn* figure system: fonts, line weights, widths, colours.
S.font = 'Arial';

% ---- font sizes (pt, final print size; min 5, <=3 distinct sizes per figure) ----
S.fs_letter = 8;        % panel letter (bold) -- usually added in Illustrator
S.fs_label  = 7;        % axis label / panel title (bold)
S.fs_tick   = 6;        % tick labels (regular)
S.fs_annot  = 6;        % in-panel annotation / legend
S.fs_min    = 5;
S.fw_label  = 'bold';
S.fw_tick   = 'normal';

% ---- line weights (pt) ----
S.lw_axis = 0.5;        % axes / box
S.lw_ref  = 0.75;       % reference / grid lines
S.lw_mean = 1.0;        % mean / primary trace (was 1.5)
S.lw_fit  = 1.0;        % model fit
S.lw_ind  = 0.4;        % individual trials
S.lw_err  = 0.5;        % error bars

% ---- figure widths (cm), JNeurosci hard maxima ----
S.W_single  = 8.5;
S.W_onehalf = 11.6;
S.W_double  = 17.6;
S.H_max     = 22.0;

% ---- default panel geometry ----
S.rowH = 3.3;           % default row height (cm)
S.gap  = 0.5;           % inter-panel gap for grid width computation (cm)

% ---- condition colours (project-locked) + misc ----
S.col_ol = [1 0 0];
S.col_cl = [0 0.40 0.85];
S.marker = 3;
S.itemtoken = [6 6];    % legend ItemTokenSize
end
