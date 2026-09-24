# ~/.config/zsh/functions/gitzip.zsh
#
# gitzip — zip a git repo into ./<repo>.zip, ready to upload or share.
#
#   gitzip [dir] [-o out.zip]              working tree + .git   (default)
#   gitzip [dir] [-o out.zip] --no-git     working tree only
#   gitzip [dir] [-o out.zip] --head       last commit only
#
#   default    tracked + untracked files (minus .gitignore'd) plus .git, so
#              the unzipped copy is a real checkout: log, status, diff and
#              blame all work, staged and unstaged changes included.
#              Leaves out .git/lfs (object cache) and the sample hooks.
#   --no-git   the same files without history
#   --head     committed state of HEAD via `git archive` — no .git, no
#              uncommitted changes; honors export-ignore in .gitattributes
#
# dir can be anywhere inside the repo; the whole repo is zipped either way,
# under a top-level <repo>/ folder. The zip lands in the current directory
# unless -o says otherwise, and is never swept into itself.

gitzip() {
  local usage='usage: gitzip [dir] [-o out.zip] [--no-git | --head]'
  local dir="" out="" mode="full"

  while (( $# )); do
    case "$1" in
      -o|--output)
        [[ -n "$2" ]] || { echo "$usage" >&2; return 1; }
        out="$2"; shift 2 ;;
      --no-git)  mode="tree"; shift ;;
      --head)    mode="head"; shift ;;
      -h|--help) echo "$usage"; return 0 ;;
      -*) echo "gitzip: unknown option '$1'" >&2; return 1 ;;
      *)  [[ -n "$dir" ]] && { echo "gitzip: one directory only" >&2; return 1; }
          dir="$1"; shift ;;
    esac
  done

  local root name parent
  root="$(git -C "${dir:-.}" rev-parse --show-toplevel 2>/dev/null)" || {
    echo "gitzip: '${dir:-.}' is not inside a git repository" >&2
    return 1
  }
  name="${root:t}"
  parent="${root:h}"

  out="${out:-$name.zip}"
  [[ "$out" == *.zip ]] || out+=".zip"   # zip would add it silently anyway
  out="${out:A}"                         # absolute, symlinks resolved like git's paths

  if [[ "$mode" == head ]]; then
    git -C "$root" archive --format=zip --prefix="$name/" -o "$out" HEAD || return 1
    echo "→ $out ($(du -h "$out" | cut -f1))"
    return
  fi

  if (( ! $+commands[zip] )); then
    echo "gitzip: 'zip' not found — install it (apt install zip)" >&2
    return 1
  fi
  if [[ "$mode" == full && ! -d "$root/.git" ]]; then
    echo "gitzip: $root/.git isn't a directory (worktree or submodule?)" >&2
    echo "gitzip: use --no-git or --head, or run it from the main checkout" >&2
    return 1
  fi

  # NUL-separated so odd filenames (spaces, unicode, quotes) survive intact;
  # -U drops the duplicate entries ls-files gives conflicted paths mid-merge
  local -aU files
  local f
  for f in ${(0)"$(git -C "$root" ls-files -z --cached --others --exclude-standard)"}; do
    [[ "$root/$f" == "$out" ]] && continue                          # not the zip itself
    [[ -e "$root/$f" || -L "$root/$f" ]] && files+=("$name/$f")    # skip deleted-but-tracked
  done

  rm -f -- "$out"
  (
    cd "$parent" || exit 1
    if (( ${#files} )); then
      print -rl -- "${files[@]}" | zip -q -y "$out" -@ || exit 1
    fi
    if [[ "$mode" == full ]]; then
      zip -q -r -y "$out" "$name/.git" \
        -x "$name/.git/lfs/*" "$name/.git/hooks/*.sample" || exit 1
    fi
  ) || return 1

  echo "→ $out ($(du -h "$out" | cut -f1))"
}
