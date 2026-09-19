% RUN_TESTS Run all synthetic MMAGIC tests.
repoRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(repoRoot, 'legacy'));
addpath(fullfile(repoRoot, 'forward_model'));
results = runtests(fullfile(repoRoot, 'tests'));
disp(results)
assert(all([results.Passed]), 'One or more tests failed.');
