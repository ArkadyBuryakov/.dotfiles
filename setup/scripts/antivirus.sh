#!/bin/bash
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CLAMAV_SRC="$DOTFILES/clamav"

echo "==> Setting up ClamAV antivirus..."

# Copy config files to /etc/clamav/
sudo mkdir -p /etc/clamav
sudo cp "$CLAMAV_SRC/clamd.conf" /etc/clamav/clamd.conf
sudo cp "$CLAMAV_SRC/freshclam.conf" /etc/clamav/freshclam.conf
sudo cp "$CLAMAV_SRC/virus-event.bash" /etc/clamav/virus-event.bash
sudo cp "$CLAMAV_SRC/scan-weekly.sh" /etc/clamav/scan-weekly.sh
sudo cp "$CLAMAV_SRC/threat-manager.sh" /etc/clamav/threat-manager.sh
sudo cp "$CLAMAV_SRC/clamav-log-action.sh" /etc/clamav/clamav-log-action.sh
sudo chmod +x /etc/clamav/virus-event.bash /etc/clamav/scan-weekly.sh \
    /etc/clamav/threat-manager.sh /etc/clamav/clamav-log-action.sh
echo "==> Copied ClamAV configs and scripts to /etc/clamav/"

# Install polkit policy for threat manager
sudo cp "$CLAMAV_SRC/com.clamav.threat-manager.policy" /usr/share/polkit-1/actions/
echo "==> Installed polkit policy for threat manager"

# Install sudoers drop-in for clamav notify-send
sudo cp "$CLAMAV_SRC/sudoers-clamav" /etc/sudoers.d/clamav
sudo chmod 440 /etc/sudoers.d/clamav
echo "==> Installed sudoers drop-in for clamav"

# Create log directory and threat log
sudo mkdir -p /var/log/clamav
sudo touch /var/log/clamav/threats.log /var/log/clamav/weekly-scan.log /var/log/clamav/actions.log /var/log/clamav/last-scan-timestamp /var/log/clamav/scan-history.log /var/log/clamav/scan-state.json
sudo chown -R clamav:clamav /var/log/clamav
sudo chmod 644 /var/log/clamav/threats.log /var/log/clamav/weekly-scan.log /var/log/clamav/actions.log /var/log/clamav/last-scan-timestamp /var/log/clamav/scan-history.log /var/log/clamav/scan-state.json
echo "==> Created log files"

# Install systemd units
UNITS=(clamav-freshclam-update.service clamav-freshclam-update.timer)
for unit in "${UNITS[@]}"; do
    sudo cp "$CLAMAV_SRC/$unit" "/etc/systemd/system/$unit"
done
# Install clamonacc override (adds --fdpass for scanning user files)
sudo mkdir -p /etc/systemd/system/clamav-clamonacc.service.d
sudo cp "$CLAMAV_SRC/clamav-clamonacc-override.conf" /etc/systemd/system/clamav-clamonacc.service.d/override.conf

sudo systemctl daemon-reload
echo "==> Installed systemd units"

# Run initial database update
echo "==> Running initial freshclam database update..."
sudo freshclam || echo "Warning: freshclam failed (may already be up to date)"

# Enable and start services
sudo systemctl enable --now clamav-daemon.service
sudo systemctl enable --now clamav-clamonacc.service
sudo systemctl enable --now clamav-freshclam-update.service
sudo systemctl enable --now clamav-freshclam-update.timer
# Disable old weekly scan timer if present (scans are now on-demand from TUI)
sudo systemctl disable --now clamav-weekly-scan.timer 2>/dev/null || true
echo "==> Enabled and started ClamAV services"

echo "==> ClamAV antivirus setup complete!"
