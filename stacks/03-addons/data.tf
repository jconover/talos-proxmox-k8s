data "terraform_remote_state" "cluster" {
  backend = "local"
  config = {
    path = var.cluster_state_path
  }
}

locals {
  cluster_endpoint_vip = data.terraform_remote_state.cluster.outputs.cluster_endpoint_vip
  kube_proxy_disabled  = data.terraform_remote_state.cluster.outputs.kube_proxy_disabled
}
