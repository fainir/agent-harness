#!/usr/bin/env bash
# Local CI (no GitHub Actions): the same step as .github/workflows/test.yml.
set -euo pipefail
cd "$(dirname "$0")/.."
bash tests/test.sh
