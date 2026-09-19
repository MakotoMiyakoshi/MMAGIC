function tests = test_legacy_core
tests = functiontests(localfunctions);
end

function testCollectsSingleBilateralMissingAndNaN(testCase)
root = local_make_synthetic_set_files();
cleanup = onCleanup(@() rmdir(root, 's')); %#ok<NASGU>

db = legacy_collect_ica_sets(root, 'LoaderFunction', @fake_loader);
verifyEqual(testCase, height(db.datasets), 3);
verifyEqual(testCase, height(db.ics), 6);
verifyEqual(testCase, height(db.dipoles), 5);

% Dataset 1, IC 2 is bilateral: one IC identity, two source-model rows.
icUid = 'D0001_IC0002';
verifyEqual(testCase, sum(strcmp(db.ics.ic_uid, icUid)), 1);
verifyEqual(testCase, sum(strcmp(db.dipoles.ic_uid, icUid)), 2);

% Dataset 2 has no DIPFIT at all; both IC identities are preserved.
verifyEqual(testCase, sum(db.ics.dataset_id == 2 & db.ics.n_dipoles == 0), 2);

% Dataset 3 contains one NaN coordinate and one midline coordinate.
verifyEqual(testCase, sum(~isfinite(db.dipoles.x)), 1);
verifyEqual(testCase, sum(db.dipoles.x == 0), 1);
end

function testAalAssignmentExactAndDistances(testCase)
root = local_make_synthetic_set_files();
cleanup = onCleanup(@() rmdir(root, 's')); %#ok<NASGU>

db = legacy_collect_ica_sets(root, 'LoaderFunction', @fake_loader);
atlas = fake_aal_atlas();
db = legacy_assign_aal_rois(db, 'Atlas', atlas);

verifyEqual(testCase, db.roi.labels, {'Region_L','Region_R'});
verifyEqual(testCase, size(db.roi.distance_mm), [5 2]);
verifyEqual(testCase, sum(strcmp(db.dipoles.roi_assignment_status, 'exact')), 3);
verifyEqual(testCase, sum(strcmp(db.dipoles.roi_assignment_status, 'nearest_only')), 1);
verifyEqual(testCase, sum(strcmp(db.dipoles.roi_assignment_status, 'invalid_xyz')), 1);

% First dipole is exactly in left AAL ROI.
verifyEqual(testCase, db.dipoles.aal_label{1}, 'Region_L');
verifyEqual(testCase, db.roi.distance_mm(1,1), 0, 'AbsTol', 1e-12);

% Midline dipole lies in atlas background and is 1 mm from both ROIs.
midlineRow = find(db.dipoles.x == 0, 1, 'first');
verifyEqual(testCase, db.dipoles.aal_label{midlineRow}, '');
verifyEqual(testCase, db.roi.distance_mm(midlineRow,:), [1 1], 'AbsTol', 1e-12);
verifyEqual(testCase, db.dipoles.nearest_roi_distance_mm(midlineRow), 1, 'AbsTol', 1e-12);
end

function testExactAndToleranceBasedSelection(testCase)
root = local_make_synthetic_set_files();
cleanup = onCleanup(@() rmdir(root, 's')); %#ok<NASGU>

db = legacy_collect_ica_sets(root, 'LoaderFunction', @fake_loader);
db = legacy_assign_aal_rois(db, 'Atlas', fake_aal_atlas());

leftExact = legacy_select_roi(db, 'Region_L');
rightExact = legacy_select_roi(db, 'Region_R');
leftNear = legacy_select_roi(db, 'Region_L', 'MaxDistanceMm', 1, ...
    'Hemisphere', 'Left', 'BoundaryPolicy', 'historical');

verifyEqual(testCase, height(leftExact.hits), 2);
verifyEqual(testCase, height(rightExact.hits), 1);
verifyEqual(testCase, height(leftNear.hits), 3); % includes x=0 background dipole at 1 mm
verifyTrue(testCase, all(leftExact.hits.is_exact_membership));
verifyEqual(testCase, max(leftNear.hits.roi_distance_mm), 1, 'AbsTol', 1e-12);

% A bilateral IC contributes one hit per side but remains one IC identity.
bilateralUid = 'D0001_IC0002';
verifyEqual(testCase, sum(strcmp(leftExact.hits.ic_uid, bilateralUid)), 1);
verifyEqual(testCase, sum(strcmp(rightExact.hits.ic_uid, bilateralUid)), 1);
verifyEqual(testCase, sum(strcmp(leftExact.ics.ic_uid, bilateralUid)), 1);
verifyEqual(testCase, sum(strcmp(rightExact.ics.ic_uid, bilateralUid)), 1);
end

function testHemisphereBoundaryPolicies(testCase)
root = local_make_synthetic_set_files();
cleanup = onCleanup(@() rmdir(root, 's')); %#ok<NASGU>

db = legacy_collect_ica_sets(root, 'LoaderFunction', @fake_loader);
db = legacy_assign_aal_rois(db, 'Atlas', fake_aal_atlas());

histLeft = legacy_select_roi(db, 'Region_L', 'MaxDistanceMm', 1, ...
    'Hemisphere', 'Left', 'BoundaryPolicy', 'historical');
histRight = legacy_select_roi(db, 'Region_R', 'MaxDistanceMm', 1, ...
    'Hemisphere', 'Right', 'BoundaryPolicy', 'historical');
strictLeft = legacy_select_roi(db, 'Region_L', 'MaxDistanceMm', 1, ...
    'Hemisphere', 'Left', 'BoundaryPolicy', 'strict');
strictRight = legacy_select_roi(db, 'Region_R', 'MaxDistanceMm', 1, ...
    'Hemisphere', 'Right', 'BoundaryPolicy', 'strict');
midlineLeft = legacy_select_roi(db, 'Region_L', 'MaxDistanceMm', 1, ...
    'Hemisphere', 'Midline', 'BoundaryPolicy', 'strict');

midlineUid = 'D0003_IC0002';
verifyEqual(testCase, sum(strcmp(histLeft.ics.ic_uid, midlineUid)), 1);
verifyEqual(testCase, sum(strcmp(histRight.ics.ic_uid, midlineUid)), 1);
verifyEqual(testCase, sum(strcmp(strictLeft.ics.ic_uid, midlineUid)), 0);
verifyEqual(testCase, sum(strcmp(strictRight.ics.ic_uid, midlineUid)), 0);
verifyEqual(testCase, sum(strcmp(midlineLeft.ics.ic_uid, midlineUid)), 1);
end

function testMultipleICsSameSubjectAndValidation(testCase)
root = local_make_synthetic_set_files();
cleanup = onCleanup(@() rmdir(root, 's')); %#ok<NASGU>

db = legacy_collect_ica_sets(root, 'LoaderFunction', @fake_loader);
db = legacy_assign_aal_rois(db, 'Atlas', fake_aal_atlas());
report = legacy_validate_database(db);

verifyTrue(testCase, report.is_valid);
verifyGreaterThan(testCase, report.n_warnings, 0); % missing DIPFIT + NaN are warnings
verifyEqual(testCase, sum(strcmp(db.ics.subject_id, 'S01')), 2);
verifyEqual(testCase, numel(unique(db.ics.ic_uid(strcmp(db.ics.subject_id, 'S01')))), 2);
end

function testOptionalICLabelAndRVFiltering(testCase)
root = tempname;
mkdir(root);
cleanup = onCleanup(@() rmdir(root, 's')); %#ok<NASGU>
fclose(fopen(fullfile(root, 'synthetic1.set'), 'w'));

db = legacy_collect_ica_sets(fullfile(root, 'synthetic1.set'), ...
    'LoaderFunction', @fake_loader, ...
    'ICLabelBrainThreshold', 0.70, ...
    'ResidualVarianceThreshold', 0.15);

verifyEqual(testCase, height(db.ics), 1);
verifyEqual(testCase, db.ics.ic_index, 1);
end

function testUnknownRoiIsRejected(testCase)
root = local_make_synthetic_set_files();
cleanup = onCleanup(@() rmdir(root, 's')); %#ok<NASGU>

db = legacy_collect_ica_sets(root, 'LoaderFunction', @fake_loader);
db = legacy_assign_aal_rois(db, 'Atlas', fake_aal_atlas());
verifyError(testCase, @() legacy_select_roi(db, 'NotAnAalRegion'), 'legacy_select_roi:UnknownROI');
end

function testDirectVoxelLookupAndAnisotropicMillimetres(testCase)
root = local_make_synthetic_set_files();
cleanup = onCleanup(@() rmdir(root, 's')); %#ok<NASGU>
db = legacy_collect_ica_sets(root, 'LoaderFunction', @fake_loader);

% A one-voxel ROI on a deliberately anisotropic 2 x 3 x 4 mm grid.
atlas = struct();
atlas.dim = [4 4 4];
atlas.transform = diag([2 3 4 1]);
atlas.unit = 'mm';
atlas.coordsys = 'mni';
atlas.tissue = zeros(atlas.dim);
atlas.tissue(2,2,2) = 1;
atlas.tissuelabel = {'Region_A'};

db.dipoles.x(1:2) = [4; 6];
db.dipoles.y(1:2) = [6; 6];
db.dipoles.z(1:2) = [8; 8];
db = legacy_assign_aal_rois(db, 'Atlas', atlas);

verifyEqual(testCase, db.dipoles.aal_voxel_i(1), 2);
verifyEqual(testCase, db.dipoles.aal_voxel_j(1), 2);
verifyEqual(testCase, db.dipoles.aal_voxel_k(1), 2);
verifyEqual(testCase, db.dipoles.aal_label{1}, 'Region_A');
verifyEqual(testCase, db.roi.distance_mm(1,1), 0, 'AbsTol', 1e-12);
verifyEqual(testCase, db.dipoles.aal_label{2}, '');
verifyEqual(testCase, db.roi.distance_mm(2,1), 2, 'AbsTol', 1e-12);
end

function root = local_make_synthetic_set_files()
root = tempname;
mkdir(root);
for k = 1:3
    fclose(fopen(fullfile(root, sprintf('synthetic%d.set', k)), 'w'));
end
end

function EEG = fake_loader(setFile)
[~, name] = fileparts(setFile);
EEG = struct();
EEG.icaweights = eye(2);
EEG.icasphere = eye(2);
EEG.icawinv = eye(2);
EEG.icachansind = 1:2;
EEG.chanlocs = struct('labels', {'Cz','Pz'});
EEG.etc.ic_classification.ICLabel.classes = {'Brain','Muscle','Eye','Heart','Line Noise','Channel Noise','Other'};
EEG.etc.ic_classification.ICLabel.classifications = [0.90 0.02 0.02 0.01 0.01 0.01 0.03; ...
                                                      0.60 0.10 0.10 0.05 0.05 0.05 0.05];

switch name
    case 'synthetic1'
        EEG.subject = 'S01';
        EEG.dipfit.model(1).posxyz = [-2 0 0];
        EEG.dipfit.model(1).momxyz = [1 0 0];
        EEG.dipfit.model(1).rv = 0.10;
        EEG.dipfit.model(2).posxyz = [-1 0 0; 1 0 0];
        EEG.dipfit.model(2).momxyz = [0 1 0; 0 -1 0];
        EEG.dipfit.model(2).rv = 0.15;
    case 'synthetic2'
        EEG.subject = 'S02';
        % Entire dataset deliberately lacks EEG.dipfit.
    case 'synthetic3'
        EEG.subject = 'S03';
        EEG.dipfit.model(1).posxyz = [NaN NaN NaN];
        EEG.dipfit.model(1).momxyz = [NaN NaN NaN];
        EEG.dipfit.model(1).rv = 0.05;
        EEG.dipfit.model(2).posxyz = [0 0 0];
        EEG.dipfit.model(2).momxyz = [0 0 1];
        EEG.dipfit.model(2).rv = 0.08;
    otherwise
        error('Unknown synthetic dataset.');
end
end

function atlas = fake_aal_atlas()
% 7 x 5 x 5 synthetic MNI atlas with a 1-mm grid.
% Physical x coordinates are -3:-1, 0, 1:3. x=0 is background.
atlas = struct();
atlas.dim = [7 5 5];
atlas.transform = [1 0 0 -4; 0 1 0 -3; 0 0 1 -3; 0 0 0 1];
atlas.unit = 'mm';
atlas.coordsys = 'mni';
atlas.tissue = zeros(atlas.dim);
atlas.tissue(1:3,:,:) = 1;
atlas.tissue(5:7,:,:) = 2;
atlas.tissuelabel = {'Region_L'; 'Region_R'};
end
