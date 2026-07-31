# WHY remote-exec here: identical justification to modules/rke2-server —
# RKE2 is installed via the vendor's own get.rke2.io script, which no
# provider models. See modules/rke2-server/main.tf for the full
# reasoning, including the accepted curl-|-sh supply-chain tradeoff.
locals {
  server_url = "https://${var.first_server_ip}:9345"

  rendered_config = templatefile("${path.module}/../../templates/rke2-agent-config.yaml.tpl", {
    token      = var.cluster_token
    server_url = local.server_url
  })
}

resource "null_resource" "rke2_agent" {
  for_each = var.nodes

  triggers = {
    config_hash  = md5(local.rendered_config)
    rke2_version = var.rke2_version
  }

  connection {
    type        = "ssh"
    host        = each.value.ip
    user        = var.ssh_user
    private_key = file(pathexpand(var.ssh_private_key_path))
    port        = var.ssh_port
    timeout     = var.connection_timeout
  }

  provisioner "file" {
    content     = local.rendered_config
    destination = "/tmp/rke2-agent-config.yaml"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p /etc/rancher/rke2",
      "sudo mv /tmp/rke2-agent-config.yaml /etc/rancher/rke2/config.yaml",
      "curl -sfL https://get.rke2.io -o /tmp/rke2-install.sh",
      "sudo INSTALL_RKE2_VERSION=${var.rke2_version} INSTALL_RKE2_TYPE=agent sh /tmp/rke2-install.sh",
      "sudo systemctl enable --now rke2-agent.service",

      # Local join gate, not cluster validation (that's Phase 6): confirm
      # the kubelet on *this* node is actually healthy before we call
      # this resource created. Deliberately checking kubelet's own
      # unauthenticated, loopback-only /healthz on :10248 rather than
      # anything requiring credentials — Phase 4 already taught us that
      # an anonymous check against an auth-required endpoint (apiserver's
      # /readyz) produces a false "not ready" forever. Kubelet's healthz
      # has no such requirement.
      "for i in $(seq 1 30); do curl -sf --max-time 2 http://localhost:10248/healthz >/dev/null 2>&1 && break; echo \"[${each.key}] waiting for kubelet ($i/30)...\"; sleep 10; done",
      "curl -sf --max-time 2 http://localhost:10248/healthz >/dev/null 2>&1 || (echo \"[${each.key}] kubelet did not become healthy in time\" && exit 1)",
    ]
  }
}
