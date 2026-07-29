# module: ssh

**Introduced in:** Phase 2

Proves, as a standalone Terraform resource, that every node in `var.nodes`
is reachable over SSH as `var.ssh_user` with the configured key and has
passwordless sudo. Nothing else — no OS changes, no packages.

## Why this exists as its own module

Every later module (`prerequisites`, `rke2-server`, `rke2-agent`, ...)
assumes SSH already works. Without a dedicated check, a bad key path or a
sudoers misconfiguration surfaces as a cryptic failure deep inside a
kernel-module or RKE2-install step. This module fails fast, with the
failing node's name right in the resource address
(`module.ssh.null_resource.connectivity_check["rke-master"]`).

## Why `remote-exec`, not a provider

No provider in this repo's preferred list (`kubernetes`, `helm`, `tls`,
`random`, `local`, `null`) can open an SSH session and run a command.
`remote-exec` inside a `null_resource` is the sanctioned Terraform
escape hatch for exactly this: an imperative, one-off action with no
declarative provider equivalent. See the comment in `main.tf` for the
full reasoning.

## Inputs / Outputs

See `variables.tf` / `outputs.tf`. `checked_nodes` exists purely so
downstream modules can depend on the check having *succeeded*, not just
on `var.nodes` existing — reference `module.ssh.checked_nodes` instead
of `var.nodes` wherever a module's provisioning genuinely requires SSH
to already be proven working.

## Re-running the check

`triggers` are keyed on IP, user, port, and the SSH private key's
content hash — so `terraform plan` stays a no-op between applies unless
one of those actually changed. To force a re-check without changing
anything: `terraform apply -replace='module.ssh.null_resource.connectivity_check["<name>"]'`.
