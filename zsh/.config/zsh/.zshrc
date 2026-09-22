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
# pyenv
export PYENV_ROOT="$HOME/.pyenv"
path=("$PYENV_ROOT/bin" $path)
if command -v pyenv >/dev/null; then
  eval "$(pyenv init - zsh)"
fi

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
# Create a new Python project with a venv, stub files, and git
pyproject() {
  [[ -z "$1" ]] && { echo "usage: pyproject <name>"; return 1; }
  mkdir -p "$1" && cd "$1" || return 1
  python3 -m venv .venv
  source .venv/bin/activate
  touch main.py requirements.txt
  printf '%s\n' ".venv/" "__pycache__/" "*.pyc" > .gitignore
  git init
  echo "Python project $1 created!"
}

# Zip a repo's last commit (HEAD only; no .git, no uncommitted changes)
gitzip() {
  local repo=${1:-.}
  local root name
  root=$(git -C "$repo" rev-parse --show-toplevel) || return 1
  name=${root:t}
  git -C "$root" archive --format=zip --prefix="$name/" -o "$PWD/$name.zip" HEAD \
    && echo "→ $PWD/$name.zip"
}

# Zip a repo's working tree (tracked + untracked files, minus .gitignore'd)
zipgit() {
  local dir="${1:-.}"
  local abs_path repo_name parent_dir out_zip
  abs_path="$(cd "$dir" && pwd)" || return 1
  repo_name="${abs_path:t}"
  parent_dir="${abs_path:h}"
  out_zip="${2:-$repo_name.zip}"

  if ! git -C "$abs_path" rev-parse --git-dir >/dev/null 2>&1; then
    echo "zipgit: '$dir' is not a git repository"
    return 1
  fi

  [[ "$out_zip" != /* ]] && out_zip="$PWD/$out_zip"
  rm -f "$out_zip"

  (
    cd "$parent_dir" || return 1
    git -C "$repo_name" ls-files --cached --others --exclude-standard \
      | sed "s|^|$repo_name/|" \
      | zip "$out_zip" -@ >/dev/null
  )

  echo "→ $out_zip"
}

# ─────────────────────────────────────────────────────────────
# Startup
# ─────────────────────────────────────────────────────────────
cd ~

# Prompt (keep last)
eval "$(starship init zsh)"
