#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TODO_FILE="$SCRIPT_DIR/todo.yaml"
SETUP_FILE="$SCRIPT_DIR/setup.sh"
SCRIPTS_DIR="$SCRIPT_DIR/scripts"

if [[ ! -f "$TODO_FILE" ]]; then
    echo "todo.yaml not found"
    exit 1
fi

mkdir -p "$SCRIPTS_DIR"

if [[ ! -f "$SETUP_FILE" ]]; then
    printf '#!/bin/bash\nset -euo pipefail\n\nSCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"\n' > "$SETUP_FILE"
    chmod +x "$SETUP_FILE"
fi

keys=()
while IFS=: read -r key value; do
    [[ -z "$key" ]] && continue
    key="$(echo "$key" | xargs)"
    value="$(echo "$value" | xargs)"

    keys+=("$key")

    script_path="$SCRIPTS_DIR/${key}.sh"
    if [[ -f "$script_path" ]]; then
        continue
    fi

    printf '#!/bin/bash\n# TODO: %s\n' "$value" > "$script_path"
    chmod +x "$script_path"
    echo "Created $script_path"
done < "$TODO_FILE"

# Rebuild setup.sh to call all scripts in todo.yaml order
{
    printf '#!/bin/bash\nset -euo pipefail\n\nSCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"\n\n'
    for key in "${keys[@]}"; do
        printf '"$SCRIPT_DIR/scripts/%s.sh"\n' "$key"
    done
} > "$SETUP_FILE"
chmod +x "$SETUP_FILE"
echo "Updated $SETUP_FILE"
