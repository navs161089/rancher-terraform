# WHY remote-exec here, specifically:
#
# RKE2 is installed via a shell script Rancher itself publishes
# (https://get.rke2.io) — there is no Terraform provider for it, because
# "install a systemd service from a vendor script" isn't something a
# declarative provider models. This is the same category of exception as
# modules/prerequisites and modules/ssh: an imperative, vendor-defined
# action with no provider equivalent, run through the narrowest possible
# null_resource + remote-exec surface.
#
# Known, accepted tradeoff: `curl | sh`-style vendor installers trust
# the vendor's HTTPS endpoint at execution time — there's no checksum or
# GPG signature pinned here. That's an explicit gap, not an oversight;
# tightening it (mirroring the installer, verifying release signatures)
# belongs in Phase 15 (Security hardening), not here.
locals {
  all_server_ips = [for n in var.nodes : n.ip]
  tls_sans       = concat(local.all_server_ips, ["127.0.0.1", "localhost"], var.extra_tls_sans)

  # Every server except the bootstrap node joins against it. For today's
  # single-server lab this map is empty — 0 resources created below —
  # which is exactly why adding 2 more control-plane nodes later is a
  # tfvars change, not a rewrite of this module.
  joiner_nodes = { for name, n in var.nodes : name => n if name != var.first_server_name }

  first_server_ip = var.nodes[var.first_server_name].ip

  rendered_config_first_server = templatefile("${path.module}/../../templates/rke2-server-config.yaml.tpl", {
    token           = var.cluster_token
    tls_sans        = local.tls_sans
    pod_cidr        = var.pod_cidr
    service_cidr    = var.service_cidr
    cluster_dns     = var.cluster_dns
    server_url      = ""
    disabled_addons = var.disabled_addons
  })

  rendered_config_joiner = templatefile("${path.module}/../../templates/rke2-server-config.yaml.tpl", {
    token           = var.cluster_token
    tls_sans        = local.tls_sans
    pod_cidr        = var.pod_cidr
    service_cidr    = var.service_cidr
    cluster_dns     = var.cluster_dns
    server_url      = "https://${local.first_server_ip}:9345"
    disabled_addons = var.disabled_addons
  })
}

resource "null_resource" "rke2_first_server" {
  for_each = { for name, n in var.nodes : name => n if name == var.first_server_name }

  triggers = {
    config_hash  = md5(local.rendered_config_first_server)
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
    content     = local.rendered_config_first_server
    destination = "/tmp/rke2-config.yaml"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p /etc/rancher/rke2",
      "sudo mv /tmp/rke2-config.yaml /etc/rancher/rke2/config.yaml",
      "curl -sfL https://get.rke2.io -o /tmp/rke2-install.sh",
      "sudo INSTALL_RKE2_VERSION=${var.rke2_version} INSTALL_RKE2_TYPE=server sh /tmp/rke2-install.sh",
      # `enable --now` only *starts* a stopped service — it does not
      # restart an already-running one, so a config-only change (e.g.
      # adding to `disable:`) would silently never take effect on
      # re-apply. `restart` is correct in both cases: starts it if
      # stopped, reloads it with the new config if already running. This
      # resource only re-runs when config_hash/rke2_version actually
      # changed (see triggers above), so restarting here is never
      # gratuitous.
      "sudo systemctl enable rke2-server.service",
      "sudo systemctl restart rke2-server.service",

      # Join-ordering gate, not cluster validation (that's Phase 6):
      # additional servers must not attempt to join until this node's
      # apiserver is actually answering, not merely "systemctl start
      # returned 0". Bounded retry so a genuinely broken install fails
      # the apply loudly instead of hanging forever.
      #
      # Uses the auto-generated admin kubeconfig, not an anonymous curl
      # to /readyz: this apiserver requires authentication even on the
      # health endpoints (anonymous requests get a 401, which is
      # indistinguishable from "not ready" to an unauthenticated caller
      # — confirmed live, not assumed).
      "for i in $(seq 1 30); do sudo /var/lib/rancher/rke2/bin/kubectl --kubeconfig /etc/rancher/rke2/rke2.yaml get --raw=/readyz 2>/dev/null | grep -q ok && break; echo \"[${each.key}] waiting for rke2 apiserver ($i/30)...\"; sleep 10; done",
      "sudo /var/lib/rancher/rke2/bin/kubectl --kubeconfig /etc/rancher/rke2/rke2.yaml get --raw=/readyz 2>/dev/null | grep -q ok || (echo \"[${each.key}] rke2 apiserver did not become ready in time\" && exit 1)",
    ]
  }
}

resource "null_resource" "rke2_additional_servers" {
  for_each   = local.joiner_nodes
  depends_on = [null_resource.rke2_first_server]

  triggers = {
    config_hash  = md5(local.rendered_config_joiner)
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
    content     = local.rendered_config_joiner
    destination = "/tmp/rke2-config.yaml"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p /etc/rancher/rke2",
      "sudo mv /tmp/rke2-config.yaml /etc/rancher/rke2/config.yaml",
      "curl -sfL https://get.rke2.io -o /tmp/rke2-install.sh",
      "sudo INSTALL_RKE2_VERSION=${var.rke2_version} INSTALL_RKE2_TYPE=server sh /tmp/rke2-install.sh",
      # `enable --now` only *starts* a stopped service — it does not
      # restart an already-running one, so a config-only change (e.g.
      # adding to `disable:`) would silently never take effect on
      # re-apply. `restart` is correct in both cases: starts it if
      # stopped, reloads it with the new config if already running. This
      # resource only re-runs when config_hash/rke2_version actually
      # changed (see triggers above), so restarting here is never
      # gratuitous.
      "sudo systemctl enable rke2-server.service",
      "sudo systemctl restart rke2-server.service",
    ]
  }
}
