function rat --description "Switch to a rex session or create one using zoxide"
    set session $argv[1]
    set id (rex ls --json | jq -r --arg label $session \
        'first(.sessions[] | select(.label == $label) | .session_id) // empty')
    if test -z "$id"
        set dir (zoxide query $session); or return
        set id (rex new $session -c $dir --json | jq -r .session_id); or return
    end
    if set -q REX_SESSION
        rex do session.select session_id=$id
    else
        rex attach $id
    end
end
