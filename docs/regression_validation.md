# Regression validation status

## Two separate validation questions

The implementation intentionally distinguishes **identity/source-model preservation** from **anatomical-label equivalence**.

### Expected to reproduce structurally

Across equivalent source datasets, pipelines should agree on:

- subject identity;
- IC index;
- DIPFIT coordinate;
- bilateral source-model identity and count.

The MMAGIC database stores bilateral source entries without duplicating the IC itself.

### Not expected to reproduce exactly

Anatomical labels are not expected to reproduce older atlas/lookup systems exactly because the current implementation uses direct FieldTrip AAL voxel membership. Such differences are redesign rather than regression failure.

## Synthetic coverage

`tests/test_legacy_core.m` covers:

1. one-dipole IC;
2. bilateral/two-dipole IC;
3. missing DIPFIT;
4. NaN xyz;
5. exact AAL membership;
6. atlas-background coordinate with nearest ROI distance;
7. hemisphere behavior;
8. boundary-policy behavior;
9. multiple ICs from the same subject;
10. optional ICLabel filtering;
11. strict residual-variance filtering (`rv < threshold`);
12. aligned distance-matrix validation;
13. physical-millimeter distance on an anisotropic synthetic grid.

The synthetic atlas permits core database and affine-distance logic to be tested without a local FieldTrip installation.

## Empirical validation summary

Aggregate validation used 22 ICA/DIPFIT datasets containing 710 IC identities and 712 source rows. Database identity/alignment checks passed. Thirty representative source coordinates were compared with an independent FieldTrip lookup; 28 agreed and two atlas-boundary tie cases differed. All 15 independent all-voxel distance checks and all 40 boundary-versus-all-voxel optimization checks passed.

Row-level real-data identifiers and local validation paths are deliberately not included in the public repository.
