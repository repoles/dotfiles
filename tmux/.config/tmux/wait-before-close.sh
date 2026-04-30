#!/usr/bin/env bash

default_timeout=5
timeout="${WAIT_BEFORE_CLOSE_SECONDS:-$default_timeout}"

case "$timeout" in
    ''|*[!0-9]*)
        timeout=$default_timeout
        ;;
esac

if (( $# == 0 )); then
    printf 'Usage: %s command [args...]\n' "${0##*/}" >&2
    exit 64
fi

"$@"
exit_status=$?

if (( timeout > 0 )) && [[ -t 0 ]]; then
    printf '\n[%s exited with status %d]\n' "$1" "$exit_status"
    printf 'Press any key within %ss to pause auto-close;\notherwise this window will close automatically...' "$timeout"

    if IFS= read -r -s -n 1 -t "$timeout" _; then
        printf '\nAuto-close paused. Press Ctrl+C to close this window.\n'
        trap 'printf "\n"; exit "$exit_status"' INT TERM

        while :; do
            sleep 86400 &
            wait "$!"
        done
    fi
fi

exit "$exit_status"
