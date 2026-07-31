# Only providers actually consumed by resources declared *in this
# environment today* are configured here. The helm provider is
# deliberately still absent — it arrives in Phase 7, once there's an
# ingress controller to install with it. Declaring a provider before
# anything uses it is dead configuration.

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
