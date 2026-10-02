#!/bin/bash
# update.sh — upgrade what install.sh installed.
#
#   ./update.sh               run every step now
#   ./update.sh --schedule    run it every Sunday at 03:30 (launchd on macOS,
#                             a systemd user timer on Linux)
#   ./update.sh --unschedule  stop the weekly run
#
# Steps, in order: the dotfiles' own links (each package restowed, so a file a
# pull added is linked), Homebrew (update, upgrade, the Brewfile, cleanup), uv's
# default Python, Neovim's plugins, tmux's plugins, rustup where it's
# installed. A step whose tool is missing is skipped; a step that fails is
# logged and the rest still run. Nothing here needs sudo, so apt stays yours.
#
# Each step leaves a line in ~/.local/state/dotfiles/update.log with its UTC
# time. Steps that failed are listed in update.failed beside it until a run
# passes; .zshrc prints that file's line at the next shell start.
#
# Neovim's plugin update rewrites lazy-lock.json in this repo. It isn't
# committed here: commit it when you want the other machines to follow.

set -u

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OS="${DOTFILES_OS:-$(uname)}"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles"
LOG="$STATE/update.log"
FAILED="$STATE/update.failed"
LABEL="dotfiles.update"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
UNITS="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"

have() { command -v "$1" > /dev/null 2>&1; }
now() { date -u +%Y-%m-%dT%H:%M:%SZ; }

schedule() {
  mkdir -p "$STATE"
  if [[ "$OS" == "Darwin" ]]; then
    mkdir -p "$(dirname "$PLIST")"
    cat > "$PLIST" << PLIST_END
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key>
  <array><string>/bin/bash</string><string>$DOTFILES/update.sh</string></array>
  <key>StartCalendarInterval</key>
  <dict><key>Weekday</key><integer>0</integer><key>Hour</key><integer>3</integer><key>Minute</key><integer>30</integer></dict>
  <key>EnvironmentVariables</key>
  <dict><key>PATH</key><string>/opt/homebrew/bin:/opt/homebrew/sbin:$HOME/.local/bin:$HOME/.cargo/bin:/usr/bin:/bin:/usr/sbin:/sbin</string></dict>
  <key>StandardOutPath</key><string>$STATE/update.out</string>
  <key>StandardErrorPath</key><string>$STATE/update.out</string>
</dict>
</plist>
PLIST_END
    launchctl bootout "gui/$(id -u)/$LABEL" 2> /dev/null
    launchctl bootstrap "gui/$(id -u)" "$PLIST" || { echo "update.sh: launchctl couldn't load $PLIST (see above)." >&2; return 1; }
    echo "Scheduled: every Sunday at 03:30 ($PLIST). launchd runs a missed job at the next wake."
  else
    mkdir -p "$UNITS"
    cat > "$UNITS/dotfiles-update.service" << UNIT_END
[Unit]
Description=Upgrade what the dotfiles installed

[Service]
Type=oneshot
ExecStart=/bin/bash $DOTFILES/update.sh
UNIT_END
    cat > "$UNITS/dotfiles-update.timer" << UNIT_END
[Unit]
Description=Weekly dotfiles upgrade

[Timer]
OnCalendar=Sun 03:30
Persistent=true

[Install]
WantedBy=timers.target
UNIT_END
    if have systemctl && systemctl --user daemon-reload 2> /dev/null; then
      systemctl --user enable --now dotfiles-update.timer || { echo "update.sh: systemctl couldn't start the timer (see above)." >&2; return 1; }
      echo "Scheduled: every Sunday at 03:30 (dotfiles-update.timer). A missed run happens at the next start."
    else
      echo "Wrote the units to $UNITS, but there is no systemd user session here (WSL without systemd?). Run ./update.sh by hand, or enable systemd and run this again."
    fi
  fi
}

unschedule() {
  if [[ "$OS" == "Darwin" ]]; then
    launchctl bootout "gui/$(id -u)/$LABEL" 2> /dev/null
    rm -f "$PLIST"
  else
    have systemctl && systemctl --user disable --now dotfiles-update.timer 2> /dev/null
    rm -f "$UNITS/dotfiles-update.service" "$UNITS/dotfiles-update.timer"
  fi
  echo "Unscheduled: the weekly run is off."
}

case "${1:-}" in
  --schedule) schedule; exit $? ;;
  --unschedule) unschedule; exit 0 ;;
  -h | --help) sed -n '2,19s/^# \{0,1\}//p' "${BASH_SOURCE[0]}"; exit 0 ;;
  "") ;;
  *) echo "update.sh: unknown option $1 (see --help)" >&2; exit 2 ;;
esac

mkdir -p "$STATE"
failures=()

# step NAME CMD...: run CMD, say what happened, log it, and carry on either way
step() {
  local name="$1"; shift
  echo "→ $name"
  if "$@"; then
    echo "$(now) $name ok" >> "$LOG"
  else
    local rc=$?
    echo "  failed (exit $rc)"
    echo "$(now) $name failed (exit $rc)" >> "$LOG"
    failures+=("$name")
  fi
}

# Stow links a package's files one by one where its folder already exists in ~,
# so a file a pull added isn't linked until its package is restowed.
restow() {
  local pkg
  for pkg in nvim alacritty starship tmux zsh git gh; do
    [[ -d "$DOTFILES/$pkg" ]] || continue
    (cd "$DOTFILES" && stow --target="$HOME" --restow "$pkg") || return 1
  done
}

if have stow; then
  step "stow" restow
fi
if have brew; then
  step "brew update" brew update
  step "brew upgrade" brew upgrade
  step "brew bundle" brew bundle --file="$DOTFILES/Brewfile"
  step "brew cleanup" brew cleanup
fi
if have uv; then
  step "uv python" uv python install 3.14 --default --preview-features python-install-default
fi
if have nvim; then
  step "nvim plugins" nvim --headless "+Lazy! update" +qa
fi
if [[ -x "$HOME/.tmux/plugins/tpm/bin/update_plugins" ]]; then
  step "tmux plugins" "$HOME/.tmux/plugins/tpm/bin/update_plugins" all
fi
if have rustup; then
  step "rustup" rustup update
fi

if ((${#failures[@]})); then
  joined=$(printf '%s, ' "${failures[@]}")
  echo "${joined%, }" > "$FAILED"
  echo "Failed: ${joined%, }. The log is $LOG."
  exit 1
fi
rm -f "$FAILED"
echo "Updated."
