if status is-interactive; and set -q HERDR_TAB_ID
    function __herdr_notify_long_cmd --on-event fish_postexec
        set -l command_status $status

        # Threshold: 5 minutes = 300,000ms
        if test $CMD_DURATION -le 300000
            return $command_status
        end

        # Don't notify while the command's tab is still focused.
        set -l tab_info (command herdr tab get "$HERDR_TAB_ID" 2>/dev/null)
        if string match --quiet --regex '"focused":true' -- "$tab_info"
            return $command_status
        end

        set -l symbol
        set -l sound
        if test $command_status -eq 0
            set symbol '✓'
            set sound none
        else
            set symbol '✗'
            set sound request
        end

        set -l short_cmd (string shorten --max 40 -- $argv[1])
        set -l duration (humanize_duration $CMD_DURATION)

        command herdr notification show "Comando concluído" \
            --body "[$HERDR_TAB_ID] $symbol $short_cmd ($duration)" \
            --sound $sound >/dev/null 2>&1

        return $command_status
    end
end
