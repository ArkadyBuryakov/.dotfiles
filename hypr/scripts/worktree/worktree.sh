# Source this file to get the worktree function with automatic cd support
# Add to your .bashrc or .zshrc:
#   source /path/to/worktree.sh

# Get script directory (works in both bash and zsh)
if [[ -n "${ZSH_VERSION:-}" ]]; then
    WORKTREE_SCRIPT="${WORKTREE_SCRIPT:-${0:A:h}/worktree}"
else
    WORKTREE_SCRIPT="${WORKTREE_SCRIPT:-$(dirname "${BASH_SOURCE[0]}")/worktree}"
fi

worktree() {
    local output
    output=$("$WORKTREE_SCRIPT" "$@")
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

# Load completions based on shell
if [[ -n "${ZSH_VERSION:-}" ]]; then
    # Zsh - load completion and register with compdef
    if [[ -f "${WORKTREE_SCRIPT}.completion.zsh" ]]; then
        source "${WORKTREE_SCRIPT}.completion.zsh"
        compdef _worktree worktree
    fi
elif [[ -n "${BASH_VERSION:-}" ]]; then
    # Bash
    [[ -f "${WORKTREE_SCRIPT}.completion.bash" ]] && source "${WORKTREE_SCRIPT}.completion.bash"
fi
