# CloudNativePG Component

Reusable CloudNativePG component with Barman Cloud backups.

## Usage

```yaml
components:
  - ../../../../components/cnpg
dependsOn:
  - name: cloudnative-pg
  - name: onepassword
postBuild:
  substitute:
    APP: *app
```

## Variables

### Application Settings

| Name | Default | Description |
| ---- | ------- | ----------- |
| `APP` *(required)* | none | App name and CNPG resource prefix. |
| `CNPG_DATABASE` | `${APP}` | Application database restored/created by CNPG. |
| `CNPG_USERNAME` | `${APP}` | Application owner/user restored/created by CNPG. |
| `CNPG_RECOVERY_SERVER_NAME` | `${APP}` | Barman recovery server name. |
| `CNPG_STORAGE_SIZE` | `10Gi` | Primary data PVC size. |

### PostgreSQL Runtime

| Name | Default | Description |
| ---- | ------- | ----------- |
| `CNPG_IMAGE_CATALOG_NAME` | `postgresql-system-trixie` | CNPG image catalog name. |
| `CNPG_IMAGE_CATALOG_MAJOR` | `18` | PostgreSQL major version. |
| `CNPG_POSTGRES_UID` | `26` | Postgres container UID. |
| `CNPG_POSTGRES_GID` | `26` | Postgres container GID. |
| `CNPG_SHARED_PRELOAD_LIBRARIES` | `[]` | PostgreSQL shared preload libraries. |

## Scheduling

The component runs three PostgreSQL instances.

The **hard** spread constraint allows up to two matching CNPG pods on the same node when fewer than two nodes are available, but prevents placing three members of the same CNPG cluster on one node. The **soft** spread constraint asks Kubernetes and the descheduler to restore an even spread when possible.

The descheduler is configured to rebalance only CNPG replicas, not primaries, after nodes return.

## Bootstrap

The base component bootstraps from Barman Cloud recovery.

For a brand-new application database with no existing backup, patch the generated
`Cluster` in the app `ks.yaml` to use `initdb`:

```yaml
patches:
  - patch: |-
      - op: replace
        path: /spec/bootstrap
        value:
          initdb:
            database: <app-name>
            owner: <app-name>
    target:
      group: postgresql.cnpg.io
      kind: Cluster
```

## Resources

- `Cluster` named `${APP}-cnpg`
- `ObjectStore` named `${APP}-barman-store`
- `PodMonitor` named `${APP}-cnpg`
- `ScheduledBackup` named `${APP}-cnpg`
- `ExternalSecret` named `${APP}-b2-secret`

## Notes

- The Backblaze credentials are read from the `backblaze` 1Password item.
- Restic repositories use `s3://${S3_BUCKET}/cnpg/${APP}` through the generated secret.
- Backups run daily at `05:00 EST/EDT` and target the standby when available.
- PVCs use `openebs-lvm`, letting CNPG replicate without adding write load to Ceph.
