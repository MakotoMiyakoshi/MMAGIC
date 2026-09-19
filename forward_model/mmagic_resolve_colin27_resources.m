function resources = mmagic_resolve_colin27_resources(varargin)
% MMAGIC_RESOLVE_COLIN27_RESOURCES Resolve EEGLAB/DIPFIT/FieldTrip resources.
%
% This function intentionally contains no machine-specific paths. EEGLAB,
% DIPFIT, and FieldTrip must already be on the MATLAB path.

parser = inputParser;
parser.FunctionName = mfilename;
addParameter(parser, 'RequireFieldTrip', true, @(x) islogical(x) && isscalar(x));
parse(parser, varargin{:});
requireFieldTrip = parser.Results.RequireFieldTrip;

resources = struct();
resources.eeglab_file = which('eeglab.m');
resources.dipfitdefs_file = which('dipfitdefs.m');
resources.fieldtrip_defaults_files = which('ft_defaults.m', '-all');
resources.pop_leadfield_file = which('pop_leadfield.m');
resources.ft_prepare_sourcemodel_file = which('ft_prepare_sourcemodel.m');
resources.ft_prepare_leadfield_file = which('ft_prepare_leadfield.m');
resources.ft_prepare_headmodel_file = which('ft_prepare_headmodel.m');
resources.ft_volumesegment_file = which('ft_volumesegment.m');
resources.ft_read_mri_file = which('ft_read_mri.m');

if isempty(resources.eeglab_file)
    error('mmagic_resolve_colin27_resources:EEGLABNotFound', ...
        'eeglab.m was not found on the MATLAB path.');
end
if isempty(resources.dipfitdefs_file)
    error('mmagic_resolve_colin27_resources:DIPFITNotFound', ...
        'dipfitdefs.m was not found on the MATLAB path.');
end
if requireFieldTrip && isempty(resources.ft_prepare_headmodel_file)
    error('mmagic_resolve_colin27_resources:FieldTripNotFound', ...
        'ft_prepare_headmodel.m was not found on the MATLAB path.');
end

resources.eeglab_root = fileparts(resources.eeglab_file);
resources.dipfit_root = fileparts(resources.dipfitdefs_file);
resources.standard_bem_dir = fullfile(resources.dipfit_root, 'standard_BEM');
resources.standard_mri_file = fullfile(resources.standard_bem_dir, 'standard_mri.mat');
resources.standard_vol_file = fullfile(resources.standard_bem_dir, 'standard_vol.mat');
resources.standard_1005_file = fullfile(resources.standard_bem_dir, 'elec', 'standard_1005.elc');

resources.fieldtrip_roots = {};
if ~isempty(resources.fieldtrip_defaults_files)
    if ischar(resources.fieldtrip_defaults_files)
        resources.fieldtrip_defaults_files = {resources.fieldtrip_defaults_files};
    end
    resources.fieldtrip_roots = cellfun(@fileparts, resources.fieldtrip_defaults_files, 'UniformOutput', false);
    resources.fieldtrip_roots = unique(resources.fieldtrip_roots, 'stable');
end

requiredFiles = {'standard_mri_file','standard_vol_file','standard_1005_file'};
for idx = 1:numel(requiredFiles)
    fieldName = requiredFiles{idx};
    if ~isfile(resources.(fieldName))
        error('mmagic_resolve_colin27_resources:MissingDIPFITResource', ...
            'Required DIPFIT resource does not exist: %s', resources.(fieldName));
    end
end
end
