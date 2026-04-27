# Backlog

### PBI-001. Terraform module for FSS filesystem

Create a Terraform module that provisions an OCI File Storage Service (FSS) filesystem suitable for reuse across environments. The module must expose the key outputs needed by downstream configuration and keep its surface area minimal. This item is complete when the module can be applied successfully in a target compartment.

Test: apply succeeds and outputs include the created filesystem identifier.

### PBI-002. Terraform module for FSS mount target

Create a Terraform module that provisions an OCI FSS mount target that can be attached to a subnet and used by clients to access a filesystem. The module must be reusable and expose outputs needed to connect it with a filesystem and export configuration. This item is complete when the mount target is created successfully and its key identifiers are available as outputs.

Test: apply succeeds and outputs include the created mount target identifier.

### PBI-003. Terraform module for FSS export

Create a Terraform module that provisions an OCI FSS export that connects a filesystem to a mount target and makes it accessible via an export path. The module must support configuring access such that clients in the intended network can mount it. This item is complete when an export exists and clients have the information needed to mount it.

Test: apply succeeds and outputs include the export identifier and export path.

