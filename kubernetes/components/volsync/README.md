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
    VOLSYNC_CAPACITY: 10Gi
```

## Variables

| Name | Default | Description |
| ---- | ------- | ----------- |
| `APP` *(required)* | none | App name and resource prefix. |
| `VOLSYNC_ACCESSMODES` | `ReadWriteOnce` | PVC access mode. |
| `VOLSYNC_CACHE_CAPACITY` | `1Gi` | Restic cache PVC size. |
| `VOLSYNC_CAPACITY` | `5Gi` | Application data PVC size. |
| `VOLSYNC_TRIGGER_SCHEDULE` | `0 5 * * *` | Backup schedule. |

### Permissions

| Name | Default | Description |
| ---- | ------- | ----------- |
| `VOLSYNC_PUID` | `568` | Restic mover user. |
| `VOLSYNC_PGID` | `568` | Restic mover group. |
| `VOLSYNC_FS_GROUP` | `568` | Restic mover fsGroup. |
| `VOLSYNC_FS_GROUP_CHANGE_POLICY` | `OnRootMismatch` | fsGroup change policy. |
| `VOLSYNC_RUN_AS_NON_ROOT` | `true` | Restic mover non-root setting. |

## Resources

- `PersistentVolumeClaim` named `${APP}-${VOLSYNC_CLAIM}`
- `ReplicationSource` named `${APP}-${VOLSYNC_CLAIM}`
- `ReplicationDestination` named `${APP}-${VOLSYNC_CLAIM}`
- `ExternalSecret` named `${APP}-volsync-secret`

## Notes

- Backblaze credentials are read from the `backblaze` 1Password item.
- Restic repositories use `s3://${S3_BUCKET}/volsync/${APP}` through the generated secret.
- Only use one `data` backed-up claim per component instance.
