#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

"$SCRIPT_DIR/scripts/apply_config.sh"
"$SCRIPT_DIR/scripts/yazi.sh"
"$SCRIPT_DIR/scripts/add_repos.sh"
"$SCRIPT_DIR/scripts/dependencies.sh"
"$SCRIPT_DIR/scripts/howdy_setup.sh"
"$SCRIPT_DIR/scripts/antivirus.sh"
"$SCRIPT_DIR/scripts/apps.sh"
"$SCRIPT_DIR/scripts/local_bin.sh"
