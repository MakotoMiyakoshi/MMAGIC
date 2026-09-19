# MMAGIC

**MMAGIC: Multi-Model Anatomical Grouping of Independent Components**

MMAGIC organizes EEG independent components across subjects using anatomical source-model information rather than conventional cross-subject k-means clustering.

## Repository layout

This repository follows the Makoto Project Layout Rule. The project root contains only `code/` and pipeline-generated p-number directories. See `code/docs/PROJECT_STRUCTURE.md`.

Current pipeline entry points:

```text
code/p1200_inspect_colin27_resources.m
code/p1210_build_colin27_bscr_headmodels.m
```

Support code is organized below `code/`:

```text
code/forward_model/
code/legacy/
code/tests/
code/docs/
code/ci/
```

## Current implementation

The public baseline remains the legacy DIPFIT/AAL implementation. Experimental distributed-source work is rebuilding a Colin27-unified forward model with explicit BSCR = 20, 40, and 80 conditions.

For the forward-model design, see `code/docs/colin27_forward_model.md`.

## MATLAB tests

From the project root:

```matlab
run('code/tests/run_tests.m')
```

## License

GNU General Public License v3.0. The license text is stored at `code/docs/LICENSE`.
