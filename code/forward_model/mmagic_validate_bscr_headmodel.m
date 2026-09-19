function report = mmagic_validate_bscr_headmodel(headmodel, spec)
% MMAGIC_VALIDATE_BSCR_HEADMODEL Validate conductivity assignment after BEM rebuild.

[bnd, metadata] = mmagic_extract_bem_geometry(headmodel);
boundaryInfo = mmagic_classify_three_layer_boundaries(bnd);
expectedCond = mmagic_conductivity_vector(boundaryInfo.labels, spec);

if ~isfield(headmodel, 'cond') || numel(headmodel.cond) ~= 3
    error('mmagic_validate_bscr_headmodel:MissingConductivity', ...
        'Rebuilt head model does not contain a three-element .cond vector.');
end
actualCond = double(headmodel.cond(:)');

scale = max(1, max(abs(expectedCond)));
tolerance = 100 * eps(scale);
if any(abs(actualCond - expectedCond) > tolerance)
    error('mmagic_validate_bscr_headmodel:ConductivityMismatch', ...
        'Rebuilt head-model conductivities do not match the intended BSCR specification.');
end

brainIdx = find(strcmp(boundaryInfo.labels, 'brain'), 1);
skullIdx = find(strcmp(boundaryInfo.labels, 'skull'), 1);
actualBSCR = actualCond(brainIdx) / actualCond(skullIdx);
if abs(actualBSCR - spec.bscr) > 100 * eps(max(1, spec.bscr))
    error('mmagic_validate_bscr_headmodel:BSCRMismatch', ...
        'Actual brain-to-skull conductivity ratio differs from the requested value.');
end

report = struct();
report.is_valid = true;
report.actual_bscr = actualBSCR;
report.expected_bscr = spec.bscr;
report.boundary_labels = boundaryInfo.labels;
report.boundary_enclosed_volume = boundaryInfo.enclosed_volume;
report.expected_cond = expectedCond;
report.actual_cond = actualCond;
report.type = metadata.type;
report.unit = metadata.unit;
report.coordsys = metadata.coordsys;
end
