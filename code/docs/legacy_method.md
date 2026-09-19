# Legacy method: preserved structure and intentional modernization

## Scientific role

The current MMAGIC release is a cleaned reference implementation of an earlier anatomical group-ICA workflow. Its central cross-subject correspondence rule is **anatomical source location** rather than EEGLAB STUDY IC clustering.

The current baseline uses DIPFIT equivalent dipoles as the source representation and FieldTrip AAL as the volumetric parcellation. Older study-specific scripts and obsolete atlas-lookup dependencies are not included in the public repository.

## Preserved concepts

The cleaned implementation preserves the reusable parts of the earlier workflow:

- cross-dataset IC identity bookkeeping;
- anatomical source-based correspondence;
- handling of bilateral source models;
- ROI selection for downstream analysis.

Study-specific ERP/ERSP analyses, condition structures, permutations, reports, and figures are intentionally excluded from the core.

## AAL assignment and distance-to-ROI

For each DIPFIT source entry, MMAGIC stores:

1. exact AAL membership when the coordinate falls in a labeled voxel;
2. nearest AAL ROI;
3. nearest-ROI distance in millimeters;
4. an aligned matrix containing distance to every AAL ROI.

The production assignment maps MNI coordinates through `aal.transform` and reads `aal.tissue` directly. `ft_volumelookup` is reserved for independent validation.

Distance is expressed in physical MNI millimeters to the centers of discrete atlas voxels. It is not a continuous cortical-surface distance.

## Bilateral DIPFIT redesign

The database separates:

- `db.ics`: exactly one row per IC identity;
- `db.dipoles`: zero, one, two, or more source-model rows linked by `ic_uid`.

Thus two fitted dipoles do not become two apparent independent components.

## Hemisphere boundary

`legacy_select_roi` supports both a historical x-coordinate boundary policy and a strict policy. Standard AAL labels already encode laterality, so this option is primarily retained for compatibility with earlier selection logic.

## Residual-variance semantics

When `ResidualVarianceThreshold` is supplied, MMAGIC applies a strict criterion:

```matlab
rv < threshold
```

No residual-variance threshold is imposed by default.

## Known limitation

Equivalent current dipole fitting can exhibit systematic localization and depth bias. This package is therefore a **legacy scientific baseline**, not a claim that a single equivalent dipole is the correct generative source model.

## Relation to distributed-source group analysis

A future solver-agnostic framework can attach cortex-constrained distributed source models to the same IC identity. Courellis et al. (2017) provide a relevant precedent for a fixed cortical source-space strategy using individually warped BEMs and cLORETA (*Frontiers in Neuroscience* 11:180; DOI: 10.3389/fnins.2017.00180).
