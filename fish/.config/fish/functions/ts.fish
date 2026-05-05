function ts --wraps="tmux list-sessions" --description "Select an open tmux session"
    set now (date +%s)

    set selected (tmux list-sessions -F "#{session_activity}	#{session_name}	#{session_windows}	#{session_attached}" $argv \
        | sort --reverse --numeric-sort \
        | while read --local line
            set parts (string split \t -- $line)

            if test "$parts[4]" -gt 0
                echo "$parts[2]: $parts[3] windows (current session)"
            else
                set last_accessed (string split ' ' (humanize_duration (math --scale=0 "($now - $parts[1]) * 1000")))[1]
                echo "$parts[2]: $parts[3] windows (accessed $last_accessed ago)"
            end
        end \
        | fzf --tmux center,60%,50%)

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
