# module: prerequisites

**Introduced in:** Phase 3

Prepares every node (server and agent alike — RKE2 requires the same OS
baseline regardless of role) for RKE2 installation: kernel modules,
sysctl, swap disabled, chrony, open-iscsi, nfs-common, and (by default)
ufw disabled.

## Why `file` + `remote-exec`, not a provider

There is no provider in this repo's preferred list for OS configuration
management — that's deliberately outside what `kubernetes`/`helm`/`tls`/
`random`/`local`/`null` do. `file` uploads declarative config content
from `templates/` (version-controlled, not a heredoc); `remote-exec`
applies it plus the handful of steps with no provider equivalent
(`modprobe`, `swapoff`, `apt-get install`). Full reasoning is inline in
`main.tf`.

## Design decisions made explicitly (see chat history / commit for the tradeoffs)

- **Package updates are a targeted install, not `apt upgrade -y`.** Only
  `chrony`, `nfs-common`, `open-iscsi` are installed. A blanket system
  upgrade was rejected: it's non-idempotent in effect (drifts with
  upstream over time), can pull in a kernel bump that needs a reboot
  Terraform never triggers, and makes `apply` behavior depend on when
  you happened to run it.
- **ufw is explicitly disabled by default** (`disable_firewall = true`).
  RKE2 manages its own iptables/nftables rules for pod networking; a
  host firewall on top of that is the most common RKE2 support issue
  upstream, and matches Rancher's own hardening guidance. Set
  `disable_firewall = false` to leave firewall state out of scope
  entirely (not "manage a port allow-list" — that's a different, larger
  feature nobody has asked for yet).
- **systemd-timesyncd is stopped before chrony starts.** Ubuntu ships
  timesyncd active by default; running it alongside chrony is undefined
  behavior, not a supported dual-NTP-daemon setup.
- **Ordering matters**: kernel modules load before `sysctl --system`,
  because `net.bridge.bridge-nf-call-iptables` only exists under
  `/proc/sys` once `br_netfilter` is loaded — running sysctl first would
  silently fail to apply that key.

## Idempotency

`triggers` hash the two template files plus `timezone`/`disable_firewall`/
`ssh_user`, so `terraform plan` stays a no-op between applies unless
desired state actually changed. Every inline command was written to be
safe to re-run (the fstab sed only matches an *active*, non-commented
swap line; `modprobe`/`apt-get install`/`ufw disable` are naturally
idempotent).

## Inputs / Outputs

Takes `module.ssh.checked_nodes` (stripped to `ip`/`role`) as `nodes`,
not `var.nodes` directly, so this module cannot run before the SSH
connectivity check succeeds. Exposes `prepared_nodes` for the same
reason downstream (`rke2-server`, `rke2-agent` should depend on *this*
module's output, not on `var.nodes`).
