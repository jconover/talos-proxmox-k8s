# 02 — Apply order

The three stacks must be applied in order. Each later stack reads outputs from
the earlier one via `terraform_remote_state` (local backend, file path).

## 0. One-time setup

```bash
cp .envrc.example .envrc && $EDITOR .envrc
direnv allow
```

## 1. `stacks/01-infra` — Proxmox VMs

```bash
cd stacks/01-infra
cp terraform.tfvars.example terraform.tfvars
$EDITOR terraform.tfvars   # fill in proxmox_nodes, network, schematic ID
terraform init
terraform plan -out tfplan
terraform apply tfplan
```

When this finishes you should see 5 VMs running in Proxmox, each booted off the
Talos ISO and waiting at the `maintenance` screen (no machine config yet).

Sanity check:

```bash
terraform output cp_ips
terraform output worker_ips
```

## 2. `stacks/02-cluster` — Talos bootstrap

```bash
cd ../02-cluster
cp terraform.tfvars.example terraform.tfvars
$EDITOR terraform.tfvars   # fill in cluster_name, endpoint VIP, etc.
terraform init
terraform apply
```

This will:

1. Generate `talos_machine_secrets` (PKI for the cluster).
2. Render machine config for each CP and worker node.
3. Apply it via `talos_machine_configuration_apply` (Talos pulls the install
   image from the factory, reboots into installed state).
4. Run `talos_machine_bootstrap` against `vex-cp-01` (etcd bootstrap).
5. Wait for `talos_cluster_kubeconfig`.

Export the configs:

```bash
mkdir -p ~/.talos ~/.kube
terraform output -raw talosconfig > ~/.talos/config
terraform output -raw kubeconfig  > ~/.kube/vex.yaml
export KUBECONFIG=~/.kube/vex.yaml

talosctl health --talosconfig ~/.talos/config
kubectl get nodes
```

All 5 nodes should appear, but `NotReady` until the CNI is installed.

## 3. `stacks/03-addons` — Cilium, MetalLB, Longhorn

```bash
cd ../03-addons
cp terraform.tfvars.example terraform.tfvars
$EDITOR terraform.tfvars   # MetalLB IP pool range
terraform init
terraform apply
```

This installs:

- **Cilium** with `kubeProxyReplacement=true` (Talos ships without kube-proxy
  when you select that mode — see `02-cluster` machine config).
- **MetalLB** with an L2 IPAddressPool.
- **Longhorn** with default 2-replica storage class.

After ~3 minutes:

```bash
kubectl get nodes                  # all Ready
kubectl get pods -A                # everything Running
kubectl get storageclass           # longhorn (default)
kubectl get ipaddresspool -n metallb-system
```

## Tearing down

Destroy in reverse order:

```bash
cd stacks/03-addons && terraform destroy
cd ../02-cluster     && terraform destroy
cd ../01-infra       && terraform destroy
```

Note: destroying `02-cluster` does **not** wipe the disk on the Talos nodes —
the install partition remains. If you destroy then re-apply `01-infra`, the
VMs will be re-created from scratch (clean ISO boot).
