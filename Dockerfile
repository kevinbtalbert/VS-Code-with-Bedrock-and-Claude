# Cloudera ML runtime: VS Code (code-server) + Claude Code → LiteLLM → AWS Bedrock
#
# Replaces CAII (Cloudera AI Inference) routing with Amazon Bedrock via a local LiteLLM
# proxy. Claude Code has native Bedrock support (CLAUDE_CODE_USE_BEDROCK=1); this image
# keeps LiteLLM for a single BEDROCK_MODEL env var — see README "Alternative: native Bedrock".
FROM --platform=linux/amd64 docker.repository.cloudera.com/cloudera/cdsw/ml-runtime-pbj-workbench-python3.13-standard:2026.08.1-b5

USER root

# ── System dependencies ─────────────────────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
        vim nano curl wget less tree jq unzip zip git ca-certificates \
        ripgrep fd-find bat netcat-openbsd dnsutils iputils-ping \
        pciutils htop procps lsof \
        ssh-client rsync socat \
    && rm -rf /var/lib/apt/lists/* \
    && ln -sf /usr/bin/fdfind /usr/local/bin/fd \
    && ln -sf /usr/bin/batcat /usr/local/bin/bat

# ── code-server (browser VS Code) ───────────────────────────────────────────
# Pattern from https://github.com/cloudera/community-ml-runtimes/tree/main/vscode
ARG CODE_SERVER_VERSION=4.139.1
RUN curl -fsSL https://code-server.dev/install.sh | sh -s -- --version "${CODE_SERVER_VERSION}"

COPY scripts/vscode-launch.sh /usr/local/bin/vscode

RUN chmod +x /usr/local/bin/vscode && \
    ln -sf /usr/local/bin/vscode /usr/local/bin/ml-runtime-editor && \
    mkdir -p /home/cdsw/.local/share/code-server/User && \
    chown -R cdsw:cdsw /home/cdsw/.local

ENV CODE_SERVER_BIND="127.0.0.1:8090"

# ── Node.js 20 (required by Claude Code) ─────────────────────────────────────
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs && \
    rm -rf /var/lib/apt/lists/*

# ── Claude Code CLI ──────────────────────────────────────────────────────────
RUN npm install -g @anthropic-ai/claude-code \
    && command -v claude >/dev/null

# ── LiteLLM proxy (Anthropic API → AWS Bedrock) ────────────────────────────────
COPY requirements-litellm.txt /opt/bedrock-claude/requirements-litellm.txt
COPY scripts/verify-litellm-install.sh /opt/bedrock-claude/verify-litellm-install.sh
RUN chmod +x /opt/bedrock-claude/verify-litellm-install.sh && \
    python3 -m venv /opt/bedrock-claude/venv && \
    /opt/bedrock-claude/venv/bin/pip install --no-cache-dir --upgrade pip wheel packaging && \
    /opt/bedrock-claude/venv/bin/pip install --no-cache-dir -r /opt/bedrock-claude/requirements-litellm.txt && \
    SKIP_LITELLM_SMOKE=1 /opt/bedrock-claude/verify-litellm-install.sh /opt/bedrock-claude/venv

# ── Bedrock runtime helpers (VS Code integrated terminal + workbench shells) ─
RUN mkdir -p /home/cdsw/.claude/bedrock /opt/bedrock-claude/lib && \
    chown -R cdsw:cdsw /home/cdsw/.claude

COPY scripts/lib/bedrock-common.sh /opt/bedrock-claude/lib/bedrock-common.sh
COPY scripts/bedrock-runtime-startup.sh /etc/profile.d/claude-bedrock.sh
RUN chmod +x /etc/profile.d/claude-bedrock.sh /opt/bedrock-claude/lib/bedrock-common.sh && \
    echo '[ -f /etc/profile.d/claude-bedrock.sh ] && source /etc/profile.d/claude-bedrock.sh' \
        >> /etc/bash.bashrc

ENV BEDROCK_HOME="/home/cdsw/.claude/bedrock" \
    BEDROCK_VENV_BIN="/opt/bedrock-claude/venv/bin" \
    BEDROCK_MODEL="" \
    AWS_ACCESS_KEY_ID="" \
    AWS_SECRET_ACCESS_KEY="" \
    AWS_REGION="" \
    BEDROCK_LITELLM_PORT="4000" \
    BEDROCK_MAX_OUTPUT_TOKENS="8192" \
    BEDROCK_MAX_INPUT_TOKENS="192000"

ENV ML_RUNTIME_EDITION="VS Code + Claude Code with AWS Bedrock" \
    ML_RUNTIME_EDITOR="VsCode" \
    ML_RUNTIME_KERNEL="Python 3.13" \
    ML_RUNTIME_SHORT_VERSION="1.0" \
    ML_RUNTIME_MAINTENANCE_VERSION="0" \
    ML_RUNTIME_DESCRIPTION="Browser VS Code and Claude Code agents via AWS Bedrock (LiteLLM) on PBJ Python 3.13"

ENV ML_RUNTIME_FULL_VERSION="${ML_RUNTIME_SHORT_VERSION}.${ML_RUNTIME_MAINTENANCE_VERSION}"

LABEL com.cloudera.ml.runtime.edition=$ML_RUNTIME_EDITION \
      com.cloudera.ml.runtime.full-version=$ML_RUNTIME_FULL_VERSION \
      com.cloudera.ml.runtime.short-version=$ML_RUNTIME_SHORT_VERSION \
      com.cloudera.ml.runtime.maintenance-version=$ML_RUNTIME_MAINTENANCE_VERSION \
      com.cloudera.ml.runtime.description=$ML_RUNTIME_DESCRIPTION \
      com.cloudera.ml.runtime.editor=$ML_RUNTIME_EDITOR

WORKDIR /home/cdsw
USER cdsw
