function fish_title
    set -l command (status current-command)

    set -l ssh_prefix
    if set -q SSH_TTY; and not set -q TMUX
        # prefix hostname if in a SSH session but not in a TMUX session
        set ssh "["(prompt_hostname | string sub -l 10)"]"
    end

    # if test "$command" = fish
    if test (status current-command) = fish
        # no command is running, display current directory
        echo -- $ssh (prompt_pwd -d 1 -D 1)
    else
        # a command is running, display the command
        echo -- $ssh (string sub -l 20 -- $argv[1] | string trim)
    end
end
