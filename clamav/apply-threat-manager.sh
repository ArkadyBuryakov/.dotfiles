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

sudo cp "$CLAMAV_SRC/com.clamav.threat-manager.policy" /usr/share/polkit-1/actions/

# Ensure new log files exist
for f in scan-history.log scan-state.json; do
    sudo touch "/var/log/clamav/$f"
    sudo chown clamav:clamav "/var/log/clamav/$f"
    sudo chmod 644 "/var/log/clamav/$f"
done

echo "Deployed: ${SCRIPTS[*]} + polkit policy"
