# TrueNAS NFS-Ganesha Media Export

This directory stores the TrueNAS Custom App configuration for exporting the
`mergerfs-all-rw` mount through NFS-Ganesha.

## Why This Exists

TrueNAS kernel NFS can export normal ZFS datasets such as `/mnt/eden/media`, but
it did not accept the FUSE-backed mergerfs mount at `/mnt/core/media-rw` as a
real NFSv4 export. Kubernetes could see the TrueNAS export in `showmount`, but
NFSv4 mount attempts failed with `No such file or directory`.

NFS-Ganesha is a user-space NFS server. It exports the already-mounted mergerfs
tree through its VFS backend, so media apps can keep using one NFSv4 `/media`
tree without `nfsvers=3,nolock`.

## Layout

```text
TrueNAS
├── mergerfs-media
│   ├── /mnt/core/media-rw        # fuse.mergerfs mount for apps/Kubernetes
│   └── /mnt/core/media-nc        # fuse.mergerfs mount for direct client access
└── nfs-ganesha
    ├── /media-rw                 # NFSv4 pseudo export for apps/Kubernetes
    └── /media-nc                 # NFSv4 pseudo export for direct client access
```

Ganesha uses the standard NFS port on a dedicated TrueNAS IP alias:
`10.0.10.11:2049`. The built-in TrueNAS NFS service stays on
`10.0.10.10:2049` for normal ZFS exports.

## TrueNAS Setup

Add a secondary IP alias to the TrueNAS interface:

```text
10.0.10.11/24
```

Do this from the TrueNAS UI under Network -> Interfaces, then test and apply the
network change carefully.

In the TrueNAS NFS service settings, set "Bind IP Addresses" to only the main
NAS IP:

```text
10.0.10.10
```

If the built-in NFS service is left bound to all addresses, it can take
`10.0.10.11:2049` before Ganesha starts.

Create a config directory on the `core` pool:

```bash
mkdir -p /mnt/core/nfs-ganesha
```

Copy `ganesha.conf` to:

```text
/mnt/core/nfs-ganesha/ganesha.conf
```

The compose file mounts this config inside the container as
`/run/ganesha.conf`, not `/etc/ganesha/ganesha.conf`. This avoids a Debian
`dpkg` conffile prompt while `nfs-ganesha` is installed at container startup.

`Allow_Set_Io_Flusher_Fail = true` is set in `NFS_CORE_PARAM` because containers
can fail `PR_SET_IO_FLUSHER` with `EPERM`. Ganesha supports allowing that
specific failure for unprivileged/containerized environments.

Shell variables inside the compose entrypoint must use `$$VAR`, not `$VAR`,
because Docker Compose interpolates `$VAR` before the script reaches the
container.

Install `compose.yaml` as a TrueNAS Custom App via "Install via YAML" after the
`mergerfs-media` app is deployed.

The app waits until `/mnt/core/media-rw` and `/mnt/core/media-nc` are live
`fuse.mergerfs` mounts and their `MERGERFS_NOT_MOUNTED` sentinels are hidden
before starting Ganesha.

## Kubernetes Mount

Use the Ganesha IP alias and pseudo path:

```yaml
volumeAttributes:
  server: 10.0.10.11
  share: /media-rw
  mountOptions: nfsvers=4.2
```

For qBittorrent-2, keep the restricted mount:

```yaml
globalMounts:
  - path: /media/share/qb2
    subPath: share/qb2
```

Radarr, Sonarr, Maintainerr, and Qui should mount the full `/media` tree when
they need to hardlink, move, or delete files across request library paths.

## Validation

From a Linux client with NFS tools installed:

```bash
sudo mkdir -p /tmp/ganesha-media
sudo mount -vvv -t nfs -o nfsvers=4.2 10.0.10.11:/media-rw /tmp/ganesha-media
findmnt -T /tmp/ganesha-media
sudo umount /tmp/ganesha-media
```

From Kubernetes, a successful event should show:

```text
Mounting arguments: -t nfs -o nfsvers=4.2 10.0.10.11:/media-rw ...
```

From macOS, mount the non-create media view through the Ganesha pseudo path:

```bash
sudo mkdir -p /Volumes/media-nc
sudo mount -t nfs -o vers=4,tcp,port=2049 10.0.10.11:/media-nc /Volumes/media-nc
mount | grep media-nc
sudo umount /Volumes/media-nc
```

The `/media-nc` export currently allows `10.0.40.215`. Update the `CLIENT`
block in `ganesha.conf` if the Mac IP changes.

## Troubleshooting

If the app starts and stops immediately with no visible TrueNAS UI logs, inspect
the container directly on TrueNAS:

```bash
docker ps -a --filter name=nfs-ganesha-media-rw
docker inspect nfs-ganesha-media-rw --format 'status={{.State.Status}} exit={{.State.ExitCode}} error={{.State.Error}} started={{.State.StartedAt}} finished={{.State.FinishedAt}}'
docker logs --tail 200 nfs-ganesha-media-rw
```

Validate the Debian runtime install before redeploying the app:

```bash
docker run --rm --entrypoint /bin/sh docker.io/library/debian:trixie-slim -lc 'set -eux; echo "deb http://deb.debian.org/debian trixie-backports main" > /etc/apt/sources.list.d/trixie-backports.list; apt-get update; apt-get install -y --no-install-recommends -t trixie-backports nfs-ganesha nfs-ganesha-vfs; command -v ganesha.nfsd; ganesha.nfsd -v || true'
```

If this fails, the host cannot reliably build the runtime container and this
should move directly to a self-built `nfs-ganesha-vfs` image.

## Image Note

Do not use random Docker Hub `nfs-ganesha` images for production. This compose
uses `docker.io/library/debian:trixie-slim` and installs Debian-packaged
`nfs-ganesha` plus `nfs-ganesha-vfs` at container start.

This is a clean validation path because the base image is official Debian and
the Ganesha packages come from Debian `trixie-backports`, but it is still not
ideal production behavior: every fresh app deployment needs package repository
access. Replace it with a digest-pinned, self-built `nfs-ganesha-vfs` image once
the export behavior is validated.

The target runtime command is:

```text
ganesha.nfsd -F -L STDOUT -N NIV_EVENT -f /run/ganesha.conf
```

Any replacement image must provide `/bin/sh`, `ganesha.nfsd`, and the VFS FSAL.
