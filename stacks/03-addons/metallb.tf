resource "kubernetes_namespace" "metallb" {
  metadata {
    name = "metallb-system"
    labels = {
      "pod-security.kubernetes.io/enforce" = "privileged"
      "pod-security.kubernetes.io/audit"   = "privileged"
      "pod-security.kubernetes.io/warn"    = "privileged"
    }
  }
}

resource "helm_release" "metallb" {
  name       = "metallb"
  namespace  = kubernetes_namespace.metallb.metadata[0].name
  repository = "https://metallb.github.io/metallb"
  chart      = "metallb"
  version    = var.metallb_version
  atomic     = true
  wait       = true
  timeout    = 600

  # MetalLB 0.16's frr-k8s subchart references prometheus.serviceMonitor.enabled
  # with no default, so installs without an explicit value error at templating.
  # Disable Prometheus integration (we're not running Prometheus yet).
  values = [yamlencode({
    prometheus = {
      serviceMonitor = { enabled = false }
      podMonitor     = { enabled = false }
    }
    frr-k8s = {
      enabled = false
      prometheus = {
        serviceMonitor = { enabled = false }
        podMonitor     = { enabled = false }
      }
    }
  })]

  depends_on = [helm_release.cilium]
}

resource "kubernetes_manifest" "metallb_pool" {
  manifest = {
    apiVersion = "metallb.io/v1beta1"
    kind       = "IPAddressPool"
    metadata = {
      name      = "default-pool"
      namespace = kubernetes_namespace.metallb.metadata[0].name
    }
    spec = {
      addresses = var.metallb_address_pool
    }
  }

  depends_on = [helm_release.metallb]
}

resource "kubernetes_manifest" "metallb_l2adv" {
  manifest = {
    apiVersion = "metallb.io/v1beta1"
    kind       = "L2Advertisement"
    metadata = {
      name      = "default-l2"
      namespace = kubernetes_namespace.metallb.metadata[0].name
    }
    spec = {
      ipAddressPools = ["default-pool"]
    }
  }

  depends_on = [kubernetes_manifest.metallb_pool]
}
