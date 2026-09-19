function conductivity = mmagic_conductivity_vector(boundaryLabels, spec)
% MMAGIC_CONDUCTIVITY_VECTOR Align a BSCR conductivity specification to BEM boundaries.

if isstring(boundaryLabels)
    boundaryLabels = cellstr(boundaryLabels);
end
if ~iscellstr(boundaryLabels) || numel(boundaryLabels) ~= 3 %#ok<ISCLSTR>
    error('mmagic_conductivity_vector:InvalidLabels', ...
        'boundaryLabels must contain three labels: brain, skull, and scalp.');
end
if ~isstruct(spec) || ~isscalar(spec) || ...
        ~all(isfield(spec, {'brain_S_per_m','skull_S_per_m','scalp_S_per_m'}))
    error('mmagic_conductivity_vector:InvalidSpec', ...
        'spec must be a scalar output element from mmagic_bscr_spec.');
end

conductivity = nan(1, 3);
for idx = 1:3
    switch lower(boundaryLabels{idx})
        case 'brain'
            conductivity(idx) = spec.brain_S_per_m;
        case 'skull'
            conductivity(idx) = spec.skull_S_per_m;
        case 'scalp'
            conductivity(idx) = spec.scalp_S_per_m;
        otherwise
            error('mmagic_conductivity_vector:UnknownBoundaryLabel', ...
                'Unknown boundary label: %s', boundaryLabels{idx});
    end
end

if any(~isfinite(conductivity))
    error('mmagic_conductivity_vector:IncompleteConductivity', ...
        'Could not assign all three conductivities.');
end
end
