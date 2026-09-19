% p1210_build_colin27_bscr_headmodels
% Rebuild three Colin27 BEM solutions that differ only in BSCR.
%
% Makoto project-layout rule:
%   <project>/
%       code/
%           p1210_build_colin27_bscr_headmodels.m
%           ...
%       p1210_build_colin27_bscr_headmodels/
%
% The output folder is generated exclusively by this script and is rebuilt
% from scratch on each run. Do not add or edit files there manually.
%
% This pipeline uses the geometry in DIPFIT standard_BEM/standard_vol.mat,
% but it does NOT reuse that file's precomputed BEM system matrix. A fresh
% FieldTrip BEM solution is computed for each conductivity condition.

clear
clc

% Scientific specification.
BSCR_VALUES = [20 40 80];
BRAIN_CONDUCTIVITY_S_PER_M = 0.33;
SCALP_CONDUCTIVITY_S_PER_M = 0.33;

% Leave empty to preserve the BEM method declared by standard_vol.mat.
% A nonempty value may be 'bemcp', 'dipoli', or 'openmeeg'.
BEM_METHOD_OVERRIDE = '';

codeRoot = fileparts(mfilename('fullpath'));
[projectRoot, codeFolderName] = fileparts(codeRoot);
if ~strcmpi(codeFolderName, 'code')
    error('p1210_build_colin27_bscr_headmodels:ProjectLayoutViolation', ...
        ['Makoto project-layout rule requires this script to live directly in ', ...
         '<project>/code/. Current folder: %s'], codeRoot);
end

addpath(fullfile(codeRoot, 'forward_model'));

[~, pipelineName] = fileparts(mfilename('fullpath'));
outputDir = fullfile(projectRoot, pipelineName);
if isfolder(outputDir)
    rmdir(outputDir, 's');
end
mkdir(outputDir);

resources = mmagic_resolve_colin27_resources('RequireFieldTrip', true);
baseHeadmodel = mmagic_load_named_struct(resources.standard_vol_file, 'vol');
[bnd, baseMetadata] = mmagic_extract_bem_geometry(baseHeadmodel);

if isempty(BEM_METHOD_OVERRIDE)
    if isempty(baseMetadata.type)
        error('p1210_build_colin27_bscr_headmodels:MissingMethod', ...
            ['standard_vol.mat does not declare a head-model type. Set ', ...
             'BEM_METHOD_OVERRIDE explicitly after inspecting p1200 output.']);
    end
    bemMethod = mmagic_normalize_bem_method(baseMetadata.type);
else
    bemMethod = mmagic_normalize_bem_method(BEM_METHOD_OVERRIDE);
end

bnd = local_convert_geometry_to_mm(bnd, baseMetadata.unit);
baseBoundaryInfo = mmagic_classify_three_layer_boundaries(bnd);
bscrSpec = mmagic_bscr_spec( ...
    'BSCR', BSCR_VALUES, ...
    'BrainConductivity', BRAIN_CONDUCTIVITY_S_PER_M, ...
    'ScalpConductivity', SCALP_CONDUCTIVITY_S_PER_M);

nModels = numel(bscrSpec);
manifestBSCR = zeros(nModels,1);
manifestBrain = zeros(nModels,1);
manifestSkull = zeros(nModels,1);
manifestScalp = zeros(nModels,1);
manifestMethod = repmat({bemMethod}, nModels,1);
manifestFile = cell(nModels,1);
manifestActualBSCR = zeros(nModels,1);

for modelIdx = 1:nModels
    currentSpec = bscrSpec(modelIdx);
    conductivityInputOrder = mmagic_conductivity_vector( ...
        baseBoundaryInfo.labels, currentSpec);

    cfg = [];
    cfg.method = bemMethod;
    cfg.conductivity = conductivityInputOrder;

    fprintf('\nBuilding Colin27 BEM for BSCR %.0f using %s...\n', ...
        currentSpec.bscr, bemMethod);
    rebuiltHeadmodel = ft_prepare_headmodel(cfg, bnd);

    if ~isfield(rebuiltHeadmodel, 'unit') || isempty(rebuiltHeadmodel.unit)
        rebuiltHeadmodel.unit = 'mm';
    end
    if ~isempty(baseMetadata.coordsys) && ...
            (~isfield(rebuiltHeadmodel, 'coordsys') || isempty(rebuiltHeadmodel.coordsys))
        rebuiltHeadmodel.coordsys = baseMetadata.coordsys;
    end

    local_assert_same_geometry(bnd, rebuiltHeadmodel.bnd);
    validation = mmagic_validate_bscr_headmodel( ...
        rebuiltHeadmodel, currentSpec);

    model = struct();
    model.headmodel = rebuiltHeadmodel;
    model.bscr = currentSpec.bscr;
    model.conductivity = currentSpec;
    model.validation = validation;
    model.provenance = local_provenance( ...
        resources, baseMetadata, bemMethod, currentSpec, mfilename);

    fileName = sprintf('colin27_bem_bscr%.0f.mat', currentSpec.bscr);
    save(fullfile(outputDir, fileName), 'model', '-v7.3');

    manifestBSCR(modelIdx) = currentSpec.bscr;
    manifestBrain(modelIdx) = currentSpec.brain_S_per_m;
    manifestSkull(modelIdx) = currentSpec.skull_S_per_m;
    manifestScalp(modelIdx) = currentSpec.scalp_S_per_m;
    manifestActualBSCR(modelIdx) = validation.actual_bscr;
    manifestFile{modelIdx} = fileName;
end

manifest = table(manifestBSCR, manifestBrain, manifestSkull, manifestScalp, ...
    manifestActualBSCR, manifestMethod, manifestFile, ...
    'VariableNames', {'bscr','brain_S_per_m','skull_S_per_m','scalp_S_per_m', ...
    'validated_bscr','bem_method','file'});
writetable(manifest, fullfile(outputDir, 'bscr_headmodel_manifest.csv'));
save(fullfile(outputDir, 'bscr_headmodel_manifest.mat'), ...
    'manifest', 'bscrSpec', 'resources', 'baseMetadata', 'baseBoundaryInfo');

reportFile = fullfile(outputDir, 'HEADMODEL_REPORT.md');
fid = fopen(reportFile, 'w');
if fid < 0
    error('p1210_build_colin27_bscr_headmodels:CannotWriteReport', ...
        'Could not create %s', reportFile);
end
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>

fprintf(fid, '# MMAGIC Colin27 BSCR head-model build\n\n');
fprintf(fid, 'Generated: %s\n\n', char(datetime('now', 'TimeZone', 'UTC', ...
    'Format', 'yyyy-MM-dd HH:mm:ss z')));
fprintf(fid, '- project root: `%s`\n', projectRoot);
fprintf(fid, '- code root: `%s`\n', codeRoot);
fprintf(fid, '- pipeline output: `%s`\n', outputDir);
fprintf(fid, '- Reference geometry: `%s`\n', resources.standard_vol_file);
fprintf(fid, '- Reference MRI: `%s`\n', resources.standard_mri_file);
fprintf(fid, '- BEM method: `%s`\n', bemMethod);
fprintf(fid, '- Geometry unit used for rebuild: `mm`\n');
fprintf(fid, '- Coordinate system: `%s`\n\n', local_text(baseMetadata.coordsys));
fprintf(fid, '| BSCR | brain (S/m) | skull (S/m) | scalp (S/m) | validated BSCR | file |\n');
fprintf(fid, '|---:|---:|---:|---:|---:|---|\n');
for idx = 1:height(manifest)
    fprintf(fid, '| %.0f | %.6g | %.6g | %.6g | %.12g | `%s` |\n', ...
        manifest.bscr(idx), manifest.brain_S_per_m(idx), ...
        manifest.skull_S_per_m(idx), manifest.scalp_S_per_m(idx), ...
        manifest.validated_bscr(idx), manifest.file{idx});
end
fprintf(fid, '\nAll three models use the same Colin27 boundary geometry. Only conductivity differs. Each BEM solution was recomputed; the precomputed matrix in `standard_vol.mat` was not reused.\n\n');
fprintf(fid, '**No source-space, leadfield, or eLORETA kernel is generated by p1210.** Those stages remain gated on the p1200 source-space decision.\n');

fprintf('\np1210 complete. Review:\n  %s\n', reportFile);

function bndMm = local_convert_geometry_to_mm(bnd, declaredUnit)
if nargin < 2, declaredUnit = ''; end

for idx = 1:numel(bnd)
    if (~isfield(bnd(idx), 'unit') || isempty(bnd(idx).unit)) && ...
            ~isempty(declaredUnit)
        bnd(idx).unit = declaredUnit;
    end
end

units = cell(1, numel(bnd));
for idx = 1:numel(bnd)
    if isfield(bnd(idx), 'unit') && ~isempty(bnd(idx).unit)
        units{idx} = lower(char(bnd(idx).unit));
    else
        units{idx} = '';
    end
end

if all(strcmp(units, 'mm'))
    bndMm = bnd;
    return
end
if any(cellfun(@isempty, units))
    error('p1210_build_colin27_bscr_headmodels:UnknownGeometryUnit', ...
        ['At least one BEM boundary lacks a declared unit. Run p1200 and ', ...
         'resolve coordinate/unit provenance before rebuilding conductivities.']);
end
if numel(unique(units)) ~= 1
    error('p1210_build_colin27_bscr_headmodels:MixedGeometryUnits', ...
        'BEM boundaries use mixed units: %s', strjoin(units, ', '));
end

bndMm = ft_convert_units(bnd, 'mm');
for idx = 1:numel(bndMm)
    if ~isfield(bndMm(idx), 'unit') || ~strcmpi(bndMm(idx).unit, 'mm')
        error('p1210_build_colin27_bscr_headmodels:UnitConversionFailed', ...
            'FieldTrip did not convert boundary %d to millimetres.', idx);
    end
end
end

function local_assert_same_geometry(referenceBnd, rebuiltBnd)
if numel(referenceBnd) ~= 3 || numel(rebuiltBnd) ~= 3
    error('p1210_build_colin27_bscr_headmodels:GeometryChanged', ...
        'Expected three boundaries before and after BEM construction.');
end

referenceInfo = mmagic_classify_three_layer_boundaries(referenceBnd);
rebuiltInfo = mmagic_classify_three_layer_boundaries(rebuiltBnd);
labels = {'brain','skull','scalp'};
for labelIdx = 1:numel(labels)
    refIdx = find(strcmp(referenceInfo.labels, labels{labelIdx}), 1);
    newIdx = find(strcmp(rebuiltInfo.labels, labels{labelIdx}), 1);
    refPos = sortrows(double(referenceBnd(refIdx).pos));
    newPos = sortrows(double(rebuiltBnd(newIdx).pos));

    if ~isequal(size(refPos), size(newPos))
        error('p1210_build_colin27_bscr_headmodels:GeometryChanged', ...
            'Vertex count changed for %s boundary.', labels{labelIdx});
    end

    tolerance = 100 * eps(max(1, max(abs(refPos(:)))));
    if any(abs(refPos(:) - newPos(:)) > tolerance)
        error('p1210_build_colin27_bscr_headmodels:GeometryChanged', ...
            'Vertex coordinates changed for %s boundary.', labels{labelIdx});
    end

    if size(referenceBnd(refIdx).tri,1) ~= size(rebuiltBnd(newIdx).tri,1)
        error('p1210_build_colin27_bscr_headmodels:GeometryChanged', ...
            'Triangle count changed for %s boundary.', labels{labelIdx});
    end
end
end

function provenance = local_provenance(resources, baseMetadata, bemMethod, spec, creationScript)
provenance = struct();
provenance.anatomy = 'Colin27 / BrainWeb-derived DIPFIT standard_BEM geometry';
provenance.mri_file = resources.standard_mri_file;
provenance.reference_headmodel_file = resources.standard_vol_file;
provenance.bem_method = bemMethod;
provenance.reference_bem_type = baseMetadata.type;
provenance.coordinate_system = baseMetadata.coordsys;
provenance.unit = 'mm';
provenance.brain_conductivity_S_per_m = spec.brain_S_per_m;
provenance.skull_conductivity_S_per_m = spec.skull_S_per_m;
provenance.scalp_conductivity_S_per_m = spec.scalp_S_per_m;
provenance.brain_to_skull_conductivity_ratio = spec.bscr;
provenance.eeglab_file = resources.eeglab_file;
provenance.dipfit_file = resources.dipfitdefs_file;
provenance.fieldtrip_headmodel_function = resources.ft_prepare_headmodel_file;
provenance.matlab_version = version;
provenance.creation_script = creationScript;
provenance.creation_date_utc = char(datetime('now', 'TimeZone', 'UTC', ...
    'Format', 'yyyy-MM-dd''T''HH:mm:ssXXX'));
end

function textOut = local_text(value)
if isempty(value)
    textOut = '';
elseif isstring(value)
    textOut = char(value);
elseif ischar(value)
    textOut = value;
else
    textOut = mat2str(value);
end
end
