#!/usr/bin/env bash
# Select an agent window across sessions; bound to A.

source "$(dirname -- "$0")/selector-common.sh"

format="#{window_activity}${separator}#{pane_id}${separator}#{session_id}${separator}#{window_id}"
format+="${separator}#{session_name}${separator}#{window_index}:#{window_name}#{s|~||:window_flags}"
format+="${separator}#{window_name}${separator}#{pane_current_command}${separator}#{pane_title}"
# Keep the existing scope: one active pane per window, across all sessions.
pane_lines=$(tmux list-panes -a -f '#{pane_active}' -F "$format")
stamp_dir="${XDG_CACHE_HOME:-$HOME/.cache}/tmux-agent-activity"
window_lines=()

while IFS="$separator" read -r activity pane_id session_id window_id session_name window name command title; do
    # F1/F2 name the windows claude/codex. Also recognize their command names;
    # titles are displayed verbatim and are not used to identify an agent.
    case "$name" in
        claude|codex*) ;;
        *) case "$command" in claude*|codex*) ;; *) continue ;; esac ;;
    esac

    # Hooks record agent activity; visiting a window does not update this stamp.
    # Windows with no valid stamp retain tmux's window_activity as a fallback.
    stamp=
    if [[ -r $stamp_dir/$pane_id ]]; then
        IFS= read -r stamp < "$stamp_dir/$pane_id" || true
        if [[ $stamp =~ ^[0-9]+$ ]]; then activity=$((10#$stamp)); fi
    fi
    window_lines+=("$activity$separator$session_id$separator$window_id$separator$session_name$separator$window$separator$title")
done <<< "$pane_lines"

if (( ${#window_lines[@]} == 0 )); then
    printf 'No claude or codex windows are open.\n' >&2
    exit 1
fi

sorted_lines=$(printf '%s\n' "${window_lines[@]}" | sort -rn)
now=$(date +%s)
entries=()
current=

while IFS="$separator" read -r activity session_id window_id session_name window title; do
    if [[ $session_id == "$SELECTOR_SESSION" && $window_id == "${SELECTOR_WINDOW:-}" ]]; then
        current=$((${#entries[@]} + 1))
    fi
    label="[$session_name] $window (active $(humanize_duration "$((now - activity))") ago)"
    if [[ -n $title ]]; then label+=" \"$title\""; fi
    entries+=("$session_id:$window_id"$'\t'"$label")
done <<< "$sorted_lines"

choose_entry "$current"
tmux switch-client -c "$SELECTOR_CLIENT" -t "$target"
