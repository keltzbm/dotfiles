# Path
export PATH="$HOME/.local/bin:$PATH"

# pyenv
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"

export PROMPT_EOL_MARK=""

eval "$(starship init zsh)"

# autoload -U colors && colors
# PROMPT='%{$fg[blue]%}%~%{$reset_color%}%{$fg[cyan]%}${vcs_info_msg_0_}%{$reset_color%} : '
# 
# autoload -Uz vcs_info
# precmd() { vcs_info }
# zstyle ':vcs_info:git:*' formats ' %{$fg[teal]%} %b%{$reset_color%}'

# eza aliases
alias ls="eza --icons --group-directories-first"
alias ll="eza --icons --group-directories-first --long"
alias la="eza --icons --group-directories-first --long --all"
alias lt="eza --icons --tree --level=2"
alias lta="eza --icons --tree --level=3"
