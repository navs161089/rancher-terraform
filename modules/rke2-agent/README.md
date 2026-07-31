# module: rke2-agent

**Introduced in:** Phase 5

Installs RKE2 agent (worker) role on every node in `var.nodes` and
joins it to the cluster bootstrapped by `modules/rke2-server`, using
the same officially published `get.rke2.io` installer.

## Why simpler than rke2-server

Every agent is symmetric — there's no bootstrap/joiner split here, just
one `null_resource "rke2_agent"` `for_each` over every agent node. All
of them join against the same `server_url` (`https://<first_server_ip>:9345`).

## Why `remote-exec`, not a provider

Identical justification to `modules/rke2-server` — see that module's
`main.tf` for the full reasoning, including the accepted `curl | sh`
supply-chain tradeoff (a Phase 15 hardening candidate, not solved here).

## The local join gate — and a lesson applied from Phase 4

After starting `rke2-agent.service`, this module waits (bounded retry,
same 30×10s pattern as `rke2-server`) on kubelet's own `/healthz` at
`http://localhost:10248/healthz`. That endpoint is deliberately chosen
over anything requiring credentials: Phase 4's first attempt at a
readiness gate polled the apiserver's `/readyz` anonymously and got a
`401` forever, even though the cluster was actually healthy, because
that endpoint requires authentication. Kubelet's `/healthz` is
loopback-only and unauthenticated by design, so this module doesn't
repeat that mistake.

This is a *local* gate (confirms kubelet on this node came up), not
cluster validation — Phase 6 is where "does the server see this node as
Ready" gets checked, from the operator's perspective, against the API.

## Inputs / Outputs

Takes `module.prerequisites.prepared_nodes` (filtered to `role ==
"agent"`) as `nodes`, `module.rke2_server.first_server_ip` (not a
locally-recomputed IP) as `first_server_ip` — referencing the module
output, not a local value, is what forces this module to wait for the
server's apiserver to actually be ready, not merely for its IP to be
known — and the same `cluster_token` used by `rke2-server`.
