#!/bin/sh
# tmux-toast.sh - show a transient notification in a tmux floating pane.
# Usage: tmux-toast.sh [-l error|warn|ok|info] [-d seconds] [-w width]
#                     [-s style] line [line...]
#
# Needs tmux 3.7+ (the new-pane command). The pane is created detached so it
# never steals focus. It is anchored to the bottom right corner; floating panes
# do not re-anchor on resize, but a toast is short lived enough not to care.

dur=4; wid=34; lvl=info; sty=
while getopts d:w:s:l: o; do
  case $o in
    d) dur=$OPTARG ;; w) wid=$OPTARG ;; s) sty=$OPTARG ;; l) lvl=$OPTARG ;;
    ?) exit 2 ;;
  esac
done
shift $((OPTIND - 1))
[ $# -gt 0 ] || exit 0

# The level backgrounds all sit at the luminance of the error tone, so every
# toast carries the same visual weight and only the hue signals severity.
case $lvl in
  info)  bg='#11151c' ;;
  ok)    bg='#0e2518' ;;
  warn)  bg='#291f0f' ;;
  error) bg='#3a1518' ;;
  *) printf 'tmux-toast: unknown level "%s" (use error, warn, ok or info)\n' \
       "$lvl" >&2; exit 2 ;;
esac
# An explicit -s wins over -l regardless of the order they were given in.
[ -n "$sty" ] || sty="bg=$bg,fg=colour223"

# No trailing newline: one extra line would scroll the content out of view.
f=$(mktemp -t toast); n=$#
{ printf ' %s' "$1"; shift
  for l in "$@"; do printf '\n %s' "$l"; done; } > "$f"

# Dismiss whatever toast is still up in this window.
tmux list-panes -F '#{pane_id} #{@toast}' | awk '$2 == "1" { print $1 }' |
  while read -r p; do tmux kill-pane -t "$p" 2>/dev/null; done

# -x/-y size the content, so the border adds one cell on each side. The offsets
# leave a 2 column / 1 line margin, which reads as even given cell proportions.
id=$(tmux new-pane -d -P -F '#{pane_id}' \
  -x "$wid" -y "$n" \
  -X "#{e|-:#{window_width},$((wid + 3))}" \
  -Y "#{e|-:#{window_height},$((n + 2))}" \
  -s "$sty" -R "$sty" \
  sh -c "cat '$f'; rm -f '$f'; exec sleep 2147483647") || { rm -f "$f"; exit 1; }
tmux set -p -t "$id" @toast 1

# Removed from outside on purpose: a pane whose own command exits fires the
# pane-exited hook, so a toast wired to that hook would retrigger itself.
tmux run-shell -b -d "$dur" -C "kill-pane -t $id"
