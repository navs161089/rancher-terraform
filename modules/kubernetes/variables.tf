variable "server_ip" {
  description = "IP of the RKE2 server to fetch the kubeconfig from — pass module.rke2_server.first_server_ip, not a recomputed value, so this module depends on the server actually being installed."
  type        = string
}

variable "ssh_user" {
  description = "Linux user to authenticate as."
  type        = string
}

variable "ssh_private_key_path" {
  description = "Path on the Terraform workstation to the private key used for SSH."
  type        = string
  sensitive   = true

  validation {
    condition     = fileexists(pathexpand(var.ssh_private_key_path))
    error_message = "ssh_private_key_path does not point to a file that exists on this workstation."
  }
}

variable "ssh_port" {
  description = "TCP port the SSH daemon listens on."
  type        = number
}

variable "local_kubeconfig_path" {
  description = "Where to write the fetched kubeconfig on the Terraform workstation. Never point this at ~/.kube/config directly — Terraform overwriting a file you also hand-edit is a recipe for clobbering other clusters' contexts. Write to a dedicated, gitignored path and merge manually if you want it permanent."
  type        = string
}
