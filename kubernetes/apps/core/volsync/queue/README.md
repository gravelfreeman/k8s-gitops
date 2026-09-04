# volsync-queue

Minimal, purpose-built queue using VolSync's official copy-trigger mechanism
to serialize backups. It runs with least-privilege limited to reading
`ReplicationSource` and PVC state, and patching PVCs to set copy triggers.

## How it works

Every day at `05:00` in `America/Toronto`, the queue:

1. Lists all `ReplicationSource` resources in the cluster.
2. Keeps resources whose source PVC has the `volsync.backube/use-copy-trigger: "true"` annotation.
3. Skips targets listed in `VOLSYNC_QUEUE_EXCLUDE_TARGETS` as space-separated `namespace/pvc` values.
4. Processes the PVCs one at a time, in a stable namespace/PVC order.
5. Sets `volsync.backube/copy-trigger` and waits for the replication to complete.

The queue continues processing the remaining PVCs when one replication fails or times out. The Job/pod ends in `Failed` if any replication fails, times out, or the Kubernetes API cannot be reached.

## Usage

Copy the `queue` directory into your repository next to your VolSync application:

```text
kubernetes/apps/core/volsync/
├── app/
│   ├── kustomization.yaml
│   └── ...
└── queue/
    ├── cronjob.yaml
    ├── kustomization.yaml
    ├── rbac.yaml
    └── volsync-queue.sh
```

Reference it from `app/kustomization.yaml`:

```yaml
resources:
  - ../queue
```

The source PVCs must use the copy-trigger annotation:

```yaml
metadata:
  annotations:
    volsync.backube/use-copy-trigger: "true"
```

> [!NOTE]
> The `spec.trigger.schedule` configured on each `ReplicationSource` is when the PVC becomes ready for the queue. It should match the queue `CronJob.spec.schedule`; **match both schedules**.

### Script Variables

| Name | Default | Description |
| ---- | :-----: | ----------- |
| `VOLSYNC_QUEUE_DEBUG` | `0` | Enables debug logging when set to `1`. |
| `VOLSYNC_QUEUE_IDLE_TIMEOUT_SECONDS` | `600` | Time to wait for a PVC to be ready for a trigger. |
| `VOLSYNC_QUEUE_EXCLUDE_TARGETS` | empty | Space-separated `namespace/pvc` targets to skip. |
| `VOLSYNC_QUEUE_POLL_INTERVAL_SECONDS` | `10` | Replication status polling interval. |
| `VOLSYNC_QUEUE_RUN_TIMEOUT_SECONDS` | `7200` | Time to wait for a replication to complete. |

### CronJob Variables

Adjust these fields in `cronjob.yaml` as needed:

| Field | Default | Description |
| ----- | :-----: | ----------- |
| `spec.schedule` | `0 5 * * *` | Queue execution schedule. |
| `spec.timeZone` | `America/Toronto` | Time zone used by the schedule. |
| `spec.suspend` | `false` | Set to `true` to pause the queue. |
| `spec.successfulJobsHistoryLimit` | `1` | Number of successful Jobs to retain. |
| `spec.failedJobsHistoryLimit` | `1` | Number of failed Jobs to retain. |

> [!IMPORTANT]
> Keep `spec.concurrencyPolicy: Forbid` so two queue runs cannot overlap.

## Prerequisites

- VolSync and its CRDs are installed.
- The cluster contains the `ReplicationSource` resources to process.
- The `volsync` namespace exists.

## Resources

- `CronJob` named `volsync-queue`
- `ServiceAccount` named `volsync-queue`
- Cluster-wide `ClusterRole` and `ClusterRoleBinding`
- ConfigMap containing `volsync-queue.sh`
