# NetworkManager

Dispatcher scripts installed into `/etc/NetworkManager/dispatcher.d/`.

```sh
bash networkmanager/apply-networkmanager.sh            # install
bash networkmanager/apply-networkmanager.sh --remove   # uninstall
```

## `no-wait.d/10-charon-nm-reap`

Works around a strongSwan bug that makes every VPN connect after the first one
fail until reboot.

`Personal DE` and `Personal RU` are IKEv2 connections handled by
`networkmanager-strongswan`, which runs one shared `charon-nm` helper spawned by
NetworkManager. A few minutes after a strongSwan VPN drops, NetworkManager
SIGTERMs the now-idle `charon-nm`. With strongSwan 6.1.0 /
networkmanager-strongswan 1.6.4 that shutdown never finishes: `charon-nm`
unregisters its D-Bus object `/org/freedesktop/NetworkManager/VPN/Plugin` and
winds down to 4 threads, but never exits and keeps owning the bus name
`org.freedesktop.NetworkManager.strongswan`.

NetworkManager sees the name still owned, so it never spawns a replacement and
keeps calling into the dead plugin. Every later activation fails instantly:

```
vpn[...,"Personal RU"]: plugin NeedSecrets request #1 failed:
GDBus.Error:org.freedesktop.DBus.Error.UnknownMethod:
Object does not exist at path "/org/freedesktop/NetworkManager/VPN/Plugin"
```

Hence the symptom: the first connect after boot works, every one after it fails.
Because a single `charon-nm` serves all strongSwan connections, one wedged
process takes out `Personal DE` and `Personal RU` together.

The script kills `charon-nm` on `vpn-down` so NetworkManager reaps it and starts
a fresh one next time. A wedged `charon-nm` ignores SIGTERM, so SIGKILL is the
fallback.

To confirm the bug is what you are hitting, and to recover by hand:

```sh
pgrep -ax charon-nm                          # alive with no VPN up == wedged
sudo pkill -KILL -x charon-nm                # connects work again
```

Drop this once upstream fixes the shutdown path.
