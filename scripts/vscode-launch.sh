#!/usr/bin/env bash
# CML editor entrypoint: start code-server for the Workbench VS Code editor.
set -Eeuo pipefail

CODE_SERVER_BIND="${CODE_SERVER_BIND:-127.0.0.1:8090}"
exec /usr/bin/code-server --auth=none --bind-addr="${CODE_SERVER_BIND}" --disable-telemetry "$@"
