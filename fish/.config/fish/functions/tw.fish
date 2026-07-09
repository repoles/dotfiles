function tw --wraps="tmux list-windows" --description "Select a window in the current tmux session"
    if not set --query TMUX
        echo "tw: not inside a tmux session" >&2
        return 1
    end

    set now (date +%s)
    set entries
    set current 1
    set last

    # list-windows already sorts by index
    # like in style.conf, the last-window flag becomes ‐ (U+2010) so that ~- does not turn into a ligature
    # the ✳ is dropped from the title, like in the status-right
    for line in (tmux list-windows -F "#{window_index}	#{window_name}	#{s|-|‐|:window_flags}	#{s|^✳ ||:pane_title}	#{window_active}	#{window_last_flag}	#{window_activity}" $argv)
        set parts (string split \t -- $line)
        set position (math (count $entries) + 1)

        if test "$parts[5]" -gt 0
            set current $position
        end

        if test "$parts[6]" -gt 0
            set last $position
        end

        set active (string split ' ' (humanize_duration (math --scale=0 "($now - $parts[7]) * 1000")))[1]

        set --append entries "$parts[1]:[$parts[2]$parts[3]] \"$parts[4]\" (active $active ago)"
    end

    # start on the current window; W jumps to the last one, like the S binding in ts
    set binds "start:pos($current)"

    if test -n "$last"
        set --append binds "W:pos($last)+accept"
    end

    set selected (printf '%s\n' $entries \
        | fzf --exact --sync --tmux center,70%,50% --bind (string join ',' $binds))

    if test -z "$selected"
        return
    end

    set window (string replace --regex ':.*$' '' "$selected")

    tmux select-window -t ":$window"
end
