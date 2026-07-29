# WHY remote-exec here, specifically:
#
# None of this repo's preferred providers (kubernetes, helm, tls, random,
# local, null) can open an SSH session and run a command — that
# capability only exists via a provisioner's `connection` block. Every
# later phase (prerequisites, rke2-server, rke2-agent) depends on SSH
# actually working for this exact user/key/port combination, so proving
# it here — as its own resource, with its own name in the plan/apply
# output — means a broken key or a locked-out user fails fast on a
# single-purpose "ssh" resource instead of surfacing as a confusing
# failure three levels into a kernel-module or RKE2-install step.
#
# This is provisioners used for what they exist for: an imperative,
# one-off action with no clean declarative provider equivalent. It is
# not a workaround for something a provider could do instead.
resource "null_resource" "connectivity_check" {
  for_each = var.nodes

  # Re-runs only when connection parameters change (a node's IP, the SSH
  # user, the port, or the key material itself) — not on every apply.
  # A no-op `terraform plan` should stay a no-op; if you need to force a
  # re-check without changing any of these, use
  # `terraform apply -replace='module.ssh.null_resource.connectivity_check["<name>"]'`.
  triggers = {
    ip          = each.value.ip
    ssh_user    = var.ssh_user
    ssh_port    = var.ssh_port
    key_content = filemd5(pathexpand(var.ssh_private_key_path))
  }

  connection {
    type        = "ssh"
    host        = each.value.ip
    user        = var.ssh_user
    private_key = file(pathexpand(var.ssh_private_key_path))
    port        = var.ssh_port
    timeout     = var.connection_timeout
  }

  provisioner "remote-exec" {
    inline = [
      "echo \"[${each.key}] connected as $(whoami) on $(hostname)\"",
      "sudo -n true && echo \"[${each.key}] passwordless sudo OK\" || (echo \"[${each.key}] passwordless sudo MISSING\" && exit 1)",
    ]
  }
}
