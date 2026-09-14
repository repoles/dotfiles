if status is-interactive; and set -q TMUX
    function __tmux_notify_long_cmd --on-event fish_postexec
        set -l last_status $status

        # Threshold: 5 minutes = 300,000ms
        test $CMD_DURATION -le 300000; and return

        # Named against the pane the command ran in rather than at display
        # time: the toast is raised in the window the user is watching, and
        # the whole point of this line is to name the one they left behind.
        set -l origin (tmux display-message -p -t $TMUX_PANE '[#S] #I:#W')

        set -l level ok
        set -l symbol '✓'
        if test $last_status -ne 0
            set level error
            set symbol '✗'
        end

        set -l short_cmd (string shorten --max 60 -- $argv[1])
        set -l duration (humanize_duration $CMD_DURATION)

        # Held longer than a status line message: after a five minute wait the
        # user is often not looking at the screen the moment it lands. -o
        # leaves the toast to decide whether the user is somewhere else and so
        # wants telling at all, since answering that means knowing which window
        # they are on, which is the same thing the toast has to know to raise
        # itself where they will read it.
        "$XDG_CONFIG_HOME/tmux/scripts/tmux-toast.sh" -o $TMUX_PANE -l $level -d 8 \
            "$symbol $short_cmd" "$origin ($duration)"

        # Rung for the same failures the toast reports and only alongside one:
        # heard from across the room it says to come and look, and there is
        # nothing to come and look at when the user is already here. 3 is the
        # toast saying it held itself back on exactly that.
        if test $status -eq 0; and test $last_status -ne 0
            tput bel
        end
    end
end
