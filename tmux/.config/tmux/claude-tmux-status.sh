#!/bin/sh
# claude-tmux-status.sh — drive the tmux window status from Claude Code hooks.
# Usage: claude-tmux-status.sh <event>
#   busy     working     -> green   (UserPromptSubmit, PostToolUse)
#   waiting  needs input -> yellow  (PermissionRequest)
#   error    failed      -> red     (PostToolUseFailure, StopFailure)
#   idle     done        -> reset   (Stop, SessionEnd)
#   notify   forward the notification message to unattended/inactive panes

[ -n "$TMUX_PANE" ] || exit 0

case "$1" in
	busy)    tmux set  -w -t "$TMUX_PANE" window-status-style 'fg=green'  ;;
	waiting) tmux set  -w -t "$TMUX_PANE" window-status-style 'fg=yellow' ;;
	error)   tmux set  -w -t "$TMUX_PANE" window-status-style 'fg=red'    ;;
	idle)    tmux set -uw -t "$TMUX_PANE" window-status-style             ;;
	notify)
		state=$(tmux display-message -p -t "$TMUX_PANE" -F "#{session_attached}.#{window_active}")
		case "$state" in
			0.*|*.0) tmux display-message -t "$TMUX_PANE" "[#S] #I:#W > $(jq -r .message)" ;;
		esac
		;;
esac
