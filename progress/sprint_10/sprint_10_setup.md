# Sprint 10 - Setup

Status: Complete

## Backlog Item

- PBI-020. Rebase v1 stack on latest Sprint 8 stack interface

## Sprint Definition

- Mode: YOLO
- Test: integration
- Regression: none

## Product Scope

Update `terraform/modules/fss_v1_stack` so the v1 stack uses the latest approved Sprint 8 stack interface:

- independent `mount_targets` map
- independent `filesystems` map
- nested filesystem exports
- exports reference mount targets by key
- optional mount target logging
- logging exposed through `mount_targets[*].logging`

