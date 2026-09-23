# ~/.config/zsh/functions/venv.zsh
#
# venv — activate the nearest .venv, switch to it, or turn it off.
#
#   venv          activate the .venv in this directory or the closest parent;
#                 run it again inside the same project to deactivate;
#                 run it in another project to switch straight over
#   venv off      deactivate, wherever you are
#
# Never stacks activations: switching deactivates the old one first, so
# $PATH doesn't collect layers of bin directories.

venv() {
  if [[ "$1" == "off" || "$1" == "-d" ]]; then
    if [[ -n "$VIRTUAL_ENV" ]]; then
      deactivate
    else
      echo "venv: nothing active" >&2
    fi
    return
  fi

  # Walk up looking for a .venv
  local dir="$PWD" found=""
  while [[ "$dir" != "/" ]]; do
    if [[ -f "$dir/.venv/bin/activate" ]]; then
      found="$dir/.venv"
      break
    fi
    dir="$(dirname "$dir")"
  done

  if [[ -z "$found" ]]; then
    echo "venv: no .venv found here or in any parent directory" >&2
    [[ -f pyproject.toml ]] && echo "venv: this looks like a project — run 'uv sync' first" >&2
    return 1
  fi

  # Already in this one? Treat a second call as "turn it off".
  if [[ "$VIRTUAL_ENV" == "$found" ]]; then
    deactivate
    return
  fi

  # In a different one? Leave it before entering the new one.
  [[ -n "$VIRTUAL_ENV" ]] && deactivate

  source "$found/bin/activate"
}
