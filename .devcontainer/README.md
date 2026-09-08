# Dev Container

## Lifecycle Order

- Build the image from `Dockerfile`.
- Run `initializeCommand.sh` on the host to prepare the Talos artifact cache.
- Create and start the container.
- Run `onCreateCommand.sh` inside the container on first creation only.
- Run `postCreateCommand.sh` inside the container after first creation setup only.
- Reopen the project connected to the running container environment.
- On later starts, `initializeCommand.sh` prepares the host artifact cache, while `onCreateCommand.sh` and `postCreateCommand.sh` do not rerun.

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
- Mounts the host 1Password SSH agent directory into `/home/zed/.1password`.
- Mounts the host 1Password CLI IPC socket into `/run/user/1000/1Password-BrowserSupport.sock`.
- Mounts the host Talos artifact cache into `/tmp/talos`.
- Configures the `op` executable with the host `onepassword-cli` GID and setgid permissions for 1Password CLI desktop app integration.
- Mounts host `~/.gitconfig` read-only into `/tmp/host.gitconfig`.
- Grants FUSE access with `/dev/fuse`, `SYS_ADMIN`, and unconfined AppArmor for local PVC mounts through `pv-mounter`/SSHFS.
- Sets shell, devcontainer marker, SSH agent, PATH, Minijinja, kubeconfig, and talosconfig environment variables.
- Runs container processes as the `zed` user.
- Disables remote user UID rewriting.
- Runs `onCreateCommand.sh` inside the container when the container is first created.
- Runs `postCreateCommand.sh` inside the container after creation setup.

## initializeCommand.sh

Runs on the host before the container starts.

- Creates `~/.cache/k8s-gitops/talos` with mode `0700` for Talos artifacts such as generated ISO files.
- Does not read or cache 1Password secrets.

## onCreateCommand.sh

Runs inside the container only when the container is first created.

- Creates `$HOME/.config`.
- Links the repository-managed `.zshrc` into `$HOME/.zshrc`.
- The `.zshrc` is Linux/container-only; host macOS shell paths stay out of the devcontainer config.
- The `.zshrc` configures Oh My Zsh, shell history, FZF theme, prompt, SSH helpers, task completion, key bindings, and syntax highlighting for the devcontainer.
- Links the repository-managed Zsh config directory into `$HOME/.config/zsh`.
- Creates `$HOME/.ssh` with mode `0700`.
- Creates an empty container-local `$HOME/.ssh/known_hosts`.
- Reads the GitHub authentication public key directly from 1Password into `$HOME/.ssh/github-auth.pub`.
- Renders `$HOME/.ssh/config` from `.devcontainer/templates/.sshconfig` for GitHub host-key handling.
- Selects the GitHub authentication key from the 1Password SSH agent with `IdentityFile` and `IdentitiesOnly yes`.
- Uses the host 1Password CLI desktop app integration for interactive `op` commands and authentication prompts.
- Configures SSH to trust new host keys into the container-local `known_hosts` file without mounting host `~/.ssh`.
- Sets `$HOME/.ssh/config`, `$HOME/.ssh/known_hosts`, and the copied GitHub public key to mode `0600`.
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
- Reads the Talos config directly from 1Password into `$HOME/.talos/config`.
- Restricts `$HOME/.talos/config` to mode `0600`.
- Selects a random Talos controller endpoint.
- Generates `$HOME/.kube/config` with `talosctl kubeconfig`.
- Restricts `$HOME/.kube/config` to mode `0600`.
- Removes the devcontainer feature-created passwordless sudoers files through an exit trap for runtime hardening.
