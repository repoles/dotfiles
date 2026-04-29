if set -q TMUX
    function __tmux_notify_long_cmd --on-event fish_postexec
        set -l last_status $status

        # Threshold: 5 minutes = 300,000ms
        test $CMD_DURATION -le 300000; and return

        # Don't notify if the user is still viewing the command's window:
        # session must be attached and the window must still be the active one
        set -l session_attached (tmux display-message -p -t $TMUX_PANE '#{session_attached}')
        set -l window_active (tmux display-message -p -t $TMUX_PANE '#{window_active}')
        test $session_attached -gt 0 -a $window_active -eq 1; and return

        set -l symbol
        if test $last_status -eq 0
            set symbol '✓'
        else
            set symbol '✗'
            tput bel
        end

        set -l short_cmd (string shorten --max 40 -- $argv[1])
        set -l duration (humanize_duration $CMD_DURATION)

        # -d 0 to show the message until dismissed
        tmux display-message -t $TMUX_PANE "[#S] #I:#W $symbol $short_cmd ($duration)"
    end
end
