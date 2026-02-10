# Bash completion for worktree CLI

_worktree_branches() {
    local branches
    # Local branches first
    branches=$(git branch --format='%(refname:short)' 2>/dev/null)
    # Remote branches excluding local duplicates
    local remote_branches
    remote_branches=$(git branch -r --format='%(refname:short)' 2>/dev/null | sed 's|^[^/]*/||' | sort -u)

    for rb in $remote_branches; do
        if ! echo "$branches" | grep -qx "$rb"; then
            branches="$branches"$'\n'"$rb"
        fi
    done
    echo "$branches"
}

_worktree_names() {
    # Only include worktrees inside a "worktrees" folder (exclude main repo)
    git worktree list --porcelain 2>/dev/null | grep '^worktree ' | sed 's|^worktree ||' | while read -r p; do
        if [[ "$(basename "$(dirname "$p")")" == "worktrees" ]]; then
            basename "$p"
        fi
    done
}

_worktree() {
    local cur prev words cword
    _init_completion || return

    local commands="create open delete checkout claude"

    case $cword in
        1)
            # First argument: command or shortcut
            COMPREPLY=($(compgen -W "$commands" -- "$cur"))
            # Also add common commands as shortcuts
            COMPREPLY+=($(compgen -c -- "$cur"))
            ;;
        2)
            case "${words[1]}" in
                create)
                    local branches
                    branches=$(_worktree_branches)
                    COMPREPLY=($(compgen -W "$branches" -- "$cur"))
                    ;;
                open|delete|checkout)
                    local worktrees
                    worktrees=$(_worktree_names)
                    COMPREPLY=($(compgen -W "$worktrees" -- "$cur"))
                    ;;
                claude)
                    COMPREPLY=($(compgen -W "copy-session" -- "$cur"))
                    ;;
                *)
                    # Shortcut mode: complete worktree names
                    local worktrees
                    worktrees=$(_worktree_names)
                    COMPREPLY=($(compgen -W "$worktrees" -- "$cur"))
                    ;;
            esac
            ;;
        3)
            if [[ "${words[1]}" == "claude" && "${words[2]}" == "copy-session" ]]; then
                local sessions
                sessions=$(worktree --complete claude 2>/dev/null | cut -f1)
                COMPREPLY=($(compgen -W "$sessions" -- "$cur"))
            fi
            ;;
        *)
            case "$prev" in
                -o)
                    COMPREPLY=($(compgen -c -- "$cur"))
                    ;;
                -p)
                    _filedir
                    ;;
                *)
                    COMPREPLY=($(compgen -W "-o -p" -- "$cur"))
                    ;;
            esac
            ;;
    esac
}

complete -F _worktree worktree
