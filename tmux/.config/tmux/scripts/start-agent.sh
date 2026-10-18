#!/bin/sh
# start-agent.sh - run an agent as the command of a tmux pane, set up as an agent window.
# Usage: start-agent.sh claude|codex [agent args...]
#
# Prefix+F1/F2 open new windows with it, and resuming a session runs it wherever the session
# goes, so every agent window gets the same options and the same close-on-exit wait. The
# window is configured from inside the pane because a respawned pane has no binding to do it.

case "$1" in
	claude) tool=claude ;;
	codex) tool=codex ;;
	*)
		printf 'Usage: %s claude|codex [agent args...]\n' "${0##*/}" >&2
		exit 64
		;;
esac
shift

# Agent windows show the whole pane title (see style.conf) and flag 5 minutes of silence.
if [ -n "$TMUX_PANE" ]; then
	tmux set -w -t "$TMUX_PANE" monitor-silence 300 \; \
		set -w -t "$TMUX_PANE" @full_title 1 || true
fi

# mise's shims go ahead of the tool directories activated in the server's PATH: they pick
# each project's version from the directory a command runs in, so the agent's commands
# need no `mise exec --`.
PATH=${MISE_DATA_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/mise}/shims:$PATH
export PATH

case "$tool" in
	codex) set -- --no-daemon "$@" ;;
esac
exec "$(dirname -- "$0")/wait-before-close.sh" "$tool" "$@"
