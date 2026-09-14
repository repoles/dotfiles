#!/bin/sh
# claude-tmux-notify.sh - raise a tmux toast for a Claude Code notification.
# Usage: claude-tmux-notify.sh   (the hook's JSON payload arrives on stdin)
#
# Wired to Claude Code's Notification hook, which is what fires when the agent
# wants the user back: a permission request, a turn left waiting on input, or a
# subagent asking or finishing. Codex's hook set carries no equivalent event;
# what it has instead is the notify program named in its own config.toml, a
# separate channel on a payload of its own. So the two cannot share this the
# way they share agent-tmux-status.sh, and the name says which one it serves:
# the fields read below are Claude's payload alone.
#
# The hook carries a matcher that narrows the sixteen notification types down
# to those five. Twelve of them are the documented set; the other four are only
# in the binary, and one of those, worker_permission_prompt, is why the matcher
# names a fifth type: a worker parked on a permission or a host it cannot reach
# is asking precisely what permission_prompt asks, in the words of the teammate
# rather than the tool. The rest are noise for a toast whose whole job is to
# say which window wants you: auth_success and the three quota_auto_resume ones
# ask for nothing, push_notification and the two computer_use ones report on a
# channel that is already reaching you elsewhere, and of the four elicitation
# ones, two fire after you have answered. The two that are left,
# elicitation_dialog and elicitation_url_dialog, do hold work up on an answer,
# so they belong with the warn types below if the matcher is ever widened to
# let them through.

[ -n "$TMUX_PANE" ] || exit 0

# Named against the pane the hook fired in rather than at display time: the
# toast is raised in the window the user is watching, and the whole point of
# this line is to say which other one is asking.
origin=$(tmux display-message -p -t "$TMUX_PANE" '[#S] #I:#W') || exit 1

# Held whole so the two fields come from one read of stdin. They are asked for
# separately because a message may carry newlines of its own, which leaves no
# way to tell the two apart in a single stream once either one is empty.
payload=$(cat)
type=$(printf '%s' "$payload" | jq -r '.notification_type // empty' 2>/dev/null)
message=$(printf '%s' "$payload" | jq -r '.message // empty' 2>/dev/null)

# Only hue tells one toast from another, so it is spent on what is being asked
# rather than on which event arrived. warn is work standing still on a
# decision of yours, the same yellow agent-tmux-status.sh paints the window
# status on a permission request. ok is the ✓ of something finished, the tone
# a completed command already takes. idle_prompt is neither: it is a turn that
# ended a minute ago (messageIdleNotifThresholdMs, 60s by default) and was
# left alone since, because a keypress after it cancels the notification, so
# nothing is held up and it reports at the tone of the unknown types rather
# than shouting alongside the blocking ones. info is the default because a
# type this script does not know is one it cannot call urgent, and
# under-toning loses nothing: the colour of the window status says the rest.
case $type in
	permission_prompt|worker_permission_prompt|agent_needs_input) level=warn; fallback='waiting on you' ;;
	agent_completed)                                              level=ok;   fallback='the subagent is done' ;;
	idle_prompt)                                                  level=info; fallback='waiting on you' ;;
	# The type carries more than any wording invented here could, and it shows
	# only when the payload named no message of its own.
	*)                                                            level=info; fallback="${type:-the agent called}" ;;
esac

# An empty message still earns a toast: the colour of the window status says
# what kind of attention is wanted, and the toast is there to say which window
# wants it. jq is needed on this path alone, so a host without it loses the
# wording and the tone and nothing else.
[ -n "$message" ] || message=$fallback

# Held longer than the 4s a status line message gets: the agent notifies
# precisely when it has already been waiting a while. -o leaves the toast to
# decide whether the user is somewhere else and so wants telling at all, since
# answering that means knowing which window they are on, which is the same
# thing the toast has to know to raise itself where they will read it.
"$(dirname "$0")/tmux-toast.sh" -o "$TMUX_PANE" -l "$level" -d 8 "$message" "$origin"

# 3 is the toast held back because the user is already there, which is this
# hook working as intended; a hook exiting non-zero is reported as having
# failed, so only a real failure is passed on.
status=$?
[ "$status" = 3 ] && exit 0
exit "$status"
