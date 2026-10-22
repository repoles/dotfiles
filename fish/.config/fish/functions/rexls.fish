function rexls --description "List rex blocks with their process, status and last terminal write"
    argparse h/help 's/session=' 'w/window=' j/json l/long -- $argv; or return

    if set -q _flag_help
        echo "Usage: rexls [-s SESSION] [-w WINDOW] [-j|--json] [-l|--long]"
        echo
        echo "SESSION and WINDOW match a label, a full ID or a short ID."
        echo "In the table, * marks the active window or block, @ the current one."
        echo "ACTIVITY and JSON last_activity use the local terminal's last write time."
        echo "This is an estimate: control sequences and redraws also count as writes."
        echo "It does not measure the last agent action; unavailable times are - or null."
        return
    end

    set -l me (rex whoami --json); or return
    set -l host (printf '%s\n' "$me" | jq -er '.host_id | select(type == "string" and length > 0)'); or return
    set -l current_window (printf '%s\n' "$me" | jq -r '.window_id // ""'); or return
    set -l current_block (printf '%s\n' "$me" | jq -r '.block_id // ""'); or return

    # Keep command failures separate from JSON parsing, including empty results.
    set -l sessions_json (rex session ls --json); or return
    set -l match 'def match($q): $q == "" or .label == $q or .id == $q or (.id | endswith($q));'
    set -l sessions (printf '%s\n' "$sessions_json" | jq -ce --arg q "$_flag_session" "$match"'
        [.sessions[] | select({id: .session_id, label} | match($q))]'); or return

    # Keep each block as a JSON object until the table is rendered.
    set -l rows
    for session in (printf '%s\n' "$sessions" | jq -c '.[]')
        set -l session_id (printf '%s\n' "$session" | jq -er '.session_id'); or return
        set -l windows_json (rex window ls -s "$session_id" --json); or return
        set -l session_rows (printf '%s\n' "$windows_json" | jq -ce \
            --argjson session "$session" --arg q "$_flag_window" \
            --arg current_window "$current_window" --arg current_block "$current_block" "$match"'
            .active_window_id as $active
            | [.windows[] | select({id: .window_id, label} | match($q))
                | . as $window | .layers[].blocks[]
                | {
                    session_id: $session.session_id, session_label: $session.label,
                    window_id: $window.window_id, window_label: $window.label,
                    window_active: ($window.window_id == $active),
                    window_current: ($window.window_id == $current_window),
                    block_id, block_label: .label,
                    block_active: (.block_id == $window.focused_block_id),
                    block_current: (.block_id == $current_block), host_id
                }]'); or return
        set -a rows (printf '%s\n' "$session_rows" | jq -c '.[]')
    end

    if test (count $rows) -eq 0
        set -q _flag_json; and echo '[]'
        return 0
    end

    set -l blocks
    for row in $rows
        set -l session_id (printf '%s\n' "$row" | jq -r '.session_id')
        set -l block_id (printf '%s\n' "$row" | jq -r '.block_id')
        # Methods may be unavailable for non-terminal blocks or a block that closed,
        # so a failed call or an unexpected result only empties that block's fields.
        set -l title (rex block call -s "$session_id" -b "$block_id" title 2>/dev/null)
        set -l process (rex block call -s "$session_id" -b "$block_id" process 2>/dev/null)
        set -l program_status (rex block call -s "$session_id" -b "$block_id" program_status 2>/dev/null)
        set -l block (jq -nc --argjson row "$row" --arg host "$host" \
            --arg title "$title" --arg process "$process" --arg program_status "$program_status" '
            def object: try fromjson catch null | if type == "object" then . else null end;
            def nullable: if . == "" then null else . end;
            def rank: {blocked: 4, error: 3, working: 2, done: 1}[.state] // 0;
            ($title | object) as $title
            | ($process | object | .foreground // .child) as $p
            | ($program_status | object) as $program_status
            | $row + {
                title: (try ($title.title | gsub("[[:space:]]"; " ") | nullable) catch null),
                process: (try ($p.script // $p.argv0 // $p.name | ltrimstr("-") | split("/") | last | nullable) catch null),
                status: (try (([$program_status.records[] | select(rank > 0)] | max_by(rank))
                    | .state + (if .state == "blocked" and .kind then ":" + .kind else "" end) | nullable) catch null),
                pid: (if $row.host_id == $host then (try ($p.pid | numbers) catch null) // null else null end)
            } | del(.host_id)'); or return
        set -a blocks "$block"
    end

    # TTY mtime estimates terminal writes, including invisible control sequences.
    # Only local PIDs can be resolved, and a failed stat must not shift other times.
    set -l tty_times '{}'
    set -l local_pids (printf '%s\n' $blocks | jq -sr '[.[].pid // empty] | unique | join(",")'); or return
    if test -n "$local_pids"
        for line in (ps -o pid=,tty= -p "$local_pids" 2>/dev/null)
            set -l fields (string split -n ' ' -- (string trim -- "$line"))
            set -l pid $fields[1]
            set -l tty $fields[2]
            contains -- "$tty" '??' - ''; and continue
            set -l mtime (stat -f %m /dev/$tty 2>/dev/null); or continue
            string match -qr '^[0-9]+$' -- "$mtime"; or continue
            set tty_times (jq -nc --argjson times "$tty_times" --arg pid "$pid" --argjson mtime "$mtime" \
                '$times + {($pid): $mtime}'); or return
        end
    end

    # Preserve the public JSON fields while discarding the internal PID.
    set -l output (printf '%s\n' $blocks | jq -sc --argjson tty_times "$tty_times" '
        map(.last_activity = ($tty_times[.pid | tostring] // null
            | if . == null then null else todate end) | del(.pid))'); or return
    if set -q _flag_json
        printf '%s\n' "$output" | jq .
        return
    end

    set -l now (date +%s); or return
    set -l long false
    set -q _flag_long; and set long true
    set -l table
    for row in (printf '%s\n' "$output" | jq -c '.[]')
        set -l title (printf '%s\n' "$row" | jq -r '.title // "-"')
        set title (string shorten -m 30 -- "$title")
        set -l line (printf '%s\n' "$row" | jq -r --arg title "$title" --argjson long $long --argjson now "$now" '
            def flags($active; $current): (if $active then "*" else " " end)
                + (if $current then "@" else " " end) + " ";
            def id: if $long then . else .[-6:] end;
            def age:
                if . == null then "-"
                else ([$now - fromdate, 0] | max | floor) as $seconds
                    | if $seconds < 60 then "\($seconds)s"
                      elif $seconds < 3600 then "\($seconds / 60 | floor)m"
                      elif $seconds < 86400 then "\($seconds / 3600 | floor)h"
                      else "\($seconds / 86400 | floor)d" end
                end;
            [(.session_label // "-" | tostring),
                (flags(.window_active; .window_current) + (.window_id | id)),
                (flags(.block_active; .block_current) + (.block_id | id)),
                (.process // "-"), $title, (.status // "-"), (.last_activity | age)]
            | map(gsub("[[:space:]]"; " ")) | join("\t")'); or return
        set -a table "$line"
    end
    begin
        string join \t SESSION '   WINDOW' '   BLOCK' PROCESS TITLE STATUS ACTIVITY
        printf '%s\n' $table
    end | column -t -s \t
end
