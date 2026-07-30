output "installed_server_nodes" {
  description = "Pass-through of var.nodes, tagged with the install resource id (from whichever of rke2_first_server / rke2_additional_servers actually created it). Downstream modules (kubernetes in Phase 6, rke2-agent in Phase 5) should depend on this, not on var.nodes."
  value = {
    for name, n in var.nodes : name => merge(n, {
      installed_id = name == var.first_server_name ? null_resource.rke2_first_server[name].id : null_resource.rke2_additional_servers[name].id
    })
  }
}

output "first_server_ip" {
  description = "IP of the bootstrap server. rke2-agent (Phase 5) joins against this address."
  value       = local.first_server_ip
}
