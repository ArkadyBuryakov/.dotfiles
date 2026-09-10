#!/bin/bash
#
# Set up rootless Docker and take the user out of the `docker` group.
#
# Membership in `docker` is root-equivalent: anyone in it can `docker run -v
# /:/host` and own the machine. Rootless Docker runs the daemon as the user
# inside a user namespace instead, so there is no root to escalate to. Bind
# mounts also come out owned by the user rather than by root, which is what
# makes the VM shared folders usable.
#
# Idempotent: safe to re-run. It does not touch the old rootful /var/lib/docker
# — prune what you want to keep or lose first, then remove that directory by
# hand once the rootless daemon is working.

set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ROOTLESS_SOCKET="/run/user/$(id -u)/docker.sock"

info() { echo "==> $*"; }
warn() { echo "==> WARNING: $*" >&2; }
die() {
  echo "==> ERROR: $*" >&2
  exit 1
}

confirm() {
  local answer
  read -r -p "==> $1 [y/N]: " answer
  [[ $answer == [yY]* ]]
}

# ------------------------------------------------------------------------------
# Preflight — everything rootless Docker needs from the host
# ------------------------------------------------------------------------------

info "Checking prerequisites..."

# Arch's docker-rootless-extras does not ship upstream's
# dockerd-rootless-setuptool.sh. It packages the systemd *user* units directly,
# which is simpler: there is nothing to generate, just a unit to enable. Fall
# back to the setuptool for hosts that do ship it instead.
PACKAGED_UNIT="/usr/lib/systemd/user/docker.service"

command -v dockerd-rootless.sh >/dev/null 2>&1 ||
  die "dockerd-rootless.sh not found.
    Install the packages first: setup/scripts/dependencies.sh
    (docker-rootless-extras, rootlesskit, slirp4netns, passt)"

command -v rootlesskit >/dev/null 2>&1 ||
  die "rootlesskit not found (package: rootlesskit)"

# dockerd-rootless.sh maps the subuid/subgid ranges with these setuid helpers;
# without them the daemon cannot create its user namespace.
command -v newuidmap >/dev/null 2>&1 && command -v newgidmap >/dev/null 2>&1 ||
  die "newuidmap/newgidmap not found (package: shadow)"

[[ -f $PACKAGED_UNIT ]] || command -v dockerd-rootless-setuptool.sh >/dev/null 2>&1 ||
  die "neither $PACKAGED_UNIT nor dockerd-rootless-setuptool.sh is available"

grep -q "^$USER:" /etc/subuid ||
  die "no /etc/subuid entry for $USER. Add one as root:
        sudo usermod --add-subuids 100000-165535 $USER"
grep -q "^$USER:" /etc/subgid ||
  die "no /etc/subgid entry for $USER. Add one as root:
        sudo usermod --add-subgids 100000-165535 $USER"

[[ $(cat /proc/sys/user/max_user_namespaces 2>/dev/null || echo 0) -gt 0 ]] ||
  die "unprivileged user namespaces are disabled in the kernel"

# A kernel upgrade deletes the running kernel's module tree, so nothing that is
# not already loaded can be loaded until reboot. Catch that here: otherwise it
# surfaces much later as an opaque 'failed to setup network ... exit status 1'
# from deep inside RootlessKit.
if [[ ! -d "/lib/modules/$(uname -r)" ]]; then
  die "the running kernel ($(uname -r)) has no module tree in /lib/modules.

    The kernel was upgraded ($(pacman -Q linux 2>/dev/null || echo 'newer version installed'))
    but not rebooted into, so no new module can be loaded — including 'tun',
    which rootless networking needs.

    Reboot, then re-run this script."
fi

[[ $(stat -fc %T /sys/fs/cgroup) == cgroup2fs ]] ||
  warn "cgroup v2 not detected — resource limits will not work rootless"

# KVM has to be reachable by the unprivileged daemon or every VM falls back to
# software emulation. Arch ships /dev/kvm as 0666 by udev default.
if [[ -e /dev/kvm ]]; then
  [[ -r /dev/kvm && -w /dev/kvm ]] ||
    warn "/dev/kvm is $(stat -c '%A %U:%G' /dev/kvm) — rootless containers cannot use KVM.
    Expected 0666 from /usr/lib/udev/rules.d/50-udev-default.rules"
else
  warn "no /dev/kvm — virtualization is off in the BIOS, or the module is not loaded"
fi

info "Prerequisites OK"

# ------------------------------------------------------------------------------
# Retire the rootful daemon
# ------------------------------------------------------------------------------

if systemctl is-enabled docker.service >/dev/null 2>&1 ||
  systemctl is-active docker.service >/dev/null 2>&1; then
  info "Stopping and disabling the system-wide Docker daemon..."
  sudo systemctl disable --now docker.service docker.socket
else
  info "System-wide Docker daemon already disabled"
fi

if id -nG "$USER" | grep -qw docker; then
  info "Removing $USER from the 'docker' group..."
  sudo gpasswd -d "$USER" docker
  warn "the group change only takes effect after a full logout"
else
  info "$USER is not in the 'docker' group"
fi

# ------------------------------------------------------------------------------
# Host tuning — must happen before the daemon starts
# ------------------------------------------------------------------------------

# RootlessKit runs its network namespace on a tap device, so the tun driver has
# to be loaded before the daemon starts. /dev/net/tun is a static node that
# exists whether or not the driver is there, so its presence proves nothing:
# without the module, opening it returns ENODEV and the daemon dies with an
# opaque 'failed to setup network' error.
MODULES_SRC="$DOTFILES/docker/modules-load-tun.conf"
MODULES_DST="/etc/modules-load.d/tun.conf"
if [[ -f $MODULES_SRC ]] && ! cmp -s "$MODULES_SRC" "$MODULES_DST" 2>/dev/null; then
  info "Installing $MODULES_DST..."
  sudo cp "$MODULES_SRC" "$MODULES_DST"
fi
if [[ ! -d /sys/module/tun ]]; then
  info "Loading the tun module..."
  sudo modprobe tun ||
    die "could not load 'tun'. If the kernel was just upgraded, reboot and re-run."
fi

# Rootless daemons cannot bind ports below 1024 by default, which breaks the
# usual `-p 80:80` / `-p 443:443` development containers. The packaged
# /usr/lib/sysctl.d/99-docker-rootless.conf only enables unprivileged user
# namespaces; it says nothing about ports, so this is additive, not a duplicate.
SYSCTL_SRC="$DOTFILES/docker/99-rootless-docker.conf"
SYSCTL_DST="/etc/sysctl.d/99-rootless-docker.conf"
if [[ -f $SYSCTL_SRC ]] && ! cmp -s "$SYSCTL_SRC" "$SYSCTL_DST" 2>/dev/null; then
  info "Installing $SYSCTL_DST (allows binding ports >= 80 unprivileged)..."
  sudo cp "$SYSCTL_SRC" "$SYSCTL_DST"
  sudo sysctl --system >/dev/null
fi

# ------------------------------------------------------------------------------
# Install the rootless daemon
# ------------------------------------------------------------------------------

if [[ -f $PACKAGED_UNIT ]]; then
  info "Using the packaged user unit ($PACKAGED_UNIT)"
elif [[ -f "$HOME/.config/systemd/user/docker.service" ]]; then
  info "Rootless Docker already installed by the setuptool"
else
  info "Installing rootless Docker via the setuptool..."
  # The setuptool refuses to run while the system daemon is up, which is why the
  # step above has to come first.
  dockerd-rootless-setuptool.sh install
fi

# Without lingering, the daemon dies when the last session closes, taking any
# running VM with it.
if [[ $(loginctl show-user "$USER" -p Linger --value 2>/dev/null) != "yes" ]]; then
  info "Enabling lingering so the daemon survives logout..."
  sudo loginctl enable-linger "$USER"
fi

# Only docker.service. The package also ships a docker.socket for socket
# activation, but rootless dockerd already listens on $XDG_RUNTIME_DIR/docker.sock
# by default, and enabling both makes two units contend for the same path.
info "Enabling the user service..."
systemctl --user daemon-reload
# A previous failed attempt leaves the unit in start-limit-hit, which makes the
# next start a no-op with a confusing message. Clear it so a re-run is honest.
systemctl --user reset-failed docker.service 2>/dev/null || true
systemctl --user enable --now docker.service

# Prefer the context over exporting DOCKER_HOST: it is picked up by every
# process, including GUI apps launched from the app launcher, not only shells
# that happen to source a profile.
#
# The setuptool creates this context itself on current versions, but not on all
# of them — and without it the CLI keeps looking for the rootful socket that we
# just took away, so create it if it is missing.
if ! docker context inspect rootless >/dev/null 2>&1; then
  info "Creating the 'rootless' Docker context..."
  docker context create rootless \
    --description "rootless dockerd" \
    --docker "host=unix://$ROOTLESS_SOCKET" >/dev/null
fi
docker context use rootless >/dev/null
info "Docker context set to 'rootless'"

# ------------------------------------------------------------------------------
# Verify
# ------------------------------------------------------------------------------

info "Verifying..."
docker info >/dev/null 2>&1 || die "cannot reach the rootless daemon at $ROOTLESS_SOCKET"

docker info --format '{{json .SecurityOptions}}' | grep -q rootless ||
  die "the daemon is reachable but does not report itself as rootless"

info "Rootless Docker is running"
echo
echo "    endpoint  $(docker context inspect --format '{{.Endpoints.docker.Host}}')"
echo "    data      $HOME/.local/share/docker"
echo
echo "    Log out and back in to drop the 'docker' group from your session."
echo "    See docker/README.md for what changes in day-to-day use."
