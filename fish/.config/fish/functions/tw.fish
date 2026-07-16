function tw --description "Select a window in the current tmux session"
    if not set --query TMUX
        echo "tw: not inside a tmux session" >&2
        return 1
    end

    if test (count $argv) -gt 0
        echo "tw: arguments are not supported; windows are selected from the current session" >&2
        return 2
    end

    set now (date +%s)
    set entries
    set current
    set last

    # list-windows already sorts by index
    # like in style.conf, the last-window flag becomes ‐ (U+2010) so that ~- does not turn into a ligature
    # the ✳ is dropped from the title, like in the status-right
    set window_lines (tmux list-windows -F "#{window_index}	#{window_name}	#{s|-|‐|:window_flags}	#{s|^✳ ||:pane_title}	#{window_active}	#{window_last_flag}	#{window_activity}")

    if test $status -ne 0
        return 1
    end

    for line in $window_lines
        set parts (string split \t -- $line)
        set position (math (count $entries) + 1)
        set title

        if test "$parts[5]" -gt 0
            set current $position
        end

        if test "$parts[6]" -gt 0
            set last $position
        end

        if test -n "$parts[4]"
            set title " \"$parts[4]\""
        end

        set active (string split ' ' (humanize_duration (math --scale=0 "($now - $parts[7]) * 1000")))[1]

        # the title goes last: it is the only field with no length bound, so fzf truncates it against the real popup width
        set --append entries "$parts[1]:[$parts[2]$parts[3]] (active $active ago)$title"
    end

    set binds

    if test -n "$current"
        set --append binds "start:pos($current)"
    end

    if test -n "$last"
        set --append binds "W:pos($last)+accept"
    end

    set fzf_options --exact --sync --tmux center,70%,50%

    if test (count $binds) -gt 0
        set --append fzf_options --bind (string join ',' $binds)
    end

    set selected (printf '%s\n' $entries | fzf $fzf_options)
    set fzf_status $status

    if test $fzf_status -eq 130
        return
    else if test $fzf_status -ne 0
        return $fzf_status
    else if test -z "$selected"
        return
    end

    set window (string replace --regex ':.*$' '' "$selected")

    tmux select-window -t ":$window"
end
