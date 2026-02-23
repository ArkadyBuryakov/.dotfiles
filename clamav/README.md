# ClamAV Antivirus Setup

## What gets installed

| File | Destination | Purpose |
|------|-------------|---------|
| `clamd.conf` | `/etc/clamav/` | Daemon config: on-access scanning for `/home`, VirusEvent hook |
| `freshclam.conf` | `/etc/clamav/` | Database update config |
| `virus-event.bash` | `/etc/clamav/` | On detection: logs threat + sends desktop notification |
| `scan-weekly.sh` | `/etc/clamav/` | Full system scan script (excludes `/sys`, `/dev`, `/proc`, `/run`) |
| `sudoers-clamav` | `/etc/sudoers.d/clamav` | Allows clamav user to run `notify-send` |
| `clamav-freshclam-update.service` | `/etc/systemd/system/` | Oneshot freshclam (also runs on boot) |
| `clamav-freshclam-update.timer` | `/etc/systemd/system/` | Triggers freshclam at midnight |
| `clamav-weekly-scan.service` | `/etc/systemd/system/` | Oneshot full-system scan |
| `clamav-weekly-scan.timer` | `/etc/systemd/system/` | Triggers scan every Saturday at midnight |

## Services

| Service | Schedule |
|---------|----------|
| `clamav-daemon` | Always running — background scanning daemon |
| `clamav-clamonacc` | Always running — real-time on-access scanning of `/home` |
| `clamav-freshclam-update` | Every boot + every midnight — virus database updates |
| `clamav-weekly-scan` | Every Saturday at midnight — full system scan |

## Threat workflow

```
Threat detected
  │
  ├─► virus-event.bash appends to /var/log/clamav/threats.log
  │
  ├─► Desktop notification (red border, top-right, 10 min)
  │
  └─► Waybar icon turns red: 󰃤
        │
        ├─ Hover: shows last 5 log entries
        └─ Click: opens kitty sudo nvim /var/log/clamav/threats.log
              │
              └─► Remove resolved lines from the log
                    │
                    └─► Log empty → Waybar returns to safe icon: 󱏛
```

## Setup

Run `setup/scripts/antivirus.sh`. It copies configs, installs systemd units, creates log files, and enables all services.

Prerequisite: `clamav` package must be installed.
