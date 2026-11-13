#!/usr/bin/env bash
# Install Agent Harness for Claude Code, Codex and other Agent Skills readers.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
exec python3 -I "$here/scripts/install.py" "$@"
