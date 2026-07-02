FROM mcr.microsoft.com/devcontainers/base:ubuntu@sha256:36c0ae9fe6bfa914cf7eb05b08b09a3a31961dc76eed6fbb75179382c817582c

ARG USERNAME=zed

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

COPY templates/xclip /usr/local/bin/xclip

RUN chmod 0755 /usr/local/bin/xclip

RUN install -d -m 0755 /usr/share/postgresql-common/pgdg \
  && curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc \
    -o /usr/share/postgresql-common/pgdg/apt.postgresql.org.asc \
  && printf 'deb [signed-by=/usr/share/postgresql-common/pgdg/apt.postgresql.org.asc] https://apt.postgresql.org/pub/repos/apt noble-pgdg main\n' \
    > /etc/apt/sources.list.d/pgdg.list \
  && apt-get update \
  && apt-get install -y --no-install-recommends barman-cli-cloud \
  && rm -rf /var/lib/apt/lists/*

RUN arch="$(uname -m)" \
  && case "$arch" in \
    aarch64|arm64) oh_my_posh_arch="arm64" ;; \
    x86_64|amd64) oh_my_posh_arch="amd64" ;; \
    *) echo "Unsupported architecture: $arch" >&2; exit 1 ;; \
  esac \
  && curl -fsSL \
    "https://github.com/JanDeDobbeleer/oh-my-posh/releases/latest/download/posh-linux-${oh_my_posh_arch}" \
    -o /usr/local/bin/oh-my-posh \
  && chmod 0755 /usr/local/bin/oh-my-posh

RUN export MINIJINJA_CLI_INSTALL_DIR=/usr/local/bin \
  && curl -sSfL "https://github.com/mitsuhiko/minijinja/releases/latest/download/minijinja-cli-installer.sh" | sh \
  && rm -f /root/.local/env /root/.local/env.fish

RUN usermod \
    --login "${USERNAME}" \
    --move-home \
    --home "/home/${USERNAME}" \
    --shell /bin/zsh \
    vscode \
  && groupmod --new-name "${USERNAME}" vscode \
  && rm -f /etc/sudoers.d/vscode /etc/sudoers.d/zed \
  && passwd -l root
