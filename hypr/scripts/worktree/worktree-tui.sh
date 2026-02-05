# Source this file to get the worktree-tui function with automatic cd support
# Add to your .bashrc or .zshrc:
#   source /path/to/worktree-tui.sh

# Get script directory (works in both bash and zsh)
if [[ -n "${ZSH_VERSION:-}" ]]; then
    WORKTREE_TUI_SCRIPT="${WORKTREE_TUI_SCRIPT:-${0:A:h}/worktree-tui}"
else
    WORKTREE_TUI_SCRIPT="${WORKTREE_TUI_SCRIPT:-$(dirname "${BASH_SOURCE[0]}")/worktree-tui}"
fi

worktree-tui() {
    local output
    output=$("$WORKTREE_TUI_SCRIPT" "$@")
    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        # Check if output looks like a command to eval (starts with "cd ")
        if [[ "$output" == cd\ * ]]; then
            eval "$output"
        else
            echo "$output"
        fi
    else
        echo "$output"
        return $exit_code
    fi
}
