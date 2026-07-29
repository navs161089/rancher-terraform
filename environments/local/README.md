# environment: local

Root module for the local, single-operator lab: 1 RKE2 server + 1 RKE2
worker on the network described in `terraform.tfvars`.

This is the only environment that exists today. When this platform moves
to a cloud or additional bare-metal target, that target becomes a sibling
directory (`environments/aws`, `environments/vmware`, ...) that composes
the same `modules/*` with different variable values and, likely, a
different `backend.tf`. Nothing in `modules/` should ever assume "local"
— that assumption belongs only here.

## Usage

```bash
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars with real IPs, versions, domain

terraform init
terraform plan
terraform apply
```

## Files

| File | Purpose |
|---|---|
| `versions.tf` | Terraform + provider version constraints |
| `backend.tf` | State backend (local, for now) |
| `providers.tf` | Provider configuration blocks |
| `variables.tf` | Full input contract for the platform |
| `locals.tf` | Derived naming/labeling used by every module |
| `outputs.tf` | Surfaced values (empty until Phase 4+) |
| `terraform.tfvars.example` | Template for real variable values |
