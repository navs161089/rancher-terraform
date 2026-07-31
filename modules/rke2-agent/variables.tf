variable "nodes" {
  description = "Agent (worker) nodes only, keyed by hostname. Pass module.prerequisites.prepared_nodes filtered to role == \"agent\" — not var.nodes directly — so RKE2 can never install before OS prep has succeeded."
  type = map(object({
    ip   = string
    role = string
  }))
}

variable "first_server_ip" {
  description = "IP of the RKE2 bootstrap server to join against. Pass module.rke2_server.first_server_ip, not a locally-computed value — that forces this module to depend on the server's apiserver having actually become ready, not just on the IP being known."
  type        = string
}

variable "ssh_user" {
  description = "Linux user to authenticate as on every node."
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

variable "rke2_version" {
  description = "RKE2 release installed via INSTALL_RKE2_VERSION. Must match the version installed on the servers this agent joins."
  type        = string
}

variable "cluster_token" {
  description = "Shared secret used to join this cluster. Must be the exact same value passed to modules.rke2-server — never generate a separate token here."
  type        = string
  sensitive   = true
}
