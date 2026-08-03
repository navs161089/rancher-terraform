# WHY local-exec here, specifically:
#
# Every other imperative step in this repo (ssh, prerequisites,
# rke2-server, rke2-agent) runs *on* the remote node via remote-exec.
# This one is different: it needs to pull a file that already exists on
# the remote node (RKE2 generates /etc/rancher/rke2/rke2.yaml itself)
# down to the Terraform *workstation*. The `file` provisioner only
# copies local -> remote, and no provider in this repo's preferred list
# fetches an arbitrary remote file. `local-exec` running `ssh ... cat`
# is the standard, minimal-surface way to reverse that direction — it
# executes on the machine running `terraform apply`, not on the node.
#
# WHY refresh on every apply, unlike every other module here:
# every other null_resource in this repo hashes its desired content so
# `terraform plan` stays a true no-op between applies. This one
# deliberately does not — RKE2 can rotate the serving certificate inside
# this kubeconfig, and a silently stale local copy (kubectl failing with
# a certificate error days later) is a worse failure mode than one
# resource always showing as "changed" in the plan.
resource "null_resource" "fetch_kubeconfig" {
  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -euo pipefail
      ssh -i '${pathexpand(var.ssh_private_key_path)}' -p ${var.ssh_port} \
        -o StrictHostKeyChecking=accept-new -o BatchMode=yes \
        ${var.ssh_user}@${var.server_ip} 'sudo cat /etc/rancher/rke2/rke2.yaml' \
        | sed 's/127\.0\.0\.1:6443/${var.server_ip}:6443/' \
        > '${var.local_kubeconfig_path}'
      chmod 600 '${var.local_kubeconfig_path}'
    EOT
  }
}

# --- Cluster-level readiness validation -----------------------------------
#
# WHY depends_on on data sources — unusual, data sources normally read
# during `plan`: the kubernetes provider (configured in the root module)
# points config_path at the file null_resource.fetch_kubeconfig writes.
# On a from-scratch apply that file doesn't exist yet at plan time.
# depends_on forces Terraform to defer these specific reads to the apply
# phase, after the fetch has actually run — the documented fix for
# "provision a cluster and validate it with the kubernetes provider in
# one terraform apply" instead of requiring two separate applies.
#
# WHY postconditions, not a `check` block: `check` block assertion
# failures are warnings — plan/apply still succeeds. Every other gate in
# this repo (the readyz waits in rke2-server/rke2-agent) hard-fails the
# apply on an unhealthy cluster, and this should be consistent with
# that: a postcondition failure is a hard error.
data "kubernetes_nodes" "this" {
  depends_on = [null_resource.fetch_kubeconfig]

  lifecycle {
    postcondition {
      condition     = length(self.nodes) > 0
      error_message = "kubernetes API is reachable but returned zero nodes."
    }

    postcondition {
      condition = alltrue([
        for node in self.nodes : anytrue([
          for c in node.status[0].conditions : c.status == "True" if c.type == "Ready"
        ])
      ])
      error_message = "Node(s) not Ready: ${join(", ", [
        for node in self.nodes : node.metadata[0].name
        if !anytrue([for c in node.status[0].conditions : c.status == "True" if c.type == "Ready"])
      ])}"
    }
  }
}

data "kubernetes_resources" "kube_system_pods" {
  depends_on  = [null_resource.fetch_kubeconfig]
  api_version = "v1"
  kind        = "Pod"
  namespace   = "kube-system"

  # WHY "not Failed" rather than "already Running/Succeeded" — found
  # live, not designed in up front: a one-shot Job pod (e.g. RKE2's own
  # internal helm-delete-* cleanup jobs when an addon is disabled) is
  # legitimately Pending for a few seconds after creation, in a
  # perfectly healthy cluster. Asserting "already settled" against a
  # single point-in-time snapshot is inherently racy for anything
  # Job-managed — Pending is a normal, expected phase on the way to
  # Succeeded, not a failure. "Failed" is the one phase that's an
  # unambiguous, non-transient problem, so that's what this actually
  # gates on.
  lifecycle {
    postcondition {
      condition = alltrue([
        for pod in self.objects : pod.status.phase != "Failed"
      ])
      error_message = "kube-system pod(s) in Failed phase: ${join(", ", [
        for pod in self.objects : pod.metadata.name
        if pod.status.phase == "Failed"
      ])}"
    }
  }
}

# Reading this successfully IS the "API reachable" proof — a genuinely
# unreachable API fails this data source's read with a connection error,
# which halts the apply on its own. Kept as its own named data source
# (rather than relying on that side effect implicitly) so the intent is
# explicit and the version is available as an output.
data "kubernetes_server_version" "this" {
  depends_on = [null_resource.fetch_kubeconfig]
}
