module "ssh" {
  source = "../../modules/ssh"

  nodes                = var.nodes
  ssh_user             = var.ssh_user
  ssh_private_key_path = var.ssh_private_key_path
  ssh_port             = var.ssh_port
}

module "prerequisites" {
  source = "../../modules/prerequisites"

  nodes                = local.nodes_after_ssh_check
  ssh_user             = var.ssh_user
  ssh_private_key_path = var.ssh_private_key_path
  ssh_port             = var.ssh_port
  timezone             = var.timezone
  disable_firewall     = var.disable_firewall
}

# Generated once here, in the root module, and threaded into both
# rke2-server (this phase) and rke2-agent (Phase 5) — never let two
# modules each generate their own token, or servers and agents would
# disagree on the cluster secret.
resource "random_password" "cluster_token" {
  length  = 48
  special = false
}

module "rke2_server" {
  source = "../../modules/rke2-server"

  nodes                = local.prepared_server_nodes
  first_server_name    = local.first_server_name
  ssh_user             = var.ssh_user
  ssh_private_key_path = var.ssh_private_key_path
  ssh_port             = var.ssh_port
  rke2_version         = var.rke2_version
  cluster_token        = local.cluster_token
  pod_cidr             = var.pod_cidr
  service_cidr         = var.service_cidr
  cluster_dns          = var.cluster_dns
  extra_tls_sans       = var.extra_tls_sans
  disabled_addons      = var.rke2_disabled_addons
}

module "rke2_agent" {
  source = "../../modules/rke2-agent"

  nodes                = local.prepared_agent_nodes
  first_server_ip      = module.rke2_server.first_server_ip
  ssh_user             = var.ssh_user
  ssh_private_key_path = var.ssh_private_key_path
  ssh_port             = var.ssh_port
  rke2_version         = var.rke2_version
  cluster_token        = local.cluster_token
}

module "kubernetes" {
  source = "../../modules/kubernetes"

  # Depends on the agent join too, not just the server — no direct data
  # dependency links them, so this is ordering by intent: don't hand the
  # user a kubeconfig until the whole cluster (not just the control
  # plane) is actually up.
  depends_on = [module.rke2_agent]

  server_ip             = module.rke2_server.first_server_ip
  ssh_user              = var.ssh_user
  ssh_private_key_path  = var.ssh_private_key_path
  ssh_port              = var.ssh_port
  local_kubeconfig_path = local.kubeconfig_path
}

module "ingress" {
  source = "../../modules/ingress"

  # module.rke2_server: so the disable: rke2-ingress-nginx config
  # change (and the restart that actually tears the bundled controller
  # down) lands before we try to install our own, avoiding a window
  # with two ingress controllers fighting over :80/:443.
  # module.kubernetes: so the helm provider has a kubeconfig to use.
  depends_on = [module.rke2_server, module.kubernetes]

  ingress_nginx_version = var.ingress_nginx_version
}
