#!/usr/bin/env bash
# /etc/profile.d/claude-bedrock.sh
#
# Sourced on every interactive shell in the VS Code / Workbench runtime image
# (including the code-server integrated terminal).
#
# Configures Claude Code to reach AWS Bedrock via a local LiteLLM proxy.
#
# Authentication — pick one (see README):
#   Auto-refresh: AWS_ACCESS_KEY_ID + AWS_SECRET_ACCESS_KEY (+ AWS_SESSION_TOKEN)
#   Manual token: AWS_BEARER_TOKEN_BEDROCK from https://console.aws.amazon.com/bedrock/home#/api-keys
#
# Required:
#   BEDROCK_MODEL, AWS_REGION
#
# Commands:
#   claude-sync-config    — mint/validate token, start LiteLLM, write Claude settings
#   claude-refresh-token  — mint a fresh 12-hour bearer token (requires base AWS creds)
#   claude                — sync config then launch Claude Code
#   claude-status         — show env + proxy health
#   claude-stop-proxy     — stop background LiteLLM
#   claude-logs           — tail LiteLLM log

[[ $- != *i* ]] && return

export BEDROCK_HOME="${BEDROCK_HOME:-${HOME}/.claude/bedrock}"
export BEDROCK_VENV_BIN="${BEDROCK_VENV_BIN:-/opt/bedrock-claude/venv/bin}"
export BEDROCK_LITELLM_PORT="${BEDROCK_LITELLM_PORT:-4000}"

# shellcheck disable=SC1091
source /opt/bedrock-claude/lib/bedrock-common.sh

claude-sync-config() {
    bedrock_sync_config 1
}

claude-refresh-token() {
    if ! bedrock_has_base_creds; then
        bedrock_log "claude-refresh-token: set AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY first."
        bedrock_log "Or paste a short-term key from: https://console.aws.amazon.com/bedrock/home#/api-keys"
        return 1
    fi
    bedrock_refresh_bearer_token && bedrock_log "Bearer token minted (valid up to 12 hours). Run: claude-sync-config"
}

claude() {
    bedrock_launch_claude "$@"
}

claude-status() {
    echo ""
    echo "┌─ Claude Code + AWS Bedrock ──────────────────────────────────────────────┐"
    if bedrock_have_cmd claude; then
        echo "│  ✓ claude: $(command -v claude) ($(claude --version 2>/dev/null | head -1 || echo ''))"
    else
        echo "│  ✗ claude CLI not found"
    fi
    if bedrock_env_ready; then
        echo "│  ✓ Bedrock env set (model: ${BEDROCK_MODEL})"
        echo "│  ✓ region: $(bedrock_aws_region)"
        echo "│  ✓ auth: $(bedrock_auth_mode) (short-term token, up to 12h)"
        if bedrock_proxy_health_ok; then
            echo "│  ✓ LiteLLM proxy: http://127.0.0.1:${BEDROCK_LITELLM_PORT}"
        else
            echo "│  ○ LiteLLM proxy not running — run: claude-sync-config"
        fi
        echo "│  → Run: claude"
        echo "│  Token expired? claude-sync-config  |  Generate: console.aws.amazon.com/bedrock → API keys"
    else
        echo "│  ○ Set BEDROCK_MODEL + AWS_REGION + credentials"
        echo "│    Auto: AWS_ACCESS_KEY_ID + AWS_SECRET_ACCESS_KEY"
        echo "│    Manual: AWS_BEARER_TOKEN_BEDROCK from Bedrock console API keys"
        echo "│    then: claude-sync-config"
    fi
    echo "│  BEDROCK_HOME=${BEDROCK_HOME}"
    echo "│  Log: ${BEDROCK_HOME}/litellm.log"
    echo "└──────────────────────────────────────────────────────────────────────────┘"
    echo ""
}

claude-stop-proxy() {
    bedrock_stop_proxy
    bedrock_log "Stopped LiteLLM proxy."
}

claude-logs() {
    tail -f "${BEDROCK_HOME}/litellm.log"
}

_claude_banner() {
    claude-status
}

_claude_banner
