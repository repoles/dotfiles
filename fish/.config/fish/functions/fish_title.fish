function fish_title
    if test (status current-command) = fish
        # no command is running, display current directory
        echo -- (prompt_pwd -d 1 -D 1)
    else
        # a command is running, display the command
        echo -- (string sub -l 20 -- $argv[1] | string trim)
    end
end
