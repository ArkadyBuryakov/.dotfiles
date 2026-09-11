#!/usr/bin/env bash
# Generates rofi (drun) entries for projects in ~/Projects/<domain>/<project>.
# Selecting one opens a kitty window in the project with the dev.session layout.
#
# Entries are rebuilt on every run, so added/removed projects are picked up.
# Run before `rofi -show drun` (see hypr/conf/key_bindings.lua).

set -eu
shopt -s nullglob

PROJECTS_DIR="$HOME/Projects"
APPS_DIR="$HOME/.local/share/applications"
PREFIX="org.arkady.project."
ICON="$HOME/.local/share/icons/Apps/Common/editor.png"
SESSION="$HOME/.config/kitty/dev.session"

# my_project-name -> My Project Name
titleize() {
  local parts words=() w
  IFS='_-' read -ra parts <<<"$1"
  for w in "${parts[@]}"; do
    [ -n "$w" ] && words+=("${w^}")
  done
  echo "${words[*]}"
}

# Escape a value for use inside a double-quoted desktop Exec argument
exec_quote() {
  local s=${1//\\/\\\\\\\\}
  s=${s//\"/\\\\\"}
  s=${s//\`/\\\\\`}
  s=${s//\$/\\\\\$}
  echo "${s//%/%%}"
}

mkdir -p "$APPS_DIR"
rm -f "$APPS_DIR/$PREFIX"*.desktop

for dir in "$PROJECTS_DIR"/*/*/; do
  dir=${dir%/}
  project=${dir##*/}
  [ "$project" = worktrees ] && continue
  domain=${dir%/*}
  domain=${domain##*/}

  title="$(titleize "$domain"): $(titleize "$project")"
  id=$(printf '%s.%s' "$domain" "$project" | tr -c 'A-Za-z0-9_.-' '_')

  cat >"$APPS_DIR/$PREFIX$id.desktop" <<EOF
[Desktop Entry]
Type=Application
Version=1.0
Name=$title
Icon=$ICON
Path=$dir
Exec=kitty --title "$(exec_quote "$title")" --session "$(exec_quote "$SESSION")"
Terminal=false
Categories=Development;
EOF
done
