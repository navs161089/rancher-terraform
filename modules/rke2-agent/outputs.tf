output "installed_agent_nodes" {
  description = "Pass-through of var.nodes, tagged with the install resource id. Downstream modules (kubernetes in Phase 6) should depend on this, not on var.nodes."
  value = {
    for name, n in var.nodes : name => merge(n, {
      installed_id = null_resource.rke2_agent[name].id
    })
  }
}
