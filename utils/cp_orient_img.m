function D = cp_orient_img(T, A)
%CP_ORIENT_IMG  Native [nY x nX] array -> display array, under the session view T (see cp_orient).
%
% Order is transpose, then flipud, then fliplr -- cp_orient_fwd/cp_orient_inv apply and undo the
% SAME order, which is what keeps markers on top of the features they mark. Works for images and
% for logical masks alike (tints and outlines must go through it too, or they land in the wrong
% frame while the brain underneath does not).

% T.rot (optional, degrees CCW, default 0) is a display-only fine rotation applied AFTER the
% dihedral tr/fu/fl. 'crop' keeps the output the same size as the pre-rotation display frame
% ([Hd x Wd]) and rotates about its centre ((Hd+1)/2,(Wd+1)/2), which is the centre the point
% transforms in cp_orient_fwd/cp_orient_inv also rotate about -- so markers stay locked to
% features. Absent or 0 => byte-identical to the pre-rotation behaviour.
if isempty(T), D = A; return; end
D = A;
if T.tr, D = D.'; end
if T.fu, D = flipud(D); end
if T.fl, D = fliplr(D); end
if isfield(T,'rot') && T.rot ~= 0
    if islogical(D)
        D = imrotate(D, T.rot, 'nearest', 'crop');
    else
        D = imrotate(D, T.rot, 'bilinear', 'crop');
    end
end
end
