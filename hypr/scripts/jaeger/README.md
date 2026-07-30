# jaeger

Side panel for Hyprland showing AI agents (Claude Code, codex, aider, …)
running across all kitty OS windows: project, git branch, live status, current
task and workspace. Click a card to jump to the agent — workspace, kitty OS
window, tab and window.

Named after the mechs from Pacific Rim: you drift with your agents.

## How it works

- `scan.sh` — enumerates kitty instances from `hyprctl clients -j` (one kitty
  process per OS window), queries each over its remote-control socket
  (`unix:@mykitty-<pid>`), and picks windows whose foreground process is a
  known agent. Status is parsed from the terminal title Claude Code maintains
  (`⠂ task…` = busy, `✳` = idle), optionally overridden by hook state files.
- `focus.sh <kitty_pid> <win_id> [hypr_address]` — `hyprctl focuswindow` to
  the right workspace, then `kitten @ focus-window` to select the exact
  tab/window; `focus_on_activate` makes Hyprland follow.
- `shell.qml` — Quickshell panel: polls `scan.sh` every 1.5 s and rescans
  instantly on Hyprland window/workspace events.
- `jaeger.sh [start|stop|toggle]` — launcher.
- `claude-hook.sh` — optional Claude Code hook for precise status
  (adds a "waiting for input" state that title parsing can't detect).

## Setup

```sh
sudo pacman -S quickshell
```

Hyprland config:

```conf
exec-once = ~/.config/hypr/scripts/jaeger/jaeger.sh start
bind = $mainMod, A, exec, ~/.config/hypr/scripts/jaeger/jaeger.sh toggle
```

## Optional: precise status via Claude Code hooks

Add to `~/.claude/settings.json`:

```json
{
  "hooks": {
    "UserPromptSubmit": [{ "hooks": [{ "type": "command", "command": "~/.config/hypr/scripts/jaeger/claude-hook.sh" }] }],
    "Notification":     [{ "hooks": [{ "type": "command", "command": "~/.config/hypr/scripts/jaeger/claude-hook.sh" }] }],
    "Stop":             [{ "hooks": [{ "type": "command", "command": "~/.config/hypr/scripts/jaeger/claude-hook.sh" }] }],
    "SessionEnd":       [{ "hooks": [{ "type": "command", "command": "~/.config/hypr/scripts/jaeger/claude-hook.sh" }] }]
  }
}
```

Card colors: yellow = busy, green = idle, red = waiting for input, gray = unknown.

## Requirements

- kitty with `allow_remote_control yes` and `listen_on unix:@mykitty`
- Hyprland with `focus_on_activate` enabled
- `quickshell`, `jq`
