function tests = test_rv_boundary
tests = functiontests(localfunctions);
end

function testStrictResidualVarianceThresholdExcludesEquality(testCase)
% Explicit regression test for historical RV semantics: retain only rv < threshold.
root = tempname;
mkdir(root);
cleanup = onCleanup(@() rmdir(root, 's')); %#ok<NASGU>
setFile = fullfile(root, 'rv_boundary.set');
fclose(fopen(setFile, 'w'));

db = legacy_collect_ica_sets(setFile, ...
    'LoaderFunction', @fake_rv_loader, ...
    'ResidualVarianceThreshold', 0.15);

% IC 1 has rv = 0.10 and must be retained.
% IC 2 has rv = 0.15 and must be excluded because the rule is strict (<), not <=.
verifyEqual(testCase, height(db.ics), 1);
verifyEqual(testCase, db.ics.ic_index, 1);
verifyEqual(testCase, db.ics.residual_variance, 0.10, 'AbsTol', 1e-12);
end

function EEG = fake_rv_loader(~)
EEG = struct();
EEG.subject = 'synthetic_rv_boundary';
EEG.icaweights = eye(2);
EEG.icasphere = eye(2);
EEG.icawinv = eye(2);
EEG.icachansind = 1:2;
EEG.chanlocs = struct('labels', {'Cz','Pz'});

EEG.dipfit.model(1).posxyz = [-2 0 0];
EEG.dipfit.model(1).momxyz = [1 0 0];
EEG.dipfit.model(1).rv = 0.10;

EEG.dipfit.model(2).posxyz = [2 0 0];
EEG.dipfit.model(2).momxyz = [-1 0 0];
EEG.dipfit.model(2).rv = 0.15;
end
