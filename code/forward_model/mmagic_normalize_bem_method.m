function method = mmagic_normalize_bem_method(method)
% MMAGIC_NORMALIZE_BEM_METHOD Normalize FieldTrip BEM method names.

if isstring(method)
    method = char(method);
end
if ~ischar(method) || isempty(strtrim(method))
    error('mmagic_normalize_bem_method:InvalidMethod', 'BEM method must be a nonempty string.');
end

method = lower(strtrim(method));
switch method
    case {'bemcp','bem_cp'}
        method = 'bemcp';
    case {'dipoli','bem_dipoli'}
        method = 'dipoli';
    case {'openmeeg','bem_openmeeg'}
        method = 'openmeeg';
    otherwise
        error('mmagic_normalize_bem_method:UnsupportedMethod', ...
            ['Unsupported three-layer BEM method "%s". MMAGIC currently supports ', ...
             'bemcp, dipoli, and openmeeg for BSCR regeneration.'], method);
end
end
