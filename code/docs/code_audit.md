# MMAGIC legacy-core code audit

## Scope

The audit separates reusable anatomical grouping infrastructure from study-specific analysis. The public repository contains only the cleaned implementation, synthetic tests, aggregate validation documentation, and CI configuration; unchanged internal historical scripts are not distributed.

## Findings

The reusable scientific core is anatomical ROI-based correspondence across subjects. Study-specific groups, fixed condition structures, ERP/ERSP tensors, plotting, and group statistics are excluded.

The current implementation also separates IC identity from source-model entries. A bilateral DIPFIT solution therefore produces one IC row linked to multiple source rows rather than duplicated IC observations.

## Audit checklist outcome

| Item | Outcome |
|---|---|
| hard-coded local paths | absent from production code; documentation uses explicit placeholders only |
| hard-coded real-data identifiers | removed |
| study-specific group labels | removed |
| fixed condition count | removed |
| duplicated bilateral IC data | removed; one IC row links to multiple source rows |
| missing DIPFIT | IC identity preserved; zero linked source rows |
| NaN coordinates | preserved and marked invalid |
| AAL assignment | direct affine MNI-to-voxel lookup in `aal.tissue`; `ft_volumelookup` is validation-only |
| distance-to-ROI | first-class aligned matrix in `db.roi.distance_mm` |
| empty/background atlas voxel | exact label empty; nearest ROI and distance retained |
| hemisphere boundary | historical and strict policies supported |
| residual variance threshold | optional, parameterized, strict (`rv < threshold`) |
| ICLabel filtering | optional and parameterized; no hidden default |
| obsolete atlas lookup dependency | removed from public API |
| study-specific statistics | excluded |

## Dependency note

The current public reference implementation depends on FieldTrip's AAL atlas for anatomical parcellation. Atlas files themselves are not included in this repository.
