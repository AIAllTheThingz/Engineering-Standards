# Tests

This directory contains real Pester tests with `Describe`, `Context`, and `It` blocks for governance validation behavior.

`CodexSkills.Tests.ps1` validates bounded skill supply-chain rules and materializes isolated valid and invalid fixture repositories from synthetic data. The suite never runs model behavior.

`ValidatorDependencies.Tests.ps1` validates the reviewed runtime and package
lock, exact Python hash requirements, offline missing-package behavior, tampered
package rejection, matching-cache success, and archive traversal rejection with
synthetic files only.
