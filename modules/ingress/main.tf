# WHY these specific value overrides — verified against the chart's
# actual values.yaml (helm show values ingress-nginx/ingress-nginx),
# not guessed:
#
# - controller.kind=DaemonSet + controller.hostNetwork=true: this is a
#   bare-metal lab with no cloud LoadBalancer and no MetalLB. The
#   chart's default (Deployment + Service type=LoadBalancer) would
#   leave the Service stuck in <pending> forever with no path for
#   external traffic in. Binding directly to each node's 80/443 via
#   hostNetwork is exactly what RKE2's own bundled ingress-nginx addon
#   does by default, for the identical reason — we're replacing it
#   (see the `disable: rke2-ingress-nginx` in modules/rke2-server), not
#   deviating from its architecture.
# - controller.dnsPolicy=ClusterFirstWithHostNet: required whenever
#   hostNetwork is true. Without it, this pod silently inherits the
#   host's /etc/resolv.conf instead of cluster DNS — an easy-to-miss
#   gotcha, so it's called out explicitly rather than left implicit.
# - controller.service.type=ClusterIP: the Service object is still
#   created (chart internals expect it to exist), but real traffic
#   arrives via the hostNetwork ports directly, not through this
#   Service.
# WHY take_ownership: confirmed live (not anticipated in advance) that
# RKE2's now-disabled rke2-ingress-nginx release left behind a
# cluster-scoped IngressClass named "nginx" — the chart's fixed default
# name, not prefixed per-release — still annotated as owned by
# "rke2-ingress-nginx"/kube-system. Helm 3 correctly refuses to
# silently adopt a resource owned by a different release; take_ownership
# is the provider's purpose-built flag for exactly this "migrating a
# shared-name resource from one release to another" case, rather than
# reaching for a kubectl-delete workaround outside Terraform's view.
# (The other leftovers — ClusterRole/rke2-ingress-nginx, the admission
# webhook — are release-name-prefixed, so they don't collide; they're
# just orphaned dead weight now that RKE2 no longer manages them.)
#
# WHY upgrade_install: also confirmed live, not anticipated — a prior
# apply attempt failed mid-install (a pre-install hook timed out on an
# unrelated, now-fixed cluster networking issue), leaving Helm with a
# release record for "ingress-nginx" in status=failed. Terraform's
# helm_release, on a fresh (state-less) create, calls plain `helm
# install`, which refuses to reuse a name Helm still has *any* record
# for — "cannot re-use a name that is still in use" — even though zero
# actual resources existed in the namespace. upgrade_install switches
# this to `helm upgrade --install` semantics, which is Helm's own
# documented recovery path for exactly this "previous install failed,
# try again" case. The provider's own docs flag this as not always
# production-appropriate (it will also silently adopt a release
# Terraform never created, from any source) — accepted here because
# this is a single-operator lab, not a shared environment where
# unexpected adoption is a real risk.
resource "helm_release" "ingress_nginx" {
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  version          = var.ingress_nginx_version
  namespace        = var.namespace
  create_namespace = true
  take_ownership   = true
  upgrade_install  = true

  values = [yamlencode({
    controller = {
      kind        = "DaemonSet"
      hostNetwork = true
      dnsPolicy   = "ClusterFirstWithHostNet"
      service = {
        type = "ClusterIP"
      }
      resources = {
        requests = {
          cpu    = "100m"
          memory = "90Mi"
        }
      }
    }
  })]
}
