output "namespace" {
  description = "Namespace ingress-nginx was installed into."
  value       = var.namespace
}

output "release_status" {
  description = "Helm release status, e.g. \"deployed\". Failing to reach \"deployed\" fails terraform apply on its own (helm_release's default wait = true), so this is mostly for visibility."
  value       = helm_release.ingress_nginx.status
}
