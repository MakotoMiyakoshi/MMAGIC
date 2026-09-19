function selection = legacy_select_roi(db, roiLabel, varargin)
%LEGACY_SELECT_ROI Select AAL ROI membership without duplicating ICs.
%
% selection = legacy_select_roi(db, roiLabel)
% selection = legacy_select_roi(db, roiLabel, 'MaxDistanceMm', 5)
%
% ROI selection is based on the first-class distance matrix created by
% legacy_assign_aal_rois(). Exact AAL membership is represented by 0 mm.
% A positive MaxDistanceMm explicitly extends the ROI by that distance.
%
% OUTPUT
%   selection.hits : one row per matching source-model entry (dipole).
%   selection.ics  : unique IC rows linked to at least one matching dipole.
%
% NAME-VALUE OPTIONS
%   'MaxDistanceMm' : maximum distance to the requested AAL ROI (default 0,
%                     exact atlas membership only).
%   'Hemisphere'    : 'Either' (default), 'Left', 'Right', or 'Midline'.
%   'BoundaryPolicy': 'historical' (default) or 'strict'. This option only
%                     concerns the legacy x-coordinate hemisphere filter:
%                     historical reproduces the earlier boundary rule, where x=0 matches both
%                     Left and Right; strict uses x<0 and x>0.
%
% Note that standard AAL labels already encode hemisphere (e.g., *_L/*_R).
% Hemisphere filtering is retained solely for backward-compatible queries.

p = inputParser;
p.addRequired('db', @isstruct);
p.addRequired('roiLabel', @(x) ischar(x) || (isstring(x) && isscalar(x)));
p.addParameter('MaxDistanceMm', 0, @(x) isscalar(x) && isnumeric(x) && isfinite(x) && x >= 0);
p.addParameter('Hemisphere', 'Either', @(x) any(strcmpi(char(x), {'Either','Left','Right','Midline'})));
p.addParameter('BoundaryPolicy', 'historical', @(x) any(strcmpi(char(x), {'historical','strict'})));
p.parse(db, roiLabel, varargin{:});
opt = p.Results;
roiLabel = char(roiLabel);
hemisphere = lower(char(opt.Hemisphere));
boundaryPolicy = lower(char(opt.BoundaryPolicy));

if ~isfield(db, 'ics') || ~istable(db.ics) || ~isfield(db, 'dipoles') || ~istable(db.dipoles)
    error('legacy_select_roi:InvalidDatabase', 'db.ics and db.dipoles tables are required.');
end
if ~isfield(db, 'roi') || ~isstruct(db.roi) || ~isfield(db.roi, 'labels') || ~isfield(db.roi, 'distance_mm')
    error('legacy_select_roi:MissingAALAssignment', ...
        'Run legacy_assign_aal_rois() before ROI selection.');
end

roiIdx = find(strcmp(db.roi.labels, roiLabel), 1, 'first');
if isempty(roiIdx)
    error('legacy_select_roi:UnknownROI', 'AAL ROI label not found: %s', roiLabel);
end
if size(db.roi.distance_mm,1) ~= height(db.dipoles) || size(db.roi.distance_mm,2) ~= numel(db.roi.labels)
    error('legacy_select_roi:MisalignedDistanceMatrix', ...
        'db.roi.distance_mm is not aligned with db.dipoles and db.roi.labels.');
end

hit_dataset_id = zeros(0,1);
hit_dataset_uid = cell(0,1);
hit_subject_id = cell(0,1);
hit_ic_uid = cell(0,1);
hit_ic_index = zeros(0,1);
hit_dipole_uid = cell(0,1);
hit_dipole_number = zeros(0,1);
hit_x = zeros(0,1);
hit_y = zeros(0,1);
hit_z = zeros(0,1);
hit_roi_label = cell(0,1);
hit_roi_distance_mm = zeros(0,1);
hit_is_exact_membership = false(0,1);

roiDistance = db.roi.distance_mm(:,roiIdx);
for r = 1:height(db.dipoles)
    xyz = [db.dipoles.x(r), db.dipoles.y(r), db.dipoles.z(r)];
    if any(~isfinite(xyz)) || ~local_hemisphere_match(xyz(1), hemisphere, boundaryPolicy)
        continue
    end

    d = roiDistance(r);
    if ~isfinite(d) || d > opt.MaxDistanceMm
        continue
    end

    hit_dataset_id(end+1,1) = db.dipoles.dataset_id(r); %#ok<AGROW>
    hit_dataset_uid{end+1,1} = db.dipoles.dataset_uid{r}; %#ok<AGROW>
    hit_subject_id{end+1,1} = db.dipoles.subject_id{r}; %#ok<AGROW>
    hit_ic_uid{end+1,1} = db.dipoles.ic_uid{r}; %#ok<AGROW>
    hit_ic_index(end+1,1) = db.dipoles.ic_index(r); %#ok<AGROW>
    hit_dipole_uid{end+1,1} = db.dipoles.dipole_uid{r}; %#ok<AGROW>
    hit_dipole_number(end+1,1) = db.dipoles.dipole_number(r); %#ok<AGROW>
    hit_x(end+1,1) = xyz(1); %#ok<AGROW>
    hit_y(end+1,1) = xyz(2); %#ok<AGROW>
    hit_z(end+1,1) = xyz(3); %#ok<AGROW>
    hit_roi_label{end+1,1} = roiLabel; %#ok<AGROW>
    hit_roi_distance_mm(end+1,1) = d; %#ok<AGROW>
    hit_is_exact_membership(end+1,1) = strcmp(db.dipoles.aal_label{r}, roiLabel); %#ok<AGROW>
end

selection = struct();
selection.query = struct('roi_label', roiLabel, ...
    'max_distance_mm', opt.MaxDistanceMm, ...
    'hemisphere', char(opt.Hemisphere), ...
    'boundary_policy', char(opt.BoundaryPolicy));
selection.hits = table(hit_dataset_id, hit_dataset_uid, hit_subject_id, hit_ic_uid, ...
    hit_ic_index, hit_dipole_uid, hit_dipole_number, hit_x, hit_y, hit_z, ...
    hit_roi_label, hit_roi_distance_mm, hit_is_exact_membership, ...
    'VariableNames', {'dataset_id','dataset_uid','subject_id','ic_uid','ic_index', ...
    'dipole_uid','dipole_number','x','y','z','roi_label','roi_distance_mm','is_exact_membership'});

if isempty(hit_ic_uid)
    selection.ics = db.ics([],:);
else
    uniqueIcUid = unique(hit_ic_uid, 'stable');
    keep = ismember(db.ics.ic_uid, uniqueIcUid);
    selection.ics = db.ics(keep,:);
end
end

function tf = local_hemisphere_match(x, hemisphere, boundaryPolicy)
switch hemisphere
    case 'either'
        tf = true;
    case 'midline'
        tf = (x == 0);
    case 'left'
        if strcmp(boundaryPolicy, 'historical')
            tf = (x <= 0);
        else
            tf = (x < 0);
        end
    case 'right'
        if strcmp(boundaryPolicy, 'historical')
            tf = (x >= 0);
        else
            tf = (x > 0);
        end
    otherwise
        tf = false;
end
end
