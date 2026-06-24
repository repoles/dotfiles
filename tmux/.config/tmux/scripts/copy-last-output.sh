#!/usr/bin/env bash
#
# Copy the output of the last executed command in a pane to the macOS clipboard.
#
# Boundaries are detected from the fish prompt marker rendered in the scrollback,
# which always starts with "HH:MM:SS ❯" (see fish_prompt.fish). The next-to-last
# prompt is where the last command was typed; the last prompt is the current
# (empty) one. Everything in between is the command's output.
#
# Usage: copy-last-output.sh [pane-id]   (defaults to the active pane)

set -euo pipefail

pane="${1:-}"
[ -n "$pane" ] || pane="$(tmux display-message -p '#{pane_id}')"

# -p plain text (escape sequences stripped), -J rejoin wrapped lines,
# -S - capture the full scrollback.
output="$(
  tmux capture-pane -t "$pane" -pJ -S - | awk '
    /^[0-9][0-9]:[0-9][0-9]:[0-9][0-9] ❯/ { prompt[++pc] = NR }
    { line[NR] = $0 }
    END {
      if (pc < 2) exit 0              # no previous command in the scrollback
      startp = prompt[pc - 1]         # prompt where the last command was typed
      endp   = prompt[pc]             # current (empty) prompt
      n = 0
      for (i = startp + 1; i < endp; i++) out[++n] = line[i]
      # The slice ends with the next prompt block: a blank line + the dir/git line.
      if (n > 0) n--                                  # drop the dir/git line
      while (n > 0 && out[n] ~ /^[ \t]*$/) n--        # drop trailing blank line(s)
      s = 1
      while (s <= n && out[s] ~ /^[ \t]*$/) s++       # skip leading blank line(s)
      for (i = s; i <= n; i++) print out[i]
    }
  '
)"

if [ -z "$output" ]; then
  tmux display-message "Nothing to copy (no command output found)"
  exit 0
fi

printf '%s\n' "$output" | pbcopy
lines="$(printf '%s\n' "$output" | wc -l | tr -d ' ')"
tmux display-message "Copied last command output ($lines line(s))"
