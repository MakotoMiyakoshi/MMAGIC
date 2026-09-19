# Colin27-unified forward-model rebuild

This document records the implementation boundary for the experimental MMAGIC distributed-source forward-model work.

## Fixed design choices

- Anatomy/geometry lineage: DIPFIT `standard_BEM` (Colin27 / BrainWeb-derived three-layer BEM).
- Electrode template: DIPFIT `standard_BEM/elec/standard_1005.elc`, resolved from the active DIPFIT installation rather than a machine-specific path.
- Brain conductivity: 0.33 S/m.
- Scalp conductivity: 0.33 S/m.
- Brain-to-skull conductivity ratio (BSCR): **20, 40, and 80**.
- Each BSCR condition receives a separately recomputed BEM solution. A conductivity field on a precomputed BEM is never edited in place and treated as a new solution.
- All three BSCR models use identical boundary geometry.

The corresponding skull conductivities are:

| BSCR | brain (S/m) | skull (S/m) | scalp (S/m) |
|---:|---:|---:|---:|
| 20 | 0.33 | 0.0165 | 0.33 |
| 40 | 0.33 | 0.00825 | 0.33 |
| 80 | 0.33 | 0.004125 | 0.33 |

## Scientific choices that remain open

The code must not silently decide any of the following:

- volumetric gray-matter grid, cortical surface, or hybrid source space;
- source spacing (for example, 5 mm vs 7 mm);
- gray-matter inclusion rule;
- cortex-only vs deep gray-matter inclusion;
- free 3-D orientation vs surface-normal constraint;
- cerebellum inclusion/exclusion.

These choices affect the scientific interpretation of ROI membership and therefore require an explicit decision after local Colin27 resources are inspected.

## Implemented pipeline stages

### p1200: resource audit

`pipelines/p1200_inspect_colin27_resources.m`

- resolves EEGLAB, DIPFIT, and FieldTrip from the MATLAB path;
- inspects DIPFIT `standard_mri.mat` and `standard_vol.mat`;
- inventories candidate Colin27/BrainWeb segmentation, surface, MRI, and source-model resources in local FieldTrip template directories;
- records BEM boundary order, stored conductivity, units, coordinate-system metadata, and whether a precomputed BEM matrix is present;
- writes reports to `p1200/`;
- stops before source-space generation.

### p1210: BSCR head-model generation

`pipelines/p1210_build_colin27_bscr_headmodels.m`

- extracts only the boundary geometry from DIPFIT `standard_vol.mat`;
- determines brain/skull/scalp boundaries from enclosed mesh volume rather than assuming array order;
- preserves the reference BEM method unless an explicit override is supplied;
- rebuilds the BEM solution separately for BSCR 20, 40, and 80;
- validates that geometry is unchanged and that the rebuilt conductivity vector produces the requested BSCR;
- writes separate model artifacts and a manifest to `p1210/`.

## Deferred stages

The following stages are intentionally not implemented until the source-space decision is made:

1. Colin27-derived source-space generation.
2. Leadfield calculation for each BSCR model.
3. eLORETA inverse-kernel construction for each BSCR model.
4. Direct-kernel vs FieldTrip rank-1 numerical regression.
5. Legacy LORETA-Talairach-BAs vs Colin27 model comparison.
6. AAL membership on the new distributed source representation.

Once the source space is fixed, the intended model grid is:

```text
                         Colin27 source space
                                  |
                 +----------------+----------------+
                 |                |                |
              BSCR 20          BSCR 40          BSCR 80
                 |                |                |
               BEM20            BEM40            BEM80
                 |                |                |
                G20              G40              G80
                 |                |                |
             eLORETA20        eLORETA40        eLORETA80
```

The separation of anatomy from conductivity is deliberate: it allows MMAGIC to quantify how much ROI membership and distributed-source summaries depend on uncertainty in skull conductivity while keeping source-space anatomy fixed.
