#!/bin/bash
# Install the custom PAM stacks from this directory into /etc/pam.d/.
#
#   apply-pam.sh            check, then install pam.d/*
#   apply-pam.sh --check    only check that every module and include resolves
#   apply-pam.sh --restore  check, then install pam.d/archive/*
#
# A broken stack locks you out of sudo and polkit: keep a root TTY open
# (Ctrl+Alt+F2) until `sudo -k && sudo true` works.
set -euo pipefail

PAM_SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FILES=(greetd hyprlock login polkit-1 su sudo)

mode="${1:-install}"
case "$mode" in
    install|--check) src="$PAM_SRC" ;;
    --restore)       src="$PAM_SRC/archive" ;;
    *) echo "usage: $0 [--check|--restore]" >&2; exit 2 ;;
esac

# PAM fails closed on a module or include it cannot find, so refuse to install
# anything that references one.
line_re='^[[:space:]]*(-?)(auth|account|session|password)[[:space:]]+(\[[^]]*\]|[^[:space:]]+)[[:space:]]+([^[:space:]]+)'
missing=0
for name in "${FILES[@]}"; do
    while IFS= read -r line; do
        [[ $line =~ $line_re ]] || continue
        [[ -n ${BASH_REMATCH[1]} ]] && continue # "-auth" etc. tolerate a missing module
        control=${BASH_REMATCH[3]} target=${BASH_REMATCH[4]}
        if [[ $control == include || $control == substack ]]; then
            [[ -e /etc/pam.d/$target || -e /usr/lib/pam.d/$target ]] && continue
        elif [[ $target == /* ]]; then
            [[ -e $target ]] && continue
        else
            [[ -e /usr/lib/security/$target ]] && continue
        fi
        echo "$src/$name: '$target' not found" >&2
        missing=1
    done < "$src/$name"
done
if ((missing)); then
    echo "Aborting, nothing installed." >&2
    exit 1
fi
echo "==> All modules and includes in $src resolve"
[[ $mode == --check ]] && exit 0

# Cache credentials while the current sudo stack still works, so a bad new one
# cannot stop the rest of this script.
sudo -v
sudo install -m644 -o root -g root -t /etc/pam.d "${FILES[@]/#/$src/}"
if [[ $mode == install ]]; then
    # su and sudo already carry these upstream changes
    sudo rm -f /etc/pam.d/su.pacnew /etc/pam.d/sudo.pacnew
fi
echo "==> Installed ${FILES[*]} from $src"
echo "Verify before closing your root TTY: sudo -k && sudo true"
