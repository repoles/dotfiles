function __rexls_windows
    # Limit to the session given with -s, if any
    set -l tokens (commandline -xpc)
    argparse -i 's/session=' -- $tokens 2>/dev/null
    for session in (rex session ls --json | jq -r --arg q "$_flag_session" '
        .sessions[] | select($q == "" or .label == $q or (.session_id | endswith($q)))
        | [.session_id, .label] | @tsv')
        set -l s (string split \t -- $session)
        rex window ls -s $s[1] --json 2>/dev/null | jq -r --arg s "$s[2]" '.windows[] | "\(.label)\t\($s)"'
    end
end

complete -c rexls -f
complete -c rexls -s h -l help -d 'Show help'
complete -c rexls -s s -l session -x -a "(rex session ls --json | jq -r '.sessions[].label')" -d 'Filter by session'
complete -c rexls -s w -l window -x -a '(__rexls_windows)' -d 'Filter by window'
complete -c rexls -s j -l json -d 'Output as JSON'
complete -c rexls -s l -l long -d 'Show full IDs'
