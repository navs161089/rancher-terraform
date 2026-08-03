# WHY file + remote-exec here, specifically:
#
# OS-level configuration management (installing packages, loading kernel
# modules, writing sysctl/fstab state, toggling services) has no
# equivalent in this repo's preferred providers (kubernetes, helm, tls,
# random, local, null) — that's the job Ansible/Chef/Puppet normally do,
# and this project deliberately has no configuration-management layer.
# `file` uploads the declarative config content that lives under
# templates/ (version-controlled, diffable, not buried in a heredoc);
# `remote-exec` applies it and runs the handful of genuinely imperative
# steps (modprobe, swapoff, apt install) that no provider wraps.
#
# Every command below is written to be idempotent — safe to re-run
# without changing behavior — because `triggers` intentionally only
# re-runs this resource when the rendered config or a relevant variable
# actually changes (see below), not on every apply.
resource "null_resource" "prerequisites" {
  for_each = var.nodes

  triggers = {
    modules_conf_hash = filemd5("${path.module}/../../templates/k8s-modules.conf")
    sysctl_conf_hash  = filemd5("${path.module}/../../templates/k8s-sysctl.conf")
    chrony_conf_hash  = filemd5("${path.module}/../../templates/chrony-makestep.conf")
    timezone          = var.timezone
    disable_firewall  = var.disable_firewall
    ssh_user          = var.ssh_user
  }

  connection {
    type        = "ssh"
    host        = each.value.ip
    user        = var.ssh_user
    private_key = file(pathexpand(var.ssh_private_key_path))
    port        = var.ssh_port
    timeout     = var.connection_timeout
  }

  # Uploaded to /tmp because the SSH user, not root, owns that path;
  # remote-exec below sudo-moves each into its real, root-owned location.
  provisioner "file" {
    source      = "${path.module}/../../templates/k8s-modules.conf"
    destination = "/tmp/k8s-modules.conf"
  }

  provisioner "file" {
    source      = "${path.module}/../../templates/k8s-sysctl.conf"
    destination = "/tmp/k8s-sysctl.conf"
  }

  provisioner "file" {
    source      = "${path.module}/../../templates/chrony-makestep.conf"
    destination = "/tmp/chrony-makestep.conf"
  }

  provisioner "remote-exec" {
    inline = [
      # --- Package updates: targeted install, not a blanket upgrade ---
      # (see modules/prerequisites/README.md for why a full `apt upgrade`
      # was deliberately rejected: non-idempotent in effect, and a
      # kernel bump here could demand a reboot Terraform never triggers)
      "sudo apt-get update -y",
      "sudo DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a apt-get install -y chrony nfs-common open-iscsi",

      # --- Chrony: systemd-timesyncd already owns NTP on a stock Ubuntu
      # image; running both time daemons at once is undefined behavior,
      # so timesyncd is explicitly stopped before chrony takes over.
      #
      # makestep override deployed here too, and unconditionally
      # restarted (not enable --now, which no-ops on an already-running
      # service — see modules/rke2-server for the same fix applied
      # there) so a config-only re-apply actually takes effect, and so
      # a VM-pause-induced clock jump gets step-corrected immediately
      # on this restart rather than waiting on slew that may never
      # catch up. Discovered live: see templates/chrony-makestep.conf.
      "sudo systemctl disable --now systemd-timesyncd || true",
      "sudo timedatectl set-timezone ${var.timezone}",
      "sudo mv /tmp/chrony-makestep.conf /etc/chrony/conf.d/90-makestep.conf",
      "sudo systemctl enable chrony",
      "sudo systemctl restart chrony",

      # --- Kernel modules + sysctl: modules must load *before* sysctl
      # --system runs, because net.bridge.bridge-nf-call-iptables only
      # exists in /proc once br_netfilter is loaded.
      "sudo mv /tmp/k8s-modules.conf /etc/modules-load.d/k8s.conf",
      "sudo mv /tmp/k8s-sysctl.conf /etc/sysctl.d/90-kubernetes.conf",
      "sudo modprobe overlay",
      "sudo modprobe br_netfilter",
      "sudo sysctl --system",

      # --- Swap: kubelet refuses to start with swap on. Disable now and
      # comment out (not delete) the fstab entry so a reboot doesn't
      # silently re-enable it. The regex only matches an *active*
      # (non-comment) swap line, so re-running this is a no-op.
      "sudo swapoff -a",
      "sudo sed -i '/^[^#].*\\sswap\\s/s/^/#/' /etc/fstab",

      # --- Open-iSCSI: required by Longhorn (Phase 12) for block-device
      # attach/detach. nfs-common ships no daemon to enable — its mount.nfs
      # client binary is all Longhorn's NFS backup target (Phase 16) needs.
      "sudo systemctl enable --now iscsid",

      # --- Firewall ---
      var.disable_firewall ? "sudo ufw disable" : "true",
    ]
  }
}
