provider "random" {}

provider "tls" {}

provider "local" {}

provider "null" {}

# config_path is a literal path string, not derived from an unknown
# resource attribute — that's what makes it safe to configure here even
# though the file it points at is written mid-apply by
# module.kubernetes. See modules/kubernetes/README.md ("The bootstrap
# ordering problem") for why every data source that actually reads
# through this provider still needs its own depends_on.
provider "kubernetes" {
  config_path = local.kubeconfig_path
}

# Same config_path reasoning as the kubernetes provider above. Note the
# nested `kubernetes = { ... }` object syntax (not a `kubernetes {}`
# block) — this is the v3.x helm provider's schema, confirmed against
# its current docs, not carried over from memory of older v2.x syntax.
provider "helm" {
  kubernetes = {
    config_path = local.kubeconfig_path
  }
}
