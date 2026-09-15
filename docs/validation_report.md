# Validation report

## Scope

This document is the public, aggregate validation summary for the MMAGIC legacy DIPFIT/AAL reference implementation. Study-specific filenames, coded identifiers, local paths, and row-level real-data validation records are intentionally excluded.

## Validation outcome

The implementation was validated on 22 ICA/DIPFIT datasets comprising:

- 710 IC identities;
- 712 source-model entries.

Validation results:

- synthetic tests: **8/8 passed**;
- independent physical-distance checks: **15/15 passed**;
- boundary-voxel optimization checks: **40/40 passed**;
- sampled comparison with FieldTrip `ft_volumelookup`: **28/30 agreement**;
- database identity/linkage checks: **passed**.

The two FieldTrip disagreements were atlas-boundary nearest-voxel tie cases. The production rule remains direct affine mapping into the AAL voxel grid followed by lookup in `aal.tissue`; FieldTrip lookup is validation-only.

## Interpretation

The validation supports computational consistency of:

- IC-to-source linkage;
- bilateral source-model handling;
- direct AAL membership;
- physical MNI-millimeter distance-to-ROI calculations;
- alignment of ROI-distance rows with source rows.

It does not establish biological validity, superiority of equivalent dipole models, or validity of any downstream group-statistical model.

## Scientific limitations

- Equivalent dipole fitting can exhibit systematic localization and depth bias.
- AAL is a volumetric anatomical parcellation, not an EEG source model.
- Direct membership is sensitive to the declared voxel-rounding convention.
- Atlas-boundary locations can produce tie behavior in independent lookup implementations.
- Distance is measured to centers of discrete atlas voxels in physical MNI millimeters.

## Verdict

**PASS WITH DOCUMENTED LIMITATIONS**
