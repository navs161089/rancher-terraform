# module: ingress

**Introduced in:** Phase 7

Installs ingress-nginx via the Helm provider — replacing, not
supplementing, RKE2's own bundled ingress-nginx addon.

## Why replace RKE2's built-in ingress-nginx at all

RKE2 ships and manages its own `rke2-ingress-nginx` by default. Running
a second, Terraform-owned ingress-nginx alongside it would conflict.
The alternative — keep RKE2's and skip this module — was considered and
rejected: it works, but RKE2 (not Terraform) then owns the chart
version and values for a component this project explicitly wants
Terraform-native control over (chart version pinning independent of
RKE2's bundled version, custom values, and a clean attachment point for
Phase 15 NetworkPolicies and Phase 13 Prometheus scraping annotations).
See `modules/rke2-server`'s `disabled_addons` — the corresponding
`disable: rke2-ingress-nginx` entry is what actually turns RKE2's
version off.

## Bare-metal values, verified against the real chart

`controller.kind=DaemonSet`, `controller.hostNetwork=true`,
`controller.dnsPolicy=ClusterFirstWithHostNet`,
`controller.service.type=ClusterIP` — full reasoning inline in
`main.tf`. Short version: no cloud LoadBalancer and no MetalLB exist in
this lab, so the chart's default `Service type=LoadBalancer` would sit
in `<pending>` forever. This mirrors what RKE2's own bundled addon does
by default, for the same reason.

## Ordering

This module depends on `module.rke2_server` (so the `disable:` config
change — and the resulting restart that actually tears down RKE2's
bundled controller — lands before this module tries to install a
second one) and `module.kubernetes` (so the helm provider has a
kubeconfig to talk through). See `environments/local/main.tf`.

## Two Helm-specific recovery flags, both discovered live

- **`take_ownership`**: RKE2's disabled release left a cluster-scoped
  `IngressClass/nginx` behind (fixed chart name, not release-prefixed),
  owned by the old `rke2-ingress-nginx` release. Helm 3 refuses to
  silently adopt a resource owned by a different release; this flag is
  the provider's purpose-built escape hatch for exactly that migration.
- **`upgrade_install`**: a prior apply failed mid-install (an unrelated
  cluster networking issue killed a pre-install hook), leaving Helm
  with a `status=failed` release record. A plain `helm install` (what
  `helm_release` does by default on a fresh Terraform state) refuses to
  reuse *any* existing release name, failed or not. This flag switches
  to `helm upgrade --install` semantics — Helm's own documented
  recovery path. Accepted despite the provider's "not always
  production-appropriate" warning because this is a single-operator
  lab, not a shared environment where silently adopting an
  unrelated release would be a real risk.

## Verifying chart facts before relying on them

Chart version and the exact `values.yaml` key paths used here
(`controller.kind`, `controller.hostNetwork`, `controller.dnsPolicy`,
`controller.service.type`, `controller.resources`) were confirmed live
via `helm show values ingress-nginx/ingress-nginx --version 4.15.1`,
not guessed — the same discipline applied after Phase 4's RKE2 version
guess turned out stale.
