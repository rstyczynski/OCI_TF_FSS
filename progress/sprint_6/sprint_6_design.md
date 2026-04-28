# Sprint 6 - Design

Status: Accepted (YOLO auto-approved)

## Overview

Sprint 6 automates mounting FSS exports on the foundation compute instance and validates common administrator operations. The sprint builds on the Sprint 5 stack module for FSS provisioning and uses the Sprint 1 foundation compute instance as the NFS client.

## PBI-010. Mount FSS file system(s) on a compute instance

Status: Accepted

### Requirement

Automate mounting one or more provisioned FSS exports on the foundation compute instance. Install required NFS client packages when needed, create mount directories, apply mount options, and verify the mounted filesystem is usable.

### Design

The integration test will:

1. Provision an FSS topology using the Sprint 5 stack module with at least one filesystem entry.
2. Retrieve the ready-to-use NFS mount source from the Sprint 5 stack `nfs_mount_sources` output.
3. Connect to the foundation compute instance via SSH.
4. Install NFS client packages (`nfs-utils` on Oracle Linux / RHEL, or equivalent).
5. Create mount point directories under `/mnt/fss/`.
6. Execute mount commands with appropriate options using the stack-provided `<mount-address>:<export-path>` value.
7. Verify mount success via `mount | grep` and `df -h`.
8. Write and read a small test file to prove the filesystem is usable.
9. Unmount and clean up.

Implementation approach:

- Shell script `tests/integration/test_fss_sprint6_mount.sh` with helper functions.
- SSH connection using the Sprint 1 foundation SSH key stored under `progress/sprint_1/scaffold/`.
- Mount options following OCI FSS best practices (e.g., `vers=3`, `rsize`, `wsize`, `timeo`, `retrans`).

### Acceptance

- Integration test connects to compute instance via SSH.
- NFS client packages are installed if missing.
- FSS export is mounted under `/mnt/fss/<name>`.
- `mount` and `df` show the mounted filesystem.
- Test file write and read succeed.
- Cleanup unmounts the filesystem.

## PBI-011. Perform administrator tasks for FSS mount(s)

Status: Accepted

### Requirement

Validate common administrator operations on mounted FSS exports: directory creation, ownership/permission changes, file creation/removal, remount behavior, and cleanup.

### Design

The integration test will extend or follow PBI-010 to:

1. Mount the FSS export (reuse PBI-010 logic).
2. Create a directory structure under the mount point.
3. Change ownership with `chown`.
4. Set permissions with `chmod`.
5. Create and delete files.
6. Remount the filesystem and verify state persistence.
7. Clean up all test artifacts.
8. Unmount.

Implementation approach:

- Combined shell script `tests/integration/test_fss_sprint6_mount.sh` with separate test functions for mount validation and administrator operations.
- All operations run via SSH on the foundation compute instance.
- Operations executed as root or with sudo as required.

### Acceptance

- Directory creation succeeds.
- Ownership and permission changes are applied and verified.
- Files can be created, read, and deleted.
- Remount shows persisted state.
- Cleanup leaves no test artifacts.
- Final unmount succeeds.

## Test Specification

### Testing Strategy

| Level | Scope | Purpose |
|-------|-------|---------|
| Integration | IT-1: Mount FSS export | Verify NFS mount from compute instance |
| Integration | IT-2: Admin operations | Verify directory, permission, file operations |

### Test Skeletons

Tests will be created in `tests/integration/`:

- `test_fss_sprint6_mount.sh` - IT-1 mount/basic file operations and IT-2 administrator workflow operations.

### Test Dependencies

- Sprint 1 foundation compute instance accessible via SSH.
- Sprint 5 stack module creates FSS topology and exposes `nfs_mount_sources` for direct client mounting.
- Network reachability confirmed by Sprint 4 NPA validation.
