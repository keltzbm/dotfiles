# ~/.zshenv — the first file zsh reads. Once ZDOTDIR is exported, shells
# started from this one (tmux panes, nested zsh) look for .zshenv in ZDOTDIR
# instead, so everything here is exported for them to inherit.

export ZDOTDIR="$HOME/.config/zsh"

# Programs that open an editor for you (git commit, crontab -e, ...) use these.
# .zshrc runs `bindkey -e` so this doesn't also switch the prompt to vi mode.
export EDITOR=nvim
export VISUAL=nvim

# Ubuntu's /etc/zsh/zshrc runs compinit before Homebrew is on the path and
# writes its cache into $ZDOTDIR (this repo). .zshrc runs it properly instead.
export skip_global_compinit=1
