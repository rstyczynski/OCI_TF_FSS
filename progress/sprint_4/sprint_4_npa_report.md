# Sprint 4 - Network Path Analyzer Report

## Scope

Validate that the Sprint 4 FSS mount target is reachable from the Sprint 1 foundation compute instance on NFS TCP/2049.

## Final New-Code Evidence

Log: `progress/sprint_4/test_run_A3_integration_20260428_081015.log`

Result:

- OCI Network Path Analyzer returned `SUCCEEDED`.
- Source endpoint: foundation compute private IP `10.0.0.39`.
- Destination endpoint: Sprint 4 mount target private IP `10.0.0.142`.
- Protocol and port: TCP/2049.
- Proof lines: `834-835`.

## Full Regression Evidence

Log: `progress/sprint_4/test_run_B3_integration_20260428_081543.log`

Result:

- OCI Network Path Analyzer returned `SUCCEEDED`.
- Source endpoint: foundation compute private IP `10.0.0.39`.
- Destination endpoint: Sprint 4 mount target private IP `10.0.0.94`.
- Destination VNIC output during the test: `ocid1.vnic.oc1.eu-zurich-1.ab5heljrbqcmrlmncg3ejjwxjct7rufjufoa4jnl6ht4vsqplmikcfacr4sq`.
- Protocol and port: TCP/2049.
- Proof lines: `2042-2043`.

## Endpoint Model

The passing NPA tests use VNIC endpoints:

- Source: Sprint 1 foundation compute VNIC, resolved at runtime from the foundation compute OCID.
- Destination: Sprint 4 mount target VNIC, resolved from the mount target private IP data source.

This endpoint model proves reachability from the actual foundation client host to the actual FSS mount target network interface.

## Resource Cleanup

Both passing runs destroyed their transient Terraform resources after NPA completion. The B3 log ends with `Destroy complete! Resources: 3 destroyed.` followed by `PASS: IT-3` and `pass=4 fail=0`.
