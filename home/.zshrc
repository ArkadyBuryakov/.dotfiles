# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
# source ~/.zshrc_title

if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

ZLE_RPROMPT_INDENT=0

# Set the directory for plugin manager
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"

# Download Zinit, if it's not installed yet
if [ ! -d "$ZINIT_HOME" ]; then
  mkdir -p "$(dirname $ZINIT_HOME)"
  git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
fi

# Load zinit
source "${ZINIT_HOME}/zinit.zsh"

# Add in Powerlevel10k
zinit ice depth=1; zinit light romkatv/powerlevel10k

# Add in zsh plugins
zinit light zsh-users/zsh-syntax-highlighting
zinit light zsh-users/zsh-completions
zinit light zsh-users/zsh-autosuggestions
zinit light Aloxaf/fzf-tab
zinit light hsaunders1904/pyautoenv
#_zsh_pyautoenv_activate

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# Load completions
autoload -U compinit && compinit
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
zstyle ':completion:*' menu no
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls --color $realpath'
zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'ls --color $realpath'
# ZSH options
setopt autocd
unsetopt beep
bindkey -v

# History
HISTSIZE=5000
HISTFILE=~/.zsh_history
SAVEHIST=$HISTSIZE
HISTDUP=erase
setopt appendhistory
setopt sharehistory
setopt hist_ignore_space
setopt hist_ignore_all_dups
setopt hist_save_no_dups
setopt hist_ignore_dups
setopt hist_find_no_dups

# Keybindings
bindkey '^f' autosuggest-accept
bindkey '\e[H'  beginning-of-line
bindkey '\e[F'  end-of-line
bindkey '\e[3~' delete-char
bindkey -v '^?' backward-delete-char

function w_clear() {clear; zle redisplay}
zle -N w_clear
bindkey '^[l'   w_clear

bindkey '^[k' history-search-backward
bindkey '^[j' history-search-forward
bindkey '^[[A' history-search-backward
bindkey '^[[B' history-search-forward

# User-defined env variables
export XDG_PICTURES_DIR='/home/arkady/Pictures/'
export HYPRSHOT_DIR='/home/arkady/Pictures/Screenshots/'

# Shell integrations
eval "$(fzf --zsh)"
if [[ "$CLAUDECODE" != "1" ]]; then
    eval "$(zoxide init --cmd cd zsh)"
fi

# Aliases
alias ls='ls --color'

# alias sudo="sudo -Es"
alias q="exit"
alias btw="echo '\nBTW, I am using Arch\n' && fastfetch"
interactive_man () {
  w3mman $@ 2> /dev/null
}
alias man="interactive_man"
alias kill-orphans="pacman -Qtdq | sudo pacman -Rns -"

alias bt="bluetuith"
alias nm="nmtui"

alias dcu="docker compose up --build"
alias dcud="docker compose up --build -d"
alias dcd="docker compose down -t 0"
alias dcw="docker compose watch"
alias sbu="supabase start"
alias sbd="supabase stop"
alias sbs="supabase status"
alias hyprlock_restore="hyprctl --instance 0 'keyword misc:allow_session_lock_restore 1' && hyprctl --instance 0 'dispatch exec hyprlock'"

alias vpython="venv/bin/python"
alias vpip="venv/bin/pip"

# Path shortcuts
cd_concat () {
  cd "$1/$2"
}

# Nvim project shortcuts
nav_to_vim() {
  if [ $# -eq 0 ]; then
    nvim .
    return
  fi
  if [ -f "$1" ]; then
    nvim "$1"
    return
  fi
  if cd "$1" 2>/dev/null; then
    nvim .
  else
    echo "nav_to_vim: cannot access '$1': No such file or directory" >&2
    return 1
  fi
}
alias nv="nav_to_vim"

source ~/.zshrc_paths

# NPM
export npm_config_prefix="$HOME/.local"

# pnpm
export PNPM_HOME="/home/arkady/.local/share/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end

# Kity ssh-fix
if [ "$TERM" = "xterm-kitty" ]; then
  alias ssh='kitten ssh'
fi

# Pyenv
export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init - zsh)"

# AsyncAPI CLI Autocomplete

ASYNCAPI_AC_ZSH_SETUP_PATH=/home/arkady/.cache/@asyncapi/cli/autocomplete/zsh_setup && test -f $ASYNCAPI_AC_ZSH_SETUP_PATH && source $ASYNCAPI_AC_ZSH_SETUP_PATH; # asyncapi autocomplete setup

# bun completions
[ -s "/home/arkady/.bun/_bun" ] && source "/home/arkady/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# Custom tools
source ~/.config/hypr/scripts/worktree/worktree.sh
source ~/.config/hypr/scripts/worktree/worktree-tui.sh

alias wt="worktree"
alias wtc="worktree create"
alias wto="worktree open"
alias wtco="worktree checkout"
alias wtd="worktree delete"
alias wtt="worktree-tui"
