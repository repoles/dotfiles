if set -q TMUX
    function long_command_notifier --on-event fish_postexec
        set -l command_status $status

        # return if command ran for less than 5 minutes
        test $CMD_DURATION -gt 300000; or return

        set -l command_pane $TMUX_PANE
        set -l current_pane (tmux display-message -p '#D')

        # do not notify if we are in the same pane
        test $current_pane != $command_pane; or return

        set -l symbol
        if test $command_status -eq 0
            set symbol "✓" # success
        else
            set symbol "✗" # failure
            tput bel
        end

        set -l command (string shorten -m 40 -- $argv)
        tmux display-message -d 0 -t $command_pane "[#S] #I:#W $symbol $command ($(humanize_duration))"
    end
end
