# talos-proxmox-k8s

Terraform-driven Talos Linux Kubernetes cluster on a 5-node Proxmox VE cluster.

## Cluster layout

| Role         | Proxmox host    | CPU model        | Storage    | Talos VM       |
|--------------|-----------------|------------------|------------|----------------|
| control-plane| `pve-beelink-01`| Ryzen 7 6800U    | local-zfs  | `talos-cp-01`  |
| control-plane| `pve-beelink-02`| Ryzen 7 6800U    | local-zfs  | `talos-cp-02`  |
| control-plane| `pve-beelink-03`| Ryzen 7 6800U    | local-zfs  | `talos-cp-03`  |
| worker       | `pve-i5`        | Intel i5-10500   | local-lvm  | `talos-wk-01`  |
| worker       | `pve-minisforum`| Ryzen 9 6900HX   | local-zfs  | `talos-wk-02`  |

- 3 control planes on the identical Beelinks give you an HA etcd quorum.
- 2 workers carry the load (Minisforum is the beefiest box).
- Control planes are **not** schedulable for workloads.

## Stacks

The project is split into three independent Terraform stacks. Apply them in order — each later stack reads outputs of the previous via `terraform_remote_state`.

| Order | Stack             | What it does                                                      |
|-------|-------------------|-------------------------------------------------------------------|
| 1     | `stacks/01-infra` | Downloads the Talos image, creates 5 VMs on Proxmox.              |
| 2     | `stacks/02-cluster` | Generates Talos machine config, applies it, bootstraps etcd.    |
| 3     | `stacks/03-addons`| Installs Cilium (CNI), MetalLB (LB), Longhorn (storage) via Helm. |

## Quickstart

```bash
# 0. Create a Proxmox API token (see docs/01-proxmox-setup.md)
cp .envrc.example .envrc && $EDITOR .envrc
direnv allow

# 1. Provision VMs
cd stacks/01-infra
cp terraform.tfvars.example terraform.tfvars && $EDITOR terraform.tfvars
terraform init && terraform apply

# 2. Bootstrap Talos + Kubernetes
cd ../02-cluster
cp terraform.tfvars.example terraform.tfvars && $EDITOR terraform.tfvars
terraform init && terraform apply
terraform output -raw kubeconfig > ~/.kube/talos-homelab.yaml
terraform output -raw talosconfig > ~/.talos/config

# 3. Install cluster add-ons
cd ../03-addons
cp terraform.tfvars.example terraform.tfvars && $EDITOR terraform.tfvars
terraform init && terraform apply
```

Full step-by-step in [`docs/02-apply-order.md`](docs/02-apply-order.md).

## Prerequisites

- Proxmox VE 8.x cluster (5 nodes) with the storage IDs above already configured.
- `terraform` >= 1.6, `talosctl`, `kubectl`, `helm`, `direnv` (optional).
- An API token for a non-root Proxmox user (see `docs/01-proxmox-setup.md`).
- A Talos Image Factory schematic ID with the extensions:
  - `siderolabs/iscsi-tools` (Longhorn)
  - `siderolabs/util-linux-tools` (Longhorn)
  - `siderolabs/qemu-guest-agent` (Proxmox)

  Generate one at <https://factory.talos.dev>.

## Day-2

See [`docs/03-day2-ops.md`](docs/03-day2-ops.md) for upgrades, node replacement, and reset procedures.
