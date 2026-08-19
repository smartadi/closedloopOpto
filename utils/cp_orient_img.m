function D = cp_orient_img(T, A)
%CP_ORIENT_IMG  Native [nY x nX] array -> display array, under the session view T (see cp_orient).
%
% Order is transpose, then flipud, then fliplr -- cp_orient_fwd/cp_orient_inv apply and undo the
% SAME order, which is what keeps markers on top of the features they mark. Works for images and
% for logical masks alike (tints and outlines must go through it too, or they land in the wrong
% frame while the brain underneath does not).

if isempty(T), D = A; return; end
D = A;
if T.tr, D = D.'; end
if T.fu, D = flipud(D); end
if T.fl, D = fliplr(D); end
end
