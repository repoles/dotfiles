if status is-interactive; and set -q TMUX
    function __tmux_notify_long_cmd --on-event fish_postexec
        set -l last_status $status

        # Threshold: 5 minutes = 300,000ms
        test $CMD_DURATION -le 300000; and return

        # The toast is a pane, and tmux puts it in the session's current window
        # rather than in this one, so the window fields have to be resolved here,
        # against the pane the command ran in, instead of at display time.
        set -l info (tmux display-message -p -t $TMUX_PANE '#{session_attached} #{window_active} [#S] #I:#W')
        # Split twice only: a window name may itself contain spaces
        set -l fields (string split -m 2 ' ' -- $info)

        # No client on the session, so the toast would live and die unseen
        test $fields[1] -eq 0; and return
        # The user is still viewing the command's own window
        test $fields[2] -eq 1; and return

        set -l level ok
        set -l symbol '✓'
        if test $last_status -ne 0
            set level error
            set symbol '✗'
            tput bel
        end

        set -l short_cmd (string shorten --max 60 -- $argv[1])
        set -l duration (humanize_duration $CMD_DURATION)

        # Held longer than a status line message: after a five minute wait the
        # user is often not looking at the screen the moment it lands.
        "$XDG_CONFIG_HOME/tmux/scripts/tmux-toast.sh" -l $level -d 8 \
            "$symbol $short_cmd" "$fields[3] ($duration)"
    end
end
