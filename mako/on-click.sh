#!/usr/bin/env bash
#
# mako left-click handler: `on-button-left=exec ~/.config/mako/on-click.sh "$id"`
#
# - Notification has a default action -> invoke it (mako's stock behaviour).
# - Otherwise, if it has a "Show in folder"-style action (e.g. MEGAsync's
#   download notifications: actions "Open" / "Show in folder", no default,
#   body names only the folder) -> invoke that action.
# - Otherwise, if it refers to an existing file or directory -> reveal it,
#   selected, in the file manager (org.freedesktop.FileManager1.ShowItems).
#   Looked up in the body first (e.g. "... saved to /path/shot.png"), then in
#   the icon, which screenshot tools set to the image itself. Icons are only
#   trusted under $HOME outside dot-directories, so app icons and cached
#   avatars (/usr/share, ~/.cache, /tmp) don't count as "files".
# - Always dismisses the notification afterwards.

id="${1:?usage: on-click.sh <notification id>}"

dismiss() { makoctl dismiss -n "$id" 2>/dev/null; }
trap dismiss EXIT

n="$(makoctl list -j | jq -c --argjson id "$id" '.[] | select(.id == $id)')"
[[ -n "$n" ]] || exit 0

if jq -e '.actions | has("default")' <<<"$n" >/dev/null; then
  makoctl invoke -n "$id" default
  exit 0
fi

action="$(jq -r '.actions | keys[] | select(test("^(show|open) (in|containing) (folder|file manager)$|^reveal"; "i"))' <<<"$n" | head -n 1)"
if [[ -n "$action" ]]; then
  makoctl invoke -n "$id" "$action"
  exit 0
fi

# Strip markup/entities and pull out absolute or ~/ paths (optionally file://).
# Paths may contain spaces, so each match runs to the end of the line and is
# then shortened word by word until it names something that exists.
candidates() {
  local p
  jq -r '.body // ""' <<<"$n" |
    sed -e 's/<[^>]*>/ /g' -e 's/&amp;/\&/g' -e 's/&lt;/</g' -e 's/&gt;/>/g' |
    grep -oE '(file://)?(~|/)[^"'"'"'<>]+' |
    sed -e 's|^file://||' -e "s|^~|$HOME|" |
    while IFS= read -r p; do
      while :; do
        p="$(sed -e 's/[[:space:].,;:!?)]*$//' <<<"$p")"
        [[ -e "$p" ]] && { printf '%s\n' "$p"; break; }
        [[ "$p" == *[[:space:]]* ]] || break
        p="${p% *}"
      done
    done

  local icon
  icon="$(jq -r '.app_icon // ""' <<<"$n")"
  icon="${icon#file://}"
  [[ "$icon" == "$HOME"/* && "$icon" != "$HOME"/.* ]] && printf '%s\n' "$icon"
}

while IFS= read -r path; do
  [[ -e "$path" ]] || continue
  # in a new window (FileManager1.ShowItems would add a tab to an open one)
  reveal "$path" &
  exit 0
done < <(candidates)
