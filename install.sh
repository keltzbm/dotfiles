#!/bin/bash

cd ~/GitHub/dotfiles

# Pull latest changes
git pull

# Stow everything
stow --target=$HOME nvim
stow --target=$HOME alacritty
stow --target=$HOME starship
stow --target=$HOME tmux
stow --target=$HOME zsh
stow --target=$HOME git

echo "Dotfiles synced!"
