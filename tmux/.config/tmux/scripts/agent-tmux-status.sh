#!/bin/sh
# agent-tmux-status.sh - drive the tmux window status for an agent event.
# Usage: agent-tmux-status.sh <event>
#   busy     working     -> green
#   waiting  needs input -> yellow
#   error    failed      -> red
#   idle     done        -> reset

[ -n "$TMUX_PANE" ] || exit 0

case "$1" in
	busy)    tmux set  -w -t "$TMUX_PANE" window-status-style 'fg=green'  ;;
	waiting) tmux set  -w -t "$TMUX_PANE" window-status-style 'fg=yellow' ;;
	error)   tmux set  -w -t "$TMUX_PANE" window-status-style 'fg=red'    ;;
	idle)    tmux set -uw -t "$TMUX_PANE" window-status-style             ;;
esac
