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

    # the stamp is written by agent-tmux-status.sh, which claude and codex both call from their
    # own hooks, so it only moves when the agent itself does something. neither window_activity
    # nor the mtime of the pane's tty can say that: session_set_current bumps the first on a
    # mere visit, and entering a session makes both agents rewrite their terminal modes, a write
    # the second cannot tell from real output. window_activity is still the fallback for a pane
    # with no stamp, like a window opened before its first hook fired.
    set cache_home $XDG_CACHE_HOME

    if test -z "$cache_home"
        set cache_home $HOME/.cache
    end

    set stamp_dir $cache_home/tmux-agent-activity

    # -a covers every session and the filter keeps one line per window; the pane id resolves the
    # stamp and the pane title is kept raw for detection, cleaned below
    set pane_lines (tmux list-panes -a -f '#{pane_active}' -F "#{window_activity}	#{pane_id}	#{session_name}	#{window_index}	#{window_name}	#{pane_current_command}	#{pane_title}")

    if test $status -ne 0
        return 1
    end

    set window_lines

    for line in $pane_lines
        set parts (string split \t -- $line)
        set last_active_at $parts[1]
        set stamp_file $stamp_dir/$parts[2]

        if test -r "$stamp_file"
            read --local stamp <$stamp_file

            if string match --quiet --regex '^\d+$' -- "$stamp"
                set last_active_at $stamp
            end
        end

        # the pane id is dropped here, so the rest of the function sees the same fields as before
        set --append window_lines (string join \t $last_active_at $parts[3..-1])
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
        # such hint, but it always prepends a symbol to the title, and that marker is claude's
        # alone; matching \p{So} instead of a list keeps this working when the symbol changes.
        set agent
        if string match --quiet --regex '^codex' -- "$name"
            or string match --quiet --regex '^codex' -- "$cmd"
            set agent codex
        else if test "$name" = claude
            or string match --quiet --regex '^\p{So}' -- "$raw_title"
            set agent claude
        else
            continue
        end

        set position (math (count $entries) + 1)
        set title

        if test "$parts[2]" = "$current_session" -a "$parts[3]" = "$current_window"
            set current $position
        end

        # the stamp is kept even for the current window: on an agent window it tells you how
        # long ago the agent last did something
        set last_active (string split ' ' (humanize_duration (math --scale=0 "($now - $parts[1]) * 1000")))[1]

        # drop only the ✳ claude code prepends when idle, like the status bar and tw; the
        # working spinner stays, it is the one marker that says something is happening
        set clean_title (string replace --regex '^✳\s*' '' -- "$raw_title")

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
