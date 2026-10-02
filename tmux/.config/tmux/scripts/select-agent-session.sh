#!/usr/bin/env bash
# Resume agent sessions that never concluded; bound to U.
# Usage: select-agent-session.sh                  open the selector
#        select-agent-session.sh --list here|all  print its entries
#        select-agent-session.sh --preview <id>   describe one session
#        select-agent-session.sh --delete <id>... forget sessions
#        select-agent-session.sh --resume <id>... resume sessions
#
# Records come from agent-tmux-session.sh. A session still running is never listed or
# resumed twice: its record names a live process with the start time it was recorded with.

source "$(dirname -- "$0")/selector-common.sh"

scripts=$(cd -- "$(dirname -- "$0")" && pwd)
sessions="${XDG_STATE_HOME:-$HOME/.local/state}/tmux-agent-sessions"

valid_id() {
    [[ $1 =~ ^[A-Za-z0-9_-]+$ ]]
}

# Epoch seconds a process started at, matching what agent-tmux-session.sh records.
process_started_at() {
    local lstart words
    lstart=$(LC_ALL=C ps -o lstart= -p "$1") || return 1
    read -ra words <<< "$lstart"
    LC_ALL=C date -j -f '%a %b %e %T %Y' "${words[*]}" +%s 2>/dev/null
}

running() {
    local pid=$1 started_at=$2
    [[ $pid =~ ^[0-9]+$ && $started_at =~ ^[0-9]+$ ]] || return 1
    [[ $(process_started_at "$pid") == "$started_at" ]]
}

# Fields of one record, joined by the separator; empty when the record cannot be read.
record_fields() {
    jq -r '[.last_prompt_at, .session_id, .tool, .cwd, .tmux_session, .window_index,
            .window_name, .pane_index, .pane_title, .agent_pid, .agent_started_at,
            .started_at]
        | map(. // "" | tostring | gsub("[[:cntrl:]]"; " ")) | join("\u001f")' \
        "$sessions/$1.json" 2>/dev/null
}

# Sessions of the repository the pane is in, or of the pane's directory outside one.
project_base() {
    [[ -n ${SELECTOR_PATH:-} ]] || return 1
    git -C "$SELECTOR_PATH" rev-parse --show-toplevel 2>/dev/null || printf '%s\n' "$SELECTOR_PATH"
}

# Agents prefix their titles with a status glyph (✳, a spinner) and Codex shows the bare
# session ID until it names the conversation; neither says what the session is about.
session_title() {
    local title=$1 id=$2
    if [[ $title =~ ^[^\ -~]+\ (.*)$ ]]; then title=${BASH_REMATCH[1]}; fi
    [[ $title == "$id" ]] && return 0
    printf '%s' "$title"
}

list_entries() {
    local scope=$1 base= now file id lines=() fields
    local last session_id tool cwd tmux_session window_index window_name pane_index title pid started_at
    if [[ $scope == here ]]; then base=$(project_base) || base=; fi
    now=$(date +%s)

    for file in "$sessions"/*.json; do
        [[ -f $file ]] || continue
        id=${file##*/}
        id=${id%.json}
        valid_id "$id" || continue
        fields=$(record_fields "$id") && [[ -n $fields ]] || continue
        IFS="$separator" read -r last session_id tool cwd tmux_session window_index window_name \
            pane_index title pid started_at _ <<< "$fields"
        [[ $last =~ ^[0-9]+$ ]] || last=0
        if [[ -n $base && $cwd != "$base" && $cwd != "$base"/* ]]; then continue; fi
        running "$pid" "$started_at" && continue

        label="[$tmux_session] $window_index:$window_name"
        label+=" (last prompt $(humanize_duration "$((now - last))") ago)"
        title=$(session_title "$title" "$id")
        if [[ -n $title ]]; then label+=" \"$title\""; fi
        lines+=("$last$separator$id"$'\t'"$label")
    done

    (( ${#lines[@]} )) || return 0
    printf '%s\n' "${lines[@]}" | sort -t "$separator" -k1,1nr | cut -d "$separator" -f2-
}

preview() {
    local id=$1 fields last session_id tool cwd tmux_session window_index window_name
    local pane_index title pid started_at first now
    valid_id "$id" && fields=$(record_fields "$id") && [[ -n $fields ]] || return 0
    IFS="$separator" read -r last session_id tool cwd tmux_session window_index window_name \
        pane_index title pid started_at first <<< "$fields"
    now=$(date +%s)
    printf '%s %s\n' "$tool" "$id"
    if [[ $cwd == "$HOME" || $cwd == "$HOME"/* ]]; then cwd="~${cwd#"$HOME"}"; fi
    printf '%s\n' "$cwd"
    printf '[%s] %s:%s.%s\n' "$tmux_session" "$window_index" "$window_name" "$pane_index"
    if [[ $first =~ ^[0-9]+$ && $last =~ ^[0-9]+$ ]]; then
        printf 'started %s ago, last prompt %s ago\n' \
            "$(humanize_duration "$((now - first))")" "$(humanize_duration "$((now - last))")"
    fi
}

delete_records() {
    local id
    for id in "$@"; do
        valid_id "$id" && rm -f -- "$sessions/$id.json"
    done
    return 0
}

# The original pane, when it still belongs to the window the session ran in and holds nothing
# but an idle shell, as tmux-resurrect leaves it. A pane with any child process is in use.
idle_original_pane() {
    local target=$1 window_name=$2 info pane_id name pane_pid dead command
    info=$(tmux display-message -p -t "$target" \
        "#{pane_id}$separator#{window_name}$separator#{pane_pid}$separator#{pane_dead}$separator#{pane_current_command}" \
        2>/dev/null) || return 1
    IFS="$separator" read -r pane_id name pane_pid dead command <<< "$info"
    [[ $name == "$window_name" ]] || return 1
    if [[ $dead != 1 ]]; then
        case "$command" in fish|bash|zsh|sh) ;; *) return 1 ;; esac
        pgrep -P "$pane_pid" > /dev/null && return 1
    fi
    printf '%s\n' "$pane_id"
}

# Until its first prompt records the agent, mark the resumed session with the process now
# running in its pane, so it is not listed and resumed a second time.
mark_running() {
    local id=$1 pid=$2 started_at tmp
    [[ $pid =~ ^[0-9]+$ ]] && started_at=$(process_started_at "$pid") || return 0
    tmp=$(mktemp "$sessions/.$id.XXXXXX") || return 0
    if jq --argjson pid "$pid" --argjson started_at "$started_at" \
            '.agent_pid = $pid | .agent_started_at = $started_at' \
            "$sessions/$id.json" > "$tmp"; then
        mv -f -- "$tmp" "$sessions/$id.json"
    else
        rm -f -- "$tmp"
    fi
}

resume_sessions() {
    local id fields order=() skipped=() target= pane
    local last session_id tool cwd tmux_session window_index window_name pane_index title pid started_at
    for id in "$@"; do
        valid_id "$id" && fields=$(record_fields "$id") && [[ -n $fields ]] || continue
        IFS="$separator" read -r last session_id tool cwd tmux_session window_index window_name \
            pane_index title pid started_at _ <<< "$fields"
        order+=("$tmux_session$separator$window_index$separator$id")
    done
    (( ${#order[@]} )) || return 0

    # In window order, so sessions that go back to the same tmux session keep their order.
    while IFS="$separator" read -r _ _ id; do
        fields=$(record_fields "$id") && [[ -n $fields ]] || continue
        IFS="$separator" read -r last session_id tool cwd tmux_session window_index window_name \
            pane_index title pid started_at _ <<< "$fields"
        if running "$pid" "$started_at"; then
            skipped+=("$id is already running")
            continue
        fi
        if [[ ! -d $cwd ]]; then
            skipped+=("$id: $cwd no longer exists")
            continue
        fi
        local command=("$scripts/start-agent.sh" "$tool")
        case "$tool" in
            claude) command+=(--resume "$id") ;;
            codex) command+=(resume "$id") ;;
            *) skipped+=("$id: unknown agent $tool"); continue ;;
        esac

        local format="#{session_id}:#{window_id}$separator#{pane_pid}" result=
        if [[ -n $tmux_session ]] &&
                pane=$(idle_original_pane "=$tmux_session:$window_index.$pane_index" "$window_name"); then
            tmux respawn-pane -k -t "$pane" -c "$cwd" "${command[@]}" &&
                result=$(tmux display-message -p -t "$pane" "$format") || result=
        elif [[ -n $tmux_session ]] && tmux has-session -t "=$tmux_session" 2>/dev/null; then
            # Back at its index: before the window there now, or after the last one.
            local place=(-t "=$tmux_session:")
            if tmux display-message -p -t "=$tmux_session:$window_index" '' > /dev/null 2>&1; then
                place=(-b -t "=$tmux_session:$window_index")
            fi
            result=$(tmux new-window -d -P -F "$format" "${place[@]}" -c "$cwd" -n "$tool" \
                "${command[@]}") || result=
        elif [[ -n $tmux_session ]]; then
            result=$(tmux new-session -d -P -F "$format" -s "$tmux_session" -c "$cwd" -n "$tool" \
                "${command[@]}") || result=
        else
            result=$(tmux new-window -d -P -F "$format" -t "$SELECTOR_SESSION:" -c "$cwd" \
                -n "$tool" "${command[@]}") || result=
        fi
        if [[ -z $result ]]; then
            skipped+=("$id could not be opened")
            continue
        fi
        target=${result%%"$separator"*}
        mark_running "$id" "${result#*"$separator"}"
    done < <(printf '%s\n' "${order[@]}" | sort -t "$separator" -k1,1 -k2,2n)

    if [[ -n $target ]]; then tmux switch-client -c "$SELECTOR_CLIENT" -t "$target" || true; fi
    if (( ${#skipped[@]} )); then
        tmux display-message -c "$SELECTOR_CLIENT" "Not resumed: $(IFS=';'; printf '%s' "${skipped[*]}")"
    fi
}

choose_sessions() {
    local base here_prompt all_prompt prompt scope=here entries self selected status
    base=$(project_base) || scope=all
    here_prompt="${base##*/}> "
    all_prompt='all projects> '
    if [[ $scope == here ]]; then entries=$(list_entries here); fi
    if [[ -z ${entries:-} ]]; then
        scope=all
        entries=$(list_entries all)
    fi
    if [[ -z $entries ]]; then
        tmux display-message -c "$SELECTOR_CLIENT" 'No unfinished agent sessions.'
        exit 0
    fi
    prompt=$here_prompt
    if [[ $scope == all ]]; then prompt=$all_prompt; fi

    printf -v self '/bin/bash %q' "$0"
    local reload_scope="[[ \$FZF_PROMPT == '$all_prompt' ]] && echo \"reload($self --list all)\" || echo \"reload($self --list here)\""
    local toggle_scope="[[ \$FZF_PROMPT == '$all_prompt' ]] && echo \"change-prompt($here_prompt)+reload($self --list here)\" || echo \"change-prompt($all_prompt)+reload($self --list all)\""
    local options=(
        --exact --multi --no-popup --ansi --with-shell 'bash -c'
        --delimiter $'\t' --with-nth '2..'
        --prompt "$prompt"
        --header 'enter resume · tab mark · ctrl-a this project/all · ctrl-x forget'
        --preview "$self --preview {1}" --preview-window 'down,4,wrap'
        --bind "ctrl-a:transform:$toggle_scope"
        --bind "ctrl-x:execute-silent($self --delete {+1})+transform:$reload_scope"
    )

    if selected=$(printf '%s\n' "$entries" | fzf "${options[@]}"); then
        [[ -n $selected ]] || exit 0
        local ids=()
        while IFS=$'\t' read -r id _; do ids+=("$id"); done <<< "$selected"
        resume_sessions "${ids[@]}"
    else
        status=$?
        # Closing the popup without a selection is a successful no-op.
        if (( status == 130 )); then exit 0; fi
        exit "$status"
    fi
}

case "${1:-}" in
    --list) list_entries "${2:-all}" ;;
    --preview) preview "${2:-}" ;;
    --delete) shift; delete_records "$@" ;;
    --resume) shift; resume_sessions "$@" ;;
    '') choose_sessions ;;
    *) printf 'Usage: %s [--list here|all | --preview id | --delete id... | --resume id...]\n' "${0##*/}" >&2; exit 64 ;;
esac
