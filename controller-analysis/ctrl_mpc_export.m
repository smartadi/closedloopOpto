function ctrl_mpc_export(fig, path)
%CTRL_MPC_EXPORT  Export for the supplementary MPC panels (Fig S-MPC, locked 2026-10-07).
%   Always writes the working PNG (paper/images/supp_mpc/*.png). With the global PAPER_FINAL on,
%   ALSO writes the vector PDF next to it; paperExport -> paper_final_mirror then drops the jn-style
%   copy into paper/figures_final/panels/supp_mpc/ iff the .pdf basename is in MANIFEST.txt.
%   The PNG goes first because the mirror's jnAxesAll pass restyles the figure in place.
global PAPER_FINAL                                                   %#ok<GVMIS>
paperExport(fig, path);
if ~isempty(PAPER_FINAL) && PAPER_FINAL
    paperExport(fig, regexprep(char(path), '\.png$', '.pdf'));
end
end
