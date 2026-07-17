---
id: NET-BROCADE-EXAMPLE-001
title: Fictitious Brocade Networking Adoption Example
version: 0.1.0
status: baseline
---

# Fictitious Brocade Networking Adoption Example

This non-production example uses invented names and omits all WWPN values; it contains no credentials or real device data.

## Scope

The fictitious `LAB-SAN` has isolated Fabric A and Fabric B test switches running a verified Fabric OS release. A test host and array each have one path per fabric. SANnav test inventory is authoritative. WWPN values are retained only in the restricted change record and are omitted here.

## Adoption decision

- Select Brocade plus storage, Linux, Python, testing, security, observability, and release-engineering standards.
- Confirm the devices are FOS Fibre Channel switches, not legacy Brocade Ethernet equipment.
- Record exact models, FOS/SANnav compatibility, fabric WWNs, FIDs, domain/principal state, ISLs, licenses, HBA/array interoperability, lifecycle source, and review date.
- Create a single-initiator zone on Fabric A first, validate the complete transaction, and stop before Fabric B until login, multipath, MAPS, counter, and fictitious I/O checks pass.
- Verify effective zoning and endpoint visibility from switch, host, and array perspectives; do not accept a zone-enable message alone.

## Recovery and evidence

The reviewer requires tested serial access, a protected configuration backup, documented support-data handling, one-fabric rollback, storage/OS owner observation, and a defined monitoring window. Director HA, firmware downgrade, cable failure, and production workload behavior were not tested, so no nondisruptive or production-readiness claim is made.
