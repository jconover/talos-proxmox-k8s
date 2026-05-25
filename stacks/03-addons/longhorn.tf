resource "kubernetes_namespace" "longhorn" {
  metadata {
    name = "longhorn-system"
    labels = {
      "pod-security.kubernetes.io/enforce" = "privileged"
      "pod-security.kubernetes.io/audit"   = "privileged"
      "pod-security.kubernetes.io/warn"    = "privileged"
    }
  }
}

resource "helm_release" "longhorn" {
  name       = "longhorn"
  namespace  = kubernetes_namespace.longhorn.metadata[0].name
  repository = "https://charts.longhorn.io"
  chart      = "longhorn"
  version    = var.longhorn_version
  atomic     = true
  wait       = true
  timeout    = 900

  values = [yamlencode({
    persistence = {
      defaultClass             = true
      defaultClassReplicaCount = var.longhorn_replica_count
    }
    defaultSettings = {
      defaultReplicaCount = var.longhorn_replica_count

      # Talos uses /var/lib/longhorn — Talos extensions already mount it.
      defaultDataPath = "/var/lib/longhorn"

      # No systemManagedComponentsNodeSelector — Talos doesn't auto-label
      # workers with `node-role.kubernetes.io/worker=`. CPs are already
      # tainted with `node-role.kubernetes.io/control-plane:NoSchedule`
      # so CSI pods skip them naturally; no extra selector needed.
    }
    csi = {
      # Talos restricts /proc visibility, so Longhorn's auto-discovery pod
      # (`discover-proc-kubelet-cmdline`) can't scrape the kubelet's args.
      # Set the root dir explicitly so the driver-deployer doesn't crash.
      kubeletRootDir = "/var/lib/kubelet"
    }
    longhornManager = {
      tolerations = []
    }
  })]

  depends_on = [helm_release.cilium]
}
