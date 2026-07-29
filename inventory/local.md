# Inventory: local

| hostname | role | ip | ssh user | notes |
|---|---|---|---|---|
| rke-master | server (control-plane) | 192.168.105.2 | ansible | initial/bootstrap server (Phase 4) |
| rke-slave1 | agent (worker) | 192.168.105.3 | ansible | |

- OS: Ubuntu Server 24.04 LTS (installed manually, out of Terraform's scope)
- SSH: key-based, passwordless sudo for `ansible` on both nodes — confirmed 2026-07-28
- SSH key (workstation-local path): `~/.ssh/id_ed25519`
