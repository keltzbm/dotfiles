#!/usr/bin/env zsh
# tests/run.zsh — checks for this repo.
#
#   zsh tests/run.zsh           syntax, stow, shell startup, zsh functions, docs
#   zsh tests/run.zsh --nvim    also start Neovim with this config (downloads
#                               plugins into a temp dir; needs network, ~1 min)
#
# Everything runs in a throwaway directory with its own $HOME, so it never
# touches your real config. A check whose tool isn't installed is skipped.

emulate -R zsh
setopt extended_glob no_nomatch pipe_fail

REPO=${0:A:h:h}
TMP=$(mktemp -d)
TMP=${TMP:A}
trap 'rm -rf "$TMP"' EXIT

with_nvim=0
[[ $1 == --nvim ]] && with_nvim=1

# Keep the real ~/.gitconfig and ~/.zshenv out of every test
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com
export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com
unset ZDOTDIR VIRTUAL_ENV

typeset -i passed=0 failed=0 skipped=0
if [[ -t 1 ]]; then
  G=$'\e[32m' R=$'\e[31m' Y=$'\e[33m' B=$'\e[1m' N=$'\e[0m'
else
  G= R= Y= B= N=
fi

section() { print -r -- $'\n'"$B$1$N"; }
pass()    { (( passed++ )); print -r -- "  ${G}✓$N $1"; }
fail()    { (( failed++ )); print -r -- "  ${R}✗$N $1"; [[ -n $2 ]] && print -r -- "$2" | sed 's/^/      /'; }
skip()    { (( skipped++ )); print -r -- "  ${Y}-$N $1 ${Y}(skipped: $2)$N"; }
have()    { (( $+commands[$1] )); }

# check "description" command... — passes when the command exits 0
check() {
  local desc=$1 out; shift
  if out=$("$@" 2>&1); then pass "$desc"; else fail "$desc" "$out"; fi
}

# same "description" actual expected
same() {
  if [[ $2 == "$3" ]]; then pass "$1"; else fail "$1" "expected: $3"$'\n'"got:      $2"; fi
}

# ─────────────────────────────────────────────────────────────
section "Syntax"
# ─────────────────────────────────────────────────────────────
for f in $REPO/zsh/.zshenv $REPO/zsh/.config/zsh/.zshrc $REPO/zsh/.config/zsh/functions/*.zsh $REPO/tests/*.zsh; do
  check "zsh -n ${f#$REPO/}" zsh -n $f
done

SHIP=$REPO/gh/.local/share/gh/extensions/gh-ship/gh-ship
check "bash -n install.sh" bash -n $REPO/install.sh
check "sh -n gh-ship" sh -n $SHIP
if have shellcheck; then
  for f in $REPO/install.sh $SHIP $REPO/tests/fake-gh/gh; do
    check "shellcheck ${f#$REPO/}" shellcheck $f
  done
else
  skip "shellcheck" "shellcheck not installed"
fi

same "Brewfile has only brew/cask lines" \
  "$(grep -vnE '^[[:space:]]*(#.*)?$|^(brew|cask) "[^"]+"( if OS\.(mac|linux)\?)?$' $REPO/Brewfile)" ""

if have nvim; then
  print -r -- 'local f, err = loadfile(arg[1]); if not f then io.stderr:write(err, "\n"); os.exit(1) end' > $TMP/luacheck.lua
  for f in $REPO/nvim/.config/nvim/**/*.lua; do
    check "Lua parses: ${f#$REPO/}" nvim --clean --headless -l $TMP/luacheck.lua $f
  done
else
  skip "Lua syntax" "nvim not installed"
fi

if have python3 && python3 -c 'import tomllib' 2>/dev/null; then
  for f in $REPO/**/*.toml(D); do
    check "TOML parses: ${f#$REPO/}" python3 -c 'import sys, tomllib; tomllib.load(open(sys.argv[1], "rb"))' $f
  done
else
  skip "TOML syntax" "needs python3 3.11+"
fi

if have tmux; then
  check "tmux parses .tmux.conf" tmux -L dotfiles-test-$$ -f /dev/null start-server \; source-file -n $REPO/tmux/.tmux.conf
  tmux -L dotfiles-test-$$ kill-server 2>/dev/null
else
  skip "tmux config" "tmux not installed"
fi

# ─────────────────────────────────────────────────────────────
section "Stow"
# ─────────────────────────────────────────────────────────────
packages=( $REPO/*(/:t) )
packages=( ${packages:#tests} )
installed=( ${(z)$(sed -n 's/^for pkg in \(.*\); do$/\1/p' $REPO/install.sh)} )
same "install.sh stows exactly the package folders" "${(j: :)${(@o)installed}}" "${(j: :)${(@o)packages}}"

if have stow; then
  H=$TMP/stow-home && mkdir -p $H/.local/share/gh/extensions   # install.sh creates this first
  check "all packages stow into an empty home" stow -d $REPO -t $H $packages
  for f in .zshenv .config/zsh/.zshrc .config/nvim/init.lua .tmux.conf .gitconfig \
           .gitignore_global .config/starship.toml .config/alacritty/alacritty.toml \
           .local/share/gh/extensions/gh-ship/gh-ship; do
    p=$H/$f
    if [[ -e $p && ${p:A} == $REPO/* ]]; then pass "~/$f links into the repo"
    else fail "~/$f links into the repo" "$(ls -la $H/$f 2>&1)"; fi
  done
  [[ ! -L $H/.local && ! -L $H/.local/share/gh/extensions ]] \
    && pass "gh's extensions folder stays a real folder (only gh-ship is linked)" \
    || fail "gh's extensions folder stays a real folder (only gh-ship is linked)" "$(ls -la $H/.local $H/.local/share/gh 2>&1)"
  stow -d $REPO -t $H -D $packages

  # .stowrc: plain `stow <pkg>` from the repo should target $HOME
  H2=$TMP/stowrc-home && mkdir -p $H2
  out=$(cd $REPO && HOME=$H2 stow -n -v tmux 2>&1)
  if [[ $out == *"LINK: .tmux.conf"* && $out != *ERROR* ]]; then pass ".stowrc targets ~"
  else fail ".stowrc targets ~" "$out"; fi
else
  skip "stow checks" "stow not installed"
fi

# ─────────────────────────────────────────────────────────────
section "Shell startup"
# ─────────────────────────────────────────────────────────────
ZH=$TMP/zsh-home && mkdir -p $ZH/project/sub
ln -s $REPO/zsh/.zshenv $ZH/.zshenv
mkdir -p $ZH/.config && ln -s $REPO/zsh/.config/zsh $ZH/.config/zsh
dumps_before=( $REPO/zsh/.config/zsh/.zcompdump*(N) )

run_zsh() { (cd $ZH/project/sub && env HOME=$ZH EDITOR=nvim zsh -i -c "$1") }
err=$(run_zsh 'true' 2>&1 >/dev/null)
same "interactive startup prints no errors" "$err" ""
same "startup keeps the starting folder (WSL cd ~ is scoped)" "$(run_zsh 'print -r -- $PWD' 2>/dev/null)" "$ZH/project/sub"
same "emacs keys even with EDITOR=nvim inherited" "$(run_zsh 'bindkey -lL main' 2>/dev/null)" "bindkey -A emacs main"
same "functions are loaded" "$(run_zsh 'whence -w gitzip newrepo venv' 2>/dev/null)" \
  $'gitzip: function\nnewrepo: function\nvenv: function'
same "EDITOR/VISUAL come from .zshenv" "$(cd $ZH && env -u EDITOR -u VISUAL HOME=$ZH zsh -c 'print $EDITOR $VISUAL' 2>/dev/null)" "nvim nvim"
[[ -e $ZH/.cache/zsh/zcompdump ]] && pass "completion cache goes to ~/.cache/zsh" \
  || fail "completion cache goes to ~/.cache/zsh" "$(ls -la $ZH/.cache/zsh 2>&1)"
dumps_after=( $REPO/zsh/.config/zsh/.zcompdump*(N) )
same "no completion cache written into the repo" "${#dumps_after}" "${#dumps_before}"

# ─────────────────────────────────────────────────────────────
section "gitzip"
# ─────────────────────────────────────────────────────────────
source $REPO/zsh/.config/zsh/functions/gitzip.zsh

if ! have zip || ! have unzip; then
  skip "gitzip" "needs zip and unzip"
else
  GZ=$TMP/gitzip && mkdir -p $GZ && cd $GZ
  git init -q -b main demo && cd demo
  print one > a.txt; print x > '[a].txt'; print sp > 'with space.txt'
  print u > 'café.txt'; print q > 'quo"te.txt'; mkdir sub; print s > sub/s.txt
  ln -s a.txt link.txt; print -l .env '*.log' > .gitignore; print gone > doomed.txt
  git add -A && git commit -qm first
  print two >> a.txt && git commit -qam second
  git checkout -qb feature && print f > f.txt && git add f.txt && git commit -qm feature && git checkout -q main
  print staged > staged.txt && git add staged.txt   # staged
  print three >> a.txt                              # unstaged
  print new > new.txt                               # untracked
  print SECRET > .env; print noise > debug.log      # ignored
  rm doomed.txt                                     # deleted but still in the index
  mkdir -p .git/lfs/objects && print big > .git/lfs/objects/blob
  expected_status=$(git status --short)
  cd $GZ

  out=$(gitzip demo 2>&1)
  same "default mode reports the output" "$out" "→ $GZ/demo.zip ($(du -h $GZ/demo.zip | cut -f1))"
  mkdir full && (cd full && unzip -q ../demo.zip)
  same "unzipped copy has the same git status" "$(git -C full/demo status --short)" "$expected_status"
  same "history and branches came along" "$(git -C full/demo log --all --format=%s | sort | tr '\n' ' ')" "feature first second "
  check "odd filenames survive" test -e 'full/demo/café.txt' -a -e 'full/demo/quo"te.txt' -a -e 'full/demo/[a].txt' -a -e 'full/demo/with space.txt'
  check "symlinks stay symlinks" test -L full/demo/link.txt
  check "ignored files stay out" test ! -e full/demo/.env -a ! -e full/demo/debug.log
  check "deleted-but-tracked file is skipped" test ! -e full/demo/doomed.txt
  check ".git/lfs and sample hooks are left out" test ! -e full/demo/.git/lfs -a -z "$(ls full/demo/.git/hooks 2>/dev/null | grep sample)"

  gitzip demo --no-git -o tree >/dev/null
  same "--no-git has no .git entries" "$(unzip -Z1 tree.zip | grep -c '/\.git/')" "0"
  check "--no-git adds .zip to -o" test -e tree.zip

  gitzip demo --head -o head.zip >/dev/null
  same "--head is the committed HEAD" "$(unzip -z head.zip | tail -1)" "$(git -C demo rev-parse HEAD)"
  check "--head has no uncommitted files" test -z "$(unzip -Z1 head.zip | grep -E 'new.txt|staged.txt')"

  (cd demo/sub && gitzip -o $GZ/fromsub.zip >/dev/null)
  check "run from a subfolder zips the whole repo" test -n "$(unzip -Z1 fromsub.zip | grep '^demo/a.txt$')"

  (cd demo && gitzip >/dev/null && gitzip >/dev/null)
  same "a zip inside the repo never includes itself" "$(unzip -Z1 demo/demo.zip | grep -c 'demo.zip')" "0"
  rm demo/demo.zip

  out=$(cd $TMP && gitzip 2>&1); rc=$?
  same "outside a repo: fails with a message" "$rc: $out" "1: gitzip: '.' is not inside a git repository"

  git -C demo worktree add -q ../wt feature 2>/dev/null
  out=$(cd wt && gitzip 2>&1); rc=$?
  same "linked worktree: refuses the default mode" "$rc" "1"
  check "linked worktree: --head still works" zsh -c "cd $GZ/wt && source $REPO/zsh/.config/zsh/functions/gitzip.zsh && gitzip --head"
  cd $REPO
fi

# ─────────────────────────────────────────────────────────────
section "venv"
# ─────────────────────────────────────────────────────────────
source $REPO/zsh/.config/zsh/functions/venv.zsh
V=$TMP/venv && mkdir -p $V/one/sub $V/two $V/none
for p in one two; do
  mkdir -p $V/$p/.venv/bin
  # Stand-in for a real activate script: sets VIRTUAL_ENV, defines deactivate
  cat > $V/$p/.venv/bin/activate <<EOF
export VIRTUAL_ENV="$V/$p/.venv"
deactivate() { unset VIRTUAL_ENV; unset -f deactivate; (( deactivations++ )); }
EOF
done
typeset -gi deactivations=0

cd $V/one/sub && venv
same "activates the nearest .venv from a subfolder" "$VIRTUAL_ENV" "$V/one/.venv"
venv
same "running it again in the same project deactivates" "${VIRTUAL_ENV:-none}" "none"
venv; cd $V/two; venv
same "switches between projects" "$VIRTUAL_ENV" "$V/two/.venv"
same "switching deactivates the old one first" "$deactivations" "2"
venv off
same "venv off deactivates" "${VIRTUAL_ENV:-none}" "none"
out=$(venv off 2>&1)
same "venv off with nothing active says so" "$out" "venv: nothing active"
cd $V/none && out=$(venv 2>&1); rc=$?
same "no .venv anywhere: fails" "$rc" "1"
print '[project]' > pyproject.toml && out=$(venv 2>&1)
[[ $out == *"uv sync"* ]] && pass "suggests uv sync when there's a pyproject.toml" \
  || fail "suggests uv sync when there's a pyproject.toml" "$out"
cd $REPO

# ─────────────────────────────────────────────────────────────
section "newrepo"
# ─────────────────────────────────────────────────────────────
source $REPO/zsh/.config/zsh/functions/newrepo.zsh
NR=$TMP/newrepo && mkdir -p $NR && cd $NR

out=$(newrepo my-tool --no-sync -d 'Says "hi"' 2>&1); rc=$?
same "scaffolds and reports the folder" "$rc: $out" "0: → $NR/my-tool"
for f in pyproject.toml README.md LICENSE CHANGELOG.md .gitignore .gitattributes .editorconfig \
         .pre-commit-config.yaml .github/workflows/ci.yml .github/dependabot.yml \
         src/my_tool/__init__.py src/my_tool/main.py src/my_tool/config.py src/my_tool/__main__.py \
         src/my_tool/py.typed tests/test_main.py tests/conftest.py data/.gitkeep docs/.gitkeep .git; do
  [[ -e $NR/my-tool/$f ]] || missing+=($f)
done
same "creates every scaffold file" "${missing[*]:-}" ""
same "--no-sync makes no commit" "$(git -C my-tool rev-list --all 2>/dev/null | wc -l | tr -d ' ')" "0"
if have python3 && python3 -c 'import tomllib' 2>/dev/null; then
  same "pyproject.toml is valid and keeps quotes in the description" \
    "$(python3 -c 'import tomllib; p = tomllib.load(open("my-tool/pyproject.toml", "rb"))["project"]; print(p["name"], p["description"])')" \
    'my-tool Says "hi"'
fi
(cd $NR && newrepo clitool --no-sync --cli >/dev/null 2>&1)
if have python3; then
  check "generated Python parses (plain and --cli)" python3 -c '
import ast, pathlib, sys
for f in list(pathlib.Path("my-tool").rglob("*.py")) + list(pathlib.Path("clitool").rglob("*.py")):
    ast.parse(f.read_text(), str(f))'
fi
grep -q argparse $NR/clitool/src/clitool/main.py && pass "--cli adds an argparse CLI" || fail "--cli adds an argparse CLI"

out=$(newrepo my-tool --no-sync 2>&1); rc=$?
same "refuses an existing folder" "$rc" "1"
out=$(newrepo 1bad --no-sync 2>&1); rc=$?
same "rejects names that don't start with a letter" "$rc" "1"
cd $REPO

# ─────────────────────────────────────────────────────────────
section "gh ship"
# ─────────────────────────────────────────────────────────────
# tests/fake-gh/gh plays GitHub: a bare repo stands in for the remote, and
# files in $FAKE_GH set how slow GitHub is and which commits fail their checks.
FAST=$TMP/fast-sleep && mkdir -p $FAST
print -l '#!/bin/sh' 'exit 0' > $FAST/sleep && chmod +x $FAST/sleep

# ship_repo NAME [DEFAULT]: fresh "GitHub" plus a clone on branch `change`
# with one new commit; leaves you in the clone
ship_repo() {
  local default=${2:-main}
  export FAKE_GH=$TMP/ship-$1
  mkdir -p $FAKE_GH && : > $FAKE_GH/calls && print $default > $FAKE_GH/default
  git init -q --bare -b $default $FAKE_GH/remote.git
  git init -q -b $default $FAKE_GH/work && cd $FAKE_GH/work
  git remote add origin $FAKE_GH/remote.git
  print base > base.txt && git add base.txt && git commit -qm base && git push -q -u origin $default
  git switch -q -c change && print change > change.txt && git add change.txt && git commit -qm change
}
ship()  { PATH=$REPO/tests/fake-gh:$FAST:$PATH $SHIP "$@" 2>&1 }
calls() { grep -c -- "^$1" $FAKE_GH/calls }
last()  { print -r -- "${1##*$'\n'}" }
# what GitHub does when it squash-merges the PR (for the already-merged cases)
github_merges() {
  local w=$TMP/merge-$RANDOM
  git clone -q $FAKE_GH/remote.git $w
  (cd $w && git checkout -q main && git merge -q --squash origin/change && git commit -qm "change (#1)" && git push -q origin main) > /dev/null
  print MERGED > $FAKE_GH/state && print main > $FAKE_GH/base && git rev-parse change > $FAKE_GH/seen
}
done_msg="gh ship: change is merged and main is up to date"

ship_repo refuse
out=$(git switch -q main && ship); rc=$?
same "refuses on main" "$rc: $out" "1: gh ship: you're on main. Run it on the change's branch."
out=$(git switch -q --detach change && ship); rc=$?
same "refuses with no branch checked out" "$rc: $out" "1: gh ship: no branch checked out. Switch to the change's branch first."
same "...and touches nothing on GitHub" "$(calls 'pr ') $(git --git-dir=$FAKE_GH/remote.git branch --list change)" "0 "

ship_repo happy
print 2 > $FAKE_GH/head_lag; print 2 > $FAKE_GH/check_lag; print 2 > $FAKE_GH/merge_lag
out=$(ship); rc=$?
same "ships a new change" "$rc: $(last $out)" "0: $done_msg"
same "ends on main with the change pulled and the branch deleted" \
  "$(git branch --show-current) $(cat change.txt) $(git branch --list change)" "main change "
same "opens one PR and turns on auto-merge once" "$(calls 'pr create') $(calls 'pr merge')" "1 1"
same "polls while GitHub catches up (head, checks, merge)" \
  "$(calls 'pr view change --json headRefOid') $(calls 'pr view change --json statusCheckRollup') $(calls 'pr view change --json state,mergeable')" \
  "3 3 3"
same "watches the checks only after they're registered" \
  "$(grep -n -E '^pr (checks|view change --json statusCheckRollup)' $FAKE_GH/calls | tail -1 | cut -d: -f2)" "pr checks change --watch --fail-fast"

ship_repo fail
git rev-parse HEAD > $FAKE_GH/failing
out=$(ship); rc=$?
same "a failed check exits non-zero and says so" "$rc: $(last $out)" \
  "1: gh ship: a check failed. Fix it, commit, and run gh ship again."
same "...and nothing merges" "$(git branch --show-current) $(cat $FAKE_GH/state) $(git --git-dir=$FAKE_GH/remote.git ls-tree --name-only main)" "change OPEN base.txt"
print fixed > change.txt && git commit -qam fix
out=$(ship); rc=$?
same "after a fix, a rerun pushes it and finishes" "$rc: $(last $out)" "0: $done_msg"
same "...reusing the PR and its auto-merge" "$(calls 'pr create') $(calls 'pr merge') $(cat change.txt)" "1 1 fixed"

ship_repo merged
git push -q -u origin change && github_merges && : > $FAKE_GH/calls
out=$(ship); rc=$?
same "already merged: goes straight to cleanup" "$rc: $(last $out)" "0: $done_msg"
same "...without touching the PR" "$(calls 'pr create') $(calls 'pr merge') $(calls 'pr checks')" "0 0 0"
same "...ending on main with the change" "$(git branch --show-current) $(cat change.txt)" "main change"

ship_repo extra
git push -q -u origin change && github_merges
print more > more.txt && git add more.txt && git commit -qm more
out=$(ship); rc=$?
same "already merged but the branch has new commits: keeps the branch" \
  "$rc $(git branch --show-current)" "1 change"

ship_repo trunk trunk
out=$(git switch -q trunk && ship); rc=$?
same "reads the default branch from GitHub (refuses on trunk)" "$rc: $out" "1: gh ship: you're on trunk. Run it on the change's branch."
out=$(git switch -q change && ship); rc=$?
same "...and lands the change on it" "$rc $(git branch --show-current) $(cat change.txt)" "0 trunk change"

ship_repo conflict
print CONFLICTING > $FAKE_GH/mergeable; print 5 > $FAKE_GH/merge_lag
out=$(ship); rc=$?
same "a merge conflict stops the wait with instructions" "$rc: $(last $out)" \
  "1: gh ship: the PR conflicts with main. Merge main into change, commit, and run gh ship again."

ship_repo stuck
print 1000 > $FAKE_GH/check_lag
out=$(GH_SHIP_TIMEOUT=20 ship); rc=$?
same "checks that never start: gives up with a message" "$rc: $(last $out)" \
  "1: gh ship: GitHub still hasn't started any checks after 20s. Check the PR on GitHub, then run gh ship again."

# Interrupt a real wait (real sleep). A script's background job can't get
# SIGINT, so SIGTERM stands in for Ctrl-C: either way the script just dies mid-poll.
ship_repo interrupt
print 1000 > $FAKE_GH/head_lag
(PATH=$REPO/tests/fake-gh:$PATH exec $SHIP >/dev/null 2>&1) &
pid=$!
sleep 3; kill $pid 2>/dev/null; wait $pid 2>/dev/null
same "interrupted mid-wait: still on the branch, nothing merged" \
  "$(git branch --show-current) $(cat $FAKE_GH/state) $(git --git-dir=$FAKE_GH/remote.git ls-tree --name-only main)" "change OPEN base.txt"
print 0 > $FAKE_GH/head_lag && rm -f $FAKE_GH/head.left
out=$(ship); rc=$?
same "...and a rerun finishes" "$rc: $(last $out)" "0: $done_msg"
cd $REPO

if have gh; then
  GH_HOME=$TMP/gh-home && mkdir -p $GH_HOME/.local/share/gh/extensions
  ln -s ${SHIP:h} $GH_HOME/.local/share/gh/extensions/gh-ship   # what Stow creates
  same "gh itself finds and runs the extension" \
    "$(cd $TMP && env -u XDG_DATA_HOME HOME=$GH_HOME GH_CONFIG_DIR=$GH_HOME/.config/gh GH_TOKEN=unused gh ship --help 2>&1)" \
    "usage: gh ship   (run on a change's branch after committing)"
else
  skip "gh finds the extension" "gh not installed"
fi

CS=$TMP/codespace && mkdir -p $CS
for run in first second; do
  out=$(cd $TMP && env -u XDG_DATA_HOME HOME=$CS CODESPACES=true bash $REPO/install.sh 2>&1); rc=$?
  link=$CS/.local/share/gh/extensions/gh-ship
  same "Codespaces install ($run run) links gh ship and stops" "$rc ${link:A}" "0 ${SHIP:h}"
done

# ─────────────────────────────────────────────────────────────
section "Docs"
# ─────────────────────────────────────────────────────────────
sheet=$(<$REPO/CHEATSHEET.md)
zfiles=( $REPO/zsh/.config/zsh/.zshrc $REPO/zsh/.config/zsh/functions/*.zsh )
funcs=( ${(f)"$(sed -n 's/^\([a-z_][a-z0-9_-]*\)() {.*/\1/p' $zfiles)"} )
alias_names=( ${(f)"$(sed -n 's/^ *alias \([a-z0-9_-]*\)=.*/\1/p' $zfiles)"} )
maps=( ${(f)"$(grep -oE 'map\(("[a-z]+"|\{[^}]*\}), "[^"]+"' $REPO/nvim/.config/nvim/lua/keymaps.lua | sed -E 's/.*, "([^"]+)"$/\1/')"} )

extensions=( $REPO/gh/.local/share/gh/extensions/gh-*(N:t) )
undocumented=()
for name in $funcs $alias_names $maps ${extensions/#gh-/gh }; do
  [[ $sheet == *"\`$name\`"* ]] || undocumented+=($name)
done
same "every function, alias, gh extension and Neovim mapping is in CHEATSHEET.md" "${undocumented[*]:-}" ""

stale=()
for key in ${(u)${(f)"$(grep -oE '`<leader>[^`]+`' $REPO/CHEATSHEET.md | tr -d '`')"}}; do
  (( ${maps[(Ie)$key]} )) || stale+=($key)
done
same "every <leader> mapping in CHEATSHEET.md exists" "${stale[*]:-}" ""

# ─────────────────────────────────────────────────────────────
section "Neovim startup"
# ─────────────────────────────────────────────────────────────
if (( ! with_nvim )); then
  skip "Neovim startup" "run with --nvim"
elif ! have nvim || ! have git; then
  skip "Neovim startup" "needs nvim and git"
else
  NH=$TMP/nvim-home && mkdir -p $NH/.config $NH/project
  cp -R $REPO/nvim/.config/nvim $NH/.config/nvim   # a copy, so lazy-lock.json stays untouched
  print 'local x = 1' > $NH/project/test.lua
  cd $NH/project
  check "plugins install at the lockfile versions" \
    env -u XDG_CONFIG_HOME -u XDG_DATA_HOME -u XDG_STATE_HOME -u XDG_CACHE_HOME HOME=$NH \
    nvim --headless "+Lazy! restore" +qa
  print -r -- '
local errs = {}
if vim.g.colors_name ~= "catppuccin-latte" then table.insert(errs, "plugins did not load (colorscheme: " .. tostring(vim.g.colors_name) .. ")") end
if vim.v.errmsg ~= "" then table.insert(errs, vim.v.errmsg) end
for _, line in ipairs(vim.split(vim.fn.execute("messages"), "\n")) do
  if line:match("E%d+:") or line:match("[Ee]rror") then table.insert(errs, line) end
end
if #errs > 0 then io.stderr:write(table.concat(errs, "\n"), "\n"); vim.cmd("cquit 1") end
vim.cmd("qa!")' > $TMP/nvimcheck.lua
  check "opens a file without errors" \
    env -u XDG_CONFIG_HOME -u XDG_DATA_HOME -u XDG_STATE_HOME -u XDG_CACHE_HOME HOME=$NH \
    nvim --headless test.lua -c "luafile $TMP/nvimcheck.lua"
  cd $REPO
fi

# ─────────────────────────────────────────────────────────────
print -r -- $'\n'"$B$passed passed, $failed failed, $skipped skipped$N"
(( failed == 0 ))
