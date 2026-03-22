#!/bin/bash
# Run all bats tests
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Running all tests..."
echo "===================="

if ! command -v bats >/dev/null 2>&1; then
  echo "ERROR: bats-core not installed. Install with: brew install bats-core" >&2
  exit 1
fi

# Run specific test file if provided, otherwise run all
if [[ $# -gt 0 ]]; then
  bats "$@"
else
  bats "${SCRIPT_DIR}"/test-*.bats
fi
