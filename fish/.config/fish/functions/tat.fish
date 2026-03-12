function tat --description "Attach to a tmux session or create one using zoxide"
    set session $argv[1]
    if not tmux has-session -t $session 2>/dev/null
        set dir (zoxide query $session)
        tmux new-session -d -s $session -c $dir
    end
    if set -q TMUX
        tmux switch-client -t $session
    else
        tmux attach-session -t $session
    end
end
