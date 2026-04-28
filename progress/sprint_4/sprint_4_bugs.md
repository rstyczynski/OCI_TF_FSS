# Sprint 4 - Bugs

## BUG-001. NPA failed when modeled as subnet/IP endpoint

Status: Fixed

Related item: PBI-004. Network Path Analyzer test for FSS availability

Severity: High

### Symptom

The first A3 quality gate attempts created the filesystem, mount target, and export successfully, but IT-3 failed because Network Path Analyzer returned `FAILED`.

Evidence:

- `progress/sprint_4/test_run_A3_integration_20260428_075851.log`
- `progress/sprint_4/test_run_A3_integration_20260428_080452.log`

### Root Cause

The original NPA helper analyzed a generic subnet source and IP destination. That did not model the actual client-to-FSS path strongly enough for this validation. A second attempt moved the source to the foundation compute private IP but still modeled the destination as a generic IP address.

### Fix

Updated the Sprint 4 test and NPA helper to use VNIC endpoints:

- Source endpoint: foundation compute VNIC and private IP.
- Destination endpoint: mount target VNIC and private IP.
- Protocol: TCP.
- Destination port: 2049.

### Verification

Fixed by the final A3 run and confirmed by the full B3 integration regression:

- A3: `progress/sprint_4/test_run_A3_integration_20260428_081015.log`, summary `pass=3 fail=0`.
- B3: `progress/sprint_4/test_run_B3_integration_20260428_081543.log`, summary `pass=4 fail=0`.
