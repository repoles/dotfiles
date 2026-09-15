#!/bin/sh
# agent-tmux-status.sh - drive the tmux window status from agent hooks.
# Usage: agent-tmux-status.sh <event>
#   busy     working     -> green   (UserPromptSubmit, PostToolUse)
#   waiting  needs input -> yellow  (PermissionRequest)
#   error    failed      -> red     (PostToolUseFailure, StopFailure)
#   idle     done        -> reset   (Stop, SessionEnd)

[ -n "$TMUX_PANE" ] || exit 0

# select-agent-window.sh reads these stamps to tell when each agent last did something. no tmux
# timestamp can say that: session_set_current bumps window_activity on a mere visit, and
# entering a session makes claude and codex rewrite their terminal modes, a write the pane
# tty's mtime cannot tell from real output. a hook fires only when the agent itself acts
stamps="${XDG_CACHE_HOME:-$HOME/.cache}/tmux-agent-activity"
mkdir -p "$stamps" && date +%s > "$stamps/$TMUX_PANE"

case "$1" in
	busy)    tmux set  -w -t "$TMUX_PANE" window-status-style 'fg=green'  ;;
	waiting) tmux set  -w -t "$TMUX_PANE" window-status-style 'fg=yellow' ;;
	error)   tmux set  -w -t "$TMUX_PANE" window-status-style 'fg=red'    ;;
	idle)
		tmux set -uw -t "$TMUX_PANE" window-status-style
		# a pane leaves no hook behind when it dies, so the stamps of the ones that are gone
		# are swept here, on the event that ends a turn rather than on every tool call
		# keep the stamps if tmux cannot tell us which panes are still alive
		live=$(tmux list-panes -a -F '#{pane_id}') || exit 1
		for stamp in "$stamps"/*; do
			[ -e "$stamp" ] || continue
			printf '%s\n' "$live" | grep -qxF "${stamp##*/}" || rm -f "$stamp"
		done
		;;
esac
