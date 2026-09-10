#!/bin/bash
#
# Prepare the host for the docker-hosted VMs managed by `bin/vm`.
#
# Nothing here needs root: the VMs run under rootless Docker, the devices they
# need are world-accessible by Arch's udev defaults, and everything else lives
# in the user's home. Run setup_docker.sh first.
#
# See vm/README.md for guest-side setup and day-to-day use.

set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DATA_DIR="$HOME/VMs"

info() { echo "==> $*"; }
warn() { echo "==> WARNING: $*" >&2; }

info "Setting up virtual machine support..."

# ------------------------------------------------------------------------------
# Host capabilities
# ------------------------------------------------------------------------------

ok=true

if [[ ! -e /dev/kvm ]]; then
  warn "no /dev/kvm — enable virtualization in the BIOS, or load kvm_intel/kvm_amd"
  ok=false
elif [[ ! -r /dev/kvm || ! -w /dev/kvm ]]; then
  warn "/dev/kvm is $(stat -c '%A %U:%G' /dev/kvm) — rootless containers cannot use it"
  ok=false
fi

if ! command -v xfreerdp3 >/dev/null 2>&1; then
  warn "xfreerdp3 not found — 'ACCESS=rdp' VMs will not connect (package: freerdp)"
  ok=false
fi

if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
  if ! docker info --format '{{json .SecurityOptions}}' | grep -q rootless; then
    warn "the active Docker context is not rootless — run setup_docker.sh"
    ok=false
  fi
else
  warn "cannot reach a Docker daemon — run setup_docker.sh"
  ok=false
fi

# ------------------------------------------------------------------------------
# Storage
# ------------------------------------------------------------------------------

# 0700: guest disks and anything dropped in a shared folder should not be
# readable by other local accounts.
install -d -m 700 "$DATA_DIR"
info "VM disks and shared folders live in $DATA_DIR"

for config in "$DOTFILES"/vm/vms.d/*.conf; do
  [[ -e $config ]] || continue
  name="$(basename "$config" .conf)"
  install -d -m 700 "$DATA_DIR/$name" "$DATA_DIR/$name/share"
done

# ------------------------------------------------------------------------------

if [[ $ok == true ]]; then
  info "Ready. Configured VMs:"
  vm list 2>/dev/null || true
  echo
  echo "    vm install windows    install a guest"
  echo "    vm launch windows     start it and connect"
else
  warn "some prerequisites are missing — see the warnings above"
fi
