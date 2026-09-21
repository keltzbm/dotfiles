if [ -f /opt/homebrew/bin/brew ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -f /home/linuxbrew/.linuxbrew/bin/brew ]; then
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi
cd ~

export PATH="$HOME/.local/share/nvim/mason/bin:$PATH"
# Path
export PATH="$HOME/.local/bin:$PATH"


# pyenv
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"

export PROMPT_EOL_MARK=""

eval "$(starship init zsh)"

# eza aliases
alias ls="eza --icons --group-directories-first"
alias ll="eza --icons --group-directories-first --long"
alias la="eza --icons --group-directories-first --long --all"
alias lt="eza --icons --tree --level=2"
alias lta="eza --icons --tree --level=3"

# vi and vim mapped to nvim
alias vi="nvim"

HISTSIZE=10000
SAVEHIST=10000
HISTFILE=~/.zsh_history
setopt HIST_IGNORE_DUPS
setopt SHARE_HISTORY
export BROWSER="explorer.exe"


# Create a new Python project
pyproject() {
    mkdir -p "$1"
    cd "$1"
    python3 -m venv .venv
    source .venv/bin/activate
    touch main.py
    touch requirements.txt
    echo ".venv/" > .gitignore
    echo "__pycache__/" >> .gitignore
    echo "*.pyc" >> .gitignore
    git init
    echo "Python project $1 created!"
}

unset zle_bracketed_paste

# Ensure system pkg-config is visible alongside Homebrew's (fixes builds
# that need apt-installed dev libraries, e.g. fontconfig, tcl/tk)
if [[ "$(uname)" == "Linux" ]]; then
  export PKG_CONFIG_PATH="/usr/lib/x86_64-linux-gnu/pkgconfig:$PKG_CONFIG_PATH"
fi

# Silence pip's "new release available" nag on every install
export PIP_DISABLE_PIP_VERSION_CHECK=1

# Zip a git repo's committed contents (no .git, respects .gitignore)
gitzip() {
  local repo=${1:-.}
  local root name
  root=$(git -C "$repo" rev-parse --show-toplevel) || return 1
  name=${root:t}
  git -C "$root" archive --format=zip --prefix="$name/" -o "$PWD/$name.zip" HEAD \
    && echo "→ $PWD/$name.zip"
}
