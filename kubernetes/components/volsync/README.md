# Volsync Component

Reusable VolSync restic backup component for one app PVC.

## Usage

```yaml
components:
  - ../../../../components/volsync
dependsOn:
  - name: onepassword
  - name: volsync
postBuild:
  substitute:
    APP: *app
```

### ReadWriteMany

For an RWX claim using CephFS, set:

```yaml
VOLSYNC_ACCESSMODES: ReadWriteMany
VOLSYNC_STORAGECLASS: ceph-filesystem
VOLSYNC_SNAPSHOT_CLASS: csi-ceph-filesystem
```

## Variables

| Name | Default | Description |
| ---- | ------- | ----------- |
| `APP` *(required)* | none | App name and resource prefix. |
| `VOLSYNC_ACCESSMODES` | `ReadWriteOnce` | PVC access mode. |
| `VOLSYNC_CACHE_CAPACITY` | `1Gi` | Restic cache PVC size. |
| `VOLSYNC_CAPACITY` | `10Gi` | Application data PVC size. |
| `VOLSYNC_SNAPSHOT_CLASS` | `csi-ceph-block` | PVC volume snapshot class. |
| `VOLSYNC_STORAGECLASS` | `ceph-block` | PVC storage class. |
| `VOLSYNC_TRIGGER_SCHEDULE` | `0 5 * * *` | Backup schedule. |

### Permissions

| Name | Default | Description |
| ---- | ------- | ----------- |
| `VOLSYNC_UID` | `568` | Default value for the Restic mover user, group, and fsGroup. |
| `VOLSYNC_PUID` | `${VOLSYNC_UID}` | Override for the Restic mover user. |
| `VOLSYNC_PGID` | `${VOLSYNC_UID}` | Override for the Restic mover group. |
| `VOLSYNC_FS_GROUP` | `${VOLSYNC_UID}` | Override for the Restic mover fsGroup. |
| `VOLSYNC_FS_GROUP_CHANGE_POLICY` | `OnRootMismatch` | fsGroup change policy. |
| `VOLSYNC_RUN_AS_NON_ROOT` | `true` | Restic mover non-root setting. |

## Resources

- `PersistentVolumeClaim` named `${APP}-data`
- `ReplicationSource` named `${APP}-data`
- `ReplicationDestination` named `${APP}-data`
- `ExternalSecret` named `${APP}-volsync-secret`

## Notes

- Backblaze credentials are read from the `backblaze` 1Password item.
- Restic repositories use `s3://${S3_BUCKET}/volsync/${APP}` through the generated secret.
- Only use one `data` backed-up claim per component instance.
