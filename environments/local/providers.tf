# Only providers actually consumed by resources declared *in this
# environment today* are configured here. The kubernetes and helm
# providers are deliberately absent — they arrive in Phase 6 and Phase 7
# respectively, once a kubeconfig actually exists for them to talk to.
# Declaring a provider before anything uses it is dead configuration.

provider "random" {}

provider "tls" {}

provider "local" {}

provider "null" {}
