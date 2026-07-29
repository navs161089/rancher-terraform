variable "nodes" {
  description = "Every node to connectivity-check, keyed by hostname. Same shape as the root nodes variable — see environments/local/variables.tf."
  type = map(object({
    ip   = string
    role = string
  }))
}

variable "ssh_user" {
  description = "Linux user to authenticate as on every node. Must already have passwordless sudo and key-based SSH configured."
  type        = string
}

variable "ssh_private_key_path" {
  description = "Path on the Terraform workstation to the private key used for SSH to every node."
  type        = string
  sensitive   = true

  validation {
    condition     = fileexists(pathexpand(var.ssh_private_key_path))
    error_message = "ssh_private_key_path does not point to a file that exists on this workstation."
  }
}

variable "ssh_port" {
  description = "TCP port the SSH daemon listens on for every node."
  type        = number
}

variable "connection_timeout" {
  description = "How long to wait for the SSH connection before failing, e.g. \"30s\"."
  type        = string
  default     = "30s"
}
