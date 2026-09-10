# Virtual machines

Windows and Linux guests running as QEMU/KVM inside rootless Docker containers,
managed by [`bin/vm`](../bin/vm).

| Guest   | Image                                                  | Access                        |
| ------- | ------------------------------------------------------ | ----------------------------- |
| Windows | [`dockurr/windows`](https://github.com/dockur/windows)  | RDP (`xfreerdp3`) + noVNC     |
| Linux   | [`qemux/qemu`](https://github.com/qemus/qemu)           | noVNC, optionally RDP         |

Both images share the same QEMU base and the same environment-variable
vocabulary, so one script drives both.

There is no GPU passthrough and no snapshots. This is for "I need Office" and
"I need to test on Fedora", not for gaming or video editing.

## Layout

```
vm/vms.d/<name>.conf          VM definition (this repo, symlinked to ~/.config/vm)
~/VMs/<name>/disk             the guest's virtual disk
~/VMs/<name>/share            folder shared with the guest
~/.local/share/vm/<name>/     generated compose file + guest password (0600)
```

The compose file and the password are generated runtime state and are
deliberately **not** in this repo. Everything you would want to edit is in the
`.conf`.

**Editing a `.conf` does nothing on its own.** The compose is rendered only by
`vm install`, so a restart — or `vm start`, or rebooting the guest — keeps
running the settings captured at the last install. To change RAM, cores, ports,
GPU or disk size:

```bash
# edit vm/vms.d/arch.conf
vm install arch          # re-renders, stops the guest cleanly, restarts it
```

That is non-destructive: the disk is a bind mount under `~/VMs/<name>/disk` and
is never touched by a reconfigure. `vm start` and `vm launch` warn when the
`.conf` is newer than the generated compose, so drift does not go unnoticed.

## Commands

```bash
vm list                  # configured VMs and their status
vm install windows       # create/refresh a VM and start the guest install
vm launch windows        # start and connect; stops the VM when you disconnect
vm launch windows -k     # ...but leave it running
vm start / stop / status windows
vm console windows       # open the noVNC console in a browser window
vm remove windows        # delete the VM and its disk (keeps the share)
vm menu                  # rofi picker
vm key                   # print this machine's OEM Windows key from firmware
```

`vm` refuses to run against a rootful Docker daemon — see
[`../docker/README.md`](../docker/README.md).

## Installing a guest

### Windows

```bash
vm install windows
```

Asks for the guest password, then downloads and installs Windows 11 Pro
unattended (~8 GB, 10-15 minutes). Watch it at <http://127.0.0.1:8006> — the
console asks for the same username and password.

Once it is up, `vm launch windows` connects over RDP with sound, microphone,
clipboard and dynamic resolution, and the display scale is mapped from your
focused Hyprland monitor. `~/VMs/windows/share` appears in the guest as drive
`Z:` and as `Shared` on the desktop.

Windows is unactivated. `vm key` prints the OEM key from this machine's ACPI
MSDM table, which survives having replaced Windows with Linux — but an OEM key
is bound to the hardware and will normally *not* activate a VM.

### Linux

```bash
vm install arch
vm console arch          # complete the distro installer here
```

`BOOT` in the `.conf` picks the distro (`arch`, `fedora`, `debian`, `nixos`,
`alpine`, `cachy`, `kali`, `tails`, `ubuntu`, …) or takes a URL to any
`.iso`/`.qcow2`/`.img`/`.vhdx`.

**What you get depends on the distro**, and it is worth knowing which before you
go looking for a login prompt:

- Some values fetch a **pre-installed cloud image** and boot straight to a login.
  `arch` pulls [`Arch-Linux-x86_64-basic.qcow2`][arch-boxes], which comes with the
  user **`arch`**, password **`arch`**, and sshd enabled. Nothing to install —
  change that password.
- Others fetch an **installer ISO** (`alpine`, for example) and you run the
  distro's own installer through the noVNC console.

`docker logs vm-<name>` shows which file it downloaded if you are unsure.

[arch-boxes]: https://gitlab.archlinux.org/archlinux/arch-boxes

Two things are worth doing inside the guest afterwards.

**Mount the shared folder.** The share is 9p, not SMB, so it is not automatic:

```bash
sudo mkdir -p /mnt/shared
sudo mount -t 9p -o trans=virtio,version=9p2000.L shared /mnt/shared
```

To make it permanent, in the guest's `/etc/fstab`:

```
shared  /mnt/shared  9p  trans=virtio,version=9p2000.L,rw,_netdev  0 0
```

**If you install a desktop, add the user to `wheel`.** The image grants sudo
through `/etc/sudoers.d/arch`, not group membership, and `useradd -U` puts the
user in no supplementary groups. But polkit does not read sudoers — Arch's
default rule makes `unix-group:wheel` the only admin identity. With `wheel`
empty, polkit falls back to root, and root is locked, so any desktop action
needing authorization (installing a system Flatpak from Discover, mounting a
disk, changing the clock) shows an unanswerable root prompt.

```bash
sudo usermod -aG wheel arch
sudo pacman -S --needed polkit-kde-agent   # or polkit-gnome
```

Log out and back in afterwards; group membership is fixed at login. Per-user
Flatpaks (`flatpak install --user`) need no authorization and sidestep this.

**If you install a desktop, switch to NetworkManager.** The Arch basic image
does networking with `systemd-networkd` + `systemd-resolved` and does not ship
NetworkManager at all. Networking works fine, but KDE/GNOME's applet only talks
to NetworkManager and will report "NetworkManager service is not running" next
to a perfectly working connection. In the guest:

```bash
sudo pacman -S --needed networkmanager
sudo systemctl disable --now systemd-networkd.socket systemd-networkd.service
sudo systemctl enable --now NetworkManager.service
sudo rm /etc/systemd/network/80-dhcp.network    # the image's networkd config
```

Install before disabling, or you drop the link before the replacement exists.
Leave `systemd-resolved` alone — NetworkManager hands DNS to it, and the
image's `/etc/resolv.conf` symlink keeps working. Check with `nmcli device`.

**Set up an RDP server** if you want a real window instead of the browser
console. This is the recommended way to use a desktop guest: a native window
with a **synced clipboard**, sound, microphone and resolution that follows the
window — and `vm launch` starts the container on connect and stops it again when
you close it.

*On a KDE guest*, use Plasma's own server. It is Wayland-native, so unlike xrdp
there is no X11 session to arrange:

```bash
sudo pacman -S krdp
```

Then **System Settings → Remote Desktop**: enable the server, add a username and
password (these are KRDP's own credentials, not your login account), and leave
it on port 3389. Configure it there before enabling anything by hand — the KCM
generates the TLS certificate that `krdpserver` refuses to start without.

It runs as a *user* service, so if RDP does not answer, check it inside the
guest:

```bash
systemctl --user status app-org.kde.krdpserver.service
journalctl --user -u app-org.kde.krdpserver -n 30
ss -ltnp | grep 3389      # must be 0.0.0.0, not 127.0.0.1
```

Three things catch people out:

- **A user service only runs while someone is logged into Plasma.** With no
  autologin in the guest, sitting at the login screen means nothing is listening.
  Keep a session open at the noVNC console, or enable autologin in the guest.
- **It needs a Wayland session** — KRDP captures through KWin's screencast
  portal and does not work from an X11 Plasma session.
- **It must bind `0.0.0.0`, not `127.0.0.1`.** User-mode networking forwards to
  the guest's own address, so a loopback-only bind is unreachable from the
  container no matter how the ports are published.

*On a non-KDE guest*, xrdp is the fallback — but it drives an X11 session, so
you need `xorg` plus a `~/.xsession`:

```bash
yay -S xrdp xorgxrdp        # Arch (AUR)
sudo apt install xrdp       # Debian / Ubuntu
echo "exec startplasma-x11" > ~/.xsession
sudo systemctl enable --now xrdp
```

Either way, back on the host set `ACCESS=rdp` in the `.conf`, put the RDP
account in `USERNAME`, and re-run `vm install <name>` — it publishes the port
and offers to remember the password so launches stop prompting. Then:

```bash
vm launch arch        # connect; stops the container when you close the window
vm launch arch -k     # ...leave it running instead
```

GPU acceleration (`GPU=Y`) gives the guest hardware OpenGL, and Vulkan via Venus
on kernel ≥ 6.13. It only affects the noVNC console — RDP is a software path
either way, so pick one or the other.

**Leave `GPU=N` for a KDE guest.** Acceleration reaches the guest one of two
ways: native contexts (vDRM), or virgl. vDRM needs the host GPU on the `i915`
driver; Lunar Lake and newer use `xe`, so it silently falls back to virgl —
the boot log says which:

```
vDRM: [   ] the Intel GPU is using 'xe' instead of the i915 DRM driver
```

`kwin_wayland` then submits commands virglrenderer rejects, the GL context dies
and the desktop freezes solid with a vCPU spinning:

```
vrend_decode_ctx_submit_cmd: context error reported 8 "kwin_wayland"
                             Illegal command buffer 394753
```

`docker logs vm-<name> | grep vrend` confirms it. Set `GPU=N` and re-run
`vm install <name>`; the guest falls back to software rendering, which is slower
but stable. If you want acceleration for something less demanding than a
compositor, keep `GPU=Y` and run a plain WM rather than Plasma.

## Config reference

```sh
KIND=windows|linux       # which backend image to use
VERSION=11               # windows: 11, 10, 11l, 2025, tiny11, … (see dockur/windows)
BOOT=arch                # linux: distro name or a URL to an image
RAM_SIZE=8G
CPU_CORES=4
DISK_SIZE=64G            # grows the disk if raised; never shrinks
USERNAME=arkady          # windows: the guest account. linux: the xrdp account
ACCESS=rdp|web           # how `vm launch` connects
WEB_PORT=8006            # host port for the noVNC console
RDP_PORT=3389            # host port for RDP
SSH_PORT=2222            # linux: host port forwarded to the guest's sshd
RDP_SIZING=smart         # dynamic | smart | fixed  (see below)
RDP_SIZE=1920x1080       # used by 'fixed', and the guest's own resolution
GPU=Y|N                  # linux: pass /dev/dri through
AUDIO=Y|N                # linux: stream guest audio to the console
ARGUMENTS=               # extra raw QEMU arguments
DESCRIPTION=Windows      # name shown in the app launcher
STORAGE= / SHARE=        # override the default ~/VMs/<name>/... paths
```

Every VM needs its own `WEB_PORT` and `RDP_PORT`. All ports bind to `127.0.0.1`
only, so nothing on the network can reach a guest.

## Making the guest fit the window

`RDP_SIZING` picks one of three mutually exclusive behaviours:

| Value | Behaviour | Use when |
|---|---|---|
| `dynamic` | The guest resizes to match the window | Windows guests |
| `smart` | The guest keeps its resolution; the image scales to the window | KDE guests today |
| `fixed` | Connect at exactly `RDP_SIZE`, no scaling | You want a known resolution |

`dynamic` is the one you actually want, but it needs the server to implement the
RDPEDISP display-control channel. Windows does. **KRDP does not, as of 6.7.4** —
`src/DisplayControl.cpp` exists only in `master` and is in no released tag, so
the client's resize requests go unanswered and nothing happens. Use `smart`
until that ships, then switch to `dynamic`.

With `smart`, set the guest's own resolution sensibly (System Settings >
Display in the guest) — that is what actually gets rendered, and scaling it up
to a much larger window looks soft.

## Rootless networking

Under rootless Docker there is no `NET_ADMIN` and no `/dev/net/tun`, so the
container cannot build its usual bridge. The generated compose asks for
`NETWORK: "passt"` (user-mode networking) up front, which is what the container
would fall back to anyway — asking for it directly skips a failed attempt and
its timeout.

The consequence: `ports:` only reaches the *container*. Ports that must reach
the *guest* also have to be listed in `USER_PORTS`, which `vm` does for RDP and
SSH. If you expose something else in the guest, add it there.

## The console in a browser window

`vm console` opens the noVNC console as a chromeless app window using
`chromium --app=`. To use something else:

```bash
VM_CONSOLE_CMD="zen-browser --kiosk" vm console arch
```

Zen's config is not managed by these dotfiles, so if you want it wired in
permanently, do it by hand:

1. Add `export VM_CONSOLE_CMD="zen-browser --kiosk"` to `home/.zshrc`, or
2. In Zen, open `http://127.0.0.1:8006` and pin it as an Essential / web panel
   so it keeps its own session, then just use `vm start <name>` and switch to
   the pinned tab instead of `vm launch`.

`--kiosk` is inherited from Firefox and opens a fullscreen, chromeless window;
press `F11` or `Esc` to get out.

## Troubleshooting

**"the active Docker context is NOT rootless"** — `docker context use rootless`,
or the daemon is not running: `systemctl --user status docker`.

**KVM is not available** — check `ls -l /dev/kvm`. It should be `crw-rw-rw-`,
which is Arch's udev default; without world access the rootless daemon cannot
use it and the guest falls back to painfully slow software emulation.

**RDP hangs for ~20s and no window appears** — this should be handled: FreeRDP 3
tries Kerberos before NTLM and Arch's stock `/etc/krb5.conf` sends it hunting
for `ATHENA.MIT.EDU`. `vm` writes a realm-less krb5 config to
`~/.local/share/vm/krb5.conf` and points `KRB5_CONFIG` at it. If you still see
it, check that file exists.

**The guest install stalls** — watch the container directly:
`docker logs -f vm-<name>`.

**Windows clock drifts** — already handled with
`-rtc base=localtime,clock=host,driftfix=slew` in the generated compose.
