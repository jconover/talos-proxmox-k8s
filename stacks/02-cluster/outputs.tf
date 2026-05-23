output "kubeconfig" {
  description = "Admin kubeconfig for the cluster. Pipe to ~/.kube/vex.yaml."
  value       = talos_cluster_kubeconfig.this.kubeconfig_raw
  sensitive   = true
}

output "talosconfig" {
  description = "talosctl client config. Pipe to ~/.talos/config."
  value       = data.talos_client_configuration.this.talos_config
  sensitive   = true
}

output "cluster_name" {
  value = var.cluster_name
}

output "cluster_endpoint" {
  value = "https://${var.cluster_endpoint_vip}:6443"
}

output "kubernetes_version" {
  value = var.kubernetes_version
}

output "kube_proxy_disabled" {
  value = var.kube_proxy_disabled
}

output "cni_none" {
  value = var.cni_none_for_cilium
}

output "cluster_endpoint_vip" {
  value = var.cluster_endpoint_vip
}
