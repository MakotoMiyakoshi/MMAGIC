function tests = test_forward_model_core
tests = functiontests(localfunctions);
end

function testDefaultBSCRSpecification(testCase)
spec = mmagic_bscr_spec();
verifyEqual(testCase, [spec.bscr], [20 40 80]);
verifyEqual(testCase, [spec.brain_S_per_m], [0.33 0.33 0.33], 'AbsTol', 1e-12);
verifyEqual(testCase, [spec.skull_S_per_m], [0.0165 0.00825 0.004125], 'AbsTol', 1e-12);
verifyEqual(testCase, [spec.scalp_S_per_m], [0.33 0.33 0.33], 'AbsTol', 1e-12);
end

function testBoundaryClassificationIgnoresInputOrder(testCase)
brain = local_tetrahedron(1);
skull = local_tetrahedron(2);
scalp = local_tetrahedron(3);

bnd = [scalp brain skull];
info = mmagic_classify_three_layer_boundaries(bnd);
verifyEqual(testCase, info.labels, {'scalp','brain','skull'});
verifyEqual(testCase, info.inside_to_outside_order, [2 3 1]);
verifyTrue(testCase, all(diff(info.sorted_enclosed_volume) > 0));
end

function testConductivityVectorFollowsBoundaryOrder(testCase)
spec = mmagic_bscr_spec('BSCR', 20);
labels = {'scalp','brain','skull'};
conductivity = mmagic_conductivity_vector(labels, spec);
verifyEqual(testCase, conductivity, [0.33 0.33 0.0165], 'AbsTol', 1e-12);
end

function testBEMMethodNormalization(testCase)
verifyEqual(testCase, mmagic_normalize_bem_method('bem_cp'), 'bemcp');
verifyEqual(testCase, mmagic_normalize_bem_method('bem_dipoli'), 'dipoli');
verifyEqual(testCase, mmagic_normalize_bem_method('bem_openmeeg'), 'openmeeg');
verifyError(testCase, @() mmagic_normalize_bem_method('unknown'), ...
    'mmagic_normalize_bem_method:UnsupportedMethod');
end

function testBSCRValidationOnSyntheticHeadmodel(testCase)
brain = local_tetrahedron(1);
skull = local_tetrahedron(2);
scalp = local_tetrahedron(3);

headmodel = struct();
headmodel.bnd = [scalp brain skull];
headmodel.cond = [0.33 0.33 0.00825];
headmodel.type = 'bemcp';
headmodel.unit = 'mm';
headmodel.coordsys = 'mni';

spec = mmagic_bscr_spec('BSCR', 40);
report = mmagic_validate_bscr_headmodel(headmodel, spec);
verifyTrue(testCase, report.is_valid);
verifyEqual(testCase, report.actual_bscr, 40, 'AbsTol', 1e-12);
verifyEqual(testCase, report.boundary_labels, {'scalp','brain','skull'});
end

function testDuplicateBSCRRejected(testCase)
verifyError(testCase, @() mmagic_bscr_spec('BSCR', [20 20]), ...
    'mmagic_bscr_spec:DuplicateBSCR');
end

function mesh = local_tetrahedron(scale)
mesh = struct();
mesh.pos = scale * [0 0 0; 1 0 0; 0 1 0; 0 0 1];
mesh.tri = [1 3 2; 1 2 4; 1 4 3; 2 3 4];
end
