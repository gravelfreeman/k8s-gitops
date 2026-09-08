#!/bin/sh
set -eu

target_gid="${ONEPASSWORDCLIGID:-1002}"
op_path="$(command -v op)"
op_path="$(readlink -f "$op_path")"

case "$target_gid" in
    ''|*[!0-9]*)
        echo "onePasswordCliGid must be numeric: ${target_gid}" >&2
        exit 1
        ;;
esac

if getent group onepassword-cli >/dev/null 2>&1; then
    current_gid="$(getent group onepassword-cli | cut -d: -f3)"
    if [ "$current_gid" != "$target_gid" ]; then
        if getent group "$target_gid" >/dev/null 2>&1; then
            echo "GID ${target_gid} is already assigned to another group" >&2
            exit 1
        fi
        groupmod --gid "$target_gid" onepassword-cli
    fi
else
    if getent group "$target_gid" >/dev/null 2>&1; then
        echo "GID ${target_gid} is already assigned to another group" >&2
        exit 1
    fi
    groupadd --system --gid "$target_gid" onepassword-cli
fi

chgrp onepassword-cli "$op_path"
chmod g+s "$op_path"

echo "Configured ${op_path} with onepassword-cli GID ${target_gid} and setgid permissions."
