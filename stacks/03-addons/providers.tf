locals {
  kubeconfig_yaml = data.terraform_remote_state.cluster.outputs.kubeconfig
  kubeconfig      = yamldecode(local.kubeconfig_yaml)

  cluster_ctx     = local.kubeconfig.contexts[0]
  cluster_name    = local.cluster_ctx.context.cluster
  cluster_cluster = [for c in local.kubeconfig.clusters : c.cluster if c.name == local.cluster_name][0]
  user_name       = local.cluster_ctx.context.user
  cluster_user    = [for u in local.kubeconfig.users : u.user if u.name == local.user_name][0]
}

provider "kubernetes" {
  host                   = local.cluster_cluster.server
  cluster_ca_certificate = base64decode(local.cluster_cluster["certificate-authority-data"])
  client_certificate     = base64decode(local.cluster_user["client-certificate-data"])
  client_key             = base64decode(local.cluster_user["client-key-data"])
}

provider "helm" {
  kubernetes {
    host                   = local.cluster_cluster.server
    cluster_ca_certificate = base64decode(local.cluster_cluster["certificate-authority-data"])
    client_certificate     = base64decode(local.cluster_user["client-certificate-data"])
    client_key             = base64decode(local.cluster_user["client-key-data"])
  }
}
