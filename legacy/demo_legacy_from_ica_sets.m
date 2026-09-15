% DEMO_LEGACY_FROM_ICA_SETS
% Minimal anatomical group-ICA reference workflow starting from
% ICA-completed EEGLAB .set files.
%
% Edit only the input folder and AAL ROI query below.

clear
clc

demoFolder = fileparts(mfilename('fullpath'));
addpath(demoFolder);

% 1) Point to a folder containing ICA-completed EEGLAB .set files.
setFolder = '/path/to/ica_completed_sets';

% 2) Collect aligned dataset, IC, and DIPFIT source-model identities.
% No ICLabel or residual-variance filtering is imposed by default. Optional
% examples are:
%   'ICLabelBrainThreshold', 0.70
%   'ResidualVarianceThreshold', 0.15
% Both thresholds are explicit parameters, never hidden defaults.
db = legacy_collect_ica_sets(setFolder);

% 3) Assign AAL labels using FieldTrip and compute distance-to-ROI.
% By default the bundled FieldTrip AAL atlas is discovered automatically:
%   <fieldtrip>/template/atlas/aal/ROI_MNI_V4.nii
% Every db.dipoles row receives an exact AAL label when present, and
% db.roi.distance_mm stores dipole-to-ROI distance for all AAL parcels.
db = legacy_assign_aal_rois(db);

% 4) Select a standard AAL parcel. MaxDistanceMm = 0 means exact atlas
% membership only. Increase explicitly (e.g., 5 or 10 mm) if the scientific
% question calls for a spatial tolerance around the atlas parcel.
selection = legacy_select_roi(db, 'Parietal_Inf_L', ...
                                  'MaxDistanceMm', 0);

% 5) Validate identity, bilateral source-model linkage, and ROI alignment.
report = legacy_validate_database(db);

disp(selection.hits)
disp(selection.ics(:, {'subject_id','ic_index','brain_probability','residual_variance','n_dipoles'}))
disp(report)

% A downstream analysis should explicitly choose its analysis unit (IC or
% subject) and its subject-level reduction rule. This package does not make
% that statistical decision for the user.
