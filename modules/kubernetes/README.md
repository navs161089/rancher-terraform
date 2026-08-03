# module: kubernetes

**Introduced in:** Phase 6 (kubeconfig retrieval landed slightly early,
pulled forward at the user's request to unblock local `kubectl` use;
cluster validation followed as the rest of Phase 6)

Two responsibilities, per the original phase scope:
1. **Kubeconfig retrieval** — fetch RKE2's generated admin kubeconfig
   from the server node to the Terraform workstation.
2. **Cluster-level readiness validation** — Node Ready, kube-system pods
   healthy, API reachable — enforced as hard `terraform apply` failures
   via data source postconditions, not just observed.

## The bootstrap ordering problem, and how it's solved

The `kubernetes` provider (configured in the root module) points
`config_path` at the file `null_resource.fetch_kubeconfig` writes. On a
genuinely from-scratch `terraform apply`, that file doesn't exist yet
when Terraform would normally read a data source — data sources are
read during the *plan* phase, before any resource in the same apply has
been created. Every `data "kubernetes_*"` block here carries
`depends_on = [null_resource.fetch_kubeconfig]`, which forces Terraform
to defer that specific read to the *apply* phase instead, after the
fetch has actually happened. This is the documented fix for "provision
a cluster and validate it with the kubernetes provider in one
`terraform apply`" — the alternative most guides reach for is splitting
into two separate root modules/applies, which this repo avoids.

## Why postconditions, not a `check` block

Terraform 1.5+ `check` blocks are the newer, more obvious-looking tool
for this — but a failed `check` assertion is only a **warning**;
`plan`/`apply` still succeeds. Every other gate in this repo (the
readyz waits in `rke2-server`/`rke2-agent`) hard-fails the apply on an
unhealthy cluster. Postconditions on the data sources keep that same
guarantee: an unhealthy cluster fails `terraform apply`, full stop.

## Why `local-exec`, not a provider

Full reasoning is inline in `main.tf`. Short version: this is the only
module in the repo that pulls a file *from* a remote node *to* the
Terraform workstation — every other module's imperative work runs on
the remote node itself. `file` provisioners only go local → remote, so
there's no way to do this declaratively with the providers this repo
uses.

## Why this resource always re-runs (unlike every other module here)

Every other `null_resource` in this repo hashes its desired content so
`terraform plan` stays a no-op between applies. This one uses
`timestamp()` deliberately — RKE2 can rotate the serving certificate
inside the kubeconfig, and a silently stale local copy is a worse
failure mode (a `kubectl` cert error days later, with no obvious cause)
than one resource always showing as "changed."

## The kube-system pod check gates on "not Failed", not "already Running"

Found live, not designed in up front: the first version of this
postcondition demanded every kube-system pod already be
`Running`/`Succeeded`. That broke the very first time RKE2 spawned an
internal one-shot Job pod (a `helm-delete-*` cleanup job, triggered by
disabling an addon in Phase 7) — its pod was legitimately `Pending` for
a few seconds, in an otherwise perfectly healthy cluster. Asserting
"already settled" against a single point-in-time snapshot is inherently
racy for anything Job-managed. `Failed` is the one phase that's an
unambiguous, non-transient problem, so that's what the postcondition
actually checks now.

## Where the kubeconfig goes, and why not `~/.kube/config`

Written to a dedicated, gitignored path (`environments/local/kubeconfig`
via the root module) — never directly at `~/.kube/config`. That file is
shared, hand-edited, and likely has other clusters' contexts in it;
Terraform overwriting it programmatically risks clobbering state it
doesn't own. Use it via:

```bash
export KUBECONFIG=$(pwd)/environments/local/kubeconfig
kubectl get nodes
```

or merge it into your default config yourself if you want it permanent
(`kubectl config view --flatten` after setting `KUBECONFIG` to both
paths colon-separated).
