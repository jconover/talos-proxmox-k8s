# 03 — Day-2 operations

## Talos upgrade

Talos upgrades replace the OS image atomically. Bump `talos_version` in
`stacks/01-infra/terraform.tfvars` (this regenerates the install image URL via
the factory schematic), then in `02-cluster`:

```bash
talosctl upgrade --nodes <ip> --image factory.talos.dev/installer/<schematic_id>:<version>
```

Roll one node at a time, watching `kubectl get nodes` between each. Upgrade
workers first, then control planes, finishing with the bootstrap node.

For Kubernetes version bumps, set the new version in `stacks/02-cluster/terraform.tfvars`
(`kubernetes_version`), then:

```bash
talosctl --nodes <cp-ip> upgrade-k8s --to <version>
```

## Replacing a node

1. Cordon and drain in Kubernetes: `kubectl drain vex-wk-02 --ignore-daemonsets --delete-emptydir-data`.
2. Reset the Talos node: `talosctl reset --nodes <ip> --graceful=false --reboot`.
3. `terraform taint` the VM in `01-infra` and re-apply.
4. Re-apply `02-cluster` — the machine config will be re-applied and the node
   will rejoin.

## etcd member removal

If a CP is destroyed without `talosctl reset` first, you'll have a stale etcd
member. Remove it:

```bash
talosctl etcd members
talosctl etcd remove-member <member-id>
```

## Kubeconfig / talosconfig regeneration

Both come from `02-cluster` outputs:

```bash
cd stacks/02-cluster
terraform output -raw talosconfig > ~/.talos/config
terraform output -raw kubeconfig  > ~/.kube/vex.yaml
```

The secrets backing them live in the `02-cluster` Terraform state
(`talos_machine_secrets.this`). Back up `stacks/02-cluster/terraform.tfstate`
offline — losing it loses the PKI and you cannot rejoin nodes.

## Longhorn maintenance

- UI: `kubectl -n longhorn-system port-forward svc/longhorn-frontend 8080:80`.
- Replica count default is 2 (set in `stacks/03-addons/longhorn.tf`); bump to 3
  if you can afford the disk.
- The i5 worker uses `local-lvm` for the VM disk; Longhorn is fine on top of
  that since it only sees the filesystem inside the Talos VM.

## Monitoring etcd / control plane

```bash
talosctl --nodes <cp-ip> service etcd status
talosctl --nodes <cp-ip> logs etcd
talosctl --nodes <cp-ip> dashboard      # TUI
```

## Reset everything (nuclear)

```bash
# Reset each node back to maintenance mode.
talosctl reset --nodes <ip1>,<ip2>,... --graceful=false --reboot \
  --system-labels-to-wipe STATE --system-labels-to-wipe EPHEMERAL
```

Or simpler: `terraform destroy` in `01-infra` and start over.
