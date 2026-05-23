# Initialize etcd on the first control plane. Runs exactly once per cluster.
resource "talos_machine_bootstrap" "this" {
  depends_on = [talos_machine_configuration_apply.cp]

  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = local.bootstrap_node
  endpoint             = local.bootstrap_node
}

# Wait for the cluster API to come up and pull the admin kubeconfig.
resource "talos_cluster_kubeconfig" "this" {
  depends_on = [talos_machine_bootstrap.this]

  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = local.bootstrap_node
  endpoint             = local.bootstrap_node
}

# Optional readiness gate so downstream stacks (03-addons) only start once the
# control plane reports healthy.
data "talos_cluster_health" "this" {
  depends_on = [talos_cluster_kubeconfig.this]

  client_configuration = talos_machine_secrets.this.client_configuration
  control_plane_nodes  = local.cp_ips
  worker_nodes         = local.worker_ips
  endpoints            = local.cp_ips
}
