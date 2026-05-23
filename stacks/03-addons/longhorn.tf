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

      # Workers only — don't put Longhorn replicas on the CP boxes.
      systemManagedComponentsNodeSelector = "node-role.kubernetes.io/worker:"
    }
    longhornManager = {
      tolerations = []
    }
  })]

  depends_on = [helm_release.cilium]
}
