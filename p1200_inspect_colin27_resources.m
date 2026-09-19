% p1200_inspect_colin27_resources
% Audit local Colin27/BrainWeb resources before defining a new source space.
%
% Makoto project-layout rule:
%   <project>/
%       code/
%           p1200_inspect_colin27_resources.m
%           ...
%       p1200_inspect_colin27_resources/
%
% The output folder is generated exclusively by this script and is rebuilt
% from scratch on each run. Do not add or edit files there manually.
%
% This pipeline intentionally does NOT create a source space. It implements
% the specification gate that local EEGLAB/DIPFIT/FieldTrip resources must be
% inspected first, and that source-space type, spacing, gray-matter rule,
% deep-structure inclusion, and orientation constraint remain scientific
% decisions rather than hidden defaults.

clear
clc

codeRoot = fileparts(mfilename('fullpath'));
[projectRoot, codeFolderName] = fileparts(codeRoot);
if ~strcmpi(codeFolderName, 'code')
    error('p1200_inspect_colin27_resources:ProjectLayoutViolation', ...
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
baseMri = mmagic_load_named_struct(resources.standard_mri_file, 'mri');
[bnd, headmodelMetadata] = mmagic_extract_bem_geometry(baseHeadmodel);
boundaryInfo = mmagic_classify_three_layer_boundaries(bnd);

candidateTable = local_find_candidate_resources(resources);
functionTable = local_function_inventory(resources);
save(fullfile(outputDir, 'colin27_resource_inventory.mat'), ...
    'resources', 'baseHeadmodel', 'baseMri', 'boundaryInfo', ...
    'candidateTable', 'functionTable', '-v7.3');
writetable(candidateTable, fullfile(outputDir, 'candidate_resources.csv'));
writetable(functionTable, fullfile(outputDir, 'function_inventory.csv'));

reportFile = fullfile(outputDir, 'RESOURCE_AUDIT.md');
fid = fopen(reportFile, 'w');
if fid < 0
    error('p1200_inspect_colin27_resources:CannotWriteReport', ...
        'Could not create %s', reportFile);
end
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>

fprintf(fid, '# MMAGIC Colin27 resource audit\n\n');
fprintf(fid, 'Generated: %s\n\n', char(datetime('now', 'TimeZone', 'UTC', ...
    'Format', 'yyyy-MM-dd HH:mm:ss z')));
fprintf(fid, '## Project layout\n\n');
fprintf(fid, '- project root: `%s`\n', projectRoot);
fprintf(fid, '- code root: `%s`\n', codeRoot);
fprintf(fid, '- pipeline output: `%s`\n\n', outputDir);
fprintf(fid, '## Resolved resources\n\n');
fprintf(fid, '- EEGLAB: `%s`\n', resources.eeglab_file);
fprintf(fid, '- DIPFIT: `%s`\n', resources.dipfitdefs_file);
fprintf(fid, '- standard MRI: `%s`\n', resources.standard_mri_file);
fprintf(fid, '- standard BEM: `%s`\n', resources.standard_vol_file);
fprintf(fid, '- standard 10-05 electrodes: `%s`\n\n', resources.standard_1005_file);

fprintf(fid, '## standard_vol.mat\n\n');
fprintf(fid, '- type: `%s`\n', local_text(headmodelMetadata.type));
fprintf(fid, '- unit: `%s`\n', local_text(headmodelMetadata.unit));
fprintf(fid, '- coordsys: `%s`\n', local_text(headmodelMetadata.coordsys));
fprintf(fid, '- stored conductivity: `%s`\n', ...
    mat2str(double(headmodelMetadata.reference_cond(:)'), 8));
fprintf(fid, '- precomputed BEM matrix present: `%d`\n', ...
    headmodelMetadata.has_precomputed_matrix);
fprintf(fid, '- boundary labels in stored order: `%s`\n', ...
    strjoin(boundaryInfo.labels, ', '));
fprintf(fid, '- enclosed volumes: `%s`\n\n', ...
    mat2str(boundaryInfo.enclosed_volume, 8));

fprintf(fid, '## standard_mri.mat\n\n');
if isfield(baseMri, 'unit'), fprintf(fid, '- unit: `%s`\n', local_text(baseMri.unit)); end
if isfield(baseMri, 'coordsys'), fprintf(fid, '- coordsys: `%s`\n', local_text(baseMri.coordsys)); end
if isfield(baseMri, 'dim'), fprintf(fid, '- dim: `%s`\n', mat2str(double(baseMri.dim(:)'))); end
fprintf(fid, '- fields: `%s`\n\n', strjoin(fieldnames(baseMri)', '`, `'));

fprintf(fid, '## Candidate local anatomical resources\n\n');
fprintf(fid, 'See `candidate_resources.csv`. Search terms include Colin, BrainWeb, gray/grey matter, cortex, surface, segmentation, MRI, and source model.\n\n');

fprintf(fid, '## BSCR requirement\n\n');
spec = mmagic_bscr_spec();
fprintf(fid, '| BSCR | brain (S/m) | skull (S/m) | scalp (S/m) |\n');
fprintf(fid, '|---:|---:|---:|---:|\n');
for idx = 1:numel(spec)
    fprintf(fid, '| %.0f | %.6g | %.6g | %.6g |\n', ...
        spec(idx).bscr, spec(idx).brain_S_per_m, ...
        spec(idx).skull_S_per_m, spec(idx).scalp_S_per_m);
end
fprintf(fid, '\nEach BSCR requires a freshly recomputed BEM solution. Editing only a stored conductivity field on a precomputed head model is not sufficient.\n\n');

fprintf(fid, '## Scientific decisions intentionally unresolved\n\n');
fprintf(fid, '- volumetric gray-matter grid vs cortical surface vs hybrid source space\n');
fprintf(fid, '- source spacing (for example 5 mm vs 7 mm)\n');
fprintf(fid, '- gray-matter inclusion criterion\n');
fprintf(fid, '- cortex-only vs deep gray matter\n');
fprintf(fid, '- free 3-D orientation vs surface-normal constraint\n');
fprintf(fid, '- cerebellum inclusion/exclusion\n\n');
fprintf(fid, '**STOP after this audit. Do not generate the source space until these decisions are made.**\n');

fprintf('p1200 complete. Review:\n  %s\n', reportFile);

function tableOut = local_function_inventory(resources)
labels = {'eeglab'; 'dipfitdefs'; 'pop_leadfield'; 'ft_prepare_sourcemodel'; ...
    'ft_prepare_leadfield'; 'ft_prepare_headmodel'; 'ft_volumesegment'; 'ft_read_mri'};
paths = {resources.eeglab_file; resources.dipfitdefs_file; resources.pop_leadfield_file; ...
    resources.ft_prepare_sourcemodel_file; resources.ft_prepare_leadfield_file; ...
    resources.ft_prepare_headmodel_file; resources.ft_volumesegment_file; ...
    resources.ft_read_mri_file};
found = ~cellfun(@isempty, paths);
tableOut = table(labels, paths, found, ...
    'VariableNames', {'function_name','resolved_path','found'});
end

function tableOut = local_find_candidate_resources(resources)
roots = {resources.standard_bem_dir};
rootLabels = {'DIPFIT standard_BEM'};
for idx = 1:numel(resources.fieldtrip_roots)
    candidate = fullfile(resources.fieldtrip_roots{idx}, 'template');
    if isfolder(candidate)
        roots{end+1} = candidate; %#ok<AGROW>
        rootLabels{end+1} = sprintf('FieldTrip template %d', idx); %#ok<AGROW>
    end
end

keywords = {'colin','brainweb','gray','grey','cortex','cortical','surface', ...
    'segment','sourcemodel','source_model','mri'};
source = {};
name = {};
path = {};
bytes = [];
for rootIdx = 1:numel(roots)
    entries = dir(fullfile(roots{rootIdx}, '**', '*'));
    entries = entries(~[entries.isdir]);
    for entryIdx = 1:numel(entries)
        lowerName = lower(entries(entryIdx).name);
        if any(cellfun(@(k) contains(lowerName, k), keywords))
            source{end+1,1} = rootLabels{rootIdx}; %#ok<AGROW>
            name{end+1,1} = entries(entryIdx).name; %#ok<AGROW>
            path{end+1,1} = fullfile(entries(entryIdx).folder, entries(entryIdx).name); %#ok<AGROW>
            bytes(end+1,1) = entries(entryIdx).bytes; %#ok<AGROW>
        end
    end
end
tableOut = table(source, name, path, bytes);
if ~isempty(source), tableOut = sortrows(tableOut, {'source','name'}); end
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
