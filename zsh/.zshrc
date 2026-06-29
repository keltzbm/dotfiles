# ── Homebrew ───────────────────────────────────────────────────
if [ -f /opt/homebrew/bin/brew ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -f /home/linuxbrew/.linuxbrew/bin/brew ]; then
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi

# ── Path ───────────────────────────────────────────────────────
export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/.local/share/nvim/mason/bin:$PATH"

# ── pyenv ──────────────────────────────────────────────────────
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"

# ── Prompt ─────────────────────────────────────────────────────
export PROMPT_EOL_MARK=""
eval "$(starship init zsh)"

# ── Completions ────────────────────────────────────────────────
autoload -Uz compinit
compinit

# ── History ────────────────────────────────────────────────────
HISTSIZE=10000
SAVEHIST=10000
HISTFILE=~/.zsh_history
setopt HIST_IGNORE_DUPS
setopt SHARE_HISTORY

# ── Aliases ────────────────────────────────────────────────────
alias vi="nvim"
alias vim="nvim"
alias ls="eza --icons --group-directories-first"
alias ll="eza --icons --group-directories-first --long"
alias la="eza --icons --group-directories-first --long --all"
alias lt="eza --icons --tree --level=2"
alias lta="eza --icons --tree --level=3"
alias plotenv="source ~/.plotenv/bin/activate"

# ── Misc ───────────────────────────────────────────────────────
export BROWSER="explorer.exe"
cd ~
