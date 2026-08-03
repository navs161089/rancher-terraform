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
- **`chrony`'s `makestep` limit is overridden to unlimited**
  (`templates/chrony-makestep.conf`, dropped into `/etc/chrony/conf.d/`).
  Discovered live, not anticipated: Ubuntu's default `makestep 1 3` only
  permits an instant clock-jump correction for chronyd's first 3 updates
  after starting — fine for a physical server, but this lab runs on VMs
  that get paused/suspended (the host Mac sleeping), and a guest clock
  frozen for hours during a pause blows straight past that 3-update
  budget. The result: chrony reports the correct offset but can only
  slew, never actually closing an hours-long gap — and every new pod's
  ServiceAccount token then fails API server validation as
  "Unauthorized" (the token looks valid to the node's wrong clock, but
  the server, with correct time, has long since expired it). Confirmed
  live: `rke-slave1` drifted 46 hours this way before being caught.

## Idempotency

`triggers` hash the three template files plus `timezone`/
`disable_firewall`/`ssh_user`, so `terraform plan` stays a no-op between
applies unless desired state actually changed. Every inline command was
written to be safe to re-run (the fstab sed only matches an *active*,
non-commented swap line; `modprobe`/`apt-get install`/`ufw disable` are
naturally idempotent; chrony is explicitly `restart`ed, not
`enable --now`, because the latter no-ops on an already-running service
and would silently never apply a config-only change like the makestep
override).

## Inputs / Outputs

Takes `module.ssh.checked_nodes` (stripped to `ip`/`role`) as `nodes`,
not `var.nodes` directly, so this module cannot run before the SSH
connectivity check succeeds. Exposes `prepared_nodes` for the same
reason downstream (`rke2-server`, `rke2-agent` should depend on *this*
module's output, not on `var.nodes`).
