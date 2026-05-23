output "cilium_release" {
  value = helm_release.cilium.metadata[0].version
}

output "metallb_release" {
  value = helm_release.metallb.metadata[0].version
}

output "longhorn_release" {
  value = helm_release.longhorn.metadata[0].version
}

output "metallb_pool" {
  value = var.metallb_address_pool
}
