# rancher-terraform

Terraform-managed Rancher/RKE2 platform, built incrementally from a bare
Ubuntu lab up to an HA-capable, cloud-portable Kubernetes platform.

Everything past base OS installation, static networking, and passwordless
SSH is owned by Terraform — no ad-hoc `kubectl apply`, no hand-run Helm
installs, no manual Rancher clicks that Terraform doesn't know about.

## Status

Building in phases. Current: **Phase 7 — Ingress NGINX**.

- [x] Phase 1 — Repository Architecture
- [x] Phase 2 — SSH Connectivity
- [x] Phase 3 — Linux Preparation
- [x] Phase 4 — RKE2 Server Installation
- [x] Phase 5 — Worker Installation
- [x] Phase 6 — Cluster Validation
- [x] Phase 7 — Ingress NGINX
- [ ] Phase 8 — cert-manager
- [ ] Phase 9 — TLS (self-signed + Let's Encrypt)
- [ ] Phase 10 — Install Rancher
- [ ] Phase 11 — Rancher health wait + bootstrap password
- [ ] Phase 12 — Install Longhorn
- [ ] Phase 13 — Monitoring (Prometheus/Grafana/Alertmanager)
- [ ] Phase 14 — Logging (Loki/Promtail)
- [ ] Phase 15 — Security (RBAC/NetworkPolicies/PSA)
- [ ] Phase 16 — Backup (etcd/Longhorn/Rancher)
- [ ] Phase 17 — Documentation

## Architecture

```
                      environments/local (root module)
                                  |
        +---------+---------+---------+---------+---------+
        |         |         |         |         |         |
       ssh   prerequisites  rke2-*  kubernetes  ingress  cert-manager
                                                    |
                                    +---------------+---------------+
                                    |               |               |
                                 rancher        longhorn        monitoring / logging
```

Every box above is a module in `modules/`. `environments/local` is the
only place that knows concrete IPs, hostnames, or the fact that this is a
2-node lab — modules take inputs and never hardcode environment facts.
That's what makes adding `environments/aws` later a matter of writing a
new root module, not rewriting `modules/`.

## Repository layout

```
rancher-terraform/
  bootstrap/        one-time infra needed before a remote backend can exist (empty until we leave "local")
  environments/
    local/           root module for the 1-server/1-worker lab (current)
  modules/           one module per concern — see each module's README.md
  templates/         templatefile() sources consumed by modules
  scripts/           helper scripts for humans, never invoked by Terraform
  inventory/         host inventory consumed by ssh/prerequisites (Phase 2)
  docs/              architecture + per-module reference docs
  examples/          example consumers of modules/ beyond environments/local
```

## Prerequisites

- Terraform >= 1.9.0 (developed against 1.15.x)
- 1+ Ubuntu Server 24.04 LTS node(s) with static IP, hostname, and
  passwordless SSH already configured (see project scope — this repo
  does not install the OS)
- An SSH key pair Terraform can use non-interactively

## Getting started

```bash
cd environments/local
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars
terraform init
terraform plan
```

## Design decisions

- **No nested `terraform-rancher/` folder.** The original spec's tree
  starts with a `terraform-rancher/` root; this git repository (already
  named `rancher-terraform`) *is* that root. Nesting an identically-purposed
  folder one level deeper would only add a path prefix with no benefit.
- **`local-exec` / `remote-exec` policy.** Preferred providers
  (`kubernetes`, `helm`, `tls`, `random`, `local`, `null`) cover nearly
  everything. Where RKE2 install genuinely requires running a remote
  script Rancher itself publishes (no Terraform provider wraps
  `rke2-install.sh`), a `null_resource` + `remote-exec`/`connection`
  block is used — and the specific justification is written down at the
  point of use in that module's README, not asserted here in the
  abstract.
- **State backend.** `local` for now, justified in
  `environments/local/backend.tf`. Revisited if/when this becomes a
  multi-operator or cloud environment.

## Module documentation

Each module under `modules/` has its own `README.md` describing what it
does, why it exists, and which phase introduces it. Start there before
reading any module's `.tf` files.
