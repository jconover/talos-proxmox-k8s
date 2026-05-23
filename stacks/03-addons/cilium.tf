# Cilium replaces flannel (CNI=none in 02-cluster) and kube-proxy.
# Values follow the Talos-recommended Cilium config:
#   https://www.talos.dev/v1.9/kubernetes-guides/network/deploying-cilium/
resource "helm_release" "cilium" {
  name             = "cilium"
  namespace        = "kube-system"
  repository       = "https://helm.cilium.io"
  chart            = "cilium"
  version          = var.cilium_version
  create_namespace = false
  atomic           = true
  wait             = true
  timeout          = 600

  values = [yamlencode({
    ipam = {
      mode = "kubernetes"
    }
    kubeProxyReplacement = local.kube_proxy_disabled ? "true" : "false"

    # Talos: kube-apiserver is reachable via the VIP, not a kubernetes svc IP
    # (because kube-proxy is gone).
    k8sServiceHost = local.cluster_endpoint_vip
    k8sServicePort = 6443

    # Talos requires these capabilities to be granted explicitly.
    securityContext = {
      capabilities = {
        ciliumAgent      = ["CHOWN", "KILL", "NET_ADMIN", "NET_RAW", "IPC_LOCK", "SYS_ADMIN", "SYS_RESOURCE", "DAC_OVERRIDE", "FOWNER", "SETGID", "SETUID"]
        cleanCiliumState = ["NET_ADMIN", "SYS_ADMIN", "SYS_RESOURCE"]
      }
    }

    # cgroup v2 on the host root
    cgroup = {
      autoMount = { enabled = false }
      hostRoot  = "/sys/fs/cgroup"
    }

    hubble = {
      enabled = true
      relay   = { enabled = true }
      ui      = { enabled = true }
    }
  })]
}
