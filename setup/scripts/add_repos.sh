#!/bin/bash
set -euo pipefail

# Add Chaotic-AUR repository
echo "==> Adding Chaotic-AUR repository..."
sudo pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com
sudo pacman-key --lsign-key 3056513887B78AEB
sudo pacman -U --noconfirm \
  'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' \
  'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'

if ! grep -q '\[chaotic-aur\]' /etc/pacman.conf; then
  echo -e '\n[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist' | sudo tee -a /etc/pacman.conf
fi

# Add arch4edu repository
echo "==> Adding arch4edu repository..."
sudo pacman-key --recv-keys 7931B6D628C8D3BA
sudo pacman-key --finger 7931B6D628C8D3BA
sudo pacman-key --lsign-key 7931B6D628C8D3BA

if ! grep -q '\[arch4edu\]' /etc/pacman.conf; then
  echo -e '\n[arch4edu]\nServer = https://mirror.sunred.org/arch4edu/$arch' | sudo tee -a /etc/pacman.conf
fi

# Sync repos and install yay
echo "==> Syncing repositories and installing yay..."
sudo pacman -Sy --noconfirm yay
