function db = legacy_collect_ica_sets(inputPath, varargin)
%LEGACY_COLLECT_ICA_SETS Build a compact cross-subject ICA/DIPFIT database.
%
% db = legacy_collect_ica_sets(inputPath)
% db = legacy_collect_ica_sets(inputPath, 'Name', value, ...)
%
% INPUT
%   inputPath : folder containing ICA-completed EEGLAB .set files, a .set
%               filename, or a cell array of .set filenames.
%
% NAME-VALUE OPTIONS
%   'ICLabelBrainThreshold' : [] (default) or scalar in [0,1]. If set,
%                             only ICs at or above this brain probability
%                             are retained. ICLabel must be present.
%   'ResidualVarianceThreshold' : [] (default) or scalar in [0,1]. If set,
%                                 only ICs strictly below this DIPFIT residual
%                                 variance are retained. DIPFIT must exist.
%   'LoaderFunction' : test hook. Function handle receiving a .set filename
%                      and returning an EEG structure. Default uses pop_loadset.
%
% OUTPUT
%   db.datasets : one row per source EEGLAB dataset.
%   db.ics      : one row per retained IC identity.
%   db.dipoles  : one row per DIPFIT source-model entry. Bilateral DIPFIT
%                 models therefore produce two rows linked to one IC row.
%
% This function intentionally does not perform preprocessing, ICA, DIPFIT,
% or group statistics. It only collects already-computed information.

p = inputParser;
p.addRequired('inputPath');
p.addParameter('ICLabelBrainThreshold', [], @(x) isempty(x) || (isscalar(x) && isnumeric(x) && x >= 0 && x <= 1));
p.addParameter('ResidualVarianceThreshold', [], @(x) isempty(x) || (isscalar(x) && isnumeric(x) && x >= 0 && x <= 1));
p.addParameter('LoaderFunction', [], @(x) isempty(x) || isa(x, 'function_handle'));
p.parse(inputPath, varargin{:});
opt = p.Results;

setFiles = local_resolve_set_files(inputPath);
if isempty(setFiles)
    error('legacy_collect_ica_sets:NoSetFiles', 'No .set files were found.');
end

if isempty(opt.LoaderFunction)
    if exist('pop_loadset', 'file') ~= 2
        error('legacy_collect_ica_sets:MissingEEGLAB', ...
            'EEGLAB pop_loadset() was not found on the MATLAB path.');
    end
    loader = @local_eeglab_loader;
else
    loader = opt.LoaderFunction;
end

% Dataset-level aligned columns.
dataset_id = zeros(numel(setFiles),1);
dataset_uid = cell(numel(setFiles),1);
subject_id = cell(numel(setFiles),1);
filename = cell(numel(setFiles),1);
filepath = cell(numel(setFiles),1);
n_components = zeros(numel(setFiles),1);
n_selected_ics = zeros(numel(setFiles),1);
has_dipfit = false(numel(setFiles),1);
has_iclabel = false(numel(setFiles),1);
icaweights = cell(numel(setFiles),1);
icasphere = cell(numel(setFiles),1);
icachansind = cell(numel(setFiles),1);
chanlocs = cell(numel(setFiles),1);

% IC-level aligned columns. Grow dynamically because retained counts vary.
ic_dataset_id = zeros(0,1);
ic_dataset_uid = cell(0,1);
ic_subject_id = cell(0,1);
ic_uid = cell(0,1);
ic_index = zeros(0,1);
brain_probability = zeros(0,1);
residual_variance = zeros(0,1);
n_dipoles = zeros(0,1);
scalp_projection = cell(0,1);

% Source-model entries. One row per dipole, not one duplicated IC.
dip_dataset_id = zeros(0,1);
dip_dataset_uid = cell(0,1);
dip_subject_id = cell(0,1);
dip_ic_uid = cell(0,1);
dip_uid = cell(0,1);
dip_ic_index = zeros(0,1);
dipole_number = zeros(0,1);
x = zeros(0,1);
y = zeros(0,1);
z = zeros(0,1);
moment_xyz = cell(0,1);
dip_residual_variance = zeros(0,1);
aal_label = cell(0,1);
aal_index = zeros(0,1);
nearest_roi_label = cell(0,1);
nearest_roi_index = zeros(0,1);
nearest_roi_distance_mm = zeros(0,1);
roi_assignment_status = cell(0,1);

for d = 1:numel(setFiles)
    EEG = loader(setFiles{d});
    [folderName, baseName, ext] = fileparts(setFiles{d});

    dataset_id(d) = d;
    dataset_uid{d} = sprintf('D%04d', d);
    filename{d} = [baseName ext];
    filepath{d} = folderName;
    subject_id{d} = local_subject_id(EEG, baseName);

    if ~isfield(EEG, 'icaweights') || isempty(EEG.icaweights)
        error('legacy_collect_ica_sets:MissingICA', ...
            'Dataset %s does not contain an ICA decomposition.', setFiles{d});
    end

    nIc = size(EEG.icaweights, 1);
    n_components(d) = nIc;
    icaweights{d} = EEG.icaweights;
    if isfield(EEG, 'icasphere'), icasphere{d} = EEG.icasphere; else, icasphere{d} = []; end
    if isfield(EEG, 'icachansind'), icachansind{d} = EEG.icachansind; else, icachansind{d} = []; end
    if isfield(EEG, 'chanlocs'), chanlocs{d} = EEG.chanlocs; else, chanlocs{d} = []; end

    hasDipfitThis = isfield(EEG, 'dipfit') && isfield(EEG.dipfit, 'model') && ~isempty(EEG.dipfit.model);
    has_dipfit(d) = hasDipfitThis;

    [brainProb, hasIcLabelThis] = local_get_brain_probabilities(EEG, nIc);
    has_iclabel(d) = hasIcLabelThis;

    if ~isempty(opt.ICLabelBrainThreshold) && ~hasIcLabelThis
        error('legacy_collect_ica_sets:MissingICLabel', ...
            'ICLabel threshold was requested, but dataset %s has no usable ICLabel result.', setFiles{d});
    end

    rv = nan(nIc,1);
    dipModels = repmat(struct(), 1, 0);
    if hasDipfitThis
        dipModels = EEG.dipfit.model;
        nModel = min(numel(dipModels), nIc);
        for ic = 1:nModel
            if isfield(dipModels(ic), 'rv') && ~isempty(dipModels(ic).rv)
                rv(ic) = dipModels(ic).rv(1);
            end
        end
    end

    if ~isempty(opt.ResidualVarianceThreshold) && ~hasDipfitThis
        error('legacy_collect_ica_sets:MissingDIPFITForRV', ...
            'Residual-variance filtering was requested, but dataset %s has no DIPFIT model.', setFiles{d});
    end

    keep = true(nIc,1);
    if ~isempty(opt.ICLabelBrainThreshold)
        keep = keep & brainProb >= opt.ICLabelBrainThreshold;
    end
    if ~isempty(opt.ResidualVarianceThreshold)
        keep = keep & rv < opt.ResidualVarianceThreshold;
    end
    keepIdx = find(keep);
    n_selected_ics(d) = numel(keepIdx);

    for k = 1:numel(keepIdx)
        ic = keepIdx(k);
        thisIcUid = sprintf('%s_IC%04d', dataset_uid{d}, ic);

        ic_dataset_id(end+1,1) = d; %#ok<AGROW>
        ic_dataset_uid{end+1,1} = dataset_uid{d}; %#ok<AGROW>
        ic_subject_id{end+1,1} = subject_id{d}; %#ok<AGROW>
        ic_uid{end+1,1} = thisIcUid; %#ok<AGROW>
        ic_index(end+1,1) = ic; %#ok<AGROW>
        brain_probability(end+1,1) = brainProb(ic); %#ok<AGROW>
        residual_variance(end+1,1) = rv(ic); %#ok<AGROW>

        thisProjection = [];
        if isfield(EEG, 'icawinv') && ~isempty(EEG.icawinv) && size(EEG.icawinv,2) >= ic
            thisProjection = EEG.icawinv(:,ic);
        end
        scalp_projection{end+1,1} = thisProjection; %#ok<AGROW>

        thisNDipoles = 0;
        if hasDipfitThis && numel(dipModels) >= ic && isfield(dipModels(ic), 'posxyz') && ~isempty(dipModels(ic).posxyz)
            posxyz = dipModels(ic).posxyz;
            if size(posxyz,2) ~= 3
                warning('legacy_collect_ica_sets:UnexpectedPosxyzShape', ...
                    'Ignoring DIPFIT coordinates for %s because posxyz is not N-by-3.', thisIcUid);
                posxyz = [];
            end
            thisNDipoles = size(posxyz,1);

            for j = 1:thisNDipoles
                dip_dataset_id(end+1,1) = d; %#ok<AGROW>
                dip_dataset_uid{end+1,1} = dataset_uid{d}; %#ok<AGROW>
                dip_subject_id{end+1,1} = subject_id{d}; %#ok<AGROW>
                dip_ic_uid{end+1,1} = thisIcUid; %#ok<AGROW>
                dip_uid{end+1,1} = sprintf('%s_D%02d', thisIcUid, j); %#ok<AGROW>
                dip_ic_index(end+1,1) = ic; %#ok<AGROW>
                dipole_number(end+1,1) = j; %#ok<AGROW>
                x(end+1,1) = posxyz(j,1); %#ok<AGROW>
                y(end+1,1) = posxyz(j,2); %#ok<AGROW>
                z(end+1,1) = posxyz(j,3); %#ok<AGROW>
                moment_xyz{end+1,1} = local_get_moment(dipModels(ic), j); %#ok<AGROW>
                dip_residual_variance(end+1,1) = rv(ic); %#ok<AGROW>
                aal_label{end+1,1} = ''; %#ok<AGROW>
                aal_index(end+1,1) = NaN; %#ok<AGROW>
                nearest_roi_label{end+1,1} = ''; %#ok<AGROW>
                nearest_roi_index(end+1,1) = NaN; %#ok<AGROW>
                nearest_roi_distance_mm(end+1,1) = NaN; %#ok<AGROW>
                roi_assignment_status{end+1,1} = 'not_assigned'; %#ok<AGROW>
            end
        end
        n_dipoles(end+1,1) = thisNDipoles; %#ok<AGROW>
    end
end

db = struct();
db.meta = struct();
db.meta.format_version = '0.1.0';
db.meta.package = 'MMAGIC';
db.meta.method = 'legacy DIPFIT + FieldTrip AAL anatomical ROI reference';
db.meta.created = datestr(now, 30);
db.meta.iclabel_brain_threshold = opt.ICLabelBrainThreshold;
db.meta.residual_variance_threshold = opt.ResidualVarianceThreshold;
db.meta.roi_assignment_method = 'not_assigned';
db.meta.atlas_name = '';
db.meta.atlas_file = '';
db.meta.distance_to_roi_is_first_class = false;

db.datasets = table(dataset_id, dataset_uid, subject_id, filename, filepath, ...
    n_components, n_selected_ics, has_dipfit, has_iclabel, ...
    icaweights, icasphere, icachansind, chanlocs);

db.ics = table(ic_dataset_id, ic_dataset_uid, ic_subject_id, ic_uid, ic_index, ...
    brain_probability, residual_variance, n_dipoles, scalp_projection, ...
    'VariableNames', {'dataset_id','dataset_uid','subject_id','ic_uid','ic_index', ...
    'brain_probability','residual_variance','n_dipoles','scalp_projection'});

db.dipoles = table(dip_dataset_id, dip_dataset_uid, dip_subject_id, dip_ic_uid, dip_uid, ...
    dip_ic_index, dipole_number, x, y, z, moment_xyz, dip_residual_variance, ...
    aal_label, aal_index, nearest_roi_label, nearest_roi_index, nearest_roi_distance_mm, roi_assignment_status, ...
    'VariableNames', {'dataset_id','dataset_uid','subject_id','ic_uid','dipole_uid', ...
    'ic_index','dipole_number','x','y','z','moment_xyz','residual_variance', ...
    'aal_label','aal_index','nearest_roi_label','nearest_roi_index','nearest_roi_distance_mm','roi_assignment_status'});

db.roi = struct('atlas_name', '', 'atlas_file', '', 'coordsys', '', 'unit', '', ...
    'values', [], 'labels', {{}}, 'distance_mm', [], 'distance_definition', '');

end

function setFiles = local_resolve_set_files(inputPath)
if ischar(inputPath) || (isstring(inputPath) && isscalar(inputPath))
    inputPath = char(inputPath);
    if exist(inputPath, 'dir') == 7
        d = dir(fullfile(inputPath, '*.set'));
        [~, order] = sort({d.name});
        d = d(order);
        setFiles = arrayfun(@(s) fullfile(s.folder, s.name), d, 'UniformOutput', false)';
    elseif exist(inputPath, 'file') == 2
        setFiles = {inputPath};
    else
        error('legacy_collect_ica_sets:InputNotFound', 'Input path does not exist: %s', inputPath);
    end
elseif iscell(inputPath)
    setFiles = inputPath(:);
else
    error('legacy_collect_ica_sets:InvalidInput', ...
        'inputPath must be a folder, a .set filename, or a cell array of .set filenames.');
end

for k = 1:numel(setFiles)
    setFiles{k} = char(setFiles{k});
    [~,~,ext] = fileparts(setFiles{k});
    if ~strcmpi(ext, '.set')
        error('legacy_collect_ica_sets:NotSetFile', 'Input is not an EEGLAB .set file: %s', setFiles{k});
    end
end
end

function EEG = local_eeglab_loader(setFile)
[folderName, baseName, ext] = fileparts(setFile);
EEG = pop_loadset('filename', [baseName ext], 'filepath', folderName, 'loadmode', 'info');
end

function subjectId = local_subject_id(EEG, fallback)
subjectId = '';
if isfield(EEG, 'subject') && ~isempty(EEG.subject)
    if ischar(EEG.subject)
        subjectId = strtrim(EEG.subject);
    elseif isstring(EEG.subject) && isscalar(EEG.subject)
        subjectId = strtrim(char(EEG.subject));
    end
end
if isempty(subjectId)
    subjectId = fallback;
end
end

function [brainProb, hasIcLabel] = local_get_brain_probabilities(EEG, nIc)
brainProb = nan(nIc,1);
hasIcLabel = false;
if ~isfield(EEG, 'etc') || ~isfield(EEG.etc, 'ic_classification') || ...
        ~isfield(EEG.etc.ic_classification, 'ICLabel')
    return
end
iclabel = EEG.etc.ic_classification.ICLabel;
if ~isfield(iclabel, 'classifications') || isempty(iclabel.classifications)
    return
end

brainColumn = 1;
if isfield(iclabel, 'classes') && ~isempty(iclabel.classes)
    classes = iclabel.classes;
    if isstring(classes), classes = cellstr(classes); end
    idx = find(strcmpi(classes, 'Brain'), 1);
    if ~isempty(idx), brainColumn = idx; end
end

if size(iclabel.classifications,1) < nIc || size(iclabel.classifications,2) < brainColumn
    return
end
brainProb = iclabel.classifications(1:nIc, brainColumn);
hasIcLabel = true;
end

function m = local_get_moment(model, dipoleNumber)
m = [NaN NaN NaN];
if ~isfield(model, 'momxyz') || isempty(model.momxyz)
    return
end
if size(model.momxyz,2) == 3 && size(model.momxyz,1) >= dipoleNumber
    m = model.momxyz(dipoleNumber,:);
end
end
