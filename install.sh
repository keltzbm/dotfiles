#!/bin/bash
set -e

cd ~/GitHub/dotfiles
git pull

OS="$(uname)"

# Install Homebrew if missing
if ! command -v brew &> /dev/null; then
  echo "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  if [[ "$OS" == "Linux" ]]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
  else
    eval "$(/opt/homebrew/bin/brew shellenv)"
  fi
fi

echo "Installing Homebrew packages..."
brew install stow zsh tmux neovim starship pyenv eza bat fd ripgrep fzf zoxide deno git

if [[ "$OS" == "Darwin" ]]; then
  brew install --cask alacritty font-jetbrains-mono-nerd-font

elif [[ "$OS" == "Linux" ]]; then
  echo "Installing Linux build dependencies..."
  sudo apt update
  sudo apt install -y \
    build-essential cmake pkg-config \
    libfontconfig1-dev libfreetype6-dev \
    libxcb-xfixes0-dev libxkbcommon-dev \
    tk-dev tcl-dev gfortran libopenblas-dev liblapack-dev \
    libssl-dev zlib1g-dev libbz2-dev libreadline-dev \
    libsqlite3-dev libncursesw5-dev xz-utils \
    libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev

  # Alacritty isn't distributed via Homebrew on Linux — build from source
  if ! command -v alacritty &> /dev/null; then
    echo "Building Alacritty from source..."
    if ! command -v cargo &> /dev/null; then
      curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
      source "$HOME/.cargo/env"
    fi
    [[ -d ~/GitHub/alacritty ]] || git clone https://github.com/alacritty/alacritty.git ~/GitHub/alacritty
    cd ~/GitHub/alacritty
    git fetch --tags
    git checkout "$(git describe --tags "$(git rev-list --tags --max-count=1)")"
    PKG_CONFIG_PATH=/usr/lib/x86_64-linux-gnu/pkgconfig cargo build --release
    sudo ln -sf ~/GitHub/alacritty/target/release/alacritty /usr/local/bin/alacritty
    sudo cp extra/logo/alacritty-term.svg /usr/share/pixmaps/Alacritty.svg
    sudo desktop-file-install extra/linux/Alacritty.desktop
    sudo update-desktop-database
    cd ~/GitHub/dotfiles
  fi
fi

echo "Stowing dotfiles..."
for pkg in nvim alacritty starship tmux zsh git; do
  stow --target="$HOME" "$pkg"
done

echo "Dotfiles synced!"
