# termsize — Alacritty opens every window at one size and keeps no memory of
# the last. This remembers the size last used on each display, so a window
# opens small on the laptop's own screen and at whatever was last used at the
# dock, and neither disturbs the other.
#
#   termsize          the display in front, the size saved for it, this window's size
#   termsize save     save this window's size for the display in front, now
#   termsize forget   forget that display's size (back to 80 by 24)
#
# How: alacritty.toml imports ~/.local/state/alacritty/size.toml, which holds
# [window.dimensions]. Inside Alacritty, a resize marks the shell; two seconds
# after the last one (while it waits at a prompt), or at its next prompt, the
# window's size is saved under the display's resolution and size.toml is
# rewritten, so closing the window right after a resize still keeps it. Each prompt also checks, at most once a minute and
# in the background, which display is in front, and rewrites size.toml for it.
# A resize that arrives together with a change of display is the system
# moving the window (undocking), not a choice, and isn't saved.
#
# Limits: the first window after docking or undocking may open at the other
# display's size; the window's position isn't remembered; off macOS there is
# one key, "default", so it is simply the last size used.

zmodload zsh/datetime zsh/sched

typeset -g _termsize_dir=$HOME/.local/state/alacritty
typeset -g _termsize_key=
typeset -gi _termsize_dirty=0 _termsize_checked=0 _termsize_prompts=0 _termsize_resized=0

termsize() {
  local dir=$_termsize_dir key size text
  case ${1:-show} in
    display)  # the display with the focused window, as WIDTHxHEIGHT in points
      if (( $+commands[osascript] )); then
        key=$(osascript -l JavaScript -e 'ObjC.import("AppKit"); var f = $.NSScreen.mainScreen.frame; Math.round(f.size.width) + "x" + Math.round(f.size.height)' 2>/dev/null)
      fi
      [[ $key == <->x<-> ]] || key=default
      print -r -- $key
      ;;
    size)  # this window's columns and lines: a tmux pane is smaller than its window
      if [[ -n ${TMUX-} ]] && (( $+commands[tmux] )); then
        size=$(tmux display-message -p '#{client_width} #{client_height}' 2>/dev/null)
      fi
      [[ $size == <->\ <-> ]] || size="$COLUMNS $LINES"
      print -r -- $size
      ;;
    apply)  # write size.toml for a display: its saved size, or 80 by 24
      key=${2:-$(termsize display)}
      [[ -r $dir/size-$key ]] && size=$(<$dir/size-$key)
      [[ $size == <->\ <-> ]] || size="80 24"
      text="# Written by termsize (dotfiles): the size last used on the display $key."$'\n'"[window.dimensions]"$'\n'"columns = ${size% *}"$'\n'"lines = ${size#* }"
      mkdir -p $dir || return 1
      [[ -r $dir/size.toml && "$(<$dir/size.toml)" == "$text" ]] && return 0
      print -r -- "$text" >| $dir/size.toml.new && mv -f $dir/size.toml.new $dir/size.toml
      ;;
    save)
      key=${2:-$(termsize display)}
      size=$(termsize size)
      if (( ${size% *} < 20 || ${size#* } < 5 )); then
        print -u2 "termsize: ${size% *} by ${size#* } is too small to be a window's size; not saved"
        return 1
      fi
      mkdir -p $dir && print -r -- $size >| $dir/size-$key && termsize apply $key
      ;;
    forget)
      key=${2:-$(termsize display)}
      rm -f $dir/size-$key && termsize apply $key
      ;;
    show)
      key=$(termsize display)
      size=$(termsize size)
      if [[ -r $dir/size-$key ]]; then
        text=$(<$dir/size-$key)
        print -r -- "display $key: ${text% *} by ${text#* } saved; this window is ${size% *} by ${size#* }"
      else
        print -r -- "display $key: nothing saved (80 by 24); this window is ${size% *} by ${size#* }"
      fi
      ;;
    *)
      print -u2 "usage: termsize [save | forget]"
      return 2
      ;;
  esac
}

# A resize, kept: the window's size under the display in front, unless the
# display changed too. Quiet, since it can run while the prompt is on screen
_termsize_settle() {
  local now seen=$_termsize_dir/display
  (( _termsize_dirty )) || return 0
  _termsize_dirty=0
  # a shell this new has only the last shell's word for the display: take the latest
  (( _termsize_prompts <= 2 )) && [[ -r $seen ]] && _termsize_key=$(<$seen)
  now=$(termsize display)
  [[ $now == $_termsize_key ]] && termsize save $now 2>/dev/null
  _termsize_key=$now _termsize_checked=$EPOCHSECONDS
  mkdir -p $_termsize_dir && print -r -- $now >| $seen
  termsize apply $now
}

# Two seconds after a resize: a drag sends many, and only the last one's timer saves
_termsize_after_resize() {
  (( EPOCHSECONDS - _termsize_resized >= 2 )) && _termsize_settle
  return 0
}

# Runs before each prompt, inside Alacritty only
_termsize_prompt() {
  local seen=$_termsize_dir/display
  (( _termsize_prompts++ ))
  if (( _termsize_dirty )); then
    _termsize_settle
    return 0
  fi
  if (( EPOCHSECONDS - _termsize_checked >= 60 )); then
    _termsize_checked=$EPOCHSECONDS
    ( now=$(termsize display); mkdir -p $_termsize_dir && print -r -- $now >| $seen; termsize apply $now ) &!
  fi
  [[ -r $seen ]] && _termsize_key=$(<$seen)
  return 0
}

if [[ -o interactive && -z ${SSH_CONNECTION-} ]] && [[ -n ${ALACRITTY_WINDOW_ID-} || $TERM == alacritty* ]]; then
  autoload -Uz add-zsh-hook
  add-zsh-hook precmd _termsize_prompt
  TRAPWINCH() { _termsize_dirty=1 _termsize_resized=$EPOCHSECONDS; sched +2 _termsize_after_resize }
fi
