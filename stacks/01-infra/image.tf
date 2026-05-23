# Download the Talos ISO directly from the Image Factory onto the chosen
# Proxmox node. Other nodes in the cluster will reference this ISO via the
# shared storage path (works because `local` is per-node but the file_id is
# just a string the API resolves on the target node — for non-shared storage
# you'd need to either upload to a shared store like NFS, or download per
# node and key VMs to their host's copy).
#
# For a small home-lab we keep it simple: download once to `image_download_node`
# and configure every VM to live on the same node's `local` for its ISO ref.
# (Boot ISO doesn't need to be on the VM's main datastore.)

resource "proxmox_download_file" "talos_iso" {
  for_each = toset(local.iso_nodes)

  content_type        = "iso"
  datastore_id        = var.image_datastore_id
  node_name           = each.value
  file_name           = "talos-${var.talos_version}-${substr(var.talos_schematic_id, 0, 8)}.iso"
  url                 = "https://factory.talos.dev/image/${var.talos_schematic_id}/${var.talos_version}/metal-amd64.iso"
  overwrite           = false
  overwrite_unmanaged = true
}

locals {
  # Build the set of Proxmox nodes that need a local copy of the ISO — every
  # node that hosts at least one Talos VM.
  iso_nodes = distinct(concat(
    [for cp in var.control_planes : cp.proxmox_node],
    [for w in var.workers : w.proxmox_node],
  ))
}
