# Backup area

This folder stores historical snapshots and non-active project artifacts.

## Policy

- no runtime dependency should point to backup assets
- legacy content remains read-only for traceability
- migration work should copy needed references into active folders

The active project flow must continue to use api/, docs/, scripts/ and web/.
