# ~/.config/zsh/functions/newrepo.zsh
#
# newrepo — scaffold a new Python repo in the current directory:
#   src/ layout · hatchling · uv · ruff · mypy · pytest+coverage · pre-commit
#   · MIT · GitHub Actions CI · Dependabot · editorconfig
#
#   newrepo <name> [-d "description"] [-p 3.13] [--cli] [--gh] [--public] [--no-sync]
#
#       --cli           main.py gets an argparse CLI (--version, -v/-vv);
#                       default is a plain main() for fixed pipelines
#   -d, --description   one-line description (pyproject + README)
#   -p, --python        minimum Python version            (default: 3.13)
#       --gh            create the GitHub repo with gh and push (private)
#       --public        with --gh, make it public instead
#       --no-sync       skip `uv sync`, pre-commit install, and the first commit
#
# Only ever creates ./<name>; refuses if it already exists.
# The project name keeps hyphens (my-tool); the import package gets
# underscores (my_tool).

newrepo() {
  local usage='usage: newrepo <name> [-d "description"] [-p 3.13] [--cli] [--gh] [--public] [--no-sync]'
  local name="" desc="" py="3.13" cli=0 gh=0 visibility="--private" sync=1

  while (( $# )); do
    case "$1" in
      -d|--description) desc="$2"; shift 2 ;;
      -p|--python)      py="$2";   shift 2 ;;
      --cli)            cli=1;     shift ;;
      --gh)             gh=1;      shift ;;
      --public)         visibility="--public"; shift ;;
      --no-sync)        sync=0;    shift ;;
      -h|--help)        echo "$usage"; return 0 ;;
      -*) echo "newrepo: unknown option '$1'" >&2; return 1 ;;
      *)  [[ -n "$name" ]] && { echo "newrepo: one name only" >&2; return 1; }
          name="$1"; shift ;;
    esac
  done

  local re='^[A-Za-z][A-Za-z0-9_-]*$'
  if [[ -z "$name" ]]; then
    echo "$usage" >&2; return 1
  elif ! [[ "$name" =~ $re ]]; then
    echo "newrepo: '$name' — use letters, digits, - and _ (start with a letter)" >&2
    return 1
  elif [[ -e "$name" ]]; then
    echo "newrepo: '$name' already exists here — nothing touched" >&2
    return 1
  fi

  local pkg author email year pyshort docline
  pkg="$(printf '%s' "${name//-/_}" | tr '[:upper:]' '[:lower:]')"
  author="$(git config user.name  || echo "Your Name")"
  email="$(git config user.email || echo "you@example.com")"
  year="$(date +%Y)"
  pyshort="py${py//./}"                         # 3.13 -> py313 (ruff target)
  docline="${desc%.}"; docline="${docline:-$name}"
  local qdesc=${desc//\"/\\\"}                  # escape " for TOML/Python strings

  mkdir -p "$name"/{src/"$pkg",tests,docs,data,.github/workflows} && cd "$name" || return 1

  # ── .gitignore ────────────────────────────────────────────────
  cat > .gitignore <<'EOF'
# Python
.venv/
__pycache__/
*.py[cod]
*.egg-info/
dist/
build/

# Tooling caches & reports
.pytest_cache/
.ruff_cache/
.mypy_cache/
.coverage
coverage.xml
htmlcov/
.ipynb_checkpoints/

# Editors
*.swp
*.swo
.idea/
.vscode/

# OS
.DS_Store
Thumbs.db

# Secrets — never commit
.env
.env.*

# Data & output: the folder is tracked, its contents aren't.
# Commit a small reference file on purpose with `git add -f data/<file>`.
data/*
!data/.gitkeep
out/
*.log
EOF

  # ── Line endings & editor defaults (Mac / WSL / Linux agree) ──
  cat > .gitattributes <<'EOF'
* text=auto eol=lf
*.png binary
*.jpg binary
*.pdf binary
EOF

  cat > .editorconfig <<'EOF'
root = true

[*]
charset = utf-8
end_of_line = lf
insert_final_newline = true
trim_trailing_whitespace = true
indent_style = space
indent_size = 4

[*.{yml,yaml,toml,json,md}]
indent_size = 2
EOF

  # ── pyproject.toml ────────────────────────────────────────────
  cat > pyproject.toml <<EOF
[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"

[project]
name = "$name"
dynamic = ["version"]
description = "$qdesc"
authors = [{ name = "$author", email = "$email" }]
readme = "README.md"
license = "MIT"
license-files = ["LICENSE"]
requires-python = ">=$py"
dependencies = []

[project.scripts]
$name = "$pkg.main:main"

[dependency-groups]
dev = [
    "mypy",
    "pre-commit",
    "pytest",
    "pytest-cov",
    "ruff",
]

[tool.hatch.version]
path = "src/$pkg/__init__.py"

[tool.hatch.build.targets.wheel]
packages = ["src/$pkg"]

[tool.pytest.ini_options]
testpaths = ["tests"]
addopts = ["--import-mode=importlib", "-ra", "--strict-markers"]

[tool.coverage.run]
source = ["$pkg"]
branch = true

[tool.coverage.report]
show_missing = true
skip_covered = true

[tool.mypy]
files = ["src"]
strict = true

[tool.ruff]
line-length = 88
target-version = "$pyshort"

[tool.ruff.lint]
extend-select = ["F", "E", "W", "I", "UP", "B", "SIM", "D"]

[tool.ruff.lint.pydocstyle]
convention = "google"

[tool.ruff.lint.isort]
known-first-party = ["$pkg"]

[tool.ruff.lint.per-file-ignores]
"tests/**" = ["D"]

[tool.ruff.format]
quote-style = "double"
docstring-code-format = true
EOF

  # ── pre-commit ────────────────────────────────────────────────
  # Hygiene hooks from pre-commit-hooks; ruff runs through uv so the hook
  # always uses the ruff version in uv.lock.
  cat > .pre-commit-config.yaml <<'EOF'
repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v6.0.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-yaml
      - id: check-toml
      - id: check-merge-conflict
      - id: check-added-large-files
        args: [--maxkb=1000]
      - id: detect-private-key

  - repo: local
    hooks:
      - id: ruff-check
        name: ruff check
        entry: uv run --frozen ruff check --fix
        language: system
        types_or: [python, pyi]
      - id: ruff-format
        name: ruff format
        entry: uv run --frozen ruff format
        language: system
        types_or: [python, pyi]
EOF

  # ── CI + Dependabot ───────────────────────────────────────────
  cat > .github/workflows/ci.yml <<'EOF'
name: CI

on:
  push:
    branches: [main]
  pull_request:

jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v5
      - uses: astral-sh/setup-uv@v7
      - run: uv sync --locked
      - run: uv run ruff check
      - run: uv run ruff format --check
      - run: uv run mypy
      - run: uv run pytest --cov
EOF

  cat > .github/dependabot.yml <<'EOF'
version: 2
updates:
  - package-ecosystem: github-actions
    directory: /
    schedule:
      interval: monthly
  - package-ecosystem: uv
    directory: /
    schedule:
      interval: monthly
EOF

  # ── Source ────────────────────────────────────────────────────
  cat > "src/$pkg/__init__.py" <<EOF
"""$docline."""

__version__ = "0.1.0"
EOF

  cat > "src/$pkg/config.py" <<EOF
"""Paths and settings shared across $name.

PROJECT_ROOT assumes an editable install from the repo (what \`uv sync\` does).
"""

from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[2]
DATA_DIR = PROJECT_ROOT / "data"
OUTPUT_DIR = PROJECT_ROOT / "out"
EOF

  if (( cli )); then
    cat > "src/$pkg/main.py" <<EOF
"""Command-line entry point for $name."""

import argparse
import logging
from collections.abc import Sequence

from $pkg import __version__
from $pkg.config import DATA_DIR

log = logging.getLogger(__name__)


def parse_args(argv: Sequence[str] | None = None) -> argparse.Namespace:
    """Parse command-line arguments.

    Args:
        argv: Arguments to parse. Defaults to \`\`sys.argv[1:]\`\`.

    Returns:
        The parsed arguments.
    """
    parser = argparse.ArgumentParser(prog="$name", description="$qdesc")
    parser.add_argument(
        "--version", action="version", version=f"%(prog)s {__version__}"
    )
    parser.add_argument(
        "-v",
        "--verbose",
        action="count",
        default=0,
        help="increase log output (-v info, -vv debug)",
    )
    return parser.parse_args(argv)


def setup_logging(verbosity: int) -> None:
    """Configure root logging from a -v count.

    Args:
        verbosity: 0 for warnings, 1 for info, 2+ for debug.
    """
    level = [logging.WARNING, logging.INFO, logging.DEBUG][min(verbosity, 2)]
    logging.basicConfig(
        level=level,
        format="%(asctime)s %(levelname)-8s %(name)s: %(message)s",
        datefmt="%H:%M:%S",
    )


def main(argv: Sequence[str] | None = None) -> int:
    """Run $name.

    Args:
        argv: Command-line arguments. Defaults to \`\`sys.argv[1:]\`\`.

    Returns:
        Process exit code (0 on success).
    """
    args = parse_args(argv)
    setup_logging(args.verbose)
    log.debug("args: %s", args)
    log.info("data dir: %s", DATA_DIR)

    print("Hello from $name!")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
EOF
  else
    cat > "src/$pkg/main.py" <<EOF
"""Entry point for $name."""

import logging
import os

from $pkg.config import DATA_DIR

log = logging.getLogger(__name__)


def setup_logging() -> None:
    """Configure root logging; set LOG_LEVEL=INFO or DEBUG for more output."""
    logging.basicConfig(
        level=os.environ.get("LOG_LEVEL", "WARNING").upper(),
        format="%(asctime)s %(levelname)-8s %(name)s: %(message)s",
        datefmt="%H:%M:%S",
    )


def main() -> int:
    """Run $name.

    Returns:
        Process exit code (0 on success).
    """
    setup_logging()
    log.info("data dir: %s", DATA_DIR)

    print("Hello from $name!")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
EOF
  fi

  cat > "src/$pkg/__main__.py" <<EOF
"""Allow \`python -m $pkg\`."""

from $pkg.main import main

raise SystemExit(main())
EOF

  touch "src/$pkg/py.typed"

  # ── Tests ─────────────────────────────────────────────────────
  cat > tests/conftest.py <<'EOF'
"""Shared pytest fixtures."""
EOF

  if (( cli )); then
    cat > tests/test_main.py <<EOF
import pytest

from $pkg import __version__
from $pkg.main import main


def test_main_succeeds(capsys):
    assert main([]) == 0
    assert "$name" in capsys.readouterr().out


def test_version_flag(capsys):
    with pytest.raises(SystemExit) as exc:
        main(["--version"])
    assert exc.value.code == 0
    assert __version__ in capsys.readouterr().out


def test_verbose_flag_logs(caplog):
    with caplog.at_level("INFO"):
        main(["-v"])
    assert "data dir" in caplog.text
EOF
  else
    cat > tests/test_main.py <<EOF
from $pkg import __version__
from $pkg.main import main


def test_version():
    assert __version__


def test_main_succeeds(capsys):
    assert main() == 0
    assert "$name" in capsys.readouterr().out
EOF
  fi

  touch docs/.gitkeep data/.gitkeep

  # ── README / CHANGELOG / LICENSE ──────────────────────────────
  cat > README.md <<EOF
# $name

${desc:-TODO: one-line description.}

## Install

\`\`\`bash
uv sync                      # creates .venv, installs the package + dev tools
source .venv/bin/activate    # or prefix commands with \`uv run\`
\`\`\`

## Usage

\`\`\`bash
$name                        # or: python -m $pkg  (LOG_LEVEL=DEBUG for more output)
\`\`\`

## Development

\`\`\`bash
uv run pytest --cov          # tests + coverage
uv run ruff check --fix      # lint
uv run ruff format           # format
uv run mypy                  # type-check
uv add <package>             # add a runtime dependency
uv add --dev <package>       # add a dev dependency
uv run pre-commit autoupdate # bump pinned hook versions
\`\`\`

## Layout

\`\`\`
src/$pkg/    package code (main.py = CLI, config.py = paths/settings)
tests/       pytest tests
docs/        notes, design docs, reference PDFs
data/        local data (contents git-ignored)
\`\`\`
EOF

  cat > CHANGELOG.md <<'EOF'
# Changelog

All notable changes to this project are documented here.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/);
versioning: [SemVer](https://semver.org/).

## [Unreleased]

### Added
- Initial project scaffold.
EOF

  cat > LICENSE <<EOF
MIT License

Copyright (c) $year $author

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
EOF

  # ── git, venv, hooks, first commit ────────────────────────────
  git init --quiet

  if (( sync )); then
    if ! command -v uv >/dev/null; then
      echo "newrepo: uv not found — skipping sync (brew install uv)" >&2
    else
      uv sync --quiet \
        && uv run --frozen ruff format --quiet . \
        && uv run --frozen pre-commit install >/dev/null \
        && git add -A \
        && git commit --quiet -m "Initial scaffold" \
        || { echo "newrepo: setup step failed — files are in place, finish by hand" >&2; return 1; }
    fi
  fi

  if (( gh )); then
    if ! command -v gh >/dev/null; then
      echo "newrepo: gh not found — skipping GitHub repo creation (brew install gh)" >&2
    elif (( ! sync )); then
      echo "newrepo: --gh needs a commit to push; rerun without --no-sync" >&2
    else
      local -a ghargs=("$name" "$visibility" --source=. --remote=origin --push)
      [[ -n "$desc" ]] && ghargs+=(--description "$desc")
      gh repo create "${ghargs[@]}"
    fi
  fi

  echo "→ $PWD"
}
