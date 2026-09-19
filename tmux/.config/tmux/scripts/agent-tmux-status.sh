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
# tty's mtime cannot tell from real output. a hook fires only when the agent itself acts.
# Namespace by this server lifetime so another tmux server cannot overwrite or sweep them.
server_instance=$(tmux display-message -p -t "$TMUX_PANE" '#{start_time}-#{pid}') || exit 1
case "$server_instance" in
	''|*[!0-9-]*|*-*-*|-*|*-) exit 1 ;;
	*-*) ;;
	*) exit 1 ;;
esac
stamp_root="${XDG_CACHE_HOME:-$HOME/.cache}/tmux-agent-activity"
stamps="$stamp_root/$server_instance"
mkdir -p "$stamps" && date +%s > "$stamps/$TMUX_PANE"

case "$1" in
	busy)    tmux set  -w -t "$TMUX_PANE" window-status-style 'fg=green'  ;;
	waiting) tmux set  -w -t "$TMUX_PANE" window-status-style 'fg=yellow' ;;
	error)   tmux set  -w -t "$TMUX_PANE" window-status-style 'fg=red'    ;;
	idle)
		tmux set -uw -t "$TMUX_PANE" window-status-style
		# Pane IDs are local to a server, so never infer dead panes from another server's
		# inventory. Remove a whole foreign namespace only after its server PID is gone.
		for instance_dir in "$stamp_root"/*-*; do
			[ -d "$instance_dir" ] || continue
			instance=${instance_dir##*/}
			case "$instance" in
				''|*[!0-9-]*|*-*-*|-*|*-) continue ;;
				*-*) ;;
				*) continue ;;
			esac
			[ "$instance" = "$server_instance" ] && continue
			server_pid=${instance##*-}
			kill -0 "$server_pid" 2>/dev/null && continue
			rm -rf -- "$instance_dir"
		done
		;;
esac
