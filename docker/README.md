# Rootless Docker

Set up by [`setup/scripts/setup_docker.sh`](../setup/scripts/setup_docker.sh).

## Why

Membership in the `docker` group is root-equivalent. Anything running as you —
a postinstall script, a compromised dev dependency, a stray `npx` — can run
`docker run -v /:/host` and own the machine, with no password prompt and no
audit trail. The group is not a permission, it is a spare key to root.

Rootless Docker runs the daemon as your own user inside a user namespace. There
is no root to escalate to. As a bonus, bind mounts come out owned by *you*
rather than by root, which is what makes the VM shared folders usable without
`sudo chown` after every write.

## What changed

|                | Before                       | After                                 |
| -------------- | ---------------------------- | ------------------------------------- |
| Daemon         | `docker.service` (root)      | `systemctl --user docker.service`     |
| Socket         | `/var/run/docker.sock`       | `/run/user/1000/docker.sock`          |
| Data root      | `/var/lib/docker`            | `~/.local/share/docker`               |
| Group          | `docker` (root-equivalent)   | none                                  |
| Networking     | bridge + iptables            | RootlessKit + slirp4netns/passt       |

The CLI finds the daemon through the `rootless` **context**, not `DOCKER_HOST`.
A context is picked up by every process — including GUI apps launched from the
app launcher — rather than only by shells that happen to source a profile. So
there is deliberately no `DOCKER_HOST` export in `home/.zshrc`.

```bash
docker context ls          # 'rootless' should carry the *
docker context use rootless
```

`lazydocker` needs no configuration; it follows the same context.

## Gotchas

**Privileged ports.** A rootless daemon cannot bind below 1024, which breaks the
usual `-p 80:80`. [`99-rootless-docker.conf`](99-rootless-docker.conf) lowers
the threshold to 80 system-wide, so 80 and 443 work again while 22 and 53 stay
protected.

**`--network host` is not the host.** It joins RootlessKit's network namespace,
not the real host namespace. Containers that expect to see the host's interfaces
or reach a service on `127.0.0.1` of the host will not.

**Anything that needs real `NET_ADMIN` on the host.** `mitmproxy` in transparent
mode manipulates host iptables and will not work rootless; use it in explicit
proxy mode instead.

**Mounting paths outside your home** works only where your user can already
read/write them. `-v /var/…` is generally out.

**The daemon dies at logout** unless lingering is on. `setup_docker.sh` enables
it (`loginctl enable-linger`), so long-running containers and VMs survive.

**The group change needs a full logout.** `id -nG` keeps showing `docker` until
the session is rebuilt, even after `gpasswd -d`.

## Rolling back

```bash
systemctl --user disable --now docker.service
docker context use default
sudo systemctl enable --now docker.service docker.socket
sudo usermod -aG docker "$USER"      # re-adds the root-equivalent group
```

There is nothing to uninstall: Arch's `docker-rootless-extras` ships the systemd
*user* units at `/usr/lib/systemd/user/`, so disabling the unit is the whole of
it. (Upstream's `dockerd-rootless-setuptool.sh`, which generates those units
into `~/.config/systemd/user/`, is not part of the Arch package.)

`~/.local/share/docker` is left alone by the uninstall; remove it by hand if you
want the space back.
