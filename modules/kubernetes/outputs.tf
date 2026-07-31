output "kubeconfig_path" {
  description = "Path to the fetched kubeconfig on the Terraform workstation, with the server URL rewritten from 127.0.0.1 to the real, externally-reachable server IP."
  value       = var.local_kubeconfig_path
  depends_on  = [null_resource.fetch_kubeconfig]
}

output "node_count" {
  description = "Number of nodes Terraform validated as Ready via the kubernetes provider."
  value       = length(data.kubernetes_nodes.this.nodes)
}

output "kubernetes_server_version" {
  description = "kube-apiserver version, confirmed reachable and authenticated via the kubernetes provider (not just via kubectl on the node)."
  value       = data.kubernetes_server_version.this.git_version
}
