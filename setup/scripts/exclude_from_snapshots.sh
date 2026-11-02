#!/bin/bash
# Exclude directories from snapper snapshots and purge them from existing ones.
#
# Usage: exclude_from_snapshots.sh [--dry-run] [--no-estimate] [DIR...]   (default: ~/Videos/Movies)
#
# Each DIR is converted into a nested btrfs subvolume (snapper does not recurse
# into those), then deleted from every existing snapshot of the /home config.
# Snapshots are flipped writable only for the deletion and restored afterwards.
# Note: this invalidates touched snapshots as parents for incremental btrfs send.
set -euo pipefail

SUBVOL="${SUBVOL:-/home}"
SNAP_ROOT="${SNAP_ROOT:-$SUBVOL/.snapshots}"

DRY_RUN=false
ESTIMATE=true
DIRS=()
for arg in "$@"; do
    case "$arg" in
        -n|--dry-run) DRY_RUN=true ;;
        --no-estimate) ESTIMATE=false ;;
        -h|--help) sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) DIRS+=("$arg") ;;
    esac
done
[[ ${#DIRS[@]} -eq 0 ]] && DIRS=("$HOME/Videos/Movies")

if [[ $EUID -eq 0 ]]; then
    echo "Run as your user (sudo is used where needed) so new subvolumes are owned by you." >&2
    exit 1
fi

is_subvolume() {
    [[ "$(stat -c %i "$1" 2>/dev/null)" == 256 ]]
}

# Resolve paths and make them relative to the snapshotted subvolume
RELS=()
for dir in "${DIRS[@]}"; do
    abs="$(realpath -m "$dir")"
    if [[ "$abs" != "$SUBVOL"/* ]]; then
        echo "Error: $abs is not inside $SUBVOL" >&2
        exit 1
    fi
    RELS+=("${abs#"$SUBVOL"/}")
done

mapfile -t SNAPSHOTS < <(sudo find "$SNAP_ROOT" -mindepth 2 -maxdepth 2 -name snapshot -type d | sort -V)
echo "==> Found ${#SNAPSHOTS[@]} snapshots in $SNAP_ROOT"

# Step 1: convert directories to subvolumes so future snapshots skip them
for rel in "${RELS[@]}"; do
    dir="$SUBVOL/$rel"
    if is_subvolume "$dir"; then
        echo "==> $dir is already a subvolume"
        continue
    fi
    if $DRY_RUN; then
        echo "[dry-run] would convert $dir to a subvolume"
        continue
    fi
    if [[ -e "$dir" ]]; then
        if [[ -e "$dir.old" ]]; then
            echo "Error: $dir.old already exists (leftover from a failed run?)" >&2
            exit 1
        fi
        # Files owned by other users (e.g. rootless Docker's subuids) can only be
        # copied with their ownership intact as root
        as=()
        if [[ -n "$(sudo find "$dir" ! -user "$USER" -print -quit)" ]]; then
            echo "==> $dir contains files not owned by $USER, converting with sudo"
            as=(sudo)
        fi
        echo "==> Converting $dir to a subvolume..."
        "${as[@]}" mv "$dir" "$dir.old"
        btrfs subvolume create "$dir" >/dev/null
        # reflink=auto: NOCOW (+C) files can't be cloned into COW ones, so those
        # fall back to a regular copy instead of failing
        "${as[@]}" cp -a --reflink=auto "$dir.old/." "$dir/"
        # Keep the directory's NOCOW attribute so new files behave as before
        lsattr -d "$dir.old" | awk '{ exit $1 !~ /C/ }' && chattr +C "$dir"
        if [[ "$("${as[@]}" find "$dir.old" | wc -l)" != "$("${as[@]}" find "$dir" | wc -l)" ]]; then
            echo "Error: copy of $dir is incomplete; originals kept in $dir.old" >&2
            exit 1
        fi
        "${as[@]}" rm -rf -- "$dir.old"
    else
        echo "==> Creating subvolume $dir"
        mkdir -p "$(dirname "$dir")"
        btrfs subvolume create "$dir" >/dev/null
    fi
done

# Step 2: purge the directories from existing snapshots
TARGETS=()
for snap in "${SNAPSHOTS[@]}"; do
    for rel in "${RELS[@]}"; do
        sudo test -e "$snap/$rel" && TARGETS+=("$snap/$rel")
    done
done

if [[ ${#TARGETS[@]} -eq 0 ]]; then
    echo "==> Nothing to purge from snapshots"
    exit 0
fi

printf '  %s\n' "${TARGETS[@]}"

# Estimate reclaimable space: extents still used by the live directories are not
# freed, so it is disk usage of (targets + live) minus disk usage of live alone.
# compsize counts each shared extent once and accounts for compression.
if $ESTIMATE; then
    if ! command -v compsize &>/dev/null; then
        echo "==> Installing compsize for the space estimate..."
        sudo pacman -S --needed --noconfirm compsize
    fi

    disk_usage() {
        [[ $# -eq 0 ]] && { echo 0; return; }
        sudo compsize -b "$@" 2>/dev/null | awk '$1 == "TOTAL" { print $3; found = 1 } END { if (!found) print 0 }'
    }

    LIVE=()
    for rel in "${RELS[@]}"; do
        [[ -e "$SUBVOL/$rel" ]] && LIVE+=("$SUBVOL/$rel")
    done
    echo "==> Estimating reclaimable space (can take minutes for dirs with many files; skip with --no-estimate)..."
    live_bytes="$(disk_usage "${LIVE[@]}")"
    union_bytes="$(disk_usage "${TARGETS[@]}" "${LIVE[@]}")"
    saved="$(numfmt --to=iec-i --suffix=B --round=nearest $((union_bytes - live_bytes)))"
    echo "==> Space to be freed: ~$saved (excludes data still shared with files outside these directories)"
fi

if $DRY_RUN; then
    echo "[dry-run] would delete the ${#TARGETS[@]} paths above"
    exit 0
fi
read -rp "Delete the ${#TARGETS[@]} paths above from snapshots? [y/N] " answer
[[ "$answer" =~ ^[Yy]$ ]] || { echo "Aborted"; exit 1; }

for target in "${TARGETS[@]}"; do
    snap="${target%%/snapshot/*}/snapshot"
    was_ro="$(sudo btrfs property get -ts "$snap" ro)"
    [[ "$was_ro" == "ro=true" ]] && sudo btrfs property set -ts "$snap" ro false
    # Always restore read-only, even if the deletion fails
    if sudo rm -rf -- "$target"; then
        echo "==> Purged $target"
    else
        echo "Error: failed to delete $target" >&2
        FAILED=true
    fi
    [[ "$was_ro" == "ro=true" ]] && sudo btrfs property set -ts "$snap" ro true
done
${FAILED:-false} && exit 1

echo "==> Done. Space is reclaimed in the background; check with: sudo btrfs filesystem usage /"
