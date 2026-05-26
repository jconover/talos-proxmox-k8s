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

## Renaming nodes

Talos generates auto hostnames like `talos-uar-myn` by default (the
provider's `HostnameConfig: auto: stable`). To rename, patch each node's
`HostnameConfig` directly. The trick: `hostname:` alone trips `'auto' and
'hostname' cannot be set at the same time` because strategic merge keeps
the inherited `auto: stable`. Set `auto: "off"` explicitly — it means
"auto-derivation disabled, use the static hostname":

```bash
talosctl patch mc -n 192.168.68.201 --patch '
apiVersion: v1alpha1
kind: HostnameConfig
auto: "off"
hostname: vex-cp-01
'
```

Applies without reboot. Kubelet re-registers under the new hostname,
leaving the old Node object orphaned — delete it:

```bash
kubectl delete node talos-uar-myn
```

**Critical follow-up — Cilium endpoint identities go stale.** Pods that
existed before the rename keep their old Cilium identity and cannot
reach in-cluster ClusterIPs (incl. `kubernetes.default` at `10.96.0.1`).
They keep running but service-to-service traffic breaks silently. After
any node rename, restart pre-existing workloads:

```bash
# Restart all longhorn-system pods (or whichever namespaces had pre-rename pods)
kubectl -n longhorn-system delete pod --all
# Or cluster-wide if you're not sure what's pre-existing:
kubectl get pods -A -o json | jq -r '.items[] | select(.metadata.creationTimestamp < "<rename-time>") | "kubectl -n \(.metadata.namespace) delete pod \(.metadata.name)"' | sh
```

Symptom of this hitting you: a Service has `<none>` for endpoints, and
the backing Deployment's pods log "no route to host" or
"connect: connection refused" when calling Kubernetes-API or other
ClusterIPs.

## Longhorn maintenance

- UI: `kubectl -n longhorn-system port-forward svc/longhorn-frontend 8080:80`.
- Replica count default is 2 (set in `stacks/03-addons/longhorn.tf`); bump to 3
  if you can afford the disk.
- The i5 worker uses `local-lvm` for the VM disk; Longhorn is fine on top of
  that since it only sees the filesystem inside the Talos VM.

### Updating Longhorn settings after install

Helm only writes Longhorn's `defaultSettings.*` values on **first
install**. Re-running `helm upgrade` (or `terraform apply`) with new
values does NOT update existing `Setting` CRs. To change a setting on a
live cluster, patch the Setting directly and roll the controller that
reads it:

```bash
kubectl -n longhorn-system patch setting <setting-name> \
  --type=merge -p '{"value":"<new-value>"}'
kubectl -n longhorn-system rollout restart deployment longhorn-driver-deployer
```

`system-managed-components-node-selector`, `default-replica-count`, and
similar live in CRs that survive helm-only updates.

### Talos-on-Longhorn install gotchas

- `csi.kubeletRootDir: /var/lib/kubelet` is required in helm values.
  Talos restricts `/proc` visibility, so Longhorn's
  `discover-proc-kubelet-cmdline` pod can't auto-detect the kubelet
  args and `longhorn-driver-deployer` crashloops with "Need to specify
  `--kubelet-root-dir`".
- Do not set `systemManagedComponentsNodeSelector` to
  `node-role.kubernetes.io/worker:` — Talos doesn't label workers with
  this. CPs are already tainted, so CSI sidecars skip them naturally.
- If `longhorn-admission-webhook` Service has `<none>` endpoints, the
  `longhorn-manager` pods are stuck on leader election (check with
  `kubectl logs -n longhorn-system <pod> -c longhorn-manager` for
  "Error retrieving lease lock"). Usually a stale-Cilium-identity
  issue — see Renaming nodes above.

## Verifying the stack with a smoke test

Exercises Longhorn (PVC), MetalLB (LoadBalancer), and Cilium (cross-node
pod routing) in one shot. Useful after upgrades or any cluster surgery:

```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Namespace
metadata: { name: smoketest }
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata: { name: web-content, namespace: smoketest }
spec:
  accessModes: [ReadWriteOnce]
  storageClassName: longhorn
  resources: { requests: { storage: 1Gi } }
---
apiVersion: apps/v1
kind: Deployment
metadata: { name: vex-hello, namespace: smoketest }
spec:
  replicas: 1
  selector: { matchLabels: { app: vex-hello } }
  template:
    metadata: { labels: { app: vex-hello } }
    spec:
      initContainers:
        - name: seed
          image: busybox:1.36
          command: [sh, -c, '[ -f /data/index.html ] || echo "<h1>Vex Hello $(date)</h1>" > /data/index.html']
          volumeMounts: [{ name: content, mountPath: /data }]
      containers:
        - name: nginx
          image: nginx:1.27-alpine
          ports: [{ containerPort: 80 }]
          volumeMounts: [{ name: content, mountPath: /usr/share/nginx/html }]
      volumes:
        - name: content
          persistentVolumeClaim: { claimName: web-content }
---
apiVersion: v1
kind: Service
metadata: { name: vex-hello, namespace: smoketest }
spec:
  type: LoadBalancer
  selector: { app: vex-hello }
  ports: [{ port: 80, targetPort: 80 }]
EOF

# Wait for ready, then hit the LB:
kubectl -n smoketest wait --for=condition=ready pod -l app=vex-hello --timeout=180s
LB=$(kubectl -n smoketest get svc vex-hello -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
curl -s http://$LB/

# Persistence check: kill pod, verify same content after respawn.
kubectl -n smoketest delete pod -l app=vex-hello
kubectl -n smoketest wait --for=condition=ready pod -l app=vex-hello --timeout=120s
curl -s http://$LB/   # timestamp on the page should be unchanged

# Teardown:
kubectl delete namespace smoketest
```

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
