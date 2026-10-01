# dotup — upgrade what the dotfiles installed (Homebrew, uv's Python, Neovim
# and tmux plugins, rustup). Runs update.sh from the repo this file lives in;
# `dotup --schedule` makes it weekly, `dotup --unschedule` stops that.

# This file is a Stow link into the repo: follow it to find update.sh
typeset -g _dotup_repo=${${(%):-%x}:A:h:h:h:h:h}

dotup() {
  if [[ ! -x $_dotup_repo/update.sh ]]; then
    print -u2 "dotup: no update.sh in $_dotup_repo"
    return 1
  fi
  $_dotup_repo/update.sh "$@"
}
