#!/bin/sh
# agent-tmux-hook.sh - dispatch an agent event to the tmux integrations.
# Usage: agent-tmux-hook.sh <event>
#            Claude                          Codex
#   busy     UserPromptSubmit, PostToolUse   UserPromptSubmit, PostToolUse, SessionStart
#   waiting  PermissionRequest               PermissionRequest
#   error    PostToolUseFailure, StopFailure -
#   idle     Stop, SessionStart, SessionEnd  Stop, SessionEnd

[ -n "$TMUX_PANE" ] || exit 0

scripts=$(dirname "$0")
failed=0

# Keep the integrations independent: a broken activity cache must not prevent
# the window status from reflecting the same event, or vice versa.
"$scripts/agent-tmux-activity.sh" "$1" || failed=1
"$scripts/agent-tmux-status.sh" "$1" || failed=1

exit "$failed"
