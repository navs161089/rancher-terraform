# Local state backend for the "local" lab environment.
#
# Why "local" and not remote (S3/azurerm/gcs/Terraform Cloud) right now:
#   - Single operator, single workstation, no team to coordinate with yet.
#   - No cloud account exists in this lab to host remote state anyway.
#   - Introducing a remote backend before it's needed adds an external
#     dependency and a chicken-and-egg bootstrap problem for no benefit.
#
# What we lose by choosing "local": state locking (two concurrent applies
# can corrupt state) and no off-machine durability (lose the laptop, lose
# the state). Both are acceptable for a single-operator local lab and are
# mitigated by (a) never running Terraform from two shells at once, and
# (b) *.tfstate being backed up like any other file worth keeping — but
# never committed to git (see .gitignore).
#
# Migration path: swap this block for `backend "s3" {}` (or azurerm/gcs/
# cloud) and run `terraform init -migrate-state`. No other .tf file in
# this environment changes — that's the whole point of isolating this in
# its own file.
terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
}
