# dotfiles

My terminal setup (zsh, Neovim, tmux, Alacritty, Starship), kept in sync
across macOS, WSL2 and native Ubuntu with [GNU Stow](https://www.gnu.org/software/stow/).

**Every command and keybinding these files add is in [CHEATSHEET.md](CHEATSHEET.md).**

## What's here

Each top-level folder is a Stow package laid out the way its files sit in `~`.

| Package     | Configures                              | Lands at                              |
|-------------|-----------------------------------------|---------------------------------------|
| `zsh`       | Shell, aliases, `gitzip`/`newrepo`/`venv` | `~/.zshenv`, `~/.config/zsh/`       |
| `nvim`      | Neovim: lazy.nvim, LSP, completion      | `~/.config/nvim/`                     |
| `tmux`      | tmux: prefix Ctrl-a, plugins via TPM    | `~/.tmux.conf`                        |
| `alacritty` | Terminal                                | `~/.config/alacritty/`                |
| `starship`  | Prompt                                  | `~/.config/starship.toml`             |
| `git`       | Git config, global ignore file          | `~/.gitconfig`, `~/.gitignore_global` |

Also at the root: `install.sh` (setup), `tests/` (checks, below) and
`.stowrc` (points Stow at `~`).

## Install

```bash
git clone git@github.com:keltzbm/dotfiles.git ~/atelier/github/dotfiles
cd ~/atelier/github/dotfiles
./install.sh
```

`install.sh` is safe to rerun, and rerunning it is how a machine picks up
changes. It pulls, installs Homebrew and the CLI tools, makes uv's Python
3.14 the default, builds Alacritty from source where it's missing (not under
WSL, where Alacritty runs on Windows), stows every package, and installs the
tmux plugins. The full list is at the end of the cheat sheet.

## Machine-specific files (not in the repo)

Git picks an identity by folder, from files you create on each machine:

- `~/atelier/github/…` uses `~/.gitconfig-personal`
- `~/atelier/gitlab/…` uses `~/.gitconfig-gitlab`

Each holds a `[user]` block (name, email). Repos anywhere else use the
`[user]` in `git/.gitconfig`.

## Day to day

- Edit the files here. Stow's links make changes live right away: open a
  new shell, `:source` in Neovim, or `Prefix r` in tmux.
- New file in an existing package: usually nothing to do, since Stow links
  whole folders where it can; otherwise `stow -R <package>`.
- New package: create `<tool>/<path as it sits in ~>`, then add the folder
  to the `for pkg in …` list in `install.sh`. A test checks the two match.

## Tests

```bash
zsh tests/run.zsh          # about 5 seconds
zsh tests/run.zsh --nvim   # also starts Neovim with this config (downloads plugins)
```

Everything runs in a throwaway folder with its own `$HOME`, so it never
touches your real setup. It checks:

- **Syntax:** zsh, bash (plus shellcheck), Lua, TOML and tmux files all parse.
- **Stow:** every package stows cleanly into an empty home, `.stowrc` points
  at `~`, and `install.sh` stows exactly the packages that exist.
- **Shell startup:** `.zshrc` starts without errors, keeps the folder it
  starts in, stays in emacs keys, and keeps its cache out of the repo.
- **Functions:** `gitzip`, `newrepo` and `venv` behave as the cheat sheet
  says, run against throwaway repos and folders.
- **Docs:** every function, alias and Neovim mapping is in the cheat sheet,
  and every `<leader>` mapping the cheat sheet lists still exists.
- **Neovim** (with `--nvim`): plugins install at the `lazy-lock.json`
  versions and a file opens without errors.

Checks whose tool isn't installed are skipped rather than failed. GitHub
Actions runs the full suite on Ubuntu and macOS for every push.

## Notes

- Because Stow links whole folders (`~/.config/zsh` points into this repo),
  anything a program writes into those folders shows up here as an
  untracked file. `.gitignore` covers the known cases: zsh's completion
  cache, `.env` files and private keys.
- WSL: Windows Alacritty reads `%APPDATA%\alacritty\alacritty.toml`, so copy
  or link `alacritty/.config/alacritty/alacritty.toml` there.
