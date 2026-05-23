# 01 — Proxmox API token & prerequisites

The bpg/proxmox Terraform provider authenticates to Proxmox with an API token.
You do **not** want to use root for this. Create a dedicated `terraform@pve`
user with a least-privilege role.

## 1. Create the role, user, and token

SSH to any Proxmox node (or one of them in a cluster — users are cluster-wide)
and run:

```bash
# Role with everything the provider needs for VM, storage, networking, SDN.
pveum role add Terraform -privs "\
Datastore.Allocate \
Datastore.AllocateSpace \
Datastore.AllocateTemplate \
Datastore.Audit \
Pool.Allocate \
Pool.Audit \
Sys.Audit \
Sys.Console \
Sys.Modify \
SDN.Use \
VM.Allocate \
VM.Audit \
VM.Clone \
VM.Config.CDROM \
VM.Config.Cloudinit \
VM.Config.CPU \
VM.Config.Disk \
VM.Config.HWType \
VM.Config.Memory \
VM.Config.Network \
VM.Config.Options \
VM.Migrate \
VM.Monitor \
VM.PowerMgmt \
User.Modify"

# Service user in the PVE realm.
pveum user add terraform@pve

# Grant the role at the datacenter scope.
pveum aclmod / -user terraform@pve -role Terraform

# Create the token. Drop `--privsep 0` if you want token-scoped permissions
# (more work — you'd then have to re-grant the role to the token too).
pveum user token add terraform@pve tf --privsep=0
```

The last command prints something like:

```
┌──────────────┬──────────────────────────────────────┐
│ key          │ value                                │
├──────────────┼──────────────────────────────────────┤
│ full-tokenid │ terraform@pve!tf                     │
│ value        │ 12345678-90ab-cdef-1234-567890abcdef │
└──────────────┴──────────────────────────────────────┘
```

The `value` is shown **once**. Copy it into `.envrc`:

```bash
export PROXMOX_VE_API_TOKEN="terraform@pve!tf=12345678-90ab-cdef-1234-567890abcdef"
```

## 2. Verify

```bash
direnv allow
curl -sk "$PROXMOX_VE_ENDPOINT/api2/json/version" \
  -H "Authorization: PVEAPIToken=$PROXMOX_VE_API_TOKEN" | jq .
```

You should see a `data.version` field.

## 3. SSH access (optional but recommended)

The provider falls back to SSH for operations the API can't do (e.g. uploading
files to a storage that doesn't expose an upload API). Make sure:

- Your SSH key is in `root@<pve-node>:~/.ssh/authorized_keys` for **every**
  Proxmox host in the cluster.
- `ssh-agent` has the key loaded (`ssh-add -l`).

## 4. Talos Image Factory schematic

Visit <https://factory.talos.dev>, pick the latest stable Talos version, then
under **System Extensions** check:

- `siderolabs/iscsi-tools`
- `siderolabs/util-linux-tools`
- `siderolabs/qemu-guest-agent`

Submit. You'll get a schematic ID (64-char hex). Paste it into
`stacks/01-infra/terraform.tfvars` as `talos_schematic_id`.
