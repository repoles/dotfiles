#!/usr/bin/env bash
# Shared by the selectors launched in tmux display-popup bindings.

set -eo pipefail

: "${SELECTOR_CLIENT:?the tmux binding must provide the client}"
: "${SELECTOR_SESSION:?the tmux binding must provide the session ID}"

# Unlike tab in IFS, this separator preserves empty tmux fields.
separator=$'\x1f'

humanize_duration() {
    local seconds=$1
    if (( seconds < 0 )); then seconds=0; fi

    if (( seconds >= 86400 )); then
        printf '%dd' "$((seconds / 86400))"
    elif (( seconds >= 3600 )); then
        printf '%dh' "$((seconds / 3600))"
    elif (( seconds >= 60 )); then
        printf '%dm' "$((seconds / 60))"
    else
        printf '%ds' "$seconds"
    fi
}

# entries carry an opaque tmux target before the tab; only the label is shown
# and searched. Never recover a target from a session name or window index.
choose_entry() {
    local current=$1 last_key=${2:-} last=${3:-} selected status
    local options=(
        --exact --sync --no-multi --no-popup --layout reverse --border
        --delimiter $'\t' --with-nth '2..'
        --prompt '❯ ' --marker '❯'
        --color 'hl:bright-yellow,hl+:bright-yellow'
        --color 'bg:#11151c,bg+:#1c212b,gutter:#11151c'
        --color 'info:cyan,border:bright-black,prompt:green'
        --color 'pointer:red,marker:yellow,spinner:yellow,header:blue'
    )

    if [[ -n $current ]]; then options+=(--bind "start:pos($current)"); fi
    if [[ -n $last ]]; then options+=(--bind "$last_key:pos($last)+accept"); fi

    if selected=$(printf '%s\n' "${entries[@]}" | fzf "${options[@]}"); then
        [[ -n $selected ]] || exit 0
        target=${selected%%$'\t'*}
    else
        status=$?
        # Closing the popup without a selection is a successful no-op.
        if (( status == 130 )); then exit 0; fi
        exit "$status"
    fi
}
