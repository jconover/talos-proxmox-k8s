# PKI / cluster secrets. Backed by terraform state — back this state up!
resource "talos_machine_secrets" "this" {
  talos_version = local.talos_version
}

# Base client config (used for talosctl and by the resources below).
data "talos_client_configuration" "this" {
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoints            = local.cp_ips
  nodes                = concat(local.cp_ips, local.worker_ips)
}

# Per-node machine config: control plane
data "talos_machine_configuration" "cp" {
  for_each = local.control_planes

  cluster_name       = var.cluster_name
  cluster_endpoint   = "https://${var.cluster_endpoint_vip}:6443"
  machine_type       = "controlplane"
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  talos_version      = local.talos_version
  kubernetes_version = var.kubernetes_version

  config_patches = [
    yamlencode({
      machine = {
        install = {
          disk            = var.install_disk
          image           = local.installer_image
          wipe            = false
          extraKernelArgs = []
        }
        network = {
          interfaces = [{
            # Talos uses predictable interface names (PCI slot-derived). For
            # bpg/proxmox VMs with a single virtio NIC, the name is `ens18`,
            # not `eth0`. Hardcoding `eth0` causes the VIP operator to bind
            # to a nonexistent interface and silently fail.
            interface = "ens18"
            addresses = ["${each.value.ip}/${split("/", local.network.cidr)[1]}"]
            routes = [{
              network = "0.0.0.0/0"
              gateway = local.network.gateway
            }]
            # Run a CP-only VRRP/VIP so kube-apiserver has a stable address.
            vip = {
              ip = var.cluster_endpoint_vip
            }
          }]
          nameservers = local.network.nameservers
        }
      }
      cluster = merge(
        var.cni_none_for_cilium ? {
          network = { cni = { name = "none" } }
        } : {},
        var.kube_proxy_disabled ? {
          proxy = { disabled = true }
        } : {},
        {
          allowSchedulingOnControlPlanes = false
        },
      )
    }),
    # Replace the auto-generated HostnameConfig (auto: stable) with an
    # explicit name. Talos 1.13 rejects setting hostname in both the legacy
    # v1alpha1 machine.network.hostname and the new HostnameConfig doc.
    # Hostname intentionally not patched here. siderolabs/talos provider 0.11
    # auto-generates `kind: HostnameConfig / auto: stable` and there's no
    # strategic-merge or JSON-patch syntax that cleanly replaces it without
    # tripping "auto and hostname cannot be set at the same time" or being
    # rejected by the patcher. Talos will derive a stable hostname from the
    # machine ID at first boot. Set human-friendly names post-bootstrap with
    # `talosctl edit machineconfig --nodes <ip>` if desired.
  ]
}

# Per-node machine config: worker
data "talos_machine_configuration" "worker" {
  for_each = local.workers

  cluster_name       = var.cluster_name
  cluster_endpoint   = "https://${var.cluster_endpoint_vip}:6443"
  machine_type       = "worker"
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  talos_version      = local.talos_version
  kubernetes_version = var.kubernetes_version

  config_patches = [
    yamlencode({
      machine = {
        install = {
          disk  = var.install_disk
          image = local.installer_image
          wipe  = false
        }
        network = {
          interfaces = [{
            # Talos uses predictable interface names (PCI slot-derived). For
            # bpg/proxmox VMs with a single virtio NIC, the name is `ens18`,
            # not `eth0`. Hardcoding `eth0` causes the VIP operator to bind
            # to a nonexistent interface and silently fail.
            interface = "ens18"
            addresses = ["${each.value.ip}/${split("/", local.network.cidr)[1]}"]
            routes = [{
              network = "0.0.0.0/0"
              gateway = local.network.gateway
            }]
          }]
          nameservers = local.network.nameservers
        }
      }
    }),
    # Hostname intentionally not patched here. siderolabs/talos provider 0.11
    # auto-generates `kind: HostnameConfig / auto: stable` and there's no
    # strategic-merge or JSON-patch syntax that cleanly replaces it without
    # tripping "auto and hostname cannot be set at the same time" or being
    # rejected by the patcher. Talos will derive a stable hostname from the
    # machine ID at first boot. Set human-friendly names post-bootstrap with
    # `talosctl edit machineconfig --nodes <ip>` if desired.
  ]
}

# Push the machine config to each node (Talos pulls installer image and reboots).
resource "talos_machine_configuration_apply" "cp" {
  for_each = local.control_planes

  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.cp[each.key].machine_configuration
  node                        = each.value.ip
  endpoint                    = each.value.ip
}

resource "talos_machine_configuration_apply" "worker" {
  for_each = local.workers

  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.worker[each.key].machine_configuration
  node                        = each.value.ip
  endpoint                    = each.value.ip
}
