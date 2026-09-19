# Colin27-unified forward-model rebuild

This document records the implementation boundary for the experimental MMAGIC distributed-source forward-model work.

## Project layout

MMAGIC follows the Makoto Project Layout Rule documented in `code/docs/PROJECT_STRUCTURE.md`.

Pipeline entry points are:

- `code/p1200_inspect_colin27_resources.m`
- `code/p1210_build_colin27_bscr_headmodels.m`

Their generated output directories are exact basename matches at the project root:

- `p1200_inspect_colin27_resources/`
- `p1210_build_colin27_bscr_headmodels/`

Those output directories are script-generated only and are rebuilt from scratch by the corresponding pipeline script.

## Fixed design choices

- Anatomy/geometry lineage: DIPFIT `standard_BEM` (Colin27 / BrainWeb-derived three-layer BEM).
- Electrode template: DIPFIT `standard_BEM/elec/standard_1005.elc`, resolved from the active DIPFIT installation rather than a machine-specific path.
- Brain conductivity: 0.33 S/m.
- Scalp conductivity: 0.33 S/m.
- Brain-to-skull conductivity ratio (BSCR): **20, 40, and 80**.
- Each BSCR condition receives a separately recomputed BEM solution. A conductivity field on a precomputed BEM is never edited in place and treated as a new solution.
- All three BSCR models use identical boundary geometry.

| BSCR | brain (S/m) | skull (S/m) | scalp (S/m) |
|---:|---:|---:|---:|
| 20 | 0.33 | 0.0165 | 0.33 |
| 40 | 0.33 | 0.00825 | 0.33 |
| 80 | 0.33 | 0.004125 | 0.33 |

## Scientific choices that remain open

The code must not silently decide:

- volumetric gray-matter grid, cortical surface, or hybrid source space;
- source spacing;
- gray-matter inclusion rule;
- cortex-only vs deep gray-matter inclusion;
- free 3-D orientation vs surface-normal constraint;
- cerebellum inclusion/exclusion.

## p1200 resource audit

`code/p1200_inspect_colin27_resources.m` resolves EEGLAB, DIPFIT, and FieldTrip from the MATLAB path, inspects the DIPFIT Colin27 resources, inventories candidate local anatomical resources, and stops before source-space generation.

## p1210 BSCR head-model generation

`code/p1210_build_colin27_bscr_headmodels.m` extracts only the boundary geometry from DIPFIT `standard_vol.mat`, rebuilds separate BEM solutions for BSCR 20/40/80, validates unchanged geometry and the requested conductivities, and writes provenance with each model.

## Deferred stages

The following remain intentionally deferred until the source-space decision is explicit:

1. Colin27-derived source-space generation.
2. Leadfield calculation for each BSCR model.
3. eLORETA inverse-kernel construction for each BSCR model.
4. Direct-kernel vs FieldTrip rank-1 numerical regression.
5. Legacy LORETA-Talairach-BAs vs Colin27 comparison.
6. AAL membership on the new distributed source representation.
