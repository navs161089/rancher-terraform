variable "ingress_nginx_version" {
  description = "ingress-nginx Helm chart version, e.g. \"4.15.1\". Verify against `helm search repo ingress-nginx/ingress-nginx --versions` before changing — an unpinned or non-existent version fails at apply, not plan."
  type        = string
}

variable "namespace" {
  description = "Namespace the ingress-nginx release is installed into. Created automatically if it doesn't exist."
  type        = string
  default     = "ingress-nginx"
}
