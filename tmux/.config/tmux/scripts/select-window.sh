#!/usr/bin/env bash
# Select a window in the invoking client's session; bound to W.

source "$(dirname -- "$0")/selector-common.sh"

format="#{window_id}${separator}#{session_name}${separator}#{window_index}:#{window_name}#{s|-|‐|:window_flags}"
format+="${separator}#{window_active}${separator}#{window_last_flag}${separator}#{window_activity}${separator}#{pane_title}"
# list-windows already sorts by index. Pin the query to the binding's session.
window_lines=$(tmux list-windows -t "$SELECTOR_SESSION" -F "$format")
now=$(date +%s)
entries=()
current=
last=

while IFS="$separator" read -r window_id session_name window active last_flag activity title; do
    position=$((${#entries[@]} + 1))
    if (( active )); then current=$position; fi
    if (( last_flag )); then last=$position; fi
    label="[$session_name] $window (active $(humanize_duration "$((now - activity))") ago)"
    if [[ -n $title ]]; then label+=" \"$title\""; fi
    entries+=("$SELECTOR_SESSION:$window_id"$'\t'"$label")
done <<< "$window_lines"

choose_entry "$current" W "$last"
tmux switch-client -c "$SELECTOR_CLIENT" -t "$target"
