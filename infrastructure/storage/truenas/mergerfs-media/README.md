# TrueNAS mergerfs Media Mounts

This directory stores the TrueNAS `mergerfs` Custom App configuration for the
`media` dataset.

## Overview

The media library is split between a primary ZFS pool and several spare
single-disk request pools:

- `eden` stores the personal/local media library.
- `mfs-1`, `mfs-2`, and `mfs-3` store lower-importance request media.
- Radarr, Sonarr, qBittorrent, and Maintainerr still need one consistent
  `/media` tree for imports, replacements, recycle-bin handling, and disk-space
  cleanup rules.

mergerfs presents all branches as one logical tree while the NAS keeps the data
physically separated. This solves the main friction points:

- Radarr/Sonarr can keep using one root path instead of multiple datasets.
- Replaced or deleted media can go to branch-local `.bin` directories instead
  of forcing copy/delete behavior across unrelated datasets.
- Request media stays isolated from the personal library under `seerr` paths.
- Maintainerr can target request cleanup by checking request-root free space.
- Qui cross-seed can create hardlink trees under the matching qBittorrent
  instance instead of using one global cross-seed directory.
- Spare mixed-size disks can be used at full capacity for replaceable data.

The request disks are capacity-first, not resilient. If request media must
survive disk failure without redownloading, use RAIDZ or mirrors instead. In
this setup, a failed `mfs-*` disk only loses files from that disk; torrents can
error and be restarted, while NZB-sourced media is recovered best-effort through
Radarr/Sonarr rescan and missing search.

## Storage Map

### Physical branches:

Personal media library dataset file structure:

```text
/mnt/eden/media
├── .bin              # unified path for arrs bins
│   ├── radarr
│   └── sonarr
├── library
│   ├── movies        # each subfolders represents a Plex library
│   │   ├── anime
│   │   ├── comedy
│   │   ├── documentaries
│   │   ├── kids
│   │   ├── original
│   │   ├── music
│   │   └── quebec
│   └── tv.shows      # each subfolders represents a Plex library
│       ├── anime
│       ├── comedy
│       ├── documentaries
│       ├── kids
│       ├── original
│       ├── music
│       └── quebec
├── share             # everything that's shared lives here
│   └── qb1           # qbit instance for personal media
│       ├── .bin
│       ├── .temp
│       ├── .torrent
│       ├── cross-seed # Qui hardlink base for qb1
│       │   ├── tracker1
│       │   ├── tracker2
│       │   ├── tracker3
│       │   └── ...
│       ├── anime     # each subfolders below represents qbit categories
│       ├── movies
│       ├── prowlarr
│       ├── radarr
│       ├── sonarr
│       ├── tv.shows
│       └── upload
└── temp
    └── downloads     # downloads are hardlinked here for manual import
        ├── anime
        ├── movies
        ├── music
        ├── prowlarr
        └── tv.shows
```

Requests media library dataset file structure:

```
/mnt/mfs-1/media
/mnt/mfs-2/media
/mnt/mfs-3/media
├── .bin              # unified path for arrs bins
│   ├── radarr
│   └── sonarr
├── library
│   ├── movies        # each subfolders represents a Plex library
│   │   └── seerr
│   └── tv.shows      # each subfolders represents a Plex library
│       └── seerr
├── share
│   └── qb2           # qbit instance for requested media
│       ├── .bin
│       ├── .temp
│       ├── .torrent
│       ├── cross-seed # Qui hardlink base for qb2
│       │   ├── tracker1
│       │   ├── tracker2
│       │   ├── tracker3
│       │   └── ...
│       ├── radarr
│       └── sonarr
└── temp
    └── downloads
        └── seerr     # temp download directory for nzbs
```

Merged view:

```text
/mnt/core/media-rw
/mnt/core/media-nc
├── .bin
│   ├── radarr
│   └── sonarr
├── library
│   ├── movies
│   │   ├── anime
│   │   ├── comedy
│   │   ├── documentaries
│   │   ├── kids
│   │   ├── original
│   │   ├── music
│   │   ├── quebec
│   │   └── seerr
│   └── tv.shows
│       ├── anime
│       ├── cartoons
│       ├── comedy
│       ├── documentaries
│       ├── kids
│       ├── original
│       ├── music
│       ├── quebec
│       └── seerr
├── share
│   ├── qb1
│   │   ├── .bin
│   │   ├── .temp
│   │   ├── .torrent
│   │   ├── cross-seed
│   │   │   ├── tracker1
│   │   │   ├── tracker2
│   │   │   ├── tracker3
│   │   │   └── ...
│   │   ├── anime
│   │   ├── movies
│   │   ├── prowlarr
│   │   ├── radarr
│   │   ├── sonarr
│   │   ├── tv.shows
│   │   └── upload
│   └── qb2
│       ├── .bin
│       ├── .temp
│       ├── .torrent
│       ├── cross-seed
│       │   ├── tracker1
│       │   ├── tracker2
│       │   ├── tracker3
│       │   └── ...
│       ├── radarr
│       └── sonarr
└── temp
    └── downloads
        ├── anime
        ├── comedy
        ├── movies
        ├── music
        ├── prowlarr
        ├── radarr
        ├── seerr
        ├── sonarr
        └── tv.shows
```

## Mounts and Policies

`compose.yaml` creates two mergerfs mounts from the same branches:

| Service | Mountpoint | Use | Branch behavior |
| --- | --- | --- | --- |
| `mergerfs-all-rw` | `/mnt/core/media-rw` | NFS path for media apps that need one `/media` tree | `eden`, `mfs-1`, `mfs-2`, and `mfs-3` can create/write |
| `mergerfs-mfs-nc` | `/mnt/core/media-nc` | SMB/admin view | `eden` can create/write; `mfs-*` are `NC` (`No Create`) |

`NC` prevents new files from being created on the `mfs-*` branches through the
admin mount. Existing files on those branches can still be read, changed,
renamed, or deleted, subject to filesystem permissions.

Both mounts use:

- `category.search=ff` - find existing files by first-found branch order.
- `category.action=epall` - apply actions to all branches where the path exists.
- `ignorepponrename=true` - keep rename/link operations on the source branch
  when path-preserving create policies would otherwise cause cross-device
  behavior.
- `statfs=full` - report space based on the branches relevant to the path.
- `export-support=true` - support NFS export behavior.

The app mount uses `category.create=epmfs`, so new files go to an existing path
on the branch with the most free space. The admin mount uses
`category.create=epff` with `mfs-* = NC`, so normal SMB/admin creation prefers
`eden`.

The request branch thresholds target roughly 20% free space:

| Branch | Observed size | Threshold |
| --- | ---: | ---: |
| `mfs-1` | `7.2T` | `1500G` |
| `mfs-2` | `5.4T` | `1100G` |
| `mfs-3` | `5.4T` | `1100G` |

These thresholds stop mergerfs from choosing a branch for new file creation once
it has less free space than the configured value.

Maintainerr can clean request media by remaining disk space because the `seerr`
root folders live on `mfs-*` branches inside the merged tree. With
`statfs=full`, paths such as `/media/library/movies/seerr` and
`/media/library/tv.shows/seerr` should report request-storage capacity instead
of the full personal `eden` library.

Qui cross-seed should use hardlink mode per qBittorrent instance:

- `qb1` hardlink base: `/media/share/qb1/cross-seed`
- `qb2` hardlink base: `/media/share/qb2/cross-seed`
- directory preset: `by-tracker`
- fallback to regular mode: disabled

All media apps, qBittorrent instances, and Qui should see the same
`/media` mount from `/mnt/core/media-rw`. Mounting subdirectories separately
can make hardlinks look like cross-device operations.

## TrueNAS Setup

The `1G` quota protects the `core` pool from accidental writes to the raw
mountpoint if mergerfs is not mounted.

Install `compose.yaml` as a TrueNAS Custom App via "Install via YAML".

Suggested datasets:

- `/mnt/eden/media`: personal media library
- `/mnt/mfs-1/media`: request media library
- `/mnt/mfs-2/media`: request media library
- `/mnt/mfs-3/media`: request media library
- `/mnt/core/media-rw`: nfs share for applications
- `/mnt/core/media-nc`: samba share for user access

## Verification

Verify path-specific space reporting for Maintainerr:

```bash
df -h /mnt/core/media-rw/library/movies
df -h /mnt/core/media-rw/library/movies/seerr
```

Run a request hardlink and recycle-bin test from the TrueNAS shell. These
commands are written for `zsh` and avoid broad `find` scans across the media
library.

```shell
RW=/mnt/core/media-rw
NC=/mnt/core/media-nc
BRANCHES=(/mnt/eden/media /mnt/mfs-1/media /mnt/mfs-2/media /mnt/mfs-3/media)
T="_mergerfs-test-$(date +%s)"
SIZE_MB=1024

findmnt -T "$RW" -o TARGET,FSTYPE,SOURCE,PROPAGATION
findmnt -T "$NC" -o TARGET,FSTYPE,SOURCE,PROPAGATION
test ! -e "$RW/MERGERFS_NOT_MOUNTED" && echo "RW sentinel hidden: OK"
test ! -e "$NC/MERGERFS_NOT_MOUNTED" && echo "NC sentinel hidden: OK"

mkdir -p "$RW/share/qb2/.temp/$T"
dd if=/dev/zero of="$RW/share/qb2/.temp/$T/bigfile.bin" bs=1M count="$SIZE_MB" status=progress

SRC_PHYS=
SRC_BRANCH=
for b in "${BRANCHES[@]}"; do
  p="$b/share/qb2/.temp/$T/bigfile.bin"
  if [ -e "$p" ]; then
    SRC_PHYS="$p"
    SRC_BRANCH="$b"
    break
  fi
done

echo "SRC_PHYS=$SRC_PHYS"
echo "SRC_BRANCH=$SRC_BRANCH"
test -n "$SRC_BRANCH" || { echo "source branch not found"; return 1; }

mkdir -p "$SRC_BRANCH/library/movies/seerr/$T"
ln "$RW/share/qb2/.temp/$T/bigfile.bin" "$RW/library/movies/seerr/$T/bigfile.bin"

stat -c '%d:%i links=%h size=%s %n' \
  "$SRC_BRANCH/share/qb2/.temp/$T/bigfile.bin" \
  "$SRC_BRANCH/library/movies/seerr/$T/bigfile.bin"
```

The two `stat` lines should show the same device, same inode, and `links=2`.

Then test the Radarr recycle-bin move:

```shell
mv "$RW/library/movies/seerr/$T/bigfile.bin" "$RW/.bin/radarr/$T.bigfile.bin"

BIN_PHYS=
for b in "${BRANCHES[@]}"; do
  p="$b/.bin/radarr/$T.bigfile.bin"
  if [ -e "$p" ]; then
    BIN_PHYS="$p"
    break
  fi
done

echo "BIN_PHYS=$BIN_PHYS"

stat -c '%d:%i links=%h size=%s %n' \
  "$SRC_BRANCH/share/qb2/.temp/$T/bigfile.bin" \
  "$SRC_BRANCH/.bin/radarr/$T.bigfile.bin"
```

`BIN_PHYS` should be on the same branch as `SRC_BRANCH`, and the `stat` output
should still show `links=2`.

Cleanup only the exact test paths:

```shell
rm -rf "$RW/share/qb2/.temp/$T"
rm -rf "$RW/library/movies/seerr/$T"
rm -f "$RW/.bin/radarr/$T.bigfile.bin"

for b in "${BRANCHES[@]}"; do
  rm -rf "$b/share/qb2/.temp/$T"
  rm -rf "$b/library/movies/seerr/$T"
  rm -f "$b/.bin/radarr/$T.bigfile.bin"
done

for b in "${BRANCHES[@]}"; do
  for p in \
    "$b/share/qb2/.temp/$T" \
    "$b/library/movies/seerr/$T" \
    "$b/.bin/radarr/$T.bigfile.bin"; do
    [ -e "$p" ] && echo "leftover: $p"
  done
done
```
