function volume = mmagic_mesh_enclosed_volume(mesh)
% MMAGIC_MESH_ENCLOSED_VOLUME Estimate enclosed volume of a closed triangle mesh.
%
% The result has the cubic unit of mesh.pos. The triangle orientation may be
% inward or outward, but it must be globally consistent.

if ~isstruct(mesh) || ~isscalar(mesh) || ~isfield(mesh, 'pos') || ~isfield(mesh, 'tri')
    error('mmagic_mesh_enclosed_volume:InvalidMesh', ...
        'mesh must be a scalar struct with pos and tri fields.');
end

pos = double(mesh.pos);
tri = double(mesh.tri);

if size(pos, 2) ~= 3 || size(tri, 2) ~= 3
    error('mmagic_mesh_enclosed_volume:InvalidDimensions', ...
        'mesh.pos and mesh.tri must have three columns.');
end
if isempty(pos) || isempty(tri) || any(~isfinite(pos(:))) || any(~isfinite(tri(:)))
    error('mmagic_mesh_enclosed_volume:NonFiniteMesh', ...
        'mesh positions and triangle indices must be finite and nonempty.');
end
if any(tri(:) < 1) || any(tri(:) > size(pos, 1)) || any(tri(:) ~= round(tri(:)))
    error('mmagic_mesh_enclosed_volume:InvalidTriangles', ...
        'mesh.tri contains invalid vertex indices.');
end

v1 = pos(tri(:,1), :);
v2 = pos(tri(:,2), :);
v3 = pos(tri(:,3), :);
signedSixVolume = sum(dot(v1, cross(v2, v3, 2), 2));
volume = abs(signedSixVolume) / 6;

if ~isfinite(volume) || volume <= eps(max(abs(pos(:))))
    error('mmagic_mesh_enclosed_volume:DegenerateMesh', ...
        'The mesh has zero or numerically degenerate enclosed volume.');
end
end
