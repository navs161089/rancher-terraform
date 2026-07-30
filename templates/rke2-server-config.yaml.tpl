token: "${token}"
%{ if server_url != "" }
server: "${server_url}"
%{ endif ~}
cni: "canal"
cluster-cidr: "${pod_cidr}"
service-cidr: "${service_cidr}"
cluster-dns: "${cluster_dns}"
write-kubeconfig-mode: "0600"
tls-san:
%{ for san in tls_sans ~}
  - "${san}"
%{ endfor ~}
