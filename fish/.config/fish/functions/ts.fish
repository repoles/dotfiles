function ts --description "Select an open tmux session"
    if test (count $argv) -gt 0
        echo "ts: arguments are not supported; every open session is listed" >&2
        return 2
    end

    set now (date +%s)
    set current_session
    set last_session

    if set --query TMUX
        # The S binding in tmux.conf exports these because run-shell has no client
        # of its own: a display-message from here would resolve against whichever
        # client tmux considers current, which is not necessarily the one that
        # pressed the key. The binding expands the formats against the right client.
        # They are absent when ts is called straight from the prompt, hence the fallback.
        if set --query TS_CURRENT_SESSION TS_LAST_SESSION
            set current_session $TS_CURRENT_SESSION
            set last_session $TS_LAST_SESSION
        else
            set client_context (tmux display-message -p "#{session_name}	#{client_last_session}")

            if test $status -eq 0
                set context_parts (string split \t -- $client_context)
                set current_session $context_parts[1]
                set last_session $context_parts[2]
            end
        end
    end

    # the ✳ is dropped from the title, like in tw and the status-right
    set session_lines (tmux list-sessions -F "#{session_activity}	#{session_name}	#{session_windows}	#{window_name}	#{session_alerts}	#{session_attached}	#{s|^✳ ||:pane_title}")

    if test $status -ne 0
        return 1
    end

    set session_lines (printf '%s\n' $session_lines | sort --reverse --numeric-sort)
    set entries
    set current
    set last

    for line in $session_lines
        set parts (string split \t -- $line)
        set position (math (count $entries) + 1)
        set session_status
        set alerts
        set title
        set windows "windows"

        if test "$parts[3]" -eq 1
            set windows "window"
        end

        if test -n "$parts[5]"
            set alerts " [$parts[5]]"
        end

        if test -n "$parts[7]"
            set title " \"$parts[7]\""
        end

        if test "$parts[2]" = "$current_session"
            set current $position
            set --append session_status "current session"
        else if test "$parts[6]" -gt 0
            set --append session_status "attached"
        else
            set last_accessed (string split ' ' (humanize_duration (math --scale=0 "($now - $parts[1]) * 1000")))[1]
            set --append session_status "accessed $last_accessed ago"
        end

        if test "$parts[2]" = "$last_session"
            set last $position
        end

        # the title goes last: it is the only field with no length bound, so fzf truncates it against the real popup width
        set --append entries "$parts[2]: $parts[3] $windows [$parts[4]]$alerts ("(string join ', ' $session_status)")$title"
    end

    set binds

    if test -n "$current"
        set --append binds "start:pos($current)"
    end

    if test -n "$last"
        set --append binds "S:pos($last)+accept"
    end

    set fzf_options --exact --sync --tmux center,80%,50%

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

    set session (string replace --regex ':.*$' '' "$selected")

    if set -q TMUX
        tmux switch-client -t "$session"
    else
        tmux attach-session -t "$session"
    end
end
