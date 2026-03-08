#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

cd "$repo_root"

echo "Regenerating bun.nix from bun.lock..."
bunx bun2nix -l bun.lock -o bun.nix
echo "Updated bun.nix"
