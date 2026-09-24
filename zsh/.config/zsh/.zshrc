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
typeset -U path PATH   # drop duplicate entries (e.g. in nested shells)

path=(
  "$HOME/.local/bin"
  "$HOME/.local/share/nvim/mason/bin"
  $path
)

# ─────────────────────────────────────────────────────────────
# Platform-specific settings
# ─────────────────────────────────────────────────────────────
case "$(uname)" in
  Darwin)
    # Keep the Mac awake (display, idle, and system sleep on AC)
    alias awake='caffeinate -dis'
    ;;
  Linux)
    # Ensure system pkg-config is visible alongside Homebrew's (fixes builds
    # that need apt-installed dev libraries, e.g. fontconfig, tcl/tk)
    export PKG_CONFIG_PATH="/usr/lib/x86_64-linux-gnu/pkgconfig:$PKG_CONFIG_PATH"

    # WSL only: open links in the Windows browser
    if [[ -n "$WSL_DISTRO_NAME" ]]; then
      export BROWSER="explorer.exe"
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

# ─────────────────────────────────────────────────────────────
# Aliases
# ─────────────────────────────────────────────────────────────
# eza
alias ls="eza --icons --group-directories-first"
alias ll="eza --icons --group-directories-first --long"
alias la="eza --icons --group-directories-first --long --all"
alias lt="eza --icons --tree --level=2"
alias lta="eza --icons --tree --level=3"

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
# Startup
# ─────────────────────────────────────────────────────────────
cd ~

# Prompt (keep last)
eval "$(starship init zsh)"
