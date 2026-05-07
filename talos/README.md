# Talos

This directory contains the versioned Talos sources for the cluster.

## Usage

Generate the SecureBoot ISO:

```bash
task talos:generate-iso
```

Apply the config to each node:

```bash
task talos:apply-node NODE=10.0.10.101
task talos:apply-node NODE=10.0.10.102
task talos:apply-node NODE=10.0.10.103
```

Then proceed with the [bootstrap workflow](../bootstrap/README.md).

## Taskfile Commands

### `task talos:<command>`

| Command | Purpose |
| ------- | ------- |
| `generate-iso` | Generate a Talos Image Factory schematic and download the SecureBoot ISO. |
| `generate-schematic` | Render `schematic.yaml.j2` and return the Image Factory ID. |
| `apply-node¹²` | Render, inject, patch, and apply the Talos machine config for one node. |
| `generate-kubeconfig` | Fetch the `kubeconfig` from a Talos control plane node. |
| `generate-secrets` | Generate a Talos secrets bundle to stdout for the initial bootstrap. |
| `reboot-node¹²` | Reboot a Talos node.  |
| `reset-node¹` | Reset a Talos node; this is **destructive**. |
| `upgrade-node¹` | Upgrade Talos on a node using the install image defined in the node machineconfig. |

- **¹** *Required:* `NODE=<ip>`
- **²** *Optional:* `MODE=<auto|no-reboot|reboot|staged|try>`

## Files

- `Taskfile.yaml`
  Talos commands.

- `controlplane/*.yaml`
  Per-node machine config patches; for install disk, hostname, network interface, static IP, and topology labels.

- `machineconfig.yaml.j2`
  Common machine config template; for k8s, secrets, storage, kernel modules, and system settings.

- `networking.yaml`
  Common network patch applied to every node.

- `schematic.yaml.j2`
  Talos extensions for the Image Factory image.

## Init Talos Config

```
mkdir -p /home/vscode/.talos /tmp/talos-bootstrap
```
```
talosctl gen secrets \
  --talos-version v1.13.0 \
  --output-file /tmp/talos-bootstrap/secrets.yaml
```
```
talosctl gen config k8s https://10.0.10.100:6443 \
  --with-secrets /tmp/talos-bootstrap/secrets.yaml \
  --output /home/vscode/.talos/config \
  --output-types talosconfig \
  --force
```
```
chmod 600 /home/vscode/.talos/config
```
```
talosctl config endpoint 10.0.10.101 10.0.10.102 10.0.10.103
talosctl config node 10.0.10.101 10.0.10.102 10.0.10.103
```

## Notes

- Rendered configs are generated in memory, injected with `op`, then sent to Talos with `talosctl`.
- `OP_VAULT`, `GIT_REPOSITORY_URL`, `TALOS_DIR`, and `KUBERNETES_DIR` come from the root `Taskfile.yaml`.
- `KUBECONFIG` and `TALOSCONFIG` come from the devcontainer and point to `$HOME`, not the repo.
- Talos artifacts, such as ISO images, are written to `/tmp/talos`, mounted from the host cache.
