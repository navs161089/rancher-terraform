output "prepared_nodes" {
  description = "Pass-through of var.nodes, each entry tagged with its prerequisites resource id. Downstream modules (rke2-server, rke2-agent) should take this as input instead of var.nodes directly — referencing .id forces a real dependency edge on OS preparation having completed first."
  value = {
    for name, n in var.nodes : name => merge(n, {
      prepared_id = null_resource.prerequisites[name].id
    })
  }
}
