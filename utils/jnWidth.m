function w = jnWidth(cls)
% JNWIDTH  Figure width in cm for a JNeurosci column class, or pass a number through.
%   jnWidth('single')  -> 8.5    jnWidth('onehalf') -> 11.6    jnWidth('double') -> 17.6
%   jnWidth(12.0)      -> 12.0   (numeric passthrough, for custom widths)
S = jnStyle();
if isnumeric(cls); w = cls; return; end
switch lower(strrep(char(cls),'.',''))
    case {'single','1','col1','1col'};       w = S.W_single;
    case {'onehalf','15','1p5','col15'};     w = S.W_onehalf;
    case {'double','2','col2','2col'};       w = S.W_double;
    otherwise; error('jnWidth: unknown class "%s" (use single/onehalf/double or a number).', char(cls));
end
end
