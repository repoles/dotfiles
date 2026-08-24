# Keep Herdr's tab label in sync with the foreground command, like tmux's
# automatic-rename option. Herdr injects HERDR_TAB_ID into every pane it owns.
if status is-interactive; and set -q HERDR_TAB_ID
    function __herdr_rename_tab --argument-names label
        test -n "$label"; or return
        command herdr tab rename "$HERDR_TAB_ID" "$label" >/dev/null 2>&1
    end

    function __herdr_tab_running_command --on-event fish_preexec
        set -l tokens
        string collect -- $argv[1] | read --tokenize --array tokens

        # Find the executable rather than naming the tab after common wrappers
        # or a leading environment-variable assignment.
        set -l command_index 1
        while test $command_index -le (count $tokens)
            set -l token $tokens[$command_index]

            if string match --quiet --regex '^[A-Za-z_][A-Za-z0-9_]*=' -- "$token"
                set command_index (math $command_index + 1)
                continue
            end

            if contains -- "$token" command exec builtin nohup sudo
                set command_index (math $command_index + 1)
                continue
            end

            __herdr_rename_tab (path basename -- "$token")
            return
        end
    end

    function __herdr_tab_idle_shell --on-event fish_postexec
        set -l command_status $status
        __herdr_rename_tab fish
        return $command_status
    end

    # New tabs start at an interactive prompt, before either event has fired.
    __herdr_rename_tab fish
end
