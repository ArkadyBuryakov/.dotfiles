#!/bin/bash
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Read dependencies from file, skip empty lines and comments
mapfile -t packages < <(grep -v '^\s*#' "$DOTFILES/dependencies.txt" | grep -v '^\s*$')

echo "==> Installing ${#packages[@]} packages..."
yay -S --needed --noconfirm "${packages[@]}"
