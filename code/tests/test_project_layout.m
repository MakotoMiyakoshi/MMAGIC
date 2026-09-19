function tests = test_project_layout
tests = functiontests(localfunctions);
end

function testProjectRootContainsOnlyCodeOrPnumberDirectories(testCase)
testDir = fileparts(mfilename('fullpath'));
codeRoot = fileparts(testDir);
projectRoot = fileparts(codeRoot);

entries = dir(projectRoot);
names = {entries.name};
isDot = ismember(names, {'.','..','.git'});
entries = entries(~isDot);

for idx = 1:numel(entries)
    verifyTrue(testCase, entries(idx).isdir, ...
        sprintf('Project-root files are forbidden: %s', entries(idx).name));
    name = entries(idx).name;
    isCode = strcmp(name, 'code');
    isPnumber = ~isempty(regexp(name, '^p\d{4}(?:_|$)', 'once'));
    verifyTrue(testCase, isCode || isPnumber, ...
        sprintf('Forbidden project-root directory: %s', name));
end
end

function testCodeRootMatlabFilesArePnumbered(testCase)
testDir = fileparts(mfilename('fullpath'));
codeRoot = fileparts(testDir);
entries = dir(fullfile(codeRoot, '*.m'));

for idx = 1:numel(entries)
    verifyNotEmpty(testCase, regexp(entries(idx).name, '^p\d{4}_.+\.m$', 'once'), ...
        sprintf('MATLAB files directly under code/ must be p-numbered: %s', entries(idx).name));
end
end
