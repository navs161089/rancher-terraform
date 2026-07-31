# Computed values derived from variables. Every module added from
# Phase 2 onward should consume these instead of re-deriving naming or
# tagging logic locally — that's the DRY contract this file exists to
# enforce.
locals {
  # Prefix for anything that needs a unique, human-readable name:
  # generated SSH key names, kubeconfig context names, etc.
  name_prefix = var.cluster_name

  # Falls back to "rancher.<domain_name>" when the caller doesn't pin an
  # explicit rancher_hostname. Centralizing this here means every module
  # that needs the Rancher FQDN (ingress, cert-manager, rancher) reads
  # the same computed value instead of re-implementing the fallback.
  rancher_hostname = var.rancher_hostname != "" ? var.rancher_hostname : "rancher.${var.domain_name}"

  # Common labels applied to every Kubernetes object and Helm release
  # created from Phase 6 onward. Kept here, not per-module, so a label
  # convention change is a one-line edit instead of an N-module edit.
  common_labels = {
    "app.kubernetes.io/managed-by" = "terraform"
    "platform.io/cluster"          = var.cluster_name
    "platform.io/environment"      = "local"
  }

  # Role-filtered views over var.nodes. Every node-scoped module
  # (ssh, prerequisites, rke2-server, rke2-agent, ...) for_each's over
  # one of these two maps — never over var.nodes directly — so adding a
  # third control-plane node or a fifth worker never touches module code.
  server_nodes = { for name, n in var.nodes : name => n if n.role == "server" }
  agent_nodes  = { for name, n in var.nodes : name => n if n.role == "agent" }

  # RKE2 bootstraps from exactly one server; every other server and every
  # agent joins against that node's IP + the shared cluster token.
  # sort() makes this a deterministic pick (alphabetically-first hostname)
  # instead of depending on map iteration order, which Terraform does not
  # guarantee to be stable across runs.
  first_server_name = sort(keys(local.server_nodes))[0]
  first_server_ip   = local.server_nodes[local.first_server_name].ip

  # Re-shaped module.ssh output: strips the module's checked_id
  # attribute back down to the {ip, role} shape modules/prerequisites
  # expects, while still forcing a real dependency edge on the
  # connectivity check having succeeded (module.ssh.checked_nodes only
  # exists once every null_resource.connectivity_check has been created).
  nodes_after_ssh_check = {
    for name, n in module.ssh.checked_nodes : name => {
      ip   = n.ip
      role = n.role
    }
  }

  # Same re-shape, one stage later: prerequisites.prepared_nodes filtered
  # down to servers only, forcing rke2-server to depend on OS prep having
  # succeeded (not just SSH connectivity).
  prepared_server_nodes = {
    for name, n in module.prerequisites.prepared_nodes : name => {
      ip   = n.ip
      role = n.role
    } if n.role == "server"
  }

  # Same re-shape, filtered to agents instead of servers.
  prepared_agent_nodes = {
    for name, n in module.prerequisites.prepared_nodes : name => {
      ip   = n.ip
      role = n.role
    } if n.role == "agent"
  }

  # random_password.cluster_token generates one automatically; an
  # explicit cluster_token_override always wins, matching the same
  # empty-string-means-generate pattern as grafana_admin_password.
  cluster_token = var.cluster_token_override != "" ? var.cluster_token_override : random_password.cluster_token.result

  # Single source of truth for where the fetched kubeconfig lives —
  # referenced by both the kubernetes provider block (providers.tf) and
  # module.kubernetes (main.tf). Keeping it here means the two can never
  # drift apart into pointing at different files.
  kubeconfig_path = "${path.root}/kubeconfig"
}
