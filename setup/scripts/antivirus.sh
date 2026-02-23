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
sudo chmod +x /etc/clamav/virus-event.bash /etc/clamav/scan-weekly.sh
echo "==> Copied ClamAV configs to /etc/clamav/"

# Install sudoers drop-in for clamav notify-send
sudo cp "$CLAMAV_SRC/sudoers-clamav" /etc/sudoers.d/clamav
sudo chmod 440 /etc/sudoers.d/clamav
echo "==> Installed sudoers drop-in for clamav"

# Create log directory and threat log
sudo mkdir -p /var/log/clamav
sudo touch /var/log/clamav/threats.log /var/log/clamav/weekly-scan.log
sudo chown -R clamav:clamav /var/log/clamav
sudo chmod 644 /var/log/clamav/threats.log /var/log/clamav/weekly-scan.log
echo "==> Created log files"

# Install systemd units
UNITS=(clamav-freshclam-update.service clamav-freshclam-update.timer clamav-weekly-scan.service clamav-weekly-scan.timer)
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
sudo systemctl enable --now clamav-weekly-scan.timer
echo "==> Enabled and started ClamAV services"

echo "==> ClamAV antivirus setup complete!"
