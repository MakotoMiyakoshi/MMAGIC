function db = legacy_assign_aal_rois(db, varargin)
%LEGACY_ASSIGN_AAL_ROIS Assign FieldTrip AAL labels and ROI distances.
%
% db = legacy_assign_aal_rois(db)
% db = legacy_assign_aal_rois(db, 'AtlasFile', atlasFile)
% db = legacy_assign_aal_rois(db, 'Atlas', atlasStruct)
%
% Exact membership is determined directly from the FieldTrip atlas array:
% MNI xyz is transformed to voxel ijk, rounded to the nearest voxel center,
% bounds-checked, and indexed in atlas.tissue. ft_volumelookup is not used
% here; validation code can use it as an independent reference.
%
% In addition to the exact AAL parcel containing each DIPFIT coordinate,
% the function stores the Euclidean distance (mm) from every dipole to
% every AAL ROI. Distance is measured to the nearest boundary-voxel center
% of each ROI; exact atlas membership is explicitly set to 0 mm.
%
% NAME-VALUE OPTIONS
%   'AtlasFile'      : AAL NIfTI file. Default is FieldTrip's bundled
%                      template/atlas/aal/ROI_MNI_V4.nii.
%   'Atlas'          : preloaded FieldTrip atlas structure. Primarily useful
%                      for testing or for avoiding repeated disk I/O.
%
% OUTPUT ADDITIONS
%   db.dipoles.aal_label
%   db.dipoles.aal_index
%   db.dipoles.nearest_roi_label
%   db.dipoles.nearest_roi_index
%   db.dipoles.nearest_roi_distance_mm
%   db.dipoles.roi_assignment_status
%
%   db.roi.labels
%   db.roi.values
%   db.roi.distance_mm    [nDipoles x nAalRois], aligned to db.dipoles rows
%
% The distance matrix is deliberately first-class information. Downstream
% ROI selection can therefore use exact membership (0 mm) or an explicit
% spatial tolerance without inventing pseudo-probabilities.

p = inputParser;
p.addRequired('db', @isstruct);
p.addParameter('AtlasFile', '', @(x) ischar(x) || (isstring(x) && isscalar(x)));
p.addParameter('Atlas', [], @(x) isempty(x) || isstruct(x));
p.parse(db, varargin{:});
opt = p.Results;

if ~isfield(db, 'dipoles') || ~istable(db.dipoles)
    error('legacy_assign_aal_rois:InvalidDatabase', 'db.dipoles table is missing.');
end

[atlas, atlasFile] = local_load_aal_atlas(opt.Atlas, char(opt.AtlasFile));
local_validate_aal_atlas(atlas);

[roiValues, roiLabels] = local_roi_values_and_labels(atlas);
roiBoundaryXyz = local_precompute_roi_boundaries(atlas, roiValues);

nDipoles = height(db.dipoles);
nRois = numel(roiValues);
distanceMm = nan(nDipoles, nRois);

aalLabel = repmat({''}, nDipoles, 1);
aalIndex = nan(nDipoles,1);
nearestRoiLabel = repmat({''}, nDipoles, 1);
nearestRoiIndex = nan(nDipoles,1);
nearestRoiDistanceMm = nan(nDipoles,1);
assignmentStatus = repmat({'not_assigned'}, nDipoles, 1);
voxelI = nan(nDipoles,1);
voxelJ = nan(nDipoles,1);
voxelK = nan(nDipoles,1);

for r = 1:nDipoles
    xyz = double([db.dipoles.x(r), db.dipoles.y(r), db.dipoles.z(r)]);
    if any(~isfinite(xyz))
        assignmentStatus{r} = 'invalid_xyz';
        continue
    end

    % Direct, transparent point-to-voxel lookup in the atlas grid.
    ijk1 = double(atlas.transform) \ [xyz(:); 1];
    ijk = round(ijk1(1:3));
    voxelI(r) = ijk(1);
    voxelJ(r) = ijk(2);
    voxelK(r) = ijk(3);
    if all(ijk >= 1) && all(ijk(:)' <= double(atlas.dim(:)'))
        tissueValue = double(atlas.tissue(ijk(1), ijk(2), ijk(3)));
        idx = find(roiValues == tissueValue, 1, 'first');
        if ~isempty(idx)
            aalLabel{r} = roiLabels{idx};
            aalIndex(r) = idx;
        end
    end

    % Compute geometrically transparent distance-to-ROI in physical mm.
    for q = 1:nRois
        xyzRoi = roiBoundaryXyz{q};
        if isempty(xyzRoi)
            continue
        end
        delta = bsxfun(@minus, xyzRoi, xyz);
        distanceMm(r,q) = sqrt(min(sum(delta.^2, 2)));
    end

    % Exact atlas membership is a set-membership statement, hence distance 0.
    if isfinite(aalIndex(r))
        distanceMm(r, aalIndex(r)) = 0;
    end

    [nearestDist, nearestIdx] = min(distanceMm(r,:));
    if isfinite(nearestDist)
        nearestRoiDistanceMm(r) = nearestDist;
        nearestRoiIndex(r) = nearestIdx;
        nearestRoiLabel{r} = roiLabels{nearestIdx};
    end

    if isfinite(aalIndex(r))
        assignmentStatus{r} = 'exact';
    elseif isfinite(nearestRoiDistanceMm(r))
        assignmentStatus{r} = 'nearest_only';
    else
        assignmentStatus{r} = 'no_roi';
    end
end

db.dipoles.aal_label = aalLabel;
db.dipoles.aal_index = aalIndex;
db.dipoles.nearest_roi_label = nearestRoiLabel;
db.dipoles.nearest_roi_index = nearestRoiIndex;
db.dipoles.nearest_roi_distance_mm = nearestRoiDistanceMm;
db.dipoles.roi_assignment_status = assignmentStatus;
db.dipoles.aal_voxel_i = voxelI;
db.dipoles.aal_voxel_j = voxelJ;
db.dipoles.aal_voxel_k = voxelK;

db.roi = struct();
db.roi.atlas_name = 'AAL';
db.roi.atlas_file = atlasFile;
db.roi.coordsys = local_get_text_field(atlas, 'coordsys', 'mni');
db.roi.unit = local_get_text_field(atlas, 'unit', 'mm');
db.roi.values = roiValues(:)';
db.roi.labels = roiLabels(:)';
db.roi.distance_mm = distanceMm;
db.roi.distance_definition = ['Minimum Euclidean distance in MNI mm from the DIPFIT coordinate ' ...
    'to an AAL ROI boundary-voxel center; exact atlas membership is set to 0 mm.'];

db.meta.method = 'legacy DIPFIT + FieldTrip AAL anatomical ROI reference';
db.meta.roi_assignment_method = 'Direct FieldTrip AAL voxel membership + distance-to-ROI';
db.meta.atlas_name = 'AAL';
db.meta.atlas_file = atlasFile;
db.meta.distance_to_roi_is_first_class = true;
end

function [atlas, atlasFile] = local_load_aal_atlas(atlasInput, atlasFileInput)
if ~isempty(atlasInput)
    atlas = atlasInput;
    atlasFile = atlasFileInput;
else
    if exist('ft_read_atlas', 'file') ~= 2
        error('legacy_assign_aal_rois:MissingFieldTrip', ...
            'FieldTrip ft_read_atlas() was not found on the MATLAB path.');
    end

    if isempty(atlasFileInput)
        if exist('ft_version', 'file') ~= 2
            error('legacy_assign_aal_rois:MissingFieldTrip', ...
                'FieldTrip ft_version() was not found on the MATLAB path.');
        end
        [~, ftPath] = ft_version;
        atlasFile = fullfile(ftPath, 'template', 'atlas', 'aal', 'ROI_MNI_V4.nii');
    else
        atlasFile = atlasFileInput;
    end

    if exist(atlasFile, 'file') ~= 2
        error('legacy_assign_aal_rois:AtlasNotFound', 'AAL atlas file not found: %s', atlasFile);
    end

    atlas = ft_read_atlas(atlasFile);
end

if isfield(atlas, 'unit') && ~isempty(atlas.unit) && ~strcmpi(atlas.unit, 'mm')
    if exist('ft_convert_units', 'file') ~= 2
        error('legacy_assign_aal_rois:MissingFieldTrip', ...
            'Atlas units are not mm and ft_convert_units() is unavailable.');
    end
    atlas = ft_convert_units(atlas, 'mm');
end
end

function local_validate_aal_atlas(atlas)
required = {'dim','transform','tissue','tissuelabel'};
for k = 1:numel(required)
    if ~isfield(atlas, required{k})
        error('legacy_assign_aal_rois:InvalidAtlas', 'Atlas is missing field "%s".', required{k});
    end
end
if ~isequal(size(atlas.tissue), double(atlas.dim(:)'))
    error('legacy_assign_aal_rois:InvalidAtlas', 'atlas.tissue size does not match atlas.dim.');
end
if ~isequal(size(atlas.transform), [4 4])
    error('legacy_assign_aal_rois:InvalidAtlas', 'atlas.transform must be 4-by-4.');
end
end

function [roiValues, roiLabels] = local_roi_values_and_labels(atlas)
roiValues = unique(double(atlas.tissue(:)));
roiValues = roiValues(isfinite(roiValues) & roiValues > 0);
roiValues = roiValues(:);
allLabels = atlas.tissuelabel(:);

if isempty(roiValues)
    error('legacy_assign_aal_rois:EmptyAtlas', 'No positive ROI values were found in atlas.tissue.');
end

if max(roiValues) <= numel(allLabels) && all(abs(roiValues - round(roiValues)) < eps)
    roiLabels = allLabels(roiValues);
elseif numel(roiValues) == numel(allLabels)
    roiLabels = allLabels;
else
    error('legacy_assign_aal_rois:AtlasLabelMismatch', ...
        'Could not map atlas.tissue values to atlas.tissuelabel entries.');
end

roiLabels = cellfun(@char, roiLabels, 'UniformOutput', false);
end

function roiBoundaryXyz = local_precompute_roi_boundaries(atlas, roiValues)
% For a point outside an ROI, the nearest ROI voxel center lies on the
% ROI's 6-connected boundary. Restricting the search to boundary voxels
% therefore avoids needless distance calculations over interior voxels.
roiBoundaryXyz = cell(numel(roiValues),1);
T = double(atlas.transform);

for q = 1:numel(roiValues)
    mask = atlas.tissue == roiValues(q);
    boundary = local_six_connected_boundary(mask);
    idx = find(boundary);
    [i, j, k] = ind2sub(size(mask), idx);
    ijk1 = [double(i(:))'; double(j(:))'; double(k(:))'; ones(1,numel(idx))];
    xyz1 = T * ijk1;
    roiBoundaryXyz{q} = xyz1(1:3,:)';
end
end

function boundary = local_six_connected_boundary(mask)
% Mark all ROI voxels touching background or the volume edge in a
% 6-connected neighborhood. No Image Processing Toolbox is required.
mask = logical(mask);
interior = false(size(mask));
if all(size(mask) >= 3)
    interior(2:end-1,2:end-1,2:end-1) = ...
        mask(2:end-1,2:end-1,2:end-1) & ...
        mask(1:end-2,2:end-1,2:end-1) & mask(3:end,2:end-1,2:end-1) & ...
        mask(2:end-1,1:end-2,2:end-1) & mask(2:end-1,3:end,2:end-1) & ...
        mask(2:end-1,2:end-1,1:end-2) & mask(2:end-1,2:end-1,3:end);
end
boundary = mask & ~interior;
end

function out = local_get_text_field(s, fieldName, defaultValue)
if isfield(s, fieldName) && ~isempty(s.(fieldName))
    out = char(s.(fieldName));
else
    out = defaultValue;
end
end
