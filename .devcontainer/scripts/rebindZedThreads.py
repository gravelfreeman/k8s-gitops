#!/usr/bin/env python3
# Watches for this devcontainer to be recreated, then rebinds Zed's saved thread
# metadata to its new Docker ID after Zed exits. It backs up the Zed database
# first; the source conversation data itself is not modified.
# Workaround for https://github.com/zed-industries/zed/issues/56576
import argparse
import fcntl
import json
import os
import shutil
import sqlite3
import subprocess
import time
from datetime import datetime, timezone
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument("workspace", type=Path)
parser.add_argument("--session-db", default="")
parser.add_argument("--session-query", default="")
parser.add_argument("agent_ids", nargs="+")
args = parser.parse_args()

host = args.workspace.resolve()
config = json.loads((host / ".devcontainer/devcontainer.json").read_text())
name = config["name"]
user = config.get("remoteUser", config.get("containerUser", "zed"))
workspace = config.get("workspaceFolder") or f"/workspaces/{host.name}"
agents = list(dict.fromkeys(
    agent.strip()
    for agent in args.agent_ids
    if agent.strip()
))
if not agents:
    raise SystemExit("Pass at least one Zed agent ID after the workspace path")
zed_db = Path.home() / ".local/share/zed/db/0-stable/db.sqlite"
session_db = Path(args.session_db).expanduser() if args.session_db else None
session_query = args.session_query.strip()
cache = Path.home() / ".cache/k8s-gitops"
lock_path = cache / "zed-rebind.lock"
poll = 3


def log(message):
    now = datetime.now(timezone.utc).astimezone().isoformat(timespec="seconds")
    print(f"[{now}] {message}", flush=True)


def notify(title, message):
    command = shutil.which("notify-send")
    if command:
        subprocess.run([command, title, message], check=False, capture_output=True)


def running_ids():
    result = subprocess.run(
        ["docker", "ps", "-q", "--filter", f"label=devcontainer.local_folder={host}"],
        check=True, capture_output=True, text=True,
    )
    return {line[:12] for line in result.stdout.splitlines() if line}


def saved_ids():
    if not zed_db.exists():
        return set()
    agent_filter = ",".join("?" for _ in agents)
    with sqlite3.connect(f"file:{zed_db}?mode=ro", uri=True) as db:
        try:
            return {
                row[0][:12] for row in db.execute(
                    f"""select distinct json_extract(remote_connection, '$.Docker.container_id')
                       from sidebar_threads where agent_id in ({agent_filter}) and folder_paths=?
                       and json_extract(remote_connection, '$.Docker.name')=?
                       and json_extract(remote_connection, '$.Docker.remote_user')=?""",
                    (*agents, workspace, name, user),
                ) if row[0]
            }
        except sqlite3.Error:
            return set()


def zed_running():
    for cmdline in Path("/proc").glob("[0-9]*/cmdline"):
        try:
            args = cmdline.read_bytes().replace(b"\0", b" ").decode(errors="replace")
            exe = Path(f"/proc/{cmdline.parent.name}/exe").resolve().name
        except OSError:
            continue
        if exe in {"zed", "zed-editor"} and "zed-cli://" not in args:
            return True
    return False


def backup():
    directory = Path.home() / ".cache/zed"
    directory.mkdir(mode=0o700, parents=True, exist_ok=True)
    path = directory / (
        "db.sqlite.k8s-gitops-before-rebind-"
        + datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S")
        + f"-{os.getpid()}.bak"
    )
    with sqlite3.connect(zed_db) as source, sqlite3.connect(path) as target:
        source.backup(target)
    os.chmod(path, 0o600)
    with sqlite3.connect(f"file:{path}?mode=ro", uri=True) as check:
        if check.execute("pragma integrity_check").fetchone()[0] != "ok":
            raise RuntimeError("Zed database backup failed integrity check")
    return path


def rebind(container_id):
    metadata = None
    agent_filter = ",".join("?" for _ in agents)
    db = sqlite3.connect(zed_db)
    try:
        db.row_factory = sqlite3.Row
        db.execute("begin immediate")
        row = db.execute(
            f"""select remote_connection from sidebar_threads
               where agent_id in ({agent_filter}) and folder_paths=?
                 and json_extract(remote_connection, '$.Docker.name')=?
                 and json_extract(remote_connection, '$.Docker.remote_user')=? limit 1""",
            (*agents, workspace, name, user),
        ).fetchone()
        if row:
            metadata = json.loads(row["remote_connection"])
            metadata["Docker"]["container_id"] = container_id
        else:
            metadata = {"Docker": {"name": name, "container_id": container_id,
                                   "remote_user": user, "upload_binary_over_docker_exec": False,
                                   "use_podman": False, "remote_env": {}}}

        threads = db.execute(
            f"""update sidebar_threads
               set remote_connection=json_set(remote_connection, '$.Docker.container_id', ?)
               where agent_id in ({agent_filter}) and folder_paths=?
                 and json_extract(remote_connection, '$.Docker.name')=?
                 and json_extract(remote_connection, '$.Docker.remote_user')=?
                 and json_extract(remote_connection, '$.Docker.container_id')<>?""",
            (container_id, *agents, workspace, name, user, container_id),
        ).rowcount

        sessions = set()
        if session_db and session_query and session_db.is_file():
            try:
                with sqlite3.connect(f"{session_db.as_uri()}?mode=ro", uri=True) as op:
                    sessions = {row[0] for row in op.execute(session_query, (workspace,))}
            except sqlite3.Error:
                pass

        placeholders = 0
        for session in sessions:
            placeholders += db.execute(
                f"""update sidebar_threads set remote_connection=? where folder_paths=?
                   and agent_id in ({agent_filter}) and session_id=? and remote_connection is null""",
                (json.dumps(metadata, separators=(",", ":")), workspace, *agents, session),
            ).rowcount

        connections = db.execute(
            "update remote_connections set container_id=? where name=? and user=? and container_id<>?",
            (container_id, name, user, container_id),
        ).rowcount
        db.commit()
        return threads, placeholders, connections
    except Exception:
        db.rollback()
        raise
    finally:
        db.close()


def main():
    cache.mkdir(mode=0o700, parents=True, exist_ok=True)
    with lock_path.open("w") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            log("Watcher already running")
            return

        baseline = running_ids()
        log(f"Watching {name} for container recreation (agents: {', '.join(agents)})")
        while True:
            running, known = running_ids(), saved_ids()
            replacement = next((cid for cid in running if known and any(old != cid for old in known)), None)
            replacement = replacement or next(iter(running - baseline), None)
            if not replacement:
                time.sleep(poll)
                continue

            log(f"Detected container {replacement}")
            if zed_running():
                notify("Devcontainer recreated", "Quit Zed completely to rebind its saved threads.")
            while zed_running():
                time.sleep(poll)
            if replacement not in running_ids():
                baseline = running_ids()
                continue

            try:
                path = backup() if zed_db.exists() else None
                counts = rebind(replacement) if path else (0, 0, 0)
                log(f"Rebound {counts[0]} threads, {counts[1]} imported sessions, "
                    f"{counts[2]} connections; backup: {path}")
                notify("Zed threads rebound", "Reopen Zed to continue saved threads.")
            except Exception as error:
                log(f"Patch failed; retrying: {type(error).__name__}: {error}")
                time.sleep(poll)
                continue
            baseline = running_ids()
            log("Rebind complete; watching for the next recreation")


if __name__ == "__main__":
    main()
