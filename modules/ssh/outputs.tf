output "checked_nodes" {
  description = "Pass-through of var.nodes, each entry tagged with its connectivity_check resource id. Downstream modules should take this as input instead of var.nodes directly — referencing .id forces a real dependency edge on the check having succeeded first, which a plain pass-through of var.nodes would not."
  value = {
    for name, n in var.nodes : name => merge(n, {
      checked_id = null_resource.connectivity_check[name].id
    })
  }
}
