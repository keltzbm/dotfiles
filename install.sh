#!/bin/bash
set -e

# Run from wherever the repo lives (~/atelier/github/dotfiles on every machine)
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
brew install stow zsh tmux neovim starship eza bat fd ripgrep fzf zoxide deno git git-lfs uv gh stylua

# Python comes from uv: `python` and `python3` in ~/.local/bin (on PATH via .zshrc).
# Projects pin their own version in .python-version; this is the default everywhere else.
echo "Installing Python..."
uv python install 3.14 --default --preview-features python-install-default

# Rust toolchain + latest tagged Alacritty source (used by both platforms' from-source builds)
ensure_rust() {
  if ! command -v cargo &> /dev/null; then
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    # shellcheck source=/dev/null
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
  echo "Installing apt packages..."
  sudo apt update
  # zip: gitzip. gfortran + BLAS/LAPACK: packages that compile against them (scipy).
  sudo apt install -y build-essential pkg-config zip gfortran libopenblas-dev liblapack-dev

  # Alacritty isn't distributed via Homebrew on Linux — build from source.
  # Skipped under WSL, where Alacritty runs on the Windows side.
  if [[ -z "$WSL_DISTRO_NAME" ]] && ! command -v alacritty &> /dev/null; then
    echo "Building Alacritty from source..."
    sudo apt install -y cmake libfontconfig1-dev libfreetype-dev libxcb-xfixes0-dev libxkbcommon-dev
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

# tmux plugin manager + the plugins .tmux.conf lists (skips ones already there)
echo "Installing tmux plugins..."
[[ -d "$HOME/.tmux/plugins/tpm" ]] || git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
"$HOME/.tmux/plugins/tpm/bin/install_plugins" > /dev/null

echo "Dotfiles synced!"
