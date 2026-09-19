function spec = mmagic_bscr_spec(varargin)
% MMAGIC_BSCR_SPEC Return conductivity specifications for MMAGIC head models.
%
% spec = mmagic_bscr_spec()
% spec = mmagic_bscr_spec('BSCR', [20 40 80], ...
%                         'BrainConductivity', 0.33, ...
%                         'ScalpConductivity', 0.33)
%
% BSCR is defined as brain conductivity divided by skull conductivity.
% Conductivity units are siemens per metre (S/m).

parser = inputParser;
parser.FunctionName = mfilename;
addParameter(parser, 'BSCR', [20 40 80], @(x) isnumeric(x) && isvector(x) && all(isfinite(x)) && all(x > 0));
addParameter(parser, 'BrainConductivity', 0.33, @(x) isnumeric(x) && isscalar(x) && isfinite(x) && x > 0);
addParameter(parser, 'ScalpConductivity', 0.33, @(x) isnumeric(x) && isscalar(x) && isfinite(x) && x > 0);
parse(parser, varargin{:});

bscr = double(parser.Results.BSCR(:)');
brainCond = double(parser.Results.BrainConductivity);
scalpCond = double(parser.Results.ScalpConductivity);

if numel(unique(bscr)) ~= numel(bscr)
    error('mmagic_bscr_spec:DuplicateBSCR', 'BSCR values must be unique.');
end

spec = repmat(struct( ...
    'bscr', [], ...
    'brain_S_per_m', [], ...
    'skull_S_per_m', [], ...
    'scalp_S_per_m', []), 1, numel(bscr));

for idx = 1:numel(bscr)
    spec(idx).bscr = bscr(idx);
    spec(idx).brain_S_per_m = brainCond;
    spec(idx).skull_S_per_m = brainCond / bscr(idx);
    spec(idx).scalp_S_per_m = scalpCond;
end
end
