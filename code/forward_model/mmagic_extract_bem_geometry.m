function [bnd, metadata] = mmagic_extract_bem_geometry(baseHeadmodel)
% MMAGIC_EXTRACT_BEM_GEOMETRY Extract a three-boundary geometry from a head model.

if ~isstruct(baseHeadmodel) || ~isscalar(baseHeadmodel)
    error('mmagic_extract_bem_geometry:InvalidHeadmodel', ...
        'baseHeadmodel must be a scalar struct.');
end
if ~isfield(baseHeadmodel, 'bnd') || ~isstruct(baseHeadmodel.bnd) || numel(baseHeadmodel.bnd) ~= 3
    error('mmagic_extract_bem_geometry:ExpectedThreeBoundaryBEM', ...
        'The reference head model must contain exactly three boundaries in .bnd.');
end

bnd = baseHeadmodel.bnd;
if ~isfield(bnd, 'pos') && isfield(bnd, 'pnt')
    for idx = 1:numel(bnd)
        bnd(idx).pos = bnd(idx).pnt;
    end
    bnd = rmfield(bnd, 'pnt');
end
if isfield(bnd, 'cond')
    bnd = rmfield(bnd, 'cond');
end

for idx = 1:numel(bnd)
    if ~isfield(bnd(idx), 'pos') || ~isfield(bnd(idx), 'tri')
        error('mmagic_extract_bem_geometry:InvalidBoundary', ...
            'Boundary %d lacks pos/tri geometry.', idx);
    end
end

metadata = struct();
metadata.type = '';
metadata.unit = '';
metadata.coordsys = '';
metadata.reference_cond = [];
metadata.has_precomputed_matrix = isfield(baseHeadmodel, 'mat') && ~isempty(baseHeadmodel.mat);
if isfield(baseHeadmodel, 'type'), metadata.type = baseHeadmodel.type; end
if isfield(baseHeadmodel, 'unit'), metadata.unit = baseHeadmodel.unit; end
if isfield(baseHeadmodel, 'coordsys'), metadata.coordsys = baseHeadmodel.coordsys; end
if isfield(baseHeadmodel, 'cond'), metadata.reference_cond = baseHeadmodel.cond; end

for idx = 1:numel(bnd)
    if ~isempty(metadata.unit) && (~isfield(bnd(idx), 'unit') || isempty(bnd(idx).unit))
        bnd(idx).unit = metadata.unit;
    end
    if ~isempty(metadata.coordsys) && (~isfield(bnd(idx), 'coordsys') || isempty(bnd(idx).coordsys))
        bnd(idx).coordsys = metadata.coordsys;
    end
end
end
