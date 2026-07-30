variable "nodes" {
  description = "Server (control-plane) nodes only, keyed by hostname. Pass module.prerequisites.prepared_nodes filtered to role == \"server\" — not var.nodes directly — so RKE2 can never install before OS prep has succeeded."
  type = map(object({
    ip   = string
    role = string
  }))
}

variable "first_server_name" {
  description = "Hostname (key into var.nodes) of the node that bootstraps the cluster with no server: field. Every other entry in var.nodes joins against this node's IP on port 9345."
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
  description = "RKE2 release installed via INSTALL_RKE2_VERSION, e.g. \"v1.35.6+rke2r1\". Verify against https://update.rke2.io/v1-release/channels before changing — an unpinned or non-existent version fails the install script, not terraform plan."
  type        = string
}

variable "cluster_token" {
  description = "Shared secret every server and agent uses to join this cluster. Generate it once in the root module (random_password) and pass the same value to modules.rke2-server and modules.rke2-agent — never let two modules generate their own."
  type        = string
  sensitive   = true
}

variable "pod_cidr" {
  description = "Cluster-wide CIDR range RKE2 assigns pod IPs from."
  type        = string
}

variable "service_cidr" {
  description = "Cluster-wide CIDR range RKE2 assigns Service ClusterIPs from."
  type        = string
}

variable "cluster_dns" {
  description = "ClusterIP assigned to CoreDNS."
  type        = string
}

variable "extra_tls_sans" {
  description = "Additional Subject Alternative Names for the kube-apiserver certificate, beyond every server node's own IP (which this module adds automatically). Populate this once a load balancer VIP or DNS name exists in front of the control plane (HA phase) — empty is correct for a single-server lab."
  type        = list(string)
  default     = []
}
