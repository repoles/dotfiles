function ta --description "Select a claude or codex window across all tmux sessions"
    if test (count $argv) -gt 0
        echo "ta: arguments are not supported; every agent window is listed" >&2
        return 2
    end

    set now (date +%s)
    set current_session
    set current_window

    if set --query TMUX
        # like ts, run-shell has no client of its own, so the A binding exports the
        # pressing client's context; the fallback covers ta being called from the prompt
        if set --query TA_CURRENT_SESSION TA_CURRENT_WINDOW
            set current_session $TA_CURRENT_SESSION
            set current_window $TA_CURRENT_WINDOW
        else
            set client_context (tmux display-message -p "#{session_name}	#{window_index}")

            if test $status -eq 0
                set context_parts (string split \t -- $client_context)
                set current_session $context_parts[1]
                set current_window $context_parts[2]
            end
        end
    end

    # -a lists windows across every session; the pane title is kept raw for detection and cleaned below
    set window_lines (tmux list-windows -a -F "#{window_activity}	#{session_name}	#{window_index}	#{window_name}	#{pane_current_command}	#{pane_title}")

    if test $status -ne 0
        return 1
    end

    set window_lines (printf '%s\n' $window_lines | sort --reverse --numeric-sort)
    set entries
    set current

    for line in $window_lines
        set parts (string split \t -- $line)
        set name $parts[4]
        set cmd $parts[5]
        set raw_title $parts[6]

        # the F1/F2 bindings name windows claude or codex; run straight from a prompt each keeps
        # instead the name of its native binary, versioned for claude (2_1_217) and per-arch for
        # codex (codex-aarch64-apple-darwin). codex still starts with codex, in the window name or
        # the running command, so a prefix match catches it either way. claude's binary carries no
        # such hint, but it always prepends a marker to the title — ✳ when idle or awaiting input,
        # an animated braille spinner while it works — and that marker is claude's alone.
        set agent
        if string match --quiet --regex '^codex' -- "$name"
            or string match --quiet --regex '^codex' -- "$cmd"
            set agent codex
        else if test "$name" = claude
            or string match --quiet --regex '^(✳|[\x{2800}-\x{28ff}])' -- "$raw_title"
            set agent claude
        else
            continue
        end

        set position (math (count $entries) + 1)
        set title

        if test "$parts[2]" = "$current_session" -a "$parts[3]" = "$current_window"
            set current $position
        end

        # window_activity is the last output in the window, kept even for the current one:
        # on an agent window it tells you how long ago it stopped producing output
        set last_active (string split ' ' (humanize_duration (math --scale=0 "($now - $parts[1]) * 1000")))[1]

        # drop only the ✳ the agent prepends, like the status bar and tw; the braille spinner stays
        set clean_title (string replace --regex '^✳ ' '' -- "$raw_title")

        if test -n "$clean_title"
            set title " \"$clean_title\""
        end

        # the title goes last: it is the only field with no length bound, so fzf truncates it against the real popup width
        set --append entries "[$parts[2]] $parts[3]:$agent (active $last_active ago)$title"
    end

    if test (count $entries) -eq 0
        echo "ta: no claude or codex windows are open" >&2
        return 1
    end

    set fzf_options --exact --sync --tmux center,80%,50%

    if test -n "$current"
        set --append fzf_options --bind "start:pos($current)"
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

    set session (string replace --regex '^\[([^]]+)\].*$' '$1' -- "$selected")
    set index (string replace --regex '^\[[^]]+\] ([0-9]+):.*$' '$1' -- "$selected")
    set target "$session:$index"

    if set -q TMUX
        tmux switch-client -t "$target"
    else
        tmux select-window -t "$target"
        tmux attach-session -t "$session"
    end
end
