output "control_planes" {
  description = "Map of CP node name -> {ip, proxmox_node, vmid}. Consumed by stacks/02-cluster."
  value = {
    for name, cp in var.control_planes : name => {
      ip           = cp.ip
      proxmox_node = cp.proxmox_node
      vmid         = cp.vmid
    }
  }
}

output "workers" {
  description = "Map of worker node name -> {ip, proxmox_node, vmid}."
  value = {
    for name, w in var.workers : name => {
      ip           = w.ip
      proxmox_node = w.proxmox_node
      vmid         = w.vmid
    }
  }
}

output "cp_ips" {
  description = "Flat list of CP IPs (for talosctl --nodes)."
  value       = [for cp in var.control_planes : cp.ip]
}

output "worker_ips" {
  description = "Flat list of worker IPs."
  value       = [for w in var.workers : w.ip]
}

output "all_ips" {
  value = concat(
    [for cp in var.control_planes : cp.ip],
    [for w in var.workers : w.ip],
  )
}

output "network" {
  description = "Network details, passed to 02-cluster for machine config."
  value = {
    cidr        = var.network_cidr
    gateway     = var.network_gateway
    nameservers = var.nameservers
  }
}

output "talos_version" {
  value = var.talos_version
}

output "talos_schematic_id" {
  value = var.talos_schematic_id
}
