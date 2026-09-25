# Cheat sheet

Everything these dotfiles add on top of stock tools. It's the same on macOS,
WSL2 and native Ubuntu unless a line says otherwise.

The first three sections (summary, shell commands, CLI tools) are what an
assistant needs to use these commands in any project folder. The rest are
keybindings.

## Summary for assistants

- Shell is **zsh**. Three custom commands exist on every machine:
  `gitzip` (zip a repo, with its git history, for sharing), `newrepo`
  (scaffold a Python project) and `venv` (activate the nearest `.venv`).
- **Changes land through `gh ship`.** Work happens one branch per change;
  after committing on the branch, `gh ship` pushes it, opens the PR, turns on
  auto-merge, waits for CI and the merge, then leaves you on an up-to-date
  `main` with the branch deleted. It's safe to rerun, and exits non-zero if a
  check fails (fix, commit, run it again). It also works in Codespaces.
- **Python comes from uv.** `python`/`python3` are uv's 3.14. Projects keep
  their own `.venv`; use `uv sync`, `uv run <cmd>`, `uv add <pkg>` rather
  than pip. `newrepo` projects use a `src/` layout with ruff, mypy, pytest
  and pre-commit.
- **Sharing a repo with Claude:** run `gitzip` inside it and upload the zip.
  Unzipped, it's a working checkout: `git log`, `git status` and
  `git diff` all work, including uncommitted changes.
- Repos live in `~/atelier/github/` (personal) and `~/atelier/gitlab/`
  (work); git picks the identity by folder.
- `ls` is eza, `vi`/`vim` open Neovim, and `EDITOR=nvim`.
- Installed everywhere (the `Brewfile`): `rg`, `fd`, `bat`, `fzf`, `zoxide`,
  `eza`, `gh`, `uv`, `deno`, `duckdb`, `shellcheck`, `stow`, `git-lfs`, `stylua`.

## Shell commands

### gitzip — zip a repo for sharing

```
gitzip [dir] [-o out.zip] [--no-git | --head]
```

| Form              | What's in the zip                                                      |
|-------------------|------------------------------------------------------------------------|
| `gitzip`          | Working tree (tracked + untracked, minus `.gitignore`d) **plus `.git`** |
| `gitzip --no-git` | The same files, no history                                            |
| `gitzip --head`   | Last commit only (`git archive HEAD`); no `.git`, no uncommitted work |

- Run it anywhere inside a repo; the whole repo is zipped under a top-level
  `<repo>/` folder.
- Writes `./<repo>.zip` in the current folder unless `-o` says otherwise
  (`.zip` is added if missing). Prints `→ path (size)`.
- Skips `.git/lfs` and sample hooks. Never zips the output file into itself.
- Fails with a message in linked worktrees/submodules (`.git` is a file
  there); use `--no-git` or `--head` for those.
- The default ships everything ever committed; use `--no-git`/`--head` for
  repos where history shouldn't leave the machine.

### newrepo — scaffold a Python project

```
newrepo <name> [-d "description"] [-p 3.13] [--cli] [--gh] [--public] [--no-sync]
```

| Option                | Effect                                                          |
|-----------------------|-----------------------------------------------------------------|
| `-d, --description`   | One-line description (pyproject + README)                       |
| `-p, --python`        | Minimum Python version (default `3.13`)                         |
| `--cli`               | `main.py` gets an argparse CLI (`--version`, `-v`/`-vv`)       |
| `--gh`                | Create a private GitHub repo with `gh` and push                 |
| `--public`            | With `--gh`, make it public                                     |
| `--no-sync`           | Skip `uv sync`, pre-commit install and the first commit         |

- Creates `./<name>` and `cd`s into it; refuses if it already exists.
- Name: letters, digits, `-` and `_`, starting with a letter. The import
  package lowercases it and swaps `-` for `_` (`my-tool` → `my_tool`).
- Creates: `src/<pkg>/` (`__init__.py` with the version, `main.py`,
  `config.py` with `DATA_DIR`/`OUTPUT_DIR`, `__main__.py`, `py.typed`),
  `tests/`, `docs/`, `data/` (contents ignored), `pyproject.toml`
  (hatchling; ruff, mypy strict, pytest, coverage), `.pre-commit-config.yaml`,
  GitHub Actions CI + Dependabot, `.gitignore`, `.gitattributes`,
  `.editorconfig`, README, CHANGELOG, MIT LICENSE.
- Then `git init`; unless `--no-sync`: `uv sync`, `ruff format`,
  `pre-commit install`, and an "Initial scaffold" commit. `--gh` needs that
  commit, so it doesn't combine with `--no-sync`.
- The project runs as `<name>` (console script) or `python -m <pkg>`.

### venv — activate the nearest virtualenv

| Command                 | Effect                                                       |
|-------------------------|--------------------------------------------------------------|
| `venv`                  | Activate the `.venv` in this folder or the closest parent    |
| `venv` (same project)   | Run again to deactivate                                      |
| `venv` (other project)  | Switches straight over (never stacks activations)            |
| `venv off` / `venv -d`  | Deactivate from anywhere                                     |

No `.venv` found → error; if there's a `pyproject.toml`, it suggests
`uv sync`.

### gh ship — land a change on the default branch

```
gh ship
```

Run it on a change's branch after committing. It doesn't return until the
change is merged or something has clearly failed:

1. Refuses on the default branch (read from GitHub, usually `main`) or with
   no branch checked out.
2. Pushes the branch and opens a PR (`gh pr create --fill`) unless one is open.
3. Turns on auto-merge (squash) unless it's already on.
4. Waits for GitHub to show the pushed commit and start its checks, then
   watches them (`gh pr checks --watch --fail-fast`).
5. If a check fails, stops with a non-zero exit and nothing merges. Fix,
   commit, and run `gh ship` again.
6. Waits for GitHub to merge, then switches to the branch it merged into,
   pulls, and deletes the local branch.

- Safe to rerun at any point; Ctrl-C during a wait changes nothing.
- If the PR is already merged it goes straight to step 6, unless the branch
  has commits the PR didn't include; then it stops and keeps them.
- Stops with a message if the PR conflicts with its base or gets closed, or
  if GitHub hasn't moved on after 5 minutes at any step (the checks
  themselves can take as long as they need). `GH_SHIP_TIMEOUT=<seconds>`
  changes the limit.
- Needs gh 2.29+, and a repo that allows auto-merge and requires a CI check
  on the default branch.
- It's a gh extension: Stow links it into `~/.local/share/gh/extensions/`
  (in Codespaces, install.sh links it by itself).

### Aliases

| Alias   | Runs                                                    |
|---------|---------------------------------------------------------|
| `ls`    | `eza --icons --group-directories-first`                  |
| `ll`    | `ls` + `--long`                                          |
| `la`    | `ls` + `--long --all`                                    |
| `lt`    | `eza --icons --tree --level=2`                           |
| `lta`   | `eza --icons --tree --level=3`                           |
| `vi`    | `nvim`                                                   |
| `vim`   | `nvim`                                                   |
| `awake` | `caffeinate -dis`: keep the Mac awake (macOS only)       |

The `eza` aliases only exist when eza is installed.

## CLI tools

Installed by `install.sh` on every machine (Homebrew).

| Tool       | Command / keys                   | Use                                        |
|------------|----------------------------------|--------------------------------------------|
| ripgrep    | `rg <pattern>`                   | Search file contents (respects .gitignore) |
| fd         | `fd <name>`                      | Find files by name                         |
| bat        | `bat <file>`                     | `cat` with syntax highlighting             |
| fzf        | `Ctrl-R` / `Ctrl-T` / `Alt-C`    | Fuzzy history search / insert a file path / cd into a folder |
| zoxide     | `z <part of path>` / `zi`        | Jump to a visited folder / pick one interactively |
| eza        | via the aliases above            | `ls` replacement                           |
| gh         | `gh pr create`, `gh repo view`…  | GitHub CLI                                 |
| uv         | `uv sync`, `uv run`, `uv add`    | Python versions, venvs, dependencies       |
| deno       | `deno`                           | JS/TS runtime (builds peek.nvim)           |
| duckdb     | `duckdb [file.db]`               | SQL on local files (CSV, Parquet, JSON)    |
| shellcheck | `shellcheck <script>`            | Lint shell scripts (the tests use it)      |
| git-lfs    | automatic                        | Large files in repos that use LFS          |
| stylua     | automatic                        | Lua formatter (Neovim formats on save)     |
| stow       | `stow -R <package>`              | Re-link a dotfiles package                 |

## Git

- Identity by folder: `~/atelier/github/` → `~/.gitconfig-personal`,
  `~/atelier/gitlab/` → `~/.gitconfig-gitlab`; elsewhere the `[user]` in
  `.gitconfig`.
- `git difftool` opens the diff in Neovim (`nvim -d`), no prompt.
- `https://github.com/…` URLs are rewritten to SSH.
- New repos start on `main`.

## Neovim

Leader is **Space**. `<leader>?` shows every leader mapping.

### Files, windows, buffers

| Keys                       | Action                                  |
|----------------------------|-----------------------------------------|
| `<leader>w` / `<leader>q`  | Save / quit                             |
| `<leader>e`                | Toggle file tree (Neo-tree)             |
| `<leader>x`                | Close buffer, keep the window           |
| `<leader>sv` / `<leader>sh`| Split side by side / top and bottom     |
| `<C-h>` `<C-j>` `<C-k>` `<C-l>` | Move between windows               |
| `<leader>ff`               | Find files (Telescope)                  |
| `<leader>fg`               | Search file contents (live grep)        |
| `<leader>fb`               | Open buffers                            |
| `<leader>fr`               | Recent files                            |

### Editing

| Keys                        | Action                                              |
|-----------------------------|-----------------------------------------------------|
| `jk` (insert)               | Leave insert mode                                   |
| `<` / `>` (visual)          | Indent and keep the selection                       |
| `<leader>cf`                | Format file (also runs on save)                     |
| `<leader>cw`                | Remove trailing whitespace                          |
| `<leader>cl` (visual)       | Move end-of-line comments onto their own line above |
| `<leader>=` (visual)        | Normalize spacing around `=` (skips `==`, `<=`, `+=`…) |
| `<leader>:` (visual)        | Normalize spacing after `:` (skips `::`, URLs, times) |
| `<leader>,` (visual)        | Normalize spacing after `,`                         |

Formatting: Lua uses stylua; other languages use their language server's
formatter when it has one.

### Code navigation (LSP)

Servers: lua_ls, pyright, ts_ls, bashls (installed by Mason on first launch).

| Keys                      | Action                                    |
|---------------------------|-------------------------------------------|
| `gd` / `gD`               | Go to definition / declaration            |
| `grr`                     | References *(built in)*                   |
| `gri` / `grt`             | Implementation / type definition *(built in)* |
| `K`                       | Hover docs *(built in)*                   |
| `<leader>rn` or `grn`     | Rename symbol                             |
| `<leader>ca` or `gra`     | Code action                               |
| `<leader>d`               | Show the diagnostic under the cursor      |
| `[d` / `]d`               | Previous / next diagnostic *(built in)*   |
| `<C-s>`                   | Signature help (normal and insert)        |

### Completion (insert mode)

Off by default except in Python, where it pops up as you type.

| Keys                        | Action                                |
|-----------------------------|---------------------------------------|
| `<C-Space>`                 | Open the menu                         |
| `<C-j>` / `<C-k>`, `<Tab>` / `<S-Tab>` | Next / previous item       |
| `<CR>`                      | Accept                                |
| `<C-e>`                     | Close the menu                        |
| `<C-f>` / `<C-b>`           | Scroll the docs window                |
| `<leader>ta` (normal)       | Toggle as-you-type completion for this buffer |

### Running and previewing

| Keys                         | Action                                                        |
|------------------------------|---------------------------------------------------------------|
| `<leader>rr` / `<leader>rv`  | Run the current file in a terminal split below / beside       |
| `<leader>mp`                 | Open markdown preview in the browser (`:PeekClose` to close)  |

`<leader>rr`/`<leader>rv` know python (`python3`), sh/bash, javascript
(`node`), go (`go run`) and rust (`cargo run`).

### Toggles

| Keys          | Action                          |
|---------------|---------------------------------|
| `<leader>tw`  | Show/hide whitespace characters |
| `<leader>tc`  | Show/hide an 80-column ruler    |

## tmux

Prefix is **Ctrl-a** (press it, release, then the key).

| Keys                  | Action                                      |
|-----------------------|---------------------------------------------|
| `Prefix \|`           | Split side by side (same folder)            |
| `Prefix -`            | Split top and bottom (same folder)          |
| `Prefix c`            | New window (same folder)                    |
| `Prefix h/j/k/l`      | Move between panes                          |
| `Prefix H/J/K/L`      | Resize pane (hold to repeat)                |
| `Prefix z`            | Zoom pane in/out                            |
| `Prefix a`            | Last window                                 |
| `Prefix Ctrl-p/Ctrl-n`| Previous / next window (tmux-sensible)      |
| `Prefix x` / `X`      | Kill pane / window (no confirmation)        |
| `Prefix Enter`        | Copy mode                                   |
| `Prefix r`            | Reload config                               |
| `Prefix Ctrl-a`       | Send Ctrl-a to the program inside           |
| `Prefix Ctrl-s` / `Ctrl-r` | Save / restore session (tmux-resurrect) |
| `Prefix I` / `U`      | Install / update plugins (TPM)              |

Copy mode (vi keys): `v` start selection, `Ctrl-v` block selection,
`H`/`L` start/end of line, `y` copy to the system clipboard.

Sessions auto-save every 15 minutes and restore when tmux starts
(tmux-continuum). The mouse works for selecting panes and scrolling.

## Alacritty

| Keys                  | Action                      |
|-----------------------|-----------------------------|
| `Ctrl+Shift+N`        | New window (any platform)   |
| `Cmd+Shift+Return`    | Toggle fullscreen (Cmd is the Super key off macOS) |

Plus Alacritty's defaults: `Cmd+C/V/N/Q` and `Cmd+0/=/-` on macOS,
`Ctrl+Shift+C/V` on Linux/Windows.

## install.sh

Safe to rerun; it's also how a machine gets updates. In order: `git pull`,
install Homebrew if missing, install everything in the `Brewfile`
(`brew bundle`; the tools above plus zsh, tmux, neovim, starship and git),
make uv's Python 3.14 the default, install a few apt packages on Linux, build
Alacritty from source if it's missing (skipped under WSL, where it runs on
Windows), stow every package into `~`, then install TPM and the tmux plugins.

In a GitHub Codespace it only links the gh extensions (`gh ship`) and stops:
the codespace image already has git and a signed-in gh.
