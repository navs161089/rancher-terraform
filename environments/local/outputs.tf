# Outputs are added incrementally as each phase's module produces
# something worth surfacing:
#   Phase 6  -> kubeconfig
#   Phase 10 -> rancher_url, rancher_bootstrap_password
#   Phase 12 -> longhorn_url
#   Phase 13 -> grafana_url, prometheus_url

output "cluster_token" {
  description = "Shared secret used by every server/agent to join this cluster. Needed if you ever have to join a node by hand."
  value       = local.cluster_token
  sensitive   = true
}

output "node_information" {
  description = "Every node in the cluster: hostname, IP, and role."
  value       = var.nodes
}

output "first_server_ip" {
  description = "IP of the RKE2 bootstrap server — the API endpoint every other node and kubeconfig points at."
  value       = module.rke2_server.first_server_ip
}
