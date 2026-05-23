variable "talos_version" {
  description = "Talos Linux version, e.g. v1.9.4. Must match a build available on factory.talos.dev."
  type        = string
  default     = "v1.9.4"
}

variable "talos_schematic_id" {
  description = "Schematic ID from factory.talos.dev with iscsi-tools, util-linux-tools, qemu-guest-agent extensions."
  type        = string
}

variable "image_datastore_id" {
  description = "Proxmox storage that holds ISOs. Usually 'local' on every node."
  type        = string
  default     = "local"
}

variable "image_download_node" {
  description = "Which Proxmox node should host the downloaded ISO. Pick one — VMs on other nodes will reference the file by name."
  type        = string
}

variable "network_bridge" {
  description = "Proxmox bridge to attach VM NICs to (e.g. vmbr0)."
  type        = string
  default     = "vmbr0"
}

variable "network_cidr" {
  description = "Subnet CIDR the VM IPs live in (e.g. 192.168.1.0/24). Used only for documentation/output; per-VM IPs are static below."
  type        = string
}

variable "network_gateway" {
  description = "Default gateway for the Talos VMs."
  type        = string
}

variable "nameservers" {
  description = "DNS servers for the Talos VMs."
  type        = list(string)
  default     = ["1.1.1.1", "8.8.8.8"]
}

variable "cp_vm_spec" {
  description = "Hardware spec for control-plane VMs (one per Beelink)."
  type = object({
    cpu_cores = number
    memory_mb = number
    disk_gb   = number
  })
  default = {
    cpu_cores = 4
    memory_mb = 8192
    disk_gb   = 50
  }
}

variable "worker_vm_spec" {
  description = "Hardware spec applied per-worker (overridable per node in `workers`)."
  type = object({
    cpu_cores = number
    memory_mb = number
    disk_gb   = number
  })
  default = {
    cpu_cores = 6
    memory_mb = 16384
    disk_gb   = 200
  }
}

variable "control_planes" {
  description = "Map of CP VM name -> placement. Storage is per-node because Beelinks use local-zfs."
  type = map(object({
    proxmox_node = string
    datastore_id = string
    ip           = string
    vmid         = number
  }))
}

variable "workers" {
  description = "Map of worker VM name -> placement. i5 is local-lvm, Minisforum is local-zfs."
  type = map(object({
    proxmox_node = string
    datastore_id = string
    ip           = string
    vmid         = number
    cpu_cores    = optional(number)
    memory_mb    = optional(number)
    disk_gb      = optional(number)
  }))
}
