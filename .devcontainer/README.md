# Dev Container

## Lifecycle Order

- Build the image from `Dockerfile`.
- Run `initializeCommand.sh` on the host during devcontainer initialization.
- Create and start the container.
- Run `onCreateCommand.sh` inside the container on first creation only.
- Run `postCreateCommand.sh` inside the container after first creation setup only.
- Reopen the project connected to the running container environment.
- On later starts, the Dev Container lifecycle can run `initializeCommand.sh` again, but `onCreateCommand.sh` and `postCreateCommand.sh` do not rerun.

## Dockerfile

Starts from the pinned `mcr.microsoft.com/devcontainers/base:ubuntu` image.

- Installs the local clipboard shim at `/usr/local/bin/xclip`.
- Adds the PostgreSQL PGDG apt repository.
- Installs `barman-cli-cloud` at image build time.
- Installs `oh-my-posh` into `/usr/local/bin`.
- Installs `minijinja-cli` into `/usr/local/bin`.
- Renames the inherited `vscode` user and group to `zed`.
- Moves the inherited home directory to `/home/zed`.
- Sets the `zed` login shell to `/bin/zsh`.
- Removes sudoers files for `vscode` and `zed`.
- Locks the `root` password.

## devcontainer.json

- Builds the image from `.devcontainer/Dockerfile`.
- Installs devcontainer features for AWS CLI, common utilities, Kubernetes tools, Cloudflared, Task, Helmfile, Talos, K9s, YQ, 1Password CLI, Flux, and Kustomize.
- Installs extra apt packages through the apt packages feature.
- Mounts the host SSH agent socket cache into `/tmp/ssh-agent.sock`.
- Mounts the host `~/.cache/k8s-gitops` directory into `/tmp/host-secrets`.
- Mounts the host Talos cache directory into `/tmp/talos`.
- Mounts host `~/.gitconfig` read-only into `/tmp/host.gitconfig`.
- Grants FUSE access with `/dev/fuse`, `SYS_ADMIN`, and unconfined AppArmor for local PVC mounts through `pv-mounter`/SSHFS.
- Sets shell, devcontainer marker, SSH agent, PATH, Minijinja, kubeconfig, and talosconfig environment variables.
- Runs container processes as the `zed` user.
- Disables remote user UID rewriting.
- Runs `initializeCommand.sh` on the host during devcontainer initialization.
- Runs `onCreateCommand.sh` inside the container when the container is first created.
- Runs `postCreateCommand.sh` inside the container after creation setup.

## initializeCommand.sh

Runs on the host, not inside the container.

- Defines the 1Password Talos config source.
- Prepares the host cache directory at `~/.cache/k8s-gitops`.
- Links the host SSH agent socket into the devcontainer cache.
- Checks for an existing devcontainer for the workspace through Docker labels.
- Skips 1Password reads when an existing devcontainer is found.
- Reads GitHub SSH public keys from 1Password into the devcontainer cache as `ssh/github-auth.pub` and `ssh/github-signing.pub`.
- Reads the `public key` field from each item.
- Skips generating the Talos config when an existing devcontainer is found.
- Reads the Talos config from 1Password when a new devcontainer needs creation.
- Base64-encodes the Talos config into the host cache for the container to consume.
- Restricts the cached Talos config file to mode `0600`.

## onCreateCommand.sh

Runs inside the container only when the container is first created.

- Creates `$HOME/.config`.
- Links the repository-managed `.zshrc` into `$HOME/.zshrc`.
- The `.zshrc` is Linux/container-only; host macOS shell paths stay out of the devcontainer config.
- The `.zshrc` configures Oh My Zsh, shell history, FZF theme, prompt, SSH helpers, task completion, key bindings, and syntax highlighting for the devcontainer.
- Links the repository-managed Zsh config directory into `$HOME/.config/zsh`.
- Creates `$HOME/.ssh` with mode `0700`.
- Creates an empty container-local `$HOME/.ssh/known_hosts`.
- Copies the cached GitHub public keys into `$HOME/.ssh/github-auth.pub` and `$HOME/.ssh/github-signing.pub` when available.
- Renders `$HOME/.ssh/config` from `.devcontainer/templates/.sshconfig` with the forwarded SSH agent socket.
- Restricts SSH agent use to `github.com` and `~/.ssh/github-auth.pub` with `IdentitiesOnly yes`.
- Configures SSH to trust new host keys into the container-local `known_hosts` file without mounting host `~/.ssh`.
- Sets `$HOME/.ssh/config`, `$HOME/.ssh/known_hosts`, and copied GitHub public keys to mode `0600`.
- Renders `$HOME/.gitconfig` from `.devcontainer/templates/.gitconfig`.
- Configures the workspace as a safe Git directory.
- Enables repository Git hooks through `.githooks`.
- Links repository-managed K9s config into `$HOME/.config/k9s`.

## postCreateCommand.sh

Runs inside the container after `onCreateCommand.sh` during first creation.

- Downloads and installs `krew` into the user home.
- Installs the `pv-mounter`, `browse-pvc`, and `df-pv` Krew plugins.
- Installs `krr` from the prebuilt Ubuntu release binary on Linux.
- Skips `krr` installation on Darwin.
- Decodes the cached Talos config from `/tmp/host-secrets/talos/config`.
- Writes the decoded Talos config to `$HOME/.talos/config`.
- Deletes the cached host Talos config after successful consumption.
- Restricts `$HOME/.talos/config` to mode `0600`.
- Selects a random Talos controller endpoint.
- Generates `$HOME/.kube/config` with `talosctl kubeconfig`.
- Restricts `$HOME/.kube/config` to mode `0600`.
- Removes the devcontainer feature-created passwordless sudoers files through an exit trap for runtime hardening.
