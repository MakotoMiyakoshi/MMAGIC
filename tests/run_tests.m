% RUN_TESTS Run the synthetic legacy-core test suite.
repoRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(repoRoot, 'legacy'));
results = runtests(fullfile(repoRoot, 'tests', 'test_legacy_core.m'));
disp(results)
assert(all([results.Passed]), 'One or more tests failed.');
