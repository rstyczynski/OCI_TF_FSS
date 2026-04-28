variable "export_set_ocid" {
  description = "Export set OCID associated with the mount target."
  type        = string
}

variable "file_system_ocid" {
  description = "Filesystem OCID to export."
  type        = string
}

variable "path" {
  description = "NFS export path."
  type        = string
}

variable "source_cidr" {
  description = "Client IPv4 CIDR allowed by the export option."
  type        = string
}

variable "access" {
  description = "Access mode for clients matching source_cidr."
  type        = string
  default     = "READ_WRITE"
}

variable "allowed_auth" {
  description = "Allowed NFS authentication types."
  type        = list(string)
  default     = ["SYS"]
}

variable "identity_squash" {
  description = "Identity squash mode for the export option."
  type        = string
  default     = "ROOT"
}

variable "anonymous_uid" {
  description = "Anonymous UID used when identity squashing applies."
  type        = number
  default     = 65534
}

variable "anonymous_gid" {
  description = "Anonymous GID used when identity squashing applies."
  type        = number
  default     = 65534
}

variable "is_anonymous_access_allowed" {
  description = "Whether anonymous access is allowed when the user is not found."
  type        = bool
  default     = false
}

variable "require_privileged_source_port" {
  description = "Whether clients must use a privileged source port."
  type        = bool
  default     = false
}
