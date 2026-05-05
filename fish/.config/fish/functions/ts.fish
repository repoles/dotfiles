function ts --wraps="tmux list-sessions" --description "Select an open tmux session"
    set now (date +%s)

    set selected (tmux list-sessions -F "#{session_activity}	#{session_name}	#{session_windows}	#{window_name}	#{session_attached}" $argv \
        | sort --reverse --numeric-sort \
        | while read --local line
            set parts (string split \t -- $line)

            if test "$parts[5]" -gt 0
                echo "$parts[2]: $parts[3] windows [$parts[4]] (current session)"
            else
                set last_accessed (string split ' ' (humanize_duration (math --scale=0 "($now - $parts[1]) * 1000")))[1]
                echo "$parts[2]: $parts[3] windows [$parts[4]] (accessed $last_accessed ago)"
            end
        end \
        | fzf --tmux center,70%,50%)

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
