# Bootstrap

This directory contains the initial Kubernetes bootstrap, before Flux can manage the cluster.

Its purpose is to install the minimum required for the cluster to become self-managed:
Cilium, cert-manager, External Secrets, OnePassword Connect, Flux Operator, and Flux Instance.

## Usage

Normal order after applying the Talos configs:

```bash
task bootstrap:talos
```
```bash
task talos:generate-kubeconfig
```
```bash
task bootstrap:cloudflare NAME=<tunnel-name>
```
```bash
task bootstrap:openebs-lvm
```
```bash
task bootstrap:apps
```

## Taskfile Commands

### `task bootstrap:<command>`

| Command | Purpose |
| ------- | ------- |
| `talos` | Bootstrap the Talos control plane and refresh the local kubeconfig after all node configs are applied. |
| `cloudflare` | Create Cloudflare local tunnel. |
| `openebs-lvm` | Prepare the `lvmvg` volume group on every Talos node. |
| `apps` | Install the initial Kubernetes components with Helmfile after Talos and OpenEBS LVM are prepared. |
| `helmfile` | Internal task used by `apps` to apply bootstrap CRDs, then sync the bootstrap Helm releases. |

## Files

- `Taskfile.yaml`
  Kubernetes bootstrap commands.

- `resources.yaml`
  Seed secrets for OnePassword Connect injected at runtime with `op inject`.

- `helmfile.d/00-crds.yaml`
  CRDs applied before Flux for resources used early in the repo.

- `helmfile.d/01-apps.yaml`
  Helm releases installed before Flux.

- `helmfile.d/templates/values.yaml.gotmpl`
  Reuses values from the GitOps `HelmRelease` manifests.

## Notes

- `GIT_REPOSITORY_URL` and `OP_VAULT` are defined in the root `Taskfile.yaml`.
