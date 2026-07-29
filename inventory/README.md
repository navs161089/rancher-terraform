# inventory

Human-readable, **committed** record of physical lab topology — which
machines exist, their role, IP, and hostname. Safe to version control:
private LAN IPs and hostnames, no credentials.

This is deliberately *not* what Terraform reads. The machine-readable
copy of the same data lives in `environments/local/terraform.tfvars`
(the `nodes` variable), which stays gitignored because it's environment
config, not durable infrastructure fact, and per-operator paths (like
`ssh_private_key_path`) live in the same file. Keeping a plain-English
copy here means you can answer "what's actually in this lab" by reading
one markdown file instead of decoding HCL — and it gives us a diffable
history of the physical topology independent of Terraform config churn.

Update `local.md` whenever a node is added, removed, or re-IP'd.
