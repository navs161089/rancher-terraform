# This file declares the full input contract for the platform, even
# though most variables are unused until later phases wire them into a
# module. Terraform does not error on unused input variables, and
# defining the interface once now means we never have to come back and
# redesign variables.tf as new phases land — only consume what already
# exists here.

# ---------------------------------------------------------------------------
# Cluster identity
# ---------------------------------------------------------------------------

variable "cluster_name" {
  description = "Short, DNS-safe name identifying this cluster. Used as a prefix for resource names, labels, and generated hostnames."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]{0,28}[a-z0-9])?$", var.cluster_name))
    error_message = "cluster_name must be lowercase alphanumeric with optional hyphens, 1-30 characters, and cannot start or end with a hyphen."
  }
}

variable "timezone" {
  description = "IANA timezone applied to every node via chrony (Phase 3)."
  type        = string
  default     = "UTC"
}

# ---------------------------------------------------------------------------
# Node connectivity — consumed starting Phase 2 (SSH Connectivity)
#
# A single map, keyed by hostname, is the entire cluster topology. Every
# module from Phase 3 onward (prerequisites, rke2-server, rke2-agent, ...)
# does `for_each` over a role-filtered view of this map (see
# local.server_nodes / local.agent_nodes in locals.tf) instead of taking
# individual IP variables. Growing from 1 server + 1 agent to 3 servers +
# N agents is then a tfvars edit, not a module signature change — that's
# the "extendable to HA without redesign" requirement from day one.
# ---------------------------------------------------------------------------

variable "nodes" {
  description = "Every node in the cluster, keyed by a unique hostname. role must be \"server\" (RKE2 control-plane) or \"agent\" (RKE2 worker)."
  type = map(object({
    ip   = string
    role = string
  }))

  validation {
    condition     = alltrue([for n in var.nodes : contains(["server", "agent"], n.role)])
    error_message = "each node's role must be exactly \"server\" or \"agent\"."
  }

  validation {
    condition     = alltrue([for n in var.nodes : can(cidrhost("${n.ip}/32", 0))])
    error_message = "each node's ip must be a valid IPv4 address."
  }

  validation {
    condition     = length([for n in var.nodes : n if n.role == "server"]) >= 1
    error_message = "at least one node must have role = \"server\" — a cluster needs a control-plane."
  }
}

variable "ssh_user" {
  description = "Linux user Terraform uses for remote provisioning over SSH. Must already have passwordless sudo and key-based SSH configured on every node."
  type        = string
  default     = "ubuntu"
}

variable "ssh_private_key_path" {
  description = "Path on the Terraform workstation to the private key used for passwordless SSH to every node. Never commit the key itself — only its path is configuration."
  type        = string
  sensitive   = true
}

variable "ssh_port" {
  description = "TCP port the SSH daemon listens on for every node."
  type        = number
  default     = 22

  validation {
    condition     = var.ssh_port > 0 && var.ssh_port <= 65535
    error_message = "ssh_port must be between 1 and 65535."
  }
}

# ---------------------------------------------------------------------------
# OS preparation — consumed starting Phase 3 (Linux Preparation)
# ---------------------------------------------------------------------------

variable "disable_firewall" {
  description = "Idempotently disable ufw on every node. RKE2 manages its own iptables/nftables rules for pod networking; a host firewall layered on top is the most common RKE2 support issue upstream. Set false to leave firewall state out of Terraform's scope entirely."
  type        = bool
  default     = true
}

# ---------------------------------------------------------------------------
# Domain & TLS — consumed starting Phase 8/9 (cert-manager / TLS)
# ---------------------------------------------------------------------------

variable "domain_name" {
  description = "Base domain used to construct hostnames for every service exposed by this platform (Rancher, Grafana, Longhorn, etc.)."
  type        = string
}

variable "rancher_hostname" {
  description = "Fully qualified hostname Rancher is exposed on. Leave empty to default to \"rancher.<domain_name>\" (see local.rancher_hostname)."
  type        = string
  default     = ""
}

# ---------------------------------------------------------------------------
# Software versions — always pinned explicitly, never "latest"
# (Phases 4, 8, 10, 12). Pinning is what makes `terraform plan` on this
# repo reproducible six months from now instead of drifting silently.
# ---------------------------------------------------------------------------

variable "rke2_version" {
  description = "RKE2 release channel/version installed on every node, e.g. \"v1.30.4+rke2r1\"."
  type        = string
}

variable "rancher_version" {
  description = "Rancher Helm chart version installed in Phase 10."
  type        = string
}

variable "cert_manager_version" {
  description = "cert-manager Helm chart version installed in Phase 8."
  type        = string
}

variable "longhorn_version" {
  description = "Longhorn Helm chart version installed in Phase 12."
  type        = string
}

variable "ingress_nginx_version" {
  description = "ingress-nginx Helm chart version installed in Phase 7, e.g. \"4.15.1\". Verify against `helm search repo ingress-nginx/ingress-nginx --versions` before changing."
  type        = string
}

# ---------------------------------------------------------------------------
# Kubernetes networking — consumed starting Phase 4 (RKE2 Server)
# ---------------------------------------------------------------------------

variable "pod_cidr" {
  description = "Cluster-wide CIDR range RKE2 assigns pod IPs from."
  type        = string
  default     = "10.42.0.0/16"
}

variable "service_cidr" {
  description = "Cluster-wide CIDR range RKE2 assigns Service ClusterIPs from."
  type        = string
  default     = "10.43.0.0/16"
}

variable "cluster_dns" {
  description = "ClusterIP assigned to CoreDNS. Must fall inside service_cidr."
  type        = string
  default     = "10.43.0.10"
}

variable "extra_tls_sans" {
  description = "Additional Subject Alternative Names for the kube-apiserver certificate, beyond every server node's own IP. Populate once a load-balancer VIP or DNS name fronts the control plane (HA phase) — empty is correct for a single-server lab."
  type        = list(string)
  default     = []
}

variable "rke2_disabled_addons" {
  description = "RKE2 packaged components to disable. Defaults to disabling RKE2's own bundled ingress-nginx so Terraform's helm_release (Phase 7) is the sole owner of ingress — running both would conflict."
  type        = list(string)
  default     = ["rke2-ingress-nginx"]
}

# ---------------------------------------------------------------------------
# Credentials — consumed starting Phase 4 (RKE2 cluster token) / Phase 11
# (Rancher bootstrap) / Phase 13 (Grafana)
# ---------------------------------------------------------------------------

variable "cluster_token_override" {
  description = "Explicit RKE2 cluster token. Leave empty (default) to have Terraform generate one via the random provider — recommended, since a hand-picked token is one more secret for a human to leak."
  type        = string
  default     = ""
  sensitive   = true
}

variable "grafana_admin_password" {
  description = "Initial Grafana admin password. Leave empty to have Terraform generate a random one via the random provider (recommended — see modules/monitoring in Phase 13)."
  type        = string
  default     = ""
  sensitive   = true
}
