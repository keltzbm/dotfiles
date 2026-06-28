pyproject() {
    if [[ -z "$1" ]]; then
        echo "Usage: pyproject <project-name>"
        return 1
    fi

    local name="$1"
    local pkg="${name//-/_}"   # convert hyphens to underscores for package name

    mkdir -p "$name"
    cd "$name"

    # ── Folder structure ──────────────────────────────────────────────
    mkdir -p src/"$pkg"
    mkdir -p tests
    mkdir -p outputs
    mkdir -p docs

    # ── Python package init ───────────────────────────────────────────
    touch src/"$pkg"/__init__.py
    touch src/"$pkg"/main.py
    touch tests/__init__.py
    touch tests/test_main.py

    # ── Virtual environment ───────────────────────────────────────────
    python3 -m venv .venv
    source .venv/bin/activate
    pip install --upgrade pip

    # ── .gitignore ────────────────────────────────────────────────────
    cat > .gitignore << 'GITIGNORE'
# Python
.venv/
__pycache__/
*.pyc
*.pyo
*.egg-info/
dist/
build/
.eggs/

# Project
outputs/

# Editors
.DS_Store
*.swp
*.swo
.idea/
.vscode/

# Testing
.pytest_cache/
.coverage
htmlcov/
GITIGNORE

    # ── pyproject.toml ────────────────────────────────────────────────
    cat > pyproject.toml << PYPROJECT
[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"

[project]
name = "$name"
version = "0.1.0"
description = ""
authors = [{ name = "Brandon Keltz", email = "keltzbm@icloud.com" }]
readme = "README.md"
license = { text = "MIT" }
requires-python = ">=3.10"
dependencies = []

[project.optional-dependencies]
dev = [
    "pytest",
    "ruff",
]

[tool.setuptools.packages.find]
where = ["src"]

[tool.pytest.ini_options]
testpaths = ["tests"]

[tool.ruff]
line-length = 88
target-version = "py310"
PYPROJECT

    # ── setup.cfg (for editable installs) ────────────────────────────
    cat > setup.cfg << SETUP
[metadata]
name = $name

[options]
package_dir =
    = src
packages = find:

[options.packages.find]
where = src
SETUP

    # ── requirements.txt ──────────────────────────────────────────────
    touch requirements.txt

    # ── README ────────────────────────────────────────────────────────
    cat > README.md << README
# $name

## Installation

\`\`\`bash
pip install -e ".[dev]"
\`\`\`

## Usage

\`\`\`bash
python -m $pkg
\`\`\`

## Project Structure

\`\`\`
$name/
├── src/$pkg/     # source code
├── tests/        # tests
├── outputs/      # generated outputs
└── docs/         # documentation
\`\`\`
README

    # ── Git ───────────────────────────────────────────────────────────
    git init
    git add .
    git commit -m "Initial commit: project scaffold"
    pip install -e ".[dev]" && echo "✓ Dependencies installed" || echo "✗ Install failed — run 'pip install -e .[dev]' manually"

    echo ""
    echo "✓ Project '$name' created at $(pwd)"
    echo "✓ Virtual environment activated"
}
