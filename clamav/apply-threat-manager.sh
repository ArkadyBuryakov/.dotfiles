#!/bin/bash
# Re-deploy threat-manager and related scripts to /etc/clamav/.
# Use after editing dotfiles — skips full setup, just copies changed files.
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLAMAV_SRC="$DOTFILES/clamav"

SCRIPTS=(virus-event.bash scan-weekly.sh threat-manager.sh clamav-log-action.sh)

for script in "${SCRIPTS[@]}"; do
    sudo cp "$CLAMAV_SRC/$script" "/etc/clamav/$script"
    sudo chmod +x "/etc/clamav/$script"
done

echo "Deployed: ${SCRIPTS[*]}"
