#!/bin/bash
# Open btop with the process list sorted by the given key: "cpu lazy", "memory", ...
#
# btop has no flag for this, only the proc_sorting setting, so it is started
# on a throwaway copy of the main config with that setting replaced. btop saves
# its state to the config it was started with, which leaves the main one alone.

sorting="${1:?usage: btop-sorted.sh <proc_sorting value>}"
main="${XDG_CONFIG_HOME:-$HOME/.config}/btop/btop.conf"
config="${XDG_RUNTIME_DIR:-/tmp}/btop-${sorting%% *}.conf"

# Without a main config btop starts from its defaults
{ cat "$main" 2>/dev/null || btop --default-config; } |
  sed '/^proc_sorting = /d' >"$config"
echo "proc_sorting = \"$sorting\"" >>"$config"

exec btop -c "$config"
