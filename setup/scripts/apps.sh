#!/bin/bash
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Use existing desktop_symlinks.sh with auto-overwrite
cd "$DOTFILES/applications"
bash desktop_symlinks.sh Y
