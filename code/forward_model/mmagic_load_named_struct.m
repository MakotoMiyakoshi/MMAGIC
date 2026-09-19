function value = mmagic_load_named_struct(fileName, preferredVariable)
% MMAGIC_LOAD_NAMED_STRUCT Load a struct from a MAT file without silent guessing.
%
% The preferred variable name is used when present. Otherwise, the MAT file
% must contain exactly one scalar struct variable.

if isstring(fileName), fileName = char(fileName); end
if isstring(preferredVariable), preferredVariable = char(preferredVariable); end
if ~isfile(fileName)
    error('mmagic_load_named_struct:FileNotFound', 'MAT file not found: %s', fileName);
end

contents = load(fileName);
if isfield(contents, preferredVariable)
    value = contents.(preferredVariable);
else
    names = fieldnames(contents);
    isScalarStruct = false(size(names));
    for idx = 1:numel(names)
        candidate = contents.(names{idx});
        isScalarStruct(idx) = isstruct(candidate) && isscalar(candidate);
    end
    structNames = names(isScalarStruct);
    if numel(structNames) ~= 1
        error('mmagic_load_named_struct:AmbiguousVariables', ...
            ['Preferred variable "%s" was not found in %s, and the file does not ', ...
             'contain exactly one scalar struct variable.'], preferredVariable, fileName);
    end
    value = contents.(structNames{1});
end

if ~isstruct(value) || ~isscalar(value)
    error('mmagic_load_named_struct:ExpectedScalarStruct', ...
        'Loaded value from %s is not a scalar struct.', fileName);
end
end
