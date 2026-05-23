locals {
  cp_iso_id = {
    for name, cp in var.control_planes :
    name => proxmox_download_file.talos_iso[cp.proxmox_node].id
  }
  worker_iso_id = {
    for name, w in var.workers :
    name => proxmox_download_file.talos_iso[w.proxmox_node].id
  }
}

# -----------------------------------------------------------------------------
# Control-plane VMs (3x — one per Beelink)
# -----------------------------------------------------------------------------
resource "proxmox_virtual_environment_vm" "cp" {
  for_each = var.control_planes

  name        = each.key
  description = "Talos control plane — managed by Terraform"
  tags        = ["talos", "control-plane", "terraform"]

  node_name = each.value.proxmox_node
  vm_id     = each.value.vmid

  machine       = "q35"
  bios          = "seabios"
  scsi_hardware = "virtio-scsi-single"

  agent {
    enabled = true
    trim    = true
  }

  cpu {
    cores = var.cp_vm_spec.cpu_cores
    type  = "host"
  }

  memory {
    dedicated = var.cp_vm_spec.memory_mb
  }

  network_device {
    bridge   = var.network_bridge
    model    = "virtio"
    firewall = false
  }

  disk {
    datastore_id = each.value.datastore_id
    interface    = "scsi0"
    iothread     = true
    size         = var.cp_vm_spec.disk_gb
    file_format  = "raw"
    discard      = "on"
    ssd          = true
  }

  cdrom {
    file_id   = local.cp_iso_id[each.key]
    interface = "ide2"
  }

  boot_order = ["scsi0", "ide2"]

  operating_system {
    type = "l26"
  }

  # Talos config is applied out-of-band in stack 02. Don't let TF churn on
  # the VM whenever Talos updates internal state.
  lifecycle {
    ignore_changes = [
      cdrom,
      started,
    ]
  }
}

# -----------------------------------------------------------------------------
# Worker VMs (i5 + Minisforum)
# -----------------------------------------------------------------------------
resource "proxmox_virtual_environment_vm" "worker" {
  for_each = var.workers

  name        = each.key
  description = "Talos worker — managed by Terraform"
  tags        = ["talos", "worker", "terraform"]

  node_name = each.value.proxmox_node
  vm_id     = each.value.vmid

  machine       = "q35"
  bios          = "seabios"
  scsi_hardware = "virtio-scsi-single"

  agent {
    enabled = true
    trim    = true
  }

  cpu {
    cores = coalesce(each.value.cpu_cores, var.worker_vm_spec.cpu_cores)
    type  = "host"
  }

  memory {
    dedicated = coalesce(each.value.memory_mb, var.worker_vm_spec.memory_mb)
  }

  network_device {
    bridge   = var.network_bridge
    model    = "virtio"
    firewall = false
  }

  disk {
    datastore_id = each.value.datastore_id
    interface    = "scsi0"
    iothread     = true
    size         = coalesce(each.value.disk_gb, var.worker_vm_spec.disk_gb)
    file_format  = each.value.datastore_id == "local-lvm" ? "raw" : "raw"
    discard      = "on"
    ssd          = true
  }

  cdrom {
    file_id   = local.worker_iso_id[each.key]
    interface = "ide2"
  }

  boot_order = ["scsi0", "ide2"]

  operating_system {
    type = "l26"
  }

  lifecycle {
    ignore_changes = [
      cdrom,
      started,
    ]
  }
}
