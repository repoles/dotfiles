#!/bin/sh
# start-remote-claude.sh - open Claude Code with remote control in a new window of a tmux session.
# Usage: start-remote-claude.sh <session>
#
# Meant to run without a terminal, e.g. from Hazel or over ssh: like the fish function tat, it creates a
# missing session in the directory zoxide finds for its name, but it never attaches to it.
# The window opens like Prefix+F1's, through start-agent.sh, and its target is printed.

if [ $# -ne 1 ] || [ -z "$1" ]; then
	printf 'Usage: %s <session>\n' "${0##*/}" >&2
	exit 64
fi
session=$1

# Resolve the link in ~/.local/bin to find start-agent.sh next to this script.
scripts=$(dirname -- "$(realpath -- "$0")") || exit

# tmux gives a window opened by a detached client that client's PATH, and callers like Hazel
# run with a bare one. Take the server's, as Prefix+F1 windows get, or with no server running
# add the directories of zoxide and claude, so the server this script starts can find them.
PATH=$PATH:$HOME/.local/bin:/opt/homebrew/bin
server_path=$(tmux show-environment -g PATH 2>/dev/null)
case "$server_path" in
	PATH=*) PATH=${server_path#PATH=} ;;
esac
export PATH

# The = matches the name exactly; a bare name also matches a session it is a prefix of.
if ! tmux has-session -t "=$session" 2>/dev/null; then
	dir=$(zoxide query -- "$session") || exit
	tmux new-session -d -s "$session" -c "$dir" || exit
fi

# -d keeps the session on its current window. Without -c, the window would start in the
# directory this script runs from.
exec tmux new-window -d -P -F '#{session_name}:#{window_index}' -t "=$session:" \
	-c '#{session_path}' -n claude \
	"exec '$scripts/start-agent.sh' claude --permission-mode auto --remote-control"
