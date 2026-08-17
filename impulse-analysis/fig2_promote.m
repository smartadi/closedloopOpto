%FIG2_PROMOTE  Copy the staged Fig-2 panels into paper/images/figure2, all or nothing.
%
% The staging step exists because Illustrator and Acrobat hold the panel PDFs open, and a
% mid-run "permission denied" from exportgraphics leaves half the panel set rebuilt and half
% stale -- which assembly cannot tell apart. So the build writes to paper/explore/figure2_build
% and this promotes in one move, only after checking that EVERY target is writable.
%
% Usage:  close Illustrator + Acrobat, then  fig2_promote

root  = fileparts(fileparts(mfilename('fullpath')));
stage = fullfile(root,'paper','explore','figure2_build','images','figure2');
dest  = fullfile(root,'paper','images','figure2');

d = dir(fullfile(stage,'*.pdf'));
assert(~isempty(d), '[PROMOTE] nothing staged in %s', stage);

% ---- pre-flight: every target must be writable BEFORE anything is copied ------------------
blocked = {};
for i = 1:numel(d)
    t = fullfile(dest, d(i).name);
    if exist(t,'file')
        fid = fopen(t,'a');
        if fid < 0, blocked{end+1} = d(i).name; else, fclose(fid); end %#ok<AGROW>
    end
end
if ~isempty(blocked)
    fprintf(2, ['[PROMOTE] ABORTED -- %d target file(s) are locked by another program\n' ...
                '          (Illustrator/Acrobat). Close them and re-run. Nothing was copied.\n'], ...
            numel(blocked));
    fprintf(2, '          %s\n', strjoin(blocked, ', '));
    return
end

for i = 1:numel(d)
    copyfile(fullfile(stage, d(i).name), fullfile(dest, d(i).name), 'f');
    fprintf('  promoted  %s  (%.0f KB)\n', d(i).name, d(i).bytes/1024);
end
fprintf('[PROMOTE] %d panel(s) -> %s\n', numel(d), dest);
