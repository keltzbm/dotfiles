# ~/.config/zsh/.zshrc

# ─────────────────────────────────────────────────────────────
# Homebrew
# ─────────────────────────────────────────────────────────────
if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x /home/linuxbrew/.linuxbrew/bin/brew ]]; then
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi

# ─────────────────────────────────────────────────────────────
# PATH
# ─────────────────────────────────────────────────────────────
typeset -U path PATH fpath FPATH   # drop duplicate entries (e.g. in nested shells)

path=(
  "$HOME/.local/bin"
  "$HOME/.local/share/nvim/mason/bin"
  $path
)

# ─────────────────────────────────────────────────────────────
# Platform-specific settings
# ─────────────────────────────────────────────────────────────
case $OSTYPE in
  darwin*)
    # Keep the Mac awake (display, idle, and system sleep on AC)
    alias awake='caffeinate -dis'
    ;;
  linux*)
    # Ensure system pkg-config is visible alongside Homebrew's (fixes builds
    # that need apt-installed dev libraries, e.g. fontconfig)
    typeset -TUx PKG_CONFIG_PATH pkg_config_path
    pkg_config_path=("/usr/lib/$CPUTYPE-linux-gnu/pkgconfig" $pkg_config_path)

    if [[ -n "$WSL_DISTRO_NAME" ]]; then
      # Open links in the Windows browser
      export BROWSER="explorer.exe"
      # Windows starts WSL in a Windows folder; begin at home instead.
      # (Scoped to /mnt/c so tmux splits keep their current folder.)
      [[ $PWD == /mnt/c/* ]] && cd ~
    fi
    ;;
esac

# ─────────────────────────────────────────────────────────────
# Tools
# ─────────────────────────────────────────────────────────────
# Silence pip's "new release available" nag on every install
export PIP_DISABLE_PIP_VERSION_CHECK=1

# eza: show mount points as bold blue instead of underlined
export EZA_COLORS="mp=1;34"

# ─────────────────────────────────────────────────────────────
# History
# ─────────────────────────────────────────────────────────────
HISTFILE="$HOME/.zsh_history"
HISTSIZE=10000
SAVEHIST=10000
setopt HIST_IGNORE_DUPS
setopt SHARE_HISTORY

# ─────────────────────────────────────────────────────────────
# Shell behavior
# ─────────────────────────────────────────────────────────────
export PROMPT_EOL_MARK=""   # hide the % marker after output without a newline
unset zle_bracketed_paste
setopt INTERACTIVE_COMMENTS # allow # comments at the prompt
bindkey -e                  # emacs keys at the prompt (EDITOR=nvim would pick vi)

# ─────────────────────────────────────────────────────────────
# Completion
# ─────────────────────────────────────────────────────────────
# Homebrew tools install their completions here (gh, uv, eza, rg, ...)
[[ -n "$HOMEBREW_PREFIX" ]] && fpath=("$HOMEBREW_PREFIX/share/zsh/site-functions" $fpath)

# Cache lives outside $ZDOTDIR so it never lands in the repo; -i skips any
# directory compaudit calls insecure instead of stopping startup to ask
autoload -Uz compinit
mkdir -p "${XDG_CACHE_HOME:-$HOME/.cache}/zsh"
compinit -i -d "${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompdump"

# ─────────────────────────────────────────────────────────────
# Aliases
# ─────────────────────────────────────────────────────────────
# eza
if (( $+commands[eza] )); then
  alias ls="eza --icons --group-directories-first"
  alias ll="eza --icons --group-directories-first --long"
  alias la="eza --icons --group-directories-first --long --all"
  alias lt="eza --icons --tree --level=2"
  alias lta="eza --icons --tree --level=3"
fi

# Editor
alias vi="nvim"
alias vim="nvim"

# ─────────────────────────────────────────────────────────────
# Functions
# ─────────────────────────────────────────────────────────────
# Scaffold a new Python repo (src layout, uv, ruff, pytest, pre-commit, CI)
source "${ZDOTDIR:-$HOME/.config/zsh}/functions/newrepo.zsh"

# Activate/switch/deactivate the nearest .venv without stacking activations
source "${ZDOTDIR:-$HOME/.config/zsh}/functions/venv.zsh"

# Zip a repo for sharing: working tree + .git by default (--no-git, --head)
source "${ZDOTDIR:-$HOME/.config/zsh}/functions/gitzip.zsh"

# ─────────────────────────────────────────────────────────────
# Integrations (after compinit)
# ─────────────────────────────────────────────────────────────
# fzf: Ctrl-R searches history, Ctrl-T picks a file, Alt-C cds into a folder.
# Terminal only: its script errors in `zsh -i -c` runs with no terminal
# (editors and tools that read your shell environment do this)
[[ -t 0 ]] && (( $+commands[fzf] )) && source <(fzf --zsh 2>/dev/null)

# zoxide: `z <part of a path>` jumps to a folder you've visited; `zi` picks one
(( $+commands[zoxide] )) && eval "$(zoxide init zsh)"

# Prompt (keep last)
(( $+commands[starship] )) && eval "$(starship init zsh)"
