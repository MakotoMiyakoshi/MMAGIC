# MMAGIC

**MMAGIC: Multi-Model Anatomical Grouping of Independent Components**

A minimal MATLAB reference implementation for organizing independent components (ICs) across multiple ICA-completed EEGLAB datasets using **anatomical source location as the cross-subject correspondence rule**.

The current release provides a legacy DIPFIT/AAL baseline while keeping the database design compatible with future source representations. It intentionally avoids embedding study-specific data, identifiers, statistics, or source files.

## Purpose

```text
ICA-completed EEGLAB .set files
        |
        v
IC identities across datasets
        |
        v
DIPFIT equivalent-dipole source-model entries
        |
        v
direct FieldTrip AAL voxel membership + distance-to-ROI
        |
        v
ROI membership across subjects
```

MMAGIC is intended for anatomical bookkeeping across subjects, scientific validation, comparison across source-model choices, and regression testing. The present implementation does **not** claim that single equivalent dipoles are the preferred source model.

## Current reference implementation

The current public baseline uses:

- EEGLAB ICA-completed `.set` files as input;
- DIPFIT equivalent-dipole locations as the source representation;
- FieldTrip's AAL atlas for anatomical grouping;
- direct voxel membership as the production assignment rule;
- physical MNI-millimeter distance to discrete AAL voxels as an explicit proximity measure.

The anatomical assignment layer is intentionally transparent: production assignment reads `aal.tissue` after mapping MNI coordinates through `aal.transform`. `ft_volumelookup` is used only as an independent validation reference.

## What this package does

- Preserves dataset, subject, and IC identity in aligned tables.
- Collects DIPFIT coordinates and residual variance when available.
- Represents bilateral DIPFIT models as multiple source-model rows linked to one IC identity.
- Optionally records/filters ICLabel brain probability.
- Optionally filters DIPFIT residual variance using a **strict** threshold (`rv < threshold`).
- Loads FieldTrip's bundled AAL atlas with `ft_read_atlas`.
- Uses `aal.transform` and `aal.tissue` for direct MNI-coordinate-to-AAL labeling.
- Uses `ft_volumelookup` only as an independent validation reference.
- Stores distance from every dipole to every AAL ROI as first-class aligned data.
- Selects ICs/dipoles by AAL ROI with an explicit distance tolerance.
- Validates key database identity/linkage and ROI-distance invariants.

## What this package does NOT do

- preprocessing,
- ICA computation,
- DIPFIT fitting,
- EEGLAB STUDY clustering,
- group statistics,
- automatic subject-level reduction of multiple ICs,
- distributed source localization.

## Requirements

- MATLAB. The current validation environment used MATLAB R2024b Update 3; earlier releases have not been systematically tested.
- EEGLAB for reading real `.set` files (`pop_loadset`).
- DIPFIT results in `EEG.dipfit.model` if source-model analysis is desired.
- FieldTrip, including `ft_read_atlas`, `ft_volumelookup`, `ft_convert_units`, and the bundled AAL atlas `template/atlas/aal/ROI_MNI_V4.nii`.
- ICLabel is optional.

## Quick start

```matlab
addpath('/path/to/MMAGIC/legacy')

setFolder = '/path/to/ica_completed_sets';

db = legacy_collect_ica_sets(setFolder);
db = legacy_assign_aal_rois(db);

selection = legacy_select_roi(db, 'Parietal_Inf_L', ...
    'MaxDistanceMm', 0);

report = legacy_validate_database(db);
```

`MaxDistanceMm = 0` means exact AAL membership only. A positive value explicitly expands the anatomical correspondence rule.

No hidden ICLabel or residual-variance threshold is imposed by default.

## Output structure

### `db.datasets`

One row per `.set` file: dataset/subject identity, filename/path, ICA dimensions, DIPFIT/ICLabel availability, ICA weights/sphere, channel indices, and channel locations.

### `db.ics`

One row per IC identity: dataset/subject identity, IC index, ICLabel brain probability if available, DIPFIT residual variance if available, number of linked source-model entries, and scalp projection when available.

### `db.dipoles`

One row per DIPFIT source-model entry. Important fields include:

- `subject_id`, `ic_uid`, `ic_index`, `dipole_number`,
- `x`, `y`, `z` in the DIPFIT/MNI coordinate frame,
- `residual_variance`,
- `aal_label`, `aal_index`,
- `nearest_roi_label`, `nearest_roi_index`, `nearest_roi_distance_mm`,
- `roi_assignment_status`.

A two-dipole model gives **one `db.ics` row and two `db.dipoles` rows**.

### `db.roi`

```matlab
db.roi.labels       % 1 x nROI AAL labels
db.roi.values       % corresponding atlas integer values
db.roi.distance_mm  % nDipoles x nROI distance matrix
```

Rows of `db.roi.distance_mm` are aligned exactly with `db.dipoles`.

## ROI assignment method

`legacy_assign_aal_rois` maps MNI millimetres into atlas voxel coordinates and reads the parcel value directly:

```matlab
ijk1 = aal.transform \ [xyzMniMm(:); 1];
ijk = round(ijk1(1:3));
aalValue = aal.tissue(ijk(1), ijk(2), ijk(3));
```

It separately computes Euclidean distance in physical MNI millimeters from the dipole coordinate to each AAL ROI. Distances are measured to the centers of discrete AAL voxels after applying the atlas affine transformation. Exact membership is represented as 0 mm.

The implementation searches ROI boundary voxels rather than all interior voxels; for a point outside an ROI, the nearest ROI voxel lies on the ROI boundary.

## Bilateral dipole handling

MMAGIC separates **IC identity** from **source-model identity**. A bilateral DIPFIT model therefore remains one IC linked to two source rows rather than becoming two apparent IC observations.

## Analysis unit

The package stops at ROI membership. Downstream analysis must explicitly choose whether the analysis unit is IC or subject. If multiple ICs from one subject fall in the same ROI, subject-level aggregation must define its rule explicitly.

## Scientific caveats

- Equivalent dipole fitting can exhibit systematic localization and depth bias.
- AAL is a macroscopic volumetric parcellation, not a generative EEG source model.
- Direct voxel assignment depends on the declared rounding convention.
- Atlas-boundary locations can be sensitive to nearest-voxel tie behavior.
- Distance means distance to the centers of discrete AAL voxels in physical MNI millimeters, not continuous cortical-surface distance.
- Historical atlas lookup methods are not expected to reproduce the current AAL labels exactly.
- Group statistics are deliberately outside the core package.
- Distributed source models are future work.

## Relation to future source models

The database design is intended to allow cortex-constrained distributed source representations to be attached to the same stable IC identity without changing cross-subject bookkeeping. A relevant precedent for fixed cortical source-space group analysis is Courellis H, Mullen T, Poizner H, Cauwenberghs G, Iversen JR. *Frontiers in Neuroscience*. 2017;11:180. DOI: 10.3389/fnins.2017.00180.

## Validation summary

Real-data validation was completed on 22 ICA/DIPFIT datasets comprising 710 ICs and 712 source entries. The public summary reports aggregate results only:

- synthetic tests: 8/8 passed;
- independent distance checks: 15/15 passed;
- boundary-voxel optimization checks: 40/40 passed;
- FieldTrip comparison: 28/30 agreement, with two documented nearest-voxel tie cases at atlas boundaries;
- database identity/linkage checks: passed.

Overall validation verdict: **PASS WITH DOCUMENTED LIMITATIONS**.

See `docs/validation_report.md` and `docs/regression_validation.md`.

```matlab
run('tests/run_tests.m')
```

## License

GNU General Public License v3.0. See `LICENSE`.
