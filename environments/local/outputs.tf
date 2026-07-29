# Intentionally empty in Phase 1 — there are no resources yet to output
# anything about. Outputs are added incrementally as each phase's module
# produces something worth surfacing:
#   Phase 6  -> kubeconfig
#   Phase 10 -> rancher_url, rancher_bootstrap_password
#   Phase 12 -> longhorn_url
#   Phase 13 -> grafana_url, prometheus_url
#   Phase 4  -> cluster_token (sensitive), node_information
