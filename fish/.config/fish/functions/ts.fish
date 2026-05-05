function ts --wraps="tmux list-sessions" --description "Select an open tmux session"
    set now (date +%s)

    set selected (tmux list-sessions -F "#{session_activity}	#{session_name}	#{session_windows}	#{window_name}	#{session_alerts}	#{session_attached}" $argv \
        | sort --reverse --numeric-sort \
        | while read --local line
            set parts (string split \t -- $line)
            set session_status
            set alerts

            if test -n "$parts[5]"
                set alerts " [$parts[5]]"
            end

            if test "$parts[6]" -gt 0
                set --append session_status "current session"
            else
                set last_accessed (string split ' ' (humanize_duration (math --scale=0 "($now - $parts[1]) * 1000")))[1]
                set --append session_status "accessed $last_accessed ago"
            end

            echo "$parts[2]: $parts[3] windows [$parts[4]]$alerts ("(string join ', ' $session_status)")"
        end \
        | fzf --exact --tmux center,70%,50%)

    if test -z "$selected"
        return
    end

    set session (string replace --regex ':.*$' '' "$selected")

    if set -q TMUX
        tmux switch-client -t "$session"
    else
        tmux attach-session -t "$session"
    end
end
