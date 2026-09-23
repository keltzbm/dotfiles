#!/bin/bash
set -e

# Run from wherever the repo lives (~/atelier/github/dotfiles on Mac, ~/GitHub/dotfiles on Linux)
DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DOTFILES"
git pull

OS="$(uname)"
ALACRITTY_SRC="$(dirname "$DOTFILES")/alacritty"

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
brew install stow zsh tmux neovim starship pyenv eza bat fd ripgrep fzf zoxide deno git uv gh

# Rust toolchain + latest tagged Alacritty source (used by both platforms' from-source builds)
ensure_rust() {
  if ! command -v cargo &> /dev/null; then
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source "$HOME/.cargo/env"
  fi
}
checkout_alacritty() {
  [[ -d "$ALACRITTY_SRC" ]] || git clone https://github.com/alacritty/alacritty.git "$ALACRITTY_SRC"
  cd "$ALACRITTY_SRC"
  git fetch --tags
  git checkout "$(git describe --tags "$(git rev-list --tags --max-count=1)")"
}

if [[ "$OS" == "Darwin" ]]; then
  brew install --cask font-jetbrains-mono-nerd-font

  # Homebrew disabled the alacritty cask (Gatekeeper, 2026-09-01) — build the .app from source
  if [[ ! -d /Applications/Alacritty.app ]]; then
    echo "Building Alacritty from source..."
    ensure_rust
    checkout_alacritty
    make app
    cp -R target/release/osx/Alacritty.app /Applications/
    cd "$DOTFILES"
  fi

  # The cask used to put `alacritty` on PATH; do it ourselves (~/.local/bin is on PATH via .zshrc)
  mkdir -p "$HOME/.local/bin"
  ln -sf /Applications/Alacritty.app/Contents/MacOS/alacritty "$HOME/.local/bin/alacritty"

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
    ensure_rust
    checkout_alacritty
    PKG_CONFIG_PATH="/usr/lib/$(uname -m)-linux-gnu/pkgconfig" cargo build --release
    sudo ln -sf "$ALACRITTY_SRC/target/release/alacritty" /usr/local/bin/alacritty
    sudo cp extra/logo/alacritty-term.svg /usr/share/pixmaps/Alacritty.svg
    sudo desktop-file-install extra/linux/Alacritty.desktop
    sudo update-desktop-database
    cd "$DOTFILES"
  fi
fi

echo "Stowing dotfiles..."
for pkg in nvim alacritty starship tmux zsh git; do
  stow --target="$HOME" "$pkg"
done

echo "Dotfiles synced!"
