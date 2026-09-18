#!/usr/bin/env bash
# Select an open session; invoked by the S binding in tmux.conf.

source "$(dirname -- "$0")/selector-common.sh"

format="#{session_activity}${separator}#{session_id}${separator}#{session_name}"
format+="${separator}#{session_windows}${separator}#{window_index}:#{window_name}#{s|\*||:window_flags}"
format+="${separator}#{session_alerts}${separator}#{session_attached}${separator}#{pane_title}"
format+="${separator}#{window-status-style}"
session_lines=$(tmux list-sessions -F "$format")
session_lines=$(printf '%s\n' "$session_lines" | sort -rn)
now=$(date +%s)
entries=()
current=
last=

while IFS="$separator" read -r activity session_id session_name windows window alerts attached title style; do
    position=$((${#entries[@]} + 1))
    if [[ $session_id == "$SELECTOR_SESSION" ]]; then
        current=$position
        session_status='current session'
    elif (( attached > 0 )); then
        session_status=attached
    else
        session_status="accessed $(humanize_duration "$((now - activity))") ago"
    fi

    if [[ $session_name == "${SELECTOR_LAST_SESSION:-}" ]]; then last=$position; fi
    window_count="$windows windows"
    if (( windows == 1 )); then window_count='1 window'; fi
    details="$window_count, $session_status"
    # if [[ -n $alerts ]]; then details+=", alerts: $alerts"; fi
    label="[$session_name] $window ($details)"
    label+=$(format_pane_title "$title" "$style")
    entries+=("$session_id"$'\t'"$label")
done <<< "$session_lines"

choose_entry "$current" S "$last"
tmux switch-client -c "$SELECTOR_CLIENT" -t "$target"
