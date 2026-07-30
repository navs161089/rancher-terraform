# module: rke2-server

**Introduced in:** Phase 4

Installs and configures the RKE2 server (control-plane) role on every
node in `var.nodes`, using the officially published `get.rke2.io`
installer.

## Why `remote-exec`, not a provider

No provider models "install a vendor-published systemd service via its
own shell script." Full reasoning is inline in `main.tf`, including the
accepted supply-chain tradeoff of trusting `get.rke2.io` at execution
time (no checksum/signature pinning yet — a Phase 15 hardening
candidate, not solved here).

## Bootstrap vs joiner split — the actual HA design

`var.first_server_name` picks exactly one node to bootstrap the cluster
with no `server:` field in its config. Every other node in `var.nodes`
is a "joiner" that points `server:` at the bootstrap node's IP on
`:9345`, and — via `depends_on = [null_resource.rke2_first_server]` —
is guaranteed not to even attempt installation until the bootstrap
resource exists.

For today's 1-server lab, `local.joiner_nodes` is empty, so
`rke2_additional_servers` creates zero resources. Growing to 3
control-plane nodes later is a `nodes` map edit in `environments/local` —
nothing here changes. This is the concrete mechanism behind the
project's "extendable to HA without redesign" requirement.

## Why a wait loop after starting the bootstrap server

`systemctl enable --now rke2-server.service` returning 0 only means the
service *started* — not that the apiserver is actually answering.
Joiners that race ahead of a not-yet-ready bootstrap server is a real
RKE2 HA failure mode. The bounded retry loop (`/readyz`, 30 attempts,
10s apart, then a hard failure) is a join-ordering gate internal to this
module, deliberately narrower than Phase 6's cluster validation — Phase
6 checks cluster health from the operator's perspective after the fact;
this only unblocks joiners.

## TLS SANs

Every server's certificate gets `tls-san` entries for every server
node's IP (`local.all_server_ips`), not just its own — any of them may
end up serving `kubectl`/Rancher traffic. `var.extra_tls_sans` exists
for a future load-balancer VIP or DNS name once real HA is in place;
empty is correct today.

## kubeconfig permissions

`write-kubeconfig-mode: "0600"` is set explicitly (not left to whatever
RKE2's own default happens to be) — root-only, on purpose. Phase 6
fetches it via `sudo cat` over SSH rather than loosening this.

## Inputs / Outputs

Takes `module.prerequisites.prepared_nodes` (filtered to `role ==
"server"`) as `nodes`, and the root module's generated `cluster_token` —
never generate the token here; it must be identical to what
`modules/rke2-agent` (Phase 5) uses to join.
