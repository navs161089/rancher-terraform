module "ssh" {
  source = "../../modules/ssh"

  nodes                = var.nodes
  ssh_user             = var.ssh_user
  ssh_private_key_path = var.ssh_private_key_path
  ssh_port             = var.ssh_port
}
