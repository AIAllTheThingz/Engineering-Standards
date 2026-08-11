# Release Records

This directory contains immutable published release records and explicitly prepared or unreleased release notes.

| Record | Lifecycle |
| --- | --- |
| [`1.2.0.md`](1.2.0.md) | Prepared `1.2.0` release record; unpublished and not yet bound to a final exact candidate SHA. |
| [`1.1.0.md`](1.1.0.md) | Published historical release record for tag `v1.1.0`. |
| [`unreleased-consolidation.md`](unreleased-consolidation.md) | Consolidated post-`v1.1.0` development history and current `1.2.0` readiness boundary. |

Published records describe only the immutable tag and commit they name. Prepared or unreleased records must not be interpreted as publication, tag authorization, or a production compatibility promise.

The authoritative current state is maintained in [Release Status](../RELEASE_STATUS.md). The prepared `1.2.0` record becomes a published release record only after the existing PreRelease, Publication, and PostRelease lifecycle requirements are satisfied and the authorized immutable tag and GitHub Release are independently verified.
