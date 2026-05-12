FROM alpine:3.23

# ── System packages ──────────────────────────────────────────────
RUN apk add --no-cache \
    git \
    make \
    bash \
    ca-certificates \
    curl \
    jq \
    ripgrep \
    fd \
    gnupg \
    openssh-client \
    poppler-utils \
    procps \
    sudo \
    g++ \
    build-base \
    file \
    dash \
    elvish \
    fish \
    loksh \
    mksh \
    nushell \
    oksh \
    tcsh \
    yash \
    zsh \
    unzip \
    github-cli \
    shadow \
    nodejs \
    npm \
    docker-cli \
    docker-cli-compose \
    gosu \
    python3 \
    py3-pip \
    socat \
    aws-cli \
    docker-cli-buildx

# ── Extra user-specified packages (no Dockerfile edit needed) ────────
ARG EXTRA_PACKAGES=""
RUN if [ -n "$EXTRA_PACKAGES" ]; then apk add --no-cache $EXTRA_PACKAGES; fi

# ── uv / uvx (Python package runner) ────────────────────────────────
RUN curl -LsSf https://astral.sh/uv/install.sh | env UV_INSTALL_DIR=/usr/local/bin sh

# ── Go + gopls ────────────────────────────────────────────────────
ARG GO_VERSION=go1.26.0
COPY scripts/go-install.sh /tmp/go-install.sh
RUN chmod +x /tmp/go-install.sh && /tmp/go-install.sh "${GO_VERSION}" \
    && rm /tmp/go-install.sh \
    && export PATH="/usr/local/go/bin:${PATH}" \
    && go install golang.org/x/tools/gopls@latest \
    && cp /root/go/bin/gopls /usr/local/bin/gopls \
    && rm -rf /root/go /root/.cache/go-build
ENV PATH="/usr/local/go/bin:${PATH}"

# ── Extra user-specified Go packages (no Dockerfile edit needed) ──
ARG EXTRA_GO_PACKAGES=""
RUN if [ -n "$EXTRA_GO_PACKAGES" ]; then \
      set -e; \
      for pkg in $EXTRA_GO_PACKAGES; do \
        env GOBIN=/usr/local/bin go install "$pkg"; \
      done; \
      rm -rf /root/go /root/.cache/go-build; \
    fi

# ── Terraform + Terragrunt ────────────────────────────────────────
RUN ARCH=$(uname -m) \
    && case "$ARCH" in x86_64) ARCH=amd64 ;; aarch64) ARCH=arm64 ;; esac \
    && curl -fsSL "https://releases.hashicorp.com/terraform/1.11.2/terraform_1.11.2_linux_${ARCH}.zip" -o /tmp/terraform.zip \
    && unzip -o /tmp/terraform.zip -d /usr/local/bin/ \
    && rm /tmp/terraform.zip \
    && curl -fsSL "https://github.com/gruntwork-io/terragrunt/releases/download/v0.77.10/terragrunt_linux_${ARCH}" -o /usr/local/bin/terragrunt \
    && chmod +x /usr/local/bin/terragrunt

# ── Host-mirrored user ──────────────────────────────────────────
ARG HOST_UID=1000
ARG HOST_USER=user
ARG HOST_HOME=/home/${HOST_USER}
ARG CONTAINER_SHELL=/bin/bash
RUN mkdir -p "$(dirname ${HOST_HOME})" \
    && adduser -D -u ${HOST_UID} \
    -h ${HOST_HOME} \
    -s ${CONTAINER_SHELL} \
    ${HOST_USER} \
    && echo "${HOST_USER} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# ── Codex CLI (npm package) ──────────────────────────────────────
ARG CODEX_VERSION=""
ENV NPM_CONFIG_UPDATE_NOTIFIER=false
RUN if [ -n "$CODEX_VERSION" ]; then \
      npm install -g "@openai/codex@${CODEX_VERSION}"; \
    else \
      npm install -g @openai/codex; \
    fi
ENV PATH="/usr/local/custom-bin:${PATH}"

# ── Useful language tooling (LSP servers) ──────────────────────────
RUN npm install -g typescript typescript-language-server pyright

# ── Extra user-specified npm packages (no Dockerfile edit needed) ──
ARG EXTRA_NPM_PACKAGES=""
RUN if [ -n "$EXTRA_NPM_PACKAGES" ]; then npm install -g $EXTRA_NPM_PACKAGES; fi

ENV NODE_PATH=/usr/local/lib/node_modules

# ── Environment marker ────────────────────────────────────────────
RUN touch /this-is-codex-docker-env \
    && ln -sf /usr/local/bin/codex-notifier /usr/local/bin/claude-notifier

# ── Security wrappers (replace real binaries) ─────────────────────
RUN mkdir -p /usr/libexec/git-real    && mv /usr/bin/git    /usr/libexec/git-real/git \
 && mkdir -p /usr/libexec/docker-real && mv /usr/bin/docker /usr/libexec/docker-real/docker
COPY scripts/git-wrapper.sh    /usr/bin/git
COPY scripts/docker-wrapper.sh /usr/bin/docker
COPY scripts/codex-session.sh  /usr/local/bin/codex-session
COPY scripts/entrypoint.sh     /usr/local/bin/entrypoint.sh
COPY scripts/profile-path.sh   /etc/profile.d/codex-path.sh
RUN chmod +x /usr/bin/git /usr/bin/docker /usr/local/bin/codex-session /usr/local/bin/entrypoint.sh /etc/profile.d/codex-path.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["sleep", "infinity"]
