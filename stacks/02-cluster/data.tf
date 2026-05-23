data "terraform_remote_state" "infra" {
  backend = "local"
  config = {
    path = var.infra_state_path
  }
}

locals {
  control_planes  = data.terraform_remote_state.infra.outputs.control_planes
  workers         = data.terraform_remote_state.infra.outputs.workers
  cp_ips          = data.terraform_remote_state.infra.outputs.cp_ips
  worker_ips      = data.terraform_remote_state.infra.outputs.worker_ips
  network         = data.terraform_remote_state.infra.outputs.network
  talos_version   = data.terraform_remote_state.infra.outputs.talos_version
  schematic_id    = data.terraform_remote_state.infra.outputs.talos_schematic_id
  installer_image = "factory.talos.dev/installer/${local.schematic_id}:${local.talos_version}"

  # The first CP is where we run `talos_machine_bootstrap` (etcd init).
  bootstrap_node = local.cp_ips[0]
}
