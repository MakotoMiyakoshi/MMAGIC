function info = mmagic_classify_three_layer_boundaries(bnd)
% MMAGIC_CLASSIFY_THREE_LAYER_BOUNDARIES Label brain/skull/scalp by nesting volume.
%
% info.labels is aligned to the input boundary order. The smallest enclosed
% surface is labeled brain, the middle surface skull, and the largest scalp.
% This function assumes a three-compartment nested BEM geometry.

if ~isstruct(bnd) || numel(bnd) ~= 3
    error('mmagic_classify_three_layer_boundaries:ExpectedThreeBoundaries', ...
        'A three-layer head model must contain exactly three boundaries.');
end

volumes = zeros(1, 3);
for idx = 1:3
    volumes(idx) = mmagic_mesh_enclosed_volume(bnd(idx));
end

[sortedVolumes, order] = sort(volumes, 'ascend');
if any(diff(sortedVolumes) <= 0)
    error('mmagic_classify_three_layer_boundaries:AmbiguousNesting', ...
        'Boundary enclosed volumes are not strictly ordered.');
end

labels = repmat({''}, 1, 3);
labels{order(1)} = 'brain';
labels{order(2)} = 'skull';
labels{order(3)} = 'scalp';

info = struct();
info.labels = labels;
info.enclosed_volume = volumes;
info.inside_to_outside_order = order;
info.sorted_enclosed_volume = sortedVolumes;
end
