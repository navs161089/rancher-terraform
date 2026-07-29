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
}
