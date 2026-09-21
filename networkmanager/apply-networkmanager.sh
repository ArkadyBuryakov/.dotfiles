#!/bin/bash
# Install this directory's NetworkManager dispatcher scripts into
# /etc/NetworkManager/dispatcher.d/.
#
#   apply-networkmanager.sh           install
#   apply-networkmanager.sh --remove  uninstall
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST=/etc/NetworkManager/dispatcher.d
SCRIPTS=(no-wait.d/10-charon-nm-reap)

mode="${1:-install}"
case "$mode" in
    install | --remove) ;;
    *)
        echo "usage: $0 [--remove]" >&2
        exit 2
        ;;
esac

sudo -v

if [[ $mode == --remove ]]; then
    for s in "${SCRIPTS[@]}"; do
        sudo rm -f "$DEST/$s"
    done
    echo "==> Removed ${SCRIPTS[*]} from $DEST"
    exit 0
fi

# The dispatcher silently skips scripts that are not root-owned, not executable,
# or writable by group/other.
for s in "${SCRIPTS[@]}"; do
    bash -n "$SRC/dispatcher.d/$s"
    sudo install -D -m755 -o root -g root "$SRC/dispatcher.d/$s" "$DEST/$s"
done
sudo systemctl enable NetworkManager-dispatcher.service

echo "==> Installed ${SCRIPTS[*]} into $DEST"
