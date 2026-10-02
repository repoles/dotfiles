#!/bin/sh
# agent-tmux-session.sh - track agent sessions started in tmux that have not ended yet.
# Usage: agent-tmux-session.sh <tool> start|stop|end   (hook payload JSON on stdin)
#   start  UserPromptSubmit  write or refresh the record
#   stop   Stop              refresh the pane of an existing record
#   end    SessionEnd        remove it
#
# Each record is $XDG_STATE_HOME/tmux-agent-sessions/<session_id>.json. A session counts
# from its first prompt for both agents: Codex only fires SessionStart then, while Claude
# fires it as soon as it opens, so a prompt is the common ground.
#
# The records live in state, not cache, and nothing sweeps them: a file left behind by a
# crash, a killed pane or a reboot is exactly a session that never concluded. tmux-resurrect
# restores session names and window/pane indexes, so those locate it again afterwards.

# Only a session running in tmux has a pane to record. Ending is the exception: a session
# recorded in tmux can be resumed in another terminal and end there.
[ -n "$TMUX_PANE" ] || [ "$2" = end ] || exit 0

tool=$1
action=$2
input=$(cat)
session_id=$(printf '%s' "$input" | jq -r '.session_id // empty') || exit 1
# The ID becomes a file name, so it must not be able to leave the directory.
case "$session_id" in
	''|*[!A-Za-z0-9_-]*) exit 1 ;;
esac

sessions="${XDG_STATE_HOME:-$HOME/.local/state}/tmux-agent-sessions"
record="$sessions/$session_id.json"

case "$action" in
	start|stop) ;;
	end) rm -f -- "$record"; exit ;;
	*) exit 1 ;;
esac

[ -n "$tool" ] || exit 1

# Every prompt refreshes where the session runs and when it was last prompted, but keeps
# when it began. The end of a turn refreshes only the pane: by then the agent has usually
# renamed its title after the conversation. Epoch seconds, like tmux's own times.
if [ "$action" = stop ]; then
	# Nothing to refresh without a prompt recorded first.
	[ -f "$record" ] || exit 0
	last_prompt_at=$(jq -r '.last_prompt_at | numbers' "$record" 2>/dev/null)
fi
started_at=$(jq -r '.started_at | numbers' "$record" 2>/dev/null)
now=$(date +%s) || exit 1
case "$last_prompt_at" in
	''|*[!0-9]*) last_prompt_at=$now ;;
esac
case "$started_at" in
	''|*[!0-9]*) started_at=$last_prompt_at ;;
esac

# Hooks run a shell or two below the agent: walk up to the agent's own process, so a
# running session can be told from one that died with its record in place. Its start time
# guards against the PID being reused after a reboot.
agent_pid=null
agent_started_at=null
pid=$PPID
depth=0
while [ "$depth" -lt 10 ]; do
	line=$(ps -o ppid= -o comm= -p "$pid") || break
	line=${line#"${line%%[! ]*}"}
	ppid=${line%% *}
	comm=${line#* }
	if [ "${comm##*/}" = "$tool" ]; then
		# lstart pads with spaces; word splitting collapses them for date.
		set -- $(LC_ALL=C ps -o lstart= -p "$pid")
		started=$(LC_ALL=C date -j -f '%a %b %e %T %Y' "$*" +%s 2>/dev/null)
		case "$started" in
			''|*[!0-9]*) ;;
			*) agent_pid=$pid agent_started_at=$started ;;
		esac
		break
	fi
	case "$ppid" in
		''|*[!0-9]*|0|1) break ;;
	esac
	pid=$ppid
	depth=$((depth + 1))
done

# Unit separators, because a pane title can contain spaces, tabs and colons.
us=$(printf '\037')
pane=$(tmux display-message -p -t "$TMUX_PANE" \
	"#{session_name}$us#{window_index}$us#{window_name}$us#{pane_index}$us#{pane_title}") || exit 1

mkdir -p "$sessions" || exit 1
tmp=$(mktemp "$sessions/.$session_id.XXXXXX") || exit 1
if printf '%s' "$input" | jq \
	--arg tool "$tool" --arg pane "$pane" --argjson started_at "$started_at" \
	--argjson last_prompt_at "$last_prompt_at" --argjson agent_pid "$agent_pid" \
	--argjson agent_started_at "$agent_started_at" '
	($pane | split("\u001f")) as [$session, $window_index, $window_name, $pane_index, $pane_title]
	| {
		tool: $tool,
		session_id,
		cwd,
		tmux_session: $session,
		window_index: ($window_index | tonumber),
		window_name: $window_name,
		pane_index: ($pane_index | tonumber),
		pane_title: $pane_title,
		started_at: $started_at,
		last_prompt_at: $last_prompt_at,
		agent_pid: $agent_pid,
		agent_started_at: $agent_started_at
	}' > "$tmp" && mv -f -- "$tmp" "$record"; then
	exit 0
fi
rm -f -- "$tmp"
exit 1
