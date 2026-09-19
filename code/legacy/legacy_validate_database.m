function report = legacy_validate_database(db, varargin)
%LEGACY_VALIDATE_DATABASE Validate identity, linkage, and AAL alignment.
%
% report = legacy_validate_database(db)
% report = legacy_validate_database(db, 'ThrowOnError', true)
%
% Missing DIPFIT and NaN coordinates are reported as warnings because the
% database intentionally preserves IC identity when a source model is
% missing or invalid.

p = inputParser;
p.addRequired('db', @isstruct);
p.addParameter('ThrowOnError', false, @(x) islogical(x) && isscalar(x));
p.parse(db, varargin{:});
opt = p.Results;

errors = cell(0,1);
warnings = cell(0,1);

requiredFields = {'meta','datasets','ics','dipoles','roi'};
for k = 1:numel(requiredFields)
    if ~isfield(db, requiredFields{k})
        errors{end+1,1} = ['Missing db.' requiredFields{k}]; %#ok<AGROW>
    end
end
if ~isempty(errors)
    report = local_report(errors, warnings);
    if opt.ThrowOnError, error('legacy_validate_database:InvalidDatabase', '%s', strjoin(errors, '\n')); end
    return
end

if ~istable(db.datasets), errors{end+1,1} = 'db.datasets is not a table.'; end %#ok<AGROW>
if ~istable(db.ics), errors{end+1,1} = 'db.ics is not a table.'; end %#ok<AGROW>
if ~istable(db.dipoles), errors{end+1,1} = 'db.dipoles is not a table.'; end %#ok<AGROW>
if ~isstruct(db.roi), errors{end+1,1} = 'db.roi is not a struct.'; end %#ok<AGROW>
if ~isempty(errors)
    report = local_report(errors, warnings);
    if opt.ThrowOnError, error('legacy_validate_database:InvalidDatabase', '%s', strjoin(errors, '\n')); end
    return
end

if numel(unique(db.datasets.dataset_id)) ~= height(db.datasets)
    errors{end+1,1} = 'dataset_id values are not unique.'; %#ok<AGROW>
end
if numel(unique(db.datasets.dataset_uid)) ~= height(db.datasets)
    errors{end+1,1} = 'dataset_uid values are not unique.'; %#ok<AGROW>
end
if numel(unique(db.ics.ic_uid)) ~= height(db.ics)
    errors{end+1,1} = 'ic_uid values are not unique.'; %#ok<AGROW>
end
if numel(unique(db.dipoles.dipole_uid)) ~= height(db.dipoles)
    errors{end+1,1} = 'dipole_uid values are not unique.'; %#ok<AGROW>
end

if any(~ismember(db.ics.dataset_id, db.datasets.dataset_id))
    errors{end+1,1} = 'At least one IC points to a missing dataset_id.'; %#ok<AGROW>
end
if any(~ismember(db.dipoles.ic_uid, db.ics.ic_uid))
    errors{end+1,1} = 'At least one dipole points to a missing ic_uid.'; %#ok<AGROW>
end

% Verify the complete dataset -> IC -> dipole identity chain, not only UID
% existence. This catches row-order and partial-column misalignment bugs.
for r = 1:height(db.ics)
    d = find(db.datasets.dataset_id == db.ics.dataset_id(r));
    if numel(d) == 1
        if ~strcmp(db.ics.dataset_uid{r}, db.datasets.dataset_uid{d}) || ...
                ~strcmp(db.ics.subject_id{r}, db.datasets.subject_id{d})
            errors{end+1,1} = sprintf('IC %s dataset/subject identity is inconsistent.', ...
                db.ics.ic_uid{r}); %#ok<AGROW>
        end
    end
end

for r = 1:height(db.dipoles)
    i = find(strcmp(db.ics.ic_uid, db.dipoles.ic_uid{r}));
    if numel(i) ~= 1
        continue
    end
    sameRv = (isnan(db.dipoles.residual_variance(r)) && isnan(db.ics.residual_variance(i))) || ...
        abs(db.dipoles.residual_variance(r) - db.ics.residual_variance(i)) <= 1e-12;
    if db.dipoles.dataset_id(r) ~= db.ics.dataset_id(i) || ...
            ~strcmp(db.dipoles.dataset_uid{r}, db.ics.dataset_uid{i}) || ...
            ~strcmp(db.dipoles.subject_id{r}, db.ics.subject_id{i}) || ...
            db.dipoles.ic_index(r) ~= db.ics.ic_index(i) || ~sameRv
        errors{end+1,1} = sprintf('Dipole %s identity/RV is inconsistent with parent IC %s.', ...
            db.dipoles.dipole_uid{r}, db.dipoles.ic_uid{r}); %#ok<AGROW>
    end
end

for r = 1:height(db.ics)
    nLinked = sum(strcmp(db.dipoles.ic_uid, db.ics.ic_uid{r}));
    if nLinked ~= db.ics.n_dipoles(r)
        errors{end+1,1} = sprintf('IC %s reports %d dipoles but has %d linked rows.', ...
            db.ics.ic_uid{r}, db.ics.n_dipoles(r), nLinked); %#ok<AGROW>
    end
end

nMissingDipfit = sum(db.ics.n_dipoles == 0);
if nMissingDipfit > 0
    warnings{end+1,1} = sprintf('%d IC(s) have no DIPFIT source-model entry.', nMissingDipfit); %#ok<AGROW>
end

if height(db.dipoles) > 0
    invalidXyz = ~isfinite(db.dipoles.x) | ~isfinite(db.dipoles.y) | ~isfinite(db.dipoles.z);
    if any(invalidXyz)
        warnings{end+1,1} = sprintf('%d dipole row(s) contain non-finite xyz coordinates.', sum(invalidXyz)); %#ok<AGROW>
    end
end

roiAssigned = isfield(db.roi, 'labels') && ~isempty(db.roi.labels);
if roiAssigned
    if ~isfield(db.roi, 'distance_mm')
        errors{end+1,1} = 'db.roi.labels exists but db.roi.distance_mm is missing.'; %#ok<AGROW>
    else
        D = db.roi.distance_mm;
        if size(D,1) ~= height(db.dipoles)
            errors{end+1,1} = 'db.roi.distance_mm row count does not match db.dipoles.'; %#ok<AGROW>
        end
        if size(D,2) ~= numel(db.roi.labels)
            errors{end+1,1} = 'db.roi.distance_mm column count does not match db.roi.labels.'; %#ok<AGROW>
        end
        finiteD = D(isfinite(D));
        if any(finiteD < 0)
            errors{end+1,1} = 'db.roi.distance_mm contains negative distances.'; %#ok<AGROW>
        end
    end

    requiredDipoleFields = {'aal_label','aal_index','nearest_roi_label','nearest_roi_index', ...
        'nearest_roi_distance_mm','roi_assignment_status'};
    for k = 1:numel(requiredDipoleFields)
        if ~ismember(requiredDipoleFields{k}, db.dipoles.Properties.VariableNames)
            errors{end+1,1} = ['db.dipoles is missing ' requiredDipoleFields{k} '.']; %#ok<AGROW>
        end
    end

    if isempty(errors) && height(db.dipoles) > 0
        for r = 1:height(db.dipoles)
            if strcmp(db.dipoles.roi_assignment_status{r}, 'invalid_xyz')
                continue
            end

            rowD = db.roi.distance_mm(r,:);
            finiteIdx = find(isfinite(rowD));
            if isempty(finiteIdx)
                continue
            end
            [dMin, idxLocal] = min(rowD(finiteIdx));
            idxMin = finiteIdx(idxLocal);

            if isfinite(db.dipoles.nearest_roi_distance_mm(r)) && ...
                    abs(db.dipoles.nearest_roi_distance_mm(r) - dMin) > 1e-9
                errors{end+1,1} = sprintf('Dipole %s nearest ROI distance is inconsistent with distance matrix.', ...
                    db.dipoles.dipole_uid{r}); %#ok<AGROW>
            end
            if isfinite(db.dipoles.nearest_roi_index(r)) && db.dipoles.nearest_roi_index(r) ~= idxMin
                errors{end+1,1} = sprintf('Dipole %s nearest ROI index is inconsistent with distance matrix.', ...
                    db.dipoles.dipole_uid{r}); %#ok<AGROW>
            end
            if isfinite(db.dipoles.nearest_roi_index(r)) && ...
                    ~strcmp(db.dipoles.nearest_roi_label{r}, db.roi.labels{idxMin})
                errors{end+1,1} = sprintf('Dipole %s nearest ROI label is inconsistent with distance matrix.', ...
                    db.dipoles.dipole_uid{r}); %#ok<AGROW>
            end

            if isfinite(db.dipoles.aal_index(r))
                q = db.dipoles.aal_index(r);
                if q < 1 || q > numel(db.roi.labels) || q ~= round(q)
                    errors{end+1,1} = sprintf('Dipole %s has invalid aal_index.', db.dipoles.dipole_uid{r}); %#ok<AGROW>
                elseif rowD(q) ~= 0
                    errors{end+1,1} = sprintf('Dipole %s exact AAL membership is not represented by 0 mm.', ...
                        db.dipoles.dipole_uid{r}); %#ok<AGROW>
                elseif ~strcmp(db.dipoles.aal_label{r}, db.roi.labels{q})
                    errors{end+1,1} = sprintf('Dipole %s AAL label/index mismatch.', db.dipoles.dipole_uid{r}); %#ok<AGROW>
                end
            end
        end
    end
else
    warnings{end+1,1} = 'AAL assignment has not been run yet.'; %#ok<AGROW>
end

report = local_report(errors, warnings);
if opt.ThrowOnError && ~report.is_valid
    error('legacy_validate_database:InvalidDatabase', '%s', strjoin(errors, '\n'));
end
end

function report = local_report(errors, warnings)
report = struct();
report.is_valid = isempty(errors);
report.errors = errors;
report.warnings = warnings;
report.n_errors = numel(errors);
report.n_warnings = numel(warnings);
end
