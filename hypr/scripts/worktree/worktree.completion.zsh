#compdef worktree

# Zsh completion for worktree CLI

_worktree_branches() {
    local branches
    branches=(${(f)"$(git branch --format='%(refname:short)' 2>/dev/null)"})
    # Add remote branches excluding local duplicates
    local remote_branches
    remote_branches=(${(f)"$(git branch -r --format='%(refname:short)' 2>/dev/null | sed 's|^[^/]*/||' | sort -u)"})
    for rb in $remote_branches; do
        if (( ! ${branches[(I)$rb]} )); then
            branches+=("$rb")
        fi
    done
    _describe -t branches 'branch' branches
}

_worktree_names() {
    local worktrees
    worktrees=(${(f)"$(git worktree list --porcelain 2>/dev/null | grep '^worktree ' | sed 's|^worktree ||' | xargs -I{} basename {})"})
    _describe -t worktrees 'worktree' worktrees
}

_worktree_commands() {
    local commands=(
        'create:Create or open worktree for a branch'
        'open:Open worktree with a command'
    )
    _describe -t commands 'command' commands
}

_worktree() {
    local curcontext="$curcontext" state line
    typeset -A opt_args

    _arguments -C \
        '1:command:->command' \
        '*::arg:->args'

    case $state in
        command)
            _worktree_commands
            # Also suggest any command as shortcut
            _command_names -e
            ;;
        args)
            case $line[1] in
                create)
                    _arguments \
                        '1:branch:_worktree_branches'
                    ;;
                open)
                    _arguments \
                        '1:worktree:_worktree_names' \
                        '-o[Command to run]:command:_command_names -e' \
                        '-p[Path within worktree]:path:_files'
                    ;;
                *)
                    # Shortcut mode: worktree [CMD] [NAME] [-p PATH]
                    _arguments \
                        '1:worktree:_worktree_names' \
                        '-p[Path within worktree]:path:_files'
                    ;;
            esac
            ;;
    esac
}
